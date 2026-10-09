# Ninola Canonical Workflow

規範優先：原始TankWar規範為基準；歷次對話許可不得自動覆蓋。已再次核准的面數安排與經專案負責人確認的Worktree位置，及本地不提交AGENTS規則，見根目錄AGENTS.md；同步來源與hash見rules-source.json。衝突操作恢復前重新提出範圍核准。

唯一持續更新文件位置：Permanent Worktree 的 `docs/image/modeling-tests/ninola-workflow/`。
STATE.md 是唯一 Current State；asset-index.json 是精確路徑與 hash 索引；revisit-register.md 是唯一 RVI 詳細清單；DECISIONS.md 保存決策。
原始 Checkout 與 migration provenance/workflow-snapshot 為唯讀歷史，current-review 不決定資產權威。不建立第二套 Current State。

## Resource Lookup

使用者指定的原始 TankWar 專案也是本任務的資源檢查對象：
`/Users/ChenPo-Yun/Documents/Codex/2026-10-06/https-github-com-billxu0521-tank-war/tank_war/`。
需要模型、Rig、動作程式、測試工具、Concept或歷史試作資料時，除Permanent Worktree與Migration Archive外，也應檢查此處；可在本任務範圍內自主唯讀取用相關資源。
先核對來源版本與目前資產的關係，不因原始專案內存在某模型或測試結果，就視為當前原型已驗證。原始Checkout保持不修改；必要測試副本與輸出留在Ninola Permanent Worktree。本條不授權新的模型修改、Production Integration或Commit／Push。

## Design / References
Ninola 是 TW-OvT_GameDev 的 Low-poly Fantasy Theropod 資產。真實獸腳類解剖為結構基礎，結合怪獸化、龐大量體、壓迫感、恐懼感與生命力。Head/Neck/Jaw、Torso、Tail、Hindlimbs 應有整體量體連續性與平衡。
Concept 未正交校準；以 silhouette、proportions、mass distribution、anatomical continuity、multi-view coherence 判斷，不 warp Concept 或只追側視吻合。
原始 Concept、三份標註與 anatomy/region communication references 已選擇性匯入，見 asset-index.json。先讀 references/README.md，不能跨圖推論顏色意義。Region labels 不等於精確 edit mask 或正式解剖鑑定。
完整 Production Reference Pack 尚待整理；docs/企劃/尼諾拉.md 提供歷史全身、動畫與行為背景，舊骨架修改指令不解除目前鎖定。走路、攻擊、待機與行為參考尚需在新模型階段重新驗證。

## Authority / Dual Track
01J v004 唯一目前 Approved Production Checkpoint；不是已完成 Godot 整合或動畫驗收。
K6 v003 Selected Morphology Candidate，非 Production Approved。K7 v006 Rejected，Archive-only，不因版本新取代或混入 K6。
K6 prototype 本體沒有 Production Shape Keys；原始 Trex 仍保留核准 keys。正式整合須另行處理 Topology、Weights、Shape Key Compatibility、Deformation、Export，不直接覆寫 01J。
Current Editing State 必須指向實際工作副本，尚無時保持 null。新 Pass 核准後從最近使用者通過的工作資產另建副本，保留已核准成果、來源與hash作rollback；目前為01L.3 v002，K6仍留作歷史基底。

## Hard Locks / Stage Scope
Armature、Bone Positions、Joint Centers、Bone Lengths、Hierarchy、Rest Pose 完全不動；不擅自 Apply/Bake 現有姿態。封存 TrexRig 45 bones，舊 47-bone 文件不可作修改依據。
01J 原檔、keys/values/weights/rollback 保全。H=.8、I=1、I1=1、J Foot Proportion=1、Ground=.8；其餘維持存檔值。
三前趾、rear-digit candidate、claws 外部 Mesh 保護屬 01K 階段限制，不是永久禁改。01L 明確核准後可重塑趾量體、趾節、爪弧，但不解除 Rig/Bones 鎖定。ground anchors 變更也須納入獲准範圍。rear digit 不宣稱 confirmed anatomical hallux。

