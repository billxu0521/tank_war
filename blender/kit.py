# 場景小物件（docs/image/house.png 裡房子以外的那些）：跟農舍同一套木板、鐵件、顏色，匯出成 kits.glb。
#   Lantern         吊燈，原點在頂上的掛鉤
#   Barrel          木桶，原點在底部中央
#   Crate           木箱，原點在底部中央
#   HayBlock        方草捆，原點在底部中央（長邊沿 X）
#   Wheel           車輪，原點在輪軸中心，輪子立在 YZ 平面（軸沿 X）
#   FenceRail       一段柵欄（一根木樁＋三條橫板），長 FENCE_SEG，木樁在 -X 端；FencePost 收尾那根
#   FenceGate       圍欄門的一扇，原點在門軸底部，門板往 +X 長
#   GatePost        門柱（比柵欄木樁高、頂上有帽）
#   HitchRail       馬匹繫柱架：兩根柱子、頂樑、斜撐、繫馬橫桿、中間吊一盞燈，原點在底部中央
#   Windmill        風車塔（塔架＋機頭＋尾舵），原點在底部中央
#   WindmillRotor   風車的葉輪，原點在輪轂（遊戲裡轉它），葉面朝 -Y
#   HayShed         倉庫／圍棚：直條板、正面大門敞開、裡面堆方草捆，原點在地面中央；HayShedCol 是碰撞
#
# 跟 main.gd 共用的數字：FENCE_H、FENCE_SEG（柵欄）、WINDMILL_HUB（葉輪掛在哪）、SHED（圍棚大小）
# 背景跑：tools/model_iter.sh kit <版號>（參考圖用 docs/image/kit.png = house.png）
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline, house
from house import *   # 借用 house.py 的材質和工具（木板、瓦片、石頭、提燈……）
from house import _parts, _push   # 底線開頭的 import * 不會帶進來

house.rnd = random.Random(20261001)   # house.py 的工具用的是 house.rnd：換成這支自己的種子
rnd = house.rnd
FENCE_H, FENCE_SEG = 1.0, 2.5
WINDMILL_TOWER = 8.0
WINDMILL_HUB = (0.0, -0.9, WINDMILL_TOWER + 0.9)
SHED = (7.0, 6.0, 3.2)    # 寬 X、深 Y、牆高
HAY = [mat('k_hay%d' % i, c, 1.0) for i, c in enumerate(tones((0.26, 0.18, 0.045), 0.15))]
HAY_CORE = mat('k_hay_core', (0.16, 0.11, 0.028), 1.0)   # 草捆芯：層跟層之間的縫看進去是暗的
TWINE = mat('k_twine', (0.10, 0.07, 0.035), 1.0)
FLOOR = mat('k_floor', (0.094, 0.063, 0.040), 1.0)   # 倉庫地板：牆芯暗色再亮 25%，門口看得進去
LID = mat('k_lid', tuple(c * 0.9 for c in (0.145, 0.09, 0.048)), 0.9)   # 桶蓋：桶身的木頭暗一成


def board(size, loc, rot=(0, 0, 0), m=None):
    return box(size, loc, rot, m=m or pick(WOOD))


# ---------------- 吊燈 ----------------
def lantern_parts(x, y, z):
    """一盞吊燈，(x, y, z) 是頂上的掛鉤，整盞往下長。吊燈和繫柱架共用"""
    box((0.07, 0.07, 0.06), (x, y, z - 0.05), m=IRON)                          # 頂上的小煙囪帽（燈身寬 0.35 倍）
    cone(0.15, 0.05, 0.07, (x, y, z - 0.11), (0, 0, math.pi / 4), 4, m=IRON)   # 上層四角錐
    box((0.25, 0.25, 0.03), (x, y, z - 0.16), m=IRON)                           # 下層外張的屋簷（出簷 12%）
    bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.012, major_segments=10, minor_segments=4,
                                     location=(x, y, z), rotation=(math.pi / 2, 0, 0))
    _push(bpy.context.object, IRON)
    box((0.16, 0.16, 0.22), (x, y, z - 0.29), m=LIT)                            # 亮著的玻璃罩
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.025, 0.025, 0.26), (x + sx * 0.085, y + sy * 0.085, z - 0.29), m=IRON)
    for d in (-1, 1):                                                            # 四面的十字框條
        box((0.012, 0.17, 0.018), (x + d * 0.082, y, z - 0.29), m=IRON)
        box((0.012, 0.018, 0.22), (x + d * 0.082, y, z - 0.29), m=IRON)
        box((0.17, 0.012, 0.018), (x, y + d * 0.082, z - 0.29), m=IRON)
        box((0.018, 0.012, 0.22), (x, y + d * 0.082, z - 0.29), m=IRON)
    box((0.20, 0.20, 0.035), (x, y, z - 0.42), m=IRON)                          # 底座
    box((0.12, 0.12, 0.04), (x, y, z - 0.46), m=IRON)


