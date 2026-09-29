#!/bin/sh
# 模型的一輪迭代：背景跑 Blender 建模（直接輸出成遊戲用的 models/<名字>s.glb）＋渲染預覽，
# 存到 docs/image/<名字>_iter/v<版號>.png，再跟參考圖 docs/image/<名字>.png 上下拼成 v<版號>_對照.png 給人看。
# 用法：tools/model_iter.sh tree 25、tools/model_iter.sh rock 1（做法見 docs/程式建模迭代.md）
set -e
cd "$(dirname "$0")/.."
NAME=${1:?物件名（blender/<名字>.py）}
N=${2:?版號}
OUT=docs/image/${NAME}_iter
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
mkdir -p $OUT
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python blender/$NAME.py -- --out models/${NAME}s.glb --preview "$OUT/v$N.png" | grep -E "tris|Error|Traceback"
magick "$OUT/v$N.png" -background white -flatten "$OUT/v$N.png"
label() { magick "$1" -resize 1680x -gravity north -background white -splice 0x60 -font "$FONT" -pointsize 40 -annotate +0+10 "$2" miff:-; }
{ label docs/image/$NAME.png "參考圖"; label "$OUT/v$N.png" "第 $N 版"; } | magick - -append "$OUT/v${N}_對照.png"
echo "-> $OUT/v${N}_對照.png"
