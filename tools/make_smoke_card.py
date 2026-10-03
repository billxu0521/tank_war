"""畫煙霧的平面貼圖（粒子用）：透明底上一團邊緣柔和的煙，白色（顏色由粒子自己染）。
中間濃、外圍幾個小團塊，邊緣不是正圓，粒子轉起來才不像同一顆球。
   python3 tools/make_smoke_card.py   → assets/textures/smoke_card.png
"""
import math
import random
from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 128
C = S / 2
rnd = random.Random(20261002)

# 透明度：一堆大小不一的圓疊起來（越靠中間越大越濃），再模糊
alpha = Image.new('L', (S, S), 0)
for _ in range(34):
    ang, dist = rnd.uniform(0, math.tau), rnd.uniform(0, S * 0.3)
    r = rnd.uniform(S * 0.05, S * 0.15) * (1.3 - dist / (S * 0.4))
    x, y = C + math.cos(ang) * dist, C + math.sin(ang) * dist
    blob = Image.new('L', (S, S), 0)
    ImageDraw.Draw(blob).ellipse([x - r, y - r, x + r, y + r], fill=int(rnd.uniform(10, 26) * (1.2 - dist / (S * 0.4))))
    alpha = ImageChops.add(alpha, blob)
alpha = alpha.filter(ImageFilter.GaussianBlur(S * 0.03))


def radial(f):
    """從外圈往內畫同心圓：f(0~1，1 是中心) → 灰階。四個角（圓外面）填 f(0)"""
    img = Image.new('L', (S, S), int(f(0)))
    d = ImageDraw.Draw(img)
    for i in range(S // 2, 0, -1):
        d.ellipse([C - i, C - i, C + i, C + i], fill=int(f(1 - i / C)))
    return img


# 邊緣一定要淡到 0，不然貼圖的方框會露出來
alpha = ImageChops.multiply(alpha, radial(lambda t: 255 * min(1.0, t / 0.3)))
top = max(alpha.getextrema()[1], 1)
alpha = alpha.point(lambda p: int(p * 210 / top))   # 最濃的地方 210，不是全白一片
# 顏色：中間亮、邊緣稍灰，疊起來有一點體積感。透明的地方也要是這個灰，不能是黑：
# 貼圖縮小時透明處的顏色會滲進邊緣，黑的就變一圈黑邊
rgb = radial(lambda t: 205 + 50 * t)
Image.merge('RGBA', (rgb, rgb, rgb, alpha)).save('assets/textures/smoke_card.png')
print('-> assets/textures/smoke_card.png')
