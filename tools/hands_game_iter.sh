#!/bin/sh
# 手的「玩家視角」預覽：用遊戲相機實際拍三把槍（左輪、散彈、槓桿步槍）的腰射、瞄準、換彈中，
# 裁掉上面的天空，拼成 3×3 存到 docs/image/hands_iter/v<版號>_遊戲.png。
# 六格對照圖（tools/model_iter.sh hands）比形狀；這張看玩家實際看到什麼（角度、大小、燈光都跟遊戲一樣）。
# 用法：先 tools/model_iter.sh cowboy <任意>（把手匯出到 models/cowboy.glb），再 tools/hands_game_iter.sh <版號>
set -e
cd "$(dirname "$0")/.."
N=${1:?版號}
OUT=docs/image/hands_iter
TMP=$(mktemp -d)
FONT="/System/Library/Fonts/Hiragino Sans GB.ttc"
godot --headless --path . --import >/dev/null 2>&1
for s in 1 2 3; do
    mkdir -p $TMP/$s
    SLOT=$s OUT=$TMP/$s godot --path . --resolution 1280x720 --script tools/viewmodel_shots.gd >/dev/null 2>&1
done
row() { magick $TMP/$1/0_hip.png $TMP/$1/1_ads.png $TMP/$1/3_reload_50.png -crop 1280x500+0+220 +repage +append miff:-; }
{ row 1; row 2; row 3; } | magick - -append -resize 1680x -gravity north -background white -splice 0x50 \
    -font "$FONT" -pointsize 30 -annotate +0+8 "第 $N 版・遊戲畫面（每排一把槍：腰射｜瞄準｜換彈中）" "$OUT/v${N}_遊戲.png"
rm -rf $TMP
echo "-> $OUT/v${N}_遊戲.png"
