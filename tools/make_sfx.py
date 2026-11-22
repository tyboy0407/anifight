"""產生遊戲的音效:用程式合成復古電玩風格的聲音,輸出成 assets/sfx/ 底下的 WAV 檔。

沒有用到任何外部素材。想調整某個音效,改下面對應的函式後重新執行(在專案資料夾):

    python tools/make_sfx.py            # 全部重做
    python tools/make_sfx.py hit_heavy  # 只重做名稱開頭符合的

想換成自己的音效檔:直接用同名的 WAV 檔蓋掉 assets/sfx/ 裡的檔案即可
(之後不要再對那個名稱執行這支工具,否則會被合成版蓋回去)。

有多個變化版的音效(例如 hit_light_1、hit_light_2)遊戲會隨機挑一個播,連打才不會單調。
清單要和 scripts/sfx.gd 的 SOUNDS 一致。需要 numpy(pip install numpy)。
"""

from __future__ import annotations

import pathlib
import sys
import wave
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "sfx"
SR = 22050  # 取樣率。復古音效不需要更高,檔案也比較小

_rng = np.random.default_rng(0)


# ---------- 基本零件 ----------

def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def osc(freq, dur: float, shape: str = "sine") -> np.ndarray:
    """振盪器。freq 可以是固定頻率,也可以是每個取樣點的頻率陣列(滑音)。"""
    n = int(SR * dur)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if np.ndim(freq) == 0 else np.asarray(freq, dtype=float)[:n]
    phase = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.sign(np.sin(phase))
    if shape == "saw":
        return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    if shape == "tri":
        return 2.0 * np.abs(2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(shape)


def glide(f0: float, f1: float, dur: float, curve: str = "exp") -> np.ndarray:
    """從 f0 滑到 f1 的頻率曲線。"""
    x = t(dur) / dur
    if curve == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def noise(dur: float) -> np.ndarray:
    return _rng.uniform(-1.0, 1.0, int(SR * dur))


def lowpass(x: np.ndarray, cutoff) -> np.ndarray:
    """單極點低通。cutoff 可以是陣列(隨時間變化)。"""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    alpha = 1.0 - np.exp(-2 * np.pi * c / SR)
    out = np.empty_like(x)
    y = 0.0
    for i in range(len(x)):
        y += alpha[i] * (x[i] - y)
        out[i] = y
    return out


def highpass(x: np.ndarray, cutoff) -> np.ndarray:
    return x - lowpass(x, cutoff)


def decay(dur: float, rate: float) -> np.ndarray:
    return np.exp(-t(dur) * rate)


def swell(dur: float, attack: float, release: float) -> np.ndarray:
    """慢慢變大、最後收掉的音量曲線。"""
    x = t(dur)
    return np.clip(x / attack, 0, 1) * np.clip((dur - x) / release, 0, 1)


def drive(x: np.ndarray, gain: float) -> np.ndarray:
    """失真:讓聲音更粗、更有打擊感。"""
    return np.tanh(x * gain)


def at(x: np.ndarray, start: float) -> np.ndarray:
    """往後延 start 秒才開始。"""
    return np.concatenate([np.zeros(int(SR * start)), x])


def mix(*parts: np.ndarray) -> np.ndarray:
    out = np.zeros(max(len(p) for p in parts))
    for p in parts:
        out[: len(p)] += p
    return out


def finish(x: np.ndarray, peak: float, fade_out: float = 0.012) -> np.ndarray:
    """去掉直流偏移、頭尾淡入淡出(避免爆音)、把最大音量調到 peak。"""
    x = x - np.mean(x)
    fi = max(int(SR * 0.002), 1)
    fo = max(int(SR * fade_out), 1)
    x[:fi] *= np.linspace(0, 1, fi)
    x[-fo:] *= np.linspace(1, 0, fo)
    return x * (peak / max(np.max(np.abs(x)), 1e-9))


def thump(f0: float, f1: float, dur: float, rate: float) -> np.ndarray:
    """低頻的「咚」:打擊感的主體。"""
    return osc(glide(f0, f1, dur), dur) * decay(dur, rate)


def whoosh(dur: float, lo: float, hi: float, floor: float = 400.0) -> np.ndarray:
    """揮動的風聲:雜訊的亮度先升後降。"""
    x = t(dur) / dur
    cut = lo + (hi - lo) * np.sin(np.pi * x) ** 2
    return highpass(lowpass(noise(dur), cut), floor) * np.sin(np.pi * x) ** 1.4


def notes(freqs: list[float], step: float, hold: float, shape: str = "square", rate: float = 9.0) -> np.ndarray:
    """一串音符,每個晚 step 秒開始、各自響 hold 秒。"""
    return mix(*[at(osc(f, hold, shape) * decay(hold, rate), i * step) for i, f in enumerate(freqs)])


# ---------- 共用戰鬥音效 ----------

def swing(v: int) -> np.ndarray:
    dur = [0.13, 0.16][v]
    return finish(whoosh(dur, 700, [3600, 2800][v]), 0.30)


def hit_light(v: int) -> np.ndarray:
    base = [220, 250, 190][v]
    body = thump(base, base * 0.4, 0.10, 34)
    grit = lowpass(noise(0.10), 2600) * decay(0.10, 46) * 0.7
    click = highpass(noise(0.03), 1800) * decay(0.03, 110) * 0.6
    return finish(drive(mix(body, grit, click), 1.6), 0.55)


def hit_heavy(v: int) -> np.ndarray:
    base = [150, 130][v]
    body = thump(base, 38, 0.30, 13)
    sub = osc(52, 0.30, "square") * decay(0.30, 20) * 0.25
    crunch = lowpass(noise(0.30), 1900) * decay(0.30, 20) * 0.9
    click = highpass(noise(0.03), 2000) * decay(0.03, 100) * 0.7
    return finish(drive(mix(body, sub, crunch, click), 2.6), 0.75)


def guard(v: int) -> np.ndarray:
    dur = 0.13
    ring = sum(osc(f, dur, "square") * w for f, w in [(820, 1.0), (1240, 0.7), (1710, 0.5)]) * decay(dur, 42)
    click = highpass(noise(0.02), 2500) * decay(0.02, 140)
    return finish(lowpass(mix(ring, click), 5200), 0.52)


def land(v: int) -> np.ndarray:
    return finish(mix(thump(110, 58, 0.10, 40), lowpass(noise(0.10), 600) * decay(0.10, 60) * 0.5), 0.30)


def down(v: int) -> np.ndarray:
    return finish(drive(mix(thump(92, 44, 0.26, 17), lowpass(noise(0.26), 950) * decay(0.26, 24) * 0.8), 1.5), 0.50)


def jump(v: int) -> np.ndarray:
    dur = 0.09
    return finish(lowpass(osc(glide(280, 560, dur), dur, "square") * decay(dur, 18), 2400), 0.20)


def dash(v: int) -> np.ndarray:
    dur = 0.15
    x = t(dur) / dur
    air = highpass(lowpass(noise(dur), 5200 - 3600 * x), 900) * (1 - x) ** 1.2
    return finish(air, 0.28)


def teleport(v: int) -> np.ndarray:
    dur = 0.16
    zip_down = osc(glide(1900, 260, dur), dur, "tri") * decay(dur, 14)
    air = highpass(noise(dur), 3000) * decay(dur, 30) * 0.5
    return finish(mix(zip_down, air), 0.35)


def burst(v: int) -> np.ndarray:
    dur = 0.42
    blast = lowpass(noise(dur), glide(4500, 350, dur)) * decay(dur, 8)
    rise = osc(glide(180, 720, 0.20), 0.20, "saw") * decay(0.20, 9) * 0.5
    return finish(drive(mix(blast, lowpass(rise, 2500), thump(140, 50, 0.2, 16)), 1.8), 0.60)


def ko(v: int) -> np.ndarray:
    dur = 0.95
    boom = thump(125, 28, dur, 5.0)
    rumble = lowpass(noise(dur), 1100) * decay(dur, 5.5) * 0.9
    fall = lowpass(osc(glide(440, 105, 0.6), 0.6, "square"), 1800) * decay(0.6, 4.5) * 0.3
    click = highpass(noise(0.04), 1500) * decay(0.04, 80)
    return finish(drive(mix(boom, rumble, fall, click), 2.4), 0.80, 0.05)


def special(v: int) -> np.ndarray:
    dur = 0.26
    edge = lowpass(osc(glide(190, 720, dur), dur, "saw"), 2600) * swell(dur, 0.03, 0.12) * 0.7
    return finish(mix(edge, whoosh(dur, 900, 4200) * 0.9), 0.45)


def bounce(v: int) -> np.ndarray:
    base = [130, 115][v]
    grit = highpass(lowpass(noise(0.20), 2600), 350) * decay(0.20, 28)
    return finish(drive(mix(thump(base, 48, 0.20, 21), grit), 2.0), 0.55)


def wall_crash(v: int) -> np.ndarray:
    dur = 0.75
    blast = lowpass(noise(dur), glide(3800, 500, dur)) * decay(dur, 6.5)
    # 碎石:稀疏的小撞擊聲,越後面越少
    sparks = (_rng.uniform(0, 1, int(SR * dur)) < 0.012) * _rng.uniform(-1, 1, int(SR * dur))
    debris = lowpass(sparks * 6.0, 3200) * decay(dur, 3.0)
    return finish(drive(mix(blast, debris, thump(105, 30, 0.45, 9)), 2.2), 0.80, 0.04)


# ---------- 介面 ----------

def ui_move(v: int) -> np.ndarray:
    return finish(lowpass(osc(740, 0.05, "square") * decay(0.05, 48), 3200), 0.22)


def ui_confirm(v: int) -> np.ndarray:
    return finish(lowpass(notes([660, 990], 0.06, 0.11, "square", 16), 3600), 0.28)


def ui_start(v: int) -> np.ndarray:
    return finish(lowpass(notes([523, 659, 784, 1047], 0.07, 0.22, "square", 9) + 0, 3800), 0.32, 0.03)


def round_start(v: int) -> np.ndarray:
    dur = 0.55
    bell = (osc(392, dur, "square") * 0.6 + osc(587, dur, "tri") + osc(784, dur) * 0.5) * decay(dur, 6)
    return finish(lowpass(mix(bell, highpass(noise(0.02), 2000) * decay(0.02, 120)), 3600), 0.40, 0.04)


def time_up(v: int) -> np.ndarray:
    return finish(lowpass(notes([660, 523, 392], 0.13, 0.30, "square", 7), 3000), 0.35, 0.04)


def victory(v: int) -> np.ndarray:
    lead = notes([523, 659, 784, 1047], 0.11, 0.55, "square", 4.5)
    bass = notes([131, 165, 196, 262], 0.11, 0.55, "tri", 4.5) * 0.8
    return finish(lowpass(mix(lead, bass), 3600), 0.40, 0.06)


# ---------- 招牌招式 ----------

def black_flash(v: int) -> np.ndarray:
    dur = 0.55
    crack = highpass(lowpass(noise(0.16), 6500), 1000) * decay(0.16, 30)
    sub = drive(osc(50, dur, "square") * decay(dur, 8.5), 3.0) * 0.8
    zap = osc(glide(3200, 120, 0.2), 0.2, "saw") * decay(0.2, 12) * 0.6
    # 殘留的電流聲
    sizzle = highpass(noise(dur), 2500) * (osc(62, dur, "square") > 0) * decay(dur, 9) * 0.45
    return finish(drive(mix(crack, sub, zap, sizzle), 1.8), 0.80, 0.04)


def domain_void(v: int) -> np.ndarray:
    dur = 1.7
    drone = (osc(55, dur) + osc(82.5, dur) * 0.7 + osc(110, dur, "tri") * 0.3) * swell(dur, 0.6, 0.6)
    x = t(dur)
    shimmer = sum(
        osc(f, dur) * (0.5 + 0.5 * np.sin(2 * np.pi * r * x)) for f, r in [(1320, 5.0), (1760, 6.3), (2093, 7.1), (2637, 4.2)]
    ) * swell(dur, 0.9, 0.5) * 0.22
    breath = highpass(noise(1.0), glide(6000, 1500, 1.0)) * (t(1.0) / 1.0) ** 2 * 0.35
    ping = at((osc(1568, 0.6) + osc(2349, 0.6) * 0.6) * decay(0.6, 6) * 0.5, 1.0)
    hit = at(thump(95, 32, 0.5, 7) * 0.9, 1.0)
    return finish(mix(drone, shimmer, breath, ping, hit), 0.62, 0.08)


def domain_shrine(v: int) -> np.ndarray:
    dur = 1.7
    x = t(dur)
    growl = lowpass(osc(49, dur, "saw") + osc(73.4, dur, "saw") * 0.7, 420) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * x))
    evil = lowpass(osc(98, dur, "square") + osc(138.6, dur, "square"), 900) * 0.25
    bed = (growl + evil) * swell(dur, 0.5, 0.5)
    cuts = mix(*[at(slash(i % 2) * 1.6, 0.95 + 0.14 * i) for i in range(3)])
    hit = at(thump(90, 30, 0.5, 7), 0.95)
    return finish(drive(mix(bed, cuts, hit), 1.4), 0.65, 0.08)


