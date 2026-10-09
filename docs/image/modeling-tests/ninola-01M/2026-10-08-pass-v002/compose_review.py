from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent;old=p.parent/'2026-10-08-dynamic-v001';m1=p.parent/'2026-10-08-pass-v001/refined-v002/captures';m2=p/'refined-v002/captures';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',28)
def pair(a,b,title,dest,size=(850,850)):
 im=Image.new('RGB',(size[0]*2, size[1]+95),(24,35,45));d=ImageDraw.Draw(im);d.text((20,5),title,font=font,fill='white');d.text((20,48),'M1｜前版',font=font,fill='white');d.text((size[0]+20,48),'M2｜本輪試作',font=font,fill='white')
 for x,path in [(0,a),(size[0],b)]:im.paste(Image.open(path).convert('RGB').resize(size,Image.Resampling.LANCZOS),(x,95))
 im.save(dest);return im
for view in ['head_side','head_front','head_threequarter','head_top','head_bottom','head_rear_threequarter','full_body_side']:
 pair(m1/f'{view}_01M1.png',m2/f'{view}_01M2.png',f'01M.2 頭顱／顎支量體與眼眶｜{view}',p/f'{view}_comparison.png')
for kind,count,oldfolder,newfolder in [('bite',72,old/'captures/M1/bite',p/'dynamic/captures/M2/bite'),('roar',48,old/'captures-reframed/M1/roar',p/'dynamic/captures-reframed/M2/roar')]:
 frames=[]
 for k in range(0,count,2):
  im=pair(oldfolder/f'{k:03d}_side.png',newfolder/f'{k:03d}_side.png',f'{kind}｜相同程序姿態｜{k/24:.2f}s',p/'temporary_frame.png',size=(720,560));frames.append(im.quantize(colors=96))
 durations=[80 if k%3!=2 else 90 for k in range(len(frames))]
 frames[0].save(p/f'{kind}_comparison.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=True)
(p/'temporary_frame.png').unlink()
pair(old/'captures/M1/bite/026_threequarter.png',p/'dynamic/captures/M2/bite/026_threequarter.png','咬擊張口關鍵姿態｜第26幀',p/'bite_key_comparison.png',size=(850,661))
pair(old/'captures-reframed/M1/roar/028_threequarter.png',p/'dynamic/captures-reframed/M2/roar/028_threequarter.png','吼叫抬頭關鍵姿態｜第28幀',p/'roar_key_comparison.png',size=(850,661))
ref=p.parents[4]/'ninola-01K8/2026-10-08-v001/references/user_reference_5.png'
# Resolve reference from repository rather than relying on ambiguous parent depth.
ref=Path.cwd()/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/references/user_reference_5.png'
img=Image.open(ref).crop((880,590,1536,842));canvas=Image.new('RGB',(1700,1510),(24,35,45));d=ImageDraw.Draw(canvas);d.text((20,8),'Concept頭部目標｜未校準視角，僅比較識別與量體方向',font=font,fill='white');canvas.paste(img.resize((1700,653)),(0,60));pairimg=Image.open(p/'head_threequarter_comparison.png').resize((1700,797));canvas.paste(pairimg,(0,713));canvas.save(p/'concept_comparison.png')
html='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 01M.2比較</title><style>body{max-width:1700px;margin:28px auto;background:#18232d;color:#edf3f7;font:20px sans-serif}img{width:100%;margin-bottom:25px}p{line-height:1.6}a{color:#9ddaff}</style><h1>01M.2｜整體頭部試作 v002</h1><p>左M1，右M2。增加顱頂／後顱／顎支承力量體，保留下顎收束；重建較平貼的眼裂與凹入眼眶。<a href="RESULT.md">結果與點評</a> · <a href="INDEPENDENT_REVIEW.md">獨立審查</a></p><p>待使用者審核，非Production完成。原有口緣交疊未修復，牙齒／舌／Rig保持。</p>'''
for n in ['head_threequarter_comparison.png','concept_comparison.png','head_side_comparison.png','head_front_comparison.png','full_body_side_comparison.png','bite_comparison.gif','bite_key_comparison.png','roar_comparison.gif','roar_key_comparison.png','head_top_comparison.png','head_bottom_comparison.png','head_rear_threequarter_comparison.png']:html+=f'<img src="{n}">'
html+='</html>';(p/'index.html').write_text(html,encoding='utf-8');print('Comparison page and GIFs saved.')
