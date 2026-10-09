from pathlib import Path
import json, math, hashlib, html
from PIL import Image, ImageDraw, ImageFont

r=Path.cwd(); p=Path(__file__).resolve().parent
s=p.parent/'2026-10-09-review-v001'
ins=json.loads((s/'inspection.json').read_text())
cams=json.loads((s/'capture_settings.json').read_text())
g=json.loads((r/'docs/image/modeling-tests/ninola-01O/2026-10-09-schematic-v001/source_geometry.json').read_text())
# Only use older face/material lookup where all evaluated vertices exactly match
# the current O2 read-only inspection. No older body geometry is displayed.
current={int(i):v for side in ins['arm_vertices'].values() for i,v in side.items()}
assert all(g['vertices'][i]==v for i,v in current.items())
source=r/ins['source']; assert hashlib.sha256(source.read_bytes()).hexdigest()==ins['sha256']
font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25)
small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
points=[]; faces=[]; edge=[]; roots={}; clawfaces={}; boundary={}
def ring(pts,kind):
 start=len(points); points.extend(pts)
 for j in range(len(pts)):edge.append((start+j,start+(j+1)%len(pts),kind))
 return list(range(start,start+len(pts)))
def join(a,b):
 for j in range(len(a)):
  faces.append([a[j],a[(j+1)%len(a)],b[(j+1)%len(b)],b[j]])
  edge.append((a[j],b[j],'rail'))
def station(x,y,z,w,d,side):
 # The YZ cross-section plane is perpendicular to the hand's approximate axis.
 return [(side*(x+math.cos(j*math.pi/4)*w),y+math.sin(j*math.pi/4)*d*.69,z+math.sin(j*math.pi/4)*d*.72) for j in range(8)]
for side in [1,-1]:
 ids=set(int(i) for i in ins['arm_vertices'][str(side)])
 cf=[fi for fi,f in enumerate(g['faces']) if g['materials'][fi]=='d_claw' and all(i in ids for i in f)]
 clawfaces[str(side)]=cf
 # Root quadrilaterals are identified from actual claw skin: the four high-Z
 # corners, rather than bone tails or a guessed Concept joint.
 for digit,cond in [(1,lambda x:abs(x)<.62),(2,lambda x:abs(x)>.62)]:
  verts={tuple(current[i]) for fi in cf for i in g['faces'][fi] if cond(current[i][0])}
  base=sorted([v for v in verts if v[2]>1.09],key=lambda v:math.atan2(v[1]-1.70,v[0]-side*(.56 if digit==1 else .68)))
  assert len(base)==4
  root=[sum(v[k] for v in base)/4 for k in range(3)]
  roots[f'{side}_{digit}']={'center':root,'actual_root_corners':base}
  # Exact claw-base corners remain fixed. Double corners allow an eight-rail
  # sleeve to terminate at the actual four-sided base, without moving the claw.
  end=[]
  for j in range(4):
   end.extend([base[j],tuple((base[j][k]+base[(j+1)%4][k])/2 for k in range(3))])
  x=.578 if digit==1 else .662
  a=ring(station(x,1.657,1.215,.037,.037,side),'digit')
  b=ring(station((x+abs(root[0]))/2,1.684,1.157,.036,.033,side),'digit')
  # Match ring winding by nearest cyclic correspondence for illustration only.
  choices=[end[j:]+end[:j] for j in range(8)]
  end=min(choices,key=lambda pts:sum(sum((points[b[i]][k]-pts[i][k])**2 for k in range(3)) for i in range(8)))
  c=ring(end,'fixed'); join(a,b);join(b,c)
 palm1=ring(station(.62,1.585,1.272,.067,.048,side),'boundary')
 palm2=ring(station(.62,1.650,1.218,.075,.037,side),'palm');join(palm1,palm2)
 boundary[str(side)]=[points[i] for i in palm1]
def cv(pt,name):
 m=cams[name]['matrix']; q=[pt[i]-m[i][3] for i in range(3)]
 return [sum(m[j][i]*q[j] for j in range(3)) for i in range(3)]
def proj(pt,name):
 v=cv(pt,name); rec=cams[name]
 scale=1100/rec['scale'] if rec.get('camera_type','ORTHO')=='ORTHO' else 1100*rec['lens']/36/(-v[2])
 return (550+v[0]*scale,550-v[1]*scale)