def slash(v: int) -> np.ndarray:
    dur = [0.14, 0.17][v]
    x = t(dur) / dur
    blade = highpass(lowpass(noise(dur), 6500 - 4200 * x), 2200) * decay(dur, 20)
    edge = osc(glide([2500, 2100][v], 900, dur), dur, "saw") * decay(dur, 26) * 0.25
    return finish(mix(blade, edge), 0.40)


def blue(v: int) -> np.ndarray:
    dur = 0.6
    x = t(dur)
    pull = osc(glide(520, 105, dur), dur) * (0.65 + 0.35 * np.sin(2 * np.pi * 22 * x))
    air = lowpass(noise(dur), glide(3000, 300, dur)) * 0.5
    return finish(mix(pull, air) * swell(dur, 0.15, 0.2), 0.50, 0.03)


def red(v: int) -> np.ndarray:
    rise = lowpass(osc(glide(150, 950, 0.13), 0.13, "saw"), 3000) * (t(0.13) / 0.13) * 0.7
    blast = lowpass(noise(0.55), glide(3800, 300, 0.55)) * decay(0.55, 7.5)
    return finish(drive(mix(rise, at(mix(blast, thump(140, 34, 0.45, 9)), 0.12)), 2.0), 0.70, 0.04)


def infinity(v: int) -> np.ndarray:
    dur = 0.55
    vib = 1 + 0.004 * np.sin(2 * np.pi * 7 * t(dur))
    glass = sum(osc(f * vib, dur) * w for f, w in [(880, 1.0), (1318.5, 0.7), (1760, 0.5)]) * decay(dur, 6)
    return finish(glass, 0.35, 0.04)


