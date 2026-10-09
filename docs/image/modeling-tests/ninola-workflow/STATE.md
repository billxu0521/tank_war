# Ninola Current State — 2026-10-09

## Authority与環境

Repository billxu0521/tank_war；Permanent Worktree `/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola`；branch `asset/ninola-authoritative`。唯一Canonical Working Documents為本ninola-workflow目錄，本檔為唯一Current State；詳細索引见asset-index.json、模型歷史见DISCUSSION_LOG.txt／DECISIONS.md。原Checkout／Archive与Library唯讀。

## 核可工作基準

最新核可工作checkpoint：01R.2 v005，blender/ninola/working/01R2/2026-10-09-v005/ninola_01R2_gold_slit_eye.blend，Object 01R2_Gold_Slit_Eye，SHA-256 363eb15913ff2b7ee528a67163aa86805126e56a64514e07001cddc0ff305929。9441頂點／7007tri／45骨。使用者核可金色虹膜、收尖黑色豎瞳與從純側向朝前累計30°的眼球安裝；眼眶、球心、球徑與Rig保持。繼承01R.1 v011核可粗面頭顎／後顱接邊，以及Q1尾部、P1掌指、O2腹部、N1下顎、M8識別棘刺、L3足部。R1 v011與其他核可checkpoint保留回退；Prototype仍有口腔／眶環疊合／爪底蓋／權重等工程限制，不作Production驗收。

N1 v004／M8 v001留核可回退，M7 v003留來源與實玩證據；M6討論錨點已取消，只留歷史。M2與O1 Rejected Experiment，O2 v001/v002只是早期試作，不承接。K6 Selected Morphology Candidate與01K暫時落地／rollback，K7 Rejected Archive-only，K8 PARTIAL未採用，01K暫停；L1／L2未承接。

01J Approved v004仍唯一Approved Production Checkpoint，SHA `b8b7e5c11f9a7c6f80901086e3d03d609f6ec732a1d888b0fdd66a61eba613b3`；沒有將Prototype整合或替換遊戲`models/trex_hd.glb`。

## 本輪收束与封存

01O：使用者否決頸肩重塑O1，選擇暫沿用既有頸軀幹；O2依綠圈黃線自然收腹並核可。封存../ninola-01O/2026-10-09-closeout-v001/，ZIP包含5份實際試作模型及33項allowlist來源檔、交接／歷史／manifest；15,659,693 bytes，CRC与逐項SHA一致，archive hash与Asset Index留存。舊STATE另留唯讀歷史快照，不作更新權威。原模型Hash未改。

O2非目標面座標、Rig／keys／pose、weights／材質／Topology保持；讀回、pipeline budget=None、三個既有姿態回放、MCP臨時場景還原已完成。未新實玩／完整身體動態或Production驗收。

## Current review / next action

2026-10-09｜使用者「覺得好，就這樣定版」核可01S合併體態／咬合基準：R2v005 Mesh＋B姿態（頸Skeleton-X+12°、頭補償-4°）＋jaw中性閉合1.5°。本輪造型與動作基準收束，後續沿用此組合；來源Blend不烘焙Pose、不改Rig／Rest。後口內腔既有交叉仍OPEN，接地DEFERRED；Production仍01J，沒有正式整合或Commit／Push／PR。

使用者已核可01R.1 v011：後顱窄亮帶修整成功，頭顎原材質、已接受鼻端眼眶與核可棘刺保持。六個接點重新對齊并共用，+5tri，保留粗面折角；本輪頭部風格修整先落地，不再自行精修或重塑。獨立審視通過有限接口造型修整，20完整視圖、保存讀回／來源hash、三人工姿態及MCP還原完成。報告../ninola-01R/2026-10-09-pass-v004/index.html。此核可不等於完整變形、全流形、所有接口或Production驗收。

主要區域已完成本輪分區回顧：後肢与足、頭部、下顎、頸軀幹／腹部、前肢手、骨盆尾部、全身風格。頸軀幹按使用者選擇保留，不能重新當必改項。R1早期分色／移點與轉移失敗歷史留DECISIONS、DISCUSSION_LOG及asset-index，不作Current State。

