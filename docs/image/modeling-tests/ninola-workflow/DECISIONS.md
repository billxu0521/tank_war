# Ninola Decisions

## 2026-10-08 Final Migration Approval / Implementation
使用者正式核准 Layer 1/Layer 2 與四項修訂，授權最小匯入、canonical 文件、索引、唯讀 K6 Fresh Morphology Audit 與下一個方案；未授權 Mesh/Rig 修改、Production Integration、01L、cleanup、Commit/Push/PR。
01J v004 Approved；K6 v003 Selected Candidate；K7 v006 Rejected Archive-only。01K 暫停，RVI-003 OPEN。Production/Prototype 雙軌、Rig/Bones Hard Lock 保留。
Canonical location 沿用 ninola-workflow；撤回 docs/素材流水線/ninola 的重複架構。舊 Checkout/workflow-snapshot 保持唯讀。
Digit Mesh protection 屬 01K 階段；未來 01L 經核准可塑趾/爪，不解除骨架鎖定。
K6 無 production shape keys，原 Trex 保留 keys；正式整合另驗 topology/weights/key compatibility/deformation/export，不能覆寫 01J。

## Retained History
01A–J 累積比例/量體/pose 修正；原 01B approved，B.2 非 base。01B 舊缺件後續已補齊。
K–K2 固定拓樸/Shape Key 研究未取得目標外形；K3 local topology 顯示可行斜向段但銜接未解；K4 選 Anatomy-Balanced A；K5 多視角下腿/踝量體；K6 shaft-normal 指定樣本相對 K5 +73.9–77.6%，使用者接受基本比例；K7 視覺退步遭否決。
Technical success ≠ morphology success；checkpoint approval ≠ integration/animation readiness。
舊 RVI-003 annotation 缺失限制保留歷史；本次已匯入 download-10/13/15，不能延用舊缺圖判定。

## Phase Retrospective / Final Task
每輪先準備完整 reference 與標註語義；以視覺決策為 approval 單位。保全 production 後大形用 prototype/blockout，不為保留拓樸反覆微調。不把 technical PASS 当視覺驗收，不過早投入 engineering cleanup。
本機共享資產與索引取代每輪 ZIP 往返；只保留必要 state/delta/證據，避免重貼歷史與長 logs。
Ninola 整體完成後，必須進行完整 Workflow Retrospective，改善未來其他模型的製作效率；目前僅階段性檢討，不宣稱整體完成。

## New Decision Entries
日期/Pass、使用者決策、base+hash、範圍/locks、Operator結果、Reviewer結果/独立性、輸出、Open Issues/下一步。

## 2026-10-08 Implementation / Audit result (not new design approval)
實際匯入63檔/65,590,064 bytes，只含01J/K6兩份.blend；K7保持Archive-only。全部匯入hash一致，來源未變。Canonical文件落地。
完成K6唯讀Fresh Audit，優先判斷為踝部環狀收束與proximal transition；新的hock mass blockout僅提案。01K暫停與RVI OPEN未解除。

## 2026-10-08 — 01K.8 execution authorized; result pending review
使用者已接受01K.8命名與局部hock mass continuity方向並要求執行，解除先前本輪未執行狀態；未授權01L或Production Integration。
Base=K6 v003，hash 6be6642d8ed8cb2b48a31bd2649cf94457be6073daa59ac6653197dd222f18ca；K7不作base。
交付K8 v004局部topology prototype，見asset-index.json及VISUAL_REVIEW.md；技術接縫／保護資料核對通過，視覺PARTIAL。Operator／Reviewer同一Codex，未獨立審核。
新表面暫用weights插值不構成Production蒙皮核准。Rig/Bones Hard Lock及原Trex資料保全；J Approved／K6 Selected／K7 Rejected不變，RVI全部OPEN。
現在停止等待使用者結果審核，不將執行授權當成造型接受。