def overflow(v: int) -> np.ndarray:
    arp = notes([330, 440, 554, 659, 880], 0.06, 0.40, "tri", 6.0)
    glow = notes([660, 880, 1108, 1318, 1760], 0.06, 0.40, "sine", 7.0) * 0.5
    hiss = highpass(noise(0.5), 4000) * swell(0.5, 0.25, 0.25) * 0.15
    return finish(mix(arp, glow, hiss), 0.40, 0.05)


def powerup(v: int) -> np.ndarray:
    lift = osc(glide(300, 900, 0.22), 0.22, "tri") * swell(0.22, 0.02, 0.08) * 0.7
    chime = at(notes([660, 990], 0.07, 0.22, "square", 11) * 0.6, 0.12)
    return finish(lowpass(mix(lift, chime), 3600), 0.35, 0.03)


def speech(v: int) -> np.ndarray:
    dur = 0.42
    x = t(dur)
    wob = 1 + 0.25 * np.sin(2 * np.pi * 14 * x)
    wave_ = (osc(92 * wob, dur) + lowpass(osc(184 * wob, dur, "square"), 700) * 0.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * x))
    air = whoosh(dur, 600, 2600) * 0.6
    return finish(drive(mix(wave_ * decay(dur, 4), air), 1.5), 0.55, 0.03)


