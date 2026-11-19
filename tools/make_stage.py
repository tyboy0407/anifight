"""用程式畫出對戰場景的點陣背景,輸出到 assets/stage/。

四層,由遠到近(遊戲裡越遠的層跟著鏡頭移動得越慢,產生景深):
    sky.png     夜空、星星與月亮。固定在畫面上,不跟著鏡頭動。
    far.png     遠山的剪影。可以左右無縫接續。
    mid.png     中景的建築、鳥居與樹。可以左右無縫接續。
    ground.png  地面的石板。可以左右無縫接續。

在專案資料夾執行(需要 numpy 與 Pillow):

    python tools/make_stage.py

想換成自己畫的背景:用同名的圖檔蓋掉即可(大小可以不同,遊戲會依圖檔大小排列)。
"""

from __future__ import annotations

import math
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "assets" / "stage"
rng = np.random.default_rng(7)


def canvas(width: int, height: int) -> np.ndarray:
    return np.zeros((height, width, 4), dtype=np.uint8)


def fill(image: np.ndarray, x: int, y: int, w: int, h: int, color) -> None:
    """畫實心長方形;超出左右邊界的部分會繞到另一側,這樣圖才能無縫接續。"""
    height, width = image.shape[:2]
    rgba = (*color, 255) if len(color) == 3 else color
    for yy in range(max(y, 0), min(y + h, height)):
        for xx in range(x, x + w):
            image[yy, xx % width] = rgba


def save(image: np.ndarray, name: str) -> None:
    Image.fromarray(image, "RGBA").save(OUTPUT / name)
    print(f"{name:11s} {image.shape[1]}x{image.shape[0]}")


def sky() -> np.ndarray:
    width, height = 384, 216
    image = canvas(width, height)
    # 由上到下幾條色帶:深藍 -> 靠近地平線的紫
    bands = [(13, 15, 34), (17, 19, 42), (22, 23, 52), (29, 27, 62), (38, 32, 72), (50, 38, 82), (64, 45, 90)]
    edges = [0, 46, 84, 114, 138, 158, 174, height]
    for index, color in enumerate(bands):
        fill(image, 0, edges[index], width, edges[index + 1] - edges[index], color)
        # 色帶交界用交錯的點過渡
        if index + 1 < len(bands):
            for x in range(0, width, 2):
                image[edges[index + 1] - 1, x + (index % 2)] = (*bands[index + 1], 255)
    # 星星:多數是暗的小點,少數比較亮
    for _ in range(90):
        x, y = int(rng.integers(0, width)), int(rng.integers(0, 150))
        bright = rng.random() < 0.2
        image[y, x] = (235, 235, 255, 255) if bright else (120, 125, 170, 255)
        if bright and rng.random() < 0.5 and 0 < x < width - 1 and 0 < y < height - 1:
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                image[y + dy, x + dx] = (120, 125, 170, 255)
    # 月亮:右上方,帶一圈光暈和幾個坑
    cx, cy, radius = 286, 78, 22  # 放低一點,不要被上方的血條與名字蓋住
    for y in range(height):
        for x in range(width):
            dist = math.hypot(x - cx, y - cy)
            if dist <= radius:
                image[y, x] = (238, 236, 214, 255)
            elif dist <= radius + 5 and (x + y) % 2 == 0:
                image[y, x] = (70, 66, 110, 255)
    for ox, oy, r in [(-8, -6, 5), (6, 3, 4), (-3, 9, 3), (9, -9, 2)]:
        for y in range(cy + oy - r, cy + oy + r + 1):
            for x in range(cx + ox - r, cx + ox + r + 1):
                if math.hypot(x - cx - ox, y - cy - oy) <= r and math.hypot(x - cx, y - cy) <= radius:
                    image[y, x] = (206, 203, 186, 255)
    return image


def far() -> np.ndarray:
    width, height = 320, 110
    image = canvas(width, height)
    back, front = (34, 33, 68), (28, 29, 58)  # 後面那排受月光比較亮,前面那排比較暗
    for x in range(width):
        t = 2 * math.pi * x / width  # 用整數倍頻率的正弦波疊起來,左右兩端自然接得上
        ridge_back = 34 + 20 * math.sin(t + 0.6) + 9 * math.sin(3 * t + 1.9) + 4 * math.sin(7 * t)
        ridge_front = 58 + 14 * math.sin(2 * t + 2.4) + 7 * math.sin(5 * t + 0.4) + 3 * math.sin(11 * t + 1.0)
        fill(image, x, int(ridge_back), 1, height, back)
        fill(image, x, int(ridge_front), 1, height, front)
    return image


