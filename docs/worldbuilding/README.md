# 世界觀與地圖文件

## Worldbuilding Background 世界觀背景設定

[WBP v1.5 討險人世界觀背景設定企劃](WBP/WBP_main_theme1_CD_v1.5.md)涵蓋「討險人、財寶、異常」的共通架構，並展開「牛仔與恐龍」主題，供背景故事、地圖場所與後續設計參照。文件內仍標為候選的名稱與地域，依原文狀態保留。

[Word 核可原稿](WBP/WBP_main_theme1_CD_v1.5.docx)供編修與原始排版參照；Markdown 為同版全文文字轉存，方便搜尋、引用與檢視文字差異。修訂時須核對兩份內容及版本。

## 地圖

| 文件 | 用途 |
|---|---|
| [CD-GBB v1.2 基礎版](maps/CD-GBB/CD_GBB_Map_Brief_v1.2.md) | 巨骨盆地與石化林的地圖配置、圖像、建築及戶外場所規格。 |
| [CD-GBB v1.2-TST 測試修改版](maps/CD-GBB/CD_GBB_Map_Brief_v1.2-TST.md) | 保留採掘坑深度，移除中央巨骨與跨坑棧道，置入坑底決鬥場。供內部測試，不取代基礎版。 |

## 共通資產文件

| 文件 | 用途 |
|---|---|
| [編碼與組成規則 v0.4](shared/Environment_Asset_Coding_Guide_v0.4.md) | 資產 ID、形體與材質搭配、組織與地域客製、組合及配置引用。 |
| [環境資產製作目錄 v0.3](shared/Environment_Asset_Catalog_v0.3.md) | 112 個常規製作單位及 5 個內部測試項目的形態、尺度、配置與材料定義。登錄不代表模型已完成。 |

《環境資產製作與交接準則》已廢止，不再作為本文件集的製作前置或驗收依據。專案另有的來源保護、必要驗證與發布權限仍依現行規範。

## 配置資料與圖像

- [基礎版空間資料](maps/CD-GBB/CD_GBB_Spatial_Data_v1.2.json)與[測試版空間資料](maps/CD-GBB/CD_GBB_Spatial_Data_v1.2-TST.json)：座標、朝向、開口、地形、路徑及環境配置。
- [資產目錄資料](shared/Asset_Catalog_v0.3.json)：資產、形體、搭配與組合的結構化定義。
- [跨圖測試組合](shared/Test_Assembly_Layout_v0.1.json)與[GBB 測試版落點](maps/CD-GBB/CD_GBB_Test_Kit_v1.2-TST.json)：組合局部配置與本圖放置方式分開管理。
- 地圖正文直接引用 `docs/image/worldbuilding/CD-GBB-v1.2/` 與 `CD-GBB-v1.2-TST/` 的俯視、斜視、側視及局部圖。下載文件時保留相對目錄結構；局部 SVG 為可編輯圖源，PNG 為正文圖像。

地圖的場所與配置依相應版本；資產的跨圖識別依編碼規則與目錄。模型、引擎通行／碰撞、效能與對戰驗證依後續實作確認。