## 2026-10-08 — 01K landing point and 01L preparation
使用者授權依現有討論選01K暫時落地點並開始01L準備。採K6 v003：基本比例已選定；K7 rejected；K8 PARTIAL未作接續base。此為暫時造型工作基準，不提升Production地位。
01L沿交接未完成方向準備腳掌／三前趾／趾節／claw arc整體審視；先收斂大形問題與方案，不追求完美，不重開hock微修。尚無01L Mesh修改。
Rig/Bones鎖、J原件與keys保護維持；01K未解問題RVI-003 DEFERRED。準備證據見ninola-01L/2026-10-08-preparation/PREPARATION.md。

## 2026-10-08 — 01L read-only review completed
依使用者「請執行」接續已準備的區域審視；實際開啟K6並產生足部證據，未修改Mesh。K6落地點／J Approved地位不變。
01L.1提案收斂三前趾volume與必要toe-root銜接；不全面重塑rear digit、不重開hock微修。大形試作尚未執行。證據ninola-01L/2026-10-08-review-v001/REVIEW.md。

## 2026-10-08 — 01L.1 execution authorized and completed
使用者「執行」授權01L.1。以K6另建01L1 v001，206頂點參照局部修改、拓樸／weights保持；claws、ground band／anchors、rear、pedal核心與Rig／原Trex保護核對通過。
結果PARTIAL，側面量體改善但三趾分化不足；同一Operator／視覺自評、未獨立審核。K6仍暫時落地基準，L1僅待審試作；不把技術檢查或執行授權當成造型核准。
不追加01L.2微修，未解項沿用RVI-003，詳ninola-01L/2026-10-08-pass-v001/RESULT.md。

## 2026-10-08 — 01L.2 toe definition authorized; proportions deferred
使用者明確決定先做趾體分化，暫不改整腳／01K足段比例；覆蓋前一比例調整方向提案。以K6另建01L2 v002局部dorsal-surface refinement／valleys；保留XY尺寸、趾尖／claw／接地及Rig。
初版v001不採，修正同輪溝深／邊界鎖後v002待審，自評PARTIAL，未獨立Reviewer。新surface weights暫用插值，交界T接點未Production驗收。K6 Selected／J Approved不變；比例原因未定，RVI-003 DEFERRED。

## 2026-10-08 — L1/L2 not carried forward; scope schematic delivered
使用者回饋L1加厚不自然，L2未有效表達趾體分化；同意先製作示意。K6為基底，L1/L2保留歷史試作，不承接。
完成實際bone／claw／ground anchor投影與原生SVG/PNG範圍圖；方向是三趾量體＋局部開放趾間，不是表面凹槽。Rig硬鎖與本方案保留外部位置區別明列。01L.3具體提案未執行；比例DEFERRED。

## 2026-10-08 — 01L.3 execution / pending review

使用者核准Concept／anatomy核對後的三趾重建方向及執行：從K6重開，建立厚實漸收趾體、自然V／Y分叉空隙；整腳比例延後。不得修改Rig／Bones、原爪、toe tips、ground anchors、rear digit與pedal核心。
01L.3 v002完成，三趾分化成立；Concept matching仍局部接近。建議保留為足部區域候選，尚非使用者採納。K6 Selected、01J Approved、K7 Rejected Archive-only、01K暫停及Production／Prototype雙軌地位不變。
原型weights及接口未Production驗收，RVI-003／002不關閉。審核後建議轉Head／Neck／Jaw現況審視，不因足部未完美繼續無限追修。完整模型完成後Workflow Retrospective仍需執行。證據../ninola-01L/2026-10-08-pass-v003/RESULT.md。

## 2026-10-08 — 01L.3 user acceptance

使用者看過局部／後肢／全身比較後明確「通過」。01L.3 v002成為足部暫時造型落地點，後續評估保留這次三趾結果；K6留作來源與rollback，不因此丟棄已核准L3。此為造型通過，非Production topology／weights／deformation／export驗收，01J地位與Rig Hard Lock不變。RVI未關閉。下一阶段提案01M Head／Neck／Jaw，先唯讀審視再圈定一個主要blockout目標；未開始修改。

## 2026-10-08 — 01M read-only review complete / 01M.1 proposal

