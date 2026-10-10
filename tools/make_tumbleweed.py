"""畫風滾草的平面貼圖（billboard 用，ambience.gd）：透明底，一團亂纏的乾枝，外圈稀、中心密一點。
64×64、最近點取樣，跟像素風的麥子、葉子一樣一格一格。
   python3 tools/make_tumbleweed.py   → assets/textures/tumbleweed.png
"""
import math
import random
from PIL import Image, ImageDraw

N = 64
rnd = random.Random(20261010)
img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
C = N / 2
R = N / 2 - 2
TWIG = [(150, 116, 70), (128, 98, 58), (170, 136, 86), (108, 82, 50)]   # 乾枯的褐黃，逆光邊亮一點


def arc():
    """一根彎曲的細枝：從團裡隨便一點出發，順著一個慢慢轉的方向畫十幾步，出了圓就停"""
    a = rnd.uniform(0, math.tau)
    r = R * math.sqrt(rnd.random()) * 0.9
    x, y = C + math.cos(a) * r, C + math.sin(a) * r
    h = rnd.uniform(0, math.tau)
    bend = rnd.uniform(-0.35, 0.35)
    col = rnd.choice(TWIG) + (255,)
    for _ in range(rnd.randint(8, 18)):
        nx, ny = x + math.cos(h) * 2.2, y + math.sin(h) * 2.2
        if math.hypot(nx - C, ny - C) > R:
            break
        d.line([(x, y), (nx, ny)], fill=col, width=1)
        x, y, h = nx, ny, h + bend


for _ in range(140):
    arc()
img.save('assets/textures/tumbleweed.png')
