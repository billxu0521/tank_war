from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v008';old=p.parent/'2026-10-09-pass-v007/refined-v003/captures';f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26)
for view in ['head_side','head_front','head_top','head_threequarter','head_right_threequarter','full_body_side','head_side_color','head_front_color','head_threequarter_color']:
 c=Image.new('RGB',(1700,950),(24,35,45));d=ImageDraw.Draw(c);d.text((20,8),view+'｜同相機／光照，無像素化',font=f,fill='white')
 for x,label,path in [(0,'M7｜目前基準',old/f'{view}_01M7.png'),(850,'M8｜頭部識別補回試作',p/f'captures/{view}_01M8.png')]:d.text((x+20,54),label,font=f,fill='white');c.paste(ImageOps.contain(Image.open(path).convert('RGB'),(850,850)),(x,100))
 c.save(p/f'{view}_comparison.png')
ref=r/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/references/user_reference_5.png';c=Image.new('RGB',(1700,1560),(24,35,45));d=ImageDraw.Draw(c);d.text((20,10),'Concept識別目標｜視角未校準，僅比較設計方向',font=f,fill='white');im=Image.open(ref).crop((880,590,1536,842));c.paste(ImageOps.contain(im,(1700,540)),(0,60));c.paste(Image.open(p/'head_threequarter_color_comparison.png'),(0,610));c.save(p/'concept_comparison.png')
