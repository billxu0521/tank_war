from pathlib import Path
import json,base64,math
r=Path.cwd();p=Path(__file__).resolve().parent;src=p.parent/'2026-10-09-pass-v003/refined-v006/captures';settings=json.loads((src/'capture_settings_01M3.json').read_text());audit=json.loads((p/'audit_geometry.json').read_text());source=audit['01M3']
def embed(f):return 'data:image/png;base64,'+base64.b64encode(f.read_bytes()).decode()
def project(q,view):
 rec=settings[view];m=rec['matrix'];d=[q[i]-m[i][3] for i in range(3)];v=[sum(m[j][i]*d[j] for j in range(3)) for i in range(3)];fac=1100/rec['scale'] if rec['camera_type']=='ORTHO' else 1100*rec['lens']/36/(-v[2]);return 550+v[0]*fac,550-v[1]*fac
colors={'nasal':'#75d49b','snout':'#edb96b','maxilla':'#e39078','orbit':'#83b9ed','rear':'#b1a7d4'}
# Proposed large-scale sections. Shared across all views; design only, not production dimensions.
stations=[(2.35,.52,2.68,2.06),(2.65,.51,2.66,2.055),(2.92,.45,2.61,2.045),(3.20,.38,2.53,2.035),(3.46,.31,2.44,2.045),(3.65,.24,2.34,2.055),(3.75,.17,2.25,2.095)]
sections=[]
for y,w,t,b in stations:
 sections.append([(0,y,t),(w*.47,y,t-.06*(t-b)),(w*.85,y,t-.23*(t-b)),(w,y,b+(t-b)*.47),(w*.87,y,b),(-w*.87,y,b),(-w,y,b+(t-b)*.47),(-w*.85,y,t-.23*(t-b)),(-w*.47,y,t-.06*(t-b))])
faces=[]
for i in range(len(sections)-1):
 for j in range(9):
  k=(j+1)%9;region='rear' if i<1 else ('nasal' if j in [0,8] else 'snout' if j in [1,7] else 'maxilla');faces.append(([sections[i][j],sections[i+1][j],sections[i+1][k],sections[i][k]],colors[region]))
faces.append((sections[-1],colors['snout']))
# Integrated orbital support panels, separated upper/pre/post/cheek instead of radial eye fan.
orbital=[]
for sign in [-1,1]:
 S=lambda x,y,z:(sign*x,y,z)
 orbital.extend([
  ([S(.22,3.19,2.50),S(.30,3.08,2.57),S(.43,2.91,2.59),S(.48,2.65,2.61),S(.39,2.72,2.50),S(.35,2.94,2.48),S(.27,3.12,2.43)],colors['orbit']),
  ([S(.27,3.12,2.43),S(.35,2.94,2.48),S(.34,2.96,2.35),S(.30,3.13,2.30)],colors['snout']),
  ([S(.39,2.72,2.50),S(.48,2.65,2.61),S(.50,2.50,2.36),S(.43,2.71,2.24),S(.40,2.83,2.34)],colors['rear']),
  ([S(.30,3.13,2.30),S(.34,2.96,2.35),S(.40,2.83,2.34),S(.43,2.71,2.24),S(.38,2.88,2.09),S(.31,3.13,2.09)],colors['maxilla'])])
# Exact legacy boundary edges around mouth/head neck are shown separately from proposed envelope.
legacy_edges=set()
for f in source['faces'][5999:]:
 for i,j in zip(f,f[1:]+f[:1]):
  if i<10444 and j<10444:legacy_edges.add(tuple(sorted((i,j))))
def poly(points,view,color,fill=.18):
 ps=' '.join(f'{x:.2f},{y:.2f}' for x,y in [project(q,view) for q in points]);return f'<polygon points="{ps}" fill="{color}" fill-opacity="{fill}" stroke="{color}" stroke-width="3"/>'
def line(a,b,view,color='#d2c5eb',dash='9 6'):
 x,y=project(a,view);xx,yy=project(b,view);return f'<path d="M{x},{y}L{xx},{yy}" stroke="{color}" stroke-width="4" stroke-dasharray="{dash}" fill="none"/>'