def friend_charge(v: int) -> np.ndarray:
    dur = 0.42
    x = t(dur)
    growl = lowpass(osc(glide(60, 250, dur), dur, "saw"), 1300) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * x))
    air = highpass(noise(dur), 2000) * 0.3
    return finish(mix(growl, air) * (x / dur) ** 1.6, 0.50, 0.01)


def rika_summon(v: int) -> np.ndarray:
    dur = 1.15
    x = t(dur)
    low = lowpass(osc(73, dur, "saw") + osc(77.8, dur, "saw"), 720) * swell(dur, 0.35, 0.4)
    wail = osc(glide(620, 440, dur, "lin") * (1 + 0.02 * np.sin(2 * np.pi * 6 * x)), dur) * swell(dur, 0.5, 0.4) * 0.45
    breath = highpass(lowpass(noise(dur), 2500), 600) * swell(dur, 0.6, 0.3) * 0.3
    return finish(drive(mix(low, wail, breath), 1.3), 0.60, 0.06)


def rika_claw(v: int) -> np.ndarray:
    cuts = mix(*[at(slash(i % 2), 0.03 * i) for i in range(3)])
    growl = lowpass(osc(118, 0.18, "square"), 600) * decay(0.18, 14) * 0.5
    return finish(mix(cuts, growl), 0.50)