## Cycle / Approval
Inspect → Discuss → Proposal → Approval → Execute → Operator Audit → Reviewer Audit → Report → Next Proposal。
Proposal 交代視覺目標、base、region/scope、連帶調整、保護範圍、工具、驗收視角與 rollback。核准 Pass 內必要連帶調整自主完成；變更 base/目標/骨架/階段須另提案。
大形優先Morphology Blockout/local mesh，保持Low-poly、不浪費面數，現階段無硬上限。執行工具／腳本與GLB交付須對照原始流水線規則；既有自訂.blend迭代不得自動視為原始流程的已核准例外。造型方向確認後再工程清理。
Operator 驗證執行、正確 Object、檔案重開、限制與副作用。Reviewer 依模型/Concept/anatomy/multiview 判斷是否改善。Technical success 不等於 morphology success。
固定 pose/camera/scale/lighting，提供全身、整腿、局部、silhouette；標明 display masks。原始流程要求子代理審查與桌面MCP多角度檢核；先前同一執行者自評不等同通過該流程。恢復建模前先核對並補足適用檢查。Operator 自评不稱獨立驗證。Fresh review 先看模型/目標/參考，再補歷史。使用者最終決定。

## Files / Git

AGENTS.md不得納入Commit或PR；.gitignore已排除根目錄該檔，提交前仍需查staged paths。工作與紀錄位於本Worktree的選擇暫定，待使用者向專案負責人確認。
影像存 docs/image/modeling-tests/ 獨立日期版本，不覆寫前次。其他 checkout 不並行編輯相同 .blend。
Commit/Push/PR 需另行明確授權；檢查 staged paths，不能 git add . 批次加入 archive、historical experiments 或暫存資料。不推 main、不自行 merge/force push、不擅改 LFS。認證問題等需要時處理。

## Model History Log
`DISCUSSION_LOG.txt` 僅記錄 Ninola 模型調整歷史：造型目標、部位問題、模型相關技術討論、版本取捨、核准/否決理由、實際變更與驗收結果。
不記錄環境設定、Migration搬運、工作流/架構、溝通方式、文件管理或一般方法論；不因這類討論新增log條目。
重要模型討論或實作完成後追加簡短日期條目（Asia/Taipei），附必要版本/證據。早期歷史標明封存摘要或回填，不編造時間；更正保留可追溯性。此log不取代STATE的Current State。

## 開發紀錄與正式交付

使用者確認本branch保存開發進程，之後依明確授權推送供專案負責人閱讀。工作紀錄持續存docs/image，不建立第二套Current State。main另行選擇正式資產與必要文件；提交前挑選可讀摘要、關鍵比較、腳本及相應資產，不無差別加入快取／大量重複截圖。原始Archive保持歷史來源。AGENTS仍排除提交。
隔離動態測試使用evaluation副本及專用GLB，程式來源／pose矩陣／渲染設定需留存；CHECK OK、視覺審查與真輸入實玩是不同驗證範圍，不能互相代替。

## 2026-10-09：剩餘全模型分區回顧規劃

使用者已核可M8；目前checkpoint以STATE.md與asset-index.json為唯一狀態依據。本節記錄後續回顧方法及順序，不建立第二套Current State，也不授權直接執行模型修改。01M本輪收尾，眼神等疑點留RVI。

