from pathlib import Path
import json,base64,html
p=Path(__file__).resolve().parent;r=Path.cwd();d=json.loads((p/'audit_geometry.json').read_text());g=json.loads((p/'design_geometry.json').read_text());stations=g['stations_y_halfwidth_top_bottom'];src=d['01M3'];skinids={i for f,mi in zip(src['faces'],src['material_indices']) if src['material_names'][mi] in ['d_olive','d_moss','d_tan'] for i in f if i>=10444}
s=['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1050"><rect width="1600" height="1050" fill="#18232d"/><g font-family="Hiragino Sans GB,sans-serif" fill="#eef3f7"><text x="25" y="45" font-size="32">主截面設計｜同一頭殼沿前後方向改變寬厚節奏</text><text x="25" y="90" font-size="23">灰點：M3指定Y平面附近的實際外皮點（±0.08）　彩線：設計截面，非修改後模型。</text>']
records=[]
for k,idx in enumerate([0,2,3,4,6]):
 y,w,t,b=stations[idx];ox=70+(k%3)*510;oy=180+(k//3)*365;scale=330;proj=lambda x,z:(ox+210+x*scale,oy+245-(z-2.05)*scale)
 for i in skinids:
  q=src['coords'][i]
  if abs(q[1]-y)<.08:
   x,z=proj(q[0],q[2]);s.append(f'<circle cx="{x}" cy="{z}" r="4" fill="#a6b7c6"/>')
 pts=[(0,t),(w*.47,t-.06*(t-b)),(w*.85,t-.23*(t-b)),(w,b+(t-b)*.47),(w*.87,b),(-w*.87,b),(-w,b+(t-b)*.47),(-w*.85,t-.23*(t-b)),(-w*.47,t-.06*(t-b))];ps=' '.join(f'{x},{z}' for x,z in [proj(x,z) for x,z in pts]);s.append(f'<polygon points="{ps}" fill="#75d49b" fill-opacity=".12" stroke="#75d49b" stroke-width="4"/><text x="{ox}" y="{oy}" font-size="25">{["後顱","眶區","眼前／鼻背","前吻","吻端"][k]}｜Y={y:.2f}</text>');records.append({'region':['posterior','orbit','preorbital','anterior','muzzle'][k],'y':y,'design_halfwidth':w,'design_top':t,'design_lower_envelope':b,'source_samples':sum(abs(src['coords'][i][1]-y)<.08 for i in skinids)})
s.append('<text x="25" y="970" font-size="24">中央鼻背有寬度，斜面向厚上顎轉入；端面短弧，不用單點扇形封口。</text><text x="25" y="1015" font-size="22">截面下緣是外殼方向；真正固定口緣須依原邊界逐點銜接，尚未驗證間隙。</text></g></svg>');(p/'cross_sections.svg').write_text(''.join(s));(p/'section_parameters.json').write_text(json.dumps(records,indent=2))
old=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-face-schematic-B-v001/eye_section.svg';s=old.read_text().replace('B｜眼窩／眉遮剖面與共同注視方向','01M.6｜眶支架・眼球・眼瞼三層關係').replace('眼球仍位於頭側；眼眶朝前外方開放，圓虹膜提供焦點，眉遮塑造壓迫感。','藍：眶部支架　灰：球面眼　金：可見虹膜。外眼開口不是骨性眼眶的複製。');(p/'orbital_section.svg').write_text(s)
rows=[]
for e in d['01M5B']['eyes']:
 tests=e['tests'];rows.append(f'<tr><td>{"左" if e["side"]==-1 else "右"}</td><td>{e["sphere_radius_fitted"]:.4f}</td><td>{tests["near"]["axis_target_angle_degrees"]:.2f}°</td><td>{tests["far"]["axis_target_angle_degrees"]:.2f}°</td><td>{tests["front"]["point_visibility"]}/{tests["front"]["tested_face_centroids"]}</td><td>{tests["left_threequarter"]["point_visibility"]}/{tests["left_threequarter"]["tested_face_centroids"]}</td><td>{tests["right_threequarter"]["point_visibility"]}/{tests["right_threequarter"]["tested_face_centroids"]}</td></tr>')
ref=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v004/references/user_annotated_concept_comparison.png';b64=base64.b64encode(ref.read_bytes()).decode()
page='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01M.6完整頭型設計包</title><style>body{max-width:1600px;margin:28px auto;background:#18232d;color:#eef3f7;font:21px sans-serif}p{line-height:1.6}img{width:100%;margin:15px 0}a{color:#9ddaff}table{border-collapse:collapse;width:100%;margin:24px 0}td,th{padding:15px;border:1px solid #516578;text-align:left}summary{cursor:pointer;padding:15px;background:#253543}</style><h1>01M.6｜整頭外殼重設計包</h1><p>唯讀定位＋完整設計，未修改模型。M3為回退基準；M5B鼻吻／圓眼與前向視軸留作可取嘗試，眼眶放射長面不承接。<a href="REVIEW.md">點評與Blockout範圍</a> · <a href="audit_results.json">實測紀錄</a> · <a href="landmarks.csv">定位表</a> · <a href="INDEPENDENT_REVIEW.md">獨立審查</a></p><p>核心：鼻背與上顎先建立整頭截面，前眶／上眉／眶後／頰面構成眼窩，最後安排小圓眼與可見眼瞼。Concept未校準，示意不是新模型成果。</p>'''
for n in ['head_threequarter_design','head_side_design','head_top_design','head_front_design','cross_sections','orbital_section']:page+=f'<img src="{n}.png">'
page+='<h2>M5B中立姿態視線診斷</h2><p>目前眼球已朝前，遠方目標軸向誤差小，但部分虹膜面心仍被外殼擋住。比率是每眼32個虹膜三角面心的射線可見數，不是瞳孔面積、視野角度或表情分數；遠側眼在3/4被頭殼遮蔽屬預期。眼面本身未作遮擋，未驗新設計。</p><table><tr><th>側</th><th>擬合半徑</th><th>近目標偏角</th><th>遠目標偏角</th><th>正面</th><th>左3/4</th><th>右3/4</th></tr>'+''.join(rows)+'</table><p>近目標Y=5.11、遠目標Y=9.16，左右共用Z=2.435；模型當前前向為+Y。兩種方向測試沒有旋轉或回存眼球。</p>'
page+='<details><summary>L1–L9區域定位（I/D，非骨點）</summary>'
for n in ['head_side','head_top','head_front','head_threequarter']:page+=f'<img src="{n}_landmarks.png">'
page+='</details><details><summary>使用者Concept標註原圖</summary><img src="data:image/png;base64,'+b64+'"></details><p>等待完整頭型設計確認後才建立01M.6獨立Blockout。Rig／下顎／原口腔／齒列／身體／足部不改，固定邊界相容性仍須模型驗證。</p></html>';(p/'index.html').write_text(page);print('Sections and inspection report page created')
