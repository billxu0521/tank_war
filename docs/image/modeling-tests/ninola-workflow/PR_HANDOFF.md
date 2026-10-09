# Ninola 分區檢視與核可 Prototype 交接

本分支保存01K→01S的研究、討論、試作與核可歷程，供專案審查；不是直接替換正式遊戲模型的合併包。正式Production仍為01J。

## 核可結果

- 模型：[01R.2 v005](../../../../blender/ninola/working/01R2/2026-10-09-v005/ninola_01R2_gold_slit_eye.blend)，Object `01R2_Gold_Slit_Eye`，9441頂點／7007tri／45骨。
- runtime姿態：B（頸Skeleton-X +12°、頭補償-4°）與jaw中性閉合1.5°；Pose沒有烘焙進Blend，Rig／Rest保持。
- [定版紀錄](../ninola-01S/2026-10-09-combined-viewer-v001/APPROVAL.md)、[全身與口頸比較](../ninola-01S/2026-10-09-combined-viewer-v001/comparison.png)、[測試報告](../ninola-01S/2026-10-09-combined-viewer-v001/REPORT.md)。
- 分區回顧：後肢足部、頭部、下顎、頸軀幹與收腹、前肢掌指、骨盆尾部、全身塊面與棘刺、金色豎瞳、體態與咬合。頸軀幹按使用者決定沿用；失敗方案保留文字紀錄。

## 本機重現

從Repository根目錄執行（Godot 4.7.2）：

```sh
godot --headless --editor --import --quit --path docs/image/modeling-tests/ninola-01S/2026-10-09-combined-viewer-v001/test-project
godot --path docs/image/modeling-tests/ninola-01S/2026-10-09-combined-viewer-v001/test-project
```

T切原版／核可姿態，C操作，W走／Shift+W跑、A/D轉向、Z咬擊、X吼叫。這是隔離Viewer，沒有改正式trex.gd或models/trex_hd.glb。完整隔離Viewer來源與GLB一併交付；模型匯出來源與腳本見01S review-v001/export_clean.py及export_records.json。

`combined_samples.json.gz`是完整1440幀數據；check_blender.py與verify_composition.py可讀壓縮版本，從Repo根目錄執行。check_blender.py使用Blender 5.2的記憶體回放、不保存來源。verify_composition.py需要NumPy。重跑會更新此評估目錄內結果，不寫正式模型。

## 紀錄權威與收錄範圍

[STATE](STATE.md)是唯一Current State，[DECISIONS](DECISIONS.md)、[模型討論log](DISCUSSION_LOG.txt)、[RVI](revisit-register.md)、[資產索引](asset-index.json)保存決策與待處理項目。歷史檔記載當時狀態，不能當最新核可。

PR收錄核可checkpoint鏈、必要概念／標註、精選比較圖、文字與腳本歷程；大量逐幀圖、GIF、原始大回放、Rejected實驗Blend、ZIP與重複測試專案保留原本本機位置，不刪除、不無差別加入Git。歷史報告可能指向這些本機檔，完整本機asset-index不代表所有檔案都已提交。publication-manifest.json明確區分本次published與local_only。舊歷史腳本若依賴未提交實驗資產，不能宣稱乾淨clone可逐輪重建。最終Viewer及合併數據為本次可重現入口。

## 工程邊界

Prototype未整合Production Shape Keys；Topology、Weights、Shape Key Compatibility、Deformation及Export仍需交付整理。既有後口內腔交叉OPEN、接地DEFERRED。六模式各120幀有限採樣牙面交叉max0，不代表幀間、完整口腔、全遊戲或碰撞驗收。MCP本輪未連、背景回放及原生Godot畫面留存，不能宣稱桌面MCP驗收。两個舊眼球空材質槽尚在。

草稿PR只供分支成果與歷程審視；入main需另外選取範圍並完成相應驗證。