def build_lantern():
    lantern_parts(0, 0, 0)
    return finish('Lantern', bevel=0.004, seg=1)


# ---------------- 木桶 ----------------
def build_barrel(name='Barrel'):
    """桶身是一圈圈往上疊的桶板（每片從頂到底一整條），中段鼓到兩端的 1.15 倍；四道鐵箍；桶口一圈凸出的桶緣"""
    r, h, n, rows = 0.30, 0.9, 14, 8
    def rad(z):
        t = (z / h) * 2 - 1
        return r * (1.0 + 0.15 * (1 - t * t))
    bm = bmesh.new()
    rings = []
    for j in range(rows + 1):
        z = h * j / rows
        rings.append([bm.verts.new((rad(z) * math.cos(k * math.tau / n), rad(z) * math.sin(k * math.tau / n), z)) for k in range(n)])
    lip = h + 0.035                                       # 桶緣高出桶蓋
    inner = [bm.verts.new((r * 0.9 * math.cos(k * math.tau / n), r * 0.9 * math.sin(k * math.tau / n), lip)) for k in range(n)]
    top_out = [bm.verts.new((r * math.cos(k * math.tau / n), r * math.sin(k * math.tau / n), lip)) for k in range(n)]
    lid = [bm.verts.new((r * 0.9 * math.cos(k * math.tau / n), r * 0.9 * math.sin(k * math.tau / n), lip - 0.02 * h)) for k in range(n)]   # 蓋子只比桶緣低 2%：深了會整片陷在陰影裡
    for k in range(n):
        k2 = (k + 1) % n
        for j in range(rows):
            f = bm.faces.new((rings[j][k], rings[j][k2], rings[j + 1][k2], rings[j + 1][k]))
            f.material_index = k % 3                     # 一片片桶板：同一片從頂到底同一個亮度
        f = bm.faces.new((rings[rows][k], rings[rows][k2], top_out[k2], top_out[k])); f.material_index = k % 3
        f = bm.faces.new((top_out[k], top_out[k2], inner[k2], inner[k])); f.material_index = k % 3
        f = bm.faces.new((inner[k], inner[k2], lid[k2], lid[k])); f.material_index = 3
    bm.faces.new(lid[::-1]).material_index = 3
    bm.faces.new([rings[0][k] for k in range(n)][::-1]).material_index = 3
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:                                   # 桶不是封閉的，自動翻面可能翻錯：蓋子一定朝上、桶底一定朝下
        if len(f.verts) == n:
            up = f.calc_center_median().z > h / 2
            if (f.normal.z < 0) == up:
                f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for m in (WOOD[0], WOOD[1], WOOD[2], LID):
        me.materials.append(m)
    _parts.append(o)
    for k in range(-2, 3):                               # 桶蓋的板縫：斜斜的，跟視角交叉
        a = 0.6
        L2 = 2 * math.sqrt(max((r * 0.9) ** 2 - (k * 0.11) ** 2, 0.01)) * 0.95
        box((0.009, L2, 0.004), (k * 0.11 * math.cos(a), k * 0.11 * math.sin(a), lip - 0.02 * h + 0.001), (0, 0, a), m=DARK)
    for f in (0.05, 0.3, 0.7, 0.95):                     # 四道鐵箍：貼著桶口桶底往內一點、30% 和 70%
        z = h * f
        cyl(rad(z) + 0.012, 0.05, (0, 0, z), (0, 0, math.pi / n), n, m=IRON)
    return finish(name, bevel=0.005, seg=1)


