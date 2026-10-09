# 01R.1 v006 主折面試作
2026-10-09｜有限試作已完成，獨立審視通過討論候選，待使用者造型核可；非頭身風格全部完成。

## 核准內容
使用者核可上一版頭刺配色，幾何化不成功、授權繼續下一步。已將Q1原幾何＋核可頭刺明暗獨立存檔為01Q1_Approved_Spine_Palette，避免因幾何否決而丟失核可棘刺結果。
此核可只指已展示的原頭刺材質分配；沒有增加棘刺、改大小位置或暗自執行先前棘刺改形提案。

## 本次修改
從原Q1另製獨立R1，沿用核可棘刺明暗和原頭顎皮色。
以吻側寬面與低位後頰承托作主面方向，按連續控制平面調整表面，原鼻背與眶周上區保持，不再用規律hill逐點加厚。控制與界面見plane_control_v006.json；原齒列／眼部／口緣／非目標面及Rig保持，來源不回寫。主輪廓保留，鼻端局部轉折仍稍硬，不宣稱所有投影輪廓完全不變。
49個原頂點改形，最大約.055模型單位；11175頂點、6994tri，較Q1減10tri。面數減量很小，不稱效能優化完成。沒有修改下顎量體或擴大其他區域。

v005寬面形成，但鼻背與眶周硬折退步，留獨立檔及captures-v005，不承接。v006从Q1重做低位主面，恢复v005變動的上部來源形。本頁最新比較圖均為v006，與Q1核可原幾何同鏡頭比較。Q1左圖尚未含新核可頭刺明暗，因此上色圖的頭刺差異是已核可項。

## 點評與下一步
幾何主面比v004細碎折帶更清楚；v005眶罩與上顱碎折已收回，一體感较好。吻側仍偏長板，鼻端前的轉接略硬，全身尺度的改善有限。獨立審視通過「有限大面試作可供討論」，不等於頭身風格統一完成，更不替代使用者核可。
建議停在v006先看是否接受主面方向。若仍嫌長板，下一只處理後段承托及鼻端前漸退，不增加細碎折面、不重開鼻背／眉眶／頭型比例。下一修改尚未執行。

## 驗證
20完整模型視圖、8組同鏡頭比較、三人工姿態（jaw20°／35°、head10°），无歷史網格重疊／遮罩。保存讀回：45骨名稱／父子／rest／pose channels與原Trex15 Shape Keys保持；全部保留點weights相同，非改形保留點bind及人工姿態evaluated坐標相同，來源hash保持。改形鄰面及全Mesh退化面均0，pipeline issues=[]、budget=None。
桌面MCP兩方向繞視臨時evaluated display，原檔／scene／active／selection／view還原，初末dirty=false，沒有儲存來源。
這些不是完整流形、相交、完整動畫、遊戲資源預算或Production驗收；Prototype仍無Production Shape Keys。口腔接口／眼神與完整Deformation RVI保持。
未修改Rig、正式01J、遊戲GLB或原Checkout，未Commit／Push／PR。

## 檔案
幾何候選：blender/ninola/working/01R1/2026-10-09-v006/ninola_01R1_geometric_head_jaw.blend
SHA：e881ce6b046b3218edc1da16f8188ea3e1dab2cccbe3ffb0b2ff2f3906affca2
核可棘刺配色副本：blender/ninola/working/01R-spine/2026-10-09-v001/ninola_Q1_approved_spine_palette.blend，實際Hash見approved_spine_palette.json与Asset Index。
來源Q1 hash保持89feeb79f1849b590476715f1db34779d27e6dfa5d918e9ef68bc217280919ae。
