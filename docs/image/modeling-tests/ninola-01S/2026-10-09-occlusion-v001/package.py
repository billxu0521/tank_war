from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
r=Path.cwd();p=Path(__file__).resolve().parent;w=r/'docs/image/modeling-tests/ninola-workflow';x=json.loads((p/'contact_details.json').read_text());angles=json.loads((p/'closure_details.json').read_text());font='/System/Library/Fonts/Hiragino Sans GB.ttc';f=ImageFont.truetype(font,25);small=ImageFont.truetype(font,20)
a=Image.new('RGB',(1200,960),'#18212a');d=ImageDraw.Draw(a);d.text((25,15),'咬合唯讀診斷｜紅色：確認的表面交叉',font=f,fill='white')
for row,(name,title) in enumerate([('head_context','完整頭顎'),('teeth_only','只看上下牙齒'),('mouth_only','只看外皮／內口腔')]):
 y=70+row*290;d.text((25,y),title,font=small,fill='white')
 for col,(path,label) in enumerate([(p/f'jaw_sweep_000_{name}.png','0°：完全閉合樣本'),(p/f'closure_002_{name}.png','約2.3°：保留小餘量')]):
  xx=25+col*590;d.text((xx,y+30),label,font=small,fill='#d3dde7');im=Image.open(path).convert('RGB').resize((300,225));a.paste(im,(xx+125,y+58))