def cannon_charge(v: int) -> np.ndarray:
    dur = 2.9  # 配合純愛砲 3 秒的蓄力
    x = t(dur)
    f = glide(100, 700, dur)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(glide(5, 28, dur)) / SR)
    tone = (osc(f, dur) + lowpass(osc(f * 0.5, dur, "saw"), 1500) * 0.5) * trem
    hiss = highpass(noise(dur), 3000) * 0.2
    return finish(mix(tone, hiss) * (0.15 + 0.85 * (x / dur) ** 2), 0.42, 0.01)


def cannon_fire(v: int) -> np.ndarray:
    dur = 0.78
    x = t(dur)
    beam = lowpass(osc(110, dur, "saw") + osc(165.6, dur, "saw") * 0.8 + osc(221, dur, "saw") * 0.6, 3200)
    roar = lowpass(noise(dur), 5000) * 0.8
    body = (beam + roar) * (0.75 + 0.25 * np.sin(2 * np.pi * 40 * x)) * np.clip((dur - x) / 0.28, 0, 1)
    return finish(drive(mix(body, thump(150, 35, 0.4, 8) * 1.2), 1.8), 0.80, 0.05)


def shikigami(v: int) -> np.ndarray:
    dur = 0.24
    x = t(dur)
    f = [glide(900, 1450, dur), glide(520, 300, dur)][v]  # 鷲:往上的鳴叫;玉犬:往下的低吼
    call = osc(f, dur, ["sine", "square"][v]) * (0.5 + 0.5 * np.sin(2 * np.pi * [36, 48][v] * x))
    return finish(lowpass(mix(call * swell(dur, 0.02, 0.1), highpass(noise(dur), 3000) * decay(dur, 20) * 0.2), 3400), 0.35, 0.02)


def combine(v: int) -> np.ndarray:
    rise = lowpass(osc(glide(160, 640, 0.35), 0.35, "saw"), 2400) * swell(0.35, 0.05, 0.1) * 0.6
    return finish(drive(mix(rise, shikigami(0) * 2, at(shikigami(1) * 2, 0.08), at(thump(120, 40, 0.3, 11) * 1.5, 0.3)), 1.4), 0.50, 0.04)


def divergent(v: int) -> np.ndarray:
    dur = 0.32
    x = t(dur)
    warp = osc(glide(320, 140, dur) * (1 + 0.08 * np.sin(2 * np.pi * 19 * x)), dur, "tri") * decay(dur, 6)
    return finish(mix(warp, whoosh(dur, 500, 2400) * 0.6), 0.45, 0.02)


def parry(v: int) -> np.ndarray:
    dur = 0.32
    ting = (osc(1568, dur) + osc(2349, dur) * 0.6 + osc(3136, dur) * 0.3) * decay(dur, 13)
    return finish(mix(ting, highpass(noise(0.015), 3000) * decay(0.015, 150) * 0.6), 0.40, 0.03)


