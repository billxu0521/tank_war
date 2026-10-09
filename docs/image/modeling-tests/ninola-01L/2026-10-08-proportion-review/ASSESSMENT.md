# 01L.1 足部比例與Concept對照

2026-10-08；使用者指出加厚後仍奇怪，疑似足部比Concept大很多。本次僅對照分析，沒有新Mesh／Rig修改。

## 判斷

使用者指出的不協調有視覺依據。最明顯的是共同趾根與前趾皮膚構成連續寬面，趾間分化主要落在前端；從側面看是長楔形，三分之四視角看是寬板。01L.1增加Z向肉量，但沒有改足部縱向占地；僅有限收窄皮膚中段，全部claw／趾尖與底部anchor固定，因此並未處理趾長或整體占地。加厚會使既有寬板更像一整塊厚實量體。

概念圖側視的趾體更有由根到爪的收束，正面趾體與間隙更分明，腳部不像連續板面。現狀的「實心板面占比」偏大值得優先處理。但全身側視對照不足以證明整腳外輪廓長寬均大了很多，也不能支持固定百分比或等比縮小結論。Concept為AI生成、pose／透視未校準，正面參考腳部本身也寬；需要區分張開跨度與實心趾根面積。

此為投影外觀判斷，不是實際plantar接地面積或承重壓力量測。上視僅能檢查現狀趾根寬面，現有Concept不提供精確、獨立正交足部Top作量測模板。

## 修正下一輪思路（未執行）

不再以「維持所有趾尖／占地、只增加厚度」作預設。重新blockout足部外形，依次評估：共同趾根的寬度／前伸、三趾相對長度與分叉位置、趾間負空間、趾體→爪的漸收。先判斷哪些共同板面應縮減、哪些部分應分成趾體，必要時接受較大局部Mesh／topology調整，而不是把既有板面普遍加厚。

方案可稱01L.2 Foot Proportion / Toe Separation Blockout；本次未授權執行該方案。若目標需縮短趾體或重排分叉，趾尖／claw及ground anchors可能需要局部重定位，必須在新方案明列，不再將前一輪操作保護誤當永久設計鎖。Rig/Bones／rest／pose保護完全維持；外部Mesh比例可重新審視，但不能忽視與固定骨架的相容性。先比較全腳大形，再處理必要趾根接合；不重新展開hock細修。

01L.1保留試作，未選定；K6為rollback／暫時工作基準，不表示其足部外形全盤核准。RVI-003補記本比例問題。沒有固定縮小百分比、沒有新候選、沒有Commit／Push。

## 對照圖

[原圖顯示對照頁](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-proportion-review/comparison.html)：側視全身去除模型render空白邊框後，以相近全身寬度顯示；細部圖獨立取景，不可據顯示大小直接比尺寸。CSS只改顯示窗口，沒有修改原圖像素。

| Concept side | 01L.1 現狀局部 |
|---|---|
| ![Concept side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-migration/2026-10-08-v001/references/references/extracted-views/concept_side.png) | ![01L.1 side](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_side_01L1.png) |

| Concept front | 01L.1 現狀front |
|---|---|
| ![Concept front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-migration/2026-10-08-v001/references/references/extracted-views/concept_front.png) | ![01L.1 front](/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v001/captures/foot_front_01L1.png) |