眼球檢查與更替已收束：來源R1v011的M7延續圓瞳已改為01R.2 v005金色虹膜／細長豎瞳，左右從純側向各朝前30°；使用者「決行此版」核可。單眼288tri／雙眼576tri，head權重1，沒有外部貼圖，非原Checkout GoldenEye。角度試作歷史與比較保留；正面注視改善有限，不因核可而宣稱完整凝視或動態已驗收。

01S全身一致性與隔離動態審視已依使用者授權完成，以核可R2v005為基準。主要區域本輪造型回顧可先收束，頸軀幹／核可頭顎足尾不重開精修。全身14視角與Concept比較、隔離Godot程序walk/run/turn/bite/roar及jaw sweep、Blender回放／原Trex控制對照已完成。功能驗收PARTIAL：動作足部下探與原Trex幾乎完全相同，不能直接歸咎新Mesh；閉口22軟面／5牙面相交仍需定位。兩舊眼球空材質槽列交付清理事項，未改工作模型。報告../ninola-01S/2026-10-09-review-v001/index.html。

使用者接受目前整體造型可收束，接地先不處理。RVI-002改OPEN／DEFERRED，先前01S.1接地診斷提案暫緩，不自行啟動。全身造型基準仍R2v005，不因收束宣稱Production或全工程通過。

本輪已按要求唯讀確認咬合：閉口R2軟面22／牙面5配對為嚴格表面交叉，原Trex21／5；多為既有內腔／齒列。隔離小角度掃描1.15°可降為1／0，殘余是原模型也有的後口側內腔／d_belly交界；8.59°为0／0但開口較大，不建議單靠角度清零。已按新授權完成1～2°完整咬擊循環測試，選1.5°為候選，保持Mesh與Rig結構／Rest；使用者已接受B與1.5°方向，合併Viewer完成有限動態檢查，等已獲使用者定版核可；後口內腔／必要牙列allowlist整理仍未核准。尚未獲試修指示，牙列／內口腔保護不解除。診斷../ninola-01S/2026-10-09-occlusion-v001/index.html。未改使用者正在操作的Viewer或來源模型。

## 保護与工程邊界

Production／Prototype雙軌。現Prototype沒有Production Shape Keys，原Trex核可keys保留；Topology／Weights／Shape Key Compatibility／Deformation／Export与Production整合仍須正式處理，不能由造型接受直接覆寫01J。Rig／Bones、名稱／hierarchy／rest／joint centers完全硬鎖。動態只在evaluation副本，來源不儲存回寫。原齒列／舌／內口腔、已接受頭顎足部、前肢爪等未獲明確新範圍前保持。H=.8、I=1、I1=1、J Foot Proportion=1、Ground=.8等沿用核可值。

RVI-001上後肢分布、002接地、003小腿踝足比例銜接、004眼神／頭顎口腔接口與完整動態仍OPEN。N1局部繞序已修，原口腔相交與完整咬合未驗收；不因O2封存強行關閉RVI，也不重啟使用者決定保留的頸軀幹。

M7有隔離真遊戲初測、真鍵盤移動／咬擊反應證據；M8／N1／O2未重跑真實遊戲，既有姿態回放不能替代實玩。持續衝刺／Boss吼叫／完整碰撞／多人与正式整合未驗收。像素風不作目前模型辨識修正依據。

Concept是視覺目標，真實獸腳類結構輔助、怪獸厚重威懾與Low-poly風格保持；AI圖非解剖實證，Production Reference Pack与完整動畫／行為參考未完備。頭顎角面化与後顱接邊已於R1 v011獲使用者核可，本輪風格先落地。Ninola整體完成後需完整Workflow Retrospective。

Migration既有63檔allowlist／65,590,064 bytes已驗證，未無差別匯入历史模型。分支保留開發歷程，main另挑選；AGENTS排除提交，無Commit／Push／PR或Production替換，保留既有未提交檔案。

2026-10-09｜01Q獨立審視通過有限提案定位，保留骨盆上腿與粗尾根；Q1共同尾巴包絡示意待核准。

2026-10-09｜01Q.1六視角共同包絡與控制值圖完成，P1 v002 hash保持；有限尾皮Prototype提案待核准。

01Q.1獨立審視通過有限方向；腹線規整只作控制，不照抄長直平底。使用者方向審核及Mesh試作授權待定。

