from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,shutil
p=Path(__file__).resolve().parent;r=Path.cwd();font='/System/Library/Fonts/Hiragino Sans GB.ttc';f=ImageFont.truetype(font,25);small=ImageFont.truetype(font,21)
canvas=Image.new('RGB',(1200,1390),'#18212a');d=ImageDraw.Draw(canvas);d.text((25,15),'01R.2｜金色虹膜・黑色豎瞳｜獨立試作／待審',font=f,fill='white')
for row,(name,title) in enumerate([('eye_forward','隔離眼球正面'),('installed_front','實裝近正面：保留原眼眶與視軸'),('head_front','頭部正面：保留原頭型')]):
 y=65+row*440;d.text((25,y),title,font=small,fill='#d7dfe7')
 for col,(label,text) in enumerate([('before','R1 v011｜原圓瞳'),('trial','R2 v001｜豎瞳試作')]):
  x=25+col*590;d.text((x,y+32),text,font=small,fill='white');im=Image.open(p/f'{label}_{name}.png').convert('RGB').resize((365,365));canvas.paste(im,(x+90,y+65))
canvas.save(p/'comparison.png')
ref=Path('/var/folders/_h/9bmjpwjx439bcmcf84gmp3gh0000gn/T/codex-clipboard-90e539fd-1332-48a5-b634-1c3ba6eea424.jpg');(p/'references').mkdir(exist_ok=True);shutil.copy2(ref,p/'references/user_gold_slit_eye.jpg')
rec=json.loads((p/'build_record.json').read_text());v=json.loads((p/'verification.json').read_text())
report='''# 01R.2 金色虹膜／黑色豎瞳試作

狀態：獨立 Prototype，待使用者審核；核可 checkpoint 仍為 01R.1 v011。只更替眼球表面，不修改眼眶、頭型、球徑、球心、視軸、Rig 或正式模型。

## 生物依據與設計定位

- Malmström & Kröger (2006) 直接記錄尼羅鱷及侏儒鱷的豎瞳：https://journals.biologists.com/jeb/article/209/1/18/33400/Pupil-shapes-and-lens-optics-in-the-eyes-of
- Nagloo (2016) 的原始學位研究記錄澳洲淡水鱷及灣鱷具有明亮黃色虹膜與狹縫瞳孔：https://api.research-repository.uwa.edu.au/ws/portalfiles/portal/16640334/THESIS_DOCTOR_OF_PHILOSOPHY_NAGLOO_Nicolas_2016.pdf
- Banks et al. (2015) 顯示豎瞳與部分伏擊掠食者及晝夜活動相關；這不是「所有掠食者皆有豎瞳」，更不是大型獸腳類的直接證據：https://pmc.ncbi.nlm.nih.gov/articles/PMC4643806/

結論：金色／黃色虹膜與黑色豎瞳有現生鱷類參考；用在 Ninola 是有生物參考的怪獸化設計選擇，不宣稱為獸腳類確定復原。使用者照片僅作外觀參考，保留原水印，不當貼圖或直接複製皮膚細節。

## 修改與資源

每眼 24 環向分段、146 頂點／288 tri，雙眼 576 tri；較來源增加 288 tri，整體 7007 tri。黑瞳長寬約 5.1:1，兩端收尖；三個接近的金色調與琥珀外緣。虹膜 metallic=0；不自發光、不加密集纖維、無外部貼圖。眼球使用較細分段與平滑法線，周圍粗面保留。

## 實際評估與限制

隔離眼球能清楚讀出金底豎瞳，細節程度適合先看方向。但實裝近圖顯示：既有眼眶与前向視軸令虹膜中央在部分角度被遮，斜向特寫尤其難看清瞳孔。這不是單純換瞳孔形狀就能完全解決；不能以隔離眼球好看宣稱頭部眼神已驗收。

建議先審核配色與瞳孔造型；若接受，再針對眼球的虹膜朝向／露出範圍提出有限方案。眼眶保持，本輪不擅自調整已核可視軸或放大球體。也未新增瞳孔縮放或獨立眼球注視控制。

## 驗證

已重新讀取保存檔：眼球以外所有面座標、材質、平滑旗標與權重完全一致；45骨／Rest Pose／目前Pose／Trex Shape Keys簽章一致。新眼球封閉、三角面朝外、每點head權重1；球面半徑讀回誤差小於2e-6。來源SHA不變。14幅實際模型與隔離眼球Workbench多視角圖，不是概念示意或PBR／遊戲最終光照。

桌面MCP握手 Broken pipe / Not connected，本輪未完成桌面繞看，不重啟或覆寫使用者工作。完整遊戲動態、匯出與PBR尚未驗證。未Commit／Push／PR，未替換Production。
'''
(p/'REPORT.md').write_text(report)
html='<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01R.2 金色豎瞳試作</title><style>body{background:#18212a;color:#e4eaf1;font:18px system-ui;margin:30px;max-width:1200px}img{max-width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}a{color:#f2ce82}</style><h1>01R.2｜金色虹膜・黑色豎瞳</h1><p>獨立試作／待審。核可來源 R1 v011 保留，眼眶、球徑、球心、視軸與 Rig 不變。</p><p>隔離眼球形狀清楚；實裝部分角度有既有遮擋，不能把隔離效果視為整體眼神已通過。Workbench預覽，非遊戲／PBR驗收。桌面MCP目前未連線。</p><a href="REPORT.md">研究與技術紀錄</a><p>各列左：原圓瞳；右：新豎瞳</p>'
for n,title in [('eye_forward','隔離正面'),('eye_oblique','隔離斜向'),('installed_front','實裝近正面'),('installed_close','實裝斜向：瞳孔遮擋限制'),('head_front','完整頭部正面'),('head_side','頭部側面'),('head_threequarter','頭部斜向')]:html+=f'<h2>{title}</h2><div class="pair"><img src="before_{n}.png"><img src="trial_{n}.png"></div>'
(p/'index.html').write_text(html)
print('comparison/report/index/reference package ready')
