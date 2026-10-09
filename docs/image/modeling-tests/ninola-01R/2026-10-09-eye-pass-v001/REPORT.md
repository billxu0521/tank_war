# 01R.2 金色虹膜／黑色豎瞳試作

狀態：獨立 Prototype，待使用者審核；核可 checkpoint 仍為 01R.1 v011。只更替眼球表面，不修改眼眶、頭型、球徑、球心、視軸、Rig 或正式模型。

## 生物依據與設計定位

- Malmström & Kröger (2006) 直接記錄尼羅鱷及侏儒鱷的豎瞳：https://journals.biologists.com/jeb/article/209/1/18/33400/Pupil-shapes-and-lens-optics-in-the-eyes-of
- Nagloo (2016) 的原始學位研究記錄澳洲淡水鱷及灣鱷具有明亮黃色虹膜與狹縫瞳孔：https://api.research-repository.uwa.edu.au/ws/portalfiles/portal/16640334/THESIS_DOCTOR_OF_PHILOSOPHY_NAGLOO_Nicolas_2016.pdf
- Banks et al. (2015) 顯示豎瞳與部分伏擊掠食者及晝夜活動相關；這不是「所有掠食者皆有豎瞳」，更不是大型獸腳類的直接證據：https://pmc.ncbi.nlm.nih.gov/articles/PMC4643806/

結論：金色／黃色虹膜與黑色豎瞳有現生鱷類參考；用在 Ninola 是有生物參考的怪獸化設計選擇，不宣稱為獸腳類確定復原。使用者照片僅作外觀參考，保留原水印，不當貼圖或直接複製皮膚細節。

## 修改與資源

每眼 24 環向分段、146 頂點／288 tri，雙眼 576 tri；較來源增加 288 tri，整體 7007 tri。黑瞳長寬約 5.1:1，兩端收尖；三個接近的金色調與琥珀外緣。虹膜 metallic=0；不自發光、不加密集纖維、無外部貼圖。眼球使用較細分段與平滑法線，周圍粗面保留。

## 實際評估與限制

隔離眼球能清楚讀出金底豎瞳，細節程度適合先看方向。但實裝近圖顯示：既有眼眶与前向視軸令虹膜中央在部分角度被遮，斜向特寫尤其難看清瞳孔。這不是單純換瞳孔形狀就能完全解決；不能以隔離眼球好看宣稱頭部眼神已驗收。

建議先審核配色與瞳孔造型；若接受，再針對眼球的虹膜朝向／露出範圍提出有限方案。眼眶保持，本輪不擅自調整已核可視軸或放大球體。也未新增瞳孔縮放或獨立眼球注視控制。

## 驗證

已重新讀取保存檔：眼球以外所有面座標、材質、平滑旗標與權重完全一致；45骨／Rest Pose／目前Pose／Trex Shape Keys簽章一致。新眼球封閉、三角面朝外、每點head權重1；球面半徑讀回誤差小於2e-6。來源SHA不變。14幅實際模型與隔離眼球Workbench多視角圖，不是概念示意或PBR／遊戲最終光照。

桌面MCP握手 Broken pipe / Not connected，本輪未完成桌面繞看，不重啟或覆寫使用者工作。完整遊戲動態、匯出與PBR尚未驗證。未Commit／Push／PR，未替換Production。