使用者核准01M唯讀審視。從通過的L3原型完成8視圖及Concept對照，優先問題為下顎腹側獨立楔塊與後端直落，吻部／後顱層次及頭頸承接列RVI-004。提出01M.1局部下顎外皮blockout，非等比放大整頭；不改Rig／pose、牙齒／齒列／口腔、頭顱／頸部及足部。修改未執行，需審核具體提案。未有同一模型張閉口資料，不聲稱咬合驗收。證據../ninola-01M/2026-10-08-review-v001/REVIEW.md。

## 2026-10-08 — 01M.1 executed / head identity requirement

使用者核准試作，強調頭部識別與攻擊必須可信服、不滑稽，Concept為方向；硬鎖Rig／Bones下大幅Mesh重塑可接受。01M.1 v002已完成局部下顎外皮513點位移，其他範圍、拓樸與weights保持。結果局部改善、整頭識別仍不足，待使用者審核，不自動採納。L3仍最近通過基底／rollback、01J仍Production。下一提案01M.2為整體頭顎量體，不繼續只削下巴；未執行。攻擊／張閉口與變形未驗證。

## 2026-10-08 — Expanded head proposal scope / isolated evaluation

使用者確認新原型應在隔離環境測試，不要求舊遊戲GLB先含新模型。整體頭部proposal可包含眼睛／眼眶重做；golden-eye為可選歷史試作參考，不是必須採用的核准資產。概念圖仍為視覺目標、Rig／Bones Hard Lock保持。下一規劃先動態比較L3／M1，再提出01M.2實作範圍，尚未執行模擬或新模型修改。

## 2026-10-08 — 規範重設：1B／2A／3A（暫定）／4A

原始規範優先，先前衝突許可須重新提出，不自動沿用；已明確再次核准造型階段無硬面數上限、保持Low-poly與不浪費資源。Worktree／分支／docs/image位置暫沿用，待專案負責人確認。建立本地AGENTS.md完整同步原始基準與本次補充，排除Commit／PR；原始Checkout不改。原始pipeline包含腳本＋GLB、自動檢查、子代理審查與桌面MCP多角度檢核，既有自評／.blend試作不是完整通過這些規則。頭部重塑與動態測試保持暫緩；已完成資產與使用者評價紀錄保留。

## 2026-10-08 — Branch紀錄與動態比較完成

使用者與專案負責人確認Permanent Worktree／branch／docs/image位置；開發branch供進程閱讀，main交付另行挑選。仍須另行授權Commit／Push／PR。
使用者恢复「先動態驗證，再整體重塑頭部」方向。完成L3／M1隔離evaluation、實際程序動畫取樣、MCP及子代理視覺審查；不修改來源Rig／Mesh／正式GLB。M1局部改善支持繼續設計，但整體頭部未通過，保持候選；L3仍最近使用者通過。01M.2具體方案已提出待審，未重塑。RVI-004保持OPEN，需重審原有口緣交疊與眼眶／吻部／後顱。完整真輸入／戰鬥及Production驗收未完成。

## 2026-10-08 — 01M.2 authorized / completed pending review

使用者在動態結果與M1一體感正向回饋後核准繼續下一工作。從M1另存M2 v002：整體頭部量體補強與眼眶重建；v001圓環試作保留未採用。Rig／Bones、原Trex／keys、牙齒／舌及足部保持；M2未整合01J。独立審查通過討論用blockout，待使用者判讀頭高與厚度，未自動成為新Approved。Godot隔離載入與程序比較完成，真輸入／Production未驗收。原口緣交疊保留RVI-004 OPEN。

## 2026-10-09 — 使用者否決01M.2

使用者認為01M.2失敗：側視顱頂變成中間凸起的三角形，明顯偏離Concept；M1原曲線雖未完成，仍較接近目標。01M.2系列標記Rejected Experiment，保留模型、動態與技術嘗試，但不承接其顱頂或自動採用其他局部修改。後續頭部設計返回M1 v002參考起點，L3仍最近正式通過工作checkpoint；不改任何模型檔案。

