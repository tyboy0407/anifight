"""把 pixelfx 的特效匯出成遊戲用的 sprite sheet。

pixelfx(https://github.com/patch-gg/pixelfx,MIT 授權)是一套用程式畫的點陣特效庫。
這支工具呼叫它的算圖程式,把下面 SETS 列出的特效各算成一張透明底的圖,
再裁切、抽格、對齊,每一組合成一張遊戲讀得懂的圖(格式見 scripts/sprite_sheet_loader.gd):

    assets/effects_fx/   招式特效(刀光、火花、斬擊、爪痕…),多半是灰階,由遊戲染色
    assets/summons_fx/   召喚物(鷲、玉犬、里香)與純愛砲的光束,用自己的顏色
    assets/domain_void_fx/、assets/domain_shrine_fx/   領域展開的背景(無量空處、伏魔御廚子)
    assets/naruto_fx/    火影忍者系列角色的特效(苦無、螺旋丸、飛雷神印記、影分身的白煙)

    python tools/import_pixelfx.py            # 全部重做
    python tools/import_pixelfx.py --only summons_fx,domain_void_fx   # 只重做其中幾組
    python tools/import_pixelfx.py --preview <資料夾>  # 另外輸出預覽圖,方便檢查

需要:Node 18 以上、numpy、Pillow,以及放在 .claude/pixelfx/ 的 pixelfx 原始碼
(這個資料夾不在版本控制裡;沒有的話要先取得 pixelfx 放進去)。
沒有 pixelfx 也能玩遊戲:assets 裡已經是匯出好的結果。

pixelfx 沒有的東西(飛行的斬擊、式神、里香)是這個專案用 pixelfx 的繪圖工具自己寫的,
原始碼在 tools/pixelfx_custom/,算圖前會複製進 pixelfx 的 src/fx/ 底下。

每個特效的設定:
    id          pixelfx 的特效編號(anifight/ 開頭的是 tools/pixelfx_custom/ 裡自己寫的)
    opts        傳給特效的選項(調色盤、高度、模式…)
    anchor      對齊點相對於特效原點的位置(點陣圖像素,往右、往下為正)。
                遊戲播放時,對齊點會落在指定的座標上。原點通常是角色的腳底。
                寫 "centroid" 的話改用圖案的重心(打在目標身上的斬擊、爪痕)。
    start       從第幾格開始取(跳過前面蓄力的部分)
    stride      每幾格取一格(減少張數)
    max_frames  只取前面幾格(特效後段多半只剩零星火星)
    speed       播放速度倍率
    keep_radius 只保留對齊點周圍這個半徑內的像素(去掉光球底下的地面反光)
"""

from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
PIXELFX = ROOT / ".claude" / "pixelfx"
CUSTOM = ROOT / "tools" / "pixelfx_custom"
ASSETS = ROOT / "assets"
MAX_WIDTH = 2048

# 灰階調色盤:算出來的圖是黑白的,顏色由遊戲在播放時染上去,同一張圖可以給不同招式共用
GRAY = ["#262626", "#4d4d4d", "#737373", "#999999", "#bfbfbf", "#e6e6e6", "#ffffff"]
# 冷色調:無量空處的黑洞、無下限的光球
ICE = ["#070a1c", "#141c44", "#24357a", "#3f62b8", "#6c9ce8", "#a8d0ff", "#e6f4ff", "#ffffff"]

