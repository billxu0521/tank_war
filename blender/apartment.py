# 台灣街角老公寓兩棟（參考圖 docs/image/apartment.png，觀察記錄 docs/image/apartment_ref.md）：匯出 apartments.glb。
#   AptA  永和公寓：五樓＋頂樓樓梯間＋鋼架水塔，灰綠水泥牆、樓板紅帶，正面騎樓＋凸出鐵窗，側面電線桿和電箱
#   AptB  國泰便利商店：四樓＋頂樓加蓋，米褐牆＋白色小方磚、花磚直條，一樓便利商店玻璃店面和鐵捲門
# 實際大小（公尺），原點在人行道地坪底部中央。正面（臨街、騎樓）朝 -Y，側面朝 -X，兩面在左前方的街角相交。
# 貼圖（招牌字、白磁磚）用 tools/apartment_tex.sh 畫。背景跑：tools/model_iter.sh apartment <版號>
# 零件都寫成「貼在某一面牆上」：face 是 FRONT（-Y 面，u 往 +X）或 SIDE（-X 面，u 往 +Y），out 是離牆往外多遠
import bpy, bmesh, math, os, random, subprocess, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline
from common import wipe, mat, box, cyl, cone, finish, _parts

rnd = random.Random(20261007)
wipe()


def tones(rgb, k):
    return [tuple(max(0.0, c * (1 + d)) for c in rgb) for d in (-k, 0, k)]


