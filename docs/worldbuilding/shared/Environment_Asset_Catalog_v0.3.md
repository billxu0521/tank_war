# 環境資產製作目錄 v0.3

<a id="catalog-guide"></a>

## 1. Catalog Guide 目錄讀法

Version 0.3 · October 19, 2026 · Draft for Review

本目錄列環境資產的製作單位、形態、尺度、材料與查找關鍵字。地圖文件決定場所落點、數量及特殊使用限制；資產碼不含首次使用地圖，供其他地圖引用相同製作單位。

目錄登錄的是**設計需求**，不是已完成模型庫。選件與拆件以此為依據；來源檔、材質參數、匯出及檢核結果於製作時補齊，完成狀態統一記入[專案物件表](../../素材流水線/物件表.md)。

**Table 1. 目錄欄位與使用**

| 項目 | 讀法 |
|---|---|
| ID 與名稱 | 穩定製作單位；碼不因用途、擺放地點或單次修訂改變。 |
| 製作形態與尺度 | 需保留的形態、尺寸範圍與功能；詳細接口依製作摘要確認。 |
| 關鍵字與採用範圍 | 用於尋找構造與外觀參照；不等於可直接使用搜尋結果的圖像或模型。 |
| 形體與搭配 | 第 9 節列已定義配置；其他項目開工時依編碼規則登錄實際 V／L。 |
| 組織與地域 | 第 10 節列客製識別方式；不改變基礎物件身分。 |

命名與組成依[編碼規則](Environment_Asset_Coding_Guide_v0.4.md)。可處理的結構資料另見 [Asset Catalog](Asset_Catalog_v0.3.json)。CD-GBB 的使用限制見[地圖規格](../maps/CD-GBB/CD_GBB_Map_Brief_v1.2.md)。

