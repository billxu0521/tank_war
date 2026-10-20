# Worldbuilding 世界觀與場景設計

## Worldbuilding Background 世界觀背景設定

[WBP v1.5 討險人世界觀背景設定企劃](WBP/WBP_main_theme1_CD_v1.5.md)涵蓋「討險人、財寶、異常」的共通架構，並展開「牛仔與恐龍」主題，供背景故事、地圖場所與後續設計參照。文件內仍標為候選的名稱與地域，依原文狀態保留。

[Word 核可原稿](WBP/WBP_main_theme1_CD_v1.5.docx)供編修與原始排版參照；Markdown 為同版全文文字轉存，方便搜尋、引用與檢視文字差異。修訂時須核對兩份內容及版本。

## Map Documents 地圖文件

| 版本 | 用途與範圍 | 閱讀版 |
|---|---|---|
| [CD-GBB v1.2：基礎版](maps/CD-GBB/CD_GBB_Map_Brief_v1.2.md) | 巨骨盆地與石化林的地圖概述、配置及製作規格。保留中央巨骨採掘場，建築依道路、地勢與院落安排坐落。 | [HTML](maps/CD-GBB/CD_GBB_Map_Brief_v1.2.html) · [PDF](maps/CD-GBB/CD_GBB_Map_Brief_v1.2.pdf) |
| [CD-GBB v1.2-TST：含決鬥場的測試修改版](maps/CD-GBB/CD_GBB_Map_Brief_v1.2-TST.md) | 以基礎版為底，保留採掘坑深度，移除巨骨及跨坑棧道，置入坑底決鬥場與四側接道。共用的周邊建築坐落及開口與基礎版一致。 | [HTML](maps/CD-GBB/CD_GBB_Map_Brief_v1.2-TST.html) · [PDF](maps/CD-GBB/CD_GBB_Map_Brief_v1.2-TST.pdf) |

兩版分開保存；TST 是內部測試用途的變體，不取代基礎版。圖面、製作規格及空間資料須使用同一版本。此處交付設計文件與配置資料；模型、材質及遊戲內驗證依後續製作流程完成。

## Shared Documents 共通文件

| 文件 | 負責的內容 | 與其他文件的關係 |
|---|---|---|
| [編碼與組成規則 v0.4](shared/Environment_Asset_Coding_Guide_v0.4.md) · [HTML](shared/Environment_Asset_Coding_Guide_v0.4.html) | **如何識別與組成。** 定義分類、穩定 ID、形體變體、材質搭配、客製與地域欄位，以及場所引用。 | 目錄依這套規則登錄；製作與交接時沿用相同識別。 |
| [環境資產製作目錄 v0.3](shared/Environment_Asset_Catalog_v0.3.md) · [HTML](shared/Environment_Asset_Catalog_v0.3.html) | **目前有哪些製作項目。** 列出 112 個常規製作單位、5 個內部測試項目、形體與材質配置、組織客製鍵及組合。 | 將規則落成可查閱的項目；地圖引用其中的資產與配置，指定落點及使用條件。登錄不代表模型已完成。 |
| [環境資產製作與交接準則 v0.3](shared/Environment_Asset_Production_Guide_v0.3.md) · [HTML](shared/Environment_Asset_Production_Guide_v0.3.html) | **如何製作、交付與驗證。** 定義拆件、接面、模型與材質分工、來源、匯出、交接及檢核要求。 | 製作者依地圖與目錄確定工作範圍，再用本準則完成可接續製作的成果。 |

三份文件分工互補，可分別修訂；不是彼此的新版或替代品。它們適用於跨地圖的環境資產工作，CD-GBB 文件則記錄本圖的空間、配置與特定要求。共通文件目前保留 1.0 前版號，作為團隊共同審閱與完善的規則。

建議先讀所需的地圖版本，建立場景概念；選件與估算查製作目錄，新增或重用資產時查編碼規則，開工至交付依製作與交接準則。

## Formats and Data 格式與資料

- Markdown 可直接在 GitHub 閱讀；HTML 為固定頁碼閱讀版，請下載後用瀏覽器開啟。地圖另附同頁碼 PDF。
- `pages.json` 保存分頁文字；`CD_GBB_Spatial_Data_*.json` 保存相應地圖的座標、朝向、開口與地形資料；TST 地圖另有 `CD_GBB_Test_Kit_v1.2-TST.json`。
- `shared/Asset_Catalog_v0.3.json` 為共通目錄資料；`shared/Test_Assembly_Layout_v0.1.json` 為可跨圖引用的測試組合局部配置。測試組合本身與它在 GBB 的落點分開管理。
- 圖檔位於 `docs/image/worldbuilding` 下的對應版本目錄；下載文件集時請保留相對目錄結構，讓跨文件與圖片引用保持有效。

## Editorial Records 編修紀錄

[2026-10-19 編修紀錄](editorial/Publication_Revision_Record_2026-10-19.md)為獨立選讀資料，保存整理決定與修訂來由。地圖及共通規則的使用不以閱讀編修紀錄為前提。
