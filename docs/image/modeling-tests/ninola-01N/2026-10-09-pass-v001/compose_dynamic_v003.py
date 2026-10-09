from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01N/2026-10-09-pass-v001';dy=p/'refined-v003/dynamic';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',24)
for kind,frames in [('bite',[0,12,20,24,26,28,40,56,70]),('roar',[0,8,14,20,28,38,46])]:
 ims=[]
 for k in frames:
  c=Image.new('RGB',(1440,650),(24,35,45));d=ImageDraw.Draw(c);d.text((20,8),f'{kind}｜既有Godot姿態回放（非新實玩）｜frame {k}',font=font,fill='white')
  for x,tag,label in [(0,'M8','M8 核可基準'),(720,'N1','01N.1 v003 試作')]:d.text((x+20,50),label,font=font,fill='white');c.paste(ImageOps.contain(Image.open(dy/f'captures/{tag}/{kind}/{k:03d}_side.png').convert('RGB'),(720,560)),(x,90))
  ims.append(c)
 duration=[max(80,round((frames[i+1]-v)/24*1000)) if i<len(frames)-1 else 350 for i,v in enumerate(frames)]
 ims[0].save(p/f'{kind}_v003_comparison.gif',save_all=True,append_images=ims[1:],duration=duration,loop=0);ims[frames.index(26 if kind=='bite' else 28)].save(p/f'{kind}_v003_key.png')
metrics=json.loads((dy/'simulation_verification.json').read_text());deltas=[]
for a,b in zip(metrics['M8']['metrics'],metrics['N1']['metrics']):
 if a['jaw_head_soft_surface_triangle_overlaps']!=b['jaw_head_soft_surface_triangle_overlaps']:deltas.append({'sequence':a['sequence'],'frame':a['frame'],'M8':a['jaw_head_soft_surface_triangle_overlaps'],'N1':b['jaw_head_soft_surface_triangle_overlaps']})
(p/'dynamic_summary_v003.json').write_text(json.dumps({'recorded_pose_source':'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json','new_game_input_test':False,'new_GLb_export_test':False,'source_rig_pose_restored_and_files_unchanged':True,'overlap_count_changes':deltas,'M8_sweep':[x for x in metrics['M8']['metrics'] if x['sequence']=='sweep'],'N1_sweep':[x for x in metrics['N1']['metrics'] if x['sequence']=='sweep'],'note':'Triangle intersection flags only; original protected mouth overlaps remain, not full collision or tooth clearance acceptance.'},indent=2));print('dynamic overlap changes',deltas)