def weapon_swap(v: int) -> np.ndarray:
    dur = 0.16
    x = t(dur) / dur
    scrape = highpass(lowpass(noise(dur), 7000 - 3000 * x), 2600) * decay(dur, 16)
    ring = (osc(2200, dur) + osc(3300, dur) * 0.6) * decay(dur, 22) * 0.5
    return finish(mix(scrape, ring), 0.38)


def bind(v: int) -> np.ndarray:
    # 咒縛狀態:兩下沉重的心跳,接著往上衝的低吼
    beats = mix(thump(85, 40, 0.22, 14), at(thump(95, 42, 0.26, 12) * 1.2, 0.20))
    dur = 0.55
    x = t(dur)
    surge = lowpass(osc(glide(55, 210, dur), dur, "saw"), 1100) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * x)) * swell(dur, 0.25, 0.2)
    return finish(drive(mix(beats, at(surge, 0.18), at(highpass(noise(0.3), 2500) * decay(0.3, 9) * 0.3, 0.42)), 1.7), 0.65, 0.05)


# ---------- 火影忍者系列 ----------

def kunai(v: int) -> np.ndarray:
    # 擲出苦無:短促尖銳的破風聲,帶一點金屬的顫音
    dur = [0.12, 0.14][v]
    x = t(dur) / dur
    air = highpass(lowpass(noise(dur), 7500 - 3500 * x), 3000) * (1 - x) ** 1.5
    ring = (osc([3100, 2700][v], dur) + osc([4650, 4050][v], dur) * 0.5) * decay(dur, 30) * 0.3
    return finish(mix(air, ring), 0.36)


def rasengan(v: int) -> np.ndarray:
    # 螺旋丸:高速旋轉的查克拉,嗡嗡聲越轉越快、越來越亮
    dur = 0.75
    x = t(dur)
    spin = np.sin(2 * np.pi * np.cumsum(glide(26, 62, dur)) / SR)
    hum = (osc(glide(190, 330, dur), dur, "tri") + lowpass(osc(glide(95, 165, dur), dur, "saw"), 1200) * 0.6) * (0.55 + 0.45 * spin)
    wind = highpass(lowpass(noise(dur), glide(1800, 5200, dur)), 900) * (0.5 + 0.5 * spin) * 0.7
    return finish(mix(hum, wind) * swell(dur, 0.12, 0.12), 0.50, 0.03)


def rasengan_burst(v: int) -> np.ndarray:
    # 螺旋丸炸開:旋轉聲一口氣甩開,接著一聲悶響
    whirl = whoosh(0.30, 900, 6000) * 0.9
    blast = lowpass(noise(0.45), glide(4200, 350, 0.45)) * decay(0.45, 8)
    return finish(drive(mix(whirl, at(mix(blast, thump(170, 40, 0.4, 9) * 1.2), 0.05)), 1.9), 0.72, 0.04)


def mark(v: int) -> np.ndarray:
    # 飛雷神的術式烙在對手身上:兩聲很短的高音
    chime = notes([1320, 1980], 0.05, 0.18, "sine", 16)
    return finish(mix(chime, highpass(noise(0.04), 4000) * decay(0.04, 80) * 0.3), 0.34, 0.03)


def poof(v: int) -> np.ndarray:
    # 影分身:「砰」一團白煙
    dur = 0.30
    puff = lowpass(noise(dur), glide(2600, 500, dur)) * decay(dur, 11)
    return finish(mix(puff, thump(210, 90, 0.10, 30) * 0.8), 0.42, 0.03)


def chidori(v: int) -> np.ndarray:
    # 千鳥:一千隻鳥在叫。又高又急的啁啾聲越來越密,底下是電流的嘶嘶聲(配合 1 秒的蓄力)
    dur = 1.0
    x = t(dur)
    rate = glide(18, 46, dur)
    chirp = np.abs(np.sin(2 * np.pi * np.cumsum(rate) / SR)) ** 3
    birds = (osc(glide(2300, 3400, dur) * (1 + 0.12 * np.sin(2 * np.pi * np.cumsum(rate * 2) / SR)), dur, "tri")
             + osc(glide(3500, 4700, dur), dur) * 0.4) * chirp
    hiss = highpass(noise(dur), 3500) * (0.25 + 0.75 * chirp) * 0.5
    hum = lowpass(osc(118, dur, "saw"), 700) * 0.25
    return finish(mix(birds, hiss, hum) * (0.3 + 0.7 * (x / dur) ** 1.5), 0.46, 0.02)


