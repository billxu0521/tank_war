from pathlib import Path
import json,math,html,hashlib
from PIL import Image,ImageDraw,ImageFont
r=Path.cwd();p=Path(__file__).resolve().parent;src=p.parent/'2026-10-09-review-v001';settings=json.loads((src/'captures/capture_settings_01N1.json').read_text());ins=json.loads((p/'constraint_inspection.json').read_text());font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',21)
# Design control stations; not measurements of the Concept or fitted editable surface.
stations=[(2.24,.55,2.62,1.78),(2.08,.59,2.68,1.71),(1.88,.61,2.73,1.58),(1.66,.65,2.77,1.46),(1.44,.70,2.81,1.33),(1.20,.77,2.84,1.21),(.96,.87,2.87,1.12),(.72,.96,2.89,1.08)]
points=[]
for y,w,t,b in stations:
 z=(t+b)/2;hh=(t-b)/2
 # Broad side planes, narrowed dorsal/ventral rails, no circular bead sections.
 points.extend([(x,y,zz) for x,zz in [(0,t),(.50*w,t-.07*hh),(w,z+.34*hh),(.92*w,z-.46*hh),(.50*w,b+.10*hh),(0,b),(-.50*w,b+.10*hh),(-.92*w,z-.46*hh),(-w,z+.34*hh),(-.50*w,t-.07*hh)]])
edges=[];faces=[]
for k in range(len(stations)):
 for j in range(10):edges.append((10*k+j,10*k+(j+1)%10,'section'))
for k in range(1,len(stations)):
 for j in range(10):
  edges.append((10*(k-1)+j,10*k+j,'rail'));faces.append([10*(k-1)+j,10*(k-1)+(j+1)%10,10*k+(j+1)%10,10*k+j])
def cv(pt,view):
 rec=settings[view];m=rec['matrix'];q=[pt[i]-m[i][3] for i in range(3)];return [sum(m[j][i]*q[j] for j in range(3)) for i in range(3)]
def proj(pt,view):
 rec=settings[view];v=cv(pt,view);s=1100/rec['scale'] if rec['camera_type']=='ORTHO' else 1100*rec['lens']/36/(-v[2]);return (550+v[0]*s,550-v[1]*s)
views=[('torso_side','側面：連續背線與喉底→前胸腹線'),('torso_top','頂視：厚頸→肩胸漸變，不新增窄腰'),('torso_threequarter','左3/4：胸腔保持厚度，承接頸根'),('torso_right_threequarter','右3/4：同一組截面，檢查兩側'),('full_body_side','全身：保留水平姿態與厚實核心')]
for view,title in views:
 base=Image.open(src/'captures'/f'{view}_01N1.png').convert('RGB');right=Image.blend(base,Image.new('RGB',base.size,(25,35,45)),.64);layer=Image.new('RGBA',base.size);d=ImageDraw.Draw(layer)
 for face in sorted(faces,key=lambda f:sum(cv(points[i],view)[2] for i in f)):
  d.polygon([proj(points[i],view) for i in face],fill=(80,180,175,28))
 for aa,bb,kind in edges:d.line([proj(points[aa],view),proj(points[bb],view)],fill=(242,197,103,190) if kind=='section' else (106,228,207,235),width=2 if kind=='section' else 3)
 for name in ['arm_l','arm_r']:
  pt=ins['bones'][name]['head_world'];x,y=proj(pt,view);d.ellipse((x-8,y-8,x+8,y+8),fill=(249,126,181,255));d.text((x+10,y-25),name,font=small,fill=(249,126,181,255))
 right=Image.alpha_composite(right.convert('RGBA'),layer).convert('RGB');c=Image.new('RGB',(1600,1040),(24,35,45));dd=ImageDraw.Draw(c);dd.text((25,12),'01O.1｜'+title,font=font,fill='white');dd.text((25,58),'目前核可 N1 v004',font=font,fill='white');dd.text((825,58),'共同3D包絡示意｜非改後模型',font=font,fill='white');c.paste(base.resize((760,760)),(20,103));c.paste(right.resize((760,760)),(820,103));dd.text((25,887),'綠：連續主線　金：共用截面　粉：真實前肢骨根（不是已解算皮膚接口）',font=small,fill=(242,197,103));dd.text((25,936),'保留厚頸胸腔；重新分配頸肩轉折與前胸腹側，不全面加厚或削瘦。',font=font,fill='white');dd.text((25,986),'包絡為設計控制值；固定邊界尚未貼合，棘刺／頭顎／前肢／Rig未改。',font=small,fill='white');c.save(p/f'{view}_schematic.png')
# cross sections in common world scale
c=Image.new('RGB',(1600,720),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'截面節奏｜同一world尺度的厚頸、肩前、胸腔',font=font,fill='white')
for x,k,label in [(280,1,'厚頸 y=2.08'),(790,4,'肩前 y=1.44'),(1310,6,'胸腔 y=0.96')]:
 y,w,t,b=stations[k];poly=[(x+pt[0]*210,140+(3.0-pt[2])*210) for pt in points[10*k:10*k+10]];d.polygon(poly,fill=(48,93,94));d.line(poly+[poly[0]],fill=(242,197,103),width=5);d.text((x-180,90),label,font=font,fill='white')
