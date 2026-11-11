#!/bin/sh
# 真的連線量火球：本機開專用伺服器（尼諾拉照劇本吐火球）＋一個開視窗的客戶端，兩邊都跑 tools/fireball_probe.gd。
# 用法：tools/fireball_probe.sh；假網路很差：LAG=1 tools/fireball_probe.sh（經過 tools/lag_proxy.py，同 smooth_probe.sh）
# 印兩邊每顆的「火球 …」，和客戶端比伺服器晚幾毫秒看到火球、那一刻落後幾公尺（同一台電腦的時鐘相減；火球每秒 35 公尺）。兩邊都要有 FIREBALL OK 才算跑完。
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
ROLE=server godot --headless --path . --script tools/fireball_probe.gd -- --server > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
if [ -n "$LAG" ]; then
	python3 tools/lag_proxy.py > "$LOG/proxy.txt" 2>&1 &
	PROXY=$!
	sleep 1
	export JOIN=127.0.0.1:24681
fi
ROLE=client godot --path . --disable-vsync --resolution 1600x900 --script tools/fireball_probe.gd > "$LOG/client.txt" 2>&1 &
CLIENT=$!
wait $SERVER
sleep 8   # 客戶端發現伺服器關了才收工
kill $CLIENT $PROXY 2>/dev/null
grep -h "^火球\|SCRIPT ERROR\|Parse Error" "$LOG/server.txt" "$LOG/client.txt"
grep -h "^FBT" "$LOG/server.txt" "$LOG/client.txt" | awk '{ if ($2 == "server") { s[$4] = $6; f[$4] = $7 } else if ($4 in s) printf "第 %s 顆：客戶端比伺服器晚 %d 毫秒看到火球；那一刻客戶端的火球比伺服器的落後 %.2f 公尺\n", $4, $6 - s[$4], ($6 - s[$4]) * 0.035 + f[$4] - $7 }'
echo "（記錄在 ${LOG}）"
if [ "$(cat "$LOG/server.txt" "$LOG/client.txt" | grep -c "FIREBALL OK")" = "2" ]; then echo "== 量完了"; else echo "== 沒跑完"; exit 1; fi
