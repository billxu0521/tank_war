from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
p=Path(__file__).resolve().parent;r=Path.cwd();w=r/'docs/image/modeling-tests/ninola-workflow';rec=json.loads((p/'build_record.json').read_text());font='/System/Library/Fonts/Hiragino Sans GB.ttc';f=ImageFont.truetype(font,25);small=ImageFont.truetype(font,21)
canvas=Image.new('RGB',(1200,1390),'#18212a');d=ImageDraw.Draw(canvas);d.text((25,15),'01R.2 v002｜左右側向安裝｜待審',font=f,fill='white')
for row,(name,title) in enumerate([('installed_side','實裝側面'),('installed_close','實裝斜側面'),('head_front','完整頭部正面：側向安裝的取捨')]):
 y=65+row*440;d.text((25,y),title,font=small,fill='#d7dfe7')
 for col,(label,text) in enumerate([('before','v001｜前向'),('trial','v002｜側向')]):
  x=25+col*590;d.text((x,y+32),text,font=small,fill='white');im=Image.open(p/f'{label}_{name}.png').convert('RGB').resize((365,365));canvas.paste(im,(x+90,y+65))
canvas.save(p/'comparison.png')
report='''# 01R.2 v002：眼球朝左右側安裝

使用者明確要求「瞳孔向左右側而非向前」。本版左右虹膜／瞳孔軸分别為世界-X/+X，豎瞳長軸保持上下；这是本次授權的新方向，取代v001前向視軸保持的限制。

金色虹膜、收尖黑豎瞳、分段與面數不變；球心、半徑、眼眶、頭型與Rig保持。以核可R1v011建立獨立比較副本，前向v001保留，不覆寫任何核可資產。

## 評估

左右側面可清楚讀到豎瞳，斜側面也可辨識，改善前向版中央瞳孔被眶遮住的問題。正面較少看到瞳孔，这是側向安裝的視角取捨；本版不是兩眼正前方共同注視，也沒有動態眼球瞄準或瞳孔收放機制。

建議先審核此側向安裝效果；若接受，眼球部分即可收束，不再增加面數／纖維細節。下一全身01S審視仍待指示。

## 檢查

保存讀回：非眼球面座標、材質、平滑旗標與權重完全一致；Rig／45骨／Rest Pose／Pose與Trex Shape Keys簽章一致。新眼球封閉、朝外、head權重1，球半徑誤差<2e-6，來源hash保持。全體9441頂點／7007tri，雙眼576tri，與v001同預算。

18張同鏡頭Workbench實際模型對比圖，左是前向v001，右是側向v002。桌面MCP重新檢查仍Not connected，本輪未桌面繞看／未遊戲PBR驗證；未替換正式Production，未Commit／Push／PR。

生物參考與科學適用範圍沿用 [v001研究紀錄](../2026-10-09-eye-pass-v001/REPORT.md)：現生鱷類參考，不宣稱獸腳類確定復原。

待使用者審核，核可checkpoint仍為R1v011。
'''
(p/'REPORT.md').write_text(report)
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01R.2 v002 側向眼球</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1200px}img{max-width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}a{color:#f2ce82}</style><h1>01R.2 v002｜瞳孔朝左右外側</h1><p>左：v001 前向；右：v002 側向。獨立試作／待審。球心、球徑、眼眶、頭型與Rig保持。</p><p>側面豎瞳清楚，斜側可辨。正面減少瞳孔露出，是側向安裝的取捨。Workbench預覽，未遊戲/PBR驗收；MCP目前未連線。</p><a href="REPORT.md">修改與驗證紀錄</a>'
for n,title in [('installed_side','右眼側面'),('installed_other_side','左眼側面'),('installed_close','斜側特寫'),('installed_front','近正面特寫'),('head_side','完整頭部側面'),('head_threequarter','完整頭部斜側'),('head_front','完整頭部正面')]:html+=f'<h2>{title}</h2><div class="pair"><img src="before_{n}.png"><img src="trial_{n}.png"></div>'
(p/'index.html').write_text(html)
s=(w/'STATE.md').read_text();s=s.split('## 眼球試作待審｜01R.2 v001')[0];s+='''## 眼球試作待審｜01R.2 v002

使用者明確要求瞳孔向左右側而非向前；已建立側向安裝副本 blender/ninola/working/01R2/2026-10-09-v002/ninola_01R2_gold_slit_eye.blend，Object 01R2_Gold_Slit_Eye。左右視軸-X/+X，取代v001前向限制；球心／球徑／眼眶／非眼球面材質權重與Rig/keys保持。9441點／7007tri，雙眼576tri，未增加面數。側面豎瞳可見，斜側可辨，正面露出較少是取捨。v001留歷史比較，核可checkpoint仍R1v011，等待使用者審核。保存讀回与18張多視角完成；MCP重新查核Not connected，未桌面繞看／遊戲PBR驗證。報告 ../ninola-01R/2026-10-09-eye-pass-v002/index.html。01S尚未開始。
''';(w/'STATE.md').write_text(s)
with (w/'DISCUSSION_LOG.txt').open('a') as f:f.write('\n2026-10-09｜使用者要求眼球瞳孔朝左右側而非向前。R2v002左右軸改-X/+X，豎瞳仍上下；側面中央瞳孔清楚，斜側可辨，正面露出減少為側向安裝取捨。球心／半徑／眼眶／所有非眼球面與Rig保持，面數仍7007tri。獨立另存並保存讀回，18幅同鏡頭比較，前向v001留歷史。待審，未升為核可基準；建議接受後眼球收束，不增加細節。MCP仍未連線，未遊戲/PBR驗證。\n')
with (w/'DECISIONS.md').open('a') as f:f.write('\n2026-10-09｜使用者明確修改眼球安裝方向：朝左右側，取代前向視軸保持條件。僅眼球表面朝向調整，眼眶／球心／球徑／Rig維持；R2v002待使用者審核，不視為Production驗收。\n')
x=json.loads((w/'asset-index.json').read_text());previous=x['assets']['01R2'];history=previous.get('history',[])+[{'version':'v001','path':previous['local_path'],'sha256':previous['sha256'],'role':'forward_axis_historical_trial'}];x['assets']['01R2']={**previous,'local_path':rec['output_path'],'sha256':rec['output_sha256'],'report':str((p/'index.html').relative_to(r)),'review':'lateral installation; pending user review','history':history,'eye_axes':[[-1,0,0],[1,0,0]]};x['current_editing_state']={'asset':'01R2','version':'v002','status':'lateral eye installation pending user review; accepted checkpoint remains 01R1 v011'};(w/'asset-index.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
print('Review package and canonical documents updated')
