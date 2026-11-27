# 建築物試做素模 #001

最後修改日期指本次交付的模型檔，採臺北日期。表內外觀與剖視圖攝於 2026-10-29，農宅與宿舍後續的門窗修訂請以 Blender、GLB 與獨立試走場景為準。

這四棟建築供 CD-GBB v1.2 基礎版審查。可直接檢視 Blender 的逐件來源與匯出模型，也可在 Godot 的獨立地台試走，查看家具擺位、屋面支承和門窗開合。

| 建築 | 模型最後修改日期 | 屋面與室內 | 全棟三角面 | 模型與六視圖 |
|---|---|---|---:|---|
| BLD-01 農宅 | 2026-11-23 | 土坯農宅置有灶、桌凳與床，木梁與分板天花承接土覆屋面。固定玻璃木格窗可擊破，破窗後可翻越。 | 9,498 | [Blender](bld_01.blend) · [GLB](bld_01.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_01_overview.png) |
| BLD-02 糧庫 | 2026-10-29 | 農產暫存與搬運空間。糧袋靠側邊堆放，墊板與手車旁留中央搬運通道，室內可見金屬屋片和支承。 | 23,480 | [Blender](bld_02.blend) · [GLB](bld_02.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_02_overview.png) |
| BLD-07 修理棚 | 2026-10-29 | 開放式木構工作棚。金屬屋片由檁條承托，棚內的工作桌與輪架供修理農車和輪具。 | 7,650 | [Blender](bld_07.blend) · [GLB](bld_07.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_07_overview.png) |
| BLD-15 員工宿舍 | 2026-11-23 | 員工共用起居空間與寢室由內門相連。金屬屋面下可見木椽與分板底層，活動門窗均可雙向推開。 | 14,784 | [Blender](bld_15.blend) · [GLB](bld_15.glb) · [外觀與剖視](../../../docs/image/modeling-tests/cd-gbb-buildings/2026-10-29-envelope-r005/bld_15_overview.png) |

## 查看與試走

在專案的 Godot 編輯器中開啟 [review.tscn](../../../tools/cd_gbb_buildings/envelope_r005/review.tscn)，按 F6 執行目前場景。F1 前往農宅，F2 修理棚，F3 糧庫，F4 宿舍。WASD 移動、空白鍵跳躍、E 操作活動門窗，左鍵擊破農宅固定窗，靠近破口按住 W 並按空白鍵翻越、F5 切換視角、Esc 釋放滑鼠。修理棚是開放式建築。眼高 1.60 公尺，預設垂直視角 70°。

在 Blender 開啟個別來源時，預設可見的網格對應遊戲使用的合批模型。要檢查木板、家具或屋架的個別接合，可在大綱檢視器搜尋並顯示以 `author_` 開頭的作者零件，同時隱藏重疊的合批模型。GLB 包含頂點色及所需貼圖。農宅四扇固定窗的玻璃與內格為獨立拆件，外框與窗臺屬於屋殼。農宅四扇門、宿舍三扇門及三扇窗支援雙面操作，開扇朝操作者的另一側。Blender 的門窗父件記錄開合類型與轉軸，Godot 以組裝資料載入碰撞及行為。

## 來源與重建

四份 `bld_XX_assembly.json` 保存逐件材料、尺寸、局部坐標、旋轉、工作區域、碰撞及活動扇轉軸。`model_path` 指向本版 GLB。`baseline_model` 僅標示歷史來源。各棟的 `bld_XX_metrics.json` 提供構件與全棟統計。`plaster_normal.png` 為泥灰表面法線貼圖。

在儲存庫根目錄用 Blender 5.2.2 LTS 執行以下指令，會在指定的新目錄產生四棟的 Blender 檔和 GLB。可加上 `--building 15` 單獨產生宿舍。個別編修後的 Blender 檔可另存；修改組裝資料再重建，則以該份組裝資料為準。

```sh
blender --background --factory-startup --python-exit-code 1 --python blender/cd_gbb/build_baseline.py -- --out /tmp/cd-gbb-rebuild
```

## 驗證範圍

下列檢查可在儲存庫根目錄使用 Godot 4.7.2 無視窗執行。第一項讀回模型、材質、碰撞與轉軸，取樣通路及使用家具的位置。第二項測試九扇門從兩側開啟、朝遠離操作者的方向旋轉，以及角色膠囊穿門。第三項用專案子彈擊破農宅四窗，再以專案牛仔測試雙向翻越，另檢查宿舍窗兩側開合與掃掠受阻。

```sh
godot --headless --path . --script tools/cd_gbb_buildings/envelope_r005/check_buildings.gd
godot --headless --path . --script tools/cd_gbb_buildings/envelope_r005/check_doors.gd
godot --headless --path . --script tools/cd_gbb_buildings/envelope_r005/check_windows.gd
```

四棟共 55,412 個三角面、207 個網格，GLB 合計 4,930,800 位元組。這些是模型規模統計。正式地圖整合、地形接坡、破壞系統、多人同步、打包與效能實測仍待進行。本目錄使用 `.gdignore` 隔離來源資產，審查場景在專案目錄直接讀取 GLB 和組裝資料。

審查場景在牛仔起跳前檢查路徑是否穿過完整固定窗。接入正式地圖時也要串接這項判斷，並確認實際地形落差及多人破窗狀態。