def tex_mat(name, img, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(os.path.join(BASE, 'tex', img))
    m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = rough
    return m


WALL_A = [mat('ap_wall_a%d' % i, c, 0.95) for i, c in enumerate(tones((0.16, 0.18, 0.15), 0.08))]   # 灰綠水泥 #7A7B67
WALL_B = [mat('ap_wall_b%d' % i, c, 0.95) for i, c in enumerate(tones((0.29, 0.235, 0.17), 0.08))]   # 米褐水泥 #A08A6C
TRIM_A = mat('ap_trim_a', (0.22, 0.235, 0.2), 0.95)       # 角柱、窗台：比牆亮一點
TRIM_B = mat('ap_trim_b', (0.36, 0.30, 0.22), 0.95)
BAND = mat('ap_band', (0.20, 0.055, 0.04), 0.9)           # 樓板紅帶 #8B3A2C
GLASS = mat('ap_glass', (0.02, 0.03, 0.05), 0.25)
FRAME = mat('ap_frame', (0.10, 0.06, 0.035), 0.8)          # 木／鋁窗框（舊的深褐）
IRON = mat('ap_iron', (0.11, 0.055, 0.03), 0.7, 0.3)       # 鐵窗：鏽褐
GREEN = [mat('ap_awning%d' % i, c, 0.6) for i, c in enumerate([(0.06, 0.16, 0.09), (0.09, 0.21, 0.12), (0.12, 0.25, 0.16)])]
AC = mat('ap_ac', (0.36, 0.35, 0.32), 0.6)   # 舊冷氣是米灰，純白在髒牆上太跳
DARK = mat('ap_dark', (0.03, 0.03, 0.035), 0.8)
SHUTTER = mat('ap_shutter', (0.22, 0.23, 0.24), 0.5, 0.5)
SHUTTER_RIB = mat('ap_shutter_rib', (0.14, 0.15, 0.16), 0.5, 0.5)
POT = mat('ap_pot', (0.32, 0.11, 0.05), 0.9)
LEAF = [mat('ap_leaf%d' % i, c, 0.8) for i, c in enumerate([(0.04, 0.13, 0.03), (0.07, 0.19, 0.05)])]
PAVE = mat('ap_pave', (0.26, 0.25, 0.23), 0.95)
CURB = mat('ap_curb', (0.36, 0.35, 0.32), 0.95)
TANK = mat('ap_tank', (0.025, 0.025, 0.028), 0.4)
POLE = mat('ap_pole', (0.40, 0.37, 0.31), 0.9)
YELLOW = mat('ap_yellow', (0.75, 0.55, 0.02), 0.6)
CABINET = mat('ap_cabinet', (0.06, 0.18, 0.10), 0.6)
BREEZE = mat('ap_breeze', (0.24, 0.07, 0.04), 0.9)         # 花磚：紅褐
WOOD = mat('ap_door_wood', (0.16, 0.07, 0.035), 0.8)
SCOOT = mat('ap_scooter', (0.22, 0.24, 0.27), 0.4, 0.3)
TIRE = mat('ap_tire', (0.02, 0.02, 0.02), 0.9)
CRATE = mat('ap_crate', (0.05, 0.25, 0.22), 0.6)           # 塑膠籃
TILE = tex_mat('ap_tiles', 'apt_tiles.png')
SIGN_A = tex_mat('ap_sign_a', 'apt_sign_a.png', 0.6)
SIGN_B = tex_mat('ap_sign_b', 'apt_sign_b.png', 0.6)

FRONT, SIDE, BACK, RIGHT = 'front', 'side', 'back', 'right'   # -Y、-X、+Y、+X 四面
GRIME_B = [mat('ap_grime_b%d' % i, c, 1.0) for i, c in enumerate([(0.22, 0.16, 0.10), (0.17, 0.12, 0.08), (0.30, 0.24, 0.16)])]   # 米褐牆用褐色系
GRIME = [mat('ap_grime%d' % i, c, 1.0) for i, c in enumerate([(0.13, 0.13, 0.10), (0.10, 0.10, 0.08), (0.24, 0.22, 0.17)])]   # 貼近牆色：太黑會像迷彩（v2）


def grime(face, u0, u1, z0, z1, n, plane=0.0, ms=None):
    """髒污：牆上一塊塊深淺不一的薄片（雨水從窗台往下流的直條、斑塊），參考圖的手繪斑駁用幾何做"""
    for _ in range(n):
        w = rnd.uniform(0.12, 0.5)          # 細長的流痕為主（雨水從窗台、樓板往下流）
        h = rnd.uniform(0.8, 2.6) if rnd.random() < 0.75 else rnd.uniform(0.2, 0.5)
        fbox(face, rnd.uniform(u0 + w / 2, u1 - w / 2), 0.004 + rnd.random() * 0.004, rnd.uniform(z0 + h / 2, z1 - h / 2), w, 0.006, h,
             rnd.choice(ms or GRIME), plane=plane)


# ---------------- 貼在牆上的座標 ----------------
def P(face, u, out, z, plane=0.0):
    """牆面座標 → 世界座標。plane：這面牆在哪（FRONT 的 y、SIDE 的 x）"""
    return {FRONT: (u, plane - out, z), SIDE: (plane - out, u, z), BACK: (u, plane + out, z), RIGHT: (plane + out, u, z)}[face]


def fbox(face, u, out, z, su, d, sz, m, tilt=0.0, plane=0.0):
    """牆上的方塊：沿牆 su、離牆 d、高 sz，中心在 (u, out, z)。tilt > 0：外緣往下斜（雨遮）"""
    size = (su, d, sz) if face in (FRONT, BACK) else (d, su, sz)
    rot = {FRONT: (tilt, 0, 0), SIDE: (0, -tilt, 0), BACK: (-tilt, 0, 0), RIGHT: (0, tilt, 0)}[face]   # 外緣往下
    return box(size, P(face, u, out, z, plane), rot, m=m)


def axis_rot(face):
    """圓柱的軸朝牆外"""
    return (math.pi / 2, 0, 0) if face in (FRONT, BACK) else (0, math.pi / 2, 0)


def quad_uv(face, u0, u1, z0, z1, out, m, rep=0.8, plane=0.0):
    """貼在牆上的一片有貼圖座標的面（白磁磚）：貼圖每 rep 公尺重複一次"""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')
    vs = [bm.verts.new(P(face, u, out, z, plane)) for u, z in ((u0, z0), (u1, z0), (u1, z1), (u0, z1))]
    f = bm.faces.new(vs if face == FRONT else list(reversed(vs)))
    for l in f.loops:
        co = l.vert.co
        uu = co.x if face == FRONT else co.y
        l[uv].uv = (uu / rep, co.z / rep)
    bm.normal_update()
    me = bpy.data.meshes.new('quad')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('quad', me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m)
    _parts.append(o)
    return o


# ---------------- 零件 ----------------
def corrugated(face, u, out, z, w, d, tilt=0.3, plane=0.0, rib=0.16, edge=True):
    """綠色浪板雨遮：一條條浪（高低交錯的細條）＋前緣一條收邊。z 是靠牆那一邊的高度"""
    n = max(2, int(w / rib))
    zc = z - math.sin(tilt) * d / 2
    oc = out + math.cos(tilt) * d / 2
    g = rnd.choice(GREEN)
    for i in range(n):
        uu = u - w / 2 + (i + 0.5) * w / n
        fbox(face, uu, oc, zc + (0.025 if i % 2 else 0.0), w / n * 1.02, d, 0.025, GREEN[(i // 3) % 3] if rnd.random() < 0.3 else g, tilt, plane)
    if edge:
        fbox(face, u, out + math.cos(tilt) * d, z - math.sin(tilt) * d - 0.03, w + 0.04, 0.05, 0.08, IRON, 0, plane)


def window(face, u, z, w, h, plane=0.0, awning=True, trim=TRIM_A, cross=True):
    """窗：玻璃、外框、中間直料＋上段橫料、窗台；上面一片小雨遮。z 是窗的下緣"""
    fbox(face, u, 0.01, z + h / 2, w, 0.04, h, GLASS, plane=plane)
    t = 0.06
    for dz in (0, h):
        fbox(face, u, 0.035, z + dz, w + t, 0.06, t, FRAME, plane=plane)
    for du in (-w / 2, w / 2):
        fbox(face, u + du, 0.035, z + h / 2, t, 0.06, h, FRAME, plane=plane)
    if cross:
        fbox(face, u, 0.03, z + h / 2, 0.04, 0.05, h, FRAME, plane=plane)
        fbox(face, u, 0.03, z + h * 0.7, w, 0.05, 0.04, FRAME, plane=plane)
    fbox(face, u, 0.07, z - 0.05, w + 0.2, 0.14, 0.07, trim, plane=plane)
    if awning:
        corrugated(face, u, 0.0, z + h + 0.32, w + 0.35, 0.55, 0.45, plane, rib=0.12, edge=False)


def cage(face, u, z, w, h, d=0.55, plane=0.0, pots=True):
    """凸出的鐵窗：底下放盆栽的鐵架＋三角托架、前面和兩側的鐵條格子、頂上浪板雨遮；後面是窗"""
    window(face, u, z + 0.3, w - 0.3, h - 0.6, plane, awning=False)
    fbox(face, u, d / 2, z, w, d, 0.05, IRON, plane=plane)                       # 底板（盆栽架）
    fbox(face, u, d, z + 0.06, w, 0.03, 0.12, IRON, plane=plane)                 # 底板前緣的擋條
    for k in range(int(w / 1.2) + 1):                                            # 三角托架
        uu = u - w / 2 + 0.1 + k * (w - 0.2) / max(1, int(w / 1.2))
        fbox(face, uu, d * 0.5, z - 0.25, 0.04, 0.04, d * 1.1, IRON, -0.9, plane)
        fbox(face, uu, d * 0.5, z - 0.03, 0.04, d, 0.04, IRON, plane=plane)
    n = int(w / 0.15)
    for i in range(n + 1):                                                       # 前面直條
        fbox(face, u - w / 2 + i * w / n, d, z + h / 2, 0.022, 0.022, h, IRON, plane=plane)
    for k in range(1, int(h / 0.4) + 1):                                         # 前面和兩側橫條
        zz = z + k * h / int(h / 0.4)
        fbox(face, u, d, zz, w, 0.03, 0.03, IRON, plane=plane)
        for su in (-1, 1):
            fbox(face, u + su * w / 2, d / 2, zz, 0.03, d, 0.03, IRON, plane=plane)
    for su in (-1, 1):                                                           # 兩側直條
        for j in range(1, 4):
            fbox(face, u + su * w / 2, d * j / 4, z + h / 2, 0.022, 0.022, h, IRON, plane=plane)
    if pots:
        for i in range(int(w / 0.45)):
            if rnd.random() < 0.8:
                plant(P(face, u - w / 2 + 0.25 + i * 0.45 + rnd.uniform(-0.05, 0.05), d * 0.55, z + 0.025, plane), rnd.uniform(0.55, 0.8))
    corrugated(face, u, d * 0.2, z + h + 0.12, w + 0.3, d + 0.35, 0.3, plane)


def ac_unit(face, u, z, plane=0.0):
    """冷氣室外機：機身、風扇（深色圓＋十字格柵＋中心）、底下兩支托架"""
    fbox(face, u, 0.2, z, 0.82, 0.3, 0.56, AC, plane=plane)
    c = P(face, u - 0.12, 0.36, z, plane)
    cyl(0.2, 0.02, c, axis_rot(face), 16, m=DARK)
    c2 = P(face, u - 0.12, 0.372, z, plane)
    cyl(0.05, 0.02, c2, axis_rot(face), 8, m=AC)
    fbox(face, u - 0.12, 0.372, z, 0.42, 0.012, 0.025, AC, plane=plane)
    fbox(face, u - 0.12, 0.372, z, 0.025, 0.012, 0.42, AC, plane=plane)
    for du in (-0.3, 0.3):
        fbox(face, u + du, 0.2, z - 0.31, 0.04, 0.4, 0.05, IRON, plane=plane)


def shutter(face, u, z, w, h, plane=0.0, out=0.0):
    """鐵捲門：門板（橫向肋條）＋上方捲箱＋兩側導軌"""
    fbox(face, u, out + 0.02, z + h / 2, w, 0.04, h, SHUTTER, plane=plane)
    for k in range(int(h / 0.12)):
        fbox(face, u, out + 0.045, z + 0.06 + k * 0.12, w, 0.015, 0.03, SHUTTER_RIB, plane=plane)
    fbox(face, u, out + 0.15, z + h + 0.18, w + 0.1, 0.3, 0.36, SHUTTER, plane=plane)
    for du in (-w / 2, w / 2):
        fbox(face, u + du, out + 0.05, z + h / 2, 0.08, 0.1, h, SHUTTER_RIB, plane=plane)


def door(face, u, z, w, h, m=WOOD, plane=0.0, out=0.0):
    fbox(face, u, out + 0.03, z + h / 2, w, 0.05, h, m, plane=plane)
    for du in (-w / 2, w / 2):
        fbox(face, u + du, out + 0.06, z + h / 2, 0.07, 0.07, h + 0.05, FRAME, plane=plane)
    fbox(face, u, out + 0.06, z + h, w + 0.14, 0.07, 0.07, FRAME, plane=plane)
    fbox(face, u + w * 0.35, out + 0.08, z + 1.0, 0.04, 0.04, 0.15, AC, plane=plane)   # 門把


def plant(at, s=1.0):
    """盆栽：陶盆（上寬下窄）＋六片往外翻的長葉"""
    x, y, z = at
    cone(0.10 * s, 0.13 * s, 0.22 * s, (x, y, z + 0.11 * s), v=8, m=POT)
    for k in range(6):
        a = k * math.pi / 3 + rnd.uniform(-0.3, 0.3)
        lean = rnd.uniform(0.3, 0.7)
        L = rnd.uniform(0.35, 0.55) * s
        box((0.05 * s, 0.012, L), (x + math.cos(a) * math.sin(lean) * L * 0.45, y + math.sin(a) * math.sin(lean) * L * 0.45,
                                    z + 0.2 * s + math.cos(lean) * L * 0.45), (0, lean, a), m=LEAF[k % 2])


def column(x, y, z0, z1, w=0.5, m=None):
    box((w, w, z1 - z0), (x, y, (z0 + z1) / 2), m=m or rnd.choice(WALL_A))


def parapet(x0, x1, y0, y1, z, h, m, t=0.2):
    """女兒牆：四邊，頂上壓一條比牆寬一點的壓頂"""
    for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0 + t / 2, x1 - x0, t), ((x0 + x1) / 2, y1 - t / 2, x1 - x0, t),
                             (x0 + t / 2, (y0 + y1) / 2, t, y1 - y0 - 2 * t), (x1 - t / 2, (y0 + y1) / 2, t, y1 - y0 - 2 * t)):   # 側邊兩頭縮一個牆厚：角落重疊的共面在光追下是黑條（v1、v2）
        box((sx, sy, h), (cx, cy, z + h / 2), m=m)
        box((sx + 0.3 * (sx > t) + 0.3 * (sx <= t), sy + 0.3 * (sy > t) + 0.3 * (sy <= t) - 0.002, 0.15), (cx - 0.15 * (sx <= t) * (1 if cx < (x0 + x1) / 2 else -1) * 0, cy, z + h + 0.075 + 0.002 * (sx <= t)), m=TRIM_A if m in WALL_A else TRIM_B)   # 厚壓頂、出簷 0.15


def water_tower(x, y, z):
    """頂樓鋼架水塔：四支角鋼腳＋斜撐＋平台、黑色圓桶（兩道箍、圓錐頂蓋、蓋子）"""
    s, H = 0.85, 2.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.08, 0.08, H), (x + sx * s, y + sy * s, z + H / 2), m=IRON)
    for k in (0.5, 1.6):
        for sx in (-1, 1):
            box((0.05, 2 * s, 0.05), (x + sx * s, y, z + k), m=IRON)
            box((2 * s, 0.05, 0.05), (x, y + sx * s, z + k), m=IRON)
    for sx in (-1, 1):   # 斜撐
        box((0.04, 2.2 * s, 0.04), (x + sx * s, y, z + H * 0.5), (math.radians(35), 0, 0), m=IRON)
        box((2.2 * s, 0.04, 0.04), (x, y + sx * s, z + H * 0.5), (0, math.radians(35), 0), m=IRON)
    box((2 * s + 0.2, 2 * s + 0.2, 0.08), (x, y, z + H), m=IRON)
    for sx in (-1, 1):   # 平台欄杆
        box((2 * s + 0.2, 0.04, 0.04), (x, y + sx * (s + 0.1), z + H + 0.5), m=IRON)
        box((0.04, 2 * s + 0.2, 0.04), (x + sx * (s + 0.1), y, z + H + 0.5), m=IRON)
        for sy in (-1, 1):
            box((0.04, 0.04, 0.5), (x + sx * (s + 0.1), y + sy * (s + 0.1), z + H + 0.25), m=IRON)
    cyl(0.85, 2.0, (x, y, z + H + 1.04), v=16, m=TANK)
    for k in (0.3, 1.0, 1.7):
        cyl(0.87, 0.07, (x, y, z + H + 0.04 + k), v=16, m=TANK)
    cone(0.87, 0.5, 0.12, (x, y, z + H + 2.1), v=16, m=TANK)   # 桶頂幾乎是平的（尖頂像穀倉，v5）
    cyl(0.22, 0.1, (x, y, z + H + 2.21), v=10, m=TANK)


