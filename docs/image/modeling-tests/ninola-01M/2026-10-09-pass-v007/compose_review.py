from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
p=Path(__file__).resolve().parent; font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',27)
b=p.parent/'2026-10-09-pass-v006/refined-v004/captures';n=p/'refined-v003/captures';old=p.parent/'2026-10-09-pass-v005B/refined-v007/captures'
def pair(a,b,title,dest,labels=('M6 v004｜討論錨點','M7 v003｜結構粗模，待審'),size=(850,850)):
 canvas=Image.new('RGB',(size[0]*2,size[1]+100),(24,35,45));d=ImageDraw.Draw(canvas);d.text((20,7),title,font=font,fill='white')
 for x,label,path in [(0,labels[0],a),(size[0],labels[1],b)]:
  d.text((x+20,52),label,font=font,fill='white');canvas.paste(ImageOps.contain(Image.open(path).convert('RGB'),size),(x,100))
 if dest:canvas.save(dest)
 return canvas
for view in ['head_side','head_front','head_threequarter','head_right_threequarter','head_top','full_body_side','head_side_color','head_front_color','head_threequarter_color']:
 pair(b/f'{view}_01M6.png',n/f'{view}_01M7.png',f'同相機、光照與比例｜{view}',p/f'{view}_comparison.png')
ref=Path.cwd()/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/references/user_reference_5.png';im=Image.open(ref).crop((880,590,1536,842));canvas=Image.new('RGB',(1700,1700),(24,35,45));d=ImageDraw.Draw(canvas);d.text((20,8),'Concept目標｜視角未校準，只比較曲線與量體方向',font=font,fill='white');canvas.paste(ImageOps.contain(im,(1700,653)),(0,60));canvas.paste(Image.open(p/'head_threequarter_color_comparison.png'),(0,730));canvas.save(p/'concept_comparison.png')
# Identical procedural poses, independently recaptured for M6.
dyn=p/'dynamic';prior=p.parent/'2026-10-09-pass-v006/dynamic'
for kind,count,folder in [('bite',72,'captures'),('roar',48,'captures-reframed')]:
 frames=[]
 for i in range(0,count,2):
  frames.append(pair(prior/f'{folder}/M6/{kind}/{i:03d}_side.png',dyn/f'{folder}/M7/{kind}/{i:03d}_side.png',f'{kind}｜相同實測程序姿態｜{i/24:.2f}s',None,('M6｜討論錨點','M7｜結構粗模'),(720,560)).quantize(colors=96))
 frames[0].save(p/f'{kind}_comparison.gif',save_all=True,append_images=frames[1:],duration=[80 if k%3!=2 else 90 for k in range(len(frames))],loop=0,disposal=2)
for kind,frame,folder in [('bite',26,'captures'),('roar',28,'captures-reframed')]:
 pair(prior/f'{folder}/M6/{kind}/{frame:03d}_threequarter.png',dyn/f'{folder}/M7/{kind}/{frame:03d}_threequarter.png',f'{kind} 關鍵張口姿態',p/f'{kind}_key_comparison.png',('M6｜討論錨點','M7｜結構粗模'),(850,661))
# Honest eye/nose close-up from one common camera, no different crop or aspect distortion.
for region,box in [('eye',(425,450,675,650)),('nose',(150,510,400,780))]:
 canv=Image.new('RGB',(1700,945),(24,35,45));draw=ImageDraw.Draw(canv);draw.text((20,5),f'{region}｜同3/4相機、同裁切區域',font=font,fill='white')
 for x,label,path in [(0,'M6｜討論錨點',b/'head_threequarter_color_01M6.png'),(850,'M7｜結構粗模',n/'head_threequarter_color_01M7.png')]:
  draw.text((x+20,48),label,font=font,fill='white');patch=ImageOps.contain(Image.open(path).crop(box),(850,850));canv.paste(patch,(x,95))
 canv.save(p/f'{region}_closeup.png')
html='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 01M.7</title><style>body{max-width:1700px;margin:28px auto;background:#18232d;color:#eef3f7;font:21px sans-serif}p{line-height:1.6}img{width:100%;margin:18px 0}a{color:#9ddaff}</style><h1>01M.7 v003｜眉罩、頰部與吻部結構粗模</h1><p>待審粗模。M6 v004保留討論錨點；M3另留已接受回退，01J仍Production。灰模與色彩先看鼻背／斜吻／頰面是否連成主量體；眼眶承托與Concept威懾尚需判斷。尚未重新加頭刺，畫面中的背頸刺為來源保留。</p><p><a href="RESULT.md">點評與驗證／下一步</a> · <a href="INDEPENDENT_REVIEW.md">獨立審查</a>。Rig、原口腔／齒列、下顎與身體／足部保持。動態是隔離程序呼叫測試，非正式遊戲整合／真輸入驗收。</p>'''
for name in ['concept_comparison.png','head_threequarter_comparison.png','head_side_comparison.png','head_side_color_comparison.png','head_front_comparison.png','head_front_color_comparison.png','head_right_threequarter_comparison.png','head_top_comparison.png','eye_closeup.png','nose_closeup.png','full_body_side_comparison.png','bite_comparison.gif','bite_key_comparison.png','roar_comparison.gif','roar_key_comparison.png','dynamic/extra-roar/M7/roar/028_front.png']:
 if (p/name).exists():html+=f'<img loading="lazy" src="{name}">'
html+='</html>';(p/'index.html').write_text(html)
