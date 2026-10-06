#!/bin/sh
# 一樣一張的並排圖（左參考、右我們）：照建模腳本裡 VIEWS 的框裁參考圖和預覽，存到 <名字>_iter/v<版號>_each/。
# 給審查子代理「一個物件一張」用（docs/素材流水線/程式建模迭代.md 4b）。用法：tools/model_each.sh survival 6
set -e
cd "$(dirname "$0")/.."
python3 - "$1" "$2" <<'P'
import re, subprocess, os, sys
name, n = sys.argv[1], sys.argv[2]
d = 'docs/image/%s_iter' % name
os.makedirs('%s/v%s_each' % (d, n), exist_ok=True)
for item, box in re.findall(r"'(\w+)':\s*\(\((\d+, \d+, \d+, \d+)\)", open('blender/%s.py' % name).read()):
    l, t, r, b = map(int, box.split(', '))
    g = '%dx%d+%d+%d' % (r - l + 30, b - t + 30, l - 15, t - 15)
    subprocess.run(['magick', '(', 'docs/image/%s.png' % name, '-crop', g, '+repage', ')', '(', '%s/v%s.png' % (d, n), '-crop', g, '+repage', ')',
                    '+append', '-resize', 'x600', '%s/v%s_each/%s.png' % (d, n, item)], check=True)
print('-> %s/v%s_each/' % (d, n))
P
