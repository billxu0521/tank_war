# Ninola Revisit Register

RVI = Revisit Item。記錄已有 approved 選擇、仍保留合理候選，待後續模型發展再比較的設計決策；不是 rejection 或缺陷清單。新項目依序 RVI-001、RVI-002…。Current approved base 維持 checkpoint index 指定版本；回看只在 temporary / evaluation copy 執行，不覆寫 canonical checkpoint。發現 dependency / fold / intersection / compatibility 問題應回報，不能強行修改正式模型。

## RVI-001 — HIND_UPPER Peak Downshift Strength

- Status: OPEN
- Source pass: 01H
- Regions: L_HIND_UPPER / R_HIND_UPPER
- Current approved choice: `01H_HindUpper_Peak_Downshift = 0.8`
- Retained alternatives: 0.6 / 1.0，均非淘汰版本。
- 設計背景（使用者驗收決策）：0.8 在 peak 下移與 low-poly surface transition 間取得目前較好的平衡；0.6 表面較乾淨但下移較弱；1.0 下移最完整但 HIND_UPPER→HIND_KNEE facet transition 較明顯。此選擇非永久鎖定。
- Revisit trigger: 完成後續 Hind Limb 主要造型修改後，在整條後肢 review 收尾前重新比較 0.6 / 0.8 / 1.0。
- Future evaluation: 載入當時最新 approved checkpoint 的 temporary evaluation copy，保留當時後續 approved Shape Keys / modifications，僅切換 01H strength，固定 camera / lighting 比較。不得為候選另建 canonical approved .blend。
- Compatibility: 現有資料保留完整同一 relative Shape Key，可切換評估；尚不存在的後續 deformation compatibility 未驗證。若有 dependency、穿插、fold 或 boundary 問題，記錄並停止強推，不改正式模型。

### Original comparison references (repository-relative)

- Front strength: `docs/image/modeling-tests/ninola-workflow/history/01H/images/front_hind_upper_strength_comparison.png`
- Front full-leg: `docs/image/modeling-tests/ninola-workflow/history/01H/images/front_full_leg_strength_comparison.png`
- Front silhouette: `docs/image/modeling-tests/ninola-workflow/history/01H/images/front_silhouette_strength_comparison.png`
- Side strengths: `docs/image/modeling-tests/ninola-workflow/history/01H-transition-review/images/side_strength_comparison.png`
- Rear 3/4 strengths: `docs/image/modeling-tests/ninola-workflow/history/01H-transition-review/images/rear_three_quarter_strength_comparison.png`
- Transition close-up: `docs/image/modeling-tests/ninola-workflow/history/01H-transition-review/images/hind_upper_knee_transition_comparison.png`
- Technical reports: `docs/image/modeling-tests/ninola-workflow/history/01H/technical_report.md` and `docs/image/modeling-tests/ninola-workflow/history/01H-transition-review/technical_report.md`

## RVI-002 — 01J Ground Contact Strength

- Status: OPEN
- Source pass: 01J
- Regions: L_FOOT / R_FOOT; toe / claw surfaces
- Current approved: `01J_Ground_Contact = 0.8`
- Fixed Foot Proportion: `1.0`
- Retained alternative: `01J_Ground_Contact = 1.0`
- Revisit trigger: **Rig Motion / Grounding / Locomotion Audit**
- Technical rationale: Ground0.8使foot skin接近Z=0，保留較自然toe/claw vertical variation；仍有已知少量穿地（FOOT minZ=-0.017503；skin minZ L+0.000698/R-0.001723）。Ground1可使所有FOOT references≥Z=0，但趾端較平，既有skin/claw接口新增相交面較多（0.8為6對，1為9對）。後續在實際pose / locomotion / grounding context重新比較。
- Evaluation: 使用最新approved checkpoint的temporary/evaluation copy，保留後續approved修改，固定Foot Proportion1.0，切換Ground0.8/1.0。不得覆寫正式checkpoint，不另建Ground1 canonical approved模型。
- Compatibility warning: 現有skin/claw接口相交需持續追蹤；未來動畫、weight deformation、動態接地未驗證。若出現fold/穿插/dependency須回報，不強行改正式模型。
- Comparison assets: `docs/image/modeling-tests/ninola-workflow/history/01J-review-supplement/images/ground_side_ground_comparison.png`、`ground_front_ground_comparison.png`、`ground_bottom_ground_comparison.png`（同images目錄）。
- Reports: `docs/image/modeling-tests/ninola-workflow/history/01J-review-supplement/technical_report.md`、`measurements.json`、`strength_safety_validation.json`。

## RVI-003 — Distal Hindlimb / Pedal Theropod Silhouette

- Status: OPEN
- Source: User instruction, Pedal Anatomy Audit + Region Map v2, 2026-10-08.
- Registration note: Prior register contained only RVI-001/002; RVI-003 explicitly requested OPEN by user, registered here without fabricating earlier approval/history.
- Current approved model: 01J P1 / Ground0.8; no new morphology approved by this Audit.
- Regions: L/R_PEDAL_PROXIMAL, MID, DISTAL; ANKLE / TOE_BASE boundaries; MAIN_TOE_* / CLAW_* morphology. REAR_DIGIT_CANDIDATE protected until reliable identification.
- Review question: Actual knee->ankle->toe-base bone chain is preserved but external distal surface remains heavy/columnar; evaluate pedal negative space, toe volume/articulation and claw arc independently of grounding.
- Revisit context: Subsequent distal hindlimb/pedal design review and Pedal Anatomy Gate, then rig/deformation/locomotion grounding. No new Shape Key or automatic modification is authorized by registration.
- Candidates: Not yet defined numerically; user's Blue/Red/Yellow textual morphology intent only, no new canonical alternatives created.
- Evidence: `docs/image/modeling-tests/ninola-workflow/history/audit-pedal-anatomy-v1/pedal_anatomy_audit_v1.md`, `pedal_region_map_v2.json` and seven audit images.
- Limitations: Latest readable Side annotation unavailable; exact Green correspondence unknown. Dew-associated rear candidate is not confirmed anatomical hallux. Shared split references/mixed weights require protection; actual safe thinning amount not validated.
