from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=Path(__file__).resolve().parent;f=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25)
for pose in ['original','bite026','sweep003']:
 for view in ['side','threequarter']:
  im=Image.new('RGB',(1700,780),(24,35,45));d=ImageDraw.Draw(im);d.text((20,8),f'{pose} / {view}｜實際保存檔比較，所有評估頂點位置相同',font=f,fill='white')
  for x,version,label in [(0,'v003','v003｜已接受造型'),(850,'v004','v004｜僅12面繞序修復')]:d.text((x+20,53),label,font=f,fill='white');im.paste(ImageOps.contain(Image.open(p/f'captures/{version}/{pose}_{view}.png').convert('RGB'),(850,660)),(x,100))
  im.save(p/f'{pose}_{view}_comparison.png')
