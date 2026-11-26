# 灌渠農莊 A v3.1 r014

> r014 已整合進主線（PR #187），`source/`、`prepare.py`、`files.json` 已移除；主遊戲直接開農莊（`main.gd` 的 `FARM_LEVEL`）。下面「重建與進場」是整合前的做法，留作紀錄。

四席試玩候選。農莊也服務周邊農戶。北田樓接收、提升與暫存散穀，南岸秤房分批吊袋清選，果筐在秤房外過磅。地圖有二十處建築與作業設施。第 2 版導覽採 r009 底圖，後續新增的兩處樹群、乾溝與石砌分件可在 r014 實景查看。[農莊導覽](review/Canal_Farm_Guide_r009_Ed02.png)

## 重建與進場

需要 Python 3、Git、Godot 4.7.2，且本機 repository 含共用遊戲基準 `71b79329769572578f13578b68ab788ccf202e46`。在 repository 根目錄執行下列指令，最後一個參數指定一個尚未存在的目錄。

```sh
python3 tools/map_study/canal_farm/r014/prepare.py ../canal-farm-r014
godot --headless --path ../canal-farm-r014 --import
godot --path ../canal-farm-r014
```

輸出專案從 `farm_match.tscn` 進入農莊。一般派對每局從四處抽一個保險箱，抽到發薪房時在櫃臺後室。定點測試可在 repository 根目錄執行下列指令，查看受擊、局部掉件、碰撞與換局結果。

```sh
godot --headless --path ../canal-farm-r014 --script "$PWD/tools/map_study/canal_farm/r014/review/masonry_check.gd" -- "$PWD/../canal-farm-r014-check.json"
```

`files.json` 記錄每個遊戲輸入的來源與 SHA-256。439 個共用檔從上述 Git 基準取用，678 個農莊覆寫檔與新資產在 `source/`。八件角色與武器 GLB 是農莊試玩外觀，以共用模型為原件，削面及色盤腳本在 `authoring/`。該目錄也收錄兩處石砌的分件腳本、後場料垛與果箱的製作腳本，以及十件有指紋的建築原料。舊牧場自測留在共用基準。共用遊戲資產授權見組裝後的 `CREDITS.md` 及原素材授權檔。

## 編碼審查與 PR 附註

兩種成樹與兩種裝車臺果箱已有候選配置。三輛農車沿用 PRP-0005，兩座穀務機具按場內組裝追溯。後場八十只堆箱另有來源。正式共用庫尚待補登的項目見各表。[WB 配置判定](review/Canal_Farm_Asset_Configurations_r014.md) · [建築對照](review/Canal_Farm_r014_Asset_Crosswalk.md) · [戶外對照](review/農莊-r014-戶外資產採用對照.md)

1. 本次採行 02 彩繪木玩具 建模 + 06 色塊切面低多邊形 貼圖，VB/MB待補
2. 水體是否妨礙行走、影響多少，規格未定。
3. 鬆石保持完整但可被打飛、撞傷人計算規格未定及多人同步需注意。
4. 土坯（磚頭）破面、散草、專屬聲塵及各種物件正式耐久待定。
5. 火球規格依然未訂。
6. 高層房屋整體倒塌可再詳細商議。
7. 場景節點歸屬警告：部分可破壞零件在組裝後仍記著原場景。若將組裝後的場景另存，可能漏存零件。兩處石砌的受擊與換局還原已通過測試。
8. 空材質錯誤：Mac 無視窗測試結束時，Godot 查詢材質參數得到空值。日誌未指出是哪個物件，是否影響 Windows 畫面仍待實機確認。

Mac 的 Godot 4.7.2 無視窗複驗通過四處定點受擊、兩次尼諾拉咬擊及換局還原。Windows 實際畫面、真人試走、大量破壞效能及跨機派對仍待驗。
