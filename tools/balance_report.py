"""整理 tools/balance_sim.gd 的輸出:每個角色的勝率、平均剩餘血量,以及兩兩對戰的勝率表。

    python tools/balance_report.py 輸出檔1.txt 輸出檔2.txt ...
"""

from __future__ import annotations

import collections
import pathlib
import sys

rounds = []
for path in sys.argv[1:]:
    text = pathlib.Path(path).read_bytes().decode("utf-8", "ignore").replace("\x00", "")
    for line in text.splitlines():
        parts = line.strip().lstrip("﻿").split()
        if len(parts) == 7 and parts[0] == "ROUND":
            rounds.append((parts[1], parts[2], int(parts[3]), float(parts[4]), float(parts[5]), float(parts[6])))

names = sorted({r[0] for r in rounds} | {r[1] for r in rounds})
wins = collections.Counter()
played = collections.Counter()
margin = collections.defaultdict(float)
versus_wins = collections.Counter()
versus_played = collections.Counter()
seconds = 0.0
for first, second, winner, left1, left2, time in rounds:
    seconds += time
    for me, foe, mine, theirs, side in [(first, second, left1, left2, 1), (second, first, left2, left1, 2)]:
        played[me] += 1
        versus_played[(me, foe)] += 1
        margin[me] += mine - theirs
        if winner == side:
            wins[me] += 1
            versus_wins[(me, foe)] += 1

print(f"共 {len(rounds)} 回合,平均每回合 {seconds / max(len(rounds), 1):.0f} 秒")
print(f"{'角色':12s} {'回合':>4s} {'勝率':>6s} {'平均血量差':>10s}")
for name in sorted(names, key=lambda n: -wins[n] / max(played[n], 1)):
    print(f"{name:12s} {played[name]:4d} {100 * wins[name] / max(played[name], 1):5.0f}% {100 * margin[name] / max(played[name], 1):+9.0f}%")
print()
print("對戰勝率(列的角色對上欄的角色):")
print(" " * 12 + "".join(f"{n[:7]:>8s}" for n in names))
for me in names:
    cells = []
    for foe in names:
        if me == foe or not versus_played[(me, foe)]:
            cells.append(f"{'-':>8s}")
        else:
            cells.append(f"{100 * versus_wins[(me, foe)] / versus_played[(me, foe)]:7.0f}%")
    print(f"{me:12s}" + "".join(cells))