def thunder(v: int) -> np.ndarray:
    # 雷打在人身上:一聲又乾又脆的爆裂,接著短短的餘響
    crack = highpass(noise(0.06), 1500) * decay(0.06, 40) * 1.2
    body = lowpass(noise(0.4), glide(5000, 400, 0.4)) * decay(0.4, 10)
    zap = osc(glide(1800, 240, 0.16), 0.16, "saw") * decay(0.16, 18) * 0.5
    return finish(drive(mix(crack, body, zap, thump(160, 45, 0.3, 11)), 2.0), 0.72, 0.04)


def fireball(v: int) -> np.ndarray:
    # 豪火球:先吸一口氣,再轟地一聲噴出去,火燒得呼呼作響
    dur = 0.75
    x = t(dur)
    roar = lowpass(noise(dur), 900 + 2400 * np.sin(np.pi * x / dur) ** 2) * (0.7 + 0.3 * np.sin(2 * np.pi * 31 * x))
    low = lowpass(osc(glide(120, 62, dur), dur, "saw"), 500) * 0.6
    return finish(drive(mix(roar, low) * swell(dur, 0.07, 0.4), 1.6), 0.60, 0.05)


def kirin_charge(v: int) -> np.ndarray:
    # 麒麟蓄力:烏雲裡悶悶的雷聲越滾越大,夾著零星的劈啪聲(配合 1 秒的蓄力)
    dur = 1.0
    x = t(dur)
    rumble = lowpass(noise(dur), glide(180, 700, dur)) * (0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(glide(4, 13, dur)) / SR))
    sub = osc(glide(42, 70, dur), dur) * 0.6
    crackle_ = highpass(noise(dur), 3000) * (_rng.uniform(0, 1, len(x)) > 0.997).astype(float)
    crackle_ = np.convolve(crackle_, decay(0.03, 120), "same") * 2.5
    return finish(drive(mix(rumble, sub, crackle_) * (0.2 + 0.8 * (x / dur) ** 1.6), 1.5), 0.55, 0.02)


def kirin(v: int) -> np.ndarray:
    # 麒麟落下:撕開空氣的一聲巨響,後面拖著長長的滾雷
    crack = highpass(noise(0.09), 1200) * decay(0.09, 26) * 1.4
    tear = osc(glide(2600, 150, 0.22), 0.22, "saw") * decay(0.22, 12) * 0.6
    roll = lowpass(noise(1.1), glide(3600, 180, 1.1)) * decay(1.1, 3.6) * (0.75 + 0.25 * np.sin(2 * np.pi * 9 * t(1.1)))
    boom = thump(120, 30, 0.7, 5.5) * 1.5
    return finish(drive(mix(crack, tear, roll, boom), 2.4), 0.85, 0.08)


def snake_bite(v: int) -> np.ndarray:
    # 蛇咬:一聲尖銳的嘶聲射出去,最後「喀」地咬住
    dur = 0.34
    x = t(dur) / dur
    hiss = highpass(noise(dur), 4200) * (0.3 + 0.7 * x) * np.clip((1 - x) / 0.15, 0, 1)
    snap = at(mix(thump(420, 160, 0.06, 50), highpass(noise(0.03), 2500) * decay(0.03, 120)), dur - 0.07)
    return finish(mix(hiss * 0.8, snap), 0.42, 0.02)


def snake_cage(v: int) -> np.ndarray:
    # 蛇籠:一大群小蛇在地上爬的沙沙聲,忽大忽小
    dur = 0.9
    x = t(dur)
    rustle = highpass(lowpass(noise(dur), 5200), 1800) * (0.55 + 0.45 * np.sin(2 * np.pi * 17 * x)) * (0.6 + 0.4 * np.sin(2 * np.pi * 3.1 * x))
    low = lowpass(noise(dur), 420) * 0.35
    return finish(mix(rustle, low) * swell(dur, 0.12, 0.35), 0.36, 0.05)


