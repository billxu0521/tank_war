# Ninola Pass History — closeout summary

最新決策依HANDOFF；本檔不把歷史technical PASS轉成Production Approval。原始報告和metadata留在docs/workflow-snapshot/history及reports/source-records，未改寫舊结論。

| Pass | 重要改動／結果 | Closeout解讀 |
|---|---|---|
| Audit /01A | Armature pose調整水平body axis、neck/tail posture；01A approved且pose basis JSON可回退 | 歷史approved，01J沿用 |
| 01B /B.2 | Relative Shape Key胸肩/軀幹mass；採原始01B，B.2 front taper未作base | 原始B approved；B.2 not_approved_for_base |
| 01C /C.1 | 骨盆/尾根mass及長taper銜接 | C.1 approved，原C工作資料保留 |
| 01D | Thigh mass distribution | approved |
| 01E | Lower-leg taper | approved |
| 01F /F.1 | Proximal/medial thigh integration；強hip-thigh bridge | F.1 value1 approved；.6/.8只歷史 |
| 01G /G.1 /G.3 | Thigh/knee carve、lower-leg completion；獨立bulge-carve | G.3 value1 approved；residual bulb issue保留 |
| RegionMapv1 /structural/joint-aware audits | 固定溝通regions、actual joint/reference vs silhouette | 不是造型更動，仍沿用 |
| 01H | HIND_UPPER peak往下重新分布 | .8 approved；.6/1仍是RVI-001合理候選 |
| 01I | Inter-joint lowerlimb carve | value1 approved |
| 01I.1 original constraint | 共享endpoint跨界使原scope不可安全執行；停止未deform | constraint歷史保留，不假造workingblend |
| 01I.1 revised | 有限shared-boundary silhouette cleanup | value1 approved，01H.8不變 |
| 01J +supplement | Foot proportion與ground correction拆開比較 | P1/Ground.8是唯一目前Production Approved；Ground1留RVI002 |
| FinalReview/PedalAuditv1/RegionMapv2 | 骨鏈正確不代表外殼theropod morphology正確；拆pedal/toe/rear candidate | RVI003OPEN，anatomy gate繼續適用 |
| 01K constraint/revised | Root固定妨礙posterior lift；允許shared attachment有限deformation；RelativeShapeKey研究 | working v005保留，不approved |
| 01K.1 | Proximal obliquity ShapeKey研究，保K=1 | working v002保留，非後續重建base |
| 01K.2 | 從01J重開，獨立K2key；安全限制降低rootfield後骨架/digits保護成立 | v004 visual success NO；細斜懸空shaft未成立，不能只因安全測試通過宣稱造型成功 |
| 01K.3 | Local topology clip/replacement loft，barycentric source weight transfer；editable Targetprototype | v007 visualPARTIAL；collar/toebase/root突兀、crossings未解，非Production |
| 01K.4 | 兩個真實獨立A/B blockout；A anatomy-balanced較厚，B較纖細 | 使用者後續選A；B保存不混入 |
| 01K.5 | 從A真實可編輯mesh擴大lower distal envelope做多視角morphology；局部subdivision | v002 selected工作路徑，不是approvedProduction |
| 01K.6 | 非對稱shaft-normal mass，實際sample增厚73.9–77.6%，平均76.35%；保斜向與下方negative space | v003被選為Morphology Candidate；87組新增strictpairs、12near-degenerate、12>90°normalchanges保留 |
| 01K.7 | 獨立distal calf/hock重建，補actualmidpoints以接續cutloop；terminaltoe transition | v006使用者否決，外觀退步。K6未被覆蓋；217新strictpairs/48>90°normalchanges/8near-degenerates，失敗分析用 |

## 版本不是必然一pass一.blend
真正檔案逐一列於ASSET_MANIFEST.csv及reports/model_inspection.json。01K.4A/B是獨立.blend；K6/K7各含舊物件。constraint-only revision可能僅報告，不能虛構模型。所有現存Ninola.blend及內部trial副本保留，不靠PNG重新生成。

## 工程與視覺分開
Strict pair counts會受新增/重切triangles影響，須使用provenance comparison，不把數字直接當volumetric collision。K6已有87是相對K5新增，不是全模型總數；K6總1198，K7總1405，1188既有保留、10既有resolve、217新增。87中81保留、6resolve。技術上無gross崩壞、能reopen，不等於自然生物形態或Production Ready。
