# 01L — Foot / Digit Morphology Review Preparation

2026-10-08 準備紀錄；持續更新的狀態以ninola-workflow/STATE.md為準，本文件不是第二套Current State。

## 暫時落地點

01K.6 v003為01K階段暫時造型落地點及01L起點，非Production Approved。01J v004仍為Approved Production Checkpoint。
K7 Rejected、Archive-only；K8 v004為PARTIAL試作，保留比較，不承接其表面或將其改善混入K6。
Base object：01K6_Pedal_Segment_Mass_Reconstruction。
Base path：blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend。
Base SHA-256：6be6642d8ed8cb2b48a31bd2649cf94457be6073daa59ac6653197dd222f18ca（本次再次核對一致）。
準備階段尚未建立01L修改副本，也未修改Mesh；實作時另存獨立副本，不覆寫K6。

## 交接依據與範圍

HANDOFF.md的未完項目及OPEN_ISSUES.md的Forward toes / claws morphology已列出：前趾立體volume、phalangeal articulation、dorsal curve、claw arc，保留為獨立01L階段。此為封存時的未完成方向，並非已存在的01L模型或完整製作方案。
本次使用者授權選定01K落地點與準備01L。先完成現況審視和大形方案，不把準備授權解讀為任意Mesh、Rig或Production修改。
01L核心是三前趾／爪與足段末端的整體讀形；後趾作附著與比例比較項，不預設其解剖身分。允許後續造型方案提出趾外部Mesh修改；骨架Hard Lock不解除。

## 審視順序與初步問題

| 優先度 | 部位 | 要回答的問題 | 現有證據與限制 |
|---|---|---|---|
| 1 | Pedal distal → toe-base、三趾整體 | 是否由厚足段突然展為扁板？三趾厚度、分叉和間隙能否讀出承重感？ | K6 fresh audit已見寬扁楔形與背側階差；需由Top／Front／Side／3/4共同判斷。 |
| 2 | Toe body／phalangeal rhythm | 趾節是否只有平面尖楔，缺乏由根至端的立體收束？ | 現有外觀問題，不據此宣稱真實關節位置錯誤；以既有Rig位置作不可變參照。 |
| 3 | Skin → claw、claw arc | 爪與趾體是否連成合理輪廓，三爪曲率及尖端方向是否協調？ | 先查輪廓及可見接合；歷史crossing未在本階段重新驗證。 |
| 4 | Rear digit attachment | 後趾根部擁擠是否影響整腳辨識？是否值得本輪大形修改？ | 已列RVI-003；先審視，不自動擴成完整後趾重塑。 |

先以足部整體而非逐一趾節進行比較。必要修改最多收斂成一個主要大形目標與一個必要接合目標，其他事項記入RVI；不追求每趾每面完美。

## 可直接使用的參考／檢視資料

- ninola-fresh-audit/2026-10-08-v001：K6 Top／Front／Side／Rear／silhouette／全身及unmasked三分之四，相機與隔離記錄俱全；目前以既有實際模型檢視證據準備，不宣稱本次新增完整01L audit。
- ninola-migration/2026-10-08-v001/references/references：Concept、download-10/13/15原始標註及Anatomy／Region references；顏色語義依README，不能當精確edit mask。
- ninola-01K8/2026-10-08-v001/references：五份使用者提供AI生成圖與來源hash，作意圖參考；SOURCES.md記錄研究來源與推論限制。不能照抄圖上肌肉名稱、關節數值或左右差異。

正式01L審視開啟K6正確object，以Local View／暫時場景隔離Trex、K4／K5與Audit markers；固定pose。觀察evaluated surface，不用未變形Edit Mode坐標直接判斷外形，不Apply／Bake。既有足部mask有裁切，輪廓判斷需與完整模型3/4交叉核對。

## 收尾與停止條件

本區交付需要：現況多視角判断、最主要的大形問題、保留／擬改區域、必要修改方案和RVI去向；不要求解剖精確復原、無任何瑕疵或Production整合完成。
修改方案應保留K6斜向足段與厚度、下方留空及整體比例；需動ground anchors的方案必須明列，不能以Z0對齊為造型目標。Rig／Bones／pose、原Trex keys、01J保持。
01K踝部環帶與後側mass問題保持RVI-003 DEFERRED；01L只在確實影響趾根時處理必要末端邊界，不重開整個hock重建。RVI-002動態接地另行驗證。
完成足部區域審視後，下一區建議Head／Neck／Jaw（含使用者在意的下顎），接著Torso／Pelvis／Tail整體連續性；最後全身比較並重排RVI。此順序為當前審視安排，不是宣稱交接已有完整順序。
No Commit／Push／PR；沒有01L Mesh修改、Production cleanup／integration或骨架修改。
