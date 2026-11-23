# CD-GBB 四棟建築基礎版

這四棟建築供 CD-GBB v1.2 基礎版審查。可直接檢視 Blender 的逐件來源與匯出模型，也可在 Godot 的獨立地台試走，查看家具擺位、屋面支承和門窗開合。

| 建築 | 屋面與室內 | 全棟三角面 | 模型與六視圖 |
|---|---|---:|---|
| BLD-01 農宅 | 土覆屋面、木梁與分板天花，內有起居、炊事及睡眠陳設 | 9,594 | [Blender](bld_01.blend) · [GLB](bld_01.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_01_overview.png) |
| BLD-02 糧庫 | 露出金屬屋片背面與支承，袋堆、墊板、手車共用搬運通道 | 23,480 | [Blender](bld_02.blend) · [GLB](bld_02.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_02_overview.png) |
| BLD-07 修理棚 | 開放式木棚，金屬屋片、檁條、修理桌與輪架皆可辨認 | 7,650 | [Blender](bld_07.blend) · [GLB](bld_07.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_07_overview.png) |
| BLD-15 員工宿舍 | 金屬屋面下有木椽與分板底層，內門連接生活空間與寢室 | 14,736 | [Blender](bld_15.blend) · [GLB](bld_15.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_15_overview.png) |

## 查看與試走

在專案的 Godot 編輯器中開啟 [review.tscn](../../../tools/cd_gbb_buildings/envelope_r005/review.tscn)，按 F6 執行目前場景。F1 前往農宅，F2 修理棚，F3 糧庫，F4 宿舍。WASD 移動、空白鍵跳躍、E 操作門窗、F5 切換視角、Esc 釋放滑鼠。修理棚是開放式建築。眼高 1.60 公尺，預設垂直視角 70°。

在 Blender 開啟個別來源時，預設可見的網格對應遊戲使用的合批模型。要檢查木板、家具或屋架的個別接合，可在大綱檢視器搜尋並顯示以 `author_` 開頭的作者零件，同時隱藏重疊的合批模型。GLB 包含頂點色及所需貼圖。門窗開合與碰撞由 Godot 審查場景載入。

## 來源與重建

四份 `bld_XX_assembly.json` 保存逐件材料、尺寸、局部坐標、旋轉、工作區域、碰撞及活動扇轉軸。`model_path` 指向本版 GLB。`baseline_model` 僅標示歷史來源。各棟的 `bld_XX_metrics.json` 提供構件與全棟統計。`plaster_normal.png` 為泥灰表面法線貼圖。

在儲存庫根目錄用 Blender 5.2.2 LTS 執行以下指令，會在指定的新目錄產生四棟的 Blender 檔和 GLB。可加上 `--building 15` 單獨產生宿舍。個別編修後的 Blender 檔可另存；修改組裝資料再重建，則以該份組裝資料為準。

```sh
blender --background --factory-startup --python-exit-code 1 --python blender/cd_gbb/build_baseline.py -- --out /tmp/cd-gbb-rebuild
```

## 驗證範圍

下列檢查可在儲存庫根目錄使用 Godot 4.7.2 無視窗執行。第一項讀回模型、材質、碰撞與轉軸，取樣通路及使用家具的位置。第二項測試九扇門從兩側開啟、朝遠離操作者的方向旋轉，以及角色膠囊穿門。結果印在終端。

```sh
godot --headless --path . --script tools/cd_gbb_buildings/envelope_r005/check_buildings.gd
godot --headless --path . --script tools/cd_gbb_buildings/envelope_r005/check_doors.gd
```

四棟共 55,460 個三角面、211 個網格，GLB 合計 4,938,432 位元組。這些是模型規模統計。正式地圖整合、地形接坡、破壞系統、多人同步、打包與效能實測仍待進行。本目錄使用 `.gdignore` 隔離來源資產，審查場景在專案目錄直接讀取 GLB 和組裝資料。
