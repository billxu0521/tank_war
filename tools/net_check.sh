#!/bin/sh
# 真的連線的檢查：本機開專用伺服器＋兩個客戶端（tools/net_check.gd），看扣血、血量同步、槍聲有沒有傳到。
# 改了連線（RPC、同步器、主機檢查）之後跑一次：tools/net_check.sh；指定模式：MODE=deathmatch tools/net_check.sh
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
godot --headless --path . -- --server ${MODE:+--mode $MODE} > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
MODE=$MODE ROLE=a godot --headless --path . --script tools/net_check.gd > "$LOG/a.txt" 2>&1 &
A=$!
sleep 1
MODE=$MODE ROLE=b godot --headless --path . --script tools/net_check.gd > "$LOG/b.txt" 2>&1 &
B=$!
wait $A $B
sleep 2   # 等伺服器處理完客戶端離開，再關
kill $SERVER 2>/dev/null
grep -h "NET \|SCRIPT ERROR" "$LOG"/a.txt "$LOG"/b.txt
grep -h "SCRIPT ERROR\|ERROR:" "$LOG/server.txt" | head -5
if [ "$(grep -h -c "NET OK" "$LOG"/a.txt "$LOG"/b.txt | paste -sd+ - | bc)" = "2" ]; then echo "== 連線檢查通過"; else echo "== 連線檢查失敗（記錄在 ${LOG}）"; exit 1; fi