views=[('left_hand_front_unmasked','正面近距離：掌端提早分成兩指'),('left_palm','掌側：兩個短指體，各自承接爪根'),('left_outer','側面：保留短手與爪的位置'),('left_hand_unmasked','左3/4：指體與爪根連續方向'),('right_hand_unmasked','右3/4：相同設計，鏡像檢查'),('full_body_side','全身：手端局部提案，不更改主比例')]
for name,title in views:
 base=Image.open(s/'captures'/f'{name}.png').convert('RGB')
 right=Image.blend(base,Image.new('RGB',base.size,(28,37,44)),.50)
 lay=Image.new('RGBA',base.size); d=ImageDraw.Draw(lay)
 def visible(indices):
  return not (name.startswith('left') and points[indices[0]][0]<0 or name.startswith('right') and points[indices[0]][0]>0)
 for f in sorted(faces,key=lambda f:sum(cv(points[i],name)[2] for i in f)):
  if not visible(f):continue
  d.polygon([proj(points[i],name) for i in f],fill=(76,220,198,65))
 for a,b,kind in edge:
  if not visible([a,b]):continue
  col=(255,189,82,255) if kind=='fixed' else (204,117,244,255) if kind=='boundary' else (92,239,211,220)
  d.line([proj(points[a],name),proj(points[b],name)],fill=col,width=2)
 for side,cf in clawfaces.items():
  if name.startswith('left') and side=='-1' or name.startswith('right') and side=='1':continue
  for fi in cf:
   vs=[proj(current[i],name) for i in g['faces'][fi]]
   d.line(vs+[vs[0]],fill=(255,189,82,160),width=2)
 for n,b in ins['arm_bones'].items():
  if not n.startswith(('hand','finger')):continue
  if name.startswith('left') and n.endswith('_r') or name.startswith('right') and n.endswith('_l'):continue
  d.line([proj(b['head_world'],name),proj(b['tail_world'],name)],fill=(242,125,172,200),width=2)
 right=Image.alpha_composite(right.convert('RGBA'),lay).convert('RGB')
 canvas=Image.new('RGB',(1600,990),(24,35,45)); dd=ImageDraw.Draw(canvas)
 dd.text((25,15),'01P.1｜'+title,font=font,fill='white')
 dd.text((25,65),'核可O2 v003｜現況',font=font,fill='white')
 dd.text((825,65),'共同3D手端包絡｜非改後模型',font=font,fill='white')
 canvas.paste(base.resize((760,760)),(20,110));canvas.paste(right.resize((760,760)),(820,110))
 dd.text((25,885),'綠：掌指量體提案　金：現有爪與固定爪根　粉：真實骨軸　紫：近腕銜接候選',font=small,fill=(215,229,238))
 dd.text((25,930),'掌／指包絡尚未連成施工網格；近腕邊界尚未貼合。Rig與来源模型未改。',font=small,fill=(215,229,238))
 canvas.save(p/f'{name}_schematic.png')
geometry={'role':'design_envelope_only_not_model_edit','points':points,'faces':faces,'edges':edge,'actual_claw_roots':roots,'near_wrist_boundary_candidate':boundary,'same_geometry_all_views':True,'claws_unchanged':True,'palm_digit_seam_solved':False,'wrist_boundary_fitted':False,'weights_transferred':False,'dynamic_verified':False,'rig_edited':False,'source_hash':ins['sha256'],'source_arm_coordinates_verified_against_current_inspection':True}
(p/'schematic_geometry.json').write_text(json.dumps(geometry,indent=2))
(p/'source_hash_verification.json').write_text(json.dumps({'source':ins['source'],'sha256_before':ins['sha256'],'sha256_after':hashlib.sha256(source.read_bytes()).hexdigest(),'unchanged':True},indent=2))
body='''# 01P.1 手端共同立體示意

2026-10-09｜使用者核准試做。基準01O.2 v003；本輪為設計示意，未改模型。

掌端保留紧湊量體，較早分成兩個短指體，再收向既有爪根。目的不是增長或放大整手，而是讓掌、雙指與爪具有可讀的連續方向。參考Concept #4的掌→指→爪輪廓與#5的短臂主次；不照AI關節標籤推定解剖規格。

六視角使用同一三維包絡與已有鏡頭；粉線為O2實際骨軸，金線為現有爪的實際角點。骨尾不是爪根；兩個爪根以現有d_claw四個高位角點定位。指體終端使用這些原角點，爪形、長度與位置保持。來源手臂坐標逐項對照最新O2 inspection，與舊面／材質查表完全一致，沒有拿舊身體當新模型。

點評：正面與掌側應能讀到雙指開始分化的位置，3/4可比較爪根量體；側面仍允許兩指自然重疊。保持上臂／前臂與肩胸的主要量體。這是方向包絡，掌指三套袖面仍分開，近腕紫色截面未與原皮共點貼合；圖中的連續感不等於接口或蒙皮已成功。全身手端很小，不應因此擴大到整條手臂。

建議下一步：方向核准後做最小獨立Prototype，先解算近腕固定邊界及掌指共面，限定掌指外皮，保持现有爪与Rig；核對非目標面、來源hash、weights及固定角點，再用正／掌／左右3/4／側／全身和有限前肢姿態檢查。若固定爪根限制太強，先回報，不自行改爪或骨架。避免整手加厚、指節精雕及人手式大張指。尚未開始此Mesh Pass。

風險：雙指過分張開像人手；加厚遮住分化；三套包絡接合可能出現尖折；固定現有直爪使Concept彎鉤感仍有限。本次沒有新Blender模型、GLB、動態／碰撞／遊戲驗收。
'''
(p/'DESIGN.md').write_text(body)
sections=''.join(f'<section><h2>{html.escape(title)}</h2><img src="{name}_schematic.png"></section>' for name,title in views)
refs=''.join(f'<img src="../2026-10-09-review-v001/{name}.png">' for name in ['concept_hand_detail','concept_short_arm'])
(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01P.1 手端立體示意</title><style>body{background:#18232d;color:#e9edf0;font:18px sans-serif;max-width:1500px;margin:30px auto;padding:20px}img{max-width:100%;height:auto}section{margin:35px 0}p{line-height:1.7}a{color:#77dfd2}</style><h1>01P.1 手端立體示意｜待審</h1><p>保持短臂與現有爪；綠色為共同三維掌指包絡，尚未修改工作模型。較早分指，以短厚指體收向固定爪根。</p><p>掌指共面與近腕邊界尚未解算，示意不是已驗收網格。<a href="DESIGN.md">完整點評與下一步</a></p><h2>Concept參考</h2>'+refs+sections+'</html>')
assert hashlib.sha256(source.read_bytes()).hexdigest()==ins['sha256']
print('6 coherent 3D design views; source hash unchanged')
