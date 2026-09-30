# 城鎮店面（西部小鎮主街）：跟農舍同一套木板、瓦片、石頭、顏色，匯出成 towns.glb。
#   Saloon      酒館：兩層高、中間再往上凸一階的假門面、二樓陽台（柱子撐著、有欄杆）、雙開大門、大窗
#   Store       雜貨店：高高的方形假門面、門口木板人行道和遮陽棚、兩扇大展示窗
#   Sheriff     警長辦公室：矮一點、石頭牆腳、窗戶有鐵條
#   WaterTower  水塔：四根木腳、一片片木板箍成的水桶、尖頂、爬梯
# 每樣匯出外觀和 <名字>Col（碰撞：牆、門窗洞、地板、屋頂、假門面、人行道、陽台、大件家具）。
# 正面朝 -Y（遊戲裡 +Z），跟農舍一樣；遊戲裡照街道轉向。
# 背景跑：tools/model_iter.sh town <版號>（參考圖 docs/image/house.png 的做工）
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline, house
from house import *   # 借用 house.py 的材質和工具（木板、瓦片、石頭、提燈……）
from house import _parts, _push   # 底線開頭的 import * 不會帶進來

house.rnd = random.Random(20261002)   # house.py 的工具用的是 house.rnd：換成這支自己的種子
rnd = house.rnd
BOARD = mat('t_board', (0.07, 0.047, 0.032), 0.95)  # 招牌底：深褐（跟屋頂一樣深）
LETTER = mat('t_letter', (0.42, 0.30, 0.17), 0.9)   # 招牌上的字：淺木色，深底淺字對比才大
STAR = mat('t_star', (0.55, 0.45, 0.28), 0.6)       # 警長的星星
GREEN = mat('t_green', (0.07, 0.09, 0.05), 0.9)     # 酒瓶
HAY_BALE = mat('k_hay0', (0.26, 0.18, 0.045), 1.0)   # 跟 kit.py 的方草捆同一個顏色


def sign(x, z, w, h, y, words=4):
    """招牌：深色底板＋8 公分寬的深色木框＋幾組淺色粗筆畫（像幾個字，讀不出來，看得出是招牌）"""
    box((w, 0.08, h), (x, y - 0.08, z), m=BOARD)
    for dz in (-1, 1):
        box((w + 0.16, 0.1, 0.08), (x, y - 0.1, z + dz * h / 2), m=TRIM)
    for dx in (-1, 1):
        box((0.08, 0.1, h + 0.16), (x + dx * w / 2, y - 0.1, z), m=TRIM)
    stroke = h / 6
    cell = (w - 0.3) / (words * 2 - 1)                  # 一個字一格，字跟字之間空一格
    for k in range(words):
        cx = x - w / 2 + 0.15 + cell * (2 * k + 0.5)
        box((stroke, 0.05, h * 0.6), (cx - cell * 0.3, y - 0.13, z), m=LETTER)
        box((cell * 0.8, 0.05, stroke), (cx, y - 0.13, z + h * rnd.choice((-0.22, 0.0, 0.22))), m=LETTER)
        if rnd.random() < 0.6:
            box((stroke, 0.05, h * 0.6), (cx + cell * 0.3, y - 0.13, z), m=LETTER)


