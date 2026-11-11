#!/bin/sh
# 連線量駕駛尼諾拉的鏡頭抖不抖：本機開專用伺服器＋一個客戶端當駕駛，兩邊都跑 tools/jitter_probe.gd（劇本見那個檔）。
# 用法：tools/jitter_probe.sh（客戶端開視窗：WINDOW=1 tools/jitter_probe.sh）；假網路很差：LAG=1 tools/jitter_probe.sh（經過 tools/lag_proxy.py，LAG_MS／JITTER_MS／LOSS 同 net_check.sh）
# 換一支量測（劇本、輸出格式一樣的）：PROBE=tools/gait_probe.gd tools/jitter_probe.sh（量尼諾拉自己的動作）
# 每一幀的原始數字：CSV=/某個資料夾 tools/jitter_probe.sh。印客戶端每段的「抖動 …」；兩邊都有 JITTER OK 才算跑完。
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
ROLE=server godot --headless --path . --script ${PROBE:-tools/jitter_probe.gd} -- --server > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
if [ -n "$LAG" ]; then
	python3 tools/lag_proxy.py > "$LOG/proxy.txt" 2>&1 &
	PROXY=$!
	sleep 1
	export JOIN=127.0.0.1:24681
fi
# 客戶端預設沒畫面（每秒 60 張、靠睡覺對時，幀的間隔不穩，「身體 急轉」會偏多）；WINDOW=1 開視窗照螢幕的幀率跑，比較接近真的
ROLE=client godot $([ -z "$WINDOW" ] && echo --headless) --path . --resolution 1280x720 --script ${PROBE:-tools/jitter_probe.gd} > "$LOG/client.txt" 2>&1 &
CLIENT=$!
wait $SERVER
sleep 8   # 客戶端發現伺服器關了才收工
kill $CLIENT $PROXY 2>/dev/null
grep -h -A6 "^抖動" "$LOG/client.txt" | grep -v "^--"
grep -h "SCRIPT ERROR\|Parse Error" "$LOG/server.txt" "$LOG/client.txt"
if [ "$(cat "$LOG/server.txt" "$LOG/client.txt" | grep -c "JITTER OK")" = "2" ]; then echo "== 量完了"; else echo "== 沒跑完（記錄在 ${LOG}）"; exit 1; fi
