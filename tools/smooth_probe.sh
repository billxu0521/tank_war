#!/bin/sh
# 真的連線量順不順：本機開專用伺服器（尼諾拉照劇本撞穿房子）＋一個客戶端（在場上來回跑），兩邊都跑 tools/smooth_probe.gd。
# 用法：tools/smooth_probe.sh；假網路很差：LAG=1 tools/smooth_probe.sh（經過 tools/lag_proxy.py，LAG_MS／JITTER_MS／LOSS 同 net_check.sh）
# 印伺服器每一段、客戶端整段的「順暢 …」，和伺服器自己記的「主機停頓」「重烘導航」「拆積木」行數。兩邊都要有 SMOOTH OK 才算跑完。
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
ROLE=server SCEN=${SCEN:-plow} godot --headless --path . --script tools/smooth_probe.gd -- --server > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
if [ -n "$LAG" ]; then
	python3 tools/lag_proxy.py > "$LOG/proxy.txt" 2>&1 &
	PROXY=$!
	sleep 1
	export JOIN=127.0.0.1:24681
fi
ROLE=client godot --headless --path . --script tools/smooth_probe.gd > "$LOG/client.txt" 2>&1 &
CLIENT=$!
wait $SERVER
sleep 8   # 客戶端發現伺服器關了才收工
kill $CLIENT $PROXY 2>/dev/null
grep -h "順暢\|SCRIPT ERROR\|Parse Error" "$LOG/server.txt" "$LOG/client.txt"
echo "伺服器記錄：主機停頓 $(grep -c "主機停頓" "$LOG/server.txt") 行、重烘導航 $(grep -c "^重烘導航" "$LOG/server.txt") 行、拆積木太慢 $(grep -c "^拆積木" "$LOG/server.txt") 行（記錄在 ${LOG}）"
grep -h "主機停頓" "$LOG/server.txt" | sort -t ' ' -k2 -n -r | head -3
if [ "$(cat "$LOG/server.txt" "$LOG/client.txt" | grep -c "SMOOTH OK")" = "2" ]; then echo "== 量完了"; else echo "== 沒跑完（記錄在 ${LOG}）"; exit 1; fi