EFFECTS = {
    # 刀光:原點在揮刀的人腳底,弧線在身前
    "slash": dict(id="melee/sword-slash", opts={"palette": GRAY}, max_frames=14, speed=1.6),
    # 命中火花:原點在被打的人腳底,火花在胸口高度炸開後掉到地上
    "spark": dict(id="impacts/hit-spark", opts={"height": 21}, speed=1.2),
    # 重擊:更大的星芒加一圈碎裂的光環
    "crit": dict(id="impacts/crit-hit", opts={"height": 21}, max_frames=20, speed=1.3),
    # 防禦:面前半圓的護盾
    "guard": dict(id="impacts/shield-block", stride=2, max_frames=13, speed=1.6),
    # 重摔在地上:裂痕、兩圈往外滾的煙塵
    "landing": dict(id="impacts/heavy-landing", stride=2, max_frames=14, speed=1.4),
    # 咒力光球(循環):對齊點是球心
    "orb": dict(id="arcane/arcane-orb", opts={"palette": GRAY}, anchor=(0, -52), keep_radius=38, stride=3, loop=True),
    # 黑洞般的漩渦(循環):五條悟的「蒼」
    "void": dict(id="shadow/void-orb", opts={"palette": GRAY}, anchor=(0, -62), keep_radius=58, stride=3, loop=True),
    # 三道爪痕:里香的爪、式神的撲咬
    "claw": dict(id="melee/claw-swipe", opts={"palette": GRAY}, anchor="centroid", max_frames=16, speed=1.5),
    # 一連串各種角度的小斬擊,最後一刀大的:宿儺的「捌」
    "flurry": dict(id="melee/dagger-flurry", opts={"palette": GRAY}, anchor="centroid", max_frames=22, speed=0.95),
    # 交叉的兩刀:伏魔御廚子落下的斬擊、「捌」的最後一擊
    "cut": dict(id="melee/double-slash", opts={"palette": GRAY}, anchor="centroid", max_frames=13, speed=1.5),
    # 飛行中的斬擊(循環):宿儺的「解」。自己寫的,見 tools/pixelfx_custom/
    "airslash": dict(id="anifight/air-slash", opts={"palette": GRAY}, loop=True),
}

# 第二組招式特效(第一張圖已經排滿了)。沒寫調色盤的用特效自己的顏色。
BLACK_RED = ["#000000", "#16020a", "#4a0810", "#8a1018", "#d01c28", "#ff5a50", "#ffc0b0", "#ffffff"]
EFFECTS2 = {
    # 瞬身:人影一閃、縮成一條線、散成光點(留在原地);另一頭光點聚成人影(出現的位置)。原點在腳底
    "vanish": dict(id="arcane/blink-out", opts={"palette": GRAY}, start=9, stride=2, max_frames=9, speed=1.7),
    "appear": dict(id="arcane/blink-in", opts={"palette": GRAY}, start=6, stride=2, max_frames=9, speed=1.7),
    # 咒力炸開:一團白光、兩圈往外擴的光環、表面爬著電弧。原點在中心
    "blast": dict(id="explosions/plasma-explosion", opts={"palette": GRAY, "accent": GRAY}, stride=2, max_frames=10, speed=1.3),
    # 兵器相擊的十字閃光與金色火花:虎杖的格檔反擊
    "parry": dict(id="impacts/parry", anchor="centroid", stride=2, max_frames=9, speed=1.3),
    # 黑閃:黑紅色的閃電從命中點炸開。原點在地面,閃電的中心在上方約 30 像素
    "blackflash": dict(id="lightning/thunderclap", opts={"palette": BLACK_RED, "sparks": ["#ffffff", "#ff8a80", "#d01c28", "#4a0810"]},
                       anchor=(0, -30), start=3, max_frames=13, speed=0.9),
    # 黑閃的全螢幕衝擊畫面:黑白集中線,遊戲裡放大到蓋滿畫面
    "impact": dict(id="impacts/impact-frame", anchor=(0, 0), max_frames=7),
    # 往前擴散的聲波:乙骨的「飛走吧!」。自己寫的。原點在嘴邊
    "shout": dict(id="anifight/shout", opts={"palette": GRAY}),
    # 地上裂開的漩渦:式神從影子裡出來。原點在地面
    "summon": dict(id="spawn/spawn-portal", opts={"palette": GRAY}, start=5, stride=2, max_frames=12, speed=1.5),
    # 撞上右邊的牆:一道閃光、往回噴的火花與碎石。對齊點在撞擊處
    "wallhit": dict(id="impacts/bullet-impact", anchor="centroid", max_frames=14),
    # 一閃:十字光、一圈光環、往外飛的星點。換武器、瞬身出現、進入狀態時用
    "flash": dict(id="pickups/collect-burst", opts={"palette": GRAY}, anchor="centroid", stride=2, max_frames=9, speed=1.4),
    # 咒力湧出:一顆光球炸成光環與往外飛的符文。原點在腳底
    "powerup": dict(id="arcane/mana-burst", opts={"palette": GRAY}, start=6, stride=2, max_frames=12, speed=1.2),
    # 由下往上的一擊加上漫畫式的命中星芒:通用大招。原點在出招的人腳底
    "uppercut": dict(id="melee/uppercut", opts={"palette": GRAY}, max_frames=16, speed=1.1),
    # 罩住全身的光球(循環):無下限。原點在腳底
    "barrier": dict(id="holy/divine-shield", opts={"palette": ICE}, stride=3, loop=True),
}