# 音效名稱 -> (產生函式, 變化版數量)。和 scripts/sfx.gd 的 SOUNDS 對應。
SOUNDS = {
    "swing": (swing, 2), "hit_light": (hit_light, 3), "hit_heavy": (hit_heavy, 2), "guard": (guard, 1),
    "land": (land, 1), "down": (down, 1), "jump": (jump, 1), "dash": (dash, 1), "teleport": (teleport, 1),
    "burst": (burst, 1), "ko": (ko, 1), "special": (special, 1), "bounce": (bounce, 2), "wall_crash": (wall_crash, 1),
    "ui_move": (ui_move, 1), "ui_confirm": (ui_confirm, 1), "ui_start": (ui_start, 1),
    "round_start": (round_start, 1), "time_up": (time_up, 1), "victory": (victory, 1),
    "black_flash": (black_flash, 1), "domain_void": (domain_void, 1), "domain_shrine": (domain_shrine, 1),
    "slash": (slash, 2), "blue": (blue, 1), "red": (red, 1), "infinity": (infinity, 1), "overflow": (overflow, 1),
    "powerup": (powerup, 1), "speech": (speech, 1), "friend_charge": (friend_charge, 1),
    "rika_summon": (rika_summon, 1), "rika_claw": (rika_claw, 1), "cannon_charge": (cannon_charge, 1),
    "cannon_fire": (cannon_fire, 1), "shikigami": (shikigami, 2), "combine": (combine, 1),
    "divergent": (divergent, 1), "parry": (parry, 1), "weapon_swap": (weapon_swap, 1), "bind": (bind, 1),
    "kunai": (kunai, 2), "rasengan": (rasengan, 1), "rasengan_burst": (rasengan_burst, 1), "mark": (mark, 1),
    "poof": (poof, 1), "chidori": (chidori, 1), "thunder": (thunder, 1), "fireball": (fireball, 1),
    "kirin_charge": (kirin_charge, 1), "kirin": (kirin, 1), "snake_bite": (snake_bite, 1), "snake_cage": (snake_cage, 1),
}


# 打擊、爆炸類的音效做完後再壓一次高頻(數字是保留到幾 Hz):
# 失真會帶出很多沙沙的雜訊,壓掉之後聲音比較沉、比較有重量,連打時也不刺耳。
SOFTEN = {
    "hit_light": 4200, "hit_heavy": 3000, "ko": 2600, "down": 2400, "bounce": 3000, "wall_crash": 3400,
    "burst": 3400, "black_flash": 4000, "cannon_fire": 3600, "speech": 3000, "red": 3400,
    "domain_shrine": 3200, "bind": 3000, "special": 4200, "rasengan_burst": 3600,
    "thunder": 4200, "kirin": 3800, "fireball": 3200,
}


def write_wav(path: pathlib.Path, samples: np.ndarray) -> None:
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(data.tobytes())


def main() -> None:
    global _rng
    prefixes = sys.argv[1:]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    total = 0
    count = 0
    for name, (make, variants) in SOUNDS.items():
        if prefixes and not any(name.startswith(p) for p in prefixes):
            continue
        for v in range(variants):
            # 每個音效用自己固定的亂數種子:重跑的結果一樣,改一個不會影響其他的
            _rng = np.random.default_rng(zlib.crc32(f"{name}{v}".encode()))
            samples = make(v)
            if name in SOFTEN:
                peak = np.max(np.abs(samples))
                samples = finish(lowpass(samples, SOFTEN[name]), peak)
            file_name = f"{name}_{v + 1}.wav" if variants > 1 else f"{name}.wav"
            write_wav(OUTPUT / file_name, samples)
            total += len(samples) * 2
            count += 1
            print(f"{file_name:22s} {len(samples) / SR:5.2f} 秒  最大音量 {np.max(np.abs(samples)):.2f}")
    print(f"輸出 {count} 個音效到 {OUTPUT.relative_to(ROOT)},共 {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