def roof_room(x0, x1, y0, y1, z, h, walls, windows, eave=None):
    """頂樓加蓋（樓梯間）：牆、屋頂板（出簷）、兩扇小窗"""
    box((x1 - x0, y1 - y0, h), ((x0 + x1) / 2, (y0 + y1) / 2, z + h / 2), m=rnd.choice(walls))
    box((x1 - x0 + 0.3, y1 - y0 + 0.3, 0.18), ((x0 + x1) / 2, (y0 + y1) / 2, z + h + 0.09), m=eave or rnd.choice(walls))
    for face, u, plane in windows:
        window(face, u, z + 1.2, 0.6, 0.7, plane, awning=False, cross=False)


def scooter(x, y, z, yaw):
    """機車：前後輪、車身（腳踏板、後座殼）、前擋、龍頭、座墊、後照鏡。建在原點再轉到位。
    finish() 會把 _parts 全部合併：先把大樓的零件收起來，機車合併完再放回去"""
    saved = _parts[:]
    _parts.clear()
    for dx in (-0.6, 0.6):
        cyl(0.24, 0.12, (dx, 0, 0.24), (math.pi / 2, 0, 0), 12, m=TIRE)
        cyl(0.13, 0.13, (dx, 0, 0.24), (math.pi / 2, 0, 0), 8, m=SHUTTER)
    box((0.7, 0.32, 0.12), (0.0, 0, 0.3), m=SCOOT)                      # 腳踏板
    box((0.6, 0.38, 0.4), (-0.45, 0, 0.55), (0, math.radians(-8), 0), m=SCOOT)   # 後座殼
    box((0.62, 0.32, 0.1), (-0.42, 0, 0.8), m=TIRE)                     # 座墊
    box((0.16, 0.36, 0.75), (0.48, 0, 0.62), (0, math.radians(18), 0), m=SCOOT)   # 前擋
    box((0.1, 0.12, 0.35), (0.62, 0, 1.0), (0, math.radians(18), 0), m=SCOOT)     # 龍頭柱
    box((0.06, 0.65, 0.06), (0.66, 0, 1.17), m=TIRE)                    # 把手
    box((0.18, 0.2, 0.12), (0.7, 0, 0.42), m=SCOOT)                     # 前土除
    for sy in (-1, 1):
        box((0.02, 0.02, 0.2), (0.66, sy * 0.25, 1.27), m=TIRE)
        box((0.03, 0.09, 0.06), (0.66, sy * 0.27, 1.38), m=TIRE)
    o = finish('tmp_scooter', bevel=0.0, seg=1)
    o.modifiers.clear()
    o.data.transform(o.matrix_world)   # 合併後的物件帶著第一個零件（輪子）的旋轉：先烤進網格，不然整台車翻倒（v1~v5）
    o.matrix_world = Matrix()
    o.rotation_euler = (0, 0, yaw)
    o.location = (x, y, z)
    _parts.extend(saved)
    _parts.append(o)
    return o