2026-10-09｜Q1 v002待使用者審核，腹線略平／頂視局部階梯留粗模；不追加全尾精修。

2026-10-09｜Q1 v002核可，01R唯讀審視完成。R1示意待核准；眼神／口腔接口不能由風格分組當已解決。

2026-10-09｜R1分組示意與棘刺風格提案完成，不能以配色當真幾何塊感或減面已完成。Q1 v002核可保持。

R1獨立審視通過方向討論，色面改善微幅、仍需真正轉面方案；棘刺統一可立項但具體改形與增補清單待定。

## 眼球核可收束｜01R.2 v005

使用者於2026-10-09確認「決行此版」。v005升為最新Approved Working Checkpoint（Prototype），累計側向朝前30°、豎瞳維持上下。保存讀回、實際角度／非眼球鎖與來源Hash檢查通過，18幅同鏡頭比較及有限獨立審查留存。v001–v004留歷史，R1v011留核可回退。眼球部分本輪收束，不自行增加角度或細節。

桌面MCP本輪未連線／未繞看，完整遊戲PBR與動態驗證未完成，不能以造型核可當Production或工程驗收。報告 ../ninola-01R/2026-10-09-eye-pass-v005/index.html。01S全身一致性與隔離動態審視已獲授權並完成；接地診斷按使用者決定暫緩，咬合有限試修待審，Production仍01J，無Commit／Push／PR。

## 使用者自行測試｜01S檢視模式

使用者要求自行測試，已開啟獨立原ModelViewer場景，位置../ninola-01S/2026-10-09-user-viewer-v001/test-project/。套用R2v005評估GLB，正式專案不替換；預設靜止恐龍，C切操控。Headless場景載入與實際Godot渲染視窗啟動確認，viewport截圖留存；操作與接地驗收待使用者回饋。01S.1仍未開始。

## 核准範圍內隔離試作｜體態與咬合

使用者核准體態Pose比較與1～2°閉合候選測試。已完成原版／A（頸+6°頭-2°）／B（+12°/-4°）世界軸暫時Pose比較；B較減輕低頭，軀幹高峰仍保留，未將世界軸數值直接套動作程式。另1／1.5／2°各120幀完整咬擊循環，牙交叉max0、既有後口側軟面max1（各96幀），暫選1.5°為候選，非完整咬合修復。原driver中性基準約6.88°，試作是改隔離基準到1.5°，保留動作項；非疊加或無效clamp。兩項各自測試，未合成、未套已開啟Viewer，來源Mesh／Rig結構／Rest／hash保持。報告../ninola-01S/2026-10-09-posture-bite-v001/index.html。B方向與1.5°已獲使用者接受；合併動態相容／Viewer比較已完成本輪有限檢查，已獲使用者定版核可；內腔接邊仍未核准試修，接地仍DEFERRED。

## 核可體態／咬合基準｜01S合併Viewer

使用者「均同意判斷，進行下一步」接受B體態方向與1.5°閉合候選並授權合併驗證。新隔離Viewer已建立：每幀原動作後頸Skeleton-X+12°／頭-4°、jaw中性基準改1.5°，T可切原版／候選。原版及候選各六模式120幀共1440幀，牙面交叉max0；候選軟面max1，僅既有後口配對(3573,2487)，idle／walk／run／turn皆120幀存在、bite96、roar67，並非完整口腔修復。Rest一致、spine2差0、來源hash保持；選取視圖未見明顯新裂口。獨立審視通過有限合併測試；新原生Godot Viewer已獲使用者定版核可。沒有真輸入／完整遊戲驗收，MCP未連；ground DEFERRED、原內口腔／牙列仍保護。最新核可Mesh仍R2v005，Production仍01J。報告../ninola-01S/2026-10-09-combined-viewer-v001/index.html。

2026-10-09｜使用者「覺得好，就這樣定版」核可01S合併體態／咬合基準：R2v005 Mesh＋B姿態（頸Skeleton-X+12°、頭補償-4°）＋jaw中性閉合1.5°。本輪造型與動作基準收束，後續沿用此組合；來源Blend不烘焙Pose、不改Rig／Rest。後口內腔既有交叉仍OPEN，接地DEFERRED；Production仍01J，沒有正式整合或Commit／Push／PR。