# 兩張圖各自不能超過 2048 像素高(舊手機的貼圖上限)。第一張還有空位,把這幾個搬過去排;
# 遊戲是用名字找特效,不管它在哪一張圖裡
for _name in ("blast", "parry", "flash"):
    EFFECTS[_name] = EFFECTS2.pop(_name)

# 召喚物:都是自己寫的(tools/pixelfx_custom/),朝右。原點:鷲在身體中心,玉犬與里香在腳底(里香是尾巴底端)
SUMMONS = {
    "owl": dict(id="anifight/owl", speed=1.25, loop=True),
    "owl_dive": dict(id="anifight/owl", opts={"mode": "dive"}, max_frames=2, speed=1.5, loop=True),
    "dog": dict(id="anifight/dog", loop=True),
    "dog_run": dict(id="anifight/dog", opts={"mode": "run"}, speed=1.8, loop=True),
    "rika": dict(id="anifight/rika", loop=True),
    # 揮爪:舉手、抓下去各一格
    "rika_strike": dict(id="anifight/rika", opts={"mode": "strike"}, stride=4, speed=3.0),
    # 純愛砲的光束(循環):自己寫的。圖長 440 像素,對齊點在光束正中間;遊戲裡橫向拉到判定的長度
    "beam": dict(id="anifight/love-beam", anchor=(220, 0), loop=True),
}

# 領域展開的背景,整片鋪在場景後面,所以用比較大的顯示倍率。只有會開領域的角色才載入。
BLOOD = ["#0a0204", "#2a060c", "#5a0c16", "#961824", "#d42c34", "#ff6a5a", "#ffc0a8", "#ffffff"]

# 無量空處:滿天星斗,正中一個吸著光的黑洞
DOMAIN_VOID = {
    "sky": dict(id="weather/shooting-stars", anchor=(0, -90), stride=7, loop=True),
    "hole": dict(id="shadow/black-hole", opts={"palette": ICE}, anchor="centroid", stride=4, loop=True),
}

# 伏魔御廚子:血色的日蝕,地上一圈骷髏繞著火焰轉
DOMAIN_SHRINE = {
    "eclipse": dict(id="shadow/eclipse", opts={"palette": BLOOD, "pearl": ["#7a1c20", "#e0564a", "#ffc4b0", "#fff4ea"]},
                    stride=4, loop=True),
    "skulls": dict(id="shadow/necro-skulls", opts={"palette": BLOOD, "bone": ["#1c0a0c", "#5a2c2c", "#a06a60", "#e0c0b0", "#fff0e6"]},
                   stride=3, loop=True),
}

