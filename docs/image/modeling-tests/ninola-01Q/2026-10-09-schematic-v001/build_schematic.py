from pathlib import Path
import json,hashlib,html,math
from PIL import Image,ImageDraw,ImageFont
r=Path.cwd();p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';g=json.loads((s/'source_geometry.json').read_text());cams=json.loads((s/'capture_settings.json').read_text());ins=json.loads((s/'inspection.json').read_text());src=r/ins['source'];before=hashlib.sha256(src.read_bytes()).hexdigest();assert before==ins['sha256'];font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
ys=[-1.2,-1.5,-1.8,-2.1,-2.4,-2.7,-3.0,-3.3,-3.6,-3.9,-4.2,-4.5,-4.8,-5.1];width=[None,None,None,None,.515,.470,.425,.385,.345,.310,.285,.260,None,None];bottom=[None,None,1.540,1.550,1.560,1.570,1.580,1.585,1.590,1.595,1.600,1.605,None,None];skin={'d_olive','d_moss','d_tan','d_belly'};stations=[];sections=[]
for idx,y in enumerate(ys):
 pts=[]
 for f,mat in zip(g['faces'],g['materials']):
  if mat not in skin:continue
  for a,b in zip(f,f[1:]+f[:1]):
   A=g['vertices'][a];B=g['vertices'][b]
   if (A[1]-y)*(B[1]-y)<0:
    t=(y-A[1])/(B[1]-A[1]);pts.append([A[k]*(1-t)+B[k]*t for k in range(3)])
 assert pts;w=max(abs(a[0]) for a in pts);lo=min(a[2] for a in pts);hi=max(a[2] for a in pts);stations.append({'y':y,'source_skin_halfwidth':w,'source_skin_bottom':lo,'source_skin_top':hi,'target_halfwidth':width[idx] if width[idx] is not None else w,'target_bottom':bottom[idx] if bottom[idx] is not None else lo,'target_top':hi,'role':'design control, not fitted mesh or physical dimension target'});sections.append(pts)
points=[];faces=[];edges=[]
for k,st in enumerate(stations):
 y=st['y'];w=st['target_halfwidth'];t=st['target_top'];b=st['target_bottom'];h=(t-b)/2;c=(t+b)/2
 profile=[(0,t),(.55*w,t-.08*h),(w,c+.25*h),(.90*w,c-.45*h),(.50*w,b+.05*h),(0,b),(-.50*w,b+.05*h),(-.90*w,c-.45*h),(-w,c+.25*h),(-.55*w,t-.08*h)]
 points.extend([(x,y,z) for x,z in profile])
 for j in range(10):edges.append((k*10+j,k*10+(j+1)%10,'section'))
 if k:
  for j in range(10):faces.append([(k-1)*10+j,(k-1)*10+(j+1)%10,k*10+(j+1)%10,k*10+j]);edges.append(((k-1)*10+j,k*10+j,'rail'))
def cv(q,view):
 m=cams[view]['matrix'];v=[q[i]-m[i][3] for i in range(3)];return [sum(m[j][i]*v[j] for j in range(3)) for i in range(3)]
def proj(q,view):
 v=cv(q,view);f=1100/cams[view]['scale'];return (550+v[0]*f,550-v[1]*f)
views=[('tail_side','側面：腰段少量補足、中段腹線收回'),('tail_top','頂面：中段寬度連續漸收，保留折面'),('tail_oblique','3/4：同一組截面，不分視圖任意畫線'),('tail_root_close','尾根：厚度基礎保留，向中段漸接'),('full_body_side','全身：尾長、骨盆與後肢保持'),('full_body_top','全身頂視：保留厚根到細尖的主次')]
for view,title in views:
 base=Image.open(s/'captures'/f'{view}.png').convert('RGB');right=Image.blend(base,Image.new('RGB',base.size,(25,35,45)),.55);lay=Image.new('RGBA',base.size);d=ImageDraw.Draw(lay)
 for face in sorted(faces,key=lambda face:sum(cv(points[i],view)[2] for i in face)):
  d.polygon([proj(points[i],view) for i in face],fill=(90,213,191,27))
 for a,b,kind in edges:d.line([proj(points[a],view),proj(points[b],view)],fill=(246,200,99,185) if kind=='section' else (98,237,211,230),width=2)
 # Baseline skin extrema exclude spines; these rails summarize sections, not
 # the exact silhouette of a perspective view.
 for mode in ['width_plus','width_minus','bottom']:
  rail=[(st['source_skin_halfwidth']*(1 if mode=='width_plus' else -1) if mode!='bottom' else 0,st['y'],(st['source_skin_top']+st['source_skin_bottom'])/2 if mode!='bottom' else st['source_skin_bottom']) for st in stations]
  for aa,bb in zip(rail,rail[1:]):
   A=proj(aa,view);B=proj(bb,view)
   for t in [0,.25,.5,.75]:d.line([(A[0]+(B[0]-A[0])*t,A[1]+(B[1]-A[1])*t),(A[0]+(B[0]-A[0])*(t+.12),A[1]+(B[1]-A[1])*(t+.12))],fill=(247,142,115,230),width=3)
 for n,bone in ins['bones'].items():
  if n.startswith('tail'):d.line([proj(bone['head_world'],view),proj(bone['tail_world'],view)],fill=(169,152,247,190),width=2)
 right=Image.alpha_composite(right.convert('RGBA'),lay).convert('RGB');c=Image.new('RGB',(1600,1000),(24,35,45));dd=ImageDraw.Draw(c);dd.text((25,15),'01Q.1｜'+title,font=font,fill='white');dd.text((25,65),'P1 v002｜核可現況',font=font,fill='white');dd.text((825,65),'共同3D包絡｜不是改後模型',font=font,fill='white');c.paste(base.resize((760,760)),(20,110));c.paste(right.resize((760,760)),(820,110));dd.text((25,890),'綠：主量體提案　金：共同截面　橘虛線：原皮截面極值摘要　紫：實際骨軸',font=small,fill='white');dd.text((25,935),'不全面削瘦、不磨成圓管；棘刺保持。端部與固定皮膚未貼合，尚未驗證動態。',font=small,fill='white');c.save(p/f'{view}_schematic.png')
