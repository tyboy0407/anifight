# 來源與授權

這個資料夾的 `sheet.png` 是宇智波佐助用的點陣特效:千鳥(手上的雷電)、千鳥命中的電擊、
千鳥雷槍、豪火球、燃燒狀態的火、麒麟蓄力時的雷雲、龍形的落雷,
以及大蛇之力的白蛇(蛇咬的蛇身與蛇頭、蛇籠地上的小白蛇、纏在人身上的白蛇)。

千鳥、雷槍、燃燒、麒麟、白蛇是這個專案自己設計的:原始碼在 `tools/pixelfx_custom/anifight/`
(chidori.js、lightning-spear.js、burn.js、kirin.js、snakes.js),用 [pixelfx](https://github.com/patch-gg/pixelfx) v0.3.1
的繪圖工具寫成(閃電用的是 pixelfx 的 lightning 工具)。
電擊、火球、雷雲是 pixelfx 內建的特效:lightning/zap-hit、fire/fireball、lightning/storm-cloud。
全部由 `tools/import_pixelfx.py` 算圖、裁切後合成一張。

pixelfx 以 MIT 授權釋出(Copyright (c) 2026 Patch;部分程式改寫自 Hugo Duprez 在
[Sprite Fusion](https://www.spritefusion.com/pixel-art-vfx) 公開的點陣特效,MIT 授權)。
授權全文見 `assets/effects_fx/NOTICE.md`。