d.text((25,610),'寬度逐步進入胸腔；背線與腹線各有方向，避免同尺寸球塊串接。',font=font,fill='white');d.text((25,660),'設計截面尚未與固定原皮膚共點貼合；非口腔／肌肉解剖剖面。',font=small,fill='white');c.save(p/'sections.png')
(p/'schematic_geometry.json').write_text(json.dumps({'role':'coherent_3D_envelope_design_only_not_edited_model','stations_y_halfwidth_top_bottom':stations,'points':points,'edges':edges,'faces':faces,'same_geometry_all_views':True,'camera_source':str((src/'captures/capture_settings_01N1.json').relative_to(r)),'boundary_fit_solved':False,'protected_seam_solved':False,'weights_transferred':False,'rig_edited':False,'source_model_edited':False,'dynamic_tested':False,'ends':'open design sleeve; ends are not holes in source model'},indent=2))
text='''# 01O.1 頸肩胸共同包絡設計

2026-10-09｜使用者核准嘗試上一輪提出的設計示意。基準01N.1 v004，模型未改。

## 設計與點評

同一三維包絡、8個截面、10點截角截面，投影到側／頂／左右3/4及全身鏡頭；不是各視圖分別畫出互不相容的曲線。截面值是提案控制值，不是Concept量測值或已貼合來源表面。

厚頸保持，向肩胸逐步展寬；背線用長緩轉折承接，避免頸肩各自鼓起成相鄰球塊。喉底向前胸平順下降，胸腹最低段保留深度，避免前肢後方吊掛的獨立尖塊。大側面、肩轉面與收束腹側有主次；沒有加皺紋／肌束等精修。

本次示意使連續方向更清楚，但還有兩點風險：正面厚頸若填得過滿會失去活動分界；前胸下緣若照單一包絡整片替换會遮住前肢接口。應在實體試作以局部漸變、固定附著及原胸深控制，不照線框整區縮放。

## 實際定位與保护

唯讀Blender5.2.2重開N1，僅隔離當前Object，使用實際evaluated座標、材質與權重定位；45骨／Trex原keys值留存。894個頸／脊椎主權重皮膚點為位置候選，其中391點與保留面共點；這不等於894點已獲授權可改，或391點全部是單一接口。未使用未被face引用的鬆散點作形狀界定。

粉點為真實arm_l/arm_r骨根：前肢皮膚附著不能由骨根點代替。頭頸邊界、前肢根部與胸後端共享拓樸仍須實體試作前另解算。不得修改頭顎／眼／牙列／口腔／頭刺、前肢手、後肢足、骨盆尾根或尾巴。Rig/Bones/name/hierarchy/rest/joint centers完全硬鎖；原Trex Shape Keys不改。棘刺附著若與外殼新表面產生間隙先回報，不自行移刺。

## Concept與歷史

目標仍為Concept厚頸承托頭部、厚胸核心与水平向後收束。視角／姿态不同，不宣稱與Concept尺寸精準相同。01B胸肩與軀幹歷史核可保留，此輪只重整新頭后的接口節奏。來源見前輪review的Concept與Library記錄；AI肌肉圖非解剖實證。當前頭顎／身體角面差異留後續全身風格統整，不藉此全面平滑身體。

## 下一建議（未執行）

若接受方向，01O.1獨立粗模試作：先建立可回退外殼mask、固定頭頸和前肢根部及胸後邊界；小範圍轉移／重整頸肩連續截面與前胸腹線，保留主要胸深，外殼新面weights以實際來源轉移。若保护边界阻礙此大形，停止受影响区并提出范围，不擅自跨锁。

驗收：固定鏡頭灰模與全身比較，主要轉接改善、沒有新窄頸／駝峰、胸腔重量仍在；核對固定點、非目標面／材質／骨架／keys與來源SHA。必要頸部与身體pose只在evaluation副本驗證；試作通過不等於Production Shape Keys或整合完成。目標只做方向粗模，不局部無限精修。
'''
(p/'DESIGN.md').write_text(text)
fig=''.join(f'<figure><figcaption>{html.escape(title)}</figcaption><a href="{v}_schematic.png"><img src="{v}_schematic.png"></a></figure>' for v,title in views)
(p/'index.html').write_text('''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Ninola 01O.1 共同包絡示意</title><style>body{background:#18232d;color:#eaf0f4;font:18px/1.75 system-ui;max-width:1600px;margin:28px auto;padding:0 22px}a{color:#80d6ff}figure,section{background:#253540;padding:18px;margin:24px 0}img{width:100%}figcaption{font-weight:bold}h1{font-size:30px}</style><h1>01O.1｜頸根—肩胸—前胸腹側共同包絡</h1><section><p>同一組3D截面、多視角投影。模型與Rig未修改；N1 v004仍工作基準。</p><p>保留厚頸與胸腔，重新安排轉接：背線長緩轉折、側面逐步展寬、喉底接到前胸腹線。先看方向與全身效果，不精修肌束。</p><p>綠線是主線、金線是截面、粉點是前肢骨根。線框不是已建好的新皮膚，也沒有解算固定接口或動態。</p><p><a href="DESIGN.md">點評、保護範圍與下一步試作建議</a> · <a href="INDEPENDENT_REVIEW.md">獨立審視</a> · <a href="../2026-10-09-review-v001/index.html">Concept與前輪審視</a></p></section>'''+fig+'<figure><figcaption>同尺度截面節奏</figcaption><img src="sections.png"></figure></html>')
assert hashlib.sha256((r/ins['source']).read_bytes()).hexdigest()==ins['sha256'];print('5 views and sections created; source SHA unchanged')
