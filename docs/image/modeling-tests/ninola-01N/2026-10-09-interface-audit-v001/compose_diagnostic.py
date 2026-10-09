from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageOps
import json,math
r=Path.cwd();p=Path(__file__).resolve().parent;prior=p.parent/'2026-10-09-pass-v001';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',26);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',22)
for label in ['original','bite026','sweep003']:
 c=Image.new('RGB',(1700,780),(24,35,45));d=ImageDraw.Draw(c);d.text((20,8),label+'｜座標完全相同，只比較面繞序（非新工作模型）',font=font,fill='white')
 for x,name,title in [(0,'current','01N.1 v003 已接受造型'),(850,'winding_only_hypothesis','僅12面繞序修正假設')]:d.text((x+20,53),title,font=font,fill='white');im=ImageOps.contain(Image.open(p/f'{label}_{name}.png').convert('RGB'),(850,660));c.paste(im,(x,100))
 c.save(p/f'{label}_comparison.png')
a=json.loads((p/'interface_analysis.json').read_text());geometry=json.loads((prior/'refined-v003/inspection_geometry.json').read_text());settings=json.loads((prior/'refined-v003/captures/capture_settings_01N1.json').read_text())['head_side_color'];m=settings['matrix']
def project(pt):
 q=[pt[i]-m[i][3] for i in range(3)];v=[sum(m[j][i]*q[j] for j in range(3)) for i in range(3)];return (550+v[0]*1100/settings['scale'],550-v[1]*1100/settings['scale'])
base=Image.open(prior/'refined-v003/captures/head_side_color_01N1.png').convert('RGB');c=Image.new('RGB',(1700,950),(24,35,45));d=ImageDraw.Draw(c);d.text((20,8),'下顎接口定位｜不是Rig變更或牙列解鎖提案',font=font,fill='white')
for x,mode,title in [(0,'boundary','粉色：固定口腔交界／綠色：短collar'),(850,'winding','紅色：新外皮內面繞序不一致邊')]:
 im=base.copy();di=ImageDraw.Draw(im)
 if mode=='boundary':
  pts=a['boundary_points'];fixed=[project(v['world']) for v in pts];collar=[project(v['collar_point']) for v in pts];di.line(fixed+[fixed[0]],fill=(240,125,169),width=4);di.line(collar+[collar[0]],fill=(111,220,200),width=4)
  for v in sorted(pts,key=lambda v:-v['deviation_from_neighbour_chord'])[:6]:px,py=project(v['world']);di.ellipse((px-5,py-5,px+5,py+5),fill=(246,198,111));di.text((px+6,py-22),str(v['order']),font=small,fill='white')
 else:
  for e in a['new_patch_inconsistent_winding_edges']:di.line([project(geometry['vertices'][i]) for i in e['vertices']],fill=(255,93,93),width=5)
 crop=im.crop((200,655,780,930));c.paste(ImageOps.contain(crop,(820,680)),(x+15,140));d.text((x+20,66),title,font=small,fill='white')
d.text((20,830),'固定邊界點都在；尖折與面繞序是兩項問題，不能只用翻面解決量體。',font=font,fill='white');d.text((20,883),'新外皮27條開放邊是接口邊界，不等於缺面；本圖只是候選定位。',font=small,fill='white');c.save(p/'interface_location.png')
