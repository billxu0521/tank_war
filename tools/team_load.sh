#!/bin/sh
# 團隊模式 T0：量 10 個人的負擔（tools/team_load.gd）。整組一次開完、一起關，所以外面包一次 Godot 鎖就好：
#   tools/team_load.sh            1 台專用伺服器＋9 個假客戶端，量 3 分鐘
#   CLIENTS=3 tools/team_load.sh  現在的人數（1＋3）對照
#   BOTS=9 tools/team_load.sh     電腦版：不連線，9 個電腦牛仔＋電腦尼諾拉（BOTS=3 是現在的派對）
#   DURATION=60 縮短量的時間（秒）
#   SYNC=30 [SYNC_ROLE=client|server] 同步降頻（只在工具裡）；PROF=1 主機印物理步拆帳
cd "$(dirname "$0")/.."
LOG=$(mktemp -d)
if [ -n "$BOTS" ]; then
	BOTS=$BOTS ROLE=bots godot --headless --path . --script tools/team_load.gd > "$LOG/bots.txt" 2>&1
	grep -h "TEAM_LOAD\|^  主機\|^  送出\|^  收到\|SCRIPT ERROR\|Parse Error" "$LOG/bots.txt"
	exit 0
fi
N=${CLIENTS:-9}
CLIENTS=$N ROLE=server godot --headless --path . --script tools/team_load.gd -- --server --mode party > "$LOG/server.txt" 2>&1 &
SERVER=$!
sleep 4
PIDS=""
for i in $(seq 1 "$N"); do
	ID=$i ROLE=client godot --headless --path . --script tools/team_load.gd > "$LOG/c$i.txt" 2>&1 &
	PIDS="$PIDS $!"
	sleep 0.5
done
wait $SERVER
wait $PIDS
grep -h "TEAM_LOAD\|^  主機\|^  送出\|^  收到\|SCRIPT ERROR\|Parse Error" "$LOG/server.txt"
grep -h "TEAM_LOAD 客戶端\|TEAM_LOAD FAIL\|SCRIPT ERROR\|Parse Error" "$LOG"/c*.txt
echo "伺服器拉回／拒絕 $(grep -c "拉回\|不接受\|被拒" "$LOG/server.txt") 行；客戶端 OK $(cat "$LOG"/c*.txt | grep -c "TEAM_LOAD OK")／${N}（記錄在 ${LOG}）"
