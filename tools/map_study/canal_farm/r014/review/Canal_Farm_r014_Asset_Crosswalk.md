# 灌渠農莊 A v3.1 r014｜建築與農務資產對照

適用於 r014 本機送審候選。以 `levels/farm_style/full_map.gd` 的接入順序、場景、配方、原件及共用目錄 v0.3 為依據。[逐處來源及 SHA-256](Canal_Farm_r014_Building_Manifest.json) 涵蓋二十處房舍與作業棚，以及中橋、院牆與護岸兩列。表中的雜湊追蹤本次讀回的檔案，提交的逐檔清單由地圖組從正式組裝入口產生。

## 表 1．建築與共用原料

| 範圍 | 目前身分與配置 | 遊戲入口與可編輯來源 |
| --- | --- | --- |
| 二十處房舍、作業棚與兩座追加作業樓 | 沿用各場所在母圖的定位與局部節點鍵。各棟依木構、土坯或混構的實裝配料，保留岩石基腳、木柱梁、板件、門窗及屋面所引用的構件。母圖的農舍與棚站以農莊自身的場所清冊追蹤。 | r001 基底從 `levels/farm_stock_assemblies/rooms.json` 到 `rooms/*.tscn`，r014 經 `levels/farm_stock_groups/install.gd` 安裝。兩座新樓從 `levels/farm_sites/sites.gd` 到 `levels/farm_buildings_r004/{GrainTransfer,WheelShop}.json` 與同名 `author/*.tscn`。各棟增改由同套件 `Extra*.json` 連回作者場景。 |
| 共用建材 | 土坯 MOD-0001、基腳 MOD-0002、柱 MOD-0003、梁 MOD-0004、斜撐 MOD-0005、板及窄條 MOD-0006、鐵皮及折片 MOD-0007。玻璃片是 MOD-0011 的子件，玻璃表面參 MAT-0011。十筆原型來源 GLB 指紋均符合 r014 原料目錄。 | `levels/farm_stock_assemblies/stock/catalog.json` 含尺寸、路徑與來源雜湊。落位與裁切留作者場景，建材方位、拆件與承座留各安裝配方。 |
| 門窗、樓面、屋面與橋板 | 木門及木窗沿用 MOD-0010／0011 家族。封板、開扇、側別及鉸軸依實裝開口；板段與支點以場內鍵追蹤。中橋以獨立橋面／支承組及原母圖接面追蹤。 | `levels/farm_ground_windows/`、`farm_interior_followup/`、`farm_eave_seats/`、`farm_roof_sections/`、`farm_large_sections/`、`farm_loft_sections/`、`farm_shed_envelope_r002/`、`farm_bridge_bearings/`。 |
| 室內家具 | 桌與工作臺比對 PRP-0020，糧袋比對 PRP-0002，土灶比對 PRP-0028。共用長凳、櫥、分格架、夾持架、秤與墨水瓶查本地候選 PRP-0045 至 0050。此範圍以場景實際連回的來源為準。 | `farm_house1_furniture/`、`farm_interior_followup/` 與各棟逐件來源。[家具候選補表](Interior_Asset_Catalog_Addendum_r001.md) 含基準尺度及構造。 |

## 表 2．農車、機具、工具及石砌