# ---------------- 木箱 ----------------
def build_crate(s=0.8):
    box((s - 0.06, s - 0.06, s - 0.06), (0, 0, s / 2), m=DARK)
    n = 4
    for axis in ('x', 'y'):                              # 四個側面：橫板
        for sgn in (-1, 1):
            for k in range(n):
                z = 0.06 + (k + 0.5) * (s - 0.12) / n
                if axis == 'x':
                    board((s - 0.14, 0.03, (s - 0.12) / n - 0.015), (0, sgn * (s / 2 - 0.015), z))
                else:
                    board((0.03, s - 0.14, (s - 0.12) / n - 0.015), (sgn * (s / 2 - 0.015), 0, z))
            # 外框和 X 撐
            for (u, zz, du, dz) in ((0, 0.04, s, 0.08), (0, s - 0.04, s, 0.08), (-s / 2 + 0.04, s / 2, 0.08, s), (s / 2 - 0.04, s / 2, 0.08, s)):
                if axis == 'x':
                    box((du, 0.05, dz), (u, sgn * (s / 2 + 0.005), zz), m=TRIM)
                else:
                    box((0.05, du, dz), (sgn * (s / 2 + 0.005), u, zz), m=TRIM)
            L = math.hypot(s - 0.16, s - 0.16)
            for d in (-1, 1):
                if axis == 'x':
                    box((L, 0.04, 0.07), (0, sgn * (s / 2 + 0.01), s / 2), (0, d * math.pi / 4, 0), m=TRIM)
                else:
                    box((0.04, L, 0.07), (sgn * (s / 2 + 0.01), 0, s / 2), (d * math.pi / 4, 0, 0), m=TRIM)
    for k in range(n):                                   # 蓋子
        board(((s - 0.1) / n - 0.015, s - 0.06, 0.03), (-s / 2 + 0.05 + (k + 0.5) * (s - 0.1) / n, 0, s - 0.015))
    return finish('Crate', bevel=0.006, seg=1)


# ---------------- 方草捆 ----------------
HAY_SIZE = (1.1, 0.55, 0.48)


def hay_parts(x=0.0, y=0.0, z=0.0, along_y=False):
    """一捆方草：沿長邊切成 4 段、段跟段前後錯開一點，每段疊 3 層；每層再沿長邊切成 6 條細長條
    （高低、深淺各不同，中間的條高一點＝頂面微微鼓起），段的角上岔出幾撮草。兩條麻繩嵌進去一半"""
    L, W, H = HAY_SIZE
    def put(size, loc, m, rot=(0, 0, 0)):
        if along_y:
            size = (size[1], size[0], size[2])
            loc = (loc[1], loc[0], loc[2])
            rot = (rot[1], rot[0], rot[2])
        box(size, (x + loc[0], y + loc[1], z + loc[2]), rot, m=m)
    strips = 6
    put((L - 0.04, W * 0.92, H * 0.98), (0, 0, H * 0.49), HAY_CORE)
    for s in range(4):
        cx = -L / 2 + (s + 0.5) * L / 4
        dy = rnd.uniform(-0.04, 0.04) * W
        lh = H / 3
        for layer in range(3):
            for k in range(strips):
                t = (k + 0.5) / strips * 2 - 1                        # -1..1 橫跨寬度
                sw = W / strips
                bulge = 0.03 * lh * 3 * (1 - t * t)                   # 中間的條高一點
                hh = lh * (0.95 + rnd.uniform(-0.09, 0.09)) + bulge   # 每層內縮 5%：層跟層之間露出一條暗縫
                put((L / 4 - 0.012, sw * 1.02, hh), (cx, dy + t * (W / 2 - sw / 2) + rnd.uniform(-0.01, 0.01),
                    lh * layer + lh * 0.025 + hh / 2), pick(HAY))
        for cxs in (-1, 1):                                          # 段的角上岔出去的草
            for cys in (-1, 1):
                for n in range(3):
                    zz = rnd.uniform(0.05, H - 0.05)
                    put((0.07, 0.012, 0.012),
                        (cx + cxs * (L / 8 - 0.01), dy + cys * (W / 2 + 0.01), zz),
                        pick(HAY), (0, rnd.uniform(-0.6, 0.6), cys * rnd.uniform(0.3, 0.8)))
    for xx in (-L * 0.25, L * 0.25):
        put((0.05, W + 0.02, 0.012), (xx, 0, H + 0.01), TWINE)
        for sy in (-1, 1):
            put((0.05, 0.012, H), (xx, sy * (W / 2 + 0.002), H / 2), TWINE)


