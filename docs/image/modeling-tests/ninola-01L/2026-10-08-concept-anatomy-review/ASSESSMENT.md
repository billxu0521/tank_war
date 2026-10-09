# Ninola 足部Concept與獸腳類復原 — 方向核對

2026-10-08。唯讀視覺分析，沒有Mesh／Rig修改。

## Concept本身的目標

重新檢視使用者五圖中的#2腳部細節、#3三視圖／足部關節細節、#5整體形態。#5用於怪獸整体重量感，#2提供本輪趾體較清楚的局部外觀，#3作方向交叉核對；不聲稱使用者另選某圖為唯一新權威。
共同特徵：足部近端厚實；三前趾各有可辨的背側／側壁、趾節起伏和漸收輪廓；趾根仍相連、空隙出現在向前分叉處；爪是由趾體支撐的彎曲尖端。外觀要保留裝甲式Low-poly怪獸感，不做三根等寬細管。
各圖腳部姿態／爪形與細節並不完全一致，圖上骨架／ROM／肌肉標籤不是科學證據。不以跨圖像素差異設定新縮放百分比。

## 搜尋資料與實際檢視範圍

1. White et al. (2016), The pes of Australovenator wintonensis: analysis of the pedal range of motion and biological restoration. DOI 10.7717/peerj.2312。
[PubMed摘要及圖說](https://pubmed.ncbi.nlm.nih.gov/27547591/)。核對CT／emu軟組織比較復原方法及Fig.12（外部foot／pads）與Fig.13（有軟組織ROM）圖說；出版社全文與部分PMC入口本次讀取失敗，沒有宣稱完整閱讀全文。
可採定性依據：復原需包含趾墊與爪鞘及軟組織，而非骨條直接加皮；不能直接以bare bone的ROM推斷完整腳。

2. White, Cook & Rumbold (2017), A methodology of theropod print replication utilising the pedal reconstruction of Australovenator and a simulated paleo-sediment. DOI 10.7717/peerj.3427。
[PubMed與Fig.2圖說](https://pubmed.ncbi.nlm.nih.gov/28603673/)，[原研究Fig.2](https://cdn.ncbi.nlm.nih.gov/pmc/blobs/3e46/5463970/fa8d74d8f441/peerj-05-3427-g002.jpg)。實際在瀏覽器查看Fig.2：F骨架、G生物復原、H皮膚覆蓋、I彈性樹脂cast及後續模擬步驟。看到三條可辨趾體與近端連接量體，不是直管或長平板；讀取可檢索正文中不同運動／基質造成印跡差異的說明。
可採定性依據：觀察骨架→軟組織→skin整體轉換；腳印不能當成唯一靜態外形模板。

Australovenator不是T. rex，也不是Ninola的精確比例模板。只參考趾體／趾墊／根部連接與爪的結構邏輯，不移植趾長、趾寬、ROM、表皮紋理或腳印比例。這些復原本身含推斷，不等於直接保存完整活體腳。

## 方向是否符合目標

結論：三趾實體量體重建＋局部趾間空隙符合Concept方向；先前示意不應照輪廓直接建模。

| 修改方向 | 接近Concept的作用 | 必要限制 |
|---|---|---|
| 把共享前趾板面重組為三趾的背側／側壁／底部量體 | 從一片楔塊，變成能由根追到爪的三條厚實趾體 | 不是整面抬高；不是三根等寬管；保留各趾有差異的漸收／趾節節奏。 |
| 在可辨分叉處形成自然V／Y形趾間缺口 | 提供Concept中三趾之間的負空間與輪廓分離 | 不把長直槽一路切入足段或joint起點；保留近端共同軟組織及支撐量體。 |
| 趾體逐漸收束至既有claw root | 爪由厚趾端承接，而非板面附加三個尖三角 | 本輪爪尖／接地點保持；爪弧更改另列範圍，不能宣稱本輪完全匹配Concept爪形。 |
| 頂／側／3/4共同驗收 | 保留Concept重量感，而非只在Top看出三條色帶 | 先粗量體，不先加鱗片、溝紋或趾節細雕；骨架／pose硬鎖維持。 |

需要修正上一示意的讀法：長條色塊只代表趾體方向，不能視為最後趾寬；橘色長切口只表達需要縮減共享面，不代表應挖成等深／等寬長縫。正式方案改用較自然、止於分叉區的缺口，保留厚實近端與各趾支撐量體。
這是依Concept及研究資料作的設計推論，不是骨架與soft tissue已通過科學或動畫認證。既有game rig是必須保持的約束，不是復原研究給出的精確解剖骨架。

## 下一步與狀態

01L.3若後續獲准：先建立三趾粗量體及較自然的分叉，檢查側壁／底面和與claw-root的實際連接，再多視角比Concept。不沿用L1厚板或L2溝槽表面，不直接照長條示意建模。
模型未動，01J Approved、K6 Selected不變。整腳／01K肢段比例RVI-003 DEFERRED；未判定腳部偏大或肢段偏小哪一項主因，不縮放。未開始01L.3、Production Integration或Commit／Push。
