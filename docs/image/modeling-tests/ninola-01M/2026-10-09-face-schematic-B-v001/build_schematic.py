from pathlib import Path
import json,base64,math
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-face-schematic-B-v001';p.mkdir(exist_ok=True);src=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v004/captures';settings=json.loads((src/'capture_settings_01M4.json').read_text());diag=json.loads((p.parent/'2026-10-09-face-proposal-v001/gaze_diagnostic.json').read_text())
def embed(path):return 'data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
def project(point,view):
 rec=settings[view];m=rec['matrix'];d=[point[i]-m[i][3] for i in range(3)];v=[sum(m[j][i]*d[j] for j in range(3)) for i in range(3)]
 fac=1100/rec['scale'] if rec['camera_type']=='ORTHO' else 1100*rec['lens']/36/(-v[2]);return (550+v[0]*fac,550-v[1]*fac)
# Shared conceptual section lines, not an editable mesh or exact parameter prescription.
stations=[(2.78,.17,.43,2.61,2.43,2.12),(3.02,.16,.40,2.57,2.39,2.10),(3.28,.15,.35,2.51,2.33,2.09),(3.50,.14,.29,2.43,2.26,2.08),(3.65,.12,.23,2.35,2.21,2.09),(3.73,.09,.16,2.28,2.18,2.12)]
sections=[]
for y,cw,sw,top,side,low in stations:sections.append([(-cw,y,top),(cw,y,top),(sw,y,side),(sw*.82,y,low),(-sw*.82,y,low),(-sw,y,side)])
patches=[]
for i in range(len(sections)-1):
 for j,color in [(0,'#68db9c'),(1,'#f8bc72'),(2,'#ee977c'),(4,'#ee977c'),(5,'#f8bc72')]:patches.append(([sections[i][j],sections[i+1][j],sections[i+1][(j+1)%6],sections[i][(j+1)%6]],color))
patches.append((sections[-1],'#68db9c'))
brows=[]
for sign in [-1,1]:
 brows.append([(sign*.22,3.16,2.49),(sign*.32,3.08,2.52),(sign*.405,2.96,2.54),(sign*.46,2.78,2.57),(sign*.37,2.79,2.49),(sign*.34,2.97,2.49),(sign*.25,3.12,2.46)])
eyes=[(sign*.31,2.98,2.425) for sign in [-1,1]];target=diag['common_target_world']
def poly(points,view,color,opacity=.24,width=4):
 ps=' '.join(f'{x:.2f},{y:.2f}' for x,y in [project(a,view) for a in points]);return f'<polygon points="{ps}" fill="{color}" fill-opacity="{opacity}" stroke="{color}" stroke-width="{width}"/>'
def line(points,view,color,width=5,dash=''):
 ps=' '.join(f'{x:.2f},{y:.2f}' for x,y in [project(a,view) for a in points]);return f'<polyline points="{ps}" fill="none" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>'
for view,label in [('head_side','側視｜鼻背至短弧吻端；眉遮有厚度'),('head_top','頂視｜鼻背與斜吻面分組；保留寬厚上顎'),('head_front','正視｜小圓眼深嵌；眉遮強、下眶輕'),('head_threequarter','三分之四｜鼻背・前眶・眉遮連續')]:
 s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1120"><rect width="1600" height="1120" fill="#18232d"/><g font-family="Hiragino Sans GB,sans-serif" fill="#eef3f7"><text x="25" y="46" font-size="32">01M.5 B 結構示意｜{label}</text><text x="25" y="86" font-size="23">左：M4現況　右：同一組三維設計線投影；示意不是修改後渲染。</text>']
 for offset,overlay in [(20,False),(820,True)]:
  s.append(f'<g transform="translate({offset},118) scale(.69)"><image href="{embed(src/(view+"_01M4.png"))}" width="1100" height="1100" opacity="{.28 if overlay else 1}"/>')
  if overlay:
   for pts,color in patches:s.append(poly(pts,view,color))
   for pts in brows:
    s.append(poly(pts,view,'#80b7ff',.40,5))
    underside=[(x,y,z-.055) for x,y,z in pts]
    for j in range(len(pts)):
     k=(j+1)%len(pts);s.append(poly([pts[j],pts[k],underside[k],underside[j]],view,'#80b7ff',.15,2))
   for center in eyes:
    # Wire sphere makes orbital depth legible without pretending it is a finished eyeball.
    for axes in [(0,1),(0,2),(1,2)]:
     ring=[]
     for k in range(33):
      pt=list(center);t=k*2*math.pi/32;pt[axes[0]]+=.07*math.cos(t);pt[axes[1]]+=.07*math.sin(t);ring.append(pt)
     s.append(line(ring,view,'#f6d175',3))
    direction=[target[i]-center[i] for i in range(3)];length=math.sqrt(sum(v*v for v in direction));end=[center[i]+direction[i]/length*.44 for i in range(3)]
    s.append(line([center,end],view,'#f6d175',4,'9 6'));x,y=project(end,view);s.append(f'<circle cx="{x}" cy="{y}" r="5" fill="#f6d175"/>')
   # Fixed original inner mouth boundary is context only, no planned jaw/teeth edit.
   s.append(line([(-.22,3.6,2.035),(-.32,3.25,2.00),(-.43,2.85,1.97)],view,'#c4badf',4,'8 7'))
  s.append('</g>')
 s+=['<text x="25" y="938" font-size="24" fill="#68db9c">綠：中央鼻背／弧轉鼻端　橙：斜吻面　珊瑚：上顎侧面</text>','<text x="25" y="978" font-size="24" fill="#80b7ff">藍：前眶接上眉遮　金：小球面眼及前方視軸（方向線縮短顯示）</text>','<text x="25" y="1018" font-size="23">保留M3整体比例；吻端不是尖喙，眉遮不是貼上的人類眉毛或完整厚圓環。</text>','<text x="25" y="1060" font-size="23">下顎／齒列／Rig保持；位置與尺寸仍須Blockout驗證，未驗證遮擋與咬合。</text></g></svg>'];(p/(view+'.svg')).write_text(''.join(s))
