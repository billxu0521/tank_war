#!/bin/sh
# 真的連線的檢查：本機開專用伺服器＋兩個客戶端（tools/net_check.gd），看扣血、血量同步、槍聲有沒有傳到。
# 改了連線（RPC、同步器、主機檢查）之後跑一次：tools/net_check.sh；指定模式：MODE=deathmatch tools/net_check.sh
# 假網路很差：LAG=1 tools/net_check.sh，可加 LAG_MS／JITTER_MS／LOSS（預設 150／40／0.05），客戶端會經過 tools/lag_proxy.py
# 斷線重連：RECONNECT=1 tools/net_check.sh（B 被扣一條命後斷線再連回，看命數有沒有回來）
# 不正常斷線（不送離開，主機要等 ENet 逾時才知道）：RECONNECT=crash tools/net_check.sh
cd "$(dirname "$0")/.."
[ -n "$RECONNECT" ] && MODE=${MODE:-deathmatch}   # 重連檢查要有命數的模式
LOG=$(mktemp -d)
godot --headless --path . -- --server ${MODE:+--mode $MODE} > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
if [ -n "$LAG" ]; then
	python3 tools/lag_proxy.py > "$LOG/proxy.txt" 2>&1 &
	PROXY=$!
	sleep 1
	export JOIN=127.0.0.1:24681
fi
MODE=$MODE ROLE=a godot --headless --path . --script tools/net_check.gd > "$LOG/a.txt" 2>&1 &
A=$!
sleep 1
MODE=$MODE ROLE=b godot --headless --path . --script tools/net_check.gd > "$LOG/b.txt" 2>&1 &
B=$!
wait $A $B
sleep 2   # 等伺服器處理完客戶端離開，再關
kill $SERVER 2>/dev/null
if [ -n "$LAG" ]; then
	kill $PROXY 2>/dev/null
	wait $PROXY 2>/dev/null
	cat "$LOG/proxy.txt"
fi
grep -h "NET \|SCRIPT ERROR" "$LOG"/a.txt "$LOG"/b.txt
grep -h "SCRIPT ERROR\|ERROR:" "$LOG/server.txt" | head -5
echo "伺服器記錄的拉回／拒絕：$(grep -h -c "拉回\|不接受\|被拒" "$LOG/server.txt") 行（僅供參考）"
grep -h "拉回\|不接受\|被拒" "$LOG/server.txt" | head -3 || true
if [ "$(grep -h -c "NET OK" "$LOG"/a.txt "$LOG"/b.txt | paste -sd+ - | bc)" = "2" ]; then echo "== 連線檢查通過"; else echo "== 連線檢查失敗（記錄在 ${LOG}）"; exit 1; fi
