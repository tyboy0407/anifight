"""用程式畫出招式特效的點陣圖,輸出成 assets/effects/sheet.png 與 sheet.json。

格式和角色素材一樣(見 scripts/sprite_sheet_loader.gd),遊戲裡用 Fighter._spawn_effect() 播放。
全部畫成白色到灰色,顏色由遊戲在播放時染上去,所以同一張圖可以給不同招式共用。

在專案資料夾執行(需要 numpy 與 Pillow):

    python tools/make_effects.py

想換成自己畫的特效:直接改 sheet.png / sheet.json 即可,動畫名稱要保留。
"""

from __future__ import annotations

import json
import math
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "effects"
CELL = 48
CENTER = (CELL - 1) / 2.0

_ys, _xs = np.mgrid[0:CELL, 0:CELL].astype(float)


def blank() -> np.ndarray:
    """一格空白畫面:每個像素是 (亮度, 不透明度)。"""
    return np.zeros((CELL, CELL, 2))


def paint(frame: np.ndarray, mask: np.ndarray, light: float, alpha: float = 1.0) -> None:
    frame[mask, 0] = light
    frame[mask, 1] = alpha


def disc(cx: float, cy: float, radius: float) -> np.ndarray:
    return (_xs - cx) ** 2 + (_ys - cy) ** 2 <= radius ** 2


def dither(mask: np.ndarray, keep: int) -> np.ndarray:
    """棋盤狀地挖掉一部分像素,用來表現「快要散掉」的半透明感。keep 越小挖越多。"""
    pattern = ((_xs.astype(int) + _ys.astype(int) * 2) % 4) < keep
    return mask & pattern


def slash() -> list[np.ndarray]:
    """往右揮的弧形刀光:先出現上半、再整道、最後變細消失。"""
    frames = []
    outer_x, radius = 14.0, 22.5
    angle = np.degrees(np.arctan2(_ys - CENTER, _xs - outer_x))
    # (內圓圓心 x, 角度範圍, 亮度, 不透明度)。內圓越靠近外圓,刀光越細
    for inner_x, (low, high), light, alpha in [(7, (-80, 5), 1.0, 1.0), (5, (-80, 80), 1.0, 1.0),
                                               (9, (-55, 80), 0.9, 0.85), (11.5, (-5, 80), 0.8, 0.55)]:
        frame = blank()
        crescent = disc(outer_x, CENTER, radius) & ~disc(inner_x, CENTER, radius) & (angle >= low) & (angle <= high)
        paint(frame, crescent, light * 0.72, alpha)
        # 外緣一條比較亮的線
        edge = crescent & ~disc(outer_x, CENTER, radius - 2)
        paint(frame, edge, light, alpha)
        frames.append(frame)
    return frames


def spark() -> list[np.ndarray]:
    """命中的火花:中心一閃,八道光往外飛。"""
    frames = []
    for near, far, width, core in [(1, 9, 2.2, 6), (5, 16, 1.8, 4), (10, 21, 1.2, 0), (17, 23, 0.9, 0)]:
        frame = blank()
        dx, dy = _xs - CENTER, _ys - CENTER
        dist = np.hypot(dx, dy)
        for k in range(8):
            theta = math.pi / 8 + k * math.pi / 4
            along = dx * math.cos(theta) + dy * math.sin(theta)
            across = np.abs(-dx * math.sin(theta) + dy * math.cos(theta))
            reach = far if k % 2 == 0 else far * 0.7
            paint(frame, (along >= near) & (along <= reach) & (across <= width), 1.0)
        if core:
            paint(frame, np.abs(dx) + np.abs(dy) <= core, 1.0)
            paint(frame, dist <= core * 0.45, 0.85)
        frames.append(frame)
    return frames


