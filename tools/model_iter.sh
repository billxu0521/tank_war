#!/bin/sh
# 模型的一輪迭代：背景跑 Blender 建模（直接輸出成遊戲用的 models/<名字>s.glb）＋渲染預覽，
# 存到 docs/image/<名字>_iter/v<版號>.png，再跟參考圖 docs/image/<名字>.png 上下拼成 v<版號>_對照.png 給人看。
# 用法：tools/model_iter.sh tree 25、tools/model_iter.sh rock 1（做法見 docs/素材流水線/程式建模迭代.md）
# 參考圖不是 <名字>.png 時用 REF 指定：REF=docs/image/house.png tools/model_iter.sh kit 1
# Blender 可用 BLENDER 指定完整執行檔路徑；預設先找 PATH，再使用 macOS 應用程式路徑。
# 沒有參考圖（weapons、props、cowboy、trex）就只出預覽圖。這幾支一次匯出好幾個 glb，放在 models/ 底下各自的檔名。
# 送審前的自動檢查（blender/pipeline.py 的 check：面數預算、沒長出來的零件、葉片卡的貼圖座標、反面）沒過就停，
# 不匯出、不出對照圖，照印出來的 CHECK FAIL 修好再跑。
set -e
cd "$(dirname "$0")/.."
BLENDER=${BLENDER:-$(command -v blender || true)}
BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
if [ ! -x "$BLENDER" ]; then
    echo "!! 找不到 Blender，請安裝或用 BLENDER 指定執行檔路徑" >&2
    exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
    echo "!! 找不到 ImageMagick，請先安裝 imagemagick" >&2
    exit 1
fi
NAME=${1:?物件名（blender/<名字>.py）}
N=${2:?版號}
OUT=docs/image/${NAME}_iter
REF=${REF:-docs/image/$NAME.png}
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
mkdir -p $OUT
LOG=$(mktemp)
"$BLENDER" --background --factory-startup \
    --python blender/$NAME.py -- --out models/${NAME}s.glb --preview "$OUT/v$N.png" > "$LOG" 2>&1 || true
grep -E "tris|CHECK|Error|Traceback" "$LOG" || true
if grep -q "CHECK FAIL" "$LOG" || grep -q "Traceback" "$LOG" || ! grep -q "CHECK OK" "$LOG"; then
    rm -f "$LOG"
    echo "!! 自動檢查沒過或腳本出錯，這版不送審"
    exit 1
fi
rm -f "$LOG"
magick "$OUT/v$N.png" -background white -flatten "$OUT/v$N.png"
if [ ! -f "$REF" ]; then
    echo "-> $OUT/v$N.png（沒有參考圖 ${REF}，不做對照圖）"
    exit 0
fi
label() { magick "$1" -resize 1680x -gravity north -background white -splice 0x60 -font "$FONT" -pointsize 40 -annotate +0+10 "$2" miff:-; }
{ label "$REF" "參考圖"; label "$OUT/v$N.png" "第 $N 版"; } | magick - -append "$OUT/v${N}_對照.png"
echo "-> $OUT/v${N}_對照.png"
