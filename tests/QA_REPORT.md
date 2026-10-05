# 《雨停之前的約定》r2 獨立 QA

結論：PASS，可凍結目前 r2。保留平台與聽審限制。

## 全量重測
- 4,703 項 runtime assertions 全通過：4,676 項獨立測試，另獨立重跑工程師 27 項 crossfade 測試。
- 649 節點、200 條完整合法路徑、7 結局、8 收藏全通過。
- 27 立繪、6 獨立背景、6 CG 的可達性、載入及可見狀態重驗通過。
- once-only effects、選擇條件與 fallback、存讀檔與錯誤格式、快進/自動暫停、收藏持久化、音訊接線全部重跑。

## 縮減內容完整性
- 劇本/art JSON、27 透明立繪、12 背景/CG 原圖、8 音訊，共 49 檔與 r1 SHA256 全相同。
- 字型 1,523 個必要 Unicode：cmap 與 Godot runtime has_char 皆 0 缺漏；全部 glyph outlines 與原字型逐一完全相同。
- 新 family/full/PostScript/CFF 名稱已變更；完整原字型、OFL 及 Adobe copyright 保留。
- 12 張實際 Godot imported texture 均解碼成功、維持 1600×900。與來源 PSNR 41.37–43.31 dB。
- 全 12 圖與原生尺寸細節目視未見顯著壓縮塊或新增條帶；5 張新版 Linux release 截圖中文無缺字方框，人物/CG 清楚、工具列完整。

## 限制
Windows 未實機執行；WebGL2 瀏覽器 gameplay/儲存/音訊政策未驗；無真實觸控硬體；dummy audio 無聽審。時長只是逐完整路徑估算，非人類遊玩實測。

## 指紋
- main.gd: ec262fb17664e8ebb5f502429d03368281c1ce048bd0c04c9c4a48457948231a
- story.json: 16332ab41d2ed649d38eb421a18a8ae8dbb7c8a7b96a8058ab32b635d1b04416

完整證據與逐路字數見 QA_REPORT.json。r1 工程及歷史報告未修改。
