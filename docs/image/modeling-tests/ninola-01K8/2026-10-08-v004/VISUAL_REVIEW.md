# 01K.8 v004 — Hock Mass Continuity 試作審核

交付結果：PARTIAL / pending user review。已執行使用者核准的01K.8局部試作，不能宣稱已完成解剖合理化，也不取代01K.6 Selected Candidate。

## 本輪變更與保護

從01K.6 v003另建01K8_Hock_Mass_Continuity，隔離歷史Mesh顯示。僅重建distal transition／hock transition／ankle collar表面；保留proximal boundary、斜向pedal核心厚度、其餘原點位與三前趾／rear digit／claw核心。
移除492面、建立744面／288點，總10054 vertices／5410 triangles。來源未使用點保留供追溯，不代表已完成production cleanup。新表面以邊界weights插值在既有pose顯示；這是原型暫用資料，尚未通過變形或Production蒙皮驗收。

重開檢查Rig的bone hierarchy／rest matrices／pose、原Trex geometry／weights／15 keys一致。原01J／K6 hash及63件已匯入Archive檔案均未變；五份概念圖來源與副本hash一致。新表面無近退化面／內部edge winding衝突；168條幾何接邊各有兩面、方向相反。這是局部幾何檢查，不是全模型manifold／self-intersection／動畫／Export認證。

## 多視角結果

| 檢查 | 實際判斷 |
|---|---|
| Side／silhouette | 原hock凸緣減少，下小腿較直接延伸至斜向足段；彎點仍清楚，留空保留。仍存在急彎及密集細長面。 |
| Front | 踝前側黑色橫向收束仍明顯，視覺像分段接頭；本輪不足以解決。不能僅凭亮度認定穿插或反面。 |
| Rear | 過渡較長，但下段仍呈柱狀／塊狀，未達自然的方向性軟組織分布。 |
| Front／rear three-quarter | 小腿→足段連續性有局部改善；細長三角面與折線節奏過密，仍有機械接合感。 |
| Top | 足段核心和趾根展開保留；toe-base寬扁楔形沒有改善。 |
| Full body | 全身比例與近端量體保留；本輪改善局部，未重塑整個後肢肌肉。 |
| Rear digit | anchor與核心保全，本輪不重塑；其根部擁擠問題仍OPEN。 |

Concept matching=PARTIAL。五圖提供厚實近端後肢、水平怪獸量體與遠端收束的設計意圖，但不是正交校準或精確肌肉資料。本輪遠端過渡有所延長，正／背面仍未达到連續、有方向性的肌肉→肌腱外形。不能把表面loft或通過hash當成生物合理性證明。解剖資料及推論限制見../2026-10-08-v001/references/SOURCES.md。

## Iteration history

v001保存後重開驗證程序失敗，未採納；v002固定拓樸位移造成細窄fold；v003限制位移減少面方向反轉但環帶仍在，未採納。v004改局部過渡表面重建，接縫檢查通過，視覺仍PARTIAL。各版本保留於工作／證據目錄，不視為新Approved checkpoint。

## 下一個合理調整（提案，未執行）

維持01K.8範圍，優先處理前側收束帶與後側面流：以v004為比較稿，重新設計局部非均勻截面，使前側較貼骨、後外側支撐逐步收束；避免整圈等幅膨脹。先以大面blockout確認正／背／側／三分之四輪廓，再處理細長面，保留K6足段核心厚度及留空。若v004不獲接受，回K6重開，不累積其不良表面。

風險：抹平hock、垂直粗柱、填滿留空、新fold或穿插。驗收：固定8視圖比較、前側無突兀環帶、後側方向性連續、側面hock辨識與留空保留、趾／爪／anchor及Rig鎖保持。動態蒙皮／keys／Export另行授權，01L未開始。

本輪由同一Codex操作與視覺自評，未獨立Reviewer。RVI-001／002／003保持OPEN。01J Approved／K6 Selected／K7 Rejected不變。Git新資產與文件untracked，沒有stage／Commit／Push／PR。完成本輪後停止等待使用者審核。

## 固定相機比較

K6與K8相機matrix／scale／顯示mask逐視圖一致，見comparison_verification.json。Side／Front／Rear／Top為局部face mask顯示，非模型刪面；Full body與三分之四為完整原型，歷史mesh均隔離。

### side

| K6 base | K8 v004 trial |
|---|---|
| ![K6 side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/side_01K6.png) | ![K8 side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/side_01K8.png) |

### front

| K6 base | K8 v004 trial |
|---|---|
| ![K6 front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/front_01K6.png) | ![K8 front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/front_01K8.png) |

### rear

| K6 base | K8 v004 trial |
|---|---|
| ![K6 rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/rear_01K6.png) | ![K8 rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/rear_01K8.png) |

### top

| K6 base | K8 v004 trial |
|---|---|
| ![K6 top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/top_01K6.png) | ![K8 top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/top_01K8.png) |

### front_threequarter_closeup

| K6 base | K8 v004 trial |
|---|---|
| ![K6 front_threequarter_closeup](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/unmasked/front_threequarter_closeup_01K6.png) | ![K8 front_threequarter_closeup](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/front_threequarter_closeup_01K8.png) |

### rear_threequarter_closeup

| K6 base | K8 v004 trial |
|---|---|
| ![K6 rear_threequarter_closeup](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/unmasked/rear_threequarter_closeup_01K6.png) | ![K8 rear_threequarter_closeup](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/rear_threequarter_closeup_01K8.png) |

### silhouette

| K6 base | K8 v004 trial |
|---|---|
| ![K6 silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/silhouette_01K6.png) | ![K8 silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/silhouette_01K8.png) |

### full_body_side

| K6 base | K8 v004 trial |
|---|---|
| ![K6 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-fresh-audit/2026-10-08-v001/full_body_side_01K6.png) | ![K8 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01K8/2026-10-08-v004/captures/full_body_side_01K8.png) |
