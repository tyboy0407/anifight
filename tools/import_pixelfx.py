"""把 pixelfx 的特效匯出成遊戲用的 sprite sheet:assets/effects_fx/sheet.png 與 sheet.json。

pixelfx(https://github.com/patch-gg/pixelfx,MIT 授權)是一套用程式畫的點陣特效庫。
這支工具呼叫它的算圖程式,把下面 EFFECTS 列出的特效各算成一張透明底的圖,
再裁切、抽格、對齊,合成一張遊戲讀得懂的圖(格式見 scripts/sprite_sheet_loader.gd)。

    python tools/import_pixelfx.py            # 全部重做
    python tools/import_pixelfx.py --preview  # 另外輸出一張放大的預覽圖,方便檢查

需要:Node 18 以上、numpy、Pillow,以及放在 .claude/pixelfx/ 的 pixelfx 原始碼
(這個資料夾不在版本控制裡;沒有的話要先取得 pixelfx 放進去)。
沒有 pixelfx 也能玩遊戲:assets/effects_fx/ 已經是匯出好的結果。

每個特效的設定:
    id          pixelfx 的特效編號
    opts        傳給特效的選項(調色盤、高度…)
    anchor      對齊點相對於特效原點的位置(點陣圖像素,往右、往下為正)。
                遊戲播放時,對齊點會落在指定的座標上。原點通常是角色的腳底。
    stride      每幾格取一格(減少張數)
    max_frames  只取前面幾格(特效後段多半只剩零星火星)
    speed       播放速度倍率
    keep_radius 只保留對齊點周圍這個半徑內的像素(去掉光球底下的地面反光)
"""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
PIXELFX = ROOT / ".claude" / "pixelfx"
OUTPUT = ROOT / "assets" / "effects_fx"
MAX_WIDTH = 2048

# 灰階調色盤:算出來的圖是黑白的,顏色由遊戲在播放時染上去,同一張圖可以給不同招式共用
GRAY = ["#262626", "#4d4d4d", "#737373", "#999999", "#bfbfbf", "#e6e6e6", "#ffffff"]

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
}


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
    frames = frames_of(sheet, info)[: spec.get("max_frames") and spec["max_frames"] * spec.get("stride", 1)]
    frames = [f.copy() for f in frames[:: spec.get("stride", 1)]]
    ax = meta["pivot"][0] + spec.get("anchor", (0, 0))[0]
    ay = meta["pivot"][1] + spec.get("anchor", (0, 0))[1]
    if "keep_radius" in spec:
        ys, xs = np.mgrid[0:frames[0].shape[0], 0:frames[0].shape[1]]
        outside = (xs - ax) ** 2 + (ys - ay) ** 2 > spec["keep_radius"] ** 2
        for frame in frames:
            frame[outside] = 0
    # 所有格子裡有畫東西的範圍;以對齊點為中心取一個剛好包住的格子
    used = np.any(np.stack([f[:, :, 3] > 0 for f in frames]), axis=0)
    ys, xs = np.nonzero(used)
    half_w = int(max(ax - xs.min(), xs.max() + 1 - ax))
    half_h = int(max(ay - ys.min(), ys.max() + 1 - ay))
    cells = []
    for frame in frames:
        cell = np.zeros((half_h * 2, half_w * 2, 4), dtype=np.uint8)
        # 來源圖中 [ax - half_w, ax + half_w) 的範圍,超出圖邊界的部分留白
        x0, y0 = ax - half_w, ay - half_h
        sx0, sy0 = max(x0, 0), max(y0, 0)
        sx1, sy1 = min(x0 + half_w * 2, frame.shape[1]), min(y0 + half_h * 2, frame.shape[0])
        cell[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = frame[sy0:sy1, sx0:sx1]
        cells.append(cell)
    fps = meta["fps"] / spec.get("stride", 1) * spec.get("speed", 1.0)
    return {"name": name, "cells": cells, "fps": round(fps, 2), "loop": bool(spec.get("loop", False)),
            "size": (half_w * 2, half_h * 2), "source": spec["id"]}


def main() -> None:
    if not (PIXELFX / "tools" / "render.mjs").exists():
        raise SystemExit(f"找不到 pixelfx:{PIXELFX}")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        built = [build(name, spec, pathlib.Path(temp)) for name, spec in EFFECTS.items()]
    # 每個特效排成幾列,整張圖的寬度不超過 MAX_WIDTH(舊一點的手機貼圖上限是 2048)
    for b in built:
        b["columns"] = max(MAX_WIDTH // b["size"][0], 1)
        b["rows"] = -(-len(b["cells"]) // b["columns"])
    width = max(min(len(b["cells"]), b["columns"]) * b["size"][0] for b in built)
    height = sum(b["rows"] * b["size"][1] for b in built)
    sheet = np.zeros((height, width, 4), dtype=np.uint8)
    data = {"scale": 3.0, "foot_offset": 0, "align": "center", "animations": {}}
    y = 0
    for b in built:
        w, h = b["size"]
        rects = []
        for index, cell in enumerate(b["cells"]):
            cx, cy = (index % b["columns"]) * w, y + (index // b["columns"]) * h
            sheet[cy:cy + h, cx:cx + w] = cell
            rects.append([cx, cy, w, h])
        data["animations"][b["name"]] = {"fps": b["fps"], "loop": b["loop"], "frames": rects}
        print(f"{b['name']:8s} {b['source']:24s} {len(b['cells']):3d} 格  {w}x{h}  {b['fps']:.1f} fps  {len(b['cells']) / b['fps']:.2f} 秒")
        y += b["rows"] * h
    Image.fromarray(sheet, "RGBA").save(OUTPUT / "sheet.png")
    (OUTPUT / "sheet.json").write_text(json.dumps(data, indent="\t"), encoding="utf-8", newline="\n")
    print(f"輸出到 {OUTPUT.relative_to(ROOT)}:{width}x{height}")
    if "--preview" in sys.argv:
        back = Image.new("RGBA", (width, height), (36, 38, 62, 255))
        back.alpha_composite(Image.fromarray(sheet, "RGBA"))
        target = pathlib.Path(sys.argv[sys.argv.index("--preview") + 1]) if len(sys.argv) > sys.argv.index("--preview") + 1 else OUTPUT / "preview.png"
        back.save(target)
        print(f"預覽:{target}")


if __name__ == "__main__":
    main()
