# ranch 地面產製來源

使用專案Godot4.7.2，Blender5.2。來源承接2026-10-10地面試作v5/v8/v9/v10/v12核可方向，交付僅保留選定方法。

## 驗證

```sh
godot --headless --path . --import
godot --headless --path . --script tools/ranch_surface/check.gd
```

## 再產製

`make_decor.py`是12種原創小碎物的可編輯來源，依賴既有`blender/pipeline.py`。無照片貼圖、下載素材或外部生成服務；12網格共240三角面，每件不超48面。已提交GLB對應此來源，不需要先手動建立每株物件。

```sh
"/Applications/OvD Tools/Blender.app/Contents/MacOS/Blender" --background --factory-startup --python tools/ranch_surface/make_decor.py
godot --path . --script tools/ranch_surface/build.gd -- --original-ground --period sunset
```

第二行會開圖形視窗。自動化操作者先依當次使用時段授權執行；需要真GPU讀回MultiMesh資料，headless dummy不能替代。產製完成自動退出；會更新`levels/ranch_surface/`四項預烘焙資源。

`base.gd`按既存道路、房屋、麥田、樹與岩石產生用途遮罩；`decor.gd`用固定種子／來源／通行遮罩／最小間距產生稀疏聚集，再依8m區塊與網格分批；`generator.gd`整合光學、材料過渡、局部接地及磨耗。林屋生活通路與岩／濕地示範區仍有特定座標，並非通用新地圖全自動美術系統。

不要把初始化全部實驗方案的時間當新增遊玩負擔；製作秒數也不包括人工選案與視覺驗收。成本與限制見審核說明。
