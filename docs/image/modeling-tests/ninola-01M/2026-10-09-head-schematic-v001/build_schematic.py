from pathlib import Path
import json,base64,math,html
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-head-schematic-v001';p.mkdir(exist_ok=True);src=r/'docs/image/modeling-tests/ninola-01M/2026-10-08-pass-v001/refined-v002/captures';settings=json.loads((src/'capture_settings_01M1.json').read_text());inspection=json.loads((src/'inspection.json').read_text())
# One shared conceptual envelope projected into all four source cameras. It is not a mesh or calibrated reconstruction.
stations=[(2.33,.52,2.64,1.95),(2.55,.53,2.68,1.95),(2.85,.49,2.66,1.96),(3.15,.40,2.58,1.98),(3.45,.31,2.48,2.00),(3.70,.23,2.36,2.02)]
points=[]
for y,width,top,bottom in stations:points.extend([(-width,y,top),(width,y,top),(width,y,bottom),(-width,y,bottom)])
edges=[]
for k in range(len(stations)):
 for j in range(4):edges.append((4*k+j,4*k+(j+1)%4))
 if k:
  for j in range(4):edges.append((4*(k-1)+j,4*k+j))
def project(point,view):
 rec=settings[view];m=rec['matrix'];d=[point[i]-m[i][3] for i in range(3)];v=[sum(m[j][i]*d[j] for j in range(3)) for i in range(3)]
 if rec['camera_type']=='ORTHO':scale=1100/rec['scale'];return (550+v[0]*scale,550-v[1]*scale)
 fac=1100*rec['lens']/36/(-v[2]);return (550+v[0]*fac,550-v[1]*fac)
def embed(path):return 'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
for view,title,notes in [('head_side','側視：延展的顱頂與鼻背，避免中央三角峰',['後側厚度来自延展量體，不把眉部堆成最高峰','小吻端有鈍面；頭皮主線與尖刺分開看']),('head_top','頂視：吻端較窄，後顱較寬',['主要梯形關係在長度方向的寬窄分配','後顱側向擴張；頭頸接口固定，不改頸部']),('head_front','正視：檢查後顱寬度、眼眶與吻端',['正視不能照搬側視梯形；避免過寬方塊臉','眼眶先佔位，眉遮與凝視另由灰模建立']),('head_threequarter','三分之四：確認同一量體，不只側視成立',['四視圖皆由同一示意包絡投影，不各畫不同頭','框線代表大形分配，不是完成頭皮或精確Edit Mask'])]:
 s=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1100" viewBox="0 0 1600 1100"><rect width="1600" height="1100" fill="#18232d"/><g font-family="Hiragino Sans GB, sans-serif" fill="#eef3f7">',f'<text x="28" y="48" font-size="32">01M.3 設計示意｜{title}</text>','<text x="28" y="86" font-size="22">左：M1現況＋既有骨軸　右：相同相機上的量體方向；不是新模型，也不是改後預測。</text>']
 for offset,showtarget in [(20,False),(820,True)]:
  s.append(f'<g transform="translate({offset},118) scale(.69)"><image href="{embed(src/(view+"_01M1.png"))}" width="1100" height="1100" opacity="{.43 if showtarget else 1}"/>')
  if showtarget:
   for a,b in edges:
    x,y=project(points[a],view);xx,yy=project(points[b],view);s.append(f'<path d="M{x:.2f},{y:.2f} L{xx:.2f},{yy:.2f}" stroke="#f6c66f" stroke-width="4" opacity=".85" fill="none"/>')
   for k,color in [(0,'#78dcca'),(len(stations)-1,'#ef9c7d')]:
    poly=[project(points[4*k+j],view) for j in range(4)];ps=' '.join(f'{x:.2f},{y:.2f}' for x,y in poly);s.append(f'<polygon points="{ps}" fill="{color}" fill-opacity=".18" stroke="{color}" stroke-width="6"/>')
  for name,color in [('head','#78dcca'),('jaw','#ef9c7d')]:
   a=inspection['bones'][name]['head_world'];b=inspection['bones'][name]['tail_world'];x,y=project(a,view);xx,yy=project(b,view);s.append(f'<line x1="{x}" y1="{y}" x2="{xx}" y2="{yy}" stroke="{color}" stroke-width="5"/><circle cx="{x}" cy="{y}" r="9" fill="{color}"/><text x="{x+14}" y="{y-10}" font-size="28" fill="{color}">{name} 固定</text>')
  if showtarget:
   jaw_stations=[(2.05,.46,1.80,1.44),(2.30,.45,1.80,1.45),(2.60,.43,1.84,1.50),(2.90,.36,1.86,1.60),(3.30,.24,1.88,1.80)]
   jp=[]
   for yy,ww,tt,bb in jaw_stations:jp.extend([(-ww,yy,tt),(ww,yy,tt),(ww,yy,bb),(-ww,yy,bb)])
   je=[]
   for k in range(len(jaw_stations)):
    for j in range(4):je.append((4*k+j,4*k+(j+1)%4))
    if k:
     for j in range(4):je.append((4*(k-1)+j,4*k+j))
   for a,b in je:
    x,y=project(jp[a],view);xx,yy=project(jp[b],view);s.append(f'<path d="M{x},{y} L{xx},{yy}" stroke="#bdabec" stroke-width="3" stroke-dasharray="9 7" fill="none" opacity=".8"/>')
  s.append('</g>')
 s+=['<text x="28" y="935" font-size="24" fill="#f6c66f">黃線：上顱方向　紫虛線：下顎收束方向　綠／橘端：後側大端／吻部小端</text>',f'<text x="28" y="976" font-size="24">{notes[0]}</text>',f'<text x="28" y="1017" font-size="24">{notes[1]}</text>','<text x="28" y="1060" font-size="22">Rig／骨軸、身體／足部、牙齒／舌保持；包絡未作閉口、齒列間隙或變形驗收。</text></g></svg>']
 (p/(view+'.svg')).write_text(''.join(s))
