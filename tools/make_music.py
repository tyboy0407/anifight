"""產生遊戲的背景音樂:用程式合成 8-bit 風格(方波、三角波、雜訊鼓)的循環樂曲,
輸出成 assets/music/ 底下的 WAV 檔。旋律是為這個遊戲寫的原創曲,沒有用到任何外部素材。

    python tools/make_music.py           # 兩首都重做
    python tools/make_music.py battle    # 只重做名稱符合的

兩首曲子:
    select  選角畫面:慢、輕,A 小調
    battle  對戰:快、有推進感,E 小調

想換成自己的音樂:用同名的 WAV 檔蓋掉即可,遊戲會從頭到尾循環播放,
所以結尾要能接回開頭。需要 numpy。
"""

from __future__ import annotations

import pathlib
import sys
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "music"
SR = 22050
STEPS_PER_BAR = 16  # 一小節切成 16 個十六分音符

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
_rng = np.random.default_rng(3)


def freq(note: str) -> float:
    """音名(例如 "F#5")轉成頻率。A4 = 440 Hz。"""
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTE_INDEX[name] + (octave - 4) * 12 - 9) / 12)


def shift(note: str, octaves: int) -> str:
    return f"{note[:-1]}{int(note[-1]) + octaves}"


def envelope(count: int, attack: float, release: float, sustain: float = 0.75) -> np.ndarray:
    """音量曲線:很快起音、掉到 sustain、結尾收掉,避免每個音頭尾有雜音。"""
    env = np.full(count, sustain)
    a, r = max(int(SR * attack), 1), max(int(SR * release), 1)
    env[:a] = np.linspace(0, 1, a)[: len(env[:a])]
    decay = min(int(SR * 0.05), max(count - a, 0))
    env[a:a + decay] = np.linspace(1, sustain, decay)
    env[-r:] *= np.linspace(1, 0, r)[-len(env[-r:]):]
    return env


def pulse(note: str, seconds: float, duty: float, vibrato: float = 0.0) -> np.ndarray:
    """方波(主旋律與琶音)。duty 是高電位佔的比例,越小聲音越尖。"""
    count = int(SR * seconds)
    t = np.arange(count) / SR
    f = freq(note) * (1 + vibrato * np.sin(2 * np.pi * 6 * t) * np.clip(t / 0.15, 0, 1))
    phase = np.cumsum(f) / SR
    return np.where(phase % 1.0 < duty, 1.0, -1.0) * envelope(count, 0.004, 0.02)


def triangle(note: str, seconds: float) -> np.ndarray:
    """三角波(貝斯)。"""
    count = int(SR * seconds)
    phase = np.arange(count) * freq(note) / SR
    return (4 * np.abs(phase % 1.0 - 0.5) - 1) * envelope(count, 0.003, 0.015, 0.9)


def kick() -> np.ndarray:
    count = int(SR * 0.12)
    t = np.arange(count) / SR
    return np.sin(2 * np.pi * np.cumsum(150 * np.exp(-t * 28) + 42) / SR) * np.exp(-t * 22)


def snare() -> np.ndarray:
    count = int(SR * 0.11)
    t = np.arange(count) / SR
    return (_rng.uniform(-1, 1, count) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 30)


def hat() -> np.ndarray:
    count = int(SR * 0.035)
    noise = _rng.uniform(-1, 1, count)
    return (noise - np.concatenate([[0], noise[:-1]])) * 0.5 * np.exp(-np.arange(count) / SR * 90)