def utility_pole(x, y):
    """水泥電線桿：往上收細的桿身、底部黃黑警示、兩支橫擔＋礙子、變壓器、電線往 -X 拉出去"""
    cone(0.17, 0.11, 10.0, (x, y, 5.0), v=10, m=POLE)
    for k in range(6):   # 黃黑相間（斜紋的近似）
        cyl(0.18, 0.2, (x, y, 0.1 + k * 0.2), v=10, m=YELLOW if k % 2 == 0 else TIRE)
    for zc, L in ((9.2, 1.6), (8.2, 1.3)):
        box((0.1, L, 0.12), (x, y, zc), m=POLE)
        for d in (-L / 2 + 0.1, 0, L / 2 - 0.1):
            cyl(0.04, 0.14, (x, y + d, zc + 0.12), v=6, m=AC)
    cyl(0.24, 0.65, (x + 0.32, y, 7.0), v=10, m=SHUTTER)                  # 變壓器
    box((0.25, 0.1, 0.5), (x + 0.15, y, 7.0), m=IRON)
    box((0.3, 0.6, 0.08), (x, y, 5.6), m=POLE)                            # 腳踏釘
    for zc in (9.25, 8.25):
        for d in (-0.7, 0.6):
            # 電線：往 -X 拉出畫面，中間往下垂（第一段往外往下、第二段往上）
            box((3.2, 0.015, 0.015), (x - 1.6, y + d * 0.9, zc - 0.14), (0, math.radians(-5), 0), m=TIRE)
            box((3.2, 0.015, 0.015), (x - 4.8, y + d * 0.9, zc - 0.14), (0, math.radians(5), 0), m=TIRE)
    # 進戶線：橫擔拉到側牆三樓
    box((1.2, 0.015, 0.015), (x + 0.6, y - 0.6, 8.0), (0, math.radians(30), 0), m=TIRE)


