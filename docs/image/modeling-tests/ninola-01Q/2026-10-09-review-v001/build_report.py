from pathlib import Path
import json,html,hashlib
from PIL import Image,ImageDraw,ImageFont
r=Path.cwd();p=Path(__file__).resolve().parent;ref=r/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/references';out=p/'references';out.mkdir(exist_ok=True);font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',24);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
references=[]
for src,box,name in [('user_reference_5.png',(300,0,1050,390),'concept_side'),('user_reference_5.png',(0,365,760,555),'concept_top'),('user_reference_3.png',(0,0,840,350),'design_skeleton_mass'),('user_reference_5.png',(0,560,760,840),'design_muscle_mass')]:
 f=ref/src;im=Image.open(f);im.crop(box).save(out/f'{name}.png');references.append({'source':str(f),'source_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'crop_native_pixels':box,'result':str(out/f'{name}.png'),'role':'AI design intent, not anatomical proof'})
(p/'reference_provenance.json').write_text(json.dumps(references,ensure_ascii=False,indent=2));ins=json.loads((p/'inspection.json').read_text());cams=json.loads((p/'capture_settings.json').read_text())
def proj(pt,view):
 m=cams[view]['matrix'];q=[pt[j]-m[j][3] for j in range(3)];xy=[sum(m[j][i]*q[j] for j in range(3)) for i in [0,1]];fac=1100/cams[view]['scale'];return (550+xy[0]*fac,550-xy[1]*fac)
for view in ['hip_side','hip_rear','tail_top']:
 im=Image.open(p/'captures'/f'{view}.png').convert('RGB');d=ImageDraw.Draw(im)
 for n,b in ins['bones'].items():
  if view.startswith('hip') and not n.startswith(('thigh','shin','tail1')):continue
  if view=='tail_top' and not n.startswith('tail'):continue
  col=(250,123,174) if n.startswith('thigh') else (111,233,209);a=proj(b['head_world'],view);bb=proj(b['tail_world'],view);d.line([a,bb],fill=col,width=3);d.ellipse((a[0]-4,a[1]-4,a[0]+4,a[1]+4),fill=col);d.text((a[0]+5,a[1]-24),n,font=small,fill=col)
 im.save(p/f'{view}_bone_locator.png')
# Design comparison is deliberately not an aligned overlay or anatomical scale test.
c=Image.new('RGB',(1600,1020),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01Q｜Concept與核可現況｜姿勢／視角未配準，僅比較量體方向',font=font,fill='white');concept=Image.open(out/'concept_side.png');concept.thumbnail((740,650));c.paste(concept,(20,135));model=Image.open(p/'captures/hip_side.png').resize((760,760));c.paste(model,(820,110));d.text((25,75),'Concept：粗尾根、厚上腿、漸收尾巴',font=font,fill='white');d.text((825,75),'P1 v002：核可來源，唯讀',font=font,fill='white');d.text((25,905),'骨盆／上腿量感建議保留；不由不同姿勢或AI肌肉標籤直接推定必須改骨架。',font=small,fill='white');d.text((25,955),'尾中段的收窄—鼓起節奏列最小設計候選；Rig與核可頭顎／腹部／手足保持。',font=small,fill='white');c.save(p/'concept_mass_comparison.png')
views=[('hip_side','骨盆／完整後肢側視'),('hip_other_side','對側'),('hip_front','前視'),('hip_rear','後視'),('hip_top','骨盆頂視'),('hip_left_oblique','左後3/4'),('hip_right_oblique','右後3/4'),('hip_underside','腹側'),('tail_side','完整尾巴側視'),('tail_top','完整尾巴頂視'),('tail_oblique','尾巴3/4'),('tail_root_close','尾根近距離'),('full_body_side','全身側視'),('full_body_top','全身頂視')]
sections=''.join(f'<section><h2>{html.escape(title)}</h2><img src="captures/{name}.png"></section>' for name,title in views)
(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01Q 骨盆後肢尾巴審視</title><style>body{background:#18232d;color:#edf0f2;font:18px sans-serif;max-width:1300px;margin:30px auto;padding:20px}p{line-height:1.7}img{max-width:100%;height:auto}section{margin:35px 0}a{color:#79dfd2}</style><h1>01Q 骨盆／上後肢／尾根與尾巴｜唯讀審視</h1><p>01P.1 v002已核可。本輪完整隔離Prototype、未改模型與pose，14視角。<a href="REVIEW.md">點評與下一提案</a>。</p><p>初步方向：保留厚骨盆與上腿、粗尾根與尾長；優先比較尾中段反覆收窄的節奏，先提出示意，不立即改模。</p><img src="concept_mass_comparison.png"><h2>尾部Concept頂視與設計解剖圖</h2><img src="references/concept_top.png"><img src="references/design_skeleton_mass.png"><img src="references/design_muscle_mass.png"><h2>实际骨鏈定位（非動態驗收）</h2><img src="hip_side_bone_locator.png"><img src="tail_top_bone_locator.png">'+sections+'</html>')
print('01Q report/reference comparison generated')
