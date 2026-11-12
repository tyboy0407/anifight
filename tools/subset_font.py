"""產生遊戲內建的中文字型:從 Noto Sans TC 取出遊戲實際用到的字,做成精簡版。

網頁版沒有系統字型可以借用,所以中文字必須跟著遊戲一起打包。整套 Noto Sans TC
有 11 MB,這裡只留用到的字,檔案會小很多,手機載入比較快。

在腳本或場景裡新增了之前沒出現過的中文字之後,要重新執行一次(在專案資料夾):

    python tools/subset_font.py

來源字型預設使用 Windows 11 內建的 Noto Sans TC(SIL Open Font License 1.1)。
需要 fontTools(pip install fonttools)。
"""

from __future__ import annotations

import argparse
import pathlib
import string
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = pathlib.Path(r"C:\Windows\Fonts\NotoSansTC-VF.ttf")
OUTPUT = ROOT / "assets" / "fonts" / "NotoSansTC-subset.ttf"
SCAN_PATTERNS = ["scripts/**/*.gd", "scenes/**/*.tscn"]
WEIGHT = 500
# 不論有沒有出現在程式裡都保留的字:英數、常用標點、方向與符號
ALWAYS_INCLUDE = (
    string.ascii_letters
    + string.digits
    + string.punctuation
    + " "
    + "\u3000、。,:;!?「」『』()…—·%+-×"
    + "↑↓←→◀▶▲▼"
)


def collect_characters() -> set[str]:
    characters = set(ALWAYS_INCLUDE)
    for pattern in SCAN_PATTERNS:
        for path in ROOT.glob(pattern):
            text = path.read_text(encoding="utf-8")
            characters.update(ch for ch in text if ord(ch) > 0x7F and not ch.isspace())
    return characters


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=pathlib.Path, default=DEFAULT_SOURCE, help="來源字型檔")
    args = parser.parse_args()
    if not args.source.exists():
        print(f"找不到來源字型:{args.source}", file=sys.stderr)
        return 1

    characters = collect_characters()
    font = TTFont(args.source)
    if "fvar" in font:
        # 可變字型:固定成單一字重,檔案更小
        font = instancer.instantiateVariableFont(font, {"wght": WEIGHT})

    supported = set(font.getBestCmap())
    missing = sorted(ch for ch in characters if ord(ch) not in supported)

    options = subset.Options()
    options.name_IDs = ["*"]  # 保留字型內嵌的版權與授權資訊
    options.name_languages = ["*"]
    options.layout_features = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(ch) for ch in characters])
    subsetter.subset(font)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUTPUT)
    size_kb = OUTPUT.stat().st_size / 1024
    cjk = sum(1 for ch in characters if ord(ch) >= 0x2E80)
    print(f"輸出 {OUTPUT.relative_to(ROOT)}:{len(characters)} 個字元(其中中文 {cjk} 個),{size_kb:.0f} KB")
    if missing:
        print("來源字型沒有這些字元,遊戲中會顯示成方框:" + " ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
