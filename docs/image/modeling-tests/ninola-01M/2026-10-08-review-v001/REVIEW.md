# Ninola 01M — Head / Neck / Jaw Read-only Review

2026-10-08。審視基底為使用者已通過的01L.3 v002；正確隔離01L3_Three_Toe_Volume_Reconstruction，不顯示歷史Mesh。8個唯讀取景：side／silhouette／front／top／bottom／front threequarter／rear threequarter／full body side。完整evaluated mesh無face mask；畫面邊缘只是camera crop，不作幾何缺陷。未儲存.blend、未改pose／keys／Rig或模型。

## 判斷

最高優先是下顎外皮量體分布與後端收束：側面前端快速落入厚顎身，腹側向後斜降並形成方厚終端，像獨立懸掛楔塊；正面下巴方厚，三分之四也有相同塊感。這是多視角視覺判斷，不把陰影／開口當已證實破洞或錯誤骨架。Concept #2側面與#5頭部目標顯示更有層次的顎身／後顎銜接；但圖中張口角度不同，不直接沿圖描摹腹線或計算縮放量。

頭部：吻部鈍圓、前後量體過渡與眼眶／後顱層次較弱；Top可見前端较窄与後方較寬，但不足以只據此認定整頭太窄或太小。整頭等比放大並非本輪首選。頸部有支撐巨大頭部的厚實量體，頭頸上緣與下側仍有硬轉折；暫不與下顎同時重塑。不要將Low-poly平面感本身當錯誤。

全身視角：主要問題不只是牙齒／材質細節，現有下顎輪廓在全身尺度仍顯得獨立。保留怪獸強壯感，改善顎身前後節奏與腹側收束，較直接回應Concept。尚未判定精確肌肉走向，不宣稱真實獸腳類解剖認證。

## 參考與限制

主視覺目標：五張使用者AI概念圖中#5整體設計、#2 head／neck／jaw sheet；其他图為交叉核對。未warp原圖。圖上肌肉、骨架標籤與ROM數值不是可靠實測資料。
搜尋並讀取Smithsonian官方The Nation's T. rex：其wide heads／thick counterbalancing tails說明僅用作整體頭尾平衡背景，不能證明這次建議的下顎輪廓或具體肌肉分布。https://naturalhistory.si.edu/explore/dinosaurs-fossils/nations-t-rex 。NHM頁面全文讀取timeout，未以其未讀全文支撐方案。沒有匯入網路媒體。

原型無Shape Keys；原Trex的15個keys以身體量體為主，沒有現成jaw open／closed key。jaw骨有原存姿態，本輪未修改。已有資料不足以提供同一模型閉口／大張口對照；目前是原存輕開口外觀，不能以此宣稱咬合、最大開口或變形通過。必要時另列evaluation copy暫時pose測試範圍，原件与rest bones保持；目前未做。

## 01M.1 提案 — Lower Jaw Ventral Mass Blockout

基底：通過的01L.3 v002另建工作副本，保留三趾成果，不回退K6，不用K7。
目標：改善下顎前端→顎身→後端外皮量體連續性；減少方厚下巴與後端直落吊塊感，保留強壯咬合視覺。
候選修改範圍：下顎腹側／外側皮膚，下巴下緣到後端外形；必要的局部拓樸重建先按真實vertices／materials／bone influence界定mask。不是固定百分比縮小，也不以示意綠線逐點雕刻。若mask牽涉受保護口緣／齒列，停止該部分並先回報範圍。
保護：Rig／Bones／rest／pose／hierarchy／joint center、Trex原件與keys、上顎／頭顱、頸部、眼睛／牙齒／齒列／口腔邊界、全身与足部。jaw bone起點在圖中由實際camera matrix投影，不是概念關節位置；綠線只是量體方向。
工具：隔離原型、局部Mesh blockout；視需要移動或重建外皮表面。新表面若需weights插值，只作prototype，必須標明未Production驗收。
風險：過薄失去怪獸強度、只改善側面而正面變窄、後端收束過度產生空隙、固定齒列下無法達成某些Concept比例、口腔／變形接口破壞；不以變動骨架補救。
驗收：固定原pose與相同camera／lighting的side、front、threequarter、bottom、silhouette與full-body對照；檢查量體連續性、前後厚度節奏、仍有強度、非修改區域保持與重開hash／資料核對。張閉口動態另驗，不能把static通過當Production通過。
Rollback：01L.3 v002原件hash保持；新試作另存01M1日期版本。不是替換01J。

完成下一轮blockout後，提供局部＋廣視角、技術驗證、視覺點評與保留／否決建議；不無限追修頭部。吻部／後顱層次、頭頸承接與動態咬合列RVI-004回看。此刻僅審視與具體提案，01M.1未執行。

Operator與Reviewer為同一執行者，未作獨立審查。證據：captures/inspection.json、capture_settings_01L3.json、concept_comparison.png、jaw_direction.png、verification.json。無Commit／Push／PR。