def star(x, y, z, r=0.25):
    """五角星（警長辦公室的招牌旁）：一片薄薄的星形"""
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((x + math.cos(a) * rr, z + math.sin(a) * rr))
    front = [bm.verts.new((px, y - 0.04, pz)) for px, pz in pts]
    back = [bm.verts.new((px, y + 0.02, pz)) for px, pz in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    for i in range(10):
        j = (i + 1) % 10
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('star')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('star', me)
    bpy.context.collection.objects.link(o)
    _push(o, STAR)


def stone_band(axis, at, out, a0, a1, z1, ops):
    """一面牆的石頭牆腳（地面到 z1），門洞那段讓開。一塊一塊、每塊亮度和凸出量不同，往外凸 5 公分"""
    z = 0.0
    while z < z1 - 0.05:
        rh = min(rnd.uniform(0.22, 0.32), z1 - z)
        for s0, s1 in spans(a0, a1, cuts(ops, z, z + rh, 0.0)):
            u = s0 + rnd.uniform(-0.1, 0.0)
            while u < s1 - 0.05:
                e = min(u + rnd.uniform(0.28, 0.5), s1)
                if s1 - e < 0.12:
                    e = s1
                on_wall(axis, at, out, (max(u, s0) + e) / 2, z + rh / 2, e - max(u, s0) - 0.035, rh - 0.035, 0.14,
                        0.02 + rnd.uniform(0.0, 0.03), pick(STONE))
                u = e
        z += rh


def storefront(W, D, H, face_h, porch, style='plank', stone=0.0, step=0.0, upper=(), win_w=1.8,
               sign_w=0.62, sign_h=1.1, words=4):
    """一棟店面：空心的牆（門窗是開口）、背後人字屋頂、正面高出屋頂的假門面、門口木板人行道。
    porch：'balcony' 二樓陽台（酒館）、'awning' 整面遮陽棚（雜貨店）、'canopy' 門上一片小雨遮（警長）。
    style：外牆板 'plank' 橫板 / 'batten' 直板加壓條；stone > 0：石頭牆腳做到這個高度，上面才是木板。
    step > 0：假門面中間再往上凸一階。upper：正面二樓的窗和門（不是開口，只有外牆板要讓開、裝上框）"""
    door = (0.0, 1.8, F, F + 2.5)
    wins = [(-(W / 2 - 0.4 - win_w / 2), win_w, F + 0.6, F + 2.3), (W / 2 - 0.4 - win_w / 2, win_w, F + 0.6, F + 2.3)]
    front = [door] + wins
    back = [(0.0, 1.1, WIN[1], WIN[2])]
    side = [(-D / 4, 1.1, WIN[1], WIN[2]), (D / 4, 1.1, WIN[1], WIN[2])]
    wall('x', -D / 2 + T / 2, -W / 2, W / 2, H, T, front, INNER)
    wall('x', D / 2 - T / 2, -W / 2, W / 2, H, T, back, INNER)
    for sx in (-1, 1):
        wall('y', sx * (W / 2 - T / 2), -D / 2 + T, D / 2 - T, H, T, side, INNER)
    solid((W - 2 * T, D - 2 * T, F), (0, 0, F / 2), m=PLANK)
    zb = stone if stone > 0 else F - 0.05
    walls = [('x', -D / 2, -1, -W / 2, W / 2, front), ('x', D / 2, 1, -W / 2, W / 2, back)] + \
            [('y', sx * W / 2, sx, -D / 2, D / 2, side) for sx in (-1, 1)]
    for axis, at, out, a0, a1, ops in walls:
        backer(axis, at, out, a0, a1, zb, H, ops, DARK)
        clad(axis, at, out, a0, a1, zb, H, ops + (list(upper) if at == -D / 2 else []), style)
        for (c, w, b, t) in ops:
            casing(axis, at, out, c, w, b, t, sill=b > F + 0.01)
        if stone > 0:
            stone_band(axis, at, out, a0 - (0.07 if axis == 'x' else 0), a1 + (0.07 if axis == 'x' else 0), stone, ops)
    for sx in (-1, 1):                                   # 轉角板
        for sy in (-1, 1):
            box((0.22, 0.22, H - zb), (sx * (W / 2 + 0.06), sy * (D / 2 + 0.06), (H + zb) / 2), m=TRIM)
    if stone <= 0:
        piers([-W / 2, 0, W / 2], [-D / 2, 0, D / 2])
        for axis, at, out, a0, a1, ops in walls:
            on_wall(axis, at, out, (a0 + a1) / 2, zb / 2, a1 - a0, zb, 0.02, -0.05, DARK)
    # 屋頂：屋脊前後走，正面那頭藏在假門面後面。兩側出挑 0.35、山牆那頭 0.25
    rise = W / 2 * math.tan(0.35)
    prism_y(0, D / 2 - T / 2, W, H, rise, T, DARK)
    prism_y(0, D / 2 + 0.005, W, H, rise, 0.01, DARK)
    clad('x', D / 2, 1, -W / 2, W / 2, H, H + rise, [], style, gable=(0.0, W / 2, H, rise))
    gable_roof(H, rise, -W / 2, W / 2, -D / 2 + 0.3, D / 2, along='y', eave=0.35, end=0.25)
    # 假門面：從牆頂一路往上，比屋脊高，擋住後面的屋頂。背面也釘板，幾支斜撐撐到屋頂
    fy = -D / 2
    fw = W + 0.4
    solid((fw, 0.2, face_h - H), (0, fy + 0.1, (face_h + H) / 2), m=INNER)
    tops = [(-fw / 2, fw / 2, face_h)] + ([(-W * 0.225, W * 0.225, face_h + step)] if step > 0 else [])
    for x0, x1, top in tops:
        z0 = H if top == face_h else face_h
        backer('x', fy, -1, x0, x1, z0, top, [], DARK)
        clad('x', fy, -1, x0, x1, z0, top, [], style)
        backer('x', fy + 0.2, 1, x0, x1, z0, top, [], DARK)
        clad('x', fy + 0.2, 1, x0, x1, z0, top, [], 'plank')
        box((x1 - x0 + 0.3, 0.35, 0.18), ((x0 + x1) / 2, fy - 0.12, top + 0.05), m=TRIM)   # 頂上的簷口
    if step > 0:
        solid((W * 0.45, 0.2, step), (0, fy + 0.1, face_h + step / 2), m=INNER)
    for k in range(int(fw / 0.8) + 1):                  # 簷口下一排小托架
        box((0.1, 0.22, 0.2), (-fw / 2 + k * fw / int(fw / 0.8), fy - 0.12, face_h - 0.14), m=TRIM)
    box((fw + 0.1, 0.12, 0.12), (0, fy - 0.08, H + 0.02), m=TRIM)              # 牆頂的腰線
    for x in (-W * 0.35, 0.0, W * 0.35):               # 背後的斜撐：從假門面頂端斜到屋頂
        roof_z = H + rise * (1 - abs(x) / (W / 2))
        p0, p1 = Vector((x, fy + 0.25, face_h - 0.25)), Vector((x, fy + 2.4, roof_z + 0.12))
        d = p1 - p0
        box((0.1, 0.1, d.length), tuple((p0 + p1) / 2), tuple(d.to_track_quat('Z', 'Y').to_euler()), m=POST)
    sign(0, H + (face_h - H) * 0.5, fw * sign_w, min(sign_h, (face_h - H) * 0.6), fy, words)
    # 門口：木板人行道（跟地板一樣高）＋台階
    pd = 2.5
    deck(-W / 2 - 0.2, W / 2 + 0.2, fy - pd, fy)
    steps(0.0, fy - pd, 1.8)
    xs = [-W / 2, -W / 6, W / 6, W / 2]
    if porch == 'awning':                                # 整面遮陽棚：約 20 度，柱子撐著，往前伸 2.5 公尺
        zt = F + 3.2
        pp = 0.35
        zf = zt - (pd + 0.2) * math.tan(pp)
        for x in xs:
            post(x, fy - pd + 0.15, F, zf - 0.1, brace=[d for d in (-1, 1) if -W / 2 + 0.4 < x + d * 0.5 < W / 2 - 0.4])
        box((W + 0.5, 0.2, 0.22), (0, fy - pd + 0.15, zf - 0.06), m=POST)
        box((W, 0.14, 0.14), (0, fy - 0.08, zt - 0.1), m=POST)
        roof_slope(Vector((0, fy - pd - 0.25, zf + 0.1)), Vector((1, 0, 0)), Vector((0, math.cos(pp), math.sin(pp))),
                   W + 0.8, (pd + 0.25) / math.cos(pp) + 0.1, thick=0.12, col=False, row=0.36)
    elif porch == 'canopy':                              # 門上一片小雨遮：寬 1.6、出挑 0.8，兩支斜撐
        zc = F + 2.9
        pp = 0.3
        roof_slope(Vector((0, fy - 0.85, zc - 0.8 * math.tan(pp))), Vector((1, 0, 0)), Vector((0, math.cos(pp), math.sin(pp))),
                   1.9, 0.9 / math.cos(pp), thick=0.1, col=False, row=0.3)
        for sx in (-1, 1):
            box((0.1, 0.8, 0.1), (sx * 0.8, fy - 0.4, zc - 0.3), m=POST)
            box((0.08, 0.1, 0.9), (sx * 0.8, fy - 0.35, zc - 0.65), (0.75, 0, 0), m=POST)
    else:                                                # 二樓陽台：柱子撐著陽台地板，陽台上一圈欄杆
        zb2 = F + 3.3
        for x in xs:
            post(x, fy - pd + 0.15, F, zb2 - 0.05, brace=[d for d in (-1, 1) if -W / 2 + 0.4 < x + d * 0.5 < W / 2 - 0.4])
        solid((W + 0.4, pd, 0.2), (0, fy - pd / 2, zb2 + 0.1), m=DARK)
        y = fy - pd
        while y < fy - 0.05:
            e = min(y + 0.2, fy)
            box((W + 0.48, e - y - 0.025, 0.05), (0, (y + e) / 2, zb2 + 0.22), m=pick(WOOD))
            y = e
        box((W + 0.5, 0.1, 0.25), (0, fy - pd - 0.03, zb2 + 0.05), m=TRIM)
        rail(-W / 2 - 0.1, fy - pd + 0.1, W / 2 + 0.1, fy - pd + 0.1, zb2 + 0.2)
        for sx in (-1, 1):
            rail(sx * (W / 2 + 0.1), fy - pd + 0.15, sx * (W / 2 + 0.1), fy - 0.1, zb2 + 0.2)
        # 二樓：一扇通陽台的門、兩扇亮著的窗（外牆板在 upper 那些位置讓開了）
        for (c, w, b, t) in upper:
            if b < zb2 + 0.5:
                on_wall('x', fy, -1, c, (b + t) / 2, w, t - b, 0.05, 0.02, pick(WOOD))
                casing('x', fy, -1, c, w, b, t, sill=False)
            else:
                casing('x', fy, -1, c, w, b, t, lit=True)
    return fy, wins


def interior_saloon(W, D):
    solid((5.0, 0.7, 1.1), (-W / 2 + 3.2, D / 2 - 1.6, F + 0.55), m=POST)            # 吧台
    box((5.2, 0.9, 0.08), (-W / 2 + 3.2, D / 2 - 1.6, F + 1.14), m=TRIM)
    for k in range(3):                                                                # 後面的酒架
        box((4.6, 0.3, 0.04), (-W / 2 + 3.2, D / 2 - 0.35, F + 1.4 + k * 0.5), m=PLANK)
        for j in range(9):
            cyl(0.05, 0.3, (-W / 2 + 1.2 + j * 0.5, D / 2 - 0.35, F + 1.58 + k * 0.5), (0, 0, 0), 6,
                m=GREEN if (j + k) % 3 else LIT)
    for (x, y) in ((1.5, -1.5), (3.2, 1.0), (0.2, 1.5)):                              # 圓桌和椅子
        cyl(0.55, 0.06, (x, y, F + 0.78), (0, 0, 0), 10, m=PLANK)
        cyl(0.07, 0.75, (x, y, F + 0.38), (0, 0, 0), 6, m=POST)
        for a in range(3):
            ang = a * math.tau / 3 + 0.4
            box((0.4, 0.4, 0.05), (x + math.cos(ang) * 0.85, y + math.sin(ang) * 0.85, F + 0.46), (0, 0, ang), m=POST)
        COL.append(((1.1, 1.1, 0.8), (x, y, F + 0.4), (0, 0, 0)))
    solid((1.6, 0.6, 1.2), (W / 2 - 1.2, D / 2 - 0.6, F + 0.6), m=IRON)             # 鋼琴
    lantern((0.0, 0.0, 4.2), hook=0.3)


def interior_store(W, D):
    solid((3.5, 0.7, 1.0), (1.5, 0.5, F + 0.5), m=POST)                              # 櫃台
    for sx in (-1, 1):                                                                # 兩側牆的貨架
        for k in range(4):
            box((0.5, D - 2.0, 0.04), (sx * (W / 2 - T - 0.3), 0.4, F + 0.5 + k * 0.55), m=PLANK)
            for j in range(8):
                box((0.3, 0.3, 0.3), (sx * (W / 2 - T - 0.3), -D / 2 + 1.8 + j * (D - 2.4) / 8, F + 0.68 + k * 0.55),
                    (0, 0, rnd.uniform(-0.2, 0.2)), m=pick(WOOD) if (j + k) % 3 else CLOTH)
        COL.append(((0.6, D - 2.0, 2.4), (sx * (W / 2 - T - 0.3), 0.4, F + 1.2), (0, 0, 0)))
    for (x, y) in ((-1.5, 2.5), (-0.8, 2.8)):
        cyl(0.3, 0.9, (x, y, F + 0.45), (0, 0, 0), 10, m=pick(WOOD))
        cyl(0.31, 0.05, (x, y, F + 0.75), (0, 0, 0), 10, m=IRON)
    lantern((0.0, 0.0, 3.4), hook=0.3)


def interior_sheriff(W, D):
    solid((1.6, 0.8, 0.8), (-1.2, -0.8, F + 0.4), m=POST)                            # 辦公桌
    box((0.5, 0.5, 0.9), (-1.2, -0.1, F + 0.45), m=POST)                             # 椅子
    # 牢房：後面右邊一角，鐵條隔開（碰撞一整片，留一個門洞）
    cx0, cy0 = W / 2 - T - 2.6, D / 2 - T - 2.4
    for k in range(14):
        x = cx0 + k * 0.2
        if not (0.8 < k * 0.2 < 1.5):
            cyl(0.02, 2.4, (x, cy0, F + 1.2), (0, 0, 0), 6, m=IRON)
    for x0, x1 in ((cx0, cx0 + 0.8), (cx0 + 1.5, cx0 + 2.6)):
        COL.append(((x1 - x0, 0.1, 2.4), ((x0 + x1) / 2, cy0, F + 1.2), (0, 0, 0)))
    box((2.6, 0.06, 0.06), (cx0 + 1.3, cy0, F + 2.4), m=IRON)
    box((1.8, 0.7, 0.45), (W / 2 - T - 1.0, D / 2 - T - 0.5, F + 0.3), m=PLANK)     # 牢房裡的床
    for k in range(3):                                                                # 牆上的槍架
        box((0.05, 0.05, 1.2), (-W / 2 + T + 0.08, 1.0 + k * 0.3, F + 1.5), (0.1, 0, 0), m=POST)
    lantern((0.0, 0.0, 3.2), hook=0.3)


def barred(axis, at, out, c, w, b, t):
    """窗戶上的鐵條（只有外觀，子彈打得穿）"""
    n = 5                                                # 4 根
    for k in range(1, n):
        u = c - w / 2 + k * w / n
        on_wall(axis, at, out, u, (b + t) / 2, 0.03, t - b, 0.03, 0.02, IRON)


def build_saloon():
    W, D, H = 10.0, 12.0, 7.4
    zb2 = F + 3.3
    upper = [(0.0, 1.1, zb2 + 0.25, zb2 + 2.35), (-(W / 2 - 1.8), 1.1, zb2 + 0.9, zb2 + 2.1), (W / 2 - 1.8, 1.1, zb2 + 0.9, zb2 + 2.1)]
    storefront(W, D, H, H + 2.6, 'balcony', step=1.3, upper=upper, sign_w=0.8, sign_h=1.2, words=5)
    interior_saloon(W, D)
    return [finish('Saloon', bevel=0.012, seg=1), make_col('SaloonCol')]


def build_store():
    W, D, H = 9.0, 11.0, 4.6
    fy, wins = storefront(W, D, H, H + 2.8, 'awning', style='batten', win_w=2.2, sign_w=0.85, sign_h=0.7, words=4)
    interior_store(W, D)
    # 人行道上堆的貨：木桶 2 個、木箱 3 個、方草捆 1 個（有碰撞，是掩體）
    for x, y in ((-3.6, fy - 0.8), (-2.9, fy - 1.4)):
        barrel(x, y, F)
        COL.append(((0.6, 0.6, 0.9), (x, y, F + 0.45), (0, 0, 0)))
    for x, y, z, s in ((2.8, fy - 0.8, 0.0, 0.7), (3.6, fy - 0.9, 0.0, 0.6), (3.1, fy - 0.85, 0.7, 0.5)):
        crate(x, y, F + z, s)
        if z == 0.0:
            COL.append(((s, s, s), (x, y, F + s / 2), (0, 0, 0)))
    box((1.1, 0.55, 0.48), (-1.9, fy - 1.9, F + 0.24), (0, 0, 0.3), m=HAY_BALE)
    return [finish('Store', bevel=0.012, seg=1), make_col('StoreCol')]


def build_sheriff():
    W, D, H = 8.0, 9.6, 4.0                              # 酒館的 0.8 倍
    fy, wins = storefront(W, D, H, H + 1.6, 'canopy', stone=0.95, win_w=1.3, sign_w=0.45, sign_h=0.9, words=2)
    star(W * 0.3, fy - 0.1, H + 0.8, 0.28)              # 招牌旁一顆淺色五角星
    for (c, w, b, t) in wins:                            # 窗戶的鐵條：每扇 4 根
        barred('x', fy, -1, c, w, b, t)
    for sy in (-1, 1):
        barred('y', W / 2, 1, sy * D / 4, 1.1, WIN[1], WIN[2])
        barred('y', -W / 2, -1, sy * D / 4, 1.1, WIN[1], WIN[2])
    box((1.8, 0.4, 0.08), (2.2, fy - 0.5, F + 0.48), m=pick(WOOD))                   # 門口長凳
    for dx in (-0.8, 0.8):
        box((0.08, 0.35, 0.45), (2.2 + dx, fy - 0.5, F + 0.23), m=POST)
    interior_sheriff(W, D)
    return [finish('Sheriff', bevel=0.012, seg=1), make_col('SheriffCol')]


def build_water_tower():
    Hl, R, Ht = 7.5, 2.2, 3.0                            # 腳高、水桶半徑、水桶高
    b0, b1 = 2.1, 1.6
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    def s(z):
        return b0 + (b1 - b0) * z / Hl
    for sx, sy in corners:                               # 四根腳：底下張開一點
        p, q = Vector((sx * b0, sy * b0, 0)), Vector((sx * b1, sy * b1, Hl))
        d = q - p
        box((0.3, 0.3, d.length), tuple((p + q) / 2), tuple(d.to_track_quat('Z', 'Y').to_euler()), m=POST)
        box((0.5, 0.5, 0.3), (sx * b0, sy * b0, 0.15), m=pick(STONE))
        COL.append(((0.4, 0.4, Hl), (sx * (b0 + b1) / 2, sy * (b0 + b1) / 2, Hl / 2), (0, 0, 0)))
    for z in (2.5, 5.0):                                 # 橫撐和交叉斜撐
        r = s(z)
        for k in range(4):
            a, c = corners[k], corners[(k + 1) % 4]
            pa, pc = Vector((a[0] * r, a[1] * r, z)), Vector((c[0] * r, c[1] * r, z))
            d = pc - pa
            box((0.12, 0.12, d.length), tuple((pa + pc) / 2), tuple(d.to_track_quat('Z', 'Y').to_euler()), m=TRIM)
            r2 = s(z - 2.5)
            pa2, pc2 = Vector((a[0] * r2, a[1] * r2, z - 2.5)), Vector((c[0] * r2, c[1] * r2, z - 2.5))
            for u, v in ((pa2, pc), (pc2, pa)):
                d = v - u
                box((0.08, 0.08, d.length), tuple((u + v) / 2), tuple(d.to_track_quat('Z', 'Y').to_euler()), m=TRIM)
    box((b1 * 2 + 0.6, b1 * 2 + 0.6, 0.2), (0, 0, Hl + 0.1), m=DARK)                # 水桶底下的平台
    n = 20                                               # 水桶：一片片直板圍一圈＋三道鐵箍
    for k in range(n):
        a = k * math.tau / n
        box((2 * R * math.sin(math.pi / n) * 0.97, 0.12, Ht), (R * math.cos(a), R * math.sin(a), Hl + 0.2 + Ht / 2),
            (0, 0, a + math.pi / 2), m=WOOD[k % 3])
    for z in (0.3, 1.5, 2.7):                           # 三道鐵箍：寬 6 公分、凸出 3 公分
        cyl(R + 0.09, 0.06, (0, 0, Hl + 0.2 + z), (0, 0, math.pi / n), n, m=IRON)
    for k in range(5):                                   # 桶底的托梁：看得出底下有木架撐著
        box((R * 2.2, 0.18, 0.2), (0, -R + 0.2 + k * (2 * R - 0.4) / 4, Hl + 0.1), m=POST)
    cyl(R * 0.98, Ht, (0, 0, Hl + 0.2 + Ht / 2), (0, 0, 0), n, m=DARK)             # 桶芯（板縫看進去是暗的）
    cone(R + 0.35, 0.15, 1.3, (0, 0, Hl + 0.2 + Ht + 0.65), (0, 0, 0), 12, m=SHING[0])   # 尖頂
    COL.append(((R * 2, R * 2, Ht + 1.3), (0, 0, Hl + 0.2 + (Ht + 1.3) / 2), (0, 0, 0)))
    for k in range(int((Hl + Ht) / 0.4)):                # 爬梯
        z = 0.5 + k * 0.4
        box((0.5, 0.05, 0.05), (0, -s(min(z, Hl)) - 0.15 if z < Hl else -R - 0.15, z), m=pick(WOOD))
    for sx in (-1, 1):
        box((0.06, 0.06, Hl + Ht), (sx * 0.25, -s(Hl / 2) - 0.15, (Hl + Ht) / 2), m=POST)
    return [finish('WaterTower', bevel=0.01, seg=1), make_col('WaterTowerCol')]


def preview(obs, path):
    sc = bpy.context.scene
    yaw, elev = math.radians(-38), math.radians(22)
    fwd = Vector((-math.sin(yaw) * math.cos(elev), math.cos(yaw) * math.cos(elev), -math.sin(elev)))
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd).normalized()
    names = ['Saloon', 'Store', 'Sheriff', 'WaterTower']
    by = {o.name: o for o in obs}
    for i, n in enumerate(names):
        for j, turn in enumerate((0, math.pi)):
            o = by[n].copy()
            sc.collection.objects.link(o)
            o.rotation_euler = (0, 0, turn)
            o.location = right * ((i - 1.5) * 17.0) + up * (7.0 - j * 16.0) - up * 3.0
    for o in obs:
        o.hide_render = True
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 72
    cam.location = -fwd * 90
    cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 5.0
    sun.data.color = (1.0, 0.88, 0.70)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-40))
    sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.85, 0.82, 0.78, 1)
    bg.inputs['Strength'].default_value = 0.55
    sc.world = world
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = 'GPU'
    except TypeError:
        pass
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = 1680, 940
    sc.render.film_transparent = True
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('preview ->', path)


def build_all():
    obs = build_saloon() + build_store() + build_sheriff() + build_water_tower()
    settle(obs)
    return obs


if __name__ == '__main__':
    pipeline.run(build_all, preview, budget=20000)
