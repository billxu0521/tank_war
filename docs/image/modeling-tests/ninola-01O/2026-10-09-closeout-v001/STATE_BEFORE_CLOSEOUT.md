# Historical snapshot before 01O closeout — not Current State

# Ninola Current State — 2026-10-09

## Environment / authority

Repository billxu0521/tank_war；Permanent Worktree `/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola`；Branch `asset/ninola-authoritative`。唯一Canonical Working Documents為本ninola-workflow目錄。
Migration已完成：63個allowlist檔案、65,590,064 bytes來源與本地SHA-256一致，僅匯入01J／K6兩份.blend。來源Checkout／Archive未修改；詳細來源見asset-index.json。

## Current assets / decision status

01J Approved v004仍唯一Approved Production Checkpoint，未完成Godot整合；遊戲入口models/trex_hd.glb。01K.6 v003為Selected Morphology Candidate與01K暫時落地／rollback基底；01K.7 Rejected、Archive-only。01K暫停；K8 v004保留為未採用PARTIAL試作。L1／L2因加厚不自然、分化無有效用意不承接。

已通過的足部工作資產：01L.3 v002，`blender/ninola/working/01L3/2026-10-08-v002/ninola_01L3_toe_volume_rebuild.blend`，隔離Object `01L3_Three_Toe_Volume_Reconstruction`。使用者已核准方向與執行；模型完成，使用者已看過局部及廣視角並正式通過，作足部暫時落地點；K6保留來源／rollback，01J仍Production。SHA／來源／角色見asset-index.json。

## Current pass outcome

目前工作基準為01N.1 v004：使用者已審核通過v004；保留已接受v003造型及完成繞序修復；01M.8 v001保留核可回退，01M.7 v003保留結構來源及既有遊戲測試基準，取消M6討論錨點；M6只保留歷史及原未通過紀錄。M3 v006留歷史回退，01J仍Production、L3 v002仍已通過足部。

依新授權完成01M.7 v003結構粗模：`blender/ninola/working/01M7/2026-10-09-v003/ninola_01M7_whole_cranial_blockout.blend`；Object `01M7_Whole_Cranial_Blockout`；10954頂點／6784三角面，比M6少244。眶區上眉／凹面／頰部有主次，後顱截面略加厚、吻端底靠近固定口緣以減少台階；仍須用正面凝視判斷核心可讀性，不宣稱Concept完成。v001／v002保留探索，v003獨立審查通過結構粗模方向，但正面眼神未通過，使用者已選為目前基準；正面眼神仍未通過。没有新增細紋／鼻孔／頭刺／全頭retopology。

Rig／Trex keys與pose、原source座標／weights、5999保留面／材質及33固定口緣／頭頸點核對保持。GLB只作evaluation，Godot45骨與M6同套姿態差0；Blender回放rest映射3.46e-6／pose2.31e-6。原軟面相交21／1／0与齒面5／0／0未修复。MCP實際觀察後完整恢复L3 scene／active／selection／viewport與dirty true，未儲存原件。

比較及點評：../ninola-01M/2026-10-09-pass-v007/index.html、RESULT.md；dynamic為v003完整證據，dynamic-v002仅早期匯出／匯入歷史。新增Library風格化研究已讀，只作參考；重現Concept優先，再用有節制大面組織增加說服力。不以工具成功或面數低當造型通過。

## Production / constraints

Production／Prototype雙軌；K6／L3／M1／M2／M3／M4／M5B／M6原型沒有Production Shape Keys。Rig／Bones Hard Lock保持，來源rest／pose不改，evaluation副本可作核准動態測試。本輪核准上部整體頭皮／眼眶重塑試作；M1下顎、原齒列／舌／內口腔及固定頭頸／口緣保持，牙齒／舌、爪形與足部錨點保持。
L3足部新皮膚weights暫用插值、當時6個近退化小三角面、原claw底蓋與新skin接口尚未工程清理；未完成topology／weights／Shape Key Compatibility／deformation／animation／export驗收，不可直接覆寫01J。H=.8、I=1、I1=1、J Foot Proportion=1、Ground=.8及核准值保持。
真實獸腳類結構提供參考，怪獸化量體與壓迫感是設計意圖；五張AI Concept是視覺目標而非解剖證據。完整Production Reference Pack與動畫／行為參考仍未完備。

