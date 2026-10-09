from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,math
r=Path.cwd();p=Path(__file__).resolve().parent;w=r/'docs/image/modeling-tests/ninola-workflow';rec=json.loads((p/'build_record.json').read_text());font='/System/Library/Fonts/Hiragino Sans GB.ttc';f=ImageFont.truetype(font,25);small=ImageFont.truetype(font,21)
canvas=Image.new('RGB',(1200,1390),'#18212a');d=ImageDraw.Draw(canvas);d.text((25,15),'01R.2 v003｜左右眼各朝前轉10°｜待審',font=f,fill='white')
for row,(name,title) in enumerate([('installed_side','側面特寫'),('installed_close','斜側特寫'),('head_front','完整頭部正面')]):
 y=65+row*440;d.text((25,y),title,font=small,fill='#d7dfe7')
 for col,(label,text) in enumerate([('before','v002｜純側向'),('trial','v003｜朝前10°')]):
  x=25+col*590;d.text((x,y+32),text,font=small,fill='white');im=Image.open(p/f'{label}_{name}.png').convert('RGB').resize((365,365));canvas.paste(im,(x+90,y+65))
canvas.save(p/'comparison.png')
(p/'REPORT.md').write_text('''# 01R.2 v003：從側向朝前10°

使用者指定「微微把眼珠子朝正面轉10度」。以+Y為前方，左右眼軸从[-1,0,0]/[1,0,0]分别改為[-0.984807753,0.173648178,0]/[0.984807753,0.173648178,0]。相對側向各轉10°，不是相對頭部正前方10°；豎瞳維持上下。

只調整眼球表面虹膜／瞳孔朝向。球心、球徑、金色與豎瞳形狀、面數、眼眶、所有非眼球面／材質／權重及Rig與Trex keys保持。v002留比較，核可checkpoint仍R1v011，v003待審。

## 評估與建議

側面中央豎瞳仍可清楚讀取；斜側面的瞳孔較v002靠近虹膜中央，稍增加朝前感。仍屬以側向為主的安裝，不宣稱兩眼已共同看向正前方。建議先比較此小角度版本，不繼續放大旋轉或增加细節，接受後即可收束眼球。

## 驗證與限制

保存讀回角度10°檢查通過，眼球以外座標／材質／平滑／權重與45骨／Pose／Rest Pose／Trex Shape Keys完全一致。球半徑誤差<2e-6，眼球封閉、面朝外、head權重1。9441點／7007tri，雙眼576tri，預算不變。來源與保存檔SHA確認。

18張同鏡頭Workbench對照，左v002、右v003；相機不變。不等於遊戲/PBR或動態驗收。桌面MCP前輪未連線，本輪未重新啟動／未完成桌面繞看。未改Production，未Commit／Push／PR。
''')
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01R.2 v003 朝前10度</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1200px}img{max-width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}a{color:#f2ce82}</style><h1>01R.2 v003｜左右眼各朝前轉10°</h1><p>左：v002 純側向；右：v003 從側向朝前10°。球心、球徑、眼眶與Rig保持，面數不變。待審。</p><p>側面豎瞳仍清楚；斜側的瞳孔較靠近虹膜中央。仍以側向為主，未做動態瞄準。Workbench預覽，未遊戲/PBR與桌面MCP檢核。</p><a href="REPORT.md">修改與驗證紀錄</a>'
for n,title in [('installed_side','右眼側面'),('installed_other_side','左眼側面'),('installed_close','斜側特寫'),('installed_front','近正面特寫'),('head_side','完整頭部側面'),('head_threequarter','完整頭部斜側'),('head_front','完整頭部正面')]:html+=f'<h2>{title}</h2><div class="pair"><img src="before_{n}.png"><img src="trial_{n}.png"></div>'
(p/'index.html').write_text(html)
s=(w/'STATE.md').read_text().split('## 眼球試作待審｜01R.2 v002')[0];s+='''## 眼球試作待審｜01R.2 v003

使用者要求從側向朝前各轉10°，已獨立保存 blender/ninola/working/01R2/2026-10-09-v003/ninola_01R2_gold_slit_eye.blend，Object 01R2_Gold_Slit_Eye。左右軸[±cos10°,sin10°,0]，豎瞳維持上下。球心／半徑／眼眶／非眼球形狀材質權重／Rig與keys保持；9441點／7007tri、雙眼576tri。側面豎瞳清楚，斜側稍靠近虹膜中央，仍以側向為主。角度與鎖保存讀回通過，18幅同鏡頭比较。v002保留歷史，v003待使用者核可，核可checkpoint仍R1v011。桌面MCP前輪未連線，本輪未桌面繞看／遊戲PBR驗證，01S未開始。報告 ../ninola-01R/2026-10-09-eye-pass-v003/index.html。
''';(w/'STATE.md').write_text(s)
with (w/'DISCUSSION_LOG.txt').open('a') as f:f.write('\n2026-10-09｜使用者指定眼球從側向朝前轉10°。R2v003左右軸改[±cos10°,sin10°,0]，豎瞳上下保持。側面仍清楚，斜側瞳孔較接近虹膜中央；仍側向為主。球心／半徑／眼眶／其他模型与Rig保持，面數不變，保存讀回含10°角度檢查通過。獨立另存，v002保留，v003待審，建議接受後收束眼球。\n')
x=json.loads((w/'asset-index.json').read_text());prev=x['assets']['01R2'];history=prev.get('history',[])+[{'version':'v002','path':prev['local_path'],'sha256':prev['sha256'],'role':'lateral_installation_comparison_retained'}];x['assets']['01R2']={**prev,'local_path':rec['output_path'],'sha256':rec['output_sha256'],'report':str((p/'index.html').relative_to(r)),'history':history,'eye_axes':[eye['gaze_axis'] for eye in rec['eyes']],'review':'10 degree forward rotation trial pending user review'};x['current_editing_state']={'asset':'01R2','version':'v003','status':'10 degree forward rotation trial pending review; accepted checkpoint stays R1v011'};x['active_phase']='01R2 v003 eye rotation trial pending user review; 01S not started';(w/'asset-index.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
before=r/'blender/ninola/working/01R2/2026-10-09-v002/ninola_01R2_gold_slit_eye.blend';(p/'comparison_provenance.json').write_text(json.dumps({'before':str(before.relative_to(r)),'before_sha256':hashlib.sha256(before.read_bytes()).hexdigest(),'trial':rec['output_path'],'trial_sha256':rec['output_sha256'],'same_camera_for_each_pair':True,'views':9,'eye_axes':[eye['gaze_axis'] for eye in rec['eyes']],'forward_rotation_from_lateral_degrees':10},indent=2)+'\n')
print('comparison, report, log and canonical index updated')
