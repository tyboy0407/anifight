# Anifight

用 Godot 4.7 製作的橫向 2D 格鬥遊戲原型。

線上試玩:https://tyboy0407.github.io/anifight/

手機請橫放。觸控裝置會自動顯示螢幕按鈕,對手由電腦操作。

iPhone 的 Safari 不支援網頁全螢幕。想要沒有網址列的全螢幕畫面,請點 Safari 的分享按鈕,選「加入主畫面」,再從主畫面的圖示開啟。

畫面位置或大小不正常時,在網址後面加上 `?debug=1` 會顯示瀏覽器回報的畫面尺寸,方便排查。

## 觸控操作

左下是左、右方向鍵與防禦鍵;右下是普攻、招式一、招式二、大招(超必殺)、跳、衝刺。

衝刺鍵有三種作用:點一下立刻衝刺(倒地時是快速起身)、按住 1 秒發動幽步、受擊時變成脫出。

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
- `web/shell.html`:網頁版的自訂外殼(畫布大小、手機安全區、禁止縮放)
- `tools/`:臨時素材產生器、切圖工具、字型精簡工具

## 發布網頁版

推送到 `master` 分支後,GitHub Actions(`.github/workflows/deploy.yml`)會自動匯出網頁版並發布到 GitHub Pages,不需要在本機上傳匯出檔。

新增了沒出現過的中文字時,推送前先執行 `python tools/subset_font.py` 更新內建字型。

本機測試網頁版:

```
godot --headless --path . --export-release Web build/web/index.html
python -m http.server 8765 --directory build/web
```

然後開啟 http://localhost:8765 (加上 `?touch=1` 可在電腦上強制顯示觸控按鈕)。