# Longitudinal graph is in common world space; main proposal and measured
# baseline separated so widening versus trimming can be assessed directly.
c=Image.new('RGB',(1600,720),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'共同控制值比較｜少量補腰＋收腹／收寬，非全尾縮小',font=font,fill='white')
for row,key,label,origin,factor in [(0,'halfwidth','半寬（來源皮面截線）',310,180),(1,'bottom','腹側高度（來源皮面截線）',610,170)]:
 d.text((25,85+row*340),label,font=font,fill='white')
 for kind,col in [('source_skin',(247,142,115)),('target',(98,237,211))]:
  rail=[(120+(abs(st['y'])-1.2)/3.9*1350,origin-(st[f'{kind}_{key}']-(1.35 if row else 0))*factor) for st in stations];d.line(rail,fill=col,width=5)
  for x,y in rail:d.ellipse((x-4,y-4,x+4,y+4),fill=col)
 for st in stations:d.text((120+(abs(st['y'])-1.2)/3.9*1350-25,300+row*340),str(st['y']),font=small,fill='white')
d.text((25,670),'橘：實測原皮極值　綠：示意控制值（不是Concept量測，也不直接當施工位移）',font=small,fill='white');c.save(p/'control_comparison.png')
(p/'schematic_geometry.json').write_text(json.dumps({'role':'coherent_3D_tail_envelope_design_only','stations':stations,'points':points,'faces':faces,'edges':edges,'same_geometry_all_views':True,'source_pose_and_rig_unchanged':True,'source_model_edited':False,'source_skin_intersections_exclude_spines':True,'spines_shown_unchanged':True,'root_and_distal_control_dimensions_preserved':True,'endpoints_fitted_to_source_surface':False,'skin_spine_interface_solved':False,'weights_transferred':False,'dynamic_tested':False},indent=2));assert hashlib.sha256(src.read_bytes()).hexdigest()==before;(p/'source_hash_verification.json').write_text(json.dumps({'source':ins['source'],'sha256_before':before,'sha256_after':hashlib.sha256(src.read_bytes()).hexdigest(),'unchanged':True},indent=2))
(p/'DESIGN.md').write_text('''# 01Q.1 共同尾部立體示意

2026-10-09｜使用者核准下一步示意；P1 v002保持核可，未改模型。

14個來源皮面Y截線取得半寬／上緣／下緣（排除棘刺），建立同一個10點角面截面包絡，投影側／頂／3/4／近根／全身側頂。橘虛線是原皮截線極值摘要，不是精確視圖輪廓；不能將各截面極值當頂點位移指令。綠是提案，金是截面，紫是實際骨鏈。

主要做法：尾根厚度與近根兩站控制值保持；腰段腹側少量補足，尾中段鼓起腹線收回，寬度少量補窄處並收鼓起處。沒有整尾縮放或磨成圓管；背面高度控制值保持，尾末兩站保持，原尾尖未覆蓋／未延長。示意僅把中段的再膨大減弱；低面數大側面與稜角保留。這些為設計控制值，不是Concept量測或已驗證解剖／生物力學。

點評：側頂可以共同比較束腰和腹側鼓段；與只把整尾削瘦相比，補腰與收鼓包的平衡較符合原厚根漸收目標。背線與棘刺仍繼承原模型，圖中包絡不表示已貼合棘刺基部；不得將包絡直接替換整尾。原骨盆／上腿／尾長／尾尖與骨架完全不動。

尚未解算：包絡端部與原皮共點、皮膚棘刺接口、權重／全尾變形、碰撞。近根控制值不变不等於實際端面共點固定已成功。本次沒有.blend新模型或動態驗收。RVI001～004不關閉。

下一提案（待核准）：先定位tail skin／棘刺／固定端部，再做有限尾中段外皮Prototype，以示意為方向、不逐點照抄；原棘刺Mesh／Rig保持，不將骨盆上腿加入。若固定棘刺基部與目標衝突，先回報範圍，不自行解鎖。實體以侧頂／3/4／全身及有限尾部姿態檢查；若改善不值得額外改模，可沿用現況接續全身風格審視。
''')
items=''.join(f'<section><h2>{html.escape(title)}</h2><img src="{name}_schematic.png"></section>' for name,title in views);refs=''.join(f'<img src="../2026-10-09-review-v001/references/{name}.png">' for name in ['concept_side','concept_top']);(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01Q.1 共同尾部立體示意</title><style>body{background:#18232d;color:#e9edf0;font:18px sans-serif;max-width:1500px;margin:30px auto;padding:20px}img{max-width:100%;height:auto}section{margin:35px 0}p{line-height:1.7}a{color:#77dfd2}</style><h1>01Q.1 尾部共同立體示意｜待審</h1><p>核可P1未改。少量補腰、收中段鼓起，以同一立體截面比較漸收方向；保留厚根、尾長、尾尖與原棘刺。<a href="DESIGN.md">點評與下一提案</a>。</p><p>示意未與固定皮膚、棘刺基部貼合，非改後模型或動態驗收。</p><h2>Concept：姿態未配準，僅比較量體方向</h2>'+refs+'<h2>控制值摘要</h2><img src="control_comparison.png">'+items+'</html>');print('Q1 six-view coherent envelope complete; source unchanged')