先前「承重感」僅指體積增加帶來的視覺厚重印象，沒有生物力學證據，也不足以證明符合Concept。實作將眉部／顱頂抬升疊加在同一區域，造成中央尖峰與向後下落；沒有經驗證的後續搭配方案能支持保留此峰。先前自評過度重視厚度增加、未充分把關側視主輪廓，判讀更正。

重新提案應先從M1與Concept比較不含尖刺的頭皮上緣、鼻背—眉眶—後顱主線；將局部眉脊厚度與整體顱頂高度分開。未提出／核准新方案前不繼續建模。RVI-004 OPEN，Rig Hard Lock與Production雙軌不變。

## 2026-10-09 — 01M.3 authorized / v006 complete pending review

使用者核准依Concept示意執行。M1來源独立重建上顱／吻部，原33接口、Rig／Trex／keys、齒列／舌／原mouth、下顎／身體／足部保持。v001–v005不採用技術試作保留，v006新外口緣连接解決主要尖折；獨立審查通過討論用灰模，但Concept識別未完成。M3待使用者審核，M1留回退，L3仍最近正式通過、01J仍Production、M2仍Rejected。無Commit／Push／PR。

## 2026-10-09 — M3 accepted for continuation / M4 authorized

使用者認為M3與M1各有優點，但M3可接受、值得承接，明確要求繼續加入鼻背、眉眶等與棘刺以便判別。承接M3 v006主量體；M1保留參考。本輪M4獨立版本與同套動態／口緣診斷屬此次已核准範圍。保護項目不解鎖，Production與Commit／Push／PR仍不授權。

### 2026-10-09 — 01M.4完成待審

M3 v006已獲使用者接受可承接，作頭部灰模回退點；M1另留局部優點比較。M4獨立加入低鼻背、眉眶、凹入眼部及16根後傾棘刺，待審。Rig／齒列／舌／原口腔／下顎／身體／足部保持；未整合Production。下一輪眉眶與鼻背結構提案等待審核。

### 2026-10-09 — 01M.5B執行與不採納

使用者核准B示意實作；完成七份獨立試作，v007仍未達眶區包覆目標，不整版承接。鼻吻參數可留作後續比較，M3已接受回退點不變。Rig與原口腔等保護核對通過，無Production整合／Commit／Push。下一輪眶區主面重建僅提案。

### 2026-10-09 — 01M.6設計包完成

使用者決行唯讀定位與整頭設計；完成同截面四視圖、L1–L9候選區、近遠視線／外殼遮擋及眶部三層剖面，獨立審查通過設計包。尚未批准Blockout，不以設計通過宣稱模型或咬合通過。新外殼須逐段接固定口緣／頭頸接口，M3保持回退。

### 2026-10-09 — 01M.6試作授權與不採納

使用者「同意，試作」批准整頭Blockout。四份獨立試作保留，v004討論版造型不通過：格面連續性改善，但鼻吻台階／長罩殼／眶區承托不足。M3 v006仍已接受回退，M5B局部進步保留參考，01J仍Production。主頭皮未通過，未繼續加頭刺；原Rig／下顎／齒列／原內口腔／身體／足部保護保持。下一輪主量體與接口提案未執行，等待使用者審視。

### 2026-10-09 — M6討論錨點／M7結構粗模

使用者保留M6 v004可退回討論，並授權結構修整而非精修。M6保留、独立未通過紀錄不改寫；M7 v003待比較，週末先選暫時測試基底，不先進Production整合。風格化研究僅參考，Concept優先；未来可能涉及鎖區重做，但本次沒有解除任何保護。

M7 v003獨立審查通過結構粗模方向，正面眼神未通過；僅推薦討論候選，M6錨點不替換，待使用者選擇。

## 2026-10-09：M7基準與分區審視持續

使用者取消M6討論錨點，以M7 v003為準；M6檔案與失敗歷史保留。M7隔離遊戲初測及真鍵盤移動／咬擊反應已記錄，非Production批准。週末測試不取代全模型分區審視；下一建議01N先唯讀頸根／肩胸／軀幹，之後前肢／手、骨盆尾根／完整尾巴與全身主次回看。Rig及其他Hard Locks不變。

## 2026-10-09：01M收尾先補回識別元素

