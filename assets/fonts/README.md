# 內建字型

`NotoSansTC-subset.ttf` 是 Noto Sans TC 的精簡版,只包含遊戲裡實際用到的字,並固定在單一字重。

- 來源:Noto Sans TC(© 2014-2021 Adobe,Reserved Font Name 'Source')
- 授權:SIL Open Font License 1.1 — https://openfontlicense.org
- 版權與授權資訊保留在字型檔內嵌的中繼資料裡

## 重新產生

網頁版沒有系統字型可借用,字型裡沒有的字會顯示成方框。在腳本或場景裡新增了之前沒出現過的中文字之後,要重新執行:

```bash
python tools/subset_font.py
```