def cabinet(x, y):
    """綠色電箱：箱體、往後斜的頂蓋、兩扇門的縫和把手、水泥底座"""
    box((0.75, 1.45, 0.15), (x, y, 0.075), m=CURB)
    box((0.6, 1.3, 1.5), (x, y, 0.9), m=CABINET)
    box((0.72, 1.42, 0.08), (x - 0.03, y, 1.68), (0, math.radians(-6), 0), m=CABINET)
    box((0.02, 0.02, 1.35), (x - 0.31, y, 0.9), m=DARK)
    for sy in (-1, 1):
        box((0.02, 0.025, 0.2), (x - 0.31, y + sy * 0.1, 0.9), m=AC)


def base(x0, x1, y0, y1):
    """人行道地坪：一塊水泥板＋前緣路緣石"""
    box((x1 - x0, y1 - y0, 0.15), ((x0 + x1) / 2, (y0 + y1) / 2, 0.075), m=PAVE)
    box((x1 - x0, 0.25, 0.2), ((x0 + x1) / 2, y0 + 0.125, 0.1), m=CURB)
    box((0.25, y1 - y0, 0.2), (x0 + 0.125, (y0 + y1) / 2, 0.1), m=CURB)


def bands(x0, x1, y0, y1, zs, m=BAND, faces=(FRONT, SIDE)):
    """每層樓板的位置一條紅帶，繞正面和側面"""
    for z in zs:
        if FRONT in faces:
            box((x1 - x0 + 0.1, 0.1, 0.28), ((x0 + x1) / 2, y0 - 0.03, z), m=m)
        if SIDE in faces:
            box((0.1, y1 - y0 + 0.1, 0.28), (x0 - 0.03, (y0 + y1) / 2, z), m=m)