| 順序 | 審視區域 | 核心問題 |
|---|---|---|
| 01N | 下顎 | 吻端／顎身／後顎整體設計，與M8上顱及固定口腔的關係 |
| 01O | 頸根／肩胸／軀幹，含胸腹過渡 | 新頭型如何接頸、頸胸背的厚重感、軀幹主量體與前肢附著是否符合Concept |
| 後續一 | 前肢／手 | 短臂的比例、肘腕與手指輪廓、與胸側的關係及必要動態；現Rig指數不能由歷史意圖自行改動 |
| 後續二 | 骨盆／上後肢／尾根／完整尾巴 | 臀股肌肉分布、整腿節奏、軀幹到尾根承接、尾巴側／頂漸變與平衡感；不重啟足部逐點修補 |
| 後續三 | 全身比例／棘刺／裝甲與色彩大面主次 | 頭身腿足尾的尺度關係、全身輪廓、刺與裝甲集中／疏密、Low-poly大面可讀性；先量體後表面細節 |
| 收束 | RVI與必要動態回看 | RVI-001上後肢、002接地、003小腿踝足段比例／銜接、004頭顎眼神／接口，依整體影響排序 |

每區同一流程：M8或後續核可checkpoint隔離唯一Prototype，固定pose與多視角，Concept優先、解剖研究輔助；交付點評及「保留／主要修改提案／RVI延後」。只有有必要且核准才試作，附前後與廣視角比較，使用者決定承接。合理區域可以直接通過，不要求每區都改。后續階段編碼待範圍確認，不預先建立大量Pass。

本輪回顧完成條件：主要區域均已有可讀評估，核可方向有工作checkpoint；影響輪廓或必要功能的問題有處置，其他疑點有明確RVI及觸發條件；完成一次全身Concept／量體與必要動態總回看。不是每項細節完美或所有RVI強行關閉。

Production整合／Topology／Weights／Shape Keys／Deformation／Export與遊戲整合另列工程階段，未隨本回顧自動授權。Rig／Bones、其他既有Hard Locks保持；需要解除鎖區先提出具體證據與範圍。週末測試可並行，不壓縮完整分區審視。

2026-10-09最新順序：使用者指定01N下顎先行，01O頸根／肩胸／軀幹及其餘項目順延。01N先審視與設計提案，再核准實作；骨架與口腔保護保持。

全身風格統整補充：比較頭／下顎較平滑與身體／尾部多面體稜角的取捨。使用者可能希望頭顎增加有選擇的多邊形主面，但尚未選定；量體方向先行，風格統整後議，不以接口鋸齒當刻意Low-poly。

2026-10-09覆蓋更新：01N以核可N1 v004收束；01O唯讀頸根／肩胸／軀幹（含胸腹）已完成，下一候選為01O.1共同包絡設計示意，尚待核准。先共用截面多視角→核准範圍→獨立試作→有限動態／固定區驗證，不把每個折面改平。剩餘分區順序保持，實際Current State依STATE与asset-index。

2026-10-09｜01O.1設計示意已核准執行並完成；同一3D包絡跨視圖核對，尚非Mesh實作。候選mask及共點需於實作前確認，不能以骨根標記替代皮膚接口。當前狀態依STATE。

2026-10-09｜01O.1粗模授權已執行，結果PARTIAL。保留v001過窄範圍及v002有限試作，展示範圍與未覆蓋區域後再決定；不因技術驗證通過直接承接。當前checkpoint依STATE／asset-index。

2026-10-09｜01O頸／軀幹已由使用者決定暫保留原形；O1失敗不構成必須再修頸部的理由。改為O2只收腹，v003候選待審；若核可即收束01O、後續前肢手唯讀分區回看。

2026-10-09｜01O已收束封存，O2 v003核可。後續一正式命名01P前肢／手；唯讀審視已完成，下一為必要手端示意待核准。剩餘骨盆尾根完整尾巴／全身主次與RVI順序不变，Current State只依STATE。

2026-10-09｜01P.1 v002已核可，後續二正式命名01Q骨盆／上後肢／尾根與完整尾巴；下一只提必要尾部包絡示意，Current State以STATE為準。

2026-10-09｜Q1 v002核可後，後續三正式命名01R全身比例／刺裝甲／色面与角面風格。唯讀審視完成；必要R1比較→RVI与必要動態總回看→本輪分區回顧收束，不每區必改。實際狀態依STATE。
