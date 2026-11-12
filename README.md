# Anifight

用 Godot 4.7 製作的橫向 2D 格鬥遊戲原型。

線上試玩:https://tyboy0407.github.io/anifight/

手機請橫放。觸控裝置會自動顯示螢幕按鈕,對手由電腦操作。

## 鍵盤操作

| 功能 | P1 | P2 |
|---|---|---|
| 移動 | A / D | ← / → |
| 防禦(按住) | S | ↓ |
| 攻擊 | J | 數字鍵盤 1 |
| 跳躍 | K | 數字鍵盤 2 |
| 衝刺、倒地時快速起身 | L | 數字鍵盤 3 |
| 技能 / 技能二 | U / W + U | 數字鍵盤 4 / ↑ + 4 |
| 大招 / 超必殺 | I / S + I | 數字鍵盤 5 / ↓ + 5 |
| 幽步 | S + L | ↓ + 數字鍵盤 3 |
| 受擊脫出 | O | 數字鍵盤 6 |

F1 切換 P2 由電腦或玩家操作,Esc 回選角畫面。

## 專案結構

- `scripts/fighter.gd`:角色的狀態機與共用系統(氣量、連段保護)
- `scripts/characters/`:各角色的專屬招式
- `scripts/touch_controls.gd`:觸控按鈕
- `assets/characters/<角色>/`:角色素材(`sheet.png` + `sheet.json`)
- `tools/`:臨時素材產生器、切圖工具、字型精簡工具、部署腳本

## 發布網頁版

```
powershell -File tools\deploy_web.ps1 -Godot "<Godot 執行檔路徑>"
```

會匯出網頁版並推送到 `gh-pages` 分支。新增了沒出現過的中文字時,先執行 `python tools/subset_font.py` 更新內建字型。