常規製作單位 112 項；內部測試項目 5 項集中[第 11 節](#test-assets)。兩組共用登錄方式，但使用範圍分開。

<a id="class-veg-0"></a>

## 2. Vegetation 植被

**Table 2. Vegetation 植被｜VEG-0001 至 VEG-0009**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="veg-0001"></a>VEG-0001 | 藍格馬草 Blue Grama | 叢高 0.15 至 0.30 m；雨季綠葉夾少量枯葉，低疏叢。 | Bouteloua gracilis rain season；取梳狀穗與基叢，不做整片高牧草。 |
| <a id="veg-0002"></a>VEG-0002 | 高草叢 Tall Grass Tuft | 0.4 至 0.65 m；葉叢疏密三變體；種未定。 | southwest bunchgrass tuft；取叢生形態，不由照片補學名。 |
| <a id="veg-0003"></a>VEG-0003 | 四翅濱藜 Fourwing Saltbush | 矮型 0.6 至 1.2 m、高型 2.0 至 2.5 m；灰綠多枝低冠。 | Atriplex canescens shrub；形體取自然不規則冠，高型候選需樣本對照。 |
| <a id="veg-0004"></a>VEG-0004 | 矮松 Pinyon Pine | 高 2.8、3.8、4.8 m；冠寬 2.8、3.8、4.6 m；短幹團冠，最低枝葉約 0.5 m。 | Pinus edulis open grown；不取高瘦密林松。 |
| <a id="veg-0005"></a>VEG-0005 | 低枝檜叢 Low-Branched Juniper | 高 2、2.5、3 m；冠寬 2.4、3.2、3.8 m；最低枝葉約 0.25 m。 | Juniperus monosperma shrub form；取低枝與不規則冠，不做球形園藝修剪。 |
| <a id="veg-0006"></a>VEG-0006 | 濕緣莎草叢 Wet-Margin Tuft | 高 0.35 至 0.7 m；只在小水盆及近水邊，種未定。 | rush sedge clump muddy edge；取挺葉叢，不擴成蘆葦沼澤。 |
| <a id="veg-0007"></a>VEG-0007 | 普通枯枝 Dead Branch | 長 0.6 至 2 m；有木纖維斷口；不可與石化木共用表面。 | weathered dead branch wood fibres。 |
| <a id="veg-0008"></a>VEG-0008 | 普通倒木 Dead Log | 長 2 至 4 m、徑 0.2 至 0.45 m；殘皮、縱向裂紋。 | fallen pinyon juniper log；不取石質橫裂。 |
| <a id="veg-0009"></a>VEG-0009 | 立枯樹 Standing Dead Tree | 高 2 至 3 m；灰木縱裂、尖纖維斷端；配置數量與落點由地圖指定。 | standing dead juniper snag；與石化殘幹分形分材質。 |

<a id="class-nat-0"></a>

## 3. Natural Forms 自然形體

**Table 3. Natural Forms 自然形體｜NAT-0001 至 NAT-0009**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="nat-0001"></a>NAT-0001 | 石化殘幹 Petrified Upright Trunk | 高 3、4.5、6 m，徑 0.6 至 0.9 m；無完整枝冠；底部需埋土／岩座。 | petrified conifer trunk natural fracture；滅絕針葉樹型候選，非現生松種。 |
| <a id="nat-0002"></a>NAT-0002 | 石化倒幹 Petrified Fallen Log | 長 3、5、7 m，徑 0.55 至 0.85 m；自然橫斷、低彩礦物斷面。 | petrified logs natural surface；不拋光、不作鋸切均勻圓柱。 |
| <a id="nat-0003"></a>NAT-0003 | 石化樹樁 Petrified Stump | 高 0.4、0.8、1.2 m；一側低埋，根頸不必完整。 | petrified stump broken top。 |
| <a id="nat-0004"></a>NAT-0004 | 石木碎塊 Petrified Fragment | 長 0.25 至 1.2 m；只做幾種可辨的斷面，不做寶石簇。 | petrified wood fragment rough exterior。 |
| <a id="nat-0005"></a>NAT-0005 | 砂岩層塊 Sandstone Ledge | 長 3 至 8 m、露高 1 至 3 m；層厚 0.2 至 0.6 m；至少一面可拼接。 | bedded sandstone ledge weathering。 |
| <a id="nat-0006"></a>NAT-0006 | 砂岩散塊 Sandstone Rubble | 長 0.3 至 1.2 m；與層塊共享岩色、斷面不同。 | angular sandstone rubble。 |
| <a id="nat-0007"></a>NAT-0007 | 泥岩坡片 Mudstone Slope Piece | 長 2 至 6 m；可接坡，細碎頁狀層理。 | mudstone weathered slope bedding。 |
| <a id="nat-0008"></a>NAT-0008 | 泥岩碎片 Mudstone Chips | 長 0.05 至 0.25 m；薄片混粗粒，避免石板鋪地感。 | mudstone chips talus。 |
| <a id="nat-0009"></a>NAT-0009 | 崩積礫塊 Talus Stone | 長 0.03 至 0.4 m，少量 0.6 m；群配另由 ASM 控制。 | sandstone talus size mixture。 |

<a id="class-nat-9"></a>

### NAT-0010 至 NAT-0012

**Table 4. Natural Forms 自然形體｜NAT-0010 至 NAT-0012**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="nat-0010"></a>NAT-0010 | 巨骨殘段 Giant Bone Fragment | 高起彎段、厚根、斷端與低骨板；輪廓以集中破碎、非人型動物骨骸為方向；不同段不按等距成對排列。 | large animal bone cortex fracture；只取骨皮／斷端結構，不複製完整骨架。 |
| <a id="nat-0011"></a>NAT-0011 | 小標本岩塊 Fossil-Bearing Block | 約 0.4 至 1.1 m；骨與圍岩分層；對應採集包覆殼。 | fossil matrix block plaster jacket。 |
| <a id="nat-0012"></a>NAT-0012 | 恐龍卵 Dinosaur Egg | 長 0.25 至 0.35 m；完整與殼片；物種與確切卵形待生物設計。 | 形體為創作候選，不從照片定種。 |

<a id="class-mod-0"></a>

## 4. Modules 拼裝構件

**Table 5. Modules 拼裝構件｜MOD-0001 至 MOD-0009**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="mod-0001"></a>MOD-0001 | 土坯牆段 Adobe Wall Module | 牆厚基準 0.45 m；長度以 1、2、4 m 候選；門窗分件，不拉伸洞口。 | historic adobe wall thickness repair。 |
| <a id="mod-0002"></a>MOD-0002 | 砂岩基腳 Stone Foundation Module | 高 0.2、0.4、0.6 m；轉角與直段分型；貼地端可延伸。 | sandstone rubble foundation adobe。 |
| <a id="mod-0003"></a>MOD-0003 | 木柱 Timber Post | 截面 0.16 至 0.25 m；長 2.4、3、4 m；基腳獨立。 | timber post framing hand tool marks。 |
| <a id="mod-0004"></a>MOD-0004 | 木梁 Timber Beam | 截面約 0.18 × 0.25 m；長 2、4、6 m；節點端保留接合。 | timber beam simple shed framing。 |
| <a id="mod-0005"></a>MOD-0005 | 斜撐 Timber Brace | 截面約 0.10 × 0.15 m；長 0.8 至 1.8 m；不可當主梁。 | timber knee brace shed。 |
| <a id="mod-0006"></a>MOD-0006 | 木板 Plank | 厚 0.025 至 0.05 m、寬 0.15 至 0.3 m；長 1、2、3 m；斷板另設形體。 | rough sawn plank edge grain。 |
| <a id="mod-0007"></a>MOD-0007 | 金屬屋面片 Metal Roof Sheet | 約 0.6 × 1.8 m；可重疊接縫；實際型式待年代細設。 | historic metal sheet roof seam；不套現代彩鋼型錄。 |
| <a id="mod-0008"></a>MOD-0008 | 土屋屋頂邊 Adobe Roof Edge | 木梁頭、土屋頂邊與排水口分型；控制於逐棟高度。 | adobe roof vigas canales；取構造，不整套複製特定建築。 |
| <a id="mod-0009"></a>MOD-0009 | 木欄構件 Fence Module | 欄高 1.2 至 1.4 m；2 至 3 道橫桿；直段／圈門／斷段。 | timber cattle pen fence gate。 |

<a id="class-mod-9"></a>

### MOD-0010 至 MOD-0012

**Table 6. Modules 拼裝構件｜MOD-0010 至 MOD-0012**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="mod-0010"></a>MOD-0010 | 木門及門框 Door Module | 單門、雙門依各棟淨開口；門框厚度向牆內扣，鉸側獨立。 | historic plank door strap hinge。 |
| <a id="mod-0011"></a>MOD-0011 | 木窗及窗框 Window Module | 依逐棟淨開口；固定窗、百葉、封板三型。 | timber sash fixed window shutter。 |
| <a id="mod-0012"></a>MOD-0012 | 石階與短坡 Step and Ramp Module | 踏面深、高度需依入口高差量體確認；石邊與表面可拆。 | stone doorstep ramp masonry。 |

<a id="class-prp-0"></a>

## 5. Props 獨立物件

**Table 7. Props 獨立物件｜PRP-0001 至 PRP-0009**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="prp-0001"></a>PRP-0001 | 木運輸箱 Shipping Crate | 基準長 0.8 × 寬 0.5 × 高 0.5 m；蓋、箱身與扣件分件。 | nineteenth century wooden shipping crate；不採現代棧板規格。 |
| <a id="prp-0002"></a>PRP-0002 | 糧袋 Grain Sack | 約 0.55 × 0.35 × 0.8 m；滿袋／半袋形體；標記另層。 | grain sack hand sewn stencilled。 |
| <a id="prp-0003"></a>PRP-0003 | 木桶 Wooden Barrel | 直徑約 0.55 m、高 0.8 m；桶箍獨立材質區。 | wooden stave barrel iron hoops。 |
| <a id="prp-0004"></a>PRP-0004 | 手推車 Handcart | 約 1.5 × 0.7 m；車輪、把手、斗體分件。 | historic wooden handcart iron wheel。 |
| <a id="prp-0005"></a>PRP-0005 | 農用車 Farm Wagon | 約 3.2 × 1.6 m；軸與輪分件；不可由外觀尺寸直接判定轉彎半徑。 | nineteenth century farm wagon wooden undercarriage。 |
| <a id="prp-0006"></a>PRP-0006 | 檔案盒 File Box | 約 0.4 × 0.3 × 0.25 m；紙頁另件，組織識別獨立。 | archival document box ledger wooden dispatch case。 |
| <a id="prp-0007"></a>PRP-0007 | 款箱 Cash Box | 約 0.45 × 0.3 × 0.25 m；金屬角、提把、鎖，無奇幻裝飾。 | nineteenth century cash strong box。 |
| <a id="prp-0008"></a>PRP-0008 | 包覆殼 Plaster Jacket | 長約 0.5 至 1.2 m；與 NAT-0011 對應凹模，破邊形體另列。 | fossil field plaster jacket burlap。 |
| <a id="prp-0009"></a>PRP-0009 | 岩芯托盤 Core Tray | 槽長約 1 m；托盤、岩芯、編號分件；槽號是場內文字。 | geological core sample wooden tray。 |

<a id="class-prp-9"></a>

### PRP-0010 至 PRP-0018

**Table 8. Props 獨立物件｜PRP-0010 至 PRP-0018**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="prp-0010"></a>PRP-0010 | 岩芯 Core Sample | 直徑候選 0.04 至 0.08 m；完整段與白色夾層形體共用，表面分層。 | rock core sedimentary bedding。 |
| <a id="prp-0011"></a>PRP-0011 | 小銅燈 Copper Lamp | 高約 0.25 m；桌上小物，穩定微亮另作材質／燈光參數。 | small copper oil lamp hooded；紅銅色表面引用 MAT-0021。 |
| <a id="prp-0012"></a>PRP-0012 | 礦片匣 Mineral Case | 約 0.35 × 0.25 × 0.15 m；格間、襯布與蓋。 | mineral specimen wooden case velvet lining。 |
| <a id="prp-0013"></a>PRP-0013 | 水泵 Pump Assembly | 約 1.4 × 0.8 × 1.2 m 候選；泵體、支座與可接管口分件。 | historic reciprocating water pump cast iron；只取機械外觀，動力配置待細設。 |
| <a id="prp-0014"></a>PRP-0014 | 銅閥 Brass Valve | 輪徑約 0.25 m；三銼痕另層；接管直徑與泵件一致。 | brass gate valve handwheel antique。 |
| <a id="prp-0015"></a>PRP-0015 | 管段 Pipe Section | 徑約 0.08 至 0.15 m；直管、彎頭、法蘭及支架分型。 | riveted iron pipe flange historic water works。 |
| <a id="prp-0016"></a>PRP-0016 | 絞盤 Winch | 約 1.8 × 1.4 m；鼓、支座、搖柄、出索點分件。 | manual winch timber mining winding drum。 |
| <a id="prp-0017"></a>PRP-0017 | 繩索 Rope | 直徑約 0.02 至 0.05 m；繩本身／盤繩形體，綁結配置另組。 | hemp rope coil splice。 |
| <a id="prp-0018"></a>PRP-0018 | 吊鉤與滑輪 Hoist Hardware | 鉤長約 0.3 m；鉤、輪與軸分件；承重玩法尚未驗證。 | historic block and tackle iron hook。 |

<a id="class-prp-18"></a>

### PRP-0019 至 PRP-0027

**Table 9. Props 獨立物件｜PRP-0019 至 PRP-0027**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="prp-0019"></a>PRP-0019 | 木滑橇 Wooden Sled | 約 2.4 × 1.2 m；底橇、臺面、拖點分件。 | stone hauling timber sled。 |
| <a id="prp-0020"></a>PRP-0020 | 工作桌 Workbench | 約 1.8 × 0.7 × 0.85 m；抽屜及虎鉗視用途增配。 | historic carpenters workbench simple timber。 |
| <a id="prp-0021"></a>PRP-0021 | 採集刷 Field Brush | 長約 0.2 至 0.3 m；木柄與刷毛分材質；不是鑿或撬槓的變體。 | fossil excavation hand tools brush chisel；無電動工具。 |
| <a id="prp-0022"></a>PRP-0022 | 工具掛架 Tool Rack | 約 1.2 × 0.15 × 0.8 m；壁掛與立架分型。 | wooden hand tool rack。 |
| <a id="prp-0023"></a>PRP-0023 | 飼槽 Feeding Trough | 約 1.5 × 0.45 × 0.4 m；木槽磨損集中上沿。 | timber cattle feeding trough。 |
| <a id="prp-0024"></a>PRP-0024 | 床架 Bed Frame | 約 1.9 × 0.8 m；簡單木架、床面與床卷分件。 | historic simple camp cot timber bed。 |
| <a id="prp-0025"></a>PRP-0025 | 床卷 Bedroll | 長約 1.8 m；展開／捲起形體；毯面獨立材質。 | canvas bedroll wool blanket。 |
| <a id="prp-0026"></a>PRP-0026 | 木凳 Stool | 約 0.35 × 0.35 × 0.45 m；磨損集中座沿。 | rough timber stool historic。 |
| <a id="prp-0027"></a>PRP-0027 | 衣箱 Trunk | 約 0.8 × 0.45 × 0.5 m；箱身、蓋與把手分件。 | nineteenth century travel trunk wooden。 |

<a id="class-prp-27"></a>

### PRP-0028 至 PRP-0036

**Table 10. Props 獨立物件｜PRP-0028 至 PRP-0036**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="prp-0028"></a>PRP-0028 | 灶體 Hearth | 約 1.2 × 0.7 m；石土座、灶口與煙道分件。 | adobe hearth historic farmhouse。 |
| <a id="prp-0029"></a>PRP-0029 | 馬具 Harness | 吊掛形體候選，皮帶與扣件分材質；由房間尺度決定長度。 | nineteenth century horse harness tack。 |
| <a id="prp-0030"></a>PRP-0030 | 生皮 Hide | 寬約 1 至 1.6 m；掛架／折疊形體，非動物屍體模型。 | cattle hide drying frame historic。 |
| <a id="prp-0031"></a>PRP-0031 | 測量三腳架 Survey Tripod | 高約 1.4 m；三腳、儀器與測繪板分件。 | historic surveyor plane table tripod。 |
| <a id="prp-0032"></a>PRP-0032 | 標樁 Marker Stake | 高 0.4 至 0.8 m；編號另層，普通與重號是配置差別。 | wooden survey stakes hand numbered。 |
| <a id="prp-0033"></a>PRP-0033 | 鑽頭 Drill Bit | 長約 0.25 至 0.8 m；獨立金屬件，與手鑽及鑽桿分開。 | historic prospecting drill hand equipment；不採現代鑽機。 |
| <a id="prp-0034"></a>PRP-0034 | 壓力表 Pressure Gauge | 盤徑約 0.12 至 0.2 m；玻璃、盤面、外殼分材質。 | antique pressure gauge brass face。 |
| <a id="prp-0035"></a>PRP-0035 | 車輪 Wagon Wheel | 直徑約 1 至 1.3 m；輪、軸分件，輪緣鐵圈。 | wooden wagon wheel iron tyre。 |
| <a id="prp-0036"></a>PRP-0036 | 油布 Canvas Tarp | 長 1 至 3 m；展開、折疊、蓋箱三型；濕色為材質搭配。 | waxed canvas tarp patch stitch。 |

<a id="class-prp-36"></a>

### PRP-0037 至 PRP-0044

**Table 11. Props 獨立物件｜PRP-0037 至 PRP-0044**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="prp-0037"></a>PRP-0037 | 低鐘 Small Bell | 高約 0.35 m；掛在低梁下，附鐘繩；非鐘塔。 | small historic chapel bell yoke。 |
| <a id="prp-0039"></a>PRP-0039 | 風輪 Wind Wheel | 直徑 2.5 m；葉片、軸、拉件分件；一葉片修補。 | historic farm windmill wheel timber tower。 |
| <a id="prp-0040"></a>PRP-0040 | 低型貨車廂 Boxcar Shell | 12 × 4 m；近水平板殼、低拱頂、門軌、輪架分件；本案頂高另列。 | historic wooden boxcar underframe；車型未定，不直接借現代貨車。 |
| <a id="prp-0041"></a>PRP-0041 | 原紙頁與冊頁 Paper Sheet | 約 0.2 × 0.3 m；平頁、折頁、薄冊；文字另層。 | historic ledger field notebook paper。 |
| <a id="prp-0042"></a>PRP-0042 | 採集鑿 Field Chisel | 長約 0.2 至 0.4 m；金屬刃與握柄分件，普通與嵌石配置共享單件。 | fossil excavation hand chisel。 |
| <a id="prp-0043"></a>PRP-0043 | 撬槓 Pry Bar | 長約 0.8 至 1.2 m；彎端與磨亮接觸面。 | historic iron pry bar。 |
| <a id="prp-0044"></a>PRP-0044 | 手鑽 Hand Drill | 長約 0.3 至 0.5 m；握把、曲柄、夾頭獨立，鑽頭引用 PRP-0033。 | historic hand brace drill。 |

<a id="class-mat-0"></a>

## 6. Materials 材質

**Table 12. Materials 材質｜MAT-0001 至 MAT-0009**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="mat-0001"></a>MAT-0001 | 木面 Timber Surface | 舊灰棕、較新黃棕、局部濕黑；磨耗隨部位。 | weathered rough sawn timber grain。 |
| <a id="mat-0002"></a>MAT-0002 | 暗色鐵材 Ferrous Metal | 暗灰底、磨亮邊與局部鏽；鑄件粗面和鍛製扣件分別在搭配中記表面細度。 | aged ferrous metal cast iron wrought iron surface；依部位區分鑄面與鍛面。 |
| <a id="mat-0003"></a>MAT-0003 | 塗漆木面 Painted Timber | 保留木紋與邊緣磨漆；與 MAT-0001 木面共用相容 UV，塗色作搭配參數。 | painted wooden shipping crate worn paint。 |
| <a id="mat-0004"></a>MAT-0004 | 土坯表面 Adobe Surface | 泥抹、剝落露磚與修補三搭配；非新的牆模型。 | adobe plaster repair texture。 |
| <a id="mat-0005"></a>MAT-0005 | 砂岩表面 Sandstone Surface | 暖灰層理，濕面較深、反光略增，保留粗粒。 | weathered sandstone wet dry surface。 |
| <a id="mat-0006"></a>MAT-0006 | 泥岩表面 Mudstone Surface | 灰褐細層；濕面變暗，不改成黏滑油漆。 | mudstone fine bedding surface。 |
| <a id="mat-0007"></a>MAT-0007 | 屋面鐵皮 Roof Metal | 偏冷灰、接縫局部氧化；鏽不均勻蓋滿。 | weathered sheet metal roof patina。 |
| <a id="mat-0008"></a>MAT-0008 | 黃銅 Brass | 黃褐底、局部深綠斑；閥的手握處較亮，三銼痕可辨。 | aged brass copper patina。 |
| <a id="mat-0009"></a>MAT-0009 | 粗帆布 Canvas | 粗織帆布、縫線和補片；油布可用不同材質搭配，毛毯另列。 | coarse canvas weave seams patches；毛毯引用 MAT-0022。 |

<a id="class-mat-9"></a>

### MAT-0010 至 MAT-0018

**Table 13. Materials 材質｜MAT-0010 至 MAT-0018**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="mat-0010"></a>MAT-0010 | 皮革 Leather | 暗褐、受拉／折處磨白；不套木紋。 | aged harness leather worn edge。 |
| <a id="mat-0011"></a>MAT-0011 | 玻璃 Glass | 微混濁、薄髒污；窗、表面透光需求另核對。 | historic glass slight distortion。 |
| <a id="mat-0012"></a>MAT-0012 | 礦化木 Petrified Wood Surface | 低飽和礦物斷面、外圈深褐，保留少量木質紋理辨識。 | petrified wood rough fracture unpolished。 |
| <a id="mat-0013"></a>MAT-0013 | 巨骨表面 Bone Surface | 暖灰白、霧面骨皮，斷端孔隙，裂縫與埋入端沾同地層土。 | large fossil bone cortical porous fracture。 |
| <a id="mat-0014"></a>MAT-0014 | 草地土面 Grassy Soil | 綠草碎葉與褐土透出；不以純綠地毯代替草叢。 | semiarid grassland monsoon soil。 |
| <a id="mat-0015"></a>MAT-0015 | 工作道路 Work Road | 壓實深淺土帶，邊沿漸混草，中心少草。 | farm dirt track wheel rut after rain。 |
| <a id="mat-0016"></a>MAT-0016 | 採掘棄土 Excavation Spoil | 礫土混合、刷理面與棄堆有差；雨後不成全面亮泥。 | fossil quarry spoil pile damp soil。 |
| <a id="mat-0017"></a>MAT-0017 | 乾縮泥面 Drying Mud | 小片 1 至 3 m；雨後仍可留在高處乾燥斑，面積受分區限制。 | drying mud cracks small patch。 |
| <a id="mat-0018"></a>MAT-0018 | 濕土 Wet Soil | 近水暗色、細小泥邊；混回一般土面需漸變。 | seep muddy margin wet soil。 |

<a id="class-mat-18"></a>

### MAT-0019 至 MAT-0022

**Table 14. Materials 材質｜MAT-0019 至 MAT-0022**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="mat-0019"></a>MAT-0019 | 淺水面 Shallow Water | 薄水盆、低反光；岸界和水面是不同幾何；不含天候系統。 | shallow stock water muddy edge。 |
| <a id="mat-0020"></a>MAT-0020 | 樹脂狀表面 Resin-Like Surface | 琥珀色小條痕；僅石木異常變體使用。 | amber resin streak；創作異常，不作石化過程事實。 |
| <a id="mat-0021"></a>MAT-0021 | 銅 Copper | 銅燈偏紅棕，接觸處略亮，局部氧化；與黃銅閥分開。 | copper oil lamp patina。 |
| <a id="mat-0022"></a>MAT-0022 | 毛毯 Wool Blanket | 粗毛織物低反光、邊縫與折痕；床卷用，非帆布。 | historic wool blanket texture。 |

<a id="class-dec-0"></a>

## 7. Decals and Surface Details 貼花與表面細節

**Table 15. Decals and Surface Details 貼花與表面細節｜DEC-0001 至 DEC-0008**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="dec-0001"></a>DEC-0001 | 濕緣薄苔斑 Moss Film | 只在有光濕邊；暗洞深處不用發光苔。 | thin moss algae film wet stone。 |
| <a id="dec-0002"></a>DEC-0002 | 落葉碎屑 Leaf Litter | 少量在背風邊，與草碎、木屑分開。 | leaf litter sparse ground scatter。 |
| <a id="dec-0003"></a>DEC-0003 | 枯草碎屑 Dry Grass Litter | 飼槽／圈外／路邊分布，非全面覆蓋。 | dry grass straw litter。 |
| <a id="dec-0004"></a>DEC-0004 | 工作木屑 Wood Shavings | 集中鋸架和刨檯，遠離工位迅速減少。 | carpentry wood shavings hand plane。 |
| <a id="dec-0005"></a>DEC-0005 | 組織標記 Organization Mark | 清單按組織鍵指定文字與位置；未定徽章先用簡寫占位。 | lettering stencil cargo mark；不借用真實商標。 |
| <a id="dec-0006"></a>DEC-0006 | 採集編號 Collection Number | 箱號、岩芯槽號、測量樁號分文字內容，底材不共用錯誤比例。 | field collection number tag handwritten。 |
| <a id="dec-0007"></a>DEC-0007 | 使用與濕痕 Use and Water Trace | 泥印、輪痕、水線以位置／方向配置，材質分層可減弱。 | mud footprint wheel rut water stain。 |
| <a id="dec-0008"></a>DEC-0008 | 白色夾層 White Interlayer | 岩芯與一處露頭共用層色及厚度 0.01 至 0.05 m；不發光。 | 創作夾層；只取 sedimentary thin white layer 的視覺結構。 |

<a id="class-asm-0"></a>

## 8. Assemblies 組合

**Table 16. Assemblies 組合｜ASM-0001 至 ASM-0006**

| ID | 名稱 | 製作形態與尺度 | 查找關鍵字及採用範圍 |
|---|---|---|---|
| <a id="asm-0001"></a>ASM-0001 | 貨物堆 Cargo Stack | 引用箱、袋、托木，排出中央搬運空隙；單箱仍 PRP。 | 組合候選，不重建同件箱模型。 |
| <a id="asm-0002"></a>ASM-0002 | 石化木碎段群 Petrified Log Group | 引用 NAT-0002／0004；每群 2 至 4 主段，一側沉入土。 | 群間留 4 至 8 m 不規則空地。 |
| <a id="asm-0003"></a>ASM-0003 | 施工散屑 Work Debris Patch | 引用石塊、土坯、斷板、薄金屬；按作業位置選子件。 | 不是一張混合來源無法拆分的貼圖。 |
| <a id="asm-0004"></a>ASM-0004 | 草巢 Nest Assembly | 直徑 1.4 m、高約 0.25 m；草材與 3 顆卵分件，單一主巢。 | 恐龍物種待定；保留可替換卵模型。 |
| <a id="asm-0005"></a>ASM-0005 | 測繪工作點 Survey Station | 三腳架、板、標樁、箱、凳按臺面配置，朝向骨床。 | 引用既有單件，留 2 m 觀測帶。 |
| <a id="asm-0006"></a>ASM-0006 | 低樹叢組 Low Cover Cluster | 2 至 4 株檜叢搭矮灌木，冠緣相接但不連成牆；枝葉自下部開始。 | 遮蔽功能待尼諾拉實際試位。 |

<a id="variant-register"></a>

## 9. Variant Register 變體與搭配

完整配置以五欄碼識別，對照下表的形體、材質、組織與地域定義。這些配置可直接作製作摘要的選用項；完成時再固定檔案及依賴修訂。未列組合須登錄相容性，不能由五欄任意排列推定有效。

**Table 17. 配置清單**

| 配置碼 | 製作內容 |
|---|---|
| PRP-0001_V00_L00_NONE_STD | 基準木箱；木板 MAT-0001、扣件 MAT-0002。 |
| PRP-0001_V00_L01_NONE_STD | 同一箱模型；箱板換 MAT-0003 塗漆木面，鐵件仍 MAT-0002。 |
| PRP-0001_V00_L02_NONE_STD | 同一箱模型；較深雨後木面搭配，保持扣件區。 |
| PRP-0001_V01_L00_CRMC_CD-GBB | 開蓋形體；內外箱板 MAT-0001、扣件 MAT-0002。 |
| PRP-0001_V00_L00_CRMC_STD | 同一木箱；考爾德箱側標記，不改幾何。 |
| PRP-0001_V00_L00_CRMC_CD-GBB | 上列考爾德箱加 GBB 泥色；跨圖時引用 CRMC 層，另換地域層。 |
| NAT-0002_V00_L00_NONE_STD | 普通礦化倒幹；MAT-0012。 |
| NAT-0002_V00_L01_NONE_CD-GBB | 相同形體，指定斷面加 MAT-0020 樹脂狀條痕；在 CD-GBB 中僅用於 BLD-19 的指定單件。 |
| PRP-0002_V00_L00_LAND-RANC_CD-GBB | 滿糧袋；家庭舊記號與牧業新封記同時保留。 |

<a id="configuration-definitions"></a>

### 定義

V 與 L 各以所屬資產為範圍；L01 不是全庫統一的「濕」或「塗漆」。NONE 表示無組織客製，STD 表示不加地域處理，均保留前面已選內容。

**Table 18. 形體定義**

| 資產／形體 | 定義 |
|---|---|
| PRP-0001／V00 | 完整閉合板箱；BODY 箱板與 HARDWARE 鐵件分區。 |
| PRP-0001／V01 | 同尺度開蓋箱；補內壁、箱底與蓋板內面，保留 BODY／HARDWARE。此配置不含開關動畫。 |
| NAT-0002／V00 | 礦化倒幹；外皮、礦化木質與斷面分區，斷面允許獨立材質處理。 |
| PRP-0002／V00 | 裝滿並束口的粗布糧袋，袋面與束繩分區，兩側保留記號區。 |

**Table 19. 材質搭配定義**

| 資產／搭配 | 部位與材料 |
|---|---|
| PRP-0001／L00 | BODY 舊灰棕木面；HARDWARE 暗鐵。 引用 MAT-0001、MAT-0002。 |
| PRP-0001／L01 | BODY 低彩度灰綠塗漆木面、邊角露底；HARDWARE 暗鐵。 引用 MAT-0003、MAT-0002。 |
| PRP-0001／L02 | BODY 雨後深灰棕木面，濕暗由板端與下緣向上減弱；HARDWARE 保留金屬區，不整體染成黑箱。 引用 MAT-0001、MAT-0002。 |
| NAT-0002／L00 | 普通礦化外皮、木質與斷面；分部位調色，不使用樹脂異常。 引用 MAT-0012。 |
| NAT-0002／L01 | 外皮與木質 MAT-0012，僅指定斷面條痕使用 MAT-0020；不改成全株活木或透明晶體。 引用 MAT-0012、MAT-0020。 |
| PRP-0002／L00 | 粗布袋面與束繩保留各自織／纖維方向，允許同底材調整粗糙度與色差。 引用 MAT-0009。 |

模型完成時，BODY 等語義部位須對應實際表面索引；搭配參數與遮罩隨修訂保存。新增幾何、通孔或需要不同 UV 的表面處理，先查形體相容性。

<a id="organization-register"></a>

## 10. Customization Keys 客製識別鍵

**Table 20. 組織識別對照**

| 鍵 | 關聯組織 | 可用物件 | 識別方式 |
|---|---|---|---|
| NHIS | 自然史院 | 標本箱、包覆殼、標籤、採集記錄 | 箱側採集記號與紙頁批次號對應；只在採集、儲放、運輸關係成立處使用。 |
| VL | 隱燈會 | 礦片匣、遮光布、小銅燈、密封包裹 | 多數外表普通；識別置於匣內小記號，CD-GBB 中的小銅燈只出現於 BLD-11。 |
| HM | 黑爾與默瑟偵探社 | 文件盒、帳冊、款箱、借用工作車 | 文件封套可有 HM 簡寫；車輛用可拆箱牌，不把每輛車永久烙滿徽章。 |
| RANC | 牧業聯盟 | 抵押貨袋、封條、牲畜用具、運貨箱 | 較新封條覆在舊袋記旁；允許與水土同盟的舊記號在同一物件共存。 |
| LAND | 水土同盟 | 家庭寄存袋、互助運輸箱、共用設備修理牌 | 各戶簡記可不同，互助記號較小；設備舊牌保留，不能被新公司牌完全蓋掉。 |
| CRMC | 考爾德鐵路礦業公司 | 機具銘牌、岩芯箱、新管支架、零件運輸箱 | 銘牌、批次號和新漆色形成一套辨識；不需在每件小工具印大商標。 |

地域鍵 CD-GBB 表示本圖的額外色澤／使用處理；不是說基礎資產只屬於 GBB。組織與地域可各自引用，實際放置另記場所 ID。

### 10.1 Markings and Regions 識別與地域

組織代碼表示客製方案，不等於物件所有權。現階段識別採表中簡寫、批次文字、封記與可拆標牌；未設計的紋章不由製作者自行補畫。組織圖樣獨立登錄為 DEC，實體標牌則依用途引用 PRP／MOD。

`LAND-RANC` 為已登錄的複合方案：同一糧袋保留水土同盟家庭舊記與牧業聯盟新封條，不是第七個組織。其他複合方案須另登錄，不能自行串接代碼。

`CD-GBB` 地域方案使用暖灰褐泥色、接地積垢與局部濕暗；不抹除組織識別、物證或材質差異。`STD` 不加地域處理。地域鍵表示外觀方案來源，實際使用地圖另記。

### 10.2 Production Conditions 製作條件

機具、泵與交通器具先依用途確定尺寸及可動部位，再補足結構；參照關鍵字不構成特定年代型號的復原證明。普通石化木、活植物與異常表面分開製作；樹脂狀斷面在 CD-GBB 僅配置於 BLD-19 的指定單件。

<a id="test-assets"></a>

## 11. Test Asset Register 內部測試資產

TST 項目可跨圖重用，適用範圍為內部測試。這些是製作需求，尚非完成模型；發布條件依編碼規則第 7 節。地圖只記採用與落點，不重新定義資產身分。

**Table 21. 測試製作單位**

| ID | 中英文名稱 | 製作形態與尺度 |
|---|---|---|
| TST-ASM-0001 | 經典決鬥圍場 Classic Duel Yard | 64 × 72 m 圍場；四側 8 m 開口；24 箱、8 牆段、4 平台與4 坡道；局部原點為西南角地坪。 |
| TST-PRP-0001 | 決鬥木箱 Duel Crate | 閉合粗板箱；寬面板、淺斜撐；七種尺寸見變體表，無開蓋或互動。 |
| TST-MOD-0001 | 圍場牆段 Yard Wall | 基準長 1 m、厚 0.6 m、高 4.4 m；沿長向拼接或調整至 32 m，截面固定；貼圖尺度不隨長向拉伸。 |
| TST-MOD-0002 | 端部平台 End Platform | 24 × 4 × 1.2 m 土臺；四側立面完整，踏面平整；本型不附欄杆。 |
| TST-MOD-0003 | 平台坡道 Platform Ramp | 6 × 6 m 坡道，升高 1.2 m；實體側面與下部閉合，基準向局部 +Y 升高。 |

木箱為刻意簡化的獨立測試形體，不替換常規 PRP-0001 運輸箱；兩者材質可以共用，形體與用途分開。組合內 24 箱、8 牆段、4 平台、4 坡道，共 40 件；地坪屬採用地圖的整平面。

<aside class="footnote">1. FREIHH and leplubodeslapin, “aim_map,” Steam Workshop, accessed October 19, 2026, <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=122443683">作品頁</a>。參照公開圖像的圍場、箱組及兩端低臺；本套件尺寸與表面為內部測試設計，未匯入原地圖資產，非精確復刻。</aside>

<a id="test-variants"></a>

### 形體與搭配

**Table 22. TST-PRP-0001 箱體尺寸變體**

| 變體 | 寬 × 深 × 高 |
|---|---|
| V00 | 3 × 3 × 2.8 m |
| V01 | 3 × 3 × 1.4 m |
| V02 | 2 × 2 × 1.1 m |
| V03 | 3 × 3 × 1.5 m |
| V04 | 3 × 3 × 2.6 m |
| V05 | 3 × 3 × 2.7 m |
| V06 | 2.2 × 2 × 1.3 m |

其餘四項以 Table 21 的形態作 V00。各單件以包絡西南底角為原點；X、Y 為水平，Z 向上。箱體保留 BODY／BRACE 部位，不含開蓋或互動；尺寸變體不由場內任意縮放代替。

**Table 23. 測試搭配 L00**

| 資產／搭配 | 部位與材料 |
|---|---|
| TST-ASM-0001／L00 | 引用本節子件的 L00，不加整體染色或第二套組織標記。 |
| TST-PRP-0001／L00 | BODY 與 BRACE 皆用 MAT-0001；寬木紋及少量深淺色塊，斜撐保留可見邊緣；不另加鐵件、封條或文字。 引用 MAT-0001。 |
| TST-MOD-0001／L00 | PLASTER 用 MAT-0004，底部 0.3 m BASE 用 MAT-0005；泥抹灰土色、牆腳局部深色，無全面苔面。 引用 MAT-0004、MAT-0005。 |
| TST-MOD-0002／L00 | TOP 與 SIDE 用 MAT-0015，臺緣以色階分面；無積水或草被。 引用 MAT-0015。 |
| TST-MOD-0003／L00 | RAMP 與 SIDE 用 MAT-0015；保留坡頂、坡腳界線，無突起石塊。 引用 MAT-0015。 |

L00 適用該資產已登錄的各 V；NONE／STD 保留上述搭配。粗簡表面以本套件的局部搭配處理，不改寫所有常規物件引用的 MAT；亦不需要將粗紋理誤編成新的模型形體。

<a id="test-assembly"></a>

### 組合與配置

### 11.1 Configurations 配置

本節各形體的配置碼均為「資產碼＿V＿L00＿NONE＿STD」，例如 `TST-PRP-0001_V02_L00_NONE_STD`。七種箱體及其餘四項 V00 共 11 組，完整登錄見 [Asset Catalog](Asset_Catalog_v0.3.json)。組織客製不套用本套件；地域 STD 保留已定義的木色、土色與局部風化。

### 11.2 Assembly 組合

TST-ASM-0001 的 V00 保存子件引用及局部位置，見 [Test Assembly Layout](Test_Assembly_Layout_v0.1.json)。相對原點為 64 × 72 m 圍場的西南角地坪，軸向 X 東、Y 北、Z 上；基準地面為 Z=0。

**Table 24. 組合內容與定位方式**

| 子件 | 數量 | 定位及接面 |
|---|---|---|
| TST-PRP-0001 | 24 | INST-01 至 INST-24；18 箱在地面、6 箱在高 1.2 m 平台；尺寸按各 V。 |
| TST-MOD-0001 | 8 | 4 段長 32 m、4 段長 28 m；四側中間各留 8 m 開口。角部搭接 .6 m，合件清理內面。 |
| TST-MOD-0002 | 4 | 兩端各分左右兩段，中央留 8 m 直通帶；臺高 1.2 m。 |
| TST-MOD-0003 | 4 | 兩端各兩座；南端向南升高、北端向北升高，坡頂接平臺。 |

資料的 bounds_min_local_m 為轉向後包絡的最小角，非任意模型轉軸；牆依 long_axis 排列、坡道依 rise_direction 升高。地圖指定組合落點後轉換局部座標；外接道路、地形過渡、角色起點及場外干擾由地圖另記，不納入套件身分。

本組合的場內幾何固定；若調整箱陣形成可並存的另一套佈局，另登錄 ASM 形體變體。通行、穿透、跳躍與對戰平衡須實作驗證，不由參考圖或登錄完成代替。
