# 灌渠農莊 A v3.1 r014｜環境資產配置對照

**適用於 r014 試玩候選。** 查某件實物時，先看表 1 的配置或表 2 的來源，再用[配置與指紋清單](Canal_Farm_Asset_Configurations_r014.json)核對版本。工程路徑從 Godot 專案根目錄起算。共通身分依[編碼與組成規則 v0.4](https://github.com/billxu0521/tank_war/blob/71b79329769572578f13578b68ab788ccf202e46/docs/worldbuilding/shared/Environment_Asset_Coding_Guide_v0.4.md)與[環境資產目錄 v0.3](https://github.com/billxu0521/tank_war/blob/71b79329769572578f13578b68ab788ccf202e46/docs/worldbuilding/shared/Asset_Catalog_v0.3.json)。本頁補登農莊試玩選用的四組配置，集中目錄的正式收錄另行審定。

## 第 1 頁　可依完整配置取用的實物

**表 1．資產、形體及實際落位**

| r014 配置 | 可辨認的形體與外觀 | 地圖怎麼用 |
|---|---|---|
| 格蘭德河棉白楊 `VEG-0010_V00_L00_NONE_STD` | 高分叉、寬冠，灰褐皮與暖橄欖綠葉。設置高度 8.5 至 11.2 m。 | 西濕渠南岸 5 株。第 02、03 株收窄並錯開冠緣，兩冠間可透天。 |
| 單籽圓柏成樹 `VEG-0011_V00_L00_NONE_STD` | 低分枝、樹冠偏斜，褐皮與灰綠葉。設置高度 5.3 至 6.9 m。原有 VEG-0005 專供 2 至 3 m 低枝檜叢。 | 西北車路外 5 株。每株沿用同一形體配置，旋轉與高度見清單。 |
| 果場封運木箱 `PRP-0001_V02_L03_NONE_STD` | 保留既有木箱的封蓋和斜撐，調整為果筐的堆疊外廓。 | 裝車臺初始場景有 10 只，來源為 `closed_crate.glb`。 |
| 果場開口週轉筐 `PRP-0001_V03_L03_NONE_STD` | 板條側壁、端面提孔、四角堆疊柱。 | 同一裝車臺有 32 只，來源為 `open_crate.glb`。 |

兩種樹均以根頸定位、Y 向上。每株的三段幹與三段冠共用一份程序網格；著色器用 UV.x 辨識兩種幹段及三段樹冠，以頂點色著色。樹冠與樹幹在斷落時沿用相同外觀。兩種樹各有自己的 L00 色盤。所有株位、名義高度及繞 Y 軸的角度（弧度）均在配置清單。乾溝安裝成功是此版場景布樹的執行條件。它屬於地圖地形。

兩款裝車臺箱筐的底面中央為原點，長 0.788、寬 0.686、高 0.475 m。L03 均使用一個帶頂點色的木面，原始表面名為 `Orchard_kit_wood`。既有 V00／V01、L00 均要求獨立的箱板、鐵件分區。兩款果筐另訂形體和搭配，沿用木運輸箱的基礎碼。層位、受擊與堆垛高度由 `models/orchard_loading/stack.gd` 管理。表 1 數量是裝車臺原始場景配置；遊戲進行後可改變。兩樹及兩箱皆無組織圖樣與附加地域調色。裝車臺兩款箱筐可由工程內的 `blender/orchard_loading/build.py`、佈局檔 `models/orchard_loading/layout.json` 與 `models/kits.glb` 重建；封箱取原 Crate 幾何，開筐則以板條程序組成，兩款均取工程色盤。樹形、箱筐與色盤依原專案素材條件使用。

## 第 2 頁　其他實物按用途查找

**表 2．既有家族、地圖組裝與登錄邊界**

| 實物 | 身分與採用範圍 | r014 取用依據 |
|---|---|---|
| 額外堆放的後場果箱 | 配方有 80 只，Part048 用 30 次、Part049 用 50 次。來源為原整垛 FarmCrates，按箱芯取相鄰 12 件板料等構件，再分層堆放。沿用這套局部鍵。與表 1 裝車臺箱筐有不同原型。 | `levels/farm_yard_loads/{recipes.json,parts.glb}`。重建採 `tools/map_study/r009_yard_loads/bake_loads.py` 讀取 `levels/farm_style_buildings/farm_parts.glb` 的 FarmCrates。 |
| 三部農車 | 整車用 PRP-0005 家族。東北工作院和西北棚共用敞車；碼頭用篷車。車輪家族 PRP-0035。兩款整車可依固定場景提交；跨圖選用前補兩者的部位搭配及正式 V／L。 | `levels/farm_wagon_parts/{farm.scn,wharf.scn,install.gd}`。車軸、車斗與承座跟隨整車；落件依同套件 `fallen.gd`。 |
| 北田散穀樓、南岸清選樓 | 北樓畜力升送；南樓人力吊入、清選。兩套機具分屬各樓。皮帶幾何依工位，MAT-0010 指皮革表面。圓鐵軸為機具內部件，家具候選 MOD-0013 V00 只定義矩形鐵料。 | `levels/farm_grain_drive/{North,South,Edits}.json`、同套件的 `baked/` 及 `stock/`。解讀程式內資產欄時依上述界線。 |
| 田埂砌石、橋旁機座與工具 | 西南田埂有 51 塊。橋旁有 58 件機座及 3 件工具（一繩、兩楔）。Heap／Seat／Tool 是拆件鍵。繩可對 PRP-0017；石、木枕、鐵座的表面分別追源，碰撞分類 brick 只說明受擊行為。 | `levels/farm_masonry/{parts.glb,install.gd}`，取自 `farm_style_buildings/farm_parts.glb` 和 `farm_style/bridge_details.glb`（皆在 levels 下）。獨立跨圖選材時補部位材質修訂。 |
| 房舍、橋面、家具與建材 | 場所按農莊的 20 處、28 層定位。十筆建材來源含土坯、石腳、柱、梁、撐、板及屋面，玻璃片屬窗的子件。家具候選 PRP-0045 至 PRP-0050 須連同其補表使用。 | `levels/farm_stock_assemblies/stock/catalog.json` 記原型、尺寸與來源指紋。逐處查 `Canal_Farm_r014_Building_Manifest.json` 及建築對照。 |
| 田地、乾溝、低草、果園、散草與字牌 | 渠岸、乾溝與田埂按地形落位。低草、田間麥與蘆葦依現役程序／散布，未知種屬保留。散草束、木料堆及字牌依各場的配方。字牌上的方向及用途文字留在原牌。 | `levels/farm_north_ditch_trees/ditch.gd`、`levels/farm_environment/`、`levels/farm_yard_loads/`、`levels/farm_world_lettering/`。外觀與採用指紋見戶外對照。 |

### 使用範圍

- **試玩送審**所需的編碼資料已備齊。四組候選配置、其餘家族與場內組裝均可循列出的來源核對。場內路線、對局、角色、動畫與音效由各自系統管理。農莊試玩沿用常規環境資產編號；此版未引用 TST 決鬥場套件。
- **跨圖重用**時，車輛的搭配、後場果箱兩原型的可重用配置、機座各部位的共用材質，以及戶外表中尚待補登的獨立植被與草料，仍需先補入共用目錄。專案物件表管理製作與採用狀態。
- **核對版本**可將清單中的 SHA-256 與相對路徑所指檔案比對。列入指紋的檔案涵蓋本頁主要引用。完整打包依賴及目標平台遊玩驗收由地圖送件項目追蹤。
