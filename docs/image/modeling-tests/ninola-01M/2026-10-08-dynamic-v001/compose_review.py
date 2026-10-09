from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
p=Path(__file__).resolve().parent
font='/System/Library/Fonts/Hiragino Sans GB.ttc';f=ImageFont.truetype(font,24);small=ImageFont.truetype(font,18)
def pair(paths,title,subtitle=''):
 canvas=Image.new('RGB',(1800,780),'#18232d');d=ImageDraw.Draw(canvas);d.text((22,10),title,font=f,fill='white');d.text((22,47),'L3 原頭顎',font=small,fill='white');d.text((925,47),'M1 下顎試作',font=small,fill='white')
 for x,path in zip([0,900],paths):canvas.paste(Image.open(path).convert('RGB'),(x,76))
 if subtitle:d.text((22,750),subtitle,font=small,fill='white')
 return canvas
for kind,folder,range_ in [('bite','captures',range(0,72,2)),('roar','captures-reframed',range(0,48,2))]:
 frames=[]
 for i in range_:
  title=('既有咬擊程序' if kind=='bite' else '既有吼叫程序・廣取景')+f'｜t={i/24:.2f}s'
  frames.append(pair([p/folder/tag/kind/f'{i:03d}_side.png' for tag in ['L3','M1']],title,'隔離新原型／相同45骨程序姿態；來源模型不修改。此為姿態比較，非正式遊戲驗收。').resize((1440,624)).quantize(colors=128))
 frames[0].save(p/f'{kind}_comparison.gif',save_all=True,append_images=frames[1:],duration=[80 if i%3 else 90 for i in range(len(frames))],loop=0,disposal=2)
for kind,i,folder in [('bite',26,'captures'),('roar',28,'captures-reframed')]:
 pair([p/folder/tag/kind/f'{i:03d}_threequarter.png' for tag in ['L3','M1']],f'{kind} 關鍵姿態：完整頭顎比較').save(p/f'{kind}_key_comparison.png')
pair([p/f'contact_diagnostic_{tag}.png' for tag in ['L3','M1']],'零 jaw 旋轉壓力測試：粉紅標示相交軟表面','兩版皆21組軟面相交、5組牙面相交；不是已確認的解剖閉口。').save(p/'contact_comparison.png')
pair([p/'captures'/tag/'bite/026_body.png' for tag in ['L3','M1']],'咬擊：全身比較').save(p/'body_bite_comparison.png')
page='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 動態比較</title><style>body{max-width:1600px;margin:30px auto;background:#18232d;color:#edf3f7;font:19px sans-serif}img{width:100%}a{color:#9ddaff}p{line-height:1.6}</style><h1>Ninola：先動態驗證，再整體重塑頭部</h1><p>使用實際45-bone Rig、未改動的trex.gd程序動畫，L3／M1隔離測試資產。左L3、右M1。<a href="REPORT.md">分析與驗證</a> · <a href="NEXT_PROPOSAL.md">01M.2方案</a></p>'''
for v in ['bite_comparison.gif','bite_key_comparison.png','body_bite_comparison.png','roar_comparison.gif','roar_key_comparison.png','contact_comparison.png']:page+=f'<img src="{v}">'
page+='<p>程序控制直接調用，非真玩家輸入／傷害碰撞實玩。零jaw旋轉是診斷姿態，不代表咬合正確。M1局部改善支持繼續設計，頭部識別仍未完成。</p><h2>獨立審查</h2><p><a href="INDEPENDENT_REVIEW.md">審查結論</a></p><h2>下一輪整體重塑方向</h2><img src="head_identity_scope.png"></html>'
(p/'index.html').write_text(page)
