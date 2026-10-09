from pathlib import Path
import json,html
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
views=[('head_side','頭顎側面灰模'),('head_threequarter','頭顎3/4灰模'),('head_front','頭顎正面'),('head_top','頭顎頂視'),('head_body_context','頭身廣視角'),('full_side','全身側視'),('full_left_oblique','全身3/4'),('head_threequarter_color','原頭顎配色與頭刺統一')]
def compare(A,B,dest,title,extra=False):
 c=Image.new('RGB',(1600,940),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01R.1 v004｜'+title+'｜實際模型',font=font,fill='white');d.text((25,65),'Q1 v002｜核可來源',font=font,fill='white');d.text((825,65),'R1 v004｜頭顎幾何試作，待審',font=font,fill='white');c.paste(A.resize((760,760)),(20,110));c.paste(B.resize((760,760)),(820,110));d.text((25,890),'頭顎局部大面整理｜原皮配色保持｜頭刺按面方向共用背尾褐色明暗',font=small,fill='white');c.save(dest)
for name,title in views:compare(Image.open(s/'captures'/f'{name}.png'),Image.open(p/'captures'/f'{name}.png'),p/f'{name}_comparison.png',title)
for name,title in [('jaw_open20','jaw局部20°'),('jaw_open35','jaw局部35°'),('head_turn10','head局部10°')]:compare(Image.open(p/'pose-captures'/f'{name}_source.png'),Image.open(p/'pose-captures'/f'{name}_R1.png'),p/f'{name}_comparison.png',title)
items=''.join(f'<section><h2>{html.escape(title)}</h2><img src="{name}_comparison.png"></section>' for name,title in views);poses=''.join(f'<img src="{name}_comparison.png">' for name in ['jaw_open20','jaw_open35','head_turn10']);
(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01R.1 頭顎幾何化</title><style>body{background:#18232d;color:#edf0f2;font:18px sans-serif;max-width:1500px;margin:30px auto;padding:20px}img{max-width:100%;height:auto}p{line-height:1.7}section{margin:35px 0}a{color:#79dfd2}</style><h1>01R.1 v004 頭顎幾何化＋頭刺配色統一｜待審</h1><p>原頭顎配色保持；局部面片整理、重新三角化與吻側／頰部／顎身轉面，7004→6988tri（-16）；另調整25個內部表面頂點，不是隨機改色。來源未改。<a href="REPORT.md">點評、棘刺色差原因與檢查</a>。</p>'+items+'<h2>重塑前M1幾何風格參照（不回復舊頭型）</h2><img src="historical-head/head_threequarter.png"><h2>三個有限人造姿態</h2>'+poses+'</html>')
print('R1 model comparisons complete')
