# Ninola 01K Closeout — 2026-10-08

## 最終決策與工作暫停
本文件記錄使用者本次明確決策；優先於封存歷史 manifest 的舊 review_pending 標籤。原 Chat + Work 流程暫停。沒有新造型、Topology Cleanup、Weight Cleanup、Rig 調整、Production Integration 或01L。封存副本不是第二套 canonical checkpoint。

| 狀態 | 真正可編輯模型 | 封存相對路徑 | 後續用途 |
|---|---|---|---|
| 01J | 唯一目前正式 Production Approved | `assets/repository/docs/image/modeling-tests/ninola-global-mass-01J/2026-10-07-v004/ninola_global_mass_01J_approved.blend` | 正式資產與回退基底；保持原樣 |
| 01K.6 | Selected Morphology Candidate，非 Production Approved | `assets/repository/docs/image/modeling-tests/ninola-global-mass-01K6-pedal-mass-reconstruction/2026-10-08-v003/ninola_01K6_pedal_mass_reconstruction.blend` | 未來造型探索的主要起點；從該真實 Mesh 另建工作副本 |
| 01K.7 | Rejected Experiment，外觀退步，不採用 | `assets/repository/docs/image/modeling-tests/ninola-global-mass-01K7-anatomical-integration/2026-10-08-v006/ninola_01K7_anatomical_integration.blend` | 只供失敗分析，不取代或自動混入K6 |

正式來源 canonical repo-relative 路徑見 docs/key_assets.json。01A至01I.1先前核准checkpoint仍是歷史已核准資料；「唯一Production01J」表示目前正式工作基底，並非撤銷早期比例決策。

## 真實模型組織
01J主體 `Trex`，8871 vertices /3047 polygons，15個既有Shape Key blocks（含Basis），骨架 `TrexRig` 45bones。01A pose與完整 `01A_original_pose_basis_json` 保留。
K6主體 `01K6_Pedal_Segment_Mass_Reconstruction`，9766 vertices /5158 triangles；K7主體 `01K7_Anatomical_Transition_Integration`，9886 vertices /5346 triangles。兩者是獨立可編輯local topology原型，非01J的Production Shape Key。原型自身沒有production Shape Keys；保留的原始 `Trex` 上仍有15個原key blocks。K6檔同時含K5、K4A及Trex；K7檔同時含K6等歷史物件。不要把全部可見物件一起當成單一模型。
K6現存檔案多個舊mesh仍為viewport可見、但render隱藏，可能造成重疊。檢視時在temporary/evaluation copy隔離正確物件；不可因此認定K6本體消失或需重新造假模型。

## Current production values
- `01H_HindUpper_Peak_Downshift = 0.8`
- `01I_InterJoint_LowerLimb_Carve = 1.0`
- `01I1_SharedBoundary_Silhouette_Cleanup = 1.0`
- `01J_Foot_Proportion = 1.0`
- `01J_Ground_Contact = 0.8`
其他既有approved keys保留已存值；精確清單在reports/model_inspection.json與REOPEN_INSTRUCTIONS.md。勿將01K／K1／K2研究keys套回production。

## 為什麼保留K6而不採用K7
K6 shaft-normal厚度proximal/middle約+77.58%、distal+73.90%（相對K5）；使用者接受其斜向段厚度比例作為造型方向，不等於工程或Production核准。
K7重建局部hock連接與distal calf分布，維持K6中段厚度；使用者判定外觀變差。歷史Work自評多項PARTIAL，不能覆蓋使用者否決。新增217組strict crossing pairs，踝部環狀硬折、toe-root接合未消除。保留失敗資料，不繼續以K7收尾。

## 未完成事項
RVI-001、RVI-002、RVI-003維持OPEN。優先未完：distal/pedal生物性銜接、ankle/hock與toe-base過渡；原型self-intersections與局部fold；前趾立體量體、趾節與claw arc；後續weight/deformation、animation/grounding驗證。詳OPEN_ISSUES.md。01K階段暫停不等於問題RESOLVED。

## Hard locks
Production01J、Armature、bones、joint centers、bone lengths、hierarchy、rest pose不動。不得以封存或技術PASS擅自Production Integration。前向三趾、rear-digit candidate、claws與ground anchors仍需保護；rear digit不宣稱confirmed anatomical hallux。

## 封存內容／限制
真正73份.blend副本均以Blender5.2.2背景open/evaluate成功，source/copySHA一致；主要assets無linked library、未打包外部image、cache或font依賴。提供完整原始Concept/標註與有用review；未無差別複製所有Render。新三版本Side比較只是唯讀捕捉，無model save。所有既有來源仍在原位，current-review.zip未覆寫。
驗證在同一macOS主機不同封存路徑執行；異OS/實際另一台機器開啟為UNVERIFIED。工程上能讀取與編輯，不代表原型無碰撞或可直接動畫。Git workingtree含未提交資產，單clone該HEAD不足以重現。
