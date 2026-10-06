# Golden Eye 建模紀錄 — 2026-10-06 v001

依使用者提供的眼球四視圖建模。

- reference.png：原始參考圖。
- front / side / back / three_quarter.png：模型四視角透明背景渲染。
- preview.png：四視圖總覽。
- comparison.png：參考圖與模型，統一顯示直徑的對比圖。
- 模型：450 頂點、896 三角面；純色材質；正面 -Y、上方 +Z。
- 驗證：0 條非流形邊、正向封閉體積；GLB 只有 GoldenEye 網格。
- 渲染：Blender 5.2.2 LTS，Cycles CPU，24 samples，單視圖 600×600。
- 限制：參考圖深色三角描邊未做成實體線條；尚未遊戲內驗證或獨立審查。
- 來源腳本：`blender/golden_eye.py`；可編輯檔：`blender/golden_eye.blend`；匯出模型：`models/golden_eye.glb`。此目錄為影像的正式留存位置。
