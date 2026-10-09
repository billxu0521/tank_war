from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json,math
r=Path.cwd();p=Path(__file__).resolve().parent;src=p.parent/'2026-10-09-review-v001/captures';settings=json.loads((src/'capture_settings_01M8.json').read_text());inspection=json.loads((src/'inspection.json').read_text());geo=json.loads((p/'source_geometry.json').read_text());fontpath='/System/Library/Fonts/Hiragino Sans GB.ttc'
font=ImageFont.truetype(fontpath,26);small=ImageFont.truetype(fontpath,22)
# Coherent external volume proposal in original world pose; not calibrated Concept measurements.
# Top rail is a design guide; actual fixed tooth/oral boundary must be retained in any future build.
stations=[(2.07,.49,1.79,1.48),(2.30,.49,1.78,1.44),(2.55,.47,1.83,1.45),(2.80,.42,1.83,1.49),(3.02,.38,1.86,1.54),(3.22,.34,1.88,1.58),(3.37,.28,1.88,1.64)]
points=[]
for y,w,t,b in stations:
 # Open U exterior contour, thickness concentrated at sides; truncated base not box or pointed chin.
 points.extend([(x,y,z) for x,z in [(-w,t),(-w,t-.08),(-.90*w,b+.075),(-.68*w,b),(0,b-.01),(.68*w,b),(.90*w,b+.075),(w,t-.08),(w,t)]])
edges=[]
for k in [0,2,4,6]:
 for j in range(8):edges.append((9*k+j,9*k+j+1,'section'))
for k in range(1,len(stations)):
 for j in [0,2,3,5,6,8]:edges.append((9*(k-1)+j,9*k+j,'rail'))
def project(pt,view):
 rec=settings[view];m=rec['matrix'];d=[pt[i]-m[i][3] for i in range(3)];v=[sum(m[j][i]*d[j] for j in range(3)) for i in range(3)]
 if rec['camera_type']=='ORTHO':scale=1100/rec['scale'];return (550+v[0]*scale,550-v[1]*scale)
 fac=1100*rec['lens']/36/(-v[2]);return (550+v[0]*fac,550-v[1]*fac)
colors={'section':(246,198,111),'rail':(111,220,200)}
for view,title in [('head_side_color','側面：顎身要有厚度，前中後段一起看'),('head_front_color','正面：有厚度的U形，避免薄片／尖下巴'),('head_threequarter_color','三分之四：側面、轉面與底面形成實體'),('head_bottom','底面：寬度漸變與收束腹面')]:
 base=Image.open(src/f'{view}_01M8.png').convert('RGB');right=Image.blend(base,Image.new('RGB',base.size,(35,42,49)),.60);d=ImageDraw.Draw(right)
 for aa,bb,kind in edges:
  a=project(points[aa],view);b=project(points[bb],view);d.line([a,b],fill=colors[kind],width=4 if kind=='rail' else 3)
 fixed=[]
 for i in geo['protected_coincident_skin']:
  pt=geo['vertices'][i];key=tuple(round(v,4) for v in pt)
  if key not in fixed:fixed.append(key)
 for pt in fixed:
  x,y=project(pt,view);d.ellipse((x-3,y-3,x+3,y+3),fill=(239,125,169))
 a=project(inspection['bones']['jaw']['head_world'],view);b=project(inspection['bones']['jaw']['tail_world'],view);d.line([a,b],fill=(147,189,255),width=5);d.ellipse((a[0]-8,a[1]-8,a[0]+8,a[1]+8),fill=(147,189,255))
 c=Image.new('RGB',(1600,1030),(24,35,45));dd=ImageDraw.Draw(c);dd.text((25,10),'01N.1｜'+title,font=font,fill='white');dd.text((25,57),'M8目前核可模型',font=font,fill='white');dd.text((825,57),'同一組3D外顎包絡｜設計示意，非改後模型',font=small,fill='white');c.paste(base.resize((760,760)),(20,100));c.paste(right.resize((760,760)),(820,100));dd.text((25,880),'金色：截面　綠色：外顎主線　粉色：固定共點候選　藍色：真實jaw骨軸',font=small,fill=(246,198,111));dd.text((25,925),'側顎保持實體厚度；底面截角收束，不削成薄片或尖下巴。',font=font,fill='white');dd.text((25,972),'固定點與包絡的接合尚未解算；未作牙列間隙／張閉口驗收，Rig與模型未改。',font=small,fill='white');c.save(p/f'{view}_schematic.png')
# Profile isolated from camera overlap so the thickness progression can be read independently.
c=Image.new('RGB',(1600,780),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'三段量體｜顎身有深度，側厚與腹面轉折共同成立',font=font,fill='white')
for x,k,label in [(25,6,'吻端：厚實鈍端'),(555,3,'顎身：有力側面＋收束底面'),(1085,1,'後顎：保留厚度與活動空間')]:
 y,w,t,b=stations[k];center=x+220;top=180;scale=500;outer=[(center+points[9*k+j][0]*scale,top+(t-points[9*k+j][2])*scale) for j in range(9)]
 d.polygon(outer+[(center,top)],fill=(82,77,60));d.line(outer,fill=(246,198,111),width=7);d.line([outer[0],outer[-1]],fill=(239,125,169),width=4);d.text((x,95),label,font=small,fill='white');d.text((x,465),'上口緣僅作位置參照',font=small,fill=(239,125,169));d.text((x,510),'此為外殼包絡，不是口腔剖面',font=small,fill='white')
d.text((25,635),'截面共用來源world尺度，形狀為提案；粉線不代表可修改的嘴內表面。',font=font,fill='white');d.text((25,690),'不是紅框長方形；不把後顎厚度堆成向下吊掛的獨立方塊。',font=font,fill='white');c.save(p/'sections.png')
(p/'schematic_geometry.json').write_text(json.dumps({'role':'external_volume_design_only_not_mesh_or_validated_result','stations_y_halfwidth_top_bottom':stations,'points':points,'edges':edges,'camera_source':str((src/'capture_settings_01M8.json').relative_to(r)),'bone_projection_source':str((src/'inspection.json').relative_to(r)),'same_geometry_all_views':True,'pose_edited':False,'source_model_edited':False,'rig_edited':False,'fixed_boundary_fit_solved':False,'tooth_clearance_tested':False,'dynamic_tested':False},indent=2))
ref=Image.open(p/'references/user_annotated_jaw_concept.png').convert('RGB');c=Image.new('RGB',(1600,980),(24,35,45));d=ImageDraw.Draw(c);d.text((25,10),'使用者Concept標註｜红框表示顎身實體厚度，非矩形規格',font=font,fill='white');c.paste(ImageOps.contain(ref.crop((800,565,1330,825)),(1500,750)),(50,90));d.text((25,880),'張口／視角不同，不能由此推算模型下顎長度、厚度或骨軸。',font=font,fill='white');c.save(p/'concept_basis.png')
print('Coherent 3D jaw envelope and 4 views generated; source model unchanged.')
