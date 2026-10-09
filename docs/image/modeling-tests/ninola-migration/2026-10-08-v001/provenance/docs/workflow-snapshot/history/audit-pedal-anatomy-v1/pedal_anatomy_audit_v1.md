# Ninola Pedal Anatomy Audit v1

Status: `audit_pending_review`。Region Map v2為功能性溝通細分，不是古生物解剖／digit numbering認證。
Source: `docs/image/modeling-tests/ninola-global-mass-01J/2026-10-07-v004/ninola_global_mass_01J_approved.blend`。實際讀取H=.8、I=1、I1=1、P=1、G=.8，与預期一致。
未Edit Mesh、改key coordinates或values、新增key、Pose、bone/joint、weights、topology、rest pose、Apply/Bake/Save。使用temporary evaluated display，不建立正式Vertex Groups。
既有10-07未完成pedal資料保留原位；本輪以重新讀取且內容完全相同的approved來源驗證，完整紀錄保存至10-08-v001。
Latest Side annotation未隨訊息附上；查得候選Downloads/viewpic0004.png主要為黑色，無法閱讀Blue/Red/Green/Yellow。圖上的Blue/Red guide僅依本次文字大意，不冒充描線目標；Green exact correspondence未知。既有Concept三視圖與Joint/Final Audit使用既有資料，未將Concept視為校準geometry。

## Current structural strengths
knee→ankle→centraltoe-base的非直線骨鏈存在；不能因此宣布獸腳類外部形態正確。actual foot bone head→tail只覆蓋這段的一部分，toe-base使用toe2_1實際head而非imported foot tail。左右reference ankle→toe-base長.410853，actual foot bone長.280891，foot tail距centraltoe-base .129961。圖中實線actual bones，白點線尾端→趾根reference，並非另一骨。
ankle(±.66,−.18,.40)→centraltoe-base(±.68,+.10,.10)：Y差+.28、Z差−.30，約43°相對垂直的側面斜向。這是骨／reference線方向，不能當成真實metatarsal解剖長度、肌腱位置或允許削量幅度。
三趾各有toe1/2/3兩段骨，三者root同位置；toe1朝本腿內側、toe3朝外側、toe2最向前，故採INNER/CENTER/OUTER功能ID，沒有宣稱是古生物digits II/III/IV。rear candidate實際dew骨parent=foot。

## Current morphology problems
Side的ankle周圍及PEDAL_PROXIMAL/MID表面厚塊，腹／後下緣接近地面，使ankle→toe-base斜向reference埋在寬厚surface内，仍可讀成偏直、偏柱的distal impression。向後尖突、hock与rear候選同時存在；任何削薄不能把三者一起抹掉。
主要forward toes有寬平多邊形面，toe bones雖分兩段，兩段方向差約4e−6至1.2e−5°（浮點誤差量級），在目前pose近共線，沒有可讀的骨段彎折。Claw由d_claw三角面形成尖楔，可辨根部和尖端，但缺乏連續弧形輪廓。不能用三趾存在或bonechain正確替代volume、dorsal curvature、phalangeal articulation與claw arc驗收。

## Blue-zone analysis
Primary候選：`L/R_PEDAL_MID`、`L/R_PEDAL_DISTAL`；必要transition：`PEDAL_PROXIMAL ↔ ANKLE`及`PEDAL_DISTAL ↔ TOE_BASE`。
P1/P2/P3只是在actual ankle→centraltoe-base reference軸投影的功能三分區，以face centroid分類；不等同真正近/中/遠metatarsal骨段，端點範圍因低面數跨區而重疊，有些P1/P2面延伸很低，不能直接拿整Region uniform削薄。
目前厚柱外缘主要由PEDAL_PROXIMAL/MID及保留的v1 ANKLE/LOWER_DISTAL context共同形成；不是单一普通lower-leg bulb。具體face IDs、vertices、family weights與confidence在map/analysis中。
likely morphology review candidates是PEDAL面中遠離joint的厚後側包絡；joint-transition boundary是靠ankle/toe-base的混合權重面；protected structural area包含關節位置、rear候選、趾根、主要趾与爪。analysis的face centroid距joint<.12只作保守visual-review flag，不是經驗證safe clearance。沒有動態試驗，本次不能宣稱任一區已可安全削薄。