使用者要求加回頭部棘刺等識別元素，授權M7上的獨立M8候選；不是另開精修頭型或解除保護。M8待審、M7仍基準，待確認後繼續全模型分區審視。像素化可讀性暫不作修改理由，本機專案更新暫緩。

## 2026-10-09：M8核可與整體回顧規劃

使用者核可M8，承接為目前工作checkpoint；M7仍保留既有遊戲測試證據，M8核可不代表已重跑或Production整合。01M本輪收尾，RVI-004保留；先交代剩餘全模型回顧規劃，不開始01N或新修改。

## 2026-10-09：01N目標改為下顎

依使用者指示，01N先重新審視下顎；頸根／肩胸／軀幹順延01O，其餘既定區域順延。此輪授權審視／建議，不自動授權下顎改形或解除Rig／口腔保護。下顎疑點沿用RVI-004。

## 2026-10-09：01N.1設計示意核准執行

使用者同意下顎結構示意，要求保留實體厚度，红框僅表達量體而非矩形規格。已完成示意，外皮建模／口腔解鎖未授權。M8仍checkpoint，Rig等保護保持。

## 2026-10-09：01N.1試作完成，未採納

使用者授權獨立下顎外皮試作。v001～v003均保留PARTIAL，獨立造型不通過，不替換M8；未解除Rig／牙列／口腔保護。頭顎与身體的面片風格統整只記錄待比較，本輪不執行。

## 2026-10-09：使用者接受01N.1 v003及接口診斷

使用者認為01N.1可接受、無像素化較佳，授權執行接口釐清。N1 v003升為目前工作checkpoint，M8回退；獨立審查限制留歷史，部分尖瓣判讀更正為保留牙齒／口腔。診斷另發現21面繞序不一致邊，暫時修12面可消除此計數，尚未保存修正版。本輪不再推動整顎大改，不解除口腔／Rig保護。

## 2026-10-09：授權繞序修復完成

v004作接受v003造型的技術修正版，僅12面繞序，驗證通過；不另宣稱新造型核可或Production驗收。保留v003／M8回退，RVI-004其他問題仍OPEN；下一順序01O頸根／肩胸／軀幹。

## 2026-10-09：01N.1 v004核可與01O唯讀審視

使用者審核通過v004，01N本輪收束。01O唯讀審視已完成，厚頸／胸腔与歷史01B成果保留；頸肩分塊及前胸腹側轉接列下一共同包絡設計候選。01O.1尚未核准／執行，Rig與已接受頭顎足等保護不变。未修改模型或Production，無Commit／Push／PR。

2026-10-09｜使用者核准01O.1共同包絡示意；已完成同一3D多視角設計，待使用者審視。未將此核准擴張為Mesh試作或跨固定接口授權，N1 v004保持。

2026-10-09｜使用者許可01O.1試作，已完成v001/v002；v002為PARTIAL未採用，獨立造型不通過，N1 v004保持核可基準。不自动將技術通過轉為造型核可或追加解除保護。

2026-10-09｜01O.1由使用者否決，保留Rejected Experiment；頸與軀幹暫沿用N1。使用者新授權僅腹部自然收斂，O2 v003從N1另製、獨立造型通過候選，未核可承接；Rig與其他保護保持。

2026-10-09｜使用者核可O2 v003收束封存，升為核可工作checkpoint；O1 Rejected保留。下一作業為01P前肢手唯讀審視；原形短臂与上臂量體保留，手端示意待核准，未解鎖Rig、指數或爪形。

2026-10-09｜01P.1手端立體示意核准執行並完成，方向待審。下一實體範圍只提掌指外皮，原爪與Rig保持；尚未授權Mesh Pass。

2026-10-09｜01P.1掌指外皮獨立試作已獲授權並完成v002，待使用者造型審核。原爪形／腕端／Rig保持；16條焊接爪根三面邊与原指權重未作Production cleanup，O2核可身份不變。

2026-10-09｜使用者核可01P.1 v002為工作checkpoint；手部先落地，工程限制保留。01Q下一區域為骨盆／上後肢／尾根与完整尾巴，唯讀審視；Q1尾部連續漸收示意待核准，不預設整腿必改。

