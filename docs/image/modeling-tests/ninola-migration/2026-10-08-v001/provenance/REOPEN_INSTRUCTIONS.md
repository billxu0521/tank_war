# 重開與接手說明

## 軟體與驗證範圍
使用 Blender **5.2.2 LTS**。本次 73 份 Blender 封存副本均已在背景模式成功開啟及讀取 Mesh。主要模型沒有未打包外部貼圖、Linked Libraries、字型或快取依賴。Render Result / Viewer Node 是暫時顯示資料，不是缺失的貼圖。
來源主機曾啟用 BlenderMCP；一般 Mesh、Armature、Shape Keys 使用 Blender 原生資料，沒有發現必須依靠該 addon 才能載入的資產。實際另一台電腦、其他 OS 與無 addon 環境仍標記 **UNVERIFIED**。

## 選擇正確的模型
先讀 HANDOFF.md 與 docs/key_assets.json。所有 active archive_path 均相對於解壓後根目錄；assets/repository 保留原儲存庫子路徑。歷史文件中的原機器路徑只作 provenance，不是新主機必要目錄。

| 檔案索引 | 正確 Object | 用途 |
|---|---|---|
| 01J | Trex | 唯一目前正式 Production Approved |
| 01K6 | 01K6_Pedal_Segment_Mass_Reconstruction | 未來 Morphology 工作起点 |
| 01K7 | 01K7_Anatomical_Transition_Integration | 不採用的歷史實驗，不能作後續 base |
| 01K4_A | Ninola_01K4_A | 歷史選定方向 |
| 01K5 | 01K5_MultiView_Morphology_Revision | 歷史多視角修正版 |

以 File → Open 開啟索引指定的實際 .blend。各檔均含 TrexRig。Outliner 的 Collections、各 Object 名稱與 visibility flags 可查 reports/model_inspection.json。
K6 檔同時包含 K5、K4 A、原始 Trex；數個舊 mesh 的 viewport 仍可見，雖已隱藏於 render，可能造成重疊。請在 **temporary inspection copy** 用 Local View / Outliner 隔離正確 K6 物件，必要時顯示 TrexRig；不得直接覆寫正式 checkpoint 或封存 master。
K7 包含被隱藏的 K6 物件，但接手應優先開啟獨立 K6 檔，避免誤將 K7 視為基底。
大量隱藏的 Audit joint ... 是檢視標記 Mesh，不是額外骨骼。真正 TrexRig 有 45 bones，不要把標記加入 creature mesh。

## 既有 Shape Keys 與 pose
選取 Trex → Object Data Properties → Shape Keys。原始 Trex 保留 15 blocks；K4 A / K5 / K6 / K7 原型本體沒有這些 production Shape Keys，不能從其無 key 推論歷史資料遺失。

目前正式值：
- Basis = 1；01B_Thorax_Mass = 1
- 01C_Pelvis_TailRoot_Mass = 1；01C1_TailRoot_Transition = 1
- 01D_Thigh_Mass_Distribution = 1；01E_LowerLeg_Taper = 1
- 01F_Thigh_Integration = 1；01F1_HipThigh_Bridge_Strong = 1
- 01G_HindLimb_Silhouette_Carve = 1；01G3_LowerLeg_Bulge_Carve = 1
- 01H_HindUpper_Peak_Downshift = 0.8
- 01I_InterJoint_LowerLimb_Carve = 1
- 01I1_SharedBoundary_Silhouette_Cleanup = 1
- 01J_Foot_Proportion = 1；01J_Ground_Contact = 0.8

本次只是讀取，不重新設定這些值。TrexRig custom property 中完整 01A_original_pose_basis_json 保留。不得改 rest pose、目前 pose 或 bones。
未來獲准新工作時，從 K6 **另存新工作副本**。原型頂點是 inverse-bound rest coordinates，透過 Armature modifier 顯示目前姿態；原始 Edit Mode 坐標可能與 posed 顯示不同。不要 Apply / Bake 來消除這個差異。

## 重現 Review Views
提供 docs/tools/review_capture.py。此工具唯讀開啟正確封存模型、evaluated mesh，建立暫時 Scene 輸出圖片，**沒有 Save Blender、Shape Key / Pose / geometry 修改**。必須輸出至新的 evaluation 目錄，不覆寫原 review。

```sh
blender -b -t 2 --python /path/to/Ninola_01K_Closeout_2026-10-08/docs/tools/review_capture.py -- --model 01K6 --views side,silhouette,full_body_side,front,rear,top,front_threequarter,rear_threequarter --output /path/to/new-evaluation-images
```

請將 blender 換成目的機器實際的 Blender 5.2 執行檔。工具以自身位置定位解壓根目錄，支援 01J / 01K6 / 01K7，拒絕覆寫既有 capture。
共同相機以 archived K6 bbox 為基準：Side scale 2.45、中心 (0, 0.3, 0.55)；Front / Rear / Top scale 2.85；3/4 lens 70mm。精確 matrix、scale、lighting 與 display mask 同時寫入 capture_settings JSON。
本次已重新驗證三模型的 Side / silhouette / full_body_side。其餘 helper views 尚未在本次重新執行；既有全部 multi-view 圖與原 capture_settings 已封存。足部檢視的 face display mask 僅移除上方遮擋，不改 mesh；完整比例請用 full-body views。

## 歷史腳本與後續限制
reports/session-scripts 與 reports/source-records 內的歷史 builder / renderer 可能使用 /Users/...、/private/tmp 或原始路徑，**未在新環境重跑，UNVERIFIED**。不能盲目執行，更不能為了接手先重建模型。真正 .blend 已封存，不需要用 PNG 反推。
本次不授權 Production Integration、Weight / Topology Cleanup、01L 或任何新 Pass。接手後先確認 OPEN_ISSUES，尤其 provisional weights、crossings、protected digits / ground anchors 與不可修改的骨架。