# ---------------- A：永和公寓 ----------------
def build_a():
    W, D, G, F, N = 7.6, 9.0, 3.4, 3.1, 4          # 正面寬、側面深、一樓高、每層高、一樓以上幾層
    top = G + F * N
    AR = 2.2                                        # 騎樓深
    base(-2.0, W + 0.4, -1.2, D + 0.3)
    z0 = 0.15
    walls = WALL_A
    TD = 6.2                                        # 五樓往後退：只蓋到這麼深，後面是四樓頂的平台（參考圖）
    box((W, D, F * (N - 1)), (W / 2, D / 2, z0 + G + F * (N - 1) / 2), m=walls[1])   # 二到四樓的量體（懸在騎樓上）
    box((W, TD, F), (W / 2, TD / 2, z0 + G + F * (N - 0.5)), m=walls[1])            # 五樓
    box((W - 0.2, D - AR, G), (W / 2 + 0.1, AR + (D - AR) / 2, z0 + G / 2), m=walls[0])   # 一樓往內退
    box((0.3, AR, G), (0.15, AR / 2, z0 + G / 2), m=walls[2])                    # 一樓側面靠街角那一段牆
    for x in (0.22, 3.5, W - 0.22):                                             # 騎樓柱三根；凸出牆面 6 cm（跟側牆共面會變黑條，v5）
        column(x, 0.22, z0, z0 + G, w=0.56)
    corrugated(FRONT, W / 2 + 0.5, 0.0, z0 + G - 0.05, W + 0.8, 0.9, 0.25)     # 騎樓口的大雨遮
    for x in (0.22, 3.5, W - 0.22):                                             # 雨遮的斜撐
        box((0.05, 1.0, 0.05), (x, -0.4, z0 + G - 0.45), (0.75, 0, 0), m=IRON)
    box((W - 0.4, 0.2, 0.35), (W / 2, 0.1, z0 + G - 0.2), m=TRIM_A)            # 騎樓樑
    # 角柱：正面兩角、側面後角，凸出牆面
    for (x, y, zb, h) in ((0.0, 0.0, 0, F * N), (W, 0.0, 0, F * N), (0.0, D, 0, F * (N - 1)), (0.0, TD, F * (N - 1), F)):   # zb：從幾樓開始
        box((0.45, 0.45, h + 0.3), (x + (0.17 if x == 0 else -0.17), y + (0.17 if y < 1 else -0.17), z0 + G + zb + h / 2), m=TRIM_A)
    bands(-0.02, W, -0.02, D, [z0 + G + k * F for k in range(N - 1)])
    bands(-0.02, W, -0.02, TD, [z0 + G + (N - 1) * F])
    parapet(0, W, 0, TD, z0 + top, 0.9, walls[1])
    z4 = z0 + G + F * (N - 1)                                                   # 四樓頂平台的女兒牆（三邊：前面靠著五樓的後牆）
    for (cx, cy, sx, sy) in ((W / 2, D - 0.1, W, 0.2), (0.1, (TD + D) / 2, 0.2, D - TD - 0.2), (W - 0.1, (TD + D) / 2, 0.2, D - TD - 0.2)):
        box((sx, sy, 0.9), (cx, cy, z4 + 0.45), m=walls[1])
        box((sx + 0.3, sy + 0.3 - 0.002, 0.15), (cx, cy, z4 + 0.975 + 0.002 * (sx < 1)), m=TRIM_A)
    # 正面樓上：左段一般窗＋冷氣，右段凸出鐵窗
    for k in range(N):
        zf = z0 + G + k * F
        window(FRONT, 1.15, zf + 0.9, 1.2, 1.5)
        ac_unit(FRONT, 2.45, zf + 2.55 if k % 2 else zf + 0.55)   # 窗右邊：窗台高或窗頂高，不壓窗也不壓紅帶
        cage(FRONT, 5.05, zf + 0.75, 3.9, 2.0)   # 右邊收到 7.0，角柱留給招牌
    # 騎樓裡：鐵捲門、門、盆栽、機車
    shutter(FRONT, 4.2, z0, 2.4, 2.7, plane=AR)
    door(FRONT, 6.4, z0, 1.0, 2.2, plane=AR)
    door(FRONT, 1.6, z0, 1.0, 2.2, m=DARK, plane=AR)
    for x in (1.0, 2.2):
        plant((x, 0.6, z0), 1.5)
    scooter(5.9, 0.6, z0, math.radians(165))
    # 側面：每層三扇窗（有的加鐵窗）、小氣窗、冷氣
    for k in range(N):
        zf = z0 + G + k * F
        window(SIDE, 1.7, zf + 0.9, 1.1, 1.4)
        if k in (1, 2):
            cage(SIDE, 4.4, zf + 0.75, 1.6, 1.8, 0.4, pots=False)
        else:
            window(SIDE, 4.4, zf + 0.9, 1.1, 1.4)
        if k < N - 1:
            window(SIDE, 7.2, zf + 0.9, 1.1, 1.4)
        window(SIDE, 5.8, zf + 1.6, 0.45, 0.45, awning=False, cross=False)
        ac_unit(SIDE, 6.5 if k % 2 else 3.0, zf + 0.6)
    for u in (3.5, 6.0, 8.0):                                                   # 一樓氣窗
        window(SIDE, u, z0 + 2.1, 0.7, 0.4, awning=False, cross=False)
    grime(FRONT, 0.4, W - 0.4, z0 + G, z0 + top, 40)
    grime(SIDE, 0.4, TD - 0.4, z0 + 0.3, z0 + top, 30)
    grime(SIDE, TD, D - 0.4, z0 + 0.3, z4, 15)
    # 頂樓：樓梯間、水塔
    roof_room(0.3, 3.3, 2.8, 5.8, z0 + top, 3.1, walls, [(FRONT, 1.8, 2.8), (SIDE, 4.3, 0.3)])
    water_tower(4.6, 2.6, z0 + top)
    # 直式招牌：在正面右邊，從牆往外伸（字面朝 -X，從街角看得到）
    sx, sy, sz = W - 0.15, -1.0, z0 + G + F * 1.9   # 鎖在角柱上：鐵臂從角柱伸出來
    box((0.16, 1.1, 3.8), (sx, sy, sz), m=IRON)
    quad_uv(SIDE, sy - 0.51, sy + 0.51, sz - 1.85, sz + 1.85, 0.0, SIGN_A, rep=1.0, plane=sx - 0.09)
    _uv_fit(_parts[-1], sy - 0.51, sy + 0.51, sz - 1.85, sz + 1.85)
    for dz in (-1.4, 1.4):
        box((0.06, 0.5, 0.06), (sx, -0.25, sz + dz), m=IRON)
    # 街道：電線桿、電箱
    back_faces(W, D, z0, G, F, N, depth=lambda k: TD if k == N - 1 else D)
    utility_pole(-1.0, 5.2)
    cabinet(-0.9, 2.6)
    return finish('AptA', bevel=0.0, seg=1)


def _uv_fit(o, u0, u1, z0, z1):
    """招牌：貼圖剛好貼滿一塊（不重複）"""
    me = o.data
    uv = me.uv_layers.active
    for li, l in enumerate(me.loops):
        co = me.vertices[l.vertex_index].co
        uv.data[li].uv = ((u1 - co.y) / (u1 - u0), (co.z - z0) / (z1 - z0))   # 從 -X 看，+Y 在左邊