def guard() -> list[np.ndarray]:
    """防禦成功:面前一道弧形的盾光,往外擴後碎掉。"""
    frames = []
    for rx, ry, thick, keep in [(9, 19, 3.0, 4), (12, 21, 2.0, 4), (15, 23, 1.5, 2)]:
        frame = blank()
        dx, dy = (_xs - 18) / rx, (_ys - CENTER) / ry
        shell = np.abs(np.hypot(dx, dy) - 1.0) <= thick / rx
        paint(frame, dither(shell & (_xs >= 18), keep), 1.0)
        frames.append(frame)
    return frames


def dust() -> list[np.ndarray]:
    """揚起的沙土:幾團往上飄、越來越大也越來越散的煙。"""
    frames = []
    for step, keep in enumerate([4, 4, 3, 2]):
        frame = blank()
        rise = step * 3.5
        grow = step * 1.6
        for cx, cy, radius, light in [(16, 34, 6, 0.8), (27, 31, 7.5, 1.0), (36, 35, 5.5, 0.7), (23, 38, 5, 0.9)]:
            blob = disc(cx + (cx - 24) * step * 0.12, cy - rise, radius + grow)
            paint(frame, dither(blob, keep), light)
        frames.append(frame)
    return frames


def orb() -> list[np.ndarray]:
    """咒力光球:外圈暗、裡面亮,左上有高光,大小微微脈動。"""
    frames = []
    for radius in [14, 15.5, 14, 12.5]:
        frame = blank()
        paint(frame, disc(CENTER, CENTER, radius), 0.5)
        paint(frame, disc(CENTER, CENTER, radius - 2.5), 0.75)
        paint(frame, disc(CENTER - 2, CENTER - 2, radius - 6), 0.92)
        paint(frame, disc(CENTER - 5, CENTER - 5, 3), 1.0)
        frames.append(frame)
    return frames


def ring() -> list[np.ndarray]:
    """往外擴散的衝擊波。"""
    frames = []
    for radius, thick, keep in [(8, 4.0, 4), (14, 3.0, 4), (19, 2.2, 3), (22.5, 1.4, 2)]:
        frame = blank()
        band = np.abs(np.hypot(_xs - CENTER, _ys - CENTER) - radius) <= thick / 2.0
        paint(frame, dither(band, keep), 1.0)
        frames.append(frame)
    return frames


# 動畫名稱 -> (畫法, 每秒格數, 是否循環)
ANIMATIONS = {
    "slash": (slash, 22, False),
    "spark": (spark, 24, False),
    "guard": (guard, 18, False),
    "dust": (dust, 12, False),
    "orb": (orb, 10, True),
    "ring": (ring, 18, False),
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rows = [(name, make()) for name, (make, _fps, _loop) in ANIMATIONS.items()]
    columns = max(len(frames) for _name, frames in rows)
    sheet = np.zeros((CELL * len(rows), CELL * columns, 4), dtype=np.uint8)
    data = {"scale": 3.0, "foot_offset": 0, "animations": {}}
    for row, (name, frames) in enumerate(rows):
        _make, fps, loop = ANIMATIONS[name]
        rects = []
        for column, frame in enumerate(frames):
            y, x = row * CELL, column * CELL
            value = np.round(frame[:, :, 0] * 255).astype(np.uint8)
            sheet[y:y + CELL, x:x + CELL, 0] = value
            sheet[y:y + CELL, x:x + CELL, 1] = value
            sheet[y:y + CELL, x:x + CELL, 2] = value
            sheet[y:y + CELL, x:x + CELL, 3] = np.round(frame[:, :, 1] * 255).astype(np.uint8)
            rects.append([x, y, CELL, CELL])
        data["animations"][name] = {"fps": fps, "loop": loop, "frames": rects}
    Image.fromarray(sheet, "RGBA").save(OUTPUT / "sheet.png")
    (OUTPUT / "sheet.json").write_text(json.dumps(data, indent="\t"), encoding="utf-8")
    print(f"輸出 {len(rows)} 種特效到 {OUTPUT.relative_to(ROOT)}:{sheet.shape[1]}x{sheet.shape[0]}")


if __name__ == "__main__":
    main()
