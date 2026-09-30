"""畫樹葉的平面貼圖（blender/tree.py、grove.py 的葉片卡用）：透明底，一簇葉子。
每片葉子沿中脈分左右兩半、一亮一暗（跟全場的平面折面同一種讀感），後面的葉子暗一點。
顏色是遊戲裡的固有色（sRGB），材質不再另外調色。
   python3 tools/make_leaf_card.py   → assets/textures/leaf_{maple,oak,pine,willow,yucca}.png
"""
import math
import random
from PIL import Image, ImageDraw

S = 512   # 畫大再縮小，邊緣才不會鋸齒太重
OUT = 256
rnd = random.Random(20261002)
# 楓葉：橘、黃橘、紅橘（grove.py 的 MAPLE 換成 sRGB 再亮一點：貼圖留白多，整簇讀起來會比實心葉團暗）
MAPLE = [(228, 132, 34), (236, 172, 52), (214, 90, 30)]
# 參考圖 tree_list.png 的色票，比照楓樹的亮度
OAK = [(118, 132, 52), (130, 142, 58), (106, 120, 46)]        # 橄欖綠，三階只差一點（差太多遠看是雜訊）
PINE = [(80, 96, 46), (96, 110, 56), (64, 78, 38)]            # 偏黃的橄欖深綠松針
WILLOW = [(150, 160, 58), (170, 172, 70), (126, 140, 48)]     # 黃綠柳葉
YUCCA = [(128, 140, 50), (150, 158, 62), (104, 116, 40)]      # 約書亞樹的尖葉


def maple_leaf(cx, cy, size, rot):
    """一片楓葉的外形：五個尖裂片（上、左右上、左右下），外緣用極座標取樣，回傳點列（中心在 cx, cy）"""
    lobes = [(0, 1.0), (-62, 0.95), (62, 0.95), (-125, 0.7), (125, 0.7)]   # (方位角, 長度)，0 度朝上：寬胖的掌形
    pts = []
    n = 80
    for i in range(n):
        a = -180 + 360 * i / n
        r = 0.5   # 裂口凹到葉長一半：五個尖還看得出來，但葉子是寬胖的
        for la, ll in lobes:
            d = abs((a - la + 180) % 360 - 180)
            r = max(r, ll * (1 - d / 48))   # 每個裂片是一個寬底的尖
        t = math.radians(a + rot)
        pts.append((cx + math.sin(t) * r * size, cy - math.cos(t) * r * size))
    return pts


def blade_leaf(cx, cy, size, rot, width):
    """一片從葉柄 (cx, cy) 往 rot 方向長 size 的葉子，width(t) 是長度 t（0~1）處的半寬（對 size 的比例）"""
    t0 = math.radians(rot)
    ux, uy = math.sin(t0), -math.cos(t0)
    nx, ny = -uy, ux
    n = 24
    left = [(cx + ux * size * t + nx * size * width(t), cy + uy * size * t + ny * size * width(t)) for t in (i / n for i in range(n + 1))]
    right = [(cx + ux * size * t - nx * size * width(t), cy + uy * size * t - ny * size * width(t)) for t in (i / n for i in range(n, -1, -1))]
    return left + right


def half(pts, cx, cy, rot, side):
    """沿中脈（方向 rot）切一半：把另一邊的點壓到中脈上"""
    t = math.radians(rot)
    ux, uy = math.sin(t), -math.cos(t)          # 中脈方向
    nx, ny = -uy, ux                             # 中脈的法線
    out = []
    for x, y in pts:
        dx, dy = x - cx, y - cy
        s = dx * nx + dy * ny
        if s * side < 0:
            dx, dy = dx - s * nx, dy - s * ny
        out.append((cx + dx, cy + dy))
    return out


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def draw_leaf(d, pts, cx, cy, rot, col, k, contrast=1.0):
    d.polygon(pts, fill=shade(col, (1 + 0.08 * contrast) * k) + (255,))
    d.polygon(half(pts, cx, cy, rot, -1), fill=shade(col, (1 - 0.18 * contrast) * k) + (255,))   # 左半暗一階


def cluster(colors, weights, n, spread, size, shape, stem=True, seed=20261002, contrast=1.0):
    """一簇 n 片葉子：黃金角螺旋鋪滿整張（半徑 spread），每片大小 size 範圍、方向亂轉，從後排畫到前排（後排暗）。
    shape(cx, cy, size, rot) 回傳葉子外形的點列"""
    rnd.seed(seed)
    # 透明的地方底色也填葉子的顏色：縮圖、貼圖取樣都會混到邊上的透明像素，底色是黑的話每片葉子會多一圈黑邊
    img = Image.new('RGBA', (S, S), colors[0] + (0,))
    d = ImageDraw.Draw(img)
    leaves = []
    for i in range(n):
        a = i * 2.39996 + rnd.uniform(-0.3, 0.3)   # 黃金角螺旋：整張平均鋪滿，不會擠在一邊
        r = math.sqrt((i + 0.5) / n) * spread * S
        leaves.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r, rnd.uniform(*size) * S,
                       rnd.uniform(-70, 70), rnd.choices(colors, weights)[0], rnd.random()))
    for cx, cy, sz, rot, col, depth in sorted(leaves, key=lambda l: l[5]):
        k = 1 - 0.28 * contrast * (1 - depth)   # 後排暗
        draw_leaf(d, shape(cx, cy, sz, rot), cx, cy, rot, col, k, contrast)
        if stem:
            t = math.radians(rot)
            d.line([(cx, cy), (cx - math.sin(t) * sz * 0.45, cy + math.cos(t) * sz * 0.45)],
                   fill=shade(col, 0.55 * k) + (255,), width=max(2, int(sz * 0.04)))   # 葉柄
    return img.resize((OUT, OUT), Image.LANCZOS)


