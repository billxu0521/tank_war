from pathlib import Path
import json,html
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',21)
views=[('left_hand_front_unmasked','正面手端'),('left_hand_unmasked','左手3/4'),('right_hand_unmasked','右手3/4'),('left_palm','左掌側灰模'),('right_palm','右掌側'),('left_outer','外側'),('left_top','上視'),('arm_context','手臂與胸腹廣視角'),('full_body_side','全身側視灰模'),('full_body_front','全身正面')]
for name,label in views:
 c=Image.new('RGB',(1600,940),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01P.1 v002｜'+label+'｜實際模型比較',font=font,fill='white');d.text((25,65),'O2 v003｜核可來源',font=font,fill='white');d.text((825,65),'P1 v002｜獨立試作，待審',font=font,fill='white');c.paste(Image.open(s/'captures'/f'{name}.png').resize((760,760)),(20,110));c.paste(Image.open(p/'captures'/f'{name}.png').resize((760,760)),(820,110));d.text((25,890),'只換掌指外皮｜腕端、原爪、前臂、身體與Rig保持｜新指體面尚有稜角，未精修',font=small,fill=(216,229,239));c.save(p/f'{name}_comparison.png')
items=''.join(f'<section><h2>{html.escape(label)}</h2><img src="{name}_comparison.png"></section>' for name,label in views)
poses=''.join(f'<img src="captures/{n}.png" style="width:32%">' for n in ['hand_plus15','hand_minus15','finger1_plus15'])
(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01P.1 掌指外皮試作</title><style>body{background:#18232d;color:#e9edf0;font:18px sans-serif;max-width:1500px;margin:30px auto;padding:20px}img{max-width:100%;height:auto}section{margin:35px 0}p{line-height:1.7}a{color:#77dfd2}</style><h1>01P.1 v002 掌指外皮試作｜待審</h1><p>左：核可 O2；右：獨立試作。雙指在掌端較早分開，指體承接固定爪根；原爪與Rig未改。</p><p>點評：分指與爪根量體較可讀，但折面仍偏機械；此輪先判結構方向，不繼續指節精雕。<a href="REPORT.md">檢查、限制與下一步</a></p>'+items+'<h2>有限姿態回放</h2><p>手掌±15°、第一指+15°，為隔離人造測試姿態，不等於遊戲抓握或完整動畫驗收。</p>'+poses+'<h2>桌面Blender額外繞視</h2><img src="mcp_left_oblique.png"><img src="mcp_right_oblique.png"></html>')
print('10 before/after comparison images and HTML complete')
