#!/bin/sh
# 手的疊圖：把參考圖（藍線）和我們第 N 版（紅線）的輪廓描在同一格裡，哪裡胖哪裡瘦、長短一眼看出來。
# 兩張六格圖（docs/image/hand.png、hands_iter/v<N>.png）是同一套鏡頭、用手長正規化過，可以直接疊；
# 輪廓從渲染時一起存的遮罩（*_mask.png，手白、背景黑）描，不靠顏色分（參考手的灰跟背景太接近）。
# 底圖是參考圖淡化。輸出 docs/image/hands_iter/v<N>_疊圖.png
# 用法：tools/hand_overlay.sh 17
set -e
cd "$(dirname "$0")/.."
N=${1:?版號}
REF=docs/image/hand.png
OURS=docs/image/hands_iter/v$N.png
OUT=docs/image/hands_iter/v${N}_疊圖.png
TMP=$(mktemp -d)
W=560; H=640; LABEL=44  # 每格大小、上面標字的高度
outline() {   # $1 遮罩 $2 x $3 y $4 顏色 → 該格的輪廓線（透明底）：純色圖用描出來的邊當透明度
    magick -size ${W}x$H xc:"$4" \( "$1" -crop ${W}x${H}+$2+$3 +repage -colorspace gray -threshold 50% \
        -morphology EdgeOut Diamond:2 \) -alpha off -compose CopyOpacity -composite "$5"
}
i=0
for r in 0 1; do
    for c in 0 1 2; do
        x=$((c * W)); y=$((r * (H + LABEL) + LABEL))
        outline ${REF%.png}_mask.png $x $y "rgb(30,90,255)" $TMP/ref$i.png
        outline ${OURS%.png}_mask.png $x $y "rgb(230,20,20)" $TMP/our$i.png
        magick $REF -crop ${W}x$((H + LABEL))+$x+$((y - LABEL)) +repage \
            \( -size ${W}x$H xc:"rgba(255,255,255,0.55)" \) -geometry +0+$LABEL -composite \
            $TMP/ref$i.png -geometry +0+$LABEL -composite $TMP/our$i.png -geometry +0+$LABEL -composite $TMP/p$i.png
        i=$((i + 1))
    done
done
magick \( $TMP/p0.png $TMP/p1.png $TMP/p2.png +append \) \( $TMP/p3.png $TMP/p4.png $TMP/p5.png +append \) -append \
    -gravity north -background white -splice 0x50 -font "/System/Library/Fonts/Hiragino Sans GB.ttc" -pointsize 30 \
    -annotate +0+8 "疊圖：藍 = 參考圖、紅 = 第 $N 版" "$OUT"
rm -rf $TMP
echo "-> $OUT"