# Eye structure close-up, explicitly noncalibrated section diagram.
(p/'eye_section.svg').write_text('''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="920"><rect width="1600" height="920" fill="#18232d"/><g font-family="Hiragino Sans GB,sans-serif" fill="#eef3f7"><text x="35" y="52" font-size="32">B｜眼窩／眉遮剖面與共同注視方向（非尺寸圖）</text><text x="35" y="97" font-size="24">眼球仍位於頭側；眼眶朝前外方開放，圓虹膜提供焦點，眉遮塑造壓迫感。</text><path d="M140 260 Q310 195 460 235 L570 330 L450 350 Q320 285 250 350 L205 535 Q270 570 385 590 L410 650 Q220 650 140 565Z" fill="#4778a0" stroke="#80b7ff" stroke-width="5"/><circle cx="345" cy="455" r="110" fill="#606c73" stroke="#d8e4ee" stroke-width="4"/><ellipse cx="430" cy="432" rx="29" ry="55" fill="#d8ae48" stroke="#f6d175" stroke-width="4"/><ellipse cx="440" cy="432" rx="9" ry="27" fill="#18232d"/><path d="M443 427 L695 360" stroke="#f6d175" stroke-width="5" stroke-dasharray="12 8"/><text x="70" y="210" font-size="25" fill="#80b7ff">上眉有厚度與遮蔽</text><text x="45" y="710" font-size="25">下緣較輕，融入頰面</text><text x="520" y="465" font-size="24" fill="#f6d175">朝前可讀的虹膜</text><text x="925" y="200" font-size="25">頂視：遠方共同目標</text><path d="M950 720 Q990 550 1070 435 Q1130 380 1190 435 Q1270 550 1310 720" fill="#31564a" stroke="#68db9c" stroke-width="4"/><circle cx="950" cy="640" r="35" fill="#606c73" stroke="#f6d175" stroke-width="4"/><circle cx="1310" cy="640" r="35" fill="#606c73" stroke="#f6d175" stroke-width="4"/><path d="M950 640 L1130 260 L1310 640" fill="none" stroke="#f6d175" stroke-width="4" stroke-dasharray="12 8"/><circle cx="1130" cy="260" r="12" fill="#f6d175"/><text x="875" y="780" font-size="23">示意距離壓縮；不把兩眼轉向鼻尖</text><text x="35" y="850" font-size="23">此為結構關係圖，非解剖復原。後續需檢查瞳孔可視面、前眶遮擋及左右3/4一致性。</text></g></svg>''')
(p/'schematic_geometry.json').write_text(json.dumps({'role':'B_design_schematic_not_mesh','stations':stations,'brow_polygons':brows,'eye_centers_conceptual':eyes,'eye_radius_conceptual':.07,'common_target_world':target,'camera_source':str((src/'capture_settings_01M4.json').relative_to(r)),'gaze_lines_shortened_for_display':True,'source_model_edited':False,'dimensions_not_approved_production_parameters':True},indent=2))
page='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 01M.5 B結構示意</title><style>body{max-width:1600px;margin:28px auto;background:#18232d;color:#eef3f7;font:21px sans-serif}p{line-height:1.65}img{width:100%;margin:15px 0}a{color:#9ddaff}</style><h1>01M.5 B｜頭面量體與視線結構示意</h1><p>僅B方向，未修改模型。中央鼻背、斜吻面與上顎協同分組；前眶接上眉遮、小圓眼深嵌。以M4現況作背景、M3保留回退。<a href="REVIEW.md">判讀與下一步</a>。</p><p>彩色線與透明面是設計關係，不是修改後成果，也未證明瞳孔可視性、齒列間隙或Rig相容性。</p>'''
for n in ['head_threequarter','head_side','head_top','head_front','eye_section']:page+=f'<img src="{n}.png">'
(p/'index.html').write_text(page+'</html>');print(p)