def roof(image: np.ndarray, x: int, y: int, w: int, color) -> None:
    """兩端上翹的屋頂:一層比一層寬的橫條。"""
    for row, extra in enumerate([2, 5, 8, 10]):
        fill(image, x - extra, y + row * 2, w + extra * 2, 2, color)
    fill(image, x - 12, y + 5, 3, 2, color)
    fill(image, x + w + 9, y + 5, 3, 2, color)


def hall(image: np.ndarray, x: int, base: int, w: int, floors: int) -> None:
    """一棟多層的木造殿堂,有幾扇亮著的窗。"""
    wall, dark, light = (44, 44, 78), (26, 26, 50), (232, 198, 122)
    top = base
    for floor in range(floors):
        fw = w - floor * 10
        fx = x + floor * 5
        top -= 26
        fill(image, fx, top, fw, 26, wall)
        fill(image, fx, top, 2, 26, dark)
        fill(image, fx + fw - 2, top, 2, 26, dark)
        for wx in range(fx + 7, fx + fw - 10, 12):
            lit = rng.random() < 0.45
            fill(image, wx, top + 9, 6, 9, light if lit else dark)
        top -= 8
        roof(image, fx, top, fw, dark)


def torii(image: np.ndarray, x: int, base: int) -> None:
    red, dark = (150, 52, 60), (104, 36, 46)
    fill(image, x, base - 46, 4, 46, red)
    fill(image, x + 30, base - 46, 4, 46, red)
    fill(image, x - 6, base - 52, 46, 5, red)
    fill(image, x - 8, base - 55, 50, 3, dark)
    fill(image, x - 2, base - 40, 38, 3, dark)


def tree(image: np.ndarray, x: int, base: int, size: int) -> None:
    leaf, shade, trunk = (30, 54, 60), (22, 40, 48), (40, 32, 44)
    fill(image, x - 1, base - size, 3, size, trunk)
    for ox, oy, r in [(0, -size, size // 2 + 4), (-size // 3, -size + 5, size // 2), (size // 3, -size + 6, size // 2)]:
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r:
                    fill(image, x + ox + xx, base + oy + yy, 1, 1, shade if (yy > 0 and xx > -2) else leaf)


def mid() -> np.ndarray:
    width, height = 320, 150
    image = canvas(width, height)
    base = height
    # 遠一點的矮牆,左右貫穿整張圖
    fill(image, 0, base - 22, width, 22, (36, 36, 64))
    fill(image, 0, base - 24, width, 2, (24, 24, 46))
    for x in range(0, width, 16):
        fill(image, x, base - 22, 1, 22, (28, 28, 52))
    tree(image, 22, base - 20, 30)
    hall(image, 60, base - 10, 92, 3)
    tree(image, 172, base - 18, 24)
    torii(image, 204, base - 6)
    tree(image, 268, base - 20, 34)
    tree(image, 300, base - 16, 22)
    return image


def ground() -> np.ndarray:
    width, height = 96, 40
    image = canvas(width, height)
    fill(image, 0, 0, width, height, (62, 56, 76))
    fill(image, 0, 0, width, 2, (112, 104, 128))   # 最上緣受光
    fill(image, 0, 2, width, 1, (84, 78, 100))
    # 石板:三排,隔排錯開半塊;越下面越暗
    rows = [(3, 11, (62, 56, 76)), (14, 12, (54, 49, 68)), (26, 14, (46, 42, 60))]
    for index, (y, h, color) in enumerate(rows):
        fill(image, 0, y, width, h, color)
        fill(image, 0, y + h - 1, width, 1, (34, 31, 46))
        for x in range(12 if index % 2 else 0, width + 24, 24):
            fill(image, x, y, 1, h, (34, 31, 46))
            fill(image, x + 1, y, 1, 1, tuple(min(c + 16, 255) for c in color))
    # 零星的小石子與裂痕
    for _ in range(14):
        x, y = int(rng.integers(0, width)), int(rng.integers(4, height - 2))
        image[y, x] = (38, 35, 50, 255)
    return image


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    save(sky(), "sky.png")
    save(far(), "far.png")
    save(mid(), "mid.png")
    save(ground(), "ground.png")
    print(f"輸出到 {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
