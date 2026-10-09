# Ninola 01K.6 Fresh Morphology Audit — 2026-10-08

Status: COMPLETE / findings and next proposal pending user review. No morphology pass executed.

## Method and evidence
Opened the imported K6 v003 in Blender 5.2.2, --factory-startup --disable-autoexec. Read only `01K6_Pedal_Segment_Mass_Reconstruction` evaluated geometry, 9766 vertices. Temporary display scene contains only this evaluated mesh and camera; no historical Trex/K4/K5/Audit objects linked to render. No .blend save, mesh/key/pose/rig/weights edits or Apply/Bake. Original 01J/K6 and ZIP hashes verified again after renders.
Eight first captures: Side, silhouette, full-body Side, Front, Rear, Top, front/rear 3/4 closeups. Added two unmasked 3/4 captures. `capture_settings_01K6.json` and `unmasked/capture_settings_01K6.json` contain camera matrices, scale and face display masks. Initial cropped views remove occluding faces (not model edits); upper cut edges and floating display fragments are not treated as model defects. Full-body and unmasked views provide original surface context.
Sources: actual isolated K6, imported Concept reference_1/reference_2 and three-view crops, original user annotations, archived pedal anatomy/region maps. Historical maps describe 01J communication regions, not exact K6 topology edit masks or certified anatomical segmentation.
Reviewer role taken fresh from actual model and references; same Codex performed inspection/capture and visual reading. This is a fresh visual assessment, **not independent reviewer certification**. Historical K7 remains rejected, not candidate/base.

## Findings
| Region | Direct visual observation | Interpretation / priority |
|---|---|---|
| Lower Leg → Ankle | Side distal lower-leg envelope tapers into a thin horizontal ledge; Front/Rear expose a dark transverse band and abrupt section change. Unmasked 3/4 retains this stepped junction. | P1: mass continuity breaks before shaft starts; it reads as a cuff/stacked pieces rather than continuous soft-tissue envelope. Not a request to erase the hock landmark or move joint. |
| Ankle → Pedal | Side has a clear oblique, thick suspended shaft and negative space. Front/Rear show fairly straight broad shaft walls with narrow annular constriction above; 3/4 emphasizes angular attachment. | Preserve accepted shaft amount/obliquity; first improve asymmetric proximal transition, not another uniform inflation or smoothing pass. |
| Pedal → Toe Base | Side shaft lands on a broad low wedge with a raised dorsal step. Front/Top toe-root spreads abruptly into wide, flat triangular toe/claw planes. | P2: proximal-to-distal mass flow lacks gradual toe-base distribution. Restrained root transition possible only in a separately approved scope; toe-body/claw redesign belongs future 01L. |
| Rear Digit Attachment | Rear/Side show a small pointed projection attached to the rear lower envelope; its base is crowded and reads more like a spur at the corner of the wedge. | P3: attachment readability weak. Core/claw retained; no confirmed hallux claim. Requires focused multi-angle attachment review before defining edit mask. |
| Full Hindlimb Mass Rhythm | Full body preserves large torso/thigh, tapered lower leg, oblique shaft and broad foot. The repeated large block → narrow collar → thick block → flat toes creates stop/start rhythm. | Prioritize transition distribution, not increasing entire foot. Preserve whole-body balance and negative space. |
| Multi-view Concept Matching | Concept has more varied dorsal/plantar contours and organic root transitions. K6 direction and shaft thickness broadly support weight, but frontal/rear views remain squared and cuff-like; toes are low planar wedges. | PARTIAL. No calibrated pixel-match score. Real theropod structure is design foundation; these generated/reference sheets are visual guides, not anatomical proof. |

## Concept / anatomy judgment
Accepted K6 shaft proportions remain a useful starting point, not blanket approval of all neighboring anatomy. Low-poly style permits deliberate facets but does not require annular joints, repeated rectangular cross-sections or an abrupt flat toe-root plate. Avoid polishing faceting with generic Smooth while leaving mass distribution unchanged.
Full-body image supports maintaining torso/thigh/tail balance. Head/neck/jaw and other regions were viewed as context, not fully audited or reapproved. No changes proposed outside distal hindlimb.
K7 comparison is retained for failure context only: its technical conservation of shaft thickness did not earn morphology acceptance. Do not copy its collar/hock reconstruction automatically.

## Technical / limitations
`model_inspection.json`: local editable meshes; 45 bones; K6 prototype 0 keys, original Trex 15 keys; rollback pose JSON present. Both imported main files have no linked libraries, unpacked file images, external fonts or caches found in this inspection.
Animation, exact joint clearance, bone containment, collision-free status, weights and Shape Key Compatibility not certified. Historical crossing counts are provenance-dependent and were not recomputed by this visual audit. No new production approval, RVI closure or approved checkpoint.
Full Production Reference Pack remains to be consolidated; supplied references are present and readable but not validated as a scientific anatomical source set.

## Next Proposal — Distal Lower-Leg / Hock Mass Continuity Blockout
Status: PROPOSED ONLY, awaiting explicit approval. Do not start a new 01K subpass automatically; assign a new pass ID after approval.
Base: exact imported K6 v003, separate new working copy; K7 not base.
Goal: remove the narrow collar/stacked-piece reading across Lower Leg→Ankle→proximal Pedal while preserving readable hock, accepted shaft thickness/obliquity and underside negative space.
Scope: asymmetric local envelope redistribution in distal lower-leg, hock and proximal pedal; local topology only where required to create continuous visual mass. Do not extend into toe-body/claw redesign, head/neck/torso/tail, global inflation, production keys/weights or Rig. Toe-base and rear-digit attachment observed but excluded from this first focused edit unless a narrowly necessary boundary adjustment is explicitly part of approved proposal.
Expected: more gradual front/medial/lateral/posterior support into shaft; a hock landmark that reads as a joint rather than a polygon cuff; continuous mass rhythm in Side, Front, Rear and both 3/4.
Risks: erasing hock, thickening into a vertical pillar, filling negative space, creating folds/crossings, changing provisional deformation, damaging protected attachment/core. Shape acceptance alone cannot certify production engineering.
Acceptance: identical camera/pose/lighting baseline vs new copy, six views plus silhouette/full body; distinguish three transition nodes; no new ring band, no flat side plate, no loss of accepted shaft or rear digit. Audit Rig data/production source hashes and protected-core displacement; document topology/weights implications. Measure old/new shaft-normal thickness using the same section definition before setting numerical tolerance (no invented universal % threshold). User judges morphology; Operator reports execution separately. Keep 01J/K6 originals unchanged. No 01L/cleanup/integration.
