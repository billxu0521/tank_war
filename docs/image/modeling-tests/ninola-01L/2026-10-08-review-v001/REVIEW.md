# 01L 腳掌／趾體現況審視 — 2026-10-08

本輪已完成唯讀審視，未執行造型修改。結論：足部整體方向可保留，但三前趾的立體量體與趾根分化值得一次大形調整。K6 v003仍為暫時落地點；沒有新的Approved模型。

## 實際檢查

Blender 5.2.2實際開啟K6，只取01K6_Pedal_Segment_Mass_Reconstruction的evaluated mesh置入暫時場景，未混入歷史Trex/K4/K5/Audit markers。9766 vertices、TrexRig 45 bones；未Save、未Apply/Bake、未改pose／Mesh／weights／keys。01J、K6與K8檔案hash均核對未變，見verification.json。
輸出8張檢視圖；初次Side趾尖碰到畫面邊界，因此另存2張reframed Side／silhouette，不覆寫原圖。正式判斷使用完整reframed側視。
Side／Front／Rear／Top圖使用Z<.70、同側leg faces的顯示裁切；上方開口和切口碎片是檢視結果，不能當作模型缺陷。三分之四與全身圖顯示完整K6原型、沒有face mask。三分之四以一隻近側腳為局部構圖，另一腳可能被畫框裁切。

## 視覺結論與取捨

| 部位／視角 | 現況 | 本區決定 |
|---|---|---|
| 三趾整體，Top／Front | 足段末端形成寬扇面；中心前趾方向可讀、兩側分叉可辨，但趾根大面連成板狀，三條獨立趾體辨識較弱。 | 最高優先：由整體板面改成可辨三趾量體，不先磨每個小趾節。保留基本三叉方向，避免任意增加總腳寬。 |
| Side／front 3/4 | 足段本身厚實；前方趾體較扁長，背側起伏集中在根部階差，往爪尖主要呈直線尖楔。 | 三趾從根到端建立漸收的厚度與背側弧度，並緩和必要的趾根階差。不要整腳等幅加厚。 |
| 趾體→爪 | 尖端辨識清楚，但直線三角形的讀形較強，與concept較有弧度、趾體支撐的爪不一致。 | 次要輪廓問題；先建立趾體，再判斷是否只需有限爪根／背弧調整。獨立每爪精修不作本輪要求。 |
| Rear digit／Rear 3/4 | 根部靠近足段，外形小而尖，後視容易與其他足部輪廓混合。 | 不阻擋前三趾審視；維持RVI-003，不在第一個大形pass全面重塑。不能稱confirmed hallux。 |
| Hock／pedal核心 | 斜向足段、厚度與下方留空仍有用；踝部環帶未解。 | 保留K6方向，踝部RVI-003 DEFERRED；不再重做K8銜接。 |
| Full body | 脚部不需要整體放大才能支持怪獸量體；當前主要問題是局部厚薄與分化。 | 將全身比例當護欄，不把近拍問題放大成全身比例修正。 |

概念一致性：PARTIAL。三趾分叉與怪獸輪廓方向已有基礎；立體趾體、背側弧度與爪的銜接仍不充分。此為外形判断，不宣稱已量測接地壓力或證實解剖錯誤。

參考：使用者五張概念圖、原Concept、download-10的YELLOW（前趾／爪後續工作）。download-13的YELLOW是下小腿，download-15的GREEN是量體占位，不能誤作01L範圍。AI生成圖片不作精確肌肉、趾節數或ROM證據；沿用SOURCES.md的定性參考限制。本輪不提出特定肌肉復原，無需為輪廓審視另行擴充解剖研究。

## 下一個大形方案：01L.1 — Forward Toe Volume Blockout

狀態：已具體提出，未執行。Base=K6 v003獨立工作副本，不承接K8。
主要目標：三前趾從寬扁板面讀成三條有厚度、漸收的趾體；必要連帶目標：趾根由共同足段自然展開，減少突然的背側台階。這兩項合併為一次足部整體blockout。
方法：先以既有evaluated pose、骨架位置和三趾方向定位；用局部外部Mesh量體調整，只有既有拓樸阻礙大形時才提出局部重建。設定區域時分辨趾皮膚、爪與共享root，不將歷史region labels或權重當成精確mask。保留footprint、趾尖／ground anchors、骨架及pose；不得Apply/Bake。若目標必須移動anchor，另明列實際必要變更，不能偷偷移動。
爪暫保留尖端與基本方向；僅在趾體方案確立後考慮必要的爪根／有限背弧調整，不要求整套爪的精修。Rig、原Trex keys／weights、01J與K6原件保持；不做Production整合或weights cleanup。
風險：趾過粗呈球塊、總腳寬擴張、分叉間隙消失、新skin/claw crossing、趾根厚板加劇。不能用整體Smooth掩蓋量體問題。
驗收：Top保留三叉與間隙；Front／3/4能辨三趾厚度；Side有漸收背側輪廓；趾根不形成新增厚塊；全身比例與K6斜向足段／留空保持。完成一次大形試作與多視角比較便停下審核，細節瑕疵登錄RVI，不連續微修。

## 本區暫存與後續

RVI-003：踝環帶／後側mass繼續DEFERRED；rear digit attachment及更細趾節／爪精修保留待回看。三趾量體與趾根為01L.1主提案，不另外新增重複RVI編號。
RVI-002：動態接地、ground/contact及skin/claw工程相容性仍未驗證，不在本次視覺審視關閉。
本區現況審視已到收尾條件：主要問題已排序、保留項與最小修改方案已明列。不是要求每個腳部細節都完美才轉下一區。
下一區仍預計Head／Neck／Jaw（包含下顎），這不構成已開始修改或已審視通過。

同一工具操作與視覺自評，沒有獨立Reviewer；未認證全模型無自交、manifold或動畫。No Commit／Push／PR。Current State只在ninola-workflow/STATE.md更新。

## 檢視證據

### foot_side

![foot_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_side_01K6.png)

### foot_silhouette

![foot_silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_silhouette_01K6.png)

### foot_top

![foot_top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_top_01K6.png)

### foot_front

![foot_front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_01K6.png)

### foot_rear

![foot_rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_01K6.png)

### foot_front_threequarter

![foot_front_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_threequarter_01K6.png)

### foot_rear_threequarter

![foot_rear_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_threequarter_01K6.png)

### full_body_side

![full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/full_body_side_01K6.png)