2026-10-09｜01Q.1共同尾部包絡示意獲授權并完成，方向待審；不全面削瘦，不進行全尾重建。P1 v002核可基準保持，Mesh Pass未授權。

2026-10-09｜Q1外皮試作已授權；v001選面不全未承接，v002獨立造型通過待使用者核可。原專屬尾皮量測更正、原棘刺／Rig／核可P1不動，非Production整合或全尾cleanup。

2026-10-09｜Q1 v002使用者核可為最新工作checkpoint。01R全身量體／背刺主次暫保留；頭顎R1主面与色面分組示意待核准，未改模或色。Production與全尾／全身動態未因區域核可通過。

2026-10-09｜採身體大幾何塊面為風格化基礎，Low-poly節約是設計方向；R1示意已授權完成，不宣稱材質分组等於幾何／減面。棘刺可檢視統一与少量增加，但具體位置、修改界面與budget需在實體提案明列；本輪未增移原刺。

2026-10-09｜使用者否決R1頭顎分色，保留原皮色並授權實體幾何化；棘刺安排方向可，要求頭刺色差說明及延續。R1 v004從Q1另製，局部合面與25內部點轉面、6988tri，頭刺只統一原褐色明暗指派。Rig／原Trex keys／weights與固定接口保持，三有限姿態、來源hash及MCP還原完成。獨立造型不通過大塊面目標，PARTIAL未承接，Q1 v002仍核可基準。下一提吻側寬面與後頰承托面主折線設計，不继续放大規律細格；尚未執行下一實作。

2026-10-09｜使用者核可頭刺配色，否決v004幾何並授權續試。核可棘刺另存Q1原幾何＋原褐色明暗指派副本01R_spine v001；棘刺形狀數量不變。R1 v005寬面形成但上部硬折不通過；v006恢复鼻背眶周上區，仅吻側寬面與低位後頰承托，49點／6994tri。獨立審視通過有限試作討論，仍偏長板、鼻端略硬，待使用者造型核可；核可副本不含此未批准幾何。Rig／原keys／weights与來源保持，三人工姿態、退化面檢查及MCP還原完成，非完整動態或Production驗收。下一若需修改只提後段承托与鼻端前漸退，停止自動追修。

2026-10-09｜使用者允許重塑前大面拼接重新貼合新版頭型，至少不強烈影響眼眶，其餘看試作定奪。R1 v007保留眶區過寬有階梯；v008縮為76面眶環；v009排除未使用歷史點，v010配準真實外皮周界，取用舊M1的118面，6714tri。粗塊感成立，鼻端厚鈍／眼睛露出與後顱接邊仍有差異，接口疊合未完成，PARTIAL未承接。原Rig／眼球／保留眶環／牙口腔／下顎與核可棘刺保持，三人工姿態及保存讀回／來源供體hash／MCP還原完成。下一若方向接受先接邊與眶環包覆轉接，不自動細雕。01R_spine v001仍核可基準。

2026-10-09｜v010獨立審視不通過承接，支持展示大方向；後顱亮條／台階不直接稱破洞，鼻端與眼眶包覆差異需使用者判斷。保持PARTIAL与核可01R_spine，不自動續修。

2026-10-09｜使用者認為v010鼻端與眼眶在可接受範圍且更好，要求保留；後顱階梯感受不明，要求示意。已用原圖定位與同鏡頭局部放大，黃框標出眼後／嘴角上方窄轉面；更正「階梯」的籠統說法，尚未證明裂縫或穿插，先列可選接邊整理，不單憑亮帶否決整版。只建說明圖，未改模型／Rig／材質；整版checkpoint尚待確認。

2026-10-09｜使用者明確認定後顱窄轉面交界是瑕疵，要求自然接續但保留粗面，不是做平滑；此前可選整理定位被取代。v011只移左右各三個接邊點、兩供體三角面插入共用點，+5tri、6719tri。鼻端眼眶棘刺原點、Rig／keys／weights／材質保持，窄亮帶減輕；保存讀回、多視角、三人工姿態与MCP還原完成。待使用者核可，若接受接口則建議頭部風格先收束，不自動扩張精修。

