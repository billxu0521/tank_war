# Ninola 01M.1 — Lower Jaw Mass Blockout

2026-10-08；本輪交付v002，待使用者審核。使用者核准實作並強調：頭部是識別與攻擊的重要區域，必須可信服、避免滑稽，以Concept設計為方向；在Rig／Bones硬鎖下大幅Mesh重塑可接受。本輪仍執行已提案的局部下顎blockout，未擅自擴大修改頭顱／牙齒／口腔。

## 實際變更

從通過的01L.3 v002另建01M1_Lower_Jaw_Mass_Blockout，保留三趾成果。依實際jaw=1權重與d_tan／d_belly材質圈定外皮，排除牙齒、口腔、非jaw面共享端點；重合來源點同步移動避免分裂。調整513個頂點，影響198面；沒有新增／刪除頂點或面，保持10444點／6308面、原weights與material assignments。
下顎腹側前後厚度漸變、後端下缘抬升並略向前收束，腹側橫截面輕收下側角。不是整顎等比縮小、不是jaw旋轉，亦未改開口角。最大world位移約0.228941來源單位。

v001側面吊塊感減少，但後端偏薄。v002保留更多後端厚度並輕收腹側側角。曾試較強橫向收束，局部面normal-dot檢查失敗，未儲存；降低幅度後檢查通過。v001保留試作，本轮交付v002，不將版本較新等同採納。

## 造型點評

**局部改善成立，整體頭部信服力尚未達標。**
側面／silhouette：後端厚楔吊掛感減少，腹側走向更連續。保留一定後顎量體，沒有只削成薄條。但顎身上緣、後端與臉頰關係仍較機械化；不能把收束本身當肌肉解剖改善。
正面：下側角略收，垂掛高度減少，但仍偏方厚／平底，吻部鈍圓與前後頭顱層次未改，臉部可信服感改善有限。
前三分之四：下顎較緊湊，仍有粗面折線；下顎收束後顯露原有前肢finger claw。v001 pixel raycast確認face3888 material d_claw、finger1_l／finger2_l，不是新牙齒或破面，不為藏爪而調手／pose。
Top：頭顱形體保持，不把 unchanged view稱為改善。Bottom：外皮收束可辨，但固定口腔／齒列仍限制可改量體；無張閉口驗收。
後三分之四／全身：前後顎的獨立塊感減少，整體頭顱仍較圓鈍。全身、頸部、後肢與L3足部保持；不宣稱整頭已接近Concept到可最終收尾。

Concept #5／#2顯示的威懾感來自吻部、眉眼／後顱層次、下顎後端與齒列的整體关系。單獨調腹側只能處理一部分。Concept張口角與來源輕開口姿態不同，獨立取景只作讀形對照，不推算高度／縮放百分比。
8個視圖實際查看；與01M review來源固定camera matrix／scale／lens／resolution／light／full mesh設定一致。無历史Mesh叠加，無face mask。Operator／Reviewer為同一執行者，非獨立審查。

## 技術驗證及限制

新檔：blender/ninola/working/01M1/2026-10-08-v002/ninola_01M1_jaw_mass_blockout.blend。
SHA-256：97b38435343c4312e16f5bf3f81e3ee892158f1ce201a1716f75ba43c1e96674。

重開核對：513點修改mask一致；其餘rest／evaluated world座標完全一致；全部拓樸／材質分配／weights及Object matrix一致。Rig bones／hierarchy／rest／pose／matrix、原Trex geometry／weights／15 keys保持。牙齒／齒列／口腔、頭顱／頸部、全身与足部protected vertices保持。01J／K6／K8／L1／L2／L3來源hash未變。
局部修改面近退化0、相對來源normal-dot負值0，inverse-bind error約5.33e-7。這些檢查不等於全模型無自交／Production manifold認證。

攻擊模組、閉口咬合、張口行程、口腔接口／動態變形未驗收；本輪Rig與pose未動。原型既有L3工程限制仍在，不因本輪拓樸不變而消失。01J仍Approved Production Checkpoint；新檔不得直接取代Production。

## 取捨與下一提案

建議將v002保留為「局部下顎改善候選」待比較討論，尚不升為已通過基底。01L.3仍為最近使用者通過的rollback。不要靠繼續削下顎來補足整頭識別。
下一提案01M.2 Head Identity / Craniofacial Mass Blockout：以吻部→眉眼／後顱→後顎的整體層次為單一目標，可採較大幅外部Mesh重塑，在硬鎖骨架下建立更明確凶悍讀形，避免三個分散小修pass。先提出侧／front／top示意與真實edit mask；是否承接M1由使用者此次審核決定。若需連帶調整口緣、齒列或眼部，明列範圍，不沿用本輪保護假設隱性擴張。
驗收將包含局部及廣視角的識別／壓迫感，而非只線條更平順；必要攻擊張閉口evaluation範圍另列，不解除Rig／Bones鎖，不在原件改pose。本轮尚未執行01M.2或動態測試。

工作狀態與模型歷史log已更新，RVI-004保持OPEN。無Commit／Push／PR。證據refined-v002/build_record.json、edit_mask.json、verification.json、camera_verification.json、captures/；比較入口comparison.html。
