# 三前趾重建 — 修改前示意與最小方案

2026-10-08。使用者授權製作示意，沒有授權或執行下一個Mesh pass。K6 v003為基底；01L.1的共享加厚、01L.2的表面刻溝不承接。

## 圖的讀法

左：K6實際模型的單腳上視投影，橘色標示過度連成板面的趾體／趾根區域。
右：同一底圖上的範圍草圖。綠色=toe1、紫色=toe2、黃色=toe3（依既有bone名稱定位，不作解剖鑑定）；三塊色區呈現各趾逐漸收束到爪的量體方向。橘色斜線區預計縮減／重建為向前端打開的局部趾間空隙；後侧保留共同趾根。不是在厚板上刻兩條溝。
兩側原底圖完全相同，沒有生成或儲存修改後Mesh。色塊是規劃範圍，不是精確形狀、可直接執行的edit mask或已驗證骨架容納。

藍色虛線／圓點投影自K6現有pose bones的head/tail，hard lock；青色投影框為現有pedal shaft保留點的凸包輪廓，非全表面精確mask。紅圈為實際爪尖；紅方為歷史六個ground anchor樣本的平均投影位置，圖中顯示一個樣本標記，完整索引／坐標在landmarks.json。
骨架／joint／rest／pose完全不變。Claw及ground anchors是本方案保留的外部位置，不是永久骨架鎖。趾間皮膚輪廓可以重塑；不要求每一處原skin silhouette都固定。
本次PNG由原生SVG確定性渲染，不使用AI重繪骨架或現狀圖，沒有將生成畫面當真實模型證據。

## 建議下一步 — 01L.3 Local Toe Volume Reconstruction（未執行）

從K6另存prototype，保持整腳長寬、三叉總跨度、足段核心與爪尖／接地樣本；重新組織趾根末端及三趾中段的外部表面，使三條趾體各自有側壁／背側／底部量體，再接到既有爪根。只在趾間改局部輪廓、移除或改接板狀連接面；不是沿用原板面增厚／刻溝，也不是將三趾做成三個互不相連物件。
先建立粗量體與開放趾間，視角確認後才處理必要的claw-root連接，不做每趾精修。皮膚可在固定骨架周圍重建，必須檢查骨架容納、真實共有邊界與sole保護；單張上視圖不能驗收。局部拓樸重建可列入該方案，新增weights屬provisional，不能稱Production蒙皮。

驗收：Top／Front 3/4能由根至爪讀出三條趾體，趾間空隙向前打開；Side三趾各自漸收而非共同厚楔；Front與Rear核對底面／共同根部；Full body確認未改整體比例。Rig、原Trex資料、爪尖及接地樣本逐項核對。不增加新硬稜、明顯裂口、浮離爪根或削掉底部支撐；自交／變形仍另驗證。

風險：固定腳長寬與骨架可能限制趾間空隙深度；如果實際邊界無法安全接合，停止受影響部位並回報，不自行縮脚或移骨。圖中空隙及toe-root分叉只是初始意圖，不能直接把畫出的色塊當數值幾何。
比例疑慮（腳部偏大、01K肢段偏小、相對比例）RVI-003 DEFERRED。本輪不處理踝部或rear digit、不調骨架、不做Production integration／cleanup。

## 本次交付與狀態

toe_rebuild_scope.png：已實際檢視的可讀示意。
toe_rebuild_scope.svg：可編輯、內嵌原圖的獨立向量版。
landmarks.json／manifest.json：真實投影與來源hash；示意位置與實際骨架坐標明確分開。
01L.1／01L.2保留歷史試作，不承接其造型；K6仍Selected、01J仍Approved。Canonical文件和模型歷程log已同步，沒有新修改模型、Commit／Push／PR。

## 2026-10-08 Concept／研究核對後補充（優先於草圖的直條輪廓）
草圖三塊長條不是final toe shapes，長切口不是預定等深縫。依Concept腳部細節與Australovenator復原資料，目標為厚實趾體、漸收／趾節起伏及自然V／Y分叉缺口；保留近端共同支撐，不切至joint起點／pedal核心。不直接移植他種恐龍比例。詳../2026-10-08-concept-anatomy-review/ASSESSMENT.md。01L.3仍未執行。