a.save(p/'comparison.png')
rows=[v for v in angles['rows'] if v['asset']=='R2'];table='\n'.join(f"|{abs(z['angle_degrees']):.2f}°|{z['soft_strict_crossing_pairs']}|{z['teeth_strict_crossing_pairs']}|" for z in rows)
report=f'''# 咬合確認與不改Rig的處理選項

使用者接受整體造型收束，接地暫緩。本輪只做核可R2v005唯讀咬合診斷；頭顎、牙齒、口腔、Rig及程式資產沒有被修正。

## 確認結果

閉口：R2有22組軟面／5組牙面三角配對交叉；原始Trex有21／5。使用BVH初篩後，逐對以三角邊線段與對方面內部交點核對，存在實際交叉，不只是共享接點或AABB旗標。配對數不是缺陷數或穿透深度，不能稱5顆牙都有問題。

軟面分類：15組d_mouth對d_mouth、6組下顎d_tan對內口d_mouth、1組下顎d_mouth對頭側d_belly。原始模型大部分同樣存在，現版較原始多1組軟面配對。牙面交叉集中於模型左側前部的一小段上下齒列，不代表需要整口換牙。

在程序動作的張口與抽樣咬擊幀，測得0／0；不等於全咬擊周期或閉合體空間已通過。保留齒尖、牙齒穿出唇線的設計，不能與上下牙面互相穿插混為一談。

## 只調整閉合餘量的可行性（隔離測試）

Godot未修改trex.gd，使用現有jaw骨程序Pose模擬不同角度，再由Blender回放。骨架名稱、父子、Rest、球心與外形不改；這是使用既有骨骼動作，不是改Rig結構。

|張開餘量|軟面交叉配對|牙面交叉配對|
|---|---:|---:|
{table}

1.15°就能消除本樣本牙面交叉，並把軟面交叉降到1；剩余pair為原模型也有的後口側d_mouth／d_belly交界（模型右側、靠近後顎）。8.59°才在此角度掃描得到0／0，但閉口外觀會更張開；不建議為追求數值清零而讓嘴永久張得更大。

## 可以做什麼

- **保守方向，建議先試**：閉合留約1～2°小餘量，內口腔後側接邊局部整理。完整閉合／咬擊時間序列仍須測試，不只看静態0／0。既有牙形與頭顎外殼保留；角度餘量只在隔離程式試作，未改正式程式。
- **若要求回到真正0°閉口**：需要針對相交的上下齒做小幅位移／縮短／錯位排列，整理內口襯面與必要口緣接口；沿用原jaw/head權重，Rig結構與Rest不改。此路徑觸及原牙列／內口腔保護範圍，必須先明確核准；不能因全身造型接受便自動解除。
- 不建議重塑整個頭顎，也不為消除遮蔽而刪掉有用牙齒或內口腔。

後續驗收：固定閉口、張口與完整咬擊周期同鏡頭比較；交叉位置／牙隙與口緣不被新的穿插取代；嘴角不裂、牙齒不離根、Rig／Rest簽章保持、核可外輪廓保持。0表面交叉不是唯一驗收條件。

## 接地暫緩，但不改Rig也有路徑

先保持RVI-002 OPEN／DEFERRED，不進行接地修正。未來若確認是動作程式，可以調整現有骨骼的IK目標、腳底高度補償、步幅、支撐／擺動時序；這些不改骨骼名稱、結構或Rest，但仍會使用現有骨骼Pose。若是局部蒙皮或腳底Mesh問題也可另提有限範圍，不能在來源未釐清前直接修。現有證據只顯示原Trex與Prototype同回放都有下探，不足以選定修法。

## 驗證範圍

只讀同一核可blend，來源SHA保持；Pose只在記憶體模擬後還原。六個現有程序樣本、七個小角度掃描、原Trex對照與18幅診斷圖。MCP未連線／本輪沒有完整原生遊戲咬合驗收。没有修改用户正在操作的獨立Viewer。未Commit／Push／PR，Production不替換。詳細面ID／位置／交點見contact_details.json及closure_details.json。
''';(p/'REPORT.md').write_text(report)
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 咬合診斷</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1200px}img{max-width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #607080}a{color:#f2ce82}</style><h1>造型收束｜接地暫緩｜咬合診斷</h1><p>唯讀，未改Mesh或Rig。紅色為逐對確認的表面交叉，不是穿透量或缺陷數。</p><p>閉口現版22／5、原Trex21／5。留約1.1°餘量降為1／0；剩後口側接邊交叉。要只用角度全消除，本掃描需8.6°，不建議以永久張大口處理。</p><p><a href="REPORT.md">完整診斷與有限試修方案</a></p><img src="comparison.png"><h2>閉合餘量測試</h2><table><tr><th>張開餘量</th><th>軟面配對</th><th>牙面配對</th></tr>'
for v in rows:html+=f'<tr><td>{abs(v["angle_degrees"]):.2f}°</td><td>{v["soft_strict_crossing_pairs"]}</td><td>{v["teeth_strict_crossing_pairs"]}</td></tr>'
html+='</table><h2>小餘量與較大餘量的外觀取捨</h2><div class="pair"><div><p>2.29°</p><img src="closure_002_head_context.png"></div><div><p>8.59°</p><img src="closure_006_head_context.png"></div></div><p>建議有限口腔接邊整理＋小閉合餘量，保留外輪廓与Rig。試修尚未執行，牙列／內口腔保護範圍需先核准。</p>';(p/'index.html').write_text(html)
# Only update current authorities; leave historical reports intact.
s=(w/'STATE.md').read_text();start=s.index('下一有限提案01S.1：');end=s.index('\n## 保護',start);s=s[:start]+'''使用者接受目前整體造型可收束，接地先不處理。RVI-002改OPEN／DEFERRED，先前01S.1接地診斷提案暫緩，不自行啟動。全身造型基準仍R2v005，不因收束宣稱Production或全工程通過。

本輪已按要求唯讀確認咬合：閉口R2軟面22／牙面5配對為嚴格表面交叉，原Trex21／5；多為既有內腔／齒列。隔離小角度掃描1.15°可降為1／0，殘余是原模型也有的後口側內腔／d_belly交界；8.59°为0／0但開口較大，不建議單靠角度清零。下一建議有限內口腔接邊整理＋約1～2°閉合餘量試作，保留已核可外輪廓、Rig與Rest。尚未獲試修指示，牙列／內口腔保護不解除。診斷../ninola-01S/2026-10-09-occlusion-v001/index.html。未改使用者正在操作的Viewer或來源模型。
'''+s[end:];s=s.replace('下一01S.1接地來源診斷待審','接地診斷按使用者決定暫緩，咬合有限試修待審');(w/'STATE.md').write_text(s)
with (w/'DISCUSSION_LOG.txt').open('a') as f:f.write('\n2026-10-09｜使用者自行測試後接受造型收束，接地暫緩，要求確認咬合與不動Rig可做項目。唯讀嚴格邊／面交叉：閉口R2軟22牙5，原Trex21/5；大多既有內腔／齒列。小角度隔離測試1.15°降為1/0，残余後口側d_mouth/d_belly接邊同原模型；8.59°为0/0但不宜以永久張大口清零。建議有限內口腔接邊整理與1～2°閉合餘量，若要0°完全閉合則需局部牙列／內腔修整；兩者不改Rig結構／Rest，試修尚未執行。\n')
with (w/'DECISIONS.md').open('a') as f:f.write('\n2026-10-09｜使用者接受R2v005整体造型收束，接地暫緩。轉向唯讀咬合確認，不重啟外觀精修，不自行解除Rig／牙列／內口腔保護。閉口角度或局部內腔／牙列試修另提有限範圍待核准。\n')
with (w/'revisit-register.md').open('a') as f:f.write('\n2026-10-09｜使用者決定接地先不處理，RVI-002 OPEN／DEFERRED，01S.1接地診斷暫緩。RVI-004咬合確認：閉口嚴格交叉R2軟22牙5、原Trex21/5；1.15°餘量降为1/0，後口側內腔／腹色面接邊仍在，8.59°零配對不能等同完整體積或咬擊周期驗收。有限內腔接邊＋小角度試修待核准；全身造型收束不等於解除牙列／口腔或Rig保護。\n')
z=json.loads((w/'asset-index.json').read_text());z['active_phase']='overall morphology accepted and closed; ground contact deferred by user; read-only occlusion diagnosis completed; finite oral fix proposed, not started';z['evaluations'].append({'phase':'01S_occlusion','report':str((p/'index.html').relative_to(r)),'source':'01R2 v005','source_sha256':x['sha256'],'status':'read_only_diagnosis_completed','closed_strict_pairs':{'R2':[22,5],'original_Trex':[21,5]},'small_opening_1_15_degrees_pairs':[1,0],'opening_8_59_degrees_pairs':[0,0],'model_modified':False,'ground_contact':'deferred_by_user'});(w/'asset-index.json').write_text(json.dumps(z,ensure_ascii=False,indent=2)+'\n')
print('Occlusion report and canonical decisions/log/RVI updated')
