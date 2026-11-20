# 來源與授權

這個資料夾的 `sheet.png` 是火影忍者系列角色(目前是波風湊)用的點陣特效:
螺旋丸(大、小兩種)、三叉苦無(飛行中、插在定點上)、飛雷神的術式印記,以及影分身出現時的白煙。

螺旋丸、苦無、術式印記是這個專案自己設計的:原始碼在 `tools/pixelfx_custom/anifight/`
(rasengan.js、kunai.js、thunder-mark.js),用 [pixelfx](https://github.com/patch-gg/pixelfx) v0.3.1
的繪圖工具寫成。白煙是 pixelfx 內建的特效 spawn/poof。
全部由 `tools/import_pixelfx.py` 算圖、裁切後合成一張。

pixelfx 以 MIT 授權釋出(Copyright (c) 2026 Patch;部分程式改寫自 Hugo Duprez 在
[Sprite Fusion](https://www.spritefusion.com/pixel-art-vfx) 公開的點陣特效,MIT 授權)。
授權全文見 `assets/effects_fx/NOTICE.md`。
