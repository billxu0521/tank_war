"""畫麥子的平面貼圖（billboard 用）：透明底，一叢五到七根麥稈，頂上一顆麥穗、中間幾片葉子。
顏色照鎖定的色盤（docs/程式建模迭代.md）：麥稈偏黃綠、穗尖亮一點，根部暗。
   python3 tools/make_wheat_card.py   → assets/textures/wheat_card.png
"""
import math
import random
from PIL import Image, ImageDraw

W, H = 128, 256
rnd = random.Random(20261001)
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

STEM = [(118, 104, 44), (132, 118, 50), (104, 92, 38)]   # sRGB，跟 p_wheat (0.22, 0.20, 0.035) 同一個色相
EAR = [(170, 146, 64), (186, 160, 72), (156, 132, 56)]
ROOT = (70, 60, 28)


def stalk(x0, top, lean):
    """一根麥稈：從底往上微彎，頂上一顆穗（一節一節的橢圓），中間一兩片往外翹的葉子"""
    pts = []
    for i in range(21):
        t = i / 20
        y = H - 2 - t * (H - 2 - top)
        x = x0 + lean * t * t * 18
        pts.append((x, y))
    col = rnd.choice(STEM)
    for a, b in zip(pts, pts[1:]):
        c = tuple(int(ROOT[k] + (col[k] - ROOT[k]) * min(1, (H - a[1]) / 90)) for k in range(3))
        d.line([a, b], fill=c + (255,), width=3)
    for _ in range(rnd.randint(1, 2)):                         # 葉子
        k = rnd.randint(6, 13)
        x, y = pts[k]
        side = rnd.choice((-1, 1))
        d.polygon([(x - side * 2, y + 2), (x + side * 18, y - 28 - rnd.randint(0, 10)), (x + side * 7, y - 12)], fill=col + (255,))
    ex, ey = pts[-1]                                            # 麥穗：六節，一節一節往上縮
    ear = rnd.choice(EAR)
    for s in range(6):
        cy = ey - s * 6
        r = 5 - s * 0.45
        dx = lean * s * 0.8
        d.ellipse([ex + dx - r, cy - 5, ex + dx + r, cy + 3], fill=ear + (255,))
        d.line([(ex + dx, cy - 4), (ex + dx + lean * 2 + (s - 3) * 0.6, cy - 12)], fill=ear + (255,), width=1)   # 麥芒


n = 7
for i in range(n):
    x = 18 + i * (W - 36) / (n - 1) + rnd.uniform(-5, 5)
    top = rnd.uniform(46, 110)
    stalk(x, top, rnd.uniform(-1, 1))
img.save('assets/textures/wheat_card.png')
print('-> assets/textures/wheat_card.png')