# ---------------- B：國泰便利商店 ----------------
def build_b():
    W, D, G, F, N = 10.0, 7.2, 4.3, 3.1, 3   # 一樓 4.3：鐵捲門、雨遮上面還有一排氣窗帶
    top = G + F * N
    base(-0.8, W + 0.4, -1.5, D + 0.3)
    z0 = 0.15
    walls = WALL_B
    RS = 6.7                                    # 正面右段（往內退）從這裡開始
    box((RS, D, top), (RS / 2, D / 2, z0 + top / 2), m=walls[1])
    box((W - RS, D - 0.8, top), ((RS + W) / 2, 0.8 + (D - 0.8) / 2, z0 + top / 2), m=walls[0])
    for (x, y, h) in ((0.0, 0.0, top + 0.3), (1.4, 0.0, top), (6.2, 0.0, top), (W, 0.8, top), (0.0, D, top)):   # 角柱、分段柱
        box((0.55, 0.5, h), (x + (0.2 if x == 0 else (-0.2 if x == W else 0.0)), y + (0.17 if y < 1 else -0.2), z0 + h / 2), m=TRIM_B)
    parapet(0, RS, 0, D, z0 + top, 0.6, walls[1])
    parapet(RS, W, 0.8, D, z0 + top, 0.6, walls[0])
    # 花磚直條（正面，靠街角那根柱子旁邊，二樓到頂）：鏤空格子＋每格一個小菱形
    x0, x1, zb, zt = 0.42, 1.18, z0 + G, z0 + top
    box((x1 - x0, 0.1, zt - zb), ((x0 + x1) / 2, 0.08, (zb + zt) / 2), m=DARK)
    c = 0.19
    nu, nz = int((x1 - x0) / c), int((zt - zb) / c)
    for i in range(nu + 1):
        box((0.04, 0.12, zt - zb), (x0 + i * (x1 - x0) / nu, 0.02, (zb + zt) / 2), m=BREEZE)
    for j in range(nz + 1):
        box((x1 - x0, 0.12, 0.04), ((x0 + x1) / 2, 0.02, zb + j * (zt - zb) / nz), m=BREEZE)
    for i in range(nu):
        for j in range(nz):
            box((0.07, 0.1, 0.07), (x0 + (i + 0.5) * (x1 - x0) / nu, 0.02, zb + (j + 0.5) * (zt - zb) / nz), (0, math.pi / 4, 0), m=BREEZE)
    # 正面左段：白磁磚＋三層凸出鐵窗
    for k in range(N):
        zf = z0 + G + k * F
        quad_uv(FRONT, 1.7, 5.9, zf + 0.05 - (0.9 if k == 0 else 0), zf + F - 0.05, 0.015, TILE)   # 一樓那層往下貼到雨遮
        cage(FRONT, 3.8, zf + 0.75, 3.8, 2.0)
    # 正面右段（往內退 0.8）：一般窗＋小陽台欄杆、冷氣
    for k in range(N):
        zf = z0 + G + k * F
        window(FRONT, 8.4, zf + 0.85, 2.4, 1.5, plane=0.8, trim=TRIM_B)
        box((3.2, 0.7, 0.1), (8.35, 0.45, zf + 0.6), m=TRIM_B)               # 小陽台板
        for i in range(12):
            box((0.025, 0.025, 0.85), (6.85 + i * 0.27, 0.12, zf + 1.05), m=IRON)
        box((3.2, 0.04, 0.05), (8.35, 0.12, zf + 1.5), m=IRON)
        if k == 0:
            ac_unit(FRONT, 9.3, zf + 0.2, plane=0.8)
    # 一樓正面：花磚下的木門、便利商店玻璃店面＋門、右邊鐵捲門、雨遮
    door(FRONT, 0.8, z0, 0.75, 2.3)
    box((4.2, 0.1, 0.5), (3.85, 0.05, z0 + 3.05), m=DARK)                        # 店招位置（深色橫條）
    for i, u in enumerate((2.3, 3.4, 4.5, 5.55)):
        if i == 2:
            door(FRONT, u, z0, 1.0, 2.4, m=GLASS)
        else:
            fbox(FRONT, u, 0.02, z0 + 1.45, 1.0, 0.04, 2.5, GLASS)
            fbox(FRONT, u, 0.05, z0 + 0.25, 1.05, 0.08, 0.5, TRIM_B)
        fbox(FRONT, u + 0.53, 0.05, z0 + 1.4, 0.07, 0.08, 2.8, FRAME)
    fbox(FRONT, 3.85, 0.05, z0 + 2.75, 4.2, 0.08, 0.08, FRAME)
    shutter(FRONT, 8.35, z0, 2.6, 2.8, plane=0.8)
    corrugated(FRONT, 3.4, 0.0, z0 + 3.3, 5.6, 1.2, 0.28)   # 蓋到花磚下的木門
    corrugated(FRONT, 8.35, 0.0, z0 + 3.3, 3.5, 1.4, 0.25, plane=0.8)
    # 側面：二、三樓白磁磚＋凸出鐵窗，頂樓窗＋冷氣，一樓兩扇鐵捲門＋長雨遮
    for k in range(N):
        zf = z0 + G + k * F
        if k < 2:
            quad_uv(SIDE, 0.8, 6.6, zf + 0.05, zf + F - 0.05, 0.015, TILE)
            cage(SIDE, 3.6, zf + 0.75, 6.2, 2.0)
        else:
            window(SIDE, 2.0, zf + 0.9, 1.2, 1.4, trim=TRIM_B)
            window(SIDE, 4.2, zf + 0.9, 1.6, 1.4, trim=TRIM_B)
            window(SIDE, 3.1, zf + 1.6, 0.45, 0.45, awning=False, cross=False, trim=TRIM_B)
            ac_unit(SIDE, 2.0, zf + 0.35)
    for u in (2.0, 5.0):
        shutter(SIDE, u, z0, 2.6, 2.7)
    corrugated(SIDE, 3.6, 0.0, z0 + 3.3, 6.4, 1.3, 0.25)
    # 一樓上方的氣窗帶（側面、正面右段）：一長條深色玻璃，上下框
    for face, u, w, plane in ((SIDE, 3.6, 6.4, 0.0), (FRONT, 8.35, 3.0, 0.8)):
        fbox(face, u, 0.01, z0 + 3.8, w, 0.04, 0.55, GLASS, plane=plane)
        for dz in (-0.3, 0.3):
            fbox(face, u, 0.04, z0 + 3.8 + dz, w + 0.1, 0.07, 0.06, FRAME, plane=plane)
    # 花磚下木門上方的小花磚氣窗
    for i in range(4):
        for j in range(3):
            box((0.16, 0.08, 0.16), (0.52 + i * 0.19, 0.03, z0 + 2.55 + j * 0.17), (0, math.pi / 4, 0), m=BREEZE)
    bands(-0.02, RS, -0.02, D, [z0 + G + k * F for k in range(N)], m=TRIM_B)
    grime(FRONT, 1.3, RS - 0.3, z0 + G, z0 + top, 45, ms=GRIME_B)   # 右段往內退，不在這個平面上
    grime(SIDE, 0.3, D - 0.3, z0 + 0.3, z0 + top, 60, ms=GRIME_B)
    # 頂樓：樓梯間、水塔、右後方加蓋（綠屋簷）
    roof_room(0.4, 2.9, 1.6, 5.0, z0 + top, 2.0, walls, [])
    roof_room(5.2, 6.6, 3.4, 4.8, z0 + top, 2.9, walls, [], eave=GREEN[1])   # 水塔後面窄高的小加蓋
    water_tower(3.9, 2.4, z0 + top)
    roof_room(6.8, 9.6, 2.6, 6.6, z0 + top, 2.4, walls, [], eave=GREEN[1])
    # 直式招牌：正面右邊往外伸
    sx, sy, sz = W - 0.3, -0.7, z0 + G + 1.6
    box((0.16, 0.9, 4.2), (sx, sy, sz), m=IRON)
    quad_uv(SIDE, sy - 0.42, sy + 0.42, sz - 2.05, sz + 2.05, 0.0, SIGN_B, rep=1.0, plane=sx - 0.09)
    _uv_fit(_parts[-1], sy - 0.42, sy + 0.42, sz - 2.05, sz + 2.05)
    for dz in (-1.5, 1.5):
        box((0.06, 1.3, 0.06), (sx, 0.0, sz + dz), m=IRON)
    back_faces(W, D, z0, G, F, N)
    # 一樓前：機車、盆栽、塑膠籃、水泥磚
    scooter(-0.8, 2.3, z0, math.radians(80))   # 側面鐵捲門前：停在木門前面人進不去
    for x in (2.6, 3.1, 5.9):
        plant((x, -0.4, z0), 1.2)
    for i in range(2):
        box((0.45, 0.35, 0.3), (5.1 + i * 0.47, -0.3, z0 + 0.15), m=CRATE)
    for i, (x, zz) in enumerate(((1.25, 0), (1.55, 0), (1.4, 0.2))):
        box((0.35, 0.18, 0.2), (x, -0.25, z0 + 0.1 + zz), m=CURB)
    return finish('AptB', bevel=0.0, seg=1)


