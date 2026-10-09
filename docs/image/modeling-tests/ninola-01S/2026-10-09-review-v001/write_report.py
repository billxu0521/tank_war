from pathlib import Path
import json,hashlib
r=Path.cwd();p=Path(__file__).resolve().parent;w=r/'docs/image/modeling-tests/ninola-workflow';m=json.loads((p/'audit_metrics.json').read_text());ex=json.loads((p/'export_records.json').read_text())[0];check=json.loads((p/'export_readback.json').read_text());controls={(a['sequence'],a['frame']):a for a in m['original_Trex_control_foot_samples']};diff=max(abs(a['foot_min_height'][side]-controls[(a['sequence'],a['frame'])]['foot_min_height'][side]) for a in m['samples'] for side in ['_l','_r']);images=len(list((p/'motion').glob('*.png')))
report=f'''# 01S：全身一致性與隔離動態審視

結果：本輪審視完成，功能驗收 PARTIAL。核可工作基準仍為01R.2 v005，未改Mesh／Rig／Bones／正式資產。原Checkout的trex.gd及正式GLB已唯讀比對，與Worktree來源SHA一致；沒有修改原Checkout。

## 全身造型：可收束項與延後項

|區域|判斷|本輪處理|
|---|---|---|
|頭顎／眼球|新頭顎的粗塊面已能與身體共同閱讀；金色豎瞳及識別棘刺成立|保留已核可造型；正面凝視不是本輪必改|
|頸、軀幹、腹部|厚實量體與收腹成果可保留|按使用者決定不重開頸軀幹|
|前肢／掌指|短臂與小型手部維持主次|保留，不追加細節|
|骨盆、尾部|粗尾根到尾中段漸收有連續性|保留Q1，不重開尾部|
|後肢、足部|Concept與模型的股部／下腿／足掌比例仍有差異|RVI-001、003延後；先釐清接地功能，不用比例修形掩蓋動作問題|
|棘刺與全身风格|幾何塊面與棘刺節奏可先落地|不追加無限精修；Concept細節密度與比例差異留回看|

Concept圖與模型沒有完成相機／姿態校準，張口與腿部姿勢也不同。對比用於視覺主次與量體方向，不宣稱精確比例疊圖或完整解剖復原。此次分區重新審視已涵蓋主要區域；後續轉向必要功能驗證。

## 動作與接地

使用目前專案trex.gd（未改動作程式）在隔離Godot 4.7.2場景直接呼叫程序動作；測試平面y=0，有StaticBody碰撞並等physics_frame。行走4單位/s、跑步10單位/s、轉向4單位/s與0.6rad/s，各6秒；另做咬擊、吼叫、4段下顎掃描。24Hz姿態記錄，Blender回放行走類每隔一格量測，231個量測樣本，{images}張動作圖、14張全身静態圖與5個GIF。

- 行走／跑步／轉向的足部最低點分別約-0.91／-1.14／-1.08模型單位。部分支撐標記樣本也低於平面；靜止閉口約-0.017。測量包含腳／趾／爪權重點，不等同特定腳底接觸面。
- **原始Trex同Rig回放也有相同下探**，新舊所有樣本最大足高差為{diff:.3g}。這不能歸咎新頭型、眼球或近期Mesh修整，也不足以直接判定程式一定有錯；需先確認Godot原生結果與回放、根高度、骨座標／足底基準、IK與支撐／擺動標記。
- 步行／跑步／轉向回放已顯示後肢與尾部隨動；未完整驗收腳滑、全部地形、Boss急轉／碰撞或多人動態。
- 閉口下顎掃描有22組軟面、5組上下牙面的三角表面相交；較大張口樣本0／0。這只是面相交警示，不能當作閉合體穿透量、咬合間隙或大張口通過的證明。張口主量體仍可讀，不能把保留齒尖一概當成新外皮瑕疵。

## 優先順序與下一有限提案

1. **01S.1 接地來源診斷**：選walk/run/turn各一個問題幀與一個穩定幀，在Godot實際網格／骨姿態與Blender回放核對髖、膝、踝、趾、根節點與足底高度；比較Prototype與原Trex。先找座標／匯出／driver／足底基準來源，維持Mesh與Rig，不直接改形。
2. 接地來源釐清後，定位閉口22／5配對到實際面與區域，区分原口腔、牙列與新顎殼，不直接再重塑頭顎。
3. 正式交付前處理兩個無使用面的舊眼球材質槽。此處只記錄，未清理工作模型。

01S.1的驗收是能重現並解釋問題幀、兩引擎映射與基準一致、明確指出問題屬動作／接地或網格；若需修正，再提出有限範圍供使用者核准。不是立即以Rig或Mesh試錯修補。

## 驗證與限制

45骨Rest映射最大誤差{m['rest_mapping_error']:.3g}，姿態回放最大誤差{m['pose_replay_error']:.3g}；來源檔hash保持，Pose於記憶體還原，不儲存來源。GLB實際Ninola網格7007tri讀回一致，bind世界座標最近點最大誤差{check['max_nearest_source_bind_world_error']:.3g}。未更替Production，未Commit／Push／PR。

匯出初次讀回誤把Blender匯入器自建Icosphere骨架顯示shape當成GLB網格。直接解析GLB後確認三份評估匯出均只有Ninola且SHA相同；修正篩選後通過。保留initial-export錯誤檢查紀錄，不能再宣稱GLB混入歷史物件。隔離測試初次缺facet.gdshader，補原檔後程序採樣成功。

Pipeline仍指出d_pupil、Ninola_Iris_Gold_M6無使用面，**不是CHECK OK／正式交付完成**。export脚本尾端舊版CHECK OK輸出僅表示評估匯出結束，以export_records的pipeline_issues為準。無硬面數預算驗收。

桌面MCP本輪Not connected，未桌面繞看。這是隔離程序采樣與Blender回放，不是使用者真輸入、最新完整遊戲、PBR或正式整合驗收；不以已放棄的像素風要求重修模型。RVI-001～004保持適當OPEN／DEFERRED，造型核可不等於功能全部完成。
'''
(p/'REPORT.md').write_text(report)
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01S 全身與動態審視</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1200px}img{max-width:100%}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}a{color:#f2ce82}</style><h1>01S｜全身一致性與隔離動態審視</h1><p>審視完成／功能驗收PARTIAL。核可基準R2v005保持，未改模型或Rig。</p><p>全身主要區域可先保留；優先釐清接地，再定位閉口相交。原Trex同回放也有足部下探，不能直接歸咎新Mesh。</p><p><a href="REPORT.md">完整結果、量測與下一提案</a> · <a href="audit_metrics.json">原始量測</a></p><h2>Concept與核可模型</h2><p>視角姿勢未校準，不作精確比例判定。</p><img src="concept_comparison.png"><h2>行走／跑步／轉向</h2><p>隔離Godot實際程序骨姿態的Blender回放，非真人實玩。紅線z=0，數值同原Trex對照；尚待原生網格接地驗證。</p>'
for mode in ['walk','run','turn','bite','roar']:html+=f'<h3>{mode}</h3><img src="{mode}.gif">'
html+='<h2>下顎掃描</h2><p>閉口22軟面／5牙面相交警示；較大張口0／0不是完整咬合驗收。</p><div class="grid">'
for i in range(4):html+=f'<img src="motion/jaw_sweep_{i:03d}_head.png">'
html+='</div><h2>完整多視角</h2><div class="grid">'
for view in ['full_other_side','full_front','full_rear','full_top','full_left_oblique','full_right_oblique','head_body_context','body_style_close']:html+=f'<div><p>{view}</p><img src="captures/{view}.png"></div>'
html+='</div><p>桌面MCP未連線；完整遊戲／PBR／功能驗收未完成。下一提案01S.1診斷接地來源，未執行。</p>';(p/'index.html').write_text(html)
# Canonical current state remains one source.
s=(w/'STATE.md').read_text();start=s.index('下一提案01S：');end=s.index('\n## 保護',start);s=s[:start]+'''01S全身一致性與隔離動態審視已依使用者授權完成，以核可R2v005為基準。主要區域本輪造型回顧可先收束，頸軀幹／核可頭顎足尾不重開精修。全身14視角與Concept比較、隔離Godot程序walk/run/turn/bite/roar及jaw sweep、Blender回放／原Trex控制對照已完成。功能驗收PARTIAL：動作足部下探與原Trex幾乎完全相同，不能直接歸咎新Mesh；閉口22軟面／5牙面相交仍需定位。兩舊眼球空材質槽列交付清理事項，未改工作模型。報告../ninola-01S/2026-10-09-review-v001/index.html。

下一有限提案01S.1：先對問題幀核對Godot原生網格／骨姿態與Blender回放的根、髖膝踝趾與足底，釐清接地／映射／driver；保持Mesh與Rig。再定位閉口相交來源。01S.1未獲執行指示／未開始，不自動修模。原生真輸入／完整遊戲PBR與Production驗收未完成，MCP本輪未連線。Ninola整體完成後完整Workflow Retrospective約定保留。
'''+s[end:];s=s.replace('01S未開始','01S審視已完成、01S.1未開始').replace('下一提案01S全身一致性與隔離動態審視，以R2v005為來源；尚未獲執行指示／未開始','01S全身一致性與隔離動態審視已獲授權並完成；下一01S.1接地來源診斷待審');(w/'STATE.md').write_text(s)
with (w/'DISCUSSION_LOG.txt').open('a') as f:f.write('\n2026-10-09｜依核准執行01S全身一致性／隔離動態審視。R2v005保持，全身主要粗面量體與棘刺可保留，Concept比例差異不自動重開精修。現有trex.gd隔離平地程序姿態回放，腳部walk/run/turn最低約-.91/-1.14/-1.08；原Trex同回放足高差僅2.38e-7，不能归咎新Mesh，先釐清原生接地／映射／driver。閉口22軟面／5牙面相交需定位，大張口0/0不算咬合驗收。GLB bind網格讀回通过；Icosphere先前是匯入器顯示shape誤算，GLB無此物件。未改模型／Rig。下一提案01S.1有限接地診斷，尚未開始；功能驗收PARTIAL。\n')
with (w/'revisit-register.md').open('a') as f:f.write('\n2026-10-09｜01S最新排序：RVI-002接地優先。隔離Godot程序回放walk/run/turn足部下探，新舊Trex控制樣本差<2.4e-7；先驗證原生／回放／地面／根與driver來源，不直接歸咎新Mesh。RVI-004閉口22軟面／5牙面三角相交保持OPEN，張口0/0非完整咬合證明；R2v005眼球已核可，眼色／角度不再列必改。RVI-001／003OPEN／DEFERRED，在本輪全身Concept未校準比較下不啟動比例修形。下一01S.1唯讀接地診斷待審。\n')
with (w/'DECISIONS.md').open('a') as f:f.write('\n2026-10-09｜01S審視完成，造型主要區域可先保留、必要功能尚未通過。先排查共同接地／映射／driver，再定位閉口相交，不用新的Morphology Pass掩蓋功能問題。01S.1提案待審；工作基準R2v005、Production 01J、Rig/Bones硬鎖保持。\n')
x=json.loads((w/'asset-index.json').read_text());x['active_phase']='01S read-only consistency and procedural motion audit completed; functional validation PARTIAL; 01S1 contact diagnosis proposed, not started';x['evaluations'].append({'report':str((p/'index.html').relative_to(r)),'source':'01R2 v005','source_sha256':ex['source_sha256'],'status':'audit_completed_functional_validation_partial','model_modified':False,'static_views':14,'motion_images':images,'sample_count':len(m['samples']),'original_Trex_max_foot_height_delta':diff,'export_readback':'7007 triangles; source bind geometry matches; Blender imported display shapes excluded','MCP':'not_connected','full_game_validation':False});(w/'asset-index.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
print('01S report and canonical state/RVI/log/index written; accepted model untouched')
