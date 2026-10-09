from pathlib import Path
import json,html
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
h=p/'comparisons-v005'
views=[('head_side','頭顎側面灰模'),('head_threequarter','頭顎3/4灰模'),('head_front','頭顎正面'),('head_top','頭顎頂視'),('head_body_context','頭身廣視角'),('full_side','全身側視'),('full_left_oblique','全身3/4'),('head_threequarter_color','原頭顎配色與頭刺統一')]
def compare(A,B,dest,title,extra=False):
 c=Image.new('RGB',(1600,940),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01R.1 v005｜'+title+'｜實際模型',font=font,fill='white');d.text((25,65),'Q1 v002｜核可來源',font=font,fill='white');d.text((825,65),'R1 v005｜頭顎幾何試作，待審',font=font,fill='white');c.paste(A.resize((760,760)),(20,110));c.paste(B.resize((760,760)),(820,110));d.text((25,890),'吻側寬面＋上緣轉面＋後頰承托面｜原皮配色保持｜頭刺按面方向共用背尾褐色明暗',font=small,fill='white');c.save(dest)
for name,title in views:compare(Image.open(s/'captures'/f'{name}.png'),Image.open(p/'captures-v005'/f'{name}.png'),h/f'{name}_comparison.png',title)
