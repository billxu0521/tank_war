from pathlib import Path
import base64,json,hashlib
p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-pass-v003'
current=s/'captures/head_threequarter.png';base=s/'baseline-captures/head_threequarter.png'
uri=lambda f:'data:image/png;base64,'+base64.b64encode(f.read_bytes()).decode()
svg=f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1500" height="1500" viewBox="0 0 1500 1500">
<defs><image id="current" width="1100" height="1100" xlink:href="{uri(current)}"/><image id="base" width="1100" height="1100" xlink:href="{uri(base)}"/>
<marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="4" orient="auto"><path d="M0 0L8 4L0 8" fill="none" stroke="#ffce65" stroke-width="2"/></marker></defs>
<rect width="1500" height="1500" fill="#18232d"/>
<g font-family="Hiragino Sans GB, sans-serif" fill="#eef2f5">
<text x="25" y="43" font-size="30">01R.1 v010｜「後顱階梯」的位置說明</text>
<text x="25" y="79" font-size="20">原始模型渲染＋向量標示；只放大同一位置，沒有修改模型或照片中的造型。</text>
<text x="25" y="122" font-size="24">目前版本：先找位置</text>
<text x="530" y="122" font-size="24">核可來源：同區域放大</text>
<text x="1010" y="122" font-size="24">v010：同區域放大</text>
<svg x="25" y="145" width="480" height="480" viewBox="0 0 1100 1100"><use xlink:href="#current"/>
<rect x="397" y="440" width="83" height="176" fill="none" stroke="#ffce65" stroke-width="7"/>
<path d="M300 430L390 475" stroke="#ffce65" stroke-width="6" fill="none" marker-end="url(#arrow)"/></svg>
<svg x="530" y="145" width="430" height="505" viewBox="350 390 230 270"><use xlink:href="#base"/></svg>
<svg x="1010" y="145" width="430" height="505" viewBox="350 390 230 270"><use xlink:href="#current"/>
<rect x="404" y="463" width="50" height="131" fill="none" stroke="#ffce65" stroke-width="2"/>
<path d="M480 562L448 550" stroke="#ffce65" stroke-width="2" fill="none" marker-end="url(#arrow)"/></svg>
<text x="25" y="673" font-size="22" fill="#ffce65">黃框：眼睛後方、嘴角上方的一條窄轉面；不是顱頂高度的問題。</text>
<text x="25" y="715" font-size="22">我指的是這裡較集中的亮帶與折角，讓粗面頭殼接到頸側時有「折一道」的讀感。</text>
<text x="25" y="755" font-size="22">「階梯」一詞過於籠統；目前未證實是裂縫或穿插，也不等於必須消除的缺陷。</text>
<text x="25" y="799" font-size="22" fill="#8fe0ca">鼻端與眼眶：已依使用者回饋記錄可接受、保留。此處只供判斷是否需要接邊整理。</text>
</g></svg>'''
(p/'rear_junction_explanation.svg').write_text(svg)
(p/'index.html').write_text('''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>Ninola 後顱轉接位置說明</title><style>body{background:#18232d;color:#eef2f5;font:20px sans-serif;margin:25px auto;max-width:1500px;padding:20px}img{width:100%;height:auto}p{line-height:1.7}a{color:#8fe0ca}</style><h1>後顱轉接位置說明</h1><img src="rear_junction_explanation.png"><p>上圖黃框指的是眼後至嘴角上方的窄亮帶。我先前用「階梯」稱呼它，容易讓人以為是顱頂變高或已確認破洞，這不夠精確。現階段只能確定局部轉面與接邊讀感較集中，還不能把它定為必須修復的錯誤。</p><p>在現在的大塊幾何風格中，它也可能是可接受的轉折。我建議列為可選的接邊整理，先不因它否決整版；若後續要動，也只處理這個接口，不動已接受的鼻端或眼眶。</p><p>鼻端與眼眶效果已記錄可接受、保留。本次只建立說明圖，未修改Mesh、Rig或材質。<a href="../2026-10-09-pass-v003/index.html">返回v010完整比較</a></p></html>''')
(p/'source_manifest.json').write_text(json.dumps({'sources':[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in [base,current]],'crop_viewbox':[350,390,230,270],'highlight_current_pixels':[404,463,50,131],'annotation_method':'SVG overlay on unchanged original renders','model_edited':False},indent=2))
