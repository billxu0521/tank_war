from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import shutil,json,hashlib
r=Path.cwd();p=Path(__file__).resolve().parent;f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20);ref=r/'docs/image/modeling-tests/ninola-migration/2026-10-08-v001/references/references/extracted-views';(p/'references').mkdir(exist_ok=True)
for name in ['concept_side.png','concept_front.png','concept_rear.png']:shutil.copyfile(ref/name,p/'references'/name)
a=Image.new('RGB',(1200,1450),'#18212a');d=ImageDraw.Draw(a);d.text((25,15),'01S｜全身一致性：Concept 與核可 R2 v005',font=f,fill='white');d.text((25,55),'視角／姿勢未校準；辨識與量體方向比較，不作精確比例疊圖。',font=small,fill='#d2dce6')
for row,(view,concept,title) in enumerate([('full_other_side','concept_side','側面'),('full_front','concept_front','正面'),('full_rear','concept_rear','背面')]):
 y=110+row*435;d.text((25,y),title,font=f,fill='white')
 for col,path in enumerate([p/'references'/f'{concept}.png',p/'captures'/f'{view}.png']):
  im=Image.open(path).convert('RGB');im.thumbnail((560,370));x=25+col*590+(560-im.width)//2;a.paste(im,(x,y+50+(370-im.height)//2))
a.save(p/'concept_comparison.png')
for mode in ['walk','run','turn']:
 frames=[]
 for path in sorted((p/'motion').glob(mode+'_*_body.png')):
  im=Image.open(path).convert('RGB');d=ImageDraw.Draw(im);d.line((0,511,1000,511),fill='#e77570',width=2);d.text((15,15),mode+'｜隔離Godot姿態回放／紅線 z=0',font=small,fill='white');frames.append(im)
 frames[0].save(p/f'{mode}.gif',save_all=True,append_images=frames[1:],duration=333 if mode!='turn' else 500,loop=0)
for mode in ['bite','roar']:
 frames=[Image.open(q).convert('RGB') for q in sorted((p/'motion').glob(mode+'_*_head.png'))];frames[0].save(p/f'{mode}.gif',save_all=True,append_images=frames[1:],duration=400,loop=0)
print('concept comparison and five native replay GIFs ready')
