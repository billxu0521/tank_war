# Ninola Chat ↔ Work Workflow v2

## 角色分工

### Chat A
與使用者討論設計、Model Audit、決定修改目標、產生給 Work 的正式指令、讀取 handoff package，向使用者解釋實作內容、方法、技術風險、交付完整性與視覺結果。提出 approve / refinement / rollback 建議，與使用者形成共識後才進下一輪。

### Work B
只執行使用者已核准的 Chat 指令；如實執行 Blender／檔案工作，完整記錄技術事實，產生驗收圖與 handoff package。不自行改變設計目標、不自行 approve／reject、不自行開始下一輪。完成一輪後停止。

### 使用者
負責最終 approval；在 Chat 與 Work 間觸發目前仍無法自動完成的跨 conversation 步驟。檔案存在不代表跨 conversation 自動讀取或同步。

## 每輪標準流程

Chat A 討論 / Audit
↓
使用者 Approve 工作指令
↓
Work B 執行
↓
history/<PASS-ID>/ handoff package
↓
current-review 更新
↓
current-review.zip 更新
↓
Work 停止
↓
Chat A 讀取成果並向使用者解釋：
1. 本輪做了什麼
2. 怎麼做
3. 交付是否完整
4. 是否有技術風險
5. 視覺結果
6. Chat 的 approve / refinement / rollback 建議
↓
使用者決定
↓
Approved checkpoint
↓
下一輪

## Package 與安全規則

每輪先完整建立 history/<PASS-ID>/，包含 manifest.json、handoff_summary.md、technical_report.md、images/。驗證檔案與圖片後再準備完整 staging package，然後更新 current-review；不先清空 current-review。完成後最後生成 ZIP 並測試解壓。讀取端先查 manifest，僅讀取其列出的圖片；current-review 實體圖片集合必須與 manifest.review_images 完全一致。manifest 應最後更新；多檔更新不保證目錄級原子性，ZIP 是完整單一交接載體。

current-review.zip 只包含 manifest.json、handoff_summary.md、technical_report.md、manifest 所列 images/，不含 source-records、alternatives、.blend。除非 Chat 明確要求，禁止加入 .blend。

canonical checkpoint 與 working path 使用 Git repository root-relative。workflow 不搬動模型、不複製 .blend、不建立第二份 canonical checkpoint、不使用 symbolic link。approved checkpoint 不存在時以 null + missing_not_created 記錄，不自行建立或將 working 宣稱 approved checkpoint。

不因製作比较圖或驗收資料而覆寫 approved / working .blend；使用臨時 Audit Scene／獨立 Audit 檔。不得未經指令 Apply／Bake 或改 topology／weights／rest pose。技術報告記錄方法、bones／controls／mesh／modifiers、Direct Edit／Apply／Bake、topology／weights／rest／hierarchy、異常、rollback 與無損回退能力；未知內容寫 unknown。

handoff_summary 使用 Goal、What changed、Method、Safety / Reversibility、Deliverables、Known Issues / Limitations、Work Status 七節。Work 只描述工程事實，approval 來自使用者。

history 圖片不可因下一輪覆寫。每一個實際執行過的 refinement 都使用獨立 pass-id，例如 01B.2；無論最後是否採用，都保存在 history/<PASS-ID>/。未採用者標記 not_approved_for_base。alternatives/ 僅用於沒有正式 pass-id 的舊資料或零散比較素材，不作為正常新流程。metadata 更新前以 copy 保存原版本，原始來源與歷史圖片保留。migration 全程 copy-only / reference-only，不刪、不移動、不重新命名任何舊資料、不修改模型、不 commit／push。

## 本次採用狀態

01A 與原始 01B 已由使用者核准；原始 01B 指原交付最終 v003，而非後續 front silhouette refinement。01B.2 僅列未採用替代方案。01B approved checkpoint 已於使用者明確核准後建立並重新開啟驗證；current-review 指向原始 approved 01B。完整警告與驗證見 migration/migration_report.md。

## 最新核准狀態：01C.1

01C.1由Chat A及使用者正式APPROVED；current-review為01C.1，後續pass唯一base為`docs/image/modeling-tests/ninola-global-mass-01C1/2026-10-07-v002/ninola_global_mass_01C1_approved.blend`。01C保留歷史。舊核准／migration記錄屬歷史當時狀態；最新checkpoint索引與current-review為準。

## 最新核准狀態：01D

01D已正式APPROVED，current-review為01D。後續唯一base：`docs/image/modeling-tests/ninola-global-mass-01D/2026-10-07-v002/ninola_global_mass_01D_approved.blend`。先前核准狀態為歷史紀錄，以checkpoint index最新base為準；不追加01D.1。

## Latest approval: 01E

01E is approved by the user in Chat A. Subsequent passes use `docs/image/modeling-tests/ninola-global-mass-01E/2026-10-07-v001/ninola_global_mass_01E_approved.blend` as the sole approved base. No next pass started.

## Latest approval: 01F.1

01F.1 is approved by the user in Chat A. Subsequent passes use `docs/image/modeling-tests/ninola-global-mass-01F1/2026-10-07-v002/ninola_global_mass_01F1_approved.blend` as the sole approved base. No next pass started.

## Latest approval: 01G.3

Approved 01G3_LowerLeg_Bulge_Carve=1.0. Subsequent sole base: `docs/image/modeling-tests/ninola-global-mass-01G3/2026-10-07-v002/ninola_global_mass_01G3_approved.blend`. Known issue: lower-leg residual bulb / silhouette cleanup; retained without further Shape Key escalation. No next pass started.

## Audit review packages

Audit 是只讀驗收，不是造型 pass。依本次使用者指令，history/audit-hind-limb-v1/ 與 current-review 包含 manifest.json、handoff_summary.md、hind_limb_audit_report.md、measurements.json、images/；ZIP 包含同一組正式交付檔。manifest.technical_report 指向 hind_limb_audit_report.md，不重複生成另一份報告。status/review_state = audit_pending_review。current-review 可代表 Audit；不得因 Audit 而改变 checkpoint index、最新 approved model base 或任何 Shape Key value。後續模型唯一 base 仍依 checkpoints/index.json 的最新 approved checkpoint。

## Revisit Item 制度

統一使用 `revisit-register.md` 與 RVI-001 起的順序 ID，記錄 approved choice、retained alternatives、來源 pass / Region、比較資產與 revisit trigger。候選不等於淘汰版本。回看於 temporary evaluation copy 保留後續 approved modifications 進行；canonical approved checkpoint 不覆寫。後續 Hind Limb 主要造型完成、整腿 review 收尾前檢查 OPEN RVI。compatibility 未驗證須如實記錄，不強行修改正式模型。

## Pedal Anatomy Gate

後續任何distal hindlimb / pedal修改均須結合`history/audit-pedal-anatomy-v1/pedal_region_map_v2.json`與report（保留v1全身ID）。骨鏈正確不等於外部獸腳類形態正確。至少同時檢查：actual bone chain preserved；distal pedal segment不呈過度垂直厚柱；ankle/hock transition可讀；toe-base與ankle不同節點；三前趾保持立體volume；claw保留弧度；rear digit candidate不被誤削；morphology優先Ground Contact；Z0僅作grounding reference，不作foot shape target。

此為後續程序要求，不在Audit中重新核准/否決既有checkpoint。Pedal子分區是功能性溝通label，不是正式解剖或Vertex Group/edit mask；未決mixed toe faces使用MAIN_TOES_SHARED，不能偽造分界。RVI-003保持OPEN；待使用者正式修改指令才執行。
