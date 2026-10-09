from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path.cwd()/'docs/image/modeling-tests/ninola-01O/2026-10-09-belly-v001';old=p.parent/'2026-10-09-review-v001';f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25)
for folder,views in [('captures',['torso_side','torso_threequarter','torso_right_threequarter','torso_rear_threequarter','full_body_side','full_body_front']),('gray-captures',['torso_side','torso_top','torso_rear_threequarter'])]:
 for v in views:
  a=Image.open(old/folder/f'{v}_01N1.png').convert('RGB');b=Image.open(p/(folder+'-v003')/f'{v}_01O2.png').convert('RGB');c=Image.new('RGB',(1600,900),(24,35,45));d=ImageDraw.Draw(c);d.text((25,10),f'01O.2 v003｜{v}｜'+('灰模' if folder=='gray-captures' else '同鏡頭比較'),font=f,fill='white');d.text((25,58),'N1 v004 核可來源',font=f,fill='white');d.text((825,58),'O2 v003 獨立粗模｜待審',font=f,fill='white');c.paste(a.resize((760,760)),(20,100));c.paste(b.resize((760,760)),(820,100));c.save(p/f'{v}_v003_{"gray_" if folder=="gray-captures" else ""}comparison.png')
