#!/bin/sh
# 台灣老公寓（blender/apartment.py）的貼圖：兩塊直式招牌、白色小方磚牆。改了圖要重跑 tools/model_iter.sh apartment
set -e
cd "$(dirname "$0")/.."
F="/System/Library/Fonts/STHeiti Medium.ttc"   # 宋體（Songti.ttc）缺「國」字
mkdir -p blender/tex
sign() {   # 背景色、字色、檔名、字（直排：一個字一行）
    n=$(python3 -c "import sys; print(len(sys.argv[1]))" "$4")
    txt=$(python3 -c "import sys; print('\n'.join(sys.argv[1]))" "$4")
    h=$((n * 215 + 90))
    magick -size 220x${h} xc:"$1" -fill none -stroke "$2" -strokewidth 6 -draw "rectangle 14,14 205,$((h - 15))" -stroke none \
        -font "$F" -fill "$2" -pointsize 165 -gravity center -interline-spacing 38 -annotate +0+0 "$txt" "blender/tex/$3"
}
sign '#9a3428' '#efe2c8' apt_sign_a.png 永和公寓
sign '#2c5a44' '#efe9d6' apt_sign_b.png 國泰便利商店
# 白色小方磚：一張圖 8×8 塊、灰縫（一張 = 0.8 m 見方，貼圖座標重複）
magick -size 32x32 xc:'#7d7a72' -fill '#cfccc2' -draw "rectangle 2,2 31,31" -write mpr:t +delete -size 256x256 tile:mpr:t blender/tex/apt_tiles.png
echo "-> blender/tex/apt_sign_a.png apt_sign_b.png apt_tiles.png"
