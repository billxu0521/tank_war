#!/bin/sh
# 生存物資（blender/survival.py）的兩張標籤貼圖：罐頭一圈的標籤、火柴盒上蓋。改了圖要重跑 tools/model_iter.sh survival。
# 罐頭標籤寬 = 罐子一圈，u=0.5 是正面（鹿頭和字）
set -e
cd "$(dirname "$0")/.."
F="/System/Library/Fonts/Supplemental/Arial Black.ttf"
mkdir -p blender/tex
# 罐頭：從上到下 紅帶 0~25%、米白雪山＋鹿頭 25~55%、深藍帶 55~85%（VENISON STEW 米白字）、紅帶 85~100%。圖高 450 = 罐子一圈 239mm 對標籤高 105mm
magick -size 1024x450 xc:'#b8402f' \
  -fill '#24324a' -draw "rectangle 0,248 1024,383" \
  -fill '#d9d2c3' -draw "polygon 0,248 0,170 90,120 200,175 310,105 420,180 470,150 512,175 554,150 604,180 714,105 824,175 934,120 1024,170 1024,248" \
  -fill '#a8a49c' -draw "polygon 90,120 120,140 105,150 135,160 150,148 200,175 175,180" -draw "polygon 310,105 345,135 325,140 360,155 380,150 420,180 380,180" \
  -draw "polygon 714,105 680,135 700,140 665,155 645,150 604,180 640,180" -draw "polygon 934,120 904,140 919,150 889,160 874,148 824,175 850,180" \
  -fill '#a8a49c' -draw "polygon 380,248 512,150 644,248" \
  -fill '#e3dccd' -stroke '#a8a49c' -strokewidth 3 -draw "polygon 483,248 489,214 496,192 493,172 483,164 491,161 500,167 504,158 520,158 524,167 533,161 541,164 531,172 528,192 535,214 541,248" \
  -stroke '#e3dccd' -strokewidth 6 -fill none -draw "polyline 504,161 494,134 473,110" -draw "line 495,138 470,133" -draw "line 485,124 491,99" -draw "line 479,117 458,106" \
  -draw "polyline 520,161 530,134 551,110" -draw "line 529,138 554,133" -draw "line 539,124 533,99" -draw "line 545,117 566,106" -stroke none \
  -fill '#efe9dd' -font "$F" -pointsize 58 -gravity north -annotate +0+262 "VENISON" -pointsize 40 -annotate +0+322 "STEW" \
  blender/tex/can_label.png
# 火柴盒上蓋：紅底、LIFE、白頂灰藍雪山、下面一條兩端剪成燕尾的藍緞帶寫 SAFETY MATCHES（沒有白框）
magick -size 660x420 xc:'#b23a2c' \
  -font "$F" -fill '#efe8dc' -pointsize 115 -gravity north -annotate +0+8 "LIFE" \
  -fill '#cfd3d6' -draw "polygon 70,300 230,140 300,210 370,110 500,250 550,215 600,300" \
  -fill '#9aa3ad' -draw "polygon 230,140 260,300 300,210" -draw "polygon 370,110 400,300 500,250" \
  -fill '#f4f1ea' -draw "polygon 200,170 230,140 260,170 245,165 230,180 215,165" -draw "polygon 335,150 370,110 405,150 388,144 370,162 352,144" \
  -fill '#2f4a6b' -draw "polygon 40,280 620,280 595,320 620,360 40,360 65,320" -fill '#efe8dc' -pointsize 42 -annotate +0+292 "SAFETY MATCHES" \
  blender/tex/matchbox_label.png
echo "-> blender/tex/can_label.png blender/tex/matchbox_label.png"