def build_hay():
    hay_parts()
    return finish('HayBlock', bevel=0.02, seg=1)


# ---------------- 車輪 ----------------
def build_wheel(r=0.6):
    rim = 0.08                                            # 輪框的徑向厚度、軸向寬度
    tube(r, r - rim, rim, (0, 0, 0), (0, math.pi / 2, 0), 24, m=pick(WOOD))          # 24 段連成一圈的木框
    tube(r + rim * 0.3, r, rim + 0.01, (0, 0, 0), (0, math.pi / 2, 0), 24, m=IRON)    # 外面一圈連續的鐵輪圈
    for k in range(12):                                   # 輪輻
        a = k * math.tau / 12
        box((0.063, 0.063, r - 0.12), (0, (r / 2) * math.cos(a), (r / 2) * math.sin(a)), (a - math.pi / 2, 0, 0), m=pick(WOOD))
    cyl(0.12, rim + 2 * 1.5 * rim, (0, 0, 0), (0, math.pi / 2, 0), 12, m=pick(WOOD))  # 輪轂：往兩側凸出
    cyl(0.065, rim + 3.4 * rim, (0, 0, 0), (0, math.pi / 2, 0), 10, m=IRON)
    return finish('Wheel', bevel=0.006, seg=1)


# ---------------- 柵欄 ----------------
RAIL_H = 0.13
POST_W = RAIL_H * 1.6


def fence_post(x, top, s=POST_W):
    """木樁：頂端四邊削角成小斜頂（高 = 柱寬 0.3 倍）"""
    box((s, s, top), (x, 0, top / 2), m=POST)
    cone(s * 0.72, s * 0.2, s * 0.3, (x, 0, top + s * 0.15), (0, 0, math.pi / 4), 4, m=POST)


def build_fence():
    rails = (0.3, 0.6, 0.9)
    top = rails[-1] + RAIL_H / 2 + POST_W * 1.2         # 高出最上面那條橫板柱寬的 1.2 倍
    fence_post(-FENCE_SEG / 2, top)
    for z in rails:                                      # 三條橫板，釘在木樁正面（不穿過柱心）
        box((FENCE_SEG + 0.02, 0.04, RAIL_H), (0, POST_W / 2 + 0.02, z), (rnd.uniform(-0.01, 0.01), 0, 0), m=pick(WOOD))
        for xx in (-FENCE_SEG / 2, FENCE_SEG / 2):
            box((0.02, 0.02, 0.02), (xx, POST_W / 2 + 0.045, z), m=IRON)
    rail = finish('FenceRail', bevel=0.008, seg=1)
    fence_post(0.0, top)
    post = finish('FencePost', bevel=0.008, seg=1)
    return [rail, post]


def build_gate(w=2.4, h=1.15):
    # 一扇門：兩根直框、三條橫板、一條斜撐、兩片鉸鏈。原點在門軸底部
    for x in (0.06, w - 0.06):
        box((0.1, 0.07, h), (x, 0, 0.1 + h / 2), m=POST)
    for z in (0.25, 0.7, 1.15):
        board((w - 0.1, 0.05, 0.14), (w / 2, 0.02, z))
    L = math.hypot(w - 0.2, 0.9)
    box((L, 0.05, 0.12), (w / 2, 0.05, 0.7), (0, -math.atan2(0.9, w - 0.2), 0), m=TRIM)
    for z in (0.25, 1.15):
        box((0.35, 0.02, 0.05), (0.17, -0.045, z), m=IRON)
    gate = finish('FenceGate', bevel=0.008, seg=1)
    fence_post(0.0, 1.6, 0.22)                           # 門柱：比柵欄木樁高、粗
    gp = finish('GatePost', bevel=0.008, seg=1)
    return [gate, gp]