# 火影忍者系列角色用的特效(目前是波風湊)。苦無、螺旋丸、印記都是自己寫的,用自己的顏色
NARUTO = {
    # 手上的螺旋丸與大招收尾的大型螺旋丸(循環):同一個特效算兩種大小,對齊點是球心
    "rasengan": dict(id="anifight/rasengan", opts={"radius": 11}, loop=True),
    "rasengan_big": dict(id="anifight/rasengan", opts={"radius": 30}, loop=True),
    # 三叉苦無(循環),朝右,對齊點在握柄與刀身交接處:飛行中、插在定點上
    "kunai": dict(id="anifight/kunai", loop=True),
    "kunai_still": dict(id="anifight/kunai", opts={"mode": "still"}, stride=2, loop=True),
    # 飛雷神的術式印記(循環):貼在被標記的對手身上。對齊點是印記中心
    "mark": dict(id="anifight/thunder-mark", loop=True),
    # 影分身出現、消失時的一團白煙。原點在腳底
    "poof": dict(id="spawn/poof", stride=2, max_frames=12, speed=1.5),
}

# 輸出資料夾(assets 底下) -> 裡面有哪些動畫、遊戲裡的顯示倍率
SETS = {
    "effects_fx": dict(effects=EFFECTS, scale=3.0),
    "effects2_fx": dict(effects=EFFECTS2, scale=3.0),
    "summons_fx": dict(effects=SUMMONS, scale=3.0),
    "domain_void_fx": dict(effects=DOMAIN_VOID, scale=4.0),
    "domain_shrine_fx": dict(effects=DOMAIN_SHRINE, scale=4.0),
    "naruto_fx": dict(effects=NARUTO, scale=3.0),
}


def sync_custom() -> None:
    """把自己寫的特效原始碼複製進 pixelfx(它只認 src/fx/<分類>/ 底下的檔案)。"""
    for source in CUSTOM.glob("*/*.js"):
        target = PIXELFX / "src" / "fx" / source.parent.name / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def render(effect_id: str, opts: dict, out_dir: pathlib.Path) -> tuple[Image.Image, dict]:
    """呼叫 pixelfx 把一個特效算成 sprite sheet,回傳圖與它的說明資料。"""
    command = ["node", str(PIXELFX / "tools" / "render.mjs"), effect_id, "--sheet", "--no-actor", "--out", str(out_dir)]
    if opts:
        command += ["--opts", json.dumps(opts)]
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise SystemExit(f"pixelfx 算圖失敗({effect_id}):\n{result.stdout}\n{result.stderr}")
    name = effect_id.split("/")[-1]
    folder = out_dir / effect_id
    return Image.open(folder / f"{name}.png").convert("RGBA"), json.loads((folder / f"{name}.json").read_text(encoding="utf-8"))