2026-10-09｜v011獨立審視通過有限接邊造型修整；保留正常粗面凹轉與陰影，不追求抹平。停在此版讓使用者核可，未自動承接為整版checkpoint。

2026-10-09｜使用者確認v011修整成功並核可。升為最新Approved Working Checkpoint（Prototype），保留鼻端／眼眶／棘刺與大面折角；01R本輪頭部風格先落地。下一建議01S全身一致性與動態審視：固定多視角對Concept、隔離Rig動作／接地／咬合，再排序RVI；先唯讀，不新增Mesh Pass。01S未開始，Production／完整工程與動態驗收未因此通過。

2026-10-09｜使用者在01S前先確認眼球模組，僅考慮眼色與瞳孔形狀更替。唯讀v011查核：M7延續12分段球，每眼74點／144tri，Ninola_Iris_Gold_M6金色虹膜与d_pupil深色圆瞳，其他球面也深色，无眼球貼圖；眼球併入主Mesh、head權重1。未使用原Checkout GoldenEye（單眼896tri）資產。已出實際隔離近圖，未改眼球、眼眶、頭型或Rig；更替尚未決定。

2026-10-09｜01R.2金色豎瞳只作獨立待審眼球試作。現生鱷類參考與獸腳類確定復原分開；隔離效果不代表實裝眼神驗收。核可R1v011、Rig/Bones與Production保護保持，不自行修改既有眼眶／視軸。

2026-10-09｜使用者明確修改眼球安裝方向：朝左右側，取代前向視軸保持條件。僅眼球表面朝向調整，眼眶／球心／球徑／Rig維持；R2v002待使用者審核，不視為Production驗收。

2026-10-09｜使用者「決行此版」核可01R.2 v005：金色虹膜／收尖黑豎瞳，左右從純側向各朝前累計30°。升為Approved Working Checkpoint（Prototype），承接R1v011，保留R1与角度試作供回退。眼球本輪收束，不繼續旋轉或加細節；核可不等於完整凝視／遊戲PBR／動態或Production驗收。01S仍提案未開始。

2026-10-09｜01S審視完成，造型主要區域可先保留、必要功能尚未通過。先排查共同接地／映射／driver，再定位閉口相交，不用新的Morphology Pass掩蓋功能問題。01S.1提案待審；工作基準R2v005、Production 01J、Rig/Bones硬鎖保持。

2026-10-09｜使用者接受R2v005整体造型收束，接地暫緩。轉向唯讀咬合確認，不重啟外觀精修，不自行解除Rig／牙列／內口腔保護。閉口角度或局部內腔／牙列試修另提有限範圍待核准。

2026-10-09｜使用者「均同意判斷，進行下一步」接受B體態方向與1.5°閉合候選並授權合併驗證。新隔離Viewer已建立：每幀原動作後頸Skeleton-X+12°／頭-4°、jaw中性基準改1.5°，T可切原版／候選。原版及候選各六模式120幀共1440幀，牙面交叉max0；候選軟面max1，僅既有後口配對(3573,2487)，idle／walk／run／turn皆120幀存在、bite96、roar67，並非完整口腔修復。Rest一致、spine2差0、來源hash保持；選取視圖未見明顯新裂口。獨立審視通過有限合併測試；新原生Godot Viewer等待使用者互動審核。沒有真輸入／完整遊戲驗收，MCP未連；ground DEFERRED、原內口腔／牙列仍保護。最新核可Mesh仍R2v005，Production仍01J。報告../ninola-01S/2026-10-09-combined-viewer-v001/index.html。

2026-10-09｜使用者「覺得好，就這樣定版」核可01S合併體態／咬合基準：R2v005 Mesh＋B姿態（頸Skeleton-X+12°、頭補償-4°）＋jaw中性閉合1.5°。本輪造型與動作基準收束，後續沿用此組合；來源Blend不烘焙Pose、不改Rig／Rest。後口內腔既有交叉仍OPEN，接地DEFERRED；Production仍01J，沒有正式整合或Commit／Push／PR。