# ---------------- 馬匹繫柱架 ----------------
def build_hitch(w=3.2, h=2.5):
    for sx in (-1, 1):
        box((0.18, 0.18, h), (sx * w / 2, 0, h / 2), m=POST)
        box((0.9, 0.12, 0.12), (sx * (w / 2 - 0.3), 0, h - 0.35), (0, sx * 0.785, 0), m=POST)   # 斜撐
        box((0.28, 0.28, 0.1), (sx * w / 2, 0, 0.05), m=TRIM)
    box((w + 0.6, 0.2, 0.2), (0, 0, h + 0.1), m=POST)                    # 頂樑，兩頭伸出去
    box((w, 0.1, 0.1), (0, 0, 1.0), m=pick(WOOD))                         # 繫馬橫桿
    box((0.03, 0.03, 0.3), (0, 0, h - 0.15), m=IRON)                       # 吊燈的鉤子
    lantern_parts(0, 0, h - 0.3)
    return finish('HitchRail', bevel=0.008, seg=1)


# ---------------- 風車塔 ----------------
def strut(p, q, t, m):
    p, q = Vector(p), Vector(q)
    d = q - p
    rot = d.to_track_quat('Z', 'Y').to_euler()
    box((t, t, d.length), tuple((p + q) / 2), tuple(rot), m=m)