def back_faces(W, D, z0, G, F, floors, walls_rear=None, depth=None):
    """背面和右側面：每層兩三扇窗＋一台冷氣（參考圖只畫兩面，但放進遊戲四面都看得到；整片空白牆不像有人住，v7 繞一圈才看到）"""
    for k in range(floors):
        zf = z0 + G + k * F
        dd = depth(k) if depth else D
        for u in (1.3, W / 2, W - 1.3):
            window(BACK, u, zf + 0.9, 1.0, 1.3, plane=dd)
        ac_unit(BACK, W / 2 + 1.1, zf + 0.5, plane=dd)
        for u in (1.5, dd - 1.5):
            window(RIGHT, u, zf + 0.9, 1.0, 1.3, plane=W)


def build_all():
    obs = [build_a(), build_b()]
    for o in obs:   # 原點放到地坪底部中央
        vs = [v.co for v in o.data.vertices]
        lo = Vector([min(v[i] for v in vs) for i in range(3)])
        hi = Vector([max(v[i] for v in vs) for i in range(3)])
        o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
        o.location = (0, 0, 0)
    return obs


# ---------------- 預覽 ----------------
# 每棟：參考圖裡的框（左、上、右、下 像素）、相機方向（從物件往眼睛）
VIEWS = {
    'AptA': ((40, 10, 720, 985), (-0.85, -1.0, 0.3)),
    'AptB': ((770, 110, 1530, 945), (-0.72, -1.0, 0.25)),
}


def preview(obs, path):
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.lens = 45   # 32 太廣角：底部變寬、往上收太多（v4）
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(10)
    sun.data.color = (1.0, 0.9, 0.78)   # 暖白
    sun.rotation_euler = (math.radians(50), 0, math.radians(-15))   # 偏正面：正面亮、側面暗三四成（參考圖）
    sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (1, 0.97, 0.92, 1)
    bg.inputs['Strength'].default_value = 0.3   # 環境光弱一點：背光面要暗，對比才出來（參考圖）
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
    sc.render.film_transparent = True
    tmp = path + '.parts'
    os.makedirs(tmp, exist_ok=True)
    args = ['magick', '-size', '1536x1024', 'xc:none']
    for o in obs:
        box_, eye = VIEWS[o.name]
        for p in obs:
            p.hide_render = p is not o
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        c = sum(pts, Vector()) / 8
        R = max((p - c).length for p in pts)
        d = R / math.sin(math.atan(18 / 45)) * 1.0
        cam.location = c + Vector(eye).normalized() * d
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x = sc.render.resolution_y = 1100
        f = os.path.join(tmp, o.name + '.png')
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        w, h = box_[2] - box_[0], box_[3] - box_[1]
        subprocess.run(['magick', f, '-trim', '+repage', '-resize', '%dx%d' % (w, h), f], check=True)
        args += ['(', f, ')', '-gravity', 'center', '-geometry', '+%d+%d' % ((box_[0] + box_[2]) / 2 - 768, (box_[1] + box_[3]) / 2 - 512),
                 '-composite']
    subprocess.run(args + [path], check=True)
    print('preview ->', path)


def export_baked(obs, out):
    """程式材質（apartment_mats.py）→ 每棟烘焙成一張 4096 的顏色貼圖 → 匯出。預覽跟著用烘焙後的材質，看到的就是遊戲拿到的"""
    import apartment_mats
    apartment_mats.upgrade()
    for o in obs:
        apartment_mats.bake(o, os.path.join(os.path.dirname(os.path.abspath(out)), 'apartment_%s.png' % o.name[-1].lower()))
    pipeline.export(obs, out)


pipeline.run(build_all, preview, budget={'*': 120000}, export_fn=export_baked)