## Open issues / next action

RVI-001／002／003／004保持OPEN。M7隔離完整遊戲初測已完成：真遊戲靜態外觀獨立審查通過，實體鍵盤移動／咬擊反應有固定telemetry證據。持續衝刺、Boss實玩吼叫、完整碰撞、多人及Production未驗收。01N下顎本輪已收束，01O頸根／肩胸／軀幹唯讀Fresh Review已完成；01O.1已授權並完成獨立粗模v002，PARTIAL待使用者審視，N1 v004保持核可基準；不因週末期限跳過全模型分區審視。證據：../ninola-01M/2026-10-09-game-review-v001/index.html、COVERAGE_AND_NEXT.md。
使用者认为未来头型可能涉及目前鎖定區域、甚至重做，記錄為可討論的可能；本次未解除Rig／下顎／齒列／原內口腔等保護，未執行全面重做。

知識庫与原Checkout唯讀。唯一Current State仍為本檔；DISCUSSION_LOG僅模型修整技術歷程。Ninola整體完成後需完整Workflow Retrospective。branch保存歷程，main另挑選；AGENTS排除提交。無Commit／Push／PR或正式模型替換；M7有真玩家移動／咬擊反應證據，M8尚未重跑。

## 01M收尾：01M.8識別元素已核可

使用者要求先加回棘刺等個性化元素再收尾。以M7為來源完成M8 v001獨立候選：16根頭部後傾棘刺，新增128tri，總6912tri；所有M7原座標／權重／面／材質、45骨與Trex keys／pose核對不變。M8核可成果保留為N1來源／回退；M7留來源與歷史實玩證據，未替換Production。非像素化作造型判斷；M8未重跑真遊戲實玩。點評與圖：../ninola-01M/2026-10-09-pass-v008/index.html。01M本輪收尾，RVI-004仍OPEN。依使用者最新指示，01N改為下顎，已完成唯讀Concept／多視角審視及01N.1三段結構示意，未修改模型；頸根／肩胸／軀幹順延01O。完整提案見../ninola-01N/2026-10-09-review-v001/index.html。

01N.1設計包已完成：../ninola-01N/2026-10-09-schematic-v001/index.html。使用者強調顎身有厚度、非薄片／矩形；同一三維包絡四視圖與真jaw軸／固定共點定位已建立，外皮試作已執行至v003，獨立造型未通過，保持PARTIAL，使用者已接受N1 v003為工作基準；固定接口與完整動態未驗收。

## 01N.1試作結果：使用者已接受v003，保留限制

v001局部收束不足、v002厚側壁但接口鋸齒、v003增加collar與腹面轉折仍有直板／托盤與尖瓣，獨立造型審查不通過。最後討論版本v003，6906tri；使用者最新已接受N1 v003，升為工作checkpoint；M8保留回退，獨立審查未通過意見留歷史。27固定接口、6709非外顎面及Rig／keys／pose核對保持。既有Godot姿態回放完成，非新實玩；sweep0軟面相交旗標21→22，完整咬合未驗收。下一建議先診斷固定口緣到外壁的連接排列，本輪停止追加修模。報告：../ninola-01N/2026-10-09-pass-v001/index.html。

使用者提出未來可能讓頭／下顎加入適度多邊形元素以契合身體／尾部；先記為全身風格統整待比較，未選定或實施頭部角面化。

## 最新接口診斷

01N1 v003使用者接受，以非像素化為準。本輪完成固定口緣／新外壁唯讀診斷：27固定位置無缺失；抽查大張口突起實為保留牙齒／口腔面，不能統稱新破片。新外皮內另有21條面繞序不一致邊，臨時顯示僅反轉12面可清為0，來源模型未修。下一建議小範圍修繞序並有限驗證，保留已接受大形，然後收束01N接01O。RVI-004仍OPEN，無牙列／Rig解鎖。證據：../ninola-01N/2026-10-09-interface-audit-v001/index.html。

