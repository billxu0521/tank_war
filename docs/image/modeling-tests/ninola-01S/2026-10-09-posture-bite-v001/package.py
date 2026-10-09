from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil
r=Path.cwd();p=Path(__file__).resolve().parent;w=r/'docs/image/modeling-tests/ninola-workflow';m=json.loads((p/'bite_metrics.json').read_text());pr=json.loads((p/'posture_record.json').read_text());f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
a=Image.new('RGB',(1200,1250),'#18212a');d=ImageDraw.Draw(a);d.text((25,15),'體態 Pose 比較｜不改Mesh／Rig結構／Rest',font=f,fill='white')
for row,(tag,label) in enumerate([('baseline','原版'),('A','A：頸+6°／頭-2°'),('B','B：頸+12°／頭-4°')]):
 y=65+row*390;d.text((25,y),label,font=small,fill='white');im=Image.open(p/f'posture_{tag}_side.png').convert('RGB').resize((570,380));a.paste(im,(25,y+30));im=Image.open(p/f'posture_{tag}_oblique.png').convert('RGB').resize((570,380));a.paste(im,(615,y+30))
a.save(p/'posture_comparison.png')
frames=[Image.open(q).convert('RGB') for q in sorted(p.glob('bite_1.5_*.png'))];durations=[500]*len(frames);frames[0].save(p/'bite_1_5_selected_frames.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0)
(p/'REPORT.md').write_text('''# 體態Pose比較與咬合餘量試作

授權範圍：頭頸／肩背體態Pose比較、1～2°咬合候選與完整循環測試；不改Mesh，不改Rig名稱／父子／Rest，原牙列／內口腔仍保持。核可資產R2v005保持，兩項試作彼此獨立，尚未合成或套入使用者已開啟的Viewer。

## 體態

原版／A（頸世界X+6°、頭補償-2°）／B（頸+12°、頭-4°）。脊椎、軀幹、骨盆與腿沒有直接改Pose。這是以原blend顯示姿態為基準的暫時世界軸旋轉；不能把它直接當作trex.gd父骨座標中的同名常數加進去。Pose控制值與骨原點見posture_record.json。

A減輕頭低，B效果更明顯，方向是頭頸更主動承接肩背，而不是削掉胸背量體。暫推薦B作視覺比較方向；軀幹峰值位置與輪廓仍保留，不宣稱駝背／Concept背線完全解決。若B被接受，下一才將等價姿態正確轉換到隔離動作程式並檢查走跑／咬擊／轉向，避免直接套世界軸值造成錯姿。若Pose仍不足，再由使用者決定是否有限調整背側Mesh包絡；本輪不執行。

## 咬合

角度掃描0／1／1.25／1.5／1.75／2／2.29°，再對1／1.5／2°各測120幀（24Hz、5秒）：閉口、預備、咬擊、收招、回待機。逐幀三角BVH＋嚴格邊對面交叉核對，三個候選牙面交叉最大皆0，軟面交叉最大皆1，各有96幀出現既有後口側交界配對；未新增其他交叉配對。

選1.5°作候選：位於使用者指定1～2°中段，較1°保留小餘量，又不特意張大嘴。這是視覺與餘量的選擇，不宣稱1.5°數學最優或交叉已完全消除。原先後口側內腔／腹色面問題仍未修；本輪不改原牙列／內口腔。

技術上原程式jaw待機基準為-0.12rad（約6.88°），本測試在獨立subclass把中性閉合基準改成-1.5°，保留咬擊／情緒等原動作項。不是在既有6.88°上再加1.5°，也不是套一個根本不會觸發的閉合clamp。正式trex.gd與已開啟的Viewer未修改。此基準變更需使用者審核，完整外觀、齒隙與碰撞／正式動作仍不能只靠0牙面交叉驗收。

## 驗證

Mesh bind點／權重／骨架Rest與來源SHA保持，Pose在記憶體還原。Godot隔離採樣、Blender映射誤差與367樣本結果見bite_metrics.json；21張實際模型影像。GIF是11個挑選幀的展示，不是等時連續影片；逐幀結論依完整120幀數據。兩項試作非完整遊戲驗收，體態未與咬合合成驗證。MCP本輪未繞看，不修改使用者測試中的Viewer，不Commit／Push／PR。

下一建議：先審核體態B方向與1.5°閉合候選；接受後才作隔離Viewer／原動作相容測試。後口側內腔整理仍需另核准有限面片範圍。接地按使用者決定暫緩，造型不因這次姿態比較全面重開。
''')
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 體態與咬合試作</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1400px}img{max-width:100%}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}a{color:#f2ce82}</style><h1>體態Pose比較＋1.5°咬合候選</h1><p>只在隔離評估，Mesh／Rig結構／Rest保持，正式資產與已開啟Viewer未改。待審。</p><p><a href="REPORT.md">完整結果與下一步</a></p><h2>體態：原版／A／B</h2><p>A頸+6°、頭-2°；B頸+12°、頭-4°。世界軸暫時Pose，脊椎不改。B較能減輕低頭感，但原軀幹高峰仍在，不宣稱Concept背線完全匹配。</p><div class="grid">'
for tag,label in [('baseline','原版'),('A','A 小幅'),('B','B 較明顯')]:html+=f'<div><p>{label}</p><img src="posture_{tag}_side.png"><img src="posture_{tag}_oblique.png"></div>'
html+='</div><h2>咬合：1°／1.5°／2°</h2><p>三候選各120幀：牙面交叉均0，後口側既有軟面交叉最高1、各96幀仍在。暫選1.5°中值；不是完整咬合已修好。</p><div class="grid">'
for idx,label in [(1,'1°'),(3,'1.5° 候選'),(5,'2°')]:html+=f'<div><p>{label}</p><img src="bite_sweep_{idx:03d}.png"></div>'
html+='</div><h2>1.5°咬擊展示</h2><p>GIF為挑選幀展示，逐幀判斷依120幀原始數據。體態B尚未與此咬擊合成。</p><img src="bite_1_5_selected_frames.gif"><p>實際原程式待機基準約6.88°，此試作是把隔離jaw中性基準改到1.5°，保留原動作項；不是再疊加1.5°。來源hash／Rest保持。</p>';(p/'index.html').write_text(html)
s=(w/'STATE.md').read_text();s+='''\n## 核准範圍內隔離試作｜體態與咬合\n\n使用者核准體態Pose比較與1～2°閉合候選測試。已完成原版／A（頸+6°頭-2°）／B（+12°/-4°）世界軸暫時Pose比較；B較減輕低頭，軀幹高峰仍保留，未將世界軸數值直接套動作程式。另1／1.5／2°各120幀完整咬擊循環，牙交叉max0、既有後口側軟面max1（各96幀），暫選1.5°為候選，非完整咬合修復。原driver中性基準約6.88°，試作是改隔離基準到1.5°，保留動作項；非疊加或無效clamp。兩項各自測試，未合成、未套已開啟Viewer，來源Mesh／Rig結構／Rest／hash保持。報告../ninola-01S/2026-10-09-posture-bite-v001/index.html。等待使用者審核B方向與1.5°，才提隔離動態相容／Viewer比較；內腔接邊仍未核准試修，接地仍DEFERRED。\n''';(w/'STATE.md').write_text(s)
with (w/'DISCUSSION_LOG.txt').open('a') as f:f.write('\n2026-10-09｜使用者核准體態Pose比較與1～2°閉合候選测试。A頸+6°頭-2°、B+12°/-4°世界軸Pose，B減輕低頭較明顯，但背部峰仍保留。Rig結構／Rest／Mesh保持。咬合1／1.5／2°各120幀，牙交叉max0、後口側軟面max1（96幀），選1.5°中值候選。原程式待機基準6.88°，隔離測試改中性基準到候選值，非疊加角度；原action項保持。兩項試作各自待審，未合成或改使用者Viewer，內口腔與牙列未修。\n')
with (w/'revisit-register.md').open('a') as f:f.write('\n2026-10-09｜RVI-004咬合：1／1.5／2°中性閉合基準各120幀，牙面交叉max0，既有後口側軟面交叉max1，各96幀仍在，不能關閉。1.5°暫選待審，未修內腔／牙列。體態A/B是暫時Pose比較，不修改Rest；背峰仍保留，不因抬頭稱背線完成。002仍DEFERRED。\n')
x=json.loads((w/'asset-index.json').read_text());x['active_phase']='isolated posture A/B comparison and 1-2 degree full bite cycles complete; posture B direction / neutral jaw 1.5 degree candidates pending user review; ground deferred';x['evaluations'].append({'phase':'01S_posture_bite','report':str((p/'index.html').relative_to(r)),'source':'01R2 v005','source_sha256':m['sha256'],'posture_candidates':pr['candidates'],'jaw_candidate_degrees':1.5,'cycles':m['cycle_summary'],'status':'evaluation_candidates_pending_user_review','model_modified':False,'live_viewer_changed':False});(w/'asset-index.json').write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');print('comparison and candidate records ready')