def build_windmill():
    H = WINDMILL_TOWER
    b0, b1 = 1.3, 0.3                                    # 塔腳半寬：底下張開、頂上收攏
    def leg_at(z):
        return b0 + (b1 - b0) * z / H
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sy in corners:                               # 四根塔腳
        strut((sx * b0, sy * b0, 0), (sx * b1, sy * b1, H), 0.12, pick(WOOD))
        box((0.3, 0.3, 0.3), (sx * b0, sy * b0, 0.1), m=pick(STONE))    # 石墩
    levels = [0.4, 2.3, 4.2, 5.9, 7.3]
    for i, z in enumerate(levels):                       # 一圈圈橫撐＋每面的交叉斜撐
        r = leg_at(z)
        for k in range(4):
            a, b = corners[k], corners[(k + 1) % 4]
            strut((a[0] * r, a[1] * r, z), (b[0] * r, b[1] * r, z), 0.07, pick(WOOD))
            if i + 1 < len(levels):
                z2 = levels[i + 1]
                r2 = leg_at(z2)
                strut((a[0] * r, a[1] * r, z), (b[0] * r2, b[1] * r2, z2), 0.05, TRIM)
                strut((b[0] * r, b[1] * r, z), (a[0] * r2, a[1] * r2, z2), 0.05, TRIM)
    box((0.9, 0.9, 0.08), (0, 0, H), m=pick(WOOD))                     # 頂上的小平台
    box((0.45, 0.7, 0.4), (0, -0.2, H + 0.4), m=IRON)                    # 機頭
    cyl(0.07, 0.5, (0, -0.55, H + 0.9), (math.pi / 2, 0, 0), 8, m=IRON)  # 輪軸
    cyl(0.05, 1.0, (0, 0, H + 0.5), (0, 0, 0), 8, m=IRON)                # 立軸
    strut((0, 0.1, H + 0.6), (0, 1.5, H + 0.75), 0.07, IRON)             # 尾舵的桿子
    box((0.04, 0.85, 0.56), (0, 1.8, H + 0.8), m=pick(WOOD))             # 尾舵（面積約上一版一半）
    box((0.05, 0.92, 0.05), (0, 1.8, H + 1.08), m=TRIM)
    box((0.05, 0.92, 0.05), (0, 1.8, H + 0.52), m=TRIM)
    for k in range(int(H / 0.4)):                        # 一側的爬梯橫檔（只是外觀）
        z = 0.5 + k * 0.4
        r = leg_at(z)
        box((0.5, 0.04, 0.04), (0, -r - 0.02, z), m=pick(WOOD))
    tower = finish('Windmill', bevel=0.006, seg=1)
    # 葉輪：18 片斜斜的葉片夾在內外兩圈之間，原點在輪轂
    n = 18
    for k in range(n):
        a = k * math.tau / n
        o = box((0.02, 0.34, 1.05), (0, 0, 0), (0, 0, 0), m=pick(WOOD))
        # 葉片沿長軸扭一點角度，推到離輪轂 0.85，再繞輪轂（原點）轉到自己的位置
        twist, place = Matrix.Rotation(0.5, 3, 'Z'), Matrix.Rotation(a, 3, 'Y')
        for v in o.data.vertices:
            v.co = place @ (twist @ v.co + Vector((0, 0, 0.98)))
    for rr in (0.5, 1.5):
        bpy.ops.mesh.primitive_torus_add(major_radius=rr, minor_radius=0.03, major_segments=24, minor_segments=4,
                                         location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
        _push(bpy.context.object, IRON)
    cyl(0.14, 0.2, (0, 0, 0), (math.pi / 2, 0, 0), 10, m=IRON)
    for k in range(6):                                   # 輻條
        a = k * math.tau / 6
        strut((0, 0, 0), (math.sin(a) * 1.5, 0, math.cos(a) * 1.5), 0.03, IRON)
    rotor = finish('WindmillRotor', bevel=0.004, seg=1)
    return [tower, rotor]


# ---------------- 倉庫／圍棚 ----------------
def build_shed():
    W, D, H = SHED
    door = (0.0, 3.0, 0.0, 2.6)
    front = [door]
    side = [(0.0, 0.7, 1.4, 2.1)]
    wall('x', -D / 2 + T / 2, -W / 2, W / 2, H, T, front, INNER)
    wall('x', D / 2 - T / 2, -W / 2, W / 2, H, T, [], INNER)
    for sx in (-1, 1):
        wall('y', sx * (W / 2 - T / 2), -D / 2 + T, D / 2 - T, H, T, side, INNER)
    walls = [('x', -D / 2, -1, -W / 2, W / 2, front), ('x', D / 2, 1, -W / 2, W / 2, [])] + \
            [('y', sx * W / 2, sx, -D / 2, D / 2, side) for sx in (-1, 1)]
    for axis, at, out, a0, a1, ops in walls:
        backer(axis, at, out, a0, a1, 0.0, H, ops, DARK)
        clad(axis, at, out, a0, a1, 0.0, H, ops, 'batten')
        for (c, w, b, t) in ops:
            casing(axis, at, out, c, w, b, t, sill=b > 0.1)
    rise = W / 2 * math.tan(0.62)
    for sd in (-1, 1):                                   # 山牆朝前後
        prism_y(0, sd * (D / 2 - T / 2), W, H, rise, T, DARK)
        prism_y(0, sd * (D / 2 + 0.005), W, H, rise, 0.01, DARK)
        clad('x', sd * D / 2, sd, -W / 2, W / 2, H, H + rise, [(0.0, 0.5, H + 0.6, H + 1.1)], 'batten', gable=(0.0, W / 2, H, rise))
        casing('x', sd * D / 2, sd, 0.0, 0.5, H + 0.6, H + 1.1, sill=False)
    gable_roof(H, rise, -W / 2, W / 2, -D / 2, D / 2, along='y', eave=0.45, end=0.45)
    for sx in (-1, 1):                                   # 轉角板
        for sy in (-1, 1):
            box((0.2, 0.2, H), (sx * (W / 2 + 0.05), sy * (D / 2 + 0.05), H / 2), m=TRIM)
    # 兩扇大門往外敞開：直板＋上下橫檔＋Z 撐
    for sx in (-1, 1):
        hx = sx * door[1] / 2
        dw = door[1] / 2
        cx, cy = hx + sx * 0.08, -D / 2 - dw / 2 - 0.08
        for k in range(5):
            board((0.04, dw / 5 - 0.012, door[3]), (cx, -D / 2 - 0.08 - (k + 0.5) * dw / 5, door[3] / 2))
        for z in (0.4, door[3] - 0.4):
            box((0.05, dw, 0.14), (cx + sx * 0.04, cy, z), m=TRIM)
        box((0.05, math.hypot(dw, door[3] - 0.8), 0.12), (cx + sx * 0.04, cy, door[3] / 2),
            (sx * math.atan2(dw, door[3] - 0.8), 0, 0), m=TRIM)
    # 屋脊上的通風小屋
    box((0.8, 0.8, 0.6), (0, 0, H + rise + 0.2), m=pick(WOOD))
    gable_roof(H + rise + 0.5, 0.35, -0.5, 0.5, -0.5, 0.5, along='y', eave=0.12, end=0.1, col=False, main=False, thick=0.08)
    # 裡面：地板（比牆芯亮一點，門口看得進去）、疊起來的方草捆（擋子彈的掩體）。正對大門那疊從門口就看得到
    box((W - 2 * T, D - 2 * T, 0.03), (0, 0, 0.015), m=FLOOR)
    L, Wd, Hh = HAY_SIZE
    # 門口那疊：門框往內約深度 15%、偏右半邊（左半邊留走道；從左前方看進來，左邊那扇門會擋住左半邊），
    # 底下 2 捆、上面疊到高過門的一半
    fy = -D / 2 + D * 0.15 + Wd / 2
    for (x, y, z, along_y) in ((1.15, fy, 0, False), (0.05, fy, 0, False), (0.6, fy, 1, False), (0.6, fy, 2, False),
                               (-2.3, 1.8, 0, False), (-1.2, 1.8, 0, False), (2.4, 1.2, 0, True), (2.4, 1.2, 1, True), (-2.5, 0.2, 0, True)):
        hay_parts(x, y, z * Hh, along_y)
        COL.append(((Wd, L, Hh) if along_y else (L, Wd, Hh), (x, y, Hh / 2 + z * Hh), (0, 0, 0)))
    shed = finish('HayShed', bevel=0.01, seg=1)
    col = make_col('HayShedCol')
    return [shed, col]


# ---------------- 預覽：兩排，小東西放大（只放大預覽，匯出是實際大小） ----------------
def preview(obs, path):
    sc = bpy.context.scene
    yaw, elev = math.radians(-38), math.radians(22)
    fwd = Vector((-math.sin(yaw) * math.cos(elev), math.cos(yaw) * math.cos(elev), -math.sin(elev)))
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd).normalized()
    by = {o.name: o for o in obs}
    rows = [
        [('FenceRail', 1.3, 0), ('FenceGate', 1.3, 0), ('HitchRail', 1.0, 0), ('Windmill', 0.5, 0), ('HayShed', 0.55, 0)],
        [('Lantern', 5.0, 0), ('Barrel', 2.6, 0), ('Crate', 2.6, 0), ('HayBlock', 2.4, 0), ('Wheel', 2.4, 1)],
    ]
    xs = [-10.0, -5.0, 0.0, 5.0, 10.0]
    for j, row in enumerate(rows):
        for i, (name, s, lean) in enumerate(row):
            parts = [by[name]] + ([by['FencePost']] if name == 'FenceRail' else []) + \
                    ([by['GatePost']] if name == 'FenceGate' else []) + ([by['WindmillRotor']] if name == 'Windmill' else [])
            base = right * xs[i] + up * (3.0 - j * 7.0) - up * 1.0
            for p in parts:
                o = p.copy()
                sc.collection.objects.link(o)
                o.scale = (s, s, s)
                loc = Vector((0, 0, 0))
                if p.name == 'FencePost':
                    loc = Vector((FENCE_SEG / 2, 0, 0))
                if p.name == 'GatePost':
                    loc = Vector((-0.12, 0, 0))
                if p.name == 'WindmillRotor':
                    loc = Vector(WINDMILL_HUB)
                if p.name == 'Wheel':
                    o.rotation_euler = (0, 0, math.pi / 2 - 0.5)
                    loc = Vector((0, 0, 0.6))
                if p.name == 'Lantern':
                    loc = Vector((0, 0, 0.45))
                o.location = base + loc * s
    for o in obs:
        o.hide_render = True
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 27
    cam.location = -fwd * 80
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
    obs = [build_lantern(), build_barrel(), build_crate(), build_hay(), build_wheel()]
    obs += build_fence() + build_gate() + [build_hitch()] + build_windmill() + build_shed()
    settle(obs)
    return obs


if __name__ == '__main__':
    pipeline.run(build_all, preview, budget={"HayShed": 20000, "*": 3000})
