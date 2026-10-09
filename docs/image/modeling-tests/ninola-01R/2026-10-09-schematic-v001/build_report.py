from pathlib import Path
import json,html,hashlib
from PIL import Image,ImageDraw,ImageFont
r=Path.cwd();p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';font=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',25);small=ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc',20)
views=[('head_side','頭顎側面'),('head_front','頭顎正面'),('head_threequarter','頭顎3/4'),('head_top','頭顎頂視'),('head_body_context','頭顎與身體銜接'),('full_left_oblique','全身：色面主次與量體保持')]
for name,title in views:
 c=Image.new('RGB',(1600,970),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'01R.1｜'+title+'｜固定幾何的主面／色面示意',font=font,fill='white');d.text((25,65),'Q1 v002｜來源原色',font=font,fill='white');d.text((825,65),'臨時顯示分組｜非新工作模型',font=font,fill='white');c.paste(Image.open(p/'captures'/f'{name}_source.png').resize((760,760)),(20,110));c.paste(Image.open(p/'captures'/f'{name}_grouping.png').resize((760,760)),(820,110));d.text((25,890),'鼻背／吻側／眶後／顎身與腹面分組｜眼、牙、口腔與刺保持',font=small,fill='white');d.text((25,930),'只變臨時顯示色面；沒有幾何轉折／法線修改或減面，尚非遊戲shader驗收',font=small,fill='white');c.save(p/f'{name}_comparison.png')
c=Image.new('RGB',(1600,1040),(24,35,45));d=ImageDraw.Draw(c);d.text((25,15),'棘刺統一風格提案｜頭→肩背→尾：一套主次與朝向',font=font,fill='white');base=Image.open(s/'captures/full_side_color.png').resize((1560,690));c.paste(base,(20,85));d.text((35,795),'頭部：小而嵌入顱部，避免整齊等高針列；不遮住眼神',font=font,fill=(245,198,114));d.text((35,845),'肩背：保留最大主刺，寬基部、後傾、側列錯開；尾部：逐段縮小、疏密有節奏',font=font,fill=(245,198,114));d.text((35,895),'增補候選：頭頸過渡／肩背側列缺口，總量先以0–4根評估；不全身均勻加密',font=small,fill='white');d.text((35,945),'上圖是現況，未移動或新增棘刺。候選需實際表面附著／骨权重／動態核對。',font=small,fill='white');d.text((35,995),'這是Concept導向的風格分布邏輯，不是化石證據或已驗證生長機制。',font=small,fill='white');c.save(p/'spine_style_plan.png')
(p/'DESIGN.md').write_text('''# 01R.1 頭顎主面色面與全身棘刺風格提案

2026-10-09｜使用者接受身體幾何塊面作風格基礎、Low-poly節約方針，核准上一輪固定輪廓示意，另提出頭背尾棘刺可統一、檢視分布與少量增加。

## 本次實際交付

六同鏡頭並排，臨時完整網格以現有面片分組為鼻背／吻側／眶後與後顱／顎身／顎底，局部與全身一起看。僅臨時顯示材質，沒有修改来源Q1輪廓、Mesh、法線、Rig或材質；沒有新.blend工作候選，三角面仍7004，節省面數=0。示意色不是定案palette，World坐標分區只是提案工具，不是完整解剖分區。

只分色能改善區域主次，仍不能讓平整吻側變成身體那種實體幾何塊面。鼻背／吻側轉面、顎身規律細格等若需真正改善，下一Mesh方案需受控的大面轉折／有方向的面片合併，保持外輪廓、口緣與識別量體；不可藉隨機三角色或噪聲偽装成幾何完成。局部面合併是否節省資源，要實體計數與weights／動態驗證，現階段不宣稱減面成果。

## 棘刺審視與提案

用d_spike／d_spike_lit／d_ridge面的共位置連通分量定位94個幾何片群；19群在頭區、42群在尾區，其餘頸軀幹。這是材料幾何群，不直接當實證棘刺根數或生物身份。原圖与Concept對照，肩背最大、往尾縮小有主次；頭部較規律小針、部分頭身刺色／基部／傾角不同。

建議統一寬基部、較粗的截角錐／楔形，整體向後傾，大小與密度沿頭頸→肩背→尾有漸變，側列錯開避免刷子。主刺肩背保留，頭部較小且與眉眶／顱部共讀，尾端細短；不是所有刺等角等高。調整不遮眼／吻輪廓、不拉高顱頂成M2中央尖峰。

少量增補只在頭頸過渡或肩背側列確有缺口時考慮，先0–4根，上限不是必加數；四個4邊封底錐約24tri的粗估，具體Topology與雙色／附著以實作為準，不當現有已新增預算。此圖未畫成已附著的新刺，不宣稱生長機制已驗證；Concept為AI設計，分布是視覺邏輯。

## 點評與下一步（待審）

頭顎色面分組可作結構討論，幅度較小，未達實體塊面目標。建議先由使用者選定這套主面方向，再做獨立幾何風格試作：只處理鼻背／吻側／顎身主要面，保留輪廓與口缘、原眼牙口腔與Rig；同時將『頭背尾既有棘刺外觀統一、必要新增至多4根』列明具體位置與可改物件，再核准實作，不默默挪動全部原刺。頭顎量體已核可，不應風格化後再變回尖峰、方盒或平扁吻。

眼神、口腔接口與完整動態仍RVI004；配色不能保證解決。來源hash保持，無Commit／Push／PR或Production替換。
''');items=''.join(f'<h2>{html.escape(t)}</h2><img src="{n}_comparison.png">' for n,t in views);(p/'index.html').write_text('<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><title>01R.1 主面與棘刺風格示意</title><style>body{background:#18232d;color:#edf0f2;font:18px sans-serif;max-width:1500px;margin:30px auto;padding:20px}p{line-height:1.7}img{max-width:100%;height:auto}h2{margin-top:35px}a{color:#79dfd2}</style><h1>01R.1 頭顎主面／色面與棘刺統一方向｜待審</h1><p>以身體大幾何塊面為方向，先固定幾何比較現有面片分組。沒有減面或改形、沒有新工作模型。<a href="DESIGN.md">點評、棘刺分布與下一步</a>。</p><p>分色只呈現主次；真正幾何塊感仍需後續獨立試作。眼神、口腔、Rig及來源保持。</p>'+items+'<h2>棘刺統一與少量增補提案</h2><img src="spine_style_plan.png"><h2>Concept</h2><img src="../2026-10-09-review-v001/references/concept_overall.png"></html>');print('R1 comparison report/spine plan complete')
