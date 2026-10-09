# 01L.2 v002 — Toe Definition / Separation Blockout

2026-10-08。使用者核准先讓趾體分化清楚，暫不處理整腳或01K足段比例。完成獨立試作，視覺PARTIAL／待使用者審核；K6仍選定落地基準，L2不是Production或自動Selected。

## 實際範圍

從K6 v003重開，不疊加L1的共享板面加厚。只在三前趾皮膚背側表面建立兩道趾間凹槽及各趾方向的低起伏，使共同寬面更可分辨。
原105個局部皮膚面細分為1680面，共增加873點；總10639 vertices／6733 faces。最後位移102個原頂點參照及513個新參照。最大抬升0.017818、最大凹槽降低0.048915 scene units；不是校準真實尺度。
只有Z向表面量體變化，沒有X／Y比例修正、縮短趾長、改三叉位置或調整01K足段。新點只在舊三角面內細分，其X／Y插值仍位於原表面投影內。原足部XY bounds完全一致，原點XY最大浮點誤差1.79e-7，见refined-v002/reopen_verification.json。
爪、趾尖、sole／ground anchor band、rear digit／attachment、pedal shaft與其他身體固定；保護原點位移0。Rig／Bones／rest／pose／原Trex geometry／weights／15 keys重開核對一致，J／K6／K8／L1 hash未變。
原頂點weights逐點核對一致；新增點使用邊中點weights插值，屬原型暫用權重，未驗收變形。沒有Production整合或weights cleanup。

## 本輪修正紀錄

同輪v001趾間溝過深、邊界舊端點未完整固定，造成尖稜與過強切溝感，視覺未採用。v002補固定原邊界端點、降低溝深、放緩開始位置，另存新檔，沒有覆寫v001。兩版均從K6重開，不累積位移。

## 多視角結果

| 視角 | 判斷 |
|---|---|
| Top | 兩道凹槽把原共享板面分成三條方向性區域，辨識有所改善；仍是連接皮膚表面，不是新開穿透式趾間空隙。 |
| Front 3/4 | 趾間量體層次比K6／L1清楚；根部仍偏共同寬面，局部稜線仍硬，不能宣稱三條趾體已完整建立。 |
| Front | 趾背起伏有所增加，但爪與前端分叉本身未變；近端細碎面仍影響自然讀形。 |
| Side／silhouette | 足部長度、斜向足段與留空保留；沒有L1的整片加厚。趾背局部仍有折線。 |
| Rear／rear 3/4 | 後趾及踝維持；本輪不解既有踝環帶或rear-root問題。 |
| Full body | 外部比例保持，本輪只改局部趾背讀形；比例不協調的成因未在這輪驗證或修正。 |

評價：趾體方向與表面分界改善，完整趾根／三趾體量體分化仍PARTIAL。不是把凹槽或更密拓樸當作解剖正確的證明。v002保留供使用者審核；不自行擴大到比例縮放或追加新pass。

## 技術限制

没有相對正常基底面的新增>90度面反轉；來源近退化面仍12個。這不代表無自交或動畫合格。
局部細分與未細分保留面交界有非一致拓樸（T接點）；界面點位固定於原幾何邊、原flat-shading重複參照保留。這是可編輯Morphology Prototype，未完成Production manifold／拓樸清理；新插值weights、deformation／keys／Export另行驗收。不以 technical PASS 自動採用。
同一Codex操作與視覺自評，沒有獨立Reviewer。build／mask／reopen／hash／camera記錄見refined-v002目錄。

## RVI與收尾

RVI-003保持OPEN：局部硬稜、共同趾根與後趾／踝問題保留。比例議題單列其下，包括整腳偏大、01K肢段偏小或二者相對比例；目前原因未確定，依使用者決定DEFERRED。全身區域審視收尾再比較，不預設只縮腳。
01J Approved、K6 Selected不變；L2待審。Canonical State／Asset Index／模型log已更新；No Commit／Push／PR。

## 固定視角比較

K6與L2 camera matrix／scale／display mask／resolution核對一致；局部裁切的上方開口不是模型缺陷，三分之四／全身為完整原型。Side採K6 reframed版本。

### foot_top

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_top_01K6.png) | ![L2 foot_top](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_top_01L2.png) |

### foot_front_threequarter

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_front_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_threequarter_01K6.png) | ![L2 foot_front_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_front_threequarter_01L2.png) |

### foot_front

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_front_01K6.png) | ![L2 foot_front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_front_01L2.png) |

### foot_side

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_side_01K6.png) | ![L2 foot_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_side_01L2.png) |

### foot_rear_threequarter

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_rear_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_threequarter_01K6.png) | ![L2 foot_rear_threequarter](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_rear_threequarter_01L2.png) |

### foot_rear

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/foot_rear_01K6.png) | ![L2 foot_rear](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_rear_01L2.png) |

### foot_silhouette

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 foot_silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/reframed/foot_silhouette_01K6.png) | ![L2 foot_silhouette](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/foot_silhouette_01L2.png) |

### full_body_side

| K6 baseline | 01L.2 v002 |
|---|---|
| ![K6 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/full_body_side_01K6.png) | ![L2 full_body_side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v002/refined-v002/captures/full_body_side_01L2.png) |
