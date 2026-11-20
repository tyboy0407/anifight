# 來源與授權

這個資料夾的 `sheet.png` 是第二組招式特效(第一組在 `assets/effects_fx/`,排滿了才分成兩張),
用 [pixelfx](https://github.com/patch-gg/pixelfx) v0.3.1 算出來,由 `tools/import_pixelfx.py` 裁切、抽格後合成一張。

使用到的特效:arcane/blink-out、arcane/blink-in、lightning/thunderclap、impacts/impact-frame、
spawn/spawn-portal、impacts/bullet-impact、arcane/mana-burst、melee/uppercut、holy/divine-shield。

另外有一個這個專案自己寫的特效:往前擴散的聲波(`tools/pixelfx_custom/anifight/shout.js`),
同樣用 pixelfx 的繪圖工具寫成。

pixelfx 以 MIT 授權釋出(Copyright (c) 2026 Patch;部分程式改寫自 Hugo Duprez 在
[Sprite Fusion](https://www.spritefusion.com/pixel-art-vfx) 公開的點陣特效,MIT 授權)。
授權全文見 `assets/effects_fx/NOTICE.md`。
