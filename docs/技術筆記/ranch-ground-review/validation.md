# v13 交付驗證

2026-10-10；基準main82ad1ea，獨立AI覆核可交付Draft PR，未見新增必修視覺項；不代替團隊批准。

| 檢查 | 實際結果 | 界線 |
|---|---|---|
| 當輪Vulkan正式接入／三時段 | 45.25秒／60組complete／exit0，圖形log無ERROR | 腳本固定相機，非真輸入或PVP |
| 遮罩保存讀回 | 七ImageTexture逐byte與核可來源一致 | 檢查交付資料，不證明藝術方向 |
| 批次裝飾與貼花讀回 | 209件／58批／3Decal，各transform有效，無新增碰撞 | dummy不能驗transform，因此此項用真GPU |
| 乾淨交付匯入 | 從Git HEAD的460個遊戲runtime檔加交付allowlist建暫存快照，無舊實驗或快取；headless import exit0、無ERROR | 未包含無關Blender來源／大量歷史；不是完整平台匯出 |
| 乾淨交付依賴 | 專屬check exit0，14資源依賴可讀、無本機實驗路徑，12網格共240面，每件≤48 | 無視窗資料／預算檢查 |
| 基本battle | exit0／OK，無SCRIPT ERROR | 有既存dummy material null、RPC unknown peer、刻意bug測試與退出資源警告；不稱零錯誤 |
| 通用asset_budget | exit1，29既有超上限／15注意 | 原模型未改；新增碎物另以上述專屬check驗證 |
| Git／交付清單 | diff --check通過；只選定本次資產／來源／文件／比較圖 | AGENTS／本機環境／實驗歷史／快取不提交 |

首輪錯誤：bulk importer受本機既有Blender路徑設定阻斷，新增風滾草ctex未生成；47.613秒第一輪場景編譯失敗，整批剔除。等待檔案掃描完成後定向重匯入PNG成功，原PNG與全域Editor設定不改，未清空快取。成功版重新驗證，不沿用失敗成本／圖片。

獨立審視：三時段小鎮通行與森林留白可辨識，濕區未見硬亮環或漂浮黑圈；午夜細節難辨，不能核可人物辨識。材質仍讓Period／PixelStyle更新同一live outline，F9開關待真輸入驗證。成本兩組波動，須報有條件增加，不宣稱穩定優化或Metal／多人FPS。

待驗維持：使用者正式入口實玩、F9、人物／掉落物、連續閃爍、4–8人PVP、低階與其他平台、Metal GPU。原版回退用`--original-ground`，正式合併由billxu／團隊審核。