| Region | faces L/R | references L/R | 證據 |
|---|---|---|---|
| L/R_PEDAL_PROXIMAL | 18/17 | 54/51 | communication thirds along actual ankle->centraltoe-base reference; not anatomical metatarsal segments |
| L/R_PEDAL_MID | 4/7 | 12/21 | communication thirds along actual ankle->centraltoe-base reference; not anatomical metatarsal segments |
| L/R_PEDAL_DISTAL | 8/11 | 24/33 | communication thirds along actual ankle->centraltoe-base reference; not anatomical metatarsal segments |
| L/R_TOE_BASE | 4/5 | 12/15 | root-proximity communication zone; mixed weights retained, no anatomical segmentation claim |
| L/R_MAIN_TOE_INNER | 24/19 | 72/57 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_MAIN_TOE_CENTER | 24/22 | 72/66 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_MAIN_TOE_OUTER | 32/35 | 96/105 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_REAR_DIGIT_CANDIDATE | 23/17 | 67/49 | dew family mean weight >=.45 and strongest; candidate, not hallux |
| L/R_CLAW_INNER | 6/6 | 16/16 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_CLAW_CENTER | 6/6 | 16/16 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_CLAW_OUTER | 6/6 | 16/16 | strongest toe family mean weight>=.45; claw uses actual d_claw material |
| L/R_MAIN_TOES_SHARED | 10/10 | 30/30 | merge uncertain per-face toe family association instead of fabricating toe subdivision |

## Red-zone analysis
Posterior / lower negative space應評估`PEDAL_PROXIMAL + MID + DISTAL`的後／腹側表面及`ANKLE`boundary；完整face候選清單在pedal_analysis.json.deformation_zone_candidates。圖中紅色projected plantar曲線只取PEDAL+TOE_BASE三角面在Y截面的minZ，青色取maxZ；排除main toes/claws/rear candidate，不是假定實際sole或肌腱。
Red文字意圖可能與`REAR_DIGIT_CANDIDATE`及toe-root混合權重帶重疊。不能為了負空間誤削dew-associated結構，也不能把joint/hock外凸一概當脂肪。任何後續上／內收須逐bundle保護rear/root并驗證Side轉折；本次未畫出新的目標surface或改geometry。

## Rear-digit candidate
識別依據是actual dew_l/r bone与vertex-group family、後向外形及d_claw材質。不是仅凭Green文字命名。

| Side | candidate faces | skin refs | claw refs | mean dew weight | foot mix refs (> .01) | main toe mix refs (> .01) |
|---|---:|---:|---:|---:|---:|---:|
| L | 23 | 51 | 16 | 0.698529 | 59 | 50 |
| R | 17 | 33 | 16 | 0.650834 | 49 | 46 |

L有23面（其中6 d_claw），R17面（其中6 d_claw）。vertex refs與face IDs完整列在pedal_analysis.json.rear_digit与v2map；skin和claw有獨立connected patch，但全部仍在Trex單一mesh object內，skin／root與foot及main-toe weights混合，不是獨立可任意切除digit物件。
dew head=(±.68,−.02,.17)，tail=(±.626497,−.287516,.103121)，確為從foot骨下向後的骨段。可稱「dew-associated rear digit candidate」，不可稱已確認anatomical hallux。未取得最新可讀Green標註，是否正是使用者圈定結構仍unknown。
建議後續列protected morphology：候選skin、其6面claw、mixed-weight root与所有coincident split bundles；不把低confidence root完全當独立digit本體。

## Toe / claw morphology
Toe skin以strongest toe-family mean weight≥.45分類；claw還必須actual d_claw材質，骨架沒有独立claw bone，因此claw skinning對應toe bones不是另造claw骨。
TOE_BASE限靠actualroot的mixed faces；無法可靠分到單趾的forward skin，合併為`L/R_MAIN_TOES_SHARED`（各10面），避免偽造精確toe boundary。Region v1全26ID/既有display_number/colors/faces/vertices保留，新增24pedal子ID。
低poly toes側視趾節皮面可見polygon transition，但不存在已验证的獨立phalangeal segmentation/tendon來源；toe1/2/3每段近共線是actual default pose事實，不代表不能以未來rig產生彎折。主要三爪每個6三角面（16split references），根／尖可辨，弧度不符合本次希望的清楚claw arc。
Yellow文字意圖對應MAIN_TOE_*+CLAW_*及TOE_BASE transition；後續應先處理立體volume与弧，再重新grounding，而不是把所有toe頂點壓向Z0。

## Ground-contact side effects
本輪完全不改任何values。因果比對使用先前已輸出的P1/G0 geometry，H/I/I1等同目前approved；不是本輪切key或假造無Ground模型。
G.8不是單純raise所有低點：main toe skin局部Z被壓低約.0079，同时原低点上抬最多L .01016/R .01579；爪尖最多上抬.07403，爪上表面部分下降約.00773。由此縮小低位垂直起伏；各toe skin較高bbox頂點未變，故不能说所有toe dorsal volume全部是Ground造成。原pose近共線与簡單mesh wedge同樣重要。

| Side/material | min approved Z | near refs | below0 refs | 新近地refs（對舊G0） | 最大 abs Z delta |
|---|---:|---:|---:|---:|---:|
| L/skin | 0.000698 | 35 | 0 | 4 | 0.010160 |
| L/claw | -0.017503 | 13 | 21 | 9 | 0.074027 |
| R/skin | -0.001723 | 93 | 17 | 17 | 0.015793 |
| R/claw | -0.017503 | 13 | 21 | 9 | 0.074027 |