## 最新修復：01N.1 v004

使用者授權的12面繞序修復已另存v004，新外皮同向共享邊21→0；所有造型座標／權重／材質／Rig／keys保持。讀回、三姿態頂點delta=0、GLB匯出與Godot隔離匯入通過，獨立技術審查通過。工作版本v004，v003保留核可來源／回退；尚未Production、完整咬合或新實玩。RVI-004此局部繞序項已修，其餘仍OPEN。下一建議收束01N、開始01O頸根／肩胸／軀幹唯讀審視，其後01O唯讀審視已完成。報告：../ninola-01N/2026-10-09-winding-fix-v001/index.html。

## 最新：01N核可收束／01O唯讀審視完成

使用者審核通過01N.1 v004，保持目前工作checkpoint，非Production替換。01O以唯一隔離N1 Prototype取得11張多視角與3張灰模，骨鏈／keys定位与15個索引模型SHA核對完成；模型未修改。頸根肩胸分塊与前胸腹側垂墜是主要候選問題，保留厚頸胸腔與01B歷史成果；獨立審視支持下一輪設計討論，不是此區完整驗收。

01O.1共同截面的多視角包絡示意已獲核准並完成，待使用者審視；保持頭顎／牙列／眼／頭刺／足部、前肢與尾部及Rig硬鎖，不直接改模。不重啟頭顎精修或全面加厚。報告../ninola-01O/2026-10-09-review-v001/index.html。其後前肢手→骨盆上後肢尾根完整尾巴→全身比例與風格→RVI必要回看。RVI-001～004仍OPEN。

## 最新：01O.1設計示意完成，待審

使用者核准嘗試共同包絡示意。完成同一8截面3D包絡的側／頂／左右3/4與全身比較，以及同尺度截面圖；頸肩逐步展寬、背線緩轉、喉底向前胸腹線連續過渡。45骨與真前肢骨根已定位，894個皮膚候選／391共點候選只作範圍參考，未解算固定接口或編輯mask。15個索引模型SHA一致，N1 v004仍基準，未修改Mesh／Rig／keys。報告../ninola-01O/2026-10-09-schematic-v001/index.html。下一建議接受方向後獨立粗模試作；此步尚未執行或授權，RVI與其他保護維持。

2026-10-09｜01O.1獨立審視通過設計討論；胸後端漸接、避免桶身及前肢皮膚接口列實作前條件。粗模試作尚未執行，N1 v004保持。

## 最新：01O.1 v002有限粗模，PARTIAL

使用者許可試作；v001只7組座標未有效測試，v002重新界定主權重外殼，195候選面／67固定共點，改61組座標（370頂點索引）、最大位移.12，11136頂點／6906tri不變。頸側局部改善，前胸吊塊與頸肩分段仍在，獨立造型不通過，保留未採用試作；N1 v004仍核可checkpoint。非目標面座標、weights／材質／topology、45骨與Trex keys／pose核對保持。讀回、pipeline無issues、三個既有姿態保護點delta0、MCP繞視／場景還原完成；未完整頸動態或新實玩。來源15索引資產hash保持。報告../ninola-01O/2026-10-09-pass-v001/index.html。下一先看局部改善与未覆蓋區域，續作前定位前胸與頸肩的固定／可動点，不直接加大位移或解除保護。

## 最新：01O.1否決／01O.2 v003收腹候選

使用者明確不核可O1，頸／軀幹暫沿用N1原形。按新綠圈黃線授權只收腹，從N1 v004另製O2 v001/v002/v003；v003腹線自然抬收、兩端漸接，獨立造型通過有限粗模，待使用者比較，N1仍核可checkpoint。改11組坐標（67索引），最大上提.22327，6906tri保持；非目標面、Rig／keys／pose、weights／材質／Topology保持。讀回、pipeline、三姿態有限回放、MCP還原與16既有模型hash核對完成。尚未Production／新實玩。報告../ninola-01O/2026-10-09-belly-v001/index.html。若核可收腹幅度，01O收束後續前肢／手唯讀審視；不強制再修已決定沿用的頸軀幹。