def maple_card():
    return cluster(MAPLE, (45, 40, 15), 6, 0.22, (0.26, 0.3), maple_leaf)   # 六片大葉：單片約樹高 1/35


def oak_card():
    """闊葉樹：十六片長橢圓、邊緣三四道圓波（橡樹葉），葉柄在中心附近"""
    def oak_leaf(cx, cy, size, rot):
        w = lambda t: 0.3 * math.sin(math.pi * t) ** 0.7 * (1 + 0.22 * math.sin(t * math.pi * 7))
        pts = blade_leaf(cx, cy, size, rot, w)
        t0 = math.radians(rot)
        return [(x - math.sin(t0) * size * 0.5, y + math.cos(t0) * size * 0.5) for x, y in pts]   # 中心對齊葉子中間
    return cluster(OAK, (50, 25, 25), 7, 0.2, (0.58, 0.68), oak_leaf, seed=11, contrast=0.7)   # 七片大葉：單片約樹高 1/40


def pine_card():
    """松樹：一片圓潤的雲狀葉簇，表面是很多撮短松針（每撮十幾根往外放射），輪廓毛毛的圓；後排暗、前排亮"""
    rnd.seed(12)
    img = Image.new('RGBA', (S, S), PINE[0] + (0,))
    d = ImageDraw.Draw(img)
    needles = []
    for t in range(40):   # 四十撮，鋪滿半徑 0.36 的圓
        ta = t * 2.39996
        tr = math.sqrt((t + 0.5) / 40) * 0.3 * S
        tx, ty = S / 2 + math.cos(ta) * tr, S / 2 + math.sin(ta) * tr
        depth = rnd.random()
        col = rnd.choices(PINE, (45, 30, 25))[0]
        for i in range(16):
            a = rnd.uniform(0, math.tau)
            L = rnd.uniform(0.06, 0.1) * S
            needles.append((tx, ty, a, L, col, depth + rnd.uniform(0, 0.05)))
    for x0, y0, a, L, col, depth in sorted(needles, key=lambda n: n[5]):
        k = 0.75 + 0.25 * depth
        d.line([(x0, y0), (x0 + math.cos(a) * L, y0 + math.sin(a) * L)], fill=shade(col, 1.05 * k) + (255,), width=5)
    return img.resize((OUT, OUT), Image.LANCZOS)


def willow_card():
    """柳條：直的長條圖（寬:高 = 1:4），中間一根細枝從上往下，兩側交錯長細長的柳葉往下斜，越往下越小"""
    rnd.seed(13)
    W, H = S, S * 2   # 寬:高 = 1:2，並排三條柳條
    img = Image.new('RGBA', (W, H), WILLOW[0] + (0,))
    d = ImageDraw.Draw(img)
    lance = lambda t: 0.16 * math.sin(math.pi * t) ** 0.8
    for x0, top, ln in ((0.22, 0.0, 0.85), (0.5, 0.0, 1.0), (0.78, 0.06, 0.78)):
        stem = [(W * x0 + math.sin(t * 2.2 + x0 * 9) * W * 0.03, (top + t * (ln - top)) * H * 0.97) for t in (i / 30 for i in range(31))]
        d.line(stem, fill=(92, 80, 40, 255), width=4)
        for i in range(20):
            t = 0.03 + 0.94 * i / 19
            x, y = stem[int(t * 30)]
            side = 1 if i % 2 else -1
            size = (0.21 - 0.09 * t) * W * rnd.uniform(0.9, 1.1)
            rot = 180 - side * rnd.uniform(28, 42)   # 往下、往兩側斜
            col = rnd.choices(WILLOW, (45, 30, 25))[0]
            draw_leaf(d, blade_leaf(x, y, size, rot, lance), x, y, rot, col, rnd.uniform(0.8, 1.0))
    return img.resize((OUT, OUT * 2), Image.LANCZOS)


def yucca_card():
    """約書亞樹：一球放射狀的尖葉（從中心往四周），中間一點暗"""
    rnd.seed(14)
    img = Image.new('RGBA', (S, S), YUCCA[0] + (0,))
    d = ImageDraw.Draw(img)
    spike = lambda t: 0.07 * (1 - t) ** 0.9 * min(1.0, t * 6 + 0.4)
    leaves = [(rnd.uniform(0, 360), rnd.uniform(0.3, 0.46) * S, rnd.choices(YUCCA, (45, 30, 25))[0], rnd.random()) for _ in range(44)]
    for rot, L, col, depth in sorted(leaves, key=lambda l: l[3]):
        draw_leaf(d, blade_leaf(S / 2, S / 2, L, rot, spike), S / 2, S / 2, rot, col, 0.7 + 0.3 * depth)
    return img.resize((OUT, OUT), Image.LANCZOS)


if __name__ == '__main__':
    for name, fn in (('maple', maple_card), ('oak', oak_card), ('pine', pine_card), ('willow', willow_card), ('yucca', yucca_card)):
        fn().save('assets/textures/leaf_%s.png' % name)
        print('-> assets/textures/leaf_%s.png' % name)
