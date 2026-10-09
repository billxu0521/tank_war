# 01L.1 v001 — Forward Toe Volume Blockout

2026-10-08。實作已完成；視覺自評PARTIAL、待使用者審核。只有一次大形試作，未追加新造型輪次。01K.6 v003仍為選定落地基準；本結果未提升為Selected或Production。

## 交付與方法

從K6原型另存01L1_Forward_Toe_Volume_Blockout。工作檔：blender/ninola/working/01L1/2026-10-08-v001/ninola_01L1_forward_toe_volume.blend。
SHA-256：7e4792bf471dd6a76b4e44a7ed983e70bc036723b28f266577b4727df48fefd7。

只調整三前趾皮膚量體與靠近趾根的必要輪廓：以本模型三趾方向作路徑參照，逐漸抬高趾背、稍收中段側面，向爪部淡出位移。沒有增加整體腳寬或縱向延長；既有claw geometry全部固定，未另改爪曲率。趾根足段核心邊界保持，避免本輪變成整段足部重建。
範圍使用歷史face provenance與實際位置共同篩選；精確變更及保護索引見edit_mask.json，不將region labels或bone weights當作解剖認證。
206個頂點參照改動（包含同位置重複參照，不等於206個獨立表面點）；內／中／外路徑分配62／69／75，兩腳合計。最大位移0.082306、最大趾背抬升0.081991 Blender scene units；不換算未校準的真實尺度。
9766 vertices／5158 faces保持；沒有拓樸重建，沒有權重改動。沿inverse-bound坐標寫回新原型，不Apply／Bake既有Armature。

## 保護與技術驗證

爪所有材質頂點、sole Z<=.035 sample band、歷史接地anchor／forward pad、rear digit與attachment、pedal shaft共享邊界固定；上述保護點位移為0。足段核心、踝與其餘身體未改；K8表面未混入。
Rig45 bones之head/tail、hierarchy、rest matrices、pose、rig matrix／properties與原Trex geometry／faces／weights／15 keys完整核對一致，重開新檔仍一致。原型weights逐點一致。
本輪未引入相對基底正常面的>90度面方向反轉；近退化面12→12，來源既有問題沒有被解決。inverse-bind顯示誤差約1.34e-7。
01J、K6、K8原檔hash及本輸出hash核對通過；見final_verification.json。這不代表無自交、變形或接地驗收；沒有全模型collision／manifold／animation／Export認證。

## 固定多視角判斷

| 視角 | 結果 |
|---|---|
| Side／silhouette | 前趾背側比K6厚、有漸收量體，原扁平輪廓有所改善；趾根後側峰值仍偏尖，不能稱為自然連續曲線。 |
| Front | 前方趾體厚度增加，但仍連成寬面，三條獨立趾體的辨識沒有充分建立。 |
| Top | 三叉方向及趾尖位置保留；板狀共享大面的問題仍在，收窄不足以改變整體讀形。 |
| Front 3/4 | 起伏更明顯，足段→趾背高差較小，但大三角面仍呈一體楔塊；尚未達到三趾volume主目標。 |
| Rear／rear 3/4 | rear digit與足段保持；趾根背側稜線仍強，沒有解決舊踝環帶。 |
| Full body | 全身比例維持，足部沒有整體放大；局部增厚未改全身主輪廓。 |

Concept matching=PARTIAL。本輪增加了前趾外部肉量，但不是三條立體趾體已完整成形，爪弧也未修改。單純保留拓樸的量體位移不足以消除共享板面；後續若仍需處理，應一次規劃趾根／三趾表面分化，而非連續微調同一批點。

## 本輪收尾

保留01L.1作待審比較稿，K6仍Selected。不自行進行01L.2，也不因結果PARTIAL要求停留本區追求完美。
三趾分化不足與趾根尖峰寫入RVI-003；踝部／rear digit問題繼續DEFERRED；RVI-002動態接地與工程驗收保持OPEN。下一個區域可轉Head／Neck／Jaw，但本輪尚未開始該區檢查或修改。
由同一Codex操作與視覺自評，沒有獨立Reviewer。模型歷程及Current State已更新。Git新工作檔／證據／文件未staged；No Commit／Push／PR。

## 比較證據

下表左側K6，右側01L.1。各視角camera matrix／scale／display mask／resolution一致。Side基底採上一輪reframed完整趾尖視圖；3/4與全身沒有face mask，其他足部視角裁切上方leg faces（切口不可當作模型缺陷）。

### foot_side

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_side_01K6.png) | ![01L.1 foot_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_side_01L1.png) |

### foot_front

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_01K6.png) | ![01L.1 foot_front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_front_01L1.png) |

### foot_top

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_top_01K6.png) | ![01L.1 foot_top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_top_01L1.png) |

### foot_front_threequarter

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_front_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_threequarter_01K6.png) | ![01L.1 foot_front_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_front_threequarter_01L1.png) |

### foot_rear_threequarter

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_rear_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_threequarter_01K6.png) | ![01L.1 foot_rear_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_rear_threequarter_01L1.png) |

### foot_rear

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_01K6.png) | ![01L.1 foot_rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_rear_01L1.png) |

### foot_silhouette

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 foot_silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_silhouette_01K6.png) | ![01L.1 foot_silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_silhouette_01L1.png) |

### full_body_side

| K6 baseline | 01L.1 trial |
|---|---|
| ![K6 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/full_body_side_01K6.png) | ![01L.1 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/full_body_side_01L1.png) |
