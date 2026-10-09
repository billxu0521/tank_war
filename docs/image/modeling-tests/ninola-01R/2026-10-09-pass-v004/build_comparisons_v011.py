from pathlib import Path
import json,html
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent;s=p;font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
views=[('head_side','頭顎側面灰模'),('head_threequarter','頭顎3/4灰模'),('head_front','頭顎正面'),('head_top','頭顎頂視'),('head_body_context','頭身廣視角'),('full_side','全身側視'),('full_left_oblique','全身3/4'),('head_threequarter_color','原頭顎配色與頭刺統一')]
def compare(A,B,dest,title,extra=False):
 c=Image.new('RGB',(1600,940),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01R.1 v011｜'+title+'｜實際模型',font=font,fill='white');d.text((25,65),'v010｜鼻端／眼眶已接受',font=font,fill='white');d.text((825,65),'R1 v011｜頭顎幾何試作，待審',font=font,fill='white');c.paste(A.resize((760,760)),(20,110));c.paste(B.resize((760,760)),(820,110));d.text((25,890),'交界六點重新接合｜保留粗面折角｜鼻眼棘刺不變｜原皮配色保持｜頭刺按面方向共用背尾褐色明暗',font=small,fill='white');c.save(dest)
for name,title in views:compare(Image.open(s/'baseline-captures'/f'{name}.png'),Image.open(p/'captures'/f'{name}.png'),p/f'{name}_comparison.png',title)
for name,title in [('jaw_open20','jaw局部20°'),('jaw_open35','jaw局部35°'),('head_turn10','head局部10°')]:compare(Image.open(p/'pose-captures'/f'{name}_source.png'),Image.open(p/'pose-captures'/f'{name}_R1.png'),p/f'{name}_comparison.png',title)
