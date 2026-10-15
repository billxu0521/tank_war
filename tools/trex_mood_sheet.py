"""把 tools/trex_mood_shots.gd 拍的照片拼成一張對照圖：每列一種狀態，四欄是側面 20 公尺、40 公尺、40 公尺剪影、正面 30 公尺剪影（都是原尺寸裁中間）。
剪影＝跟背景色不一樣的像素塗黑，看輪廓認不認得出狀態。
  python3 tools/trex_mood_sheet.py /tmp/mood out.png "標題"
"""
import sys
from PIL import Image, ImageDraw, ImageFont

BG = (33, 38, 46)   # trex_mood_shots.gd 的背景色 (0.13, 0.15, 0.18)
STATES = [("roam", "逛"), ("search", "找"), ("hunt", "追"), ("retreat", "退開")]
W, H = 640, 360
LABEL = 90
TOP = 50

src, out = sys.argv[1], sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else ""
font = ImageFont.truetype("/System/Library/Fonts/STHeiti Medium.ttc", 30)


def center(im):   # 原尺寸裁中間：兩欄比例一樣，看得出遠近實際差多少
    w, h = im.size
    return im.crop(((w - W) // 2, (h - H) // 2, (w + W) // 2, (h + H) // 2))


def silhouette(im):
    px = im.convert("RGB").load()
    s = Image.new("L", im.size, 255)
    sp = s.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b = px[x, y]
            if abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 12:
                sp[x, y] = 0
    return s.convert("RGB")


sheet = Image.new("RGB", (LABEL + W * 4, TOP + H * len(STATES)), "white")
d = ImageDraw.Draw(sheet)
d.text((10, 8), title, fill="black", font=font)
for c, head in enumerate(["側面 20 公尺", "40 公尺", "40 公尺剪影", "正面 30 公尺剪影"]):
    d.text((LABEL + c * W + 10, 8), head, fill="gray", font=font)
for r, (key, name) in enumerate(STATES):
    y = TOP + r * H
    near = center(Image.open(f"{src}/{key}_20.png"))
    far = center(Image.open(f"{src}/{key}_40.png"))
    sheet.paste(near, (LABEL, y))
    sheet.paste(far, (LABEL + W, y))
    sheet.paste(silhouette(far), (LABEL + W * 2, y))
    sheet.paste(silhouette(center(Image.open(f"{src}/{key}_front.png"))), (LABEL + W * 3, y))
    d.text((12, y + H // 2 - 18), name, fill="black", font=font)
sheet.save(out)
