#!/bin/sh
# 精修暴龍的一輪迭代：背景跑 blender/trex_hd.py → 五個視角的預覽 → 照參考圖排版 → 跟參考圖上下拼成對照圖。
# 用法：tools/trex_hd_iter.sh <版號>   輸出 docs/image/trex_hd_iter/v<版號>.png、v<版號>_對照.png
# 跟 model_iter.sh 分開是因為這支一次出五張圖要自己排；自動檢查一樣是 pipeline.check。
set -e
cd "$(dirname "$0")/.."
N=${1:?版號}
OUT=docs/image/trex_hd_iter
REF=docs/image/dinosaur.png
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
mkdir -p $OUT
LOG=$(mktemp)
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python blender/trex_hd.py -- --out models/trex_hd.glb --preview "$OUT/v$N.png" > "$LOG" 2>&1 || true
grep -E "tris|CHECK|Error|Traceback" "$LOG" || true
if grep -q "CHECK FAIL" "$LOG" || grep -q "Traceback" "$LOG" || ! grep -q "CHECK OK" "$LOG"; then
    rm -f "$LOG"; echo "!! 自動檢查沒過或腳本出錯，這版不送審"; exit 1
fi
rm -f "$LOG"
BG='#2a2a2c'
V="$OUT/v$N"
# 上排 正面｜側面｜背面、下排 上視｜下視（跟參考圖同一個排法）
magick \( "${V}_front.png" "${V}_side.png" "${V}_back.png" -background "$BG" -alpha remove -alpha off +append \) \
       \( "${V}_top.png" "${V}_bottom.png" -background "$BG" -alpha remove -alpha off -resize 50% +append \) \
       -background "$BG" -gravity center -append "$V.png"
# 疊圖：我們的輪廓（洋紅線）描在參考圖的側面和正面上，比例尺相同（參考圖 1 單位 = 103.9 px，預覽 150 px）
# 側面相機中心在 Godot (z=1.2, y=1.75) = 參考圖 (774.6, 250.3)；正面中心 x=0 對到參考圖 x=193
edge() {   # 預覽的不透明區域 → 洋紅色外框（其餘透明）
    magick "$1" -alpha extract -threshold 50% -resize "$2" -morphology EdgeOut Diamond:2 \
        \( +clone -fill magenta -colorize 100 \) +swap -alpha off -compose copyopacity -composite "$3"; }
edge "${V}_side.png" 997x384! "${V}_es.png"
edge "${V}_front.png" 301x384! "${V}_ef.png"
magick \( $REF -crop 300x420+40+40 +repage "${V}_ef.png" -geometry +3+18 -composite \) \
       \( $REF -crop 1000x420+275+40 +repage "${V}_es.png" -geometry +2+18 -composite \) \
       +append -resize 200% "${V}_疊圖.png"
rm -f "${V}_es.png" "${V}_ef.png"
rm -f "${V}_front.png" "${V}_side.png" "${V}_back.png" "${V}_top.png" "${V}_bottom.png"
label() { magick "$1" -resize 1600x -gravity north -background white -splice 0x60 -font "$FONT" -pointsize 40 -annotate +0+10 "$2" miff:-; }
{ label "$REF" "參考圖"; label "$V.png" "第 $N 版"; } | magick - -append "${V}_對照.png"
echo "-> ${V}_對照.png"