def frames_of(sheet: Image.Image, info: dict) -> list[np.ndarray]:
    meta = info["meta"]["pixelfx"]
    width, height = meta["frameSize"]
    columns = meta["columns"]
    pixels = np.asarray(sheet)
    return [pixels[(i // columns) * height:(i // columns + 1) * height, (i % columns) * width:(i % columns + 1) * width]
            for i in range(meta["frames"])]


def build(name: str, spec: dict, out_dir: pathlib.Path) -> dict:
    sheet, info = render(spec["id"], spec.get("opts", {}), out_dir)
    meta = info["meta"]["pixelfx"]
    frames = frames_of(sheet, info)[spec.get("start", 0):]
    frames = frames[: spec.get("max_frames") and spec["max_frames"] * spec.get("stride", 1)]
    frames = [f.copy() for f in frames[:: spec.get("stride", 1)]]
    anchor = spec.get("anchor", (0, 0))
    if anchor == "centroid":
        # 圖案的重心:越不透明的像素越重,零星的火星影響不大
        weight = np.sum([f[:, :, 3].astype(float) for f in frames], axis=0)
        ys, xs = np.mgrid[0:weight.shape[0], 0:weight.shape[1]]
        ax, ay = int(round((xs * weight).sum() / weight.sum())), int(round((ys * weight).sum() / weight.sum()))
    else:
        ax, ay = meta["pivot"][0] + anchor[0], meta["pivot"][1] + anchor[1]
    if "keep_radius" in spec:
        ys, xs = np.mgrid[0:frames[0].shape[0], 0:frames[0].shape[1]]
        outside = (xs - ax) ** 2 + (ys - ay) ** 2 > spec["keep_radius"] ** 2
        for frame in frames:
            frame[outside] = 0
    # 只存所有格子裡有畫東西的範圍(寬高取偶數),另外記下這個範圍的中心離對齊點多遠;
    # 遊戲載入時用這個偏移把對齊點擺回正中央,不必在圖上留空白
    used = np.any(np.stack([f[:, :, 3] > 0 for f in frames]), axis=0)
    ys, xs = np.nonzero(used)
    x0, y0 = int(xs.min()), int(ys.min())
    w, h = int(xs.max()) + 1 - x0, int(ys.max()) + 1 - y0
    w, h = w + w % 2, h + h % 2
    cells = []
    for frame in frames:
        cell = np.zeros((h, w, 4), dtype=np.uint8)
        part = frame[y0:y0 + h, x0:x0 + w]
        cell[:part.shape[0], :part.shape[1]] = part
        cells.append(cell)
    fps = meta["fps"] / spec.get("stride", 1) * spec.get("speed", 1.0)
    return {"name": name, "cells": cells, "fps": round(fps, 2), "loop": bool(spec.get("loop", False)),
            "size": (w, h), "offset": [x0 + w // 2 - ax, y0 + h // 2 - ay], "source": spec["id"]}


def main() -> None:
    if not (PIXELFX / "tools" / "render.mjs").exists():
        raise SystemExit(f"找不到 pixelfx:{PIXELFX}")
    sync_custom()
    preview = None
    if "--preview" in sys.argv:
        preview = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1])
        preview.mkdir(parents=True, exist_ok=True)
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else list(SETS)
    for folder in only:
        export(ASSETS / folder, SETS[folder]["effects"], SETS[folder]["scale"], preview / f"{folder}.png" if preview else None)


def export(output: pathlib.Path, effects: dict, scale: float, preview: pathlib.Path | None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        built = [build(name, spec, pathlib.Path(temp)) for name, spec in effects.items()]
    # 每個特效排成幾列,整張圖的寬度不超過 MAX_WIDTH(舊一點的手機貼圖上限是 2048)
    for b in built:
        b["columns"] = max(MAX_WIDTH // b["size"][0], 1)
        b["rows"] = -(-len(b["cells"]) // b["columns"])
    width = max(min(len(b["cells"]), b["columns"]) * b["size"][0] for b in built)
    height = sum(b["rows"] * b["size"][1] for b in built)
    sheet = np.zeros((height, width, 4), dtype=np.uint8)
    data = {"scale": scale, "foot_offset": 0, "align": "center", "animations": {}}
    y = 0
    for b in built:
        w, h = b["size"]
        rects = []
        for index, cell in enumerate(b["cells"]):
            cx, cy = (index % b["columns"]) * w, y + (index // b["columns"]) * h
            sheet[cy:cy + h, cx:cx + w] = cell
            rects.append([cx, cy, w, h])
        data["animations"][b["name"]] = {"fps": b["fps"], "loop": b["loop"], "offset": b["offset"], "frames": rects}
        print(f"{b['name']:8s} {b['source']:24s} {len(b['cells']):3d} 格  {w}x{h}  {b['fps']:.1f} fps  {len(b['cells']) / b['fps']:.2f} 秒")
        y += b["rows"] * h
    Image.fromarray(sheet, "RGBA").save(output / "sheet.png")
    (output / "sheet.json").write_text(json.dumps(data, indent="\t"), encoding="utf-8", newline="\n")
    print(f"輸出到 {output.relative_to(ROOT)}:{width}x{height}")
    if height > 2048:
        print("  注意:圖高超過 2048,舊一點的手機載不了這麼大的貼圖;把幾個特效搬到別張圖")
    if preview is not None:
        back = Image.new("RGBA", (width, height), (36, 38, 62, 255))
        back.alpha_composite(Image.fromarray(sheet, "RGBA"))
        back.save(preview)
        print(f"預覽:{preview}")


if __name__ == "__main__":
    main()