for view,label in [('head_side','側視：延展顱頂、鼻端短弧與上顎厚度'),('head_top','頂視：後顱→眶區→鼻背→寬厚弧轉吻端'),('head_front','正視：眶上包覆、眼下承托與中央鼻背'),('head_threequarter','三分之四：整頭主面共同形成威懾感')]:
 s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1120"><rect width="1600" height="1120" fill="#18232d"/><g fill="#eef3f7" font-family="Hiragino Sans GB,sans-serif"><text x="25" y="46" font-size="31">01M.6 整頭設計｜{label}</text><text x="25" y="86" font-size="23">左：已接受M3基準　右：共用三維設計截面；不是修改後模型。</text>']
 for off,overlay in [(20,False),(820,True)]:
  s.append(f'<g transform="translate({off},118) scale(.69)"><image href="{embed(src/(view+"_01M3.png"))}" width="1100" height="1100" opacity="{.20 if overlay else 1}"/>')
  if overlay:
   for pts,col in faces+orbital:s.append(poly(pts,view,col,.16 if col!=colors['orbit'] else .35))
   for sign in [-1,1]:
    center=(sign*.355,2.94,2.435);ring=[(center[0],center[1]+.057*math.cos(k*2*math.pi/32),center[2]+.047*math.sin(k*2*math.pi/32)) for k in range(33)];s.append(poly(ring,view,'#f3d580',.20))
   for i,j in legacy_edges:s.append(line(source['coords'][i],source['coords'][j],view))
  s.append('</g>')
 s+=['<text x="25" y="935" font-size="24" fill="#75d49b">綠：鼻背　金橙：斜吻面　珊瑚：上顎／頰部　藍：前眶／上眉　紫：後顱</text>','<text x="25" y="976" font-size="23">紫虛線取自實際M3固定邊界；整頭主面重建，眼區不用長面拉回小眼圈。</text>','<text x="25" y="1017" font-size="23">外殼包絡與固定口緣仍須銜接；透明面穿透顯示，不能當新模型可見性證據。</text>','<text x="25" y="1060" font-size="23">下顎／齒列／舌／Rig保持；尺寸暫擬，先審整頭關係，再批准Blockout。</text></g></svg>'];(p/(view+'_design.svg')).write_text(''.join(s))
# Region audits use measured region centroids; label interpretation remains I/D, not fossil landmarks.
for view in ['head_side','head_top','head_front','head_threequarter']:
 s=[f'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1050"><rect width="1600" height="1050" fill="#18232d"/><g fill="#eef3f7" font-family="Hiragino Sans GB,sans-serif"><text x="25" y="45" font-size="31">M3區域定位｜{view}｜I/D，非骨縫測量</text><image href="{embed(src/(view+"_01M3.png"))}" x="20" y="100" width="820" height="820"/>']
 for k,lid in enumerate(['L1','L2','L3','L4','L5','L6','L7','L8','L9']):
  lm=next(x for x in source['landmarks'] if x['id']==lid and x['side'] in [-1,0]);q=lm['candidate_skin_region_centroid'];label_y=170+k*75
  if q:
   x,y=project(q,view);x=20+x*820/1100;y=100+y*820/1100;s.append(f'<path d="M{x},{y}L850,{label_y-8}" stroke="#e7bd72" stroke-width="1.5" opacity=".6"/><circle cx="{x}" cy="{y}" r="7" fill="#e7bd72"/><text x="{x+8}" y="{y-10}" font-size="20">{lid}</text>')
  s.append(f'<text x="875" y="{label_y}" font-size="25">{lid}｜{lm["region"]}</text><text x="875" y="{label_y+28}" font-size="20" fill="#b5c5cf">{lm["vertex_samples"]}個外皮點；{lm["confidence"]}；{"鼻孔身份未確認" if lid=="L9" else "区域对应候选"}</text>')
 s.append('<text x="25" y="990" font-size="23">位置是指定區域的實際外皮點平均，不代表解剖骨點；左右完整資料見landmarks.csv。</text></g></svg>');(p/(view+'_landmarks.svg')).write_text(''.join(s))
(p/'design_geometry.json').write_text(json.dumps({'role':'shared_design_sections_not_mesh','stations_y_halfwidth_top_bottom':stations,'orbital_support_panels':orbital,'exact_source_boundary_edges':len(legacy_edges),'source':'01M3','camera_source':str((src/'capture_settings_01M3.json').relative_to(r)),'models_edited':False,'teeth_clearance_or_new_weights_validated':False},indent=2))
print('Whole head designs and region audit vectors saved')
