#!/bin/sh
# 碎塊各台位置對不對得上（tools/debris_sync.gd）：1 台主機＋客戶端 a（一開始就在）、b（中途斷線重連）、c（晚加入），約 80 秒。
#   tools/debris_sync.sh              專用伺服器（碎塊不飛，直接落地）
#   HOST=listen tools/debris_sync.sh  自己開房（主機的碎塊也飛）
# 看最後的「DS ====」幾行和「DEBRIS_SYNC OK」（Godot 解析錯誤也回 0）
cd "$(dirname "$0")/.."
HOST=${HOST:-dedicated}
DIR=$(mktemp -d)
export DIR HOST
if [ "$HOST" = listen ]; then ARGS="--host --mode deathmatch"; else ARGS="--server --mode deathmatch"; fi
CLIENTS=2 NAMES="a b c" NAME=host ROLE=server godot --headless --path . --script tools/debris_sync.gd -- $ARGS > "$DIR/host.txt" 2>&1 &
S=$!
sleep 4
NAME=a ROLE=client godot --headless --path . --script tools/debris_sync.gd > "$DIR/a.txt" 2>&1 &
A=$!
NAME=b DROP=1 ROLE=client godot --headless --path . --script tools/debris_sync.gd > "$DIR/b.txt" 2>&1 &
B=$!
NAME=c LATE=1 ROLE=client godot --headless --path . --script tools/debris_sync.gd > "$DIR/c.txt" 2>&1 &
C=$!
wait $S
sleep 3
kill $A $B $C 2>/dev/null
wait $A $B $C 2>/dev/null
grep -h "^DS \|DEBRIS_SYNC\|SCRIPT ERROR\|Parse Error" "$DIR/host.txt"
grep -h "SCRIPT ERROR\|Parse Error" "$DIR"/a.txt "$DIR"/b.txt "$DIR"/c.txt | sort | uniq -c | head -5
echo "（記錄在 $DIR）"
