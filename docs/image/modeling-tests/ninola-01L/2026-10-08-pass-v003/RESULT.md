# Ninola 01L.3 — Local Toe Volume Reconstruction

2026-10-08；v002為本輪交付，待使用者審核。從01K.6 v003獨立重建，不承接01L.1／01L.2，也不使用01K.7。

## 結果與造型判斷

三趾分化目標已建立：移除原共同前趾板面，形成三份各有背面、側面、底面的趾體；共同近端保留支撐量體，趾間開放為向前展開的V形空隙。趾背加入寬窄與高低變化，漸收至原爪。這次分化會實際改變輪廓、遮擋與負空間，與前版表面刻溝不同。

Concept matching仍為局部接近，不能宣稱完成。Concept #2有厚實趾節及向下彎曲的爪；L3接近「共同根部→三趾→爪」的結構讀形，但趾節仍較規律、表面偏機械化，原爪直而呈寬楔形。固定爪及接地點限制了本輪可達到的側面弧線。
Concept #5仍為整體怪獸量體方向；AI概念圖不作精確解剖、尺度或骨架依據。先前搜尋的Australovenator足部復原只提供三趾／軟組織／趾墊的定性輔助，本輪未新增解剖認證或修改Rig。

## 多視角點評

| 視圖 | 改善 | 保留問題 |
| --- | --- | --- |
| Top | 三趾扇形與兩個趾間負空間可辨 | 中趾仍較直長；全腳與肢段相對比例未調整 |
| Front／前三分之四 | 每趾有立體量體，厚板感減少 | 趾節起伏仍較規律；共同趾根與足段接口有硬唇／階差 |
| Side／Silhouette | 趾背有節段節奏，不再共同扁板 | 爪曲率、趾底自然度及既有接地小突片仍待回看 |
| Rear／後三分之四 | 原後趾、足段與接地支撐保留 | 踝與近端收束硬折未處理 |
| Full body side | 整體姿態、肢段與原爪位置保持 | 不能據此判定腳部與01K肢段比例已合理 |

8張review captures已實際查看，正確原型隔離；不疊加歷史Mesh。K6／L3攝影matrix、scale、lens、resolution、lighting與display mask核對一致；側面K6採review-v001/captures/reframed。非三分之四的足部圖使用一致區域face mask，上緣裁切不可當模型破洞；三分之四及全身圖使用完整evaluated model。Concept獨立裁切，非同尺度／視角，不推算縮放百分比。Operator與Reviewer為同一執行者，沒有獨立審查。

## 實際資產及驗證

模型：`blender/ninola/working/01L3/2026-10-08-v002/ninola_01L3_toe_volume_rebuild.blend`。
Object：`01L3_Three_Toe_Volume_Reconstruction`；只此原型可見，歷史物件保留但隱藏。
SHA-256：`34e6608bfb04e73a271199dbd3f4f684545bf7d7cdc8f6e3282d3d970c44c6fd`。

移除260個前趾皮膚面，新增1410面／678點；總10444點／6308面。v001三趾成立但偏直梁，本輪v002調整趾節量體並處理局部Boolean細碎面；v001只保留試作記錄，不是目前交付。

重開核對原來源9766頂點rest座標、按bone/group name比對weights、所有保留面及material index完全一致；Rig的bones/rest/hierarchy/pose/matrix及Trex geometry/weights/15 keys一致；原claw面未移除。01J／K6／K8／L1／L2來源hash皆未變。
新皮膚的30個來源接邊方向衝突0，新增面內部方向衝突0，inverse-bind誤差約1.885e-7。原claw／toe tips、接地錨點、後趾、pedal shaft核心保留；未等比縮放或搬移整腳。實際使用面足部bounds的Y/Z與原件一致；正側內緣X由0.402398變0.408935，屬重建皮膚局部輪廓變化，不能宣稱全部XY輪廓逐點相同。

工程限制：新增趾皮膚weights是暫用插值；6個近退化小三角面仍存在。原封閉爪底蓋依保護要求保留，skin／claw幾何接口可能nonmanifold／存在內部蓋面；未完成全模型自交、變形、動畫接地、Shape Key Compatibility或Export驗收。舊板面未用點保留作來源對照、不參與顯示。這是造型原型，不能直接覆寫01J。

## 取捨與下一步

建議保留01L.3 v002為足部區域暫時候選，待使用者審核；K6仍為已選整體rollback基底，01J仍唯一Approved Production Checkpoint。不要因新版號自動提升為approved。
本輪不再追修腳部：三趾結構已有可評估結果，未解的root銜接、趾節自然度、爪弧及相對比例繼續記RVI-003；接地與動態記RVI-002。若審核認為三趾量體仍不成立，再明確界定下一個局部目標。
若接受這個區域落地，建議下一個工作為Head／Neck／Jaw現況唯讀審視：比較閉口／張口的下顎厚度與腹側輪廓、頭頸承接、整體頭顎比例，再提出單一blockout修改範圍。未執行新區域，亦未開始Production Cleanup／Integration。

證據：refined-v002/comparison.png、captures/、build_record.json、verification.json、camera_verification.json、edit_mask.json；比較入口comparison.html。Canonical STATE／DECISIONS／RVI／Asset Index／DISCUSSION_LOG已更新。無Commit／Push／PR。