class Song:
    def __init__(self, bpm: float, bars: int) -> None:
        self.step = 60.0 / bpm / 4.0  # 一個十六分音符的秒數
        self.bars = bars
        self.length = int(round(SR * self.step * STEPS_PER_BAR * bars))
        self.mix = np.zeros(self.length)

    def add(self, sound: np.ndarray, bar: int, step: float, volume: float) -> None:
        start = int(round(SR * self.step * (bar * STEPS_PER_BAR + step)))
        # 超出結尾的部分繞回開頭:循環播放時尾音會自然接上
        for i in range(0, len(sound), self.length):
            chunk = sound[i:i + self.length]
            index = (start + i + np.arange(len(chunk))) % self.length
            np.add.at(self.mix, index, chunk * volume)

    def lead(self, bar: int, notes: list[tuple[float, str, float]], volume: float, duty: float = 0.25) -> None:
        for step, note, steps in notes:
            self.add(pulse(note, self.step * steps * 0.92, duty, 0.006), bar, step, volume)

    def arpeggio(self, bar: int, chord: list[str], volume: float, every: int = 1) -> None:
        for index, step in enumerate(range(0, STEPS_PER_BAR, every)):
            self.add(pulse(chord[index % len(chord)], self.step * every * 0.8, 0.125), bar, step, volume)

    def bass(self, bar: int, root: str, pattern: list[tuple[int, int, int]], volume: float) -> None:
        """pattern 的每一項是 (第幾步, 長度, 升幾個八度)。"""
        for step, steps, octave in pattern:
            self.add(triangle(shift(root, octave), self.step * steps * 0.9), bar, step, volume)

    def drums(self, bar: int, kicks: list[int], snares: list[int], hats: list[int], volume: float) -> None:
        for step in kicks:
            self.add(kick(), bar, step, volume)
        for step in snares:
            self.add(snare(), bar, step, volume * 0.6)
        for step in hats:
            self.add(hat(), bar, step, volume * 0.35)

    def render(self, peak: float) -> np.ndarray:
        # 輕輕壓掉最尖的高頻,方波才不會刺耳
        out = np.empty_like(self.mix)
        y = self.mix[-1]
        alpha = 1 - np.exp(-2 * np.pi * 7000 / SR)
        for i in range(2):  # 跑兩圈:第二圈的起點已經是「前一輪結尾」的狀態,循環點才沒有接縫
            for n in range(self.length):
                y += alpha * (self.mix[n] - y)
                out[n] = y
        out -= np.mean(out)
        return out * (peak / np.max(np.abs(out)))


# 和弦:根音與琶音用的四個音
CHORDS = {
    "Em": ("E2", ["E4", "G4", "B4", "E5"]), "C": ("C2", ["E4", "G4", "C5", "E5"]),
    "D": ("D2", ["D4", "F#4", "A4", "D5"]), "G": ("G2", ["D4", "G4", "B4", "D5"]),
    "Am": ("A2", ["E4", "A4", "C5", "E5"]), "B": ("B1", ["D#4", "F#4", "B4", "D#5"]),
    "F": ("F2", ["F4", "A4", "C5", "F5"]),
}


