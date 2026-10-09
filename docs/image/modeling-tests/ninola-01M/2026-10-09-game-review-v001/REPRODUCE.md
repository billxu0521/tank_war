# 重現隔離測試

從Ninola Worktree根目錄執行本目錄setup_game_review.py，建立test-project。已有test-project時腳本會停止，不覆寫。使用來源allowlist、M7 evaluation GLB與test-support/review_probe.gd；副本不納入Git。

以Godot 4.7.2開啟test-project，啟動參數為`-- --sandbox`。可用桌面Godot執行檔，背景模式Metal支援需另確認。

實體W/A/S/D移動、F咬擊；F6切換觀察鏡頭。F9截圖同時觸發原pixel-style開關，因此不同截圖可能是不同顯示風格。probe只觀察角色，不注入輸入；telemetry持續寫入，交付採固定telemetry_snapshot.json。

測試只替換副本模型路徑與練習模式角色／出生設定，原始dino.gd保持。測試不證明Production整合、持續衝刺、Boss吼叫、完整碰撞或多人連線通過。