| r014 實件 | 編碼判定及需要補登的內容 | 來源與配置 |
| --- | --- | --- |
| 東北糧車、西北棚車與碼頭篷車 | 整車沿用 PRP-0005，輪總成可參 PRP-0035。敞斗和有篷為不同形體候選。車輪、車軸、車轅、板、飛落物、輪楔及每袋的受擊鍵留在場內。兩種整車形體和本次材質搭配仍需正式 V／L 指派。 | `farm_wagon_parts/{farm,wharf}.scn`。敞斗沿用 `NorthwestWagonShed_r002` 與 `HarvestWagon_r001` 同源輪軸及木料；碼頭保留原 `ChockedWagon` 輪軸、篷布及篷弓，以同源木板取代原整塊車斗。原件拆分參 `tools/farm_r011/wagon_recipe.py`、`bake.gd`。原形碎落由 `farm_wagon_parts/fallen.gd` 經 `farm_destruction/fragments.gd` 套用。車木／暗鐵／篷布對應 MAT-0001 或 0003／0002／0009 家族，實際顏色留輸出表面。 |
| 粗布糧袋與料垛 | 滿袋／半袋沿用 PRP-0002，MAT-0009 描述布面家族。貨垛的承座屬場內配方。 | `farm_yard_sections/{FullSack,HalfSack}.scn`、`farm_shed_stock/stock.scn`。 |
| 後場果箱 | 80 個箱位使用 Part048（30 件）與 Part049（50 件）。兩者可比對 PRP-0001，目前仍缺與共用 V00 閉箱或 V01 開蓋配置相同的證據。 | 戶外工作區 `tools/map_study/r009_yard_loads/bake_loads.py` 第 99 至 116 行讀取 `levels/farm_style_buildings/farm_parts.glb` 的 FarmCrates。由 62 個外露箱芯各搭配 12 片附板，再重排為 4 × 5 格、每格四層。遊戲讀取 `farm_yard_loads/{recipes.json,parts.glb}`。 |
| 果場裝車臺週轉箱 | 開口週轉筐與封箱是獨立模型。本輪由世界觀補表登為試玩配置。 | `models/orchard_loading/loading_station.tscn` 引用 `open_crate.glb` 和 `closed_crate.glb`。兩件均可由地圖工作區 `blender/orchard_loading/build.py` 重建。開口筐以木料組裝，封箱取 `models/kits.glb` 的 Crate 調整至同一堆疊外廓。裝車臺木構另查 `farm_loading_sections/stock.json`。 |
| 北田畜力踏床、傳動架與散穀升送 | 場內安裝沿用 GrainTransfer；踏床、輪、皮帶、筒、斗與槽依該樓配方追蹤。柱梁板依共用木料，皮帶實體是機構內部件，MAT-0010 是皮革材質參照。 | `farm_grain_drive/{North,Edits}.json` 與烘製場景。圓鐵軸、輪芯、皮帶由該套件 `stock/` 定義。現行圓軸節點標 MOD-0013；補表 V00 的既定範圍為矩形鐵料，送審紀錄將本件列為機內圓軸並參 MAT-0002，獨立重用時才補形體定義。 |
| 清選樓手搖吊具、篩臺與提斗 | 場內安裝沿用 RegistrationRoom／SeedCleaningLoft。麻繩可對 PRP-0017；吊鉤與滑輪可參 PRP-0018。絞盤、棘爪、托臂及提斗依這個工位的實裝配方追蹤。 | `farm_grain_drive/South.json` 與烘製場景，原吊臂及斗孔出自 `farm_buildings_v31/tower.gd` 及 `farm_buildings_r004/ExtraRegistrationRoom.json`。兩樓的逐件可編輯配方均在 `tools/farm_r011/grain.py`。 |
| 西南田埂石垛、橋旁水車機座 | 人工砌體。石垛 51 件，機座 58 件。可引用 MAT-0005 的石面語義，實際模型材質仍循場景讀值。機座石腳可與 MOD-0002 比對；整個機座還有木枕與鐵座，應給其各自的部位材質說明。r014 使用 `structure_material=brick` 作試玩受擊分組。 | `farm_masonry/parts.glb` 由 `farm_style_buildings/farm_parts.glb` 的 StoneHeap 和 WheelSeat 取件。移除重疊石芯，按接觸面配置承座。母圖保存 `2026-11-26-r014-石砌分件/split_stock.py`。 |
| 橋旁工具與水尺 | 繩可對 PRP-0017，兩個木楔依場內配料追蹤，實體木楔有獨立材料來源時可連回 stock。水尺持續沿水邊原位。 | 繩和楔取自 `farm_style/bridge_details.glb` 的「水尺與水車機座工具」。r014 取出 ToolRope、兩個 ToolWedge，沿用原工具材質，並隨機座受擊。 |

## 送審前的配置與來源標記

1. **配置碼。** 五欄依序記基礎碼、形體、材質搭配、組織、地域。此版外觀採 02 建模＋06 貼圖。02 與 06 是美術方向，正式 V／L 依個別資產的形體及表面定義登錄。三車可先以基礎碼和 r014 配方對照；兩樓機具與原工位同交，跨圖共用需求確立後再議 ASM。
2. **材質與幾何欄位。** `drive_belt.tscn` 目前把 MAT-0010 放在 asset 欄，對照表將它解讀為材質引用。圓軸目前沿掛 MOD-0013，應保留上述場內幾何註記。這兩筆都宜在後續來源整理時改成明確的欄位。其餘 runtime 的 `support_seats`、`ground_anchor` 與耐久類別可照現有接口讀取。
3. **可追溯範圍。** 清單記錄本次原件及組裝版本。敞斗與篷車正式配置碼、後場果箱與共用配置的對應、砌石機座逐部位的共用材質修訂尚待齊備；送審可先引用這份對照與固定雜湊。Windows 安裝與遊戲操作驗收見母圖的 r014 試玩紀錄。