Near=|Z|≤.01，不是真實contact pressure或sole面积。Bottom markers依目前geometry分類；新增近地refs證明是Ground修正推入near band，未证明它们應承重。現有爪尖低Z和6組新增skin/claw相交面對（前次Final Review嚴格非共面測試）仍保留，不在本次修正。

## Proposed editable regions
僅供下一次正式指令定scope，不是已驗證安全或執行授權。
- Primary silhouette candidate：L/R_PEDAL_MID、PEDAL_DISTAL，以及少量PEDAL_PROXIMAL後側非joint核心面。
- Boundaries：L/R_ANKLE、TOE_BASE、MAIN_TOES_SHARED與PEDAL各區coincident endpoints；按照實際split bundle一致處理，不能只移一份。
- Toe-volume/claw morphology應作獨立考量：MAIN_TOE_INNER/CENTER/OUTER及CLAW_INNER/CENTER/OUTER，不以ground target反向定型。
- 名稱不能作自動Vertex Group或全Regionuniform scale mask；所有候選face lists保留confidence與shared warnings。

## Protected regions
所有actual bones/joints、bone lengths、rest/pose/weights/topology、HIND_LOWER_MID以上approved核心；ANKLE/hock及toe-base joint transition，REAR_DIGIT_CANDIDATE包括claw/root，未決MAIN_TOES_SHARED全部需特別保護。
肌腱實體／正式metatarsal／anatomical digit numbering沒有可靠mesh／rig證據，不能自行命名或用僅一條reference線給出safe thinning極限。

## Pedal Anatomy Gate result
Gate是後續distal modification的固定程序条件，不用來推翻既有approved值。當前骨鏈項成立，但外部morphology項尚未全面成立；不得宣稱已通過全套pedal形態驗收。

| Gate | 本次結果 |
|---|---|
| actual bone chain preserved | verified：保持讀入approved pose，未動骨 |
| distal pedal segment不過度垂直厚柱 | needs morphology review：PEDAL/ANKLE後下表面仍厚 |
| ankle/hock transition可讀 | partial：bone折向與後方表面存在，外包絡偏塊狀 |
| toe-base與ankle不同節點 | verified：actual heads距.410853，foot tail不是toe-base |
| 三前趾保持3D volume | pending：有三趾surface，但vertical articulation與dorsal curvature简化 |
| claw保留弧度 | needs refinement review：主要为低面数尖楔，无明确連續弧 |
| rear digit不誤削 | protected candidate identified；exact Green correspondence unknown |
| morphology優先Ground Contact | future workflow rule；不能以當前near count宣稱形態成立 |
| Z0只為ground reference、不作foot shape target | 本輪已遵守；後續須持續檢查 |

## Candidate next modification
可能分開討論：①不動骨／joint与rear candidate的PEDAL posterior/dorsal envelope相對減薄与负空間；②保持三趾辨識度的digit volume、dorsal curvature和claw arc；③形態確定後再單獨grounding。优先可逆獨立deformation；若現有低poly/split/mixedweights不能安全達成，先surface/topology feasibility review，不在本Audit自動remesh或改權重。
不提出削薄百分比／joint移动／新approved strength；RVI-003保持OPEN，等待使用者/Chat設計端下一步指令。

## Verification / provenance
Approved source SHA-256：`b8b7e5c11f9a7c6f80901086e3d03d609f6ec732a1d888b0fdd66a61eba613b3`（before/after相同）。完整model fingerprint：`661f09a5f1144bf02677e29316b3a40bf3e49dbfc169bde12d7ef80eba1b5bfe`（Basis/keys values&coordinates/faces/groups/weights/pose/rest/01Arollback均包含）。
Pedal regions只在FOOT及必要ANKLE原有face集合中细分；LOWER_DISTAL为context，不重新标定。既有RegionMapv1原檔SHA與嵌入regions一致，無新Vertex Groups。Concept來源沿用Final Review reference_sources，未知annotation精確位置不猜。
Source inventory/face evidence保存於独立工作紀錄；review package不含.blend。RVI register原先仅有001/002，本次依用户指定补登003 OPEN，原001/002保留，未變更approved checkpoint index。

## Independent image QA
七張圖可交付。Front/Top最初標籤重疊已修正：完整RegionID外置、引線和色點可追溯至實際可見face；遮擋區標Hidden，两足完整入框，Side L/R不同。形態觀察：近踝高塊、中段厚度和rear候選銜接共同造成厚柱感；三趾skin近大片合併楔板、趾節起伏少，爪呈直三角楔；rear小尖突及相連綠色面需保護。Bottom near點不是pressure/contact證明，文字intent不冒充不可讀Side標註描線。圖面QA可交付不等於Pedal Anatomy Gate全通過。
