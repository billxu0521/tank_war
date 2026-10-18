#!/bin/sh
# 對抗模式真的連線檢查：本機開專用伺服器（--mode versus）＋兩個客戶端（tools/versus_check.gd），
# A 想當恐龍、要被抽到並操作得動；B 要看到。改了對抗模式、boss 的駕駛或同步之後跑：tools/versus_check.sh
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
godot --headless --path . -- --server --mode versus > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
ROLE=a godot --headless --path . --script tools/versus_check.gd > "$LOG/a.txt" 2>&1 &
A=$!
sleep 1
ROLE=b godot --headless --path . --script tools/versus_check.gd > "$LOG/b.txt" 2>&1 &
B=$!
wait $A $B
kill $SERVER 2>/dev/null
grep -h "VS \|SCRIPT ERROR" "$LOG"/a.txt "$LOG"/b.txt
grep -h "SCRIPT ERROR" "$LOG/server.txt" | head -5
if [ "$(grep -h -c "VS OK" "$LOG"/a.txt "$LOG"/b.txt | paste -sd+ - | bc)" = "2" ]; then echo "== 對抗模式連線檢查通過"; else echo "== 對抗模式連線檢查失敗（記錄在 ${LOG}）"; exit 1; fi
