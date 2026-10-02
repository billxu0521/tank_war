"""畫地面的兩張灰階貼圖（跟頂點顏色相乘，所以只管明暗、不管顏色）：
  ground_detail.png  近看的紋理：碎石子、短草梗、小斑點。一張鋪 4 公尺
  ground_macro.png   遠看的深淺：一大塊一大塊的亮暗，打破整片同色。一張鋪 48 公尺
  path_dirt.png      荒地小路：踩實的乾土，有龜裂、碎石比較多，沒有草梗。一張鋪 3 公尺（terrain.gdshader）
兩張都是無縫的（左右、上下接得起來）。
   python3 tools/make_ground_tex.py
"""
import random
from PIL import Image, ImageDraw, ImageFilter

rnd = random.Random(20261001)


def tiled_blur(img, r):
    """無縫模糊：先拼成 3x3 再模糊，取中間那張，邊緣才接得起來"""
    w, h = img.size
    big = Image.new(img.mode, (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * w, j * h))
    big = big.filter(ImageFilter.GaussianBlur(r))
    return big.crop((w, h, w * 2, h * 2))


def wrap(draw, size, fn):
    """畫在邊上的東西，另一邊也畫一份（無縫）"""
    for dx in (-size, 0, size):
        for dy in (-size, 0, size):
            fn(draw, dx, dy)


def blobs(size, n, rmin, rmax, lo, hi, blur, base):
    img = Image.new('L', (size, size), base)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y, r, v = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(rmin, rmax), rnd.randint(lo, hi)
        wrap(d, size, lambda d, dx, dy: d.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=v))
    return tiled_blur(img, blur)


# 近看：底色斑駁 → 短草梗 → 碎石子
S = 512
img = blobs(S, 260, 8, 36, 205, 250, 10, 232)
d = ImageDraw.Draw(img)
for _ in range(900):   # 短草梗：細短線，偏暗
    x, y = rnd.uniform(0, S), rnd.uniform(0, S)
    ex, ey, v = x + rnd.uniform(-5, 5), y + rnd.uniform(-12, -4), rnd.randint(170, 210)
    wrap(d, S, lambda d, dx, dy: d.line([x + dx, y + dy, ex + dx, ey + dy], fill=v, width=1))
for _ in range(500):   # 碎石子：小圓點，亮暗都有，底下一點陰影
    x, y, r = rnd.uniform(0, S), rnd.uniform(0, S), rnd.uniform(1.0, 3.2)
    v = rnd.choice([rnd.randint(150, 185), rnd.randint(240, 255)])
    wrap(d, S, lambda d, dx, dy: (d.ellipse([x + dx - r, y + dy - r + 1.2, x + dx + r, y + dy + r + 1.2], fill=150),
                                  d.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=v)))
img = tiled_blur(img, 0.6)
img.convert('RGB').save('assets/textures/ground_detail.png')

# 遠看：大塊亮暗
blobs(256, 90, 10, 40, 195, 255, 14, 228).convert('RGB').save('assets/textures/ground_macro.png')

# 荒地小路（放在最後：前兩張用的亂數順序不變，重跑也一模一樣）：底色比草地平、亮 → 乾裂的縫 → 碎石子
img = blobs(S, 160, 14, 50, 215, 250, 14, 236)
d = ImageDraw.Draw(img)
for _ in range(70):   # 龜裂：一條條彎折的暗縫，走幾步轉個方向，偶爾分岔
    x, y = rnd.uniform(0, S), rnd.uniform(0, S)
    ang = rnd.uniform(0, 6.283)
    for _ in range(rnd.randint(4, 9)):
        import math
        ang += rnd.uniform(-0.9, 0.9)
        l = rnd.uniform(10, 30)
        ex, ey = x + math.cos(ang) * l, y + math.sin(ang) * l
        v, w = rnd.randint(140, 180), rnd.choice([1, 1, 2])
        wrap(d, S, lambda d, dx, dy: d.line([x + dx, y + dy, ex + dx, ey + dy], fill=v, width=w))
        x, y = ex, ey
for _ in range(900):   # 碎石子：比草地多，大小不一
    x, y, r = rnd.uniform(0, S), rnd.uniform(0, S), rnd.uniform(0.8, 4.0)
    v = rnd.choice([rnd.randint(160, 195), rnd.randint(245, 255)])
    wrap(d, S, lambda d, dx, dy: (d.ellipse([x + dx - r, y + dy - r + 1.4, x + dx + r, y + dy + r + 1.4], fill=145),
                                  d.ellipse([x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=v)))
img = tiled_blur(img, 0.7)
img.convert('RGB').save('assets/textures/path_dirt.png')
print('-> assets/textures/ground_detail.png, ground_macro.png, path_dirt.png')