# Reference sheet includes actual unwarped source; annotated interpretation stays separate from image.
ref=r/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/references/user_reference_5.png'
s=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1280"><rect width="1600" height="1280" fill="#18232d"/><g fill="#eef3f7" font-family="Hiragino Sans GB, sans-serif"><text x="30" y="50" font-size="32">Concept依據｜小吻端 → 較大的後顱／頸側量體</text><image href="{embed(ref)}" x="32" y="95" width="1536" height="1024"/><text x="30" y="1166" font-size="24">依據：整體側視與下方Head Detail。梯形是量體關係，不是要求平直四邊形。</text><text x="30" y="1210" font-size="24">Concept含透視、張口與尖刺；不能把圖中頸部一併當作可修改頭部。</text><text x="30" y="1250" font-size="22">此圖不是正交Blueprint。示意包絡的具體尺寸仍需灰模與同姿態動態確認。</text></g></svg>''';(p/'concept_basis.svg').write_text(s)
(p/'schematic_geometry.json').write_text(json.dumps({'role':'design_envelope_only_not_mesh_not_calibrated_concept','units':'source model world coordinates used only for comparable projection','stations_y_halfwidth_top_bottom':stations,'camera_source':str((src/'capture_settings_01M1.json').relative_to(r)),'bone_projection_source':str((src/'inspection.json').relative_to(r)),'rig_edited':False,'teeth_clearance_tested':False},indent=2))
page='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01M.3頭型設計示意</title><style>body{background:#18232d;color:#eef3f7;max-width:1600px;margin:30px auto;font:21px sans-serif}img{width:100%;margin:20px 0}p{line-height:1.6}a{color:#9ddaff}</style><h1>01M.3｜整頭量體方向，尚未建模</h1><p>以Concept為依歸：吻端較小、後顱側較大；保留鈍吻、延展顱頂，不用中央尖峰取得厚度。<a href="REVIEW.md">判讀與保護範圍</a></p>'
for name in ['concept_basis','head_side','head_top','head_front','head_threequarter']:page+=f'<img src="{name}.png">'
(p/'index.html').write_text(page+'</html>')
print('Native SVG schematics written; no Blender model changes.')
