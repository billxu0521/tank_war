# PR 驗證紀錄｜2026-10-09

- 明確allowlist提交：核可checkpoint鏈、核心參考／標註、精選圖、文字與腳本歷程、最終隔離Viewer與壓縮1440幀回放。大量本機歷史不提交也不刪除。
- git diff --cached --check：通過；AGENTS.md、M1simutest.html及正式models/trex_hd.glb／trex.gd未納入。
- 乾淨交付副本最終Viewer匯入：完成、無GDScript錯誤；check_combined.gd輸出COMBINED_SAMPLES_OK。headless dummy renderer仍有null material警告，不稱渲染警告全消除。
- 壓縮回放讀取及verify_composition.py：720候選幀、Rest一致、spine2差0、構成誤差1.32794e-5。原先1440幀Blender交叉檢查與使用者互動核可另見01S報告。
- test_battle.gd：乾淨暫存副本完成資源匯入後輸出OK、退出0；有headless dummy renderer警告與退出資源仍使用警告。第一次未匯入直接跑曾型別／資源缺失失敗；不隱藏重跑條件。
- Root import第一次遇既有blender/golden_eye.blend匯入器路徑未設定。只在暫存副本以blender/.gdignore排除離線來源，再匯入及跑基本檢查；未改正式project.godot或既有golden_eye資產。PR加入blender/ninola/.gdignore與docs/image/modeling-tests/.gdignore，避免新離線checkpoint／研究被Godot當正式資源掃描，獨立子專案仍能以自身path開啟。
- asset_budget.gd：退出1，既有資產29超限／15注意。其掃描正式models資源與HEAD保持相同，此PR沒有改這些資產；不能宣稱全專案budget通過，也不能用此結果驗收未整合的7007tri Prototype。
- 來源R2v005 SHA保持，Rig／Rest／正式Mesh未改，Production仍01J。Pipeline兩個未使用旧眼材質槽與其他工程限制仍未修；不宣稱CHECK OK或完整工程驗收。
- Git分支asset/ninola-authoritative；建立草稿PR，main需另選整合範圍。

## 同步 main 與草稿PR

草稿PR #7：https://github.com/billxu0521/tank_war/pull/7。首次提交3e4a2c9。main新增的忽略規則與本分支.gitignore有文字衝突，已保留雙方規則並同步main，其餘上游變更沿用原內容。同步後乾淨暫存副本再匯入、test_battle.gd輸出OK且退出0，asset_budget仍29超限／15注意；相對origin/main，正式models、trex.gd、main.gd、project.godot無差異。頭頸模型來源保持。
