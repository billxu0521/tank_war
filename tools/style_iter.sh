#!/bin/sh
# 全場景風格檢查的一輪：從固定角度拍遊戲畫面（tools/style_shots.gd），拼成 docs/image/style_iter/v<版號>.png，
# 左上角標名字，給人和審查子代理看。用法：tools/style_iter.sh 1
set -e
cd "$(dirname "$0")/.."
N=${1:?版號}
OUT=docs/image/style_iter/v$N
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
mkdir -p $OUT
OUT=$OUT godot --path . --resolution 1280x720 --script tools/style_shots.gd >/dev/null 2>&1
magick montage $OUT/*.png -tile 3x -geometry 960x540+4+4 -font "$FONT" -pointsize 22 -title "第 $N 版" docs/image/style_iter/v$N.png
echo "-> docs/image/style_iter/v$N.png"