def battle() -> np.ndarray:
    song = Song(bpm=150, bars=16)
    chords = ["Em", "Em", "C", "D", "Em", "G", "C", "D", "Am", "Em", "C", "D", "Am", "Em", "B", "B"]
    melody = [
        [(0, "E5", 3), (3, "G5", 3), (6, "B5", 4), (10, "A5", 2), (12, "G5", 4)],
        [(0, "E5", 6), (6, "D5", 2), (8, "E5", 4), (12, "G5", 4)],
        [(0, "G5", 3), (3, "E5", 3), (6, "C5", 4), (10, "E5", 2), (12, "G5", 4)],
        [(0, "A5", 4), (4, "F#5", 4), (8, "D5", 4), (12, "F#5", 2), (14, "A5", 2)],
        [(0, "B5", 3), (3, "G5", 3), (6, "E5", 4), (10, "G5", 2), (12, "B5", 4)],
        [(0, "D6", 4), (4, "B5", 4), (8, "G5", 4), (12, "B5", 4)],
        [(0, "C6", 3), (3, "B5", 3), (6, "G5", 4), (10, "E5", 2), (12, "G5", 4)],
        [(0, "A5", 6), (6, "F#5", 2), (8, "D5", 2), (10, "F#5", 2), (12, "A5", 2), (14, "B5", 2)],
        [(0, "C6", 4), (4, "A5", 4), (8, "E5", 4), (12, "A5", 4)],
        [(0, "B5", 6), (6, "G5", 2), (8, "E5", 8)],
        [(0, "E5", 2), (2, "G5", 2), (4, "C6", 4), (8, "B5", 4), (12, "G5", 4)],
        [(0, "A5", 4), (4, "D6", 4), (8, "A5", 4), (12, "F#5", 4)],
        [(0, "E6", 4), (4, "C6", 4), (8, "A5", 4), (12, "C6", 4)],
        [(0, "B5", 4), (4, "G5", 4), (8, "E5", 4), (12, "G5", 2), (14, "B5", 2)],
        [(0, "F#5", 4), (4, "B5", 4), (8, "D#6", 4), (12, "B5", 4)],
        [(0, "F#5", 2), (2, "B5", 2), (4, "D#6", 2), (6, "F#6", 2), (8, "B5", 8)],
    ]
    drive_bass = [(0, 2, 0), (2, 2, 0), (4, 2, 0), (6, 2, 1), (8, 2, 0), (10, 2, 0), (12, 2, 0), (14, 2, 1)]
    for bar, name in enumerate(chords):
        root, tones = CHORDS[name]
        song.lead(bar, melody[bar], 0.30)
        song.arpeggio(bar, tones, 0.10)
        song.bass(bar, root, drive_bass, 0.34)
        last = bar % 8 == 7
        song.drums(bar, [0, 6, 8] if bar % 2 else [0, 8, 10],
                   [4, 12] if not last else [4, 10, 12, 13, 14, 15], list(range(0, 16, 2)), 0.42)
    return song.render(0.36)


def select() -> np.ndarray:
    song = Song(bpm=100, bars=8)
    chords = ["Am", "F", "C", "G", "Am", "F", "G", "Em"]
    melody = [
        [(0, "E5", 6), (6, "C5", 2), (8, "A4", 8)],
        [(0, "A4", 4), (4, "C5", 4), (8, "F5", 8)],
        [(0, "E5", 6), (6, "G5", 2), (8, "E5", 8)],
        [(0, "D5", 4), (4, "B4", 4), (8, "G4", 8)],
        [(0, "E5", 4), (4, "A5", 4), (8, "G5", 4), (12, "E5", 4)],
        [(0, "F5", 6), (6, "E5", 2), (8, "C5", 8)],
        [(0, "D5", 4), (4, "G5", 4), (8, "B5", 8)],
        [(0, "B4", 4), (4, "E5", 4), (8, "G5", 4), (12, "B4", 4)],
    ]
    for bar, name in enumerate(chords):
        root, tones = CHORDS[name]
        song.lead(bar, melody[bar], 0.24, 0.5)
        song.arpeggio(bar, tones, 0.10, 2)
        song.bass(bar, root, [(0, 6, 0), (8, 4, 0), (12, 4, 1)], 0.36)
        song.drums(bar, [0], [], [4, 12], 0.30)
    return song.render(0.30)


SONGS = {"select": select, "battle": battle}


def main() -> None:
    only = sys.argv[1:]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, make in SONGS.items():
        if only and not any(name.startswith(prefix) for prefix in only):
            continue
        samples = make()
        data = (np.clip(samples, -1, 1) * 32767).astype("<i2")
        with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(SR)
            out.writeframes(data.tobytes())
        rms = float(np.sqrt(np.mean(samples ** 2)))
        print(f"{name}.wav  {len(samples) / SR:5.1f} 秒  最大音量 {np.max(np.abs(samples)):.2f}  平均音量 {rms:.3f}  {len(data) * 2 / 1024:.0f} KB")


if __name__ == "__main__":
    main()
