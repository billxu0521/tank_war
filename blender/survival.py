# 冰雪荒野生存物資（參考圖 docs/image/survival.png，十樣）：匯出成 survivals.glb，實際大小，原點在底部中央。
#   Campfire  營火：一圈石頭＋劈開的柴（一根高的斜靠）
#   Lantern   提燈：油壺、旋鈕、玻璃罩、裡面的銅燈芯座、護欄、上蓋、八角提把
#   Backpack  背包：帆布包身、上蓋翻下來、前面口袋、四條皮帶扣、兩條肩帶、皮標
#   SnowRock  積雪的大石頭：朝上的面積雪
#   Antler    鹿角（掉落的一支）：角座、主幹、分岔
#   Rifle     栓式步槍：槍托、槍管、機匣、槍栓拉柄、扳機護弓、槍管箍、準星
#   Axe       手斧：彎的木柄（尾端有孔）、斧頭（刃口亮）
#   StewCan   鹿肉燉罐頭：標籤貼圖 blender/tex/can_label.png
#   Mug       琺瑯杯：深藍杯緣、掉漆
#   Matchbox  火柴盒：外盒（上蓋貼圖 blender/tex/matchbox_label.png）、抽出一半的內盒、一排火柴
# 貼圖用 tools/survival_tex.sh 畫。背景跑：tools/model_iter.sh survival <版號>
# 座標：Blender（X 右、Y 往裡、Z 上）。預覽一樣一樣分開渲染，再照參考圖的位置拼成一張（scale 照參考圖框的大小）
import bpy, bmesh, math, os, random, subprocess, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline
from common import wipe, mat, box, cyl, sphere, finish, _parts, _push

rnd = random.Random(20261006)
wipe()   # 先清場再建材質：wipe 會把沒人用的材質刪掉

STONE = [mat('sv_stone%d' % i, c, 0.9) for i, c in enumerate([(0.045, 0.05, 0.06), (0.035, 0.04, 0.05), (0.055, 0.06, 0.07)])]
WOOD = mat('sv_wood', (0.07, 0.05, 0.04), 0.9)
WOOD_END = mat('sv_wood_end', (0.15, 0.12, 0.10), 0.9)      # 柴的切口：曬白的灰
IRON = mat('sv_iron', (0.045, 0.048, 0.055), 0.6, 0.4)      # 黑鐵（提燈、槍的金屬）
GLASS = mat('sv_glass', (0.75, 0.82, 0.85), 0.1)
BRASS = mat('sv_brass', (0.35, 0.22, 0.08), 0.5, 0.5)
WICK = mat('sv_wick', (0.55, 0.50, 0.40), 0.8)
CANVAS = mat('sv_cloth', (0.045, 0.05, 0.04), 0.95)           # 橄欖綠帆布（cloth：遊戲不加紋理）
BUCKLE = mat('sv_buckle', (0.20, 0.20, 0.21), 0.5, 0.6)   # 背包扣環：灰鋼，黑鐵在深綠布上看不見
LEATHER = mat('sv_leather', (0.13, 0.05, 0.022), 0.7)
ROCK = mat('sv_rock', (0.055, 0.065, 0.085), 0.9)
SNOW = mat('sv_snow', (0.62, 0.66, 0.72), 0.8)
ANTLER = mat('sv_antler', (0.22, 0.19, 0.16), 0.85)
ANTLER_BASE = mat('sv_antler_base', (0.10, 0.07, 0.05), 0.85)   # 角根附近深褐，往上漸淺
ANTLER_MID = mat('sv_antler_mid', (0.16, 0.13, 0.11), 0.85)   # 深褐到灰米的過渡
ANTLER_TIP = mat('sv_antler_tip', (0.55, 0.52, 0.47), 0.85)
BURR = mat('sv_burr', (0.52, 0.45, 0.36), 0.9)
GUNWOOD = mat('sv_gunwood', (0.10, 0.042, 0.020), 0.6)
STEEL = mat('sv_steel', (0.5, 0.5, 0.52), 0.4, 0.8)        # 斧刃磨亮的地方、罐頭
AXEHEAD = mat('sv_axehead', (0.06, 0.065, 0.07), 0.6, 0.5)
HANDLE = mat('sv_handle_wood', (0.09, 0.055, 0.03), 0.8)
TIN = mat('sv_tin', (0.24, 0.25, 0.26), 0.6, 0.6)   # 霧一點：亮的反光在罐口後面看起來像缺口
ENAMEL = mat('sv_enamel', (0.45, 0.45, 0.44), 0.4)
ENAMEL_RIM = mat('sv_enamel_rim', (0.035, 0.05, 0.09), 0.4)
RUST = mat('sv_rust', (0.10, 0.05, 0.025), 0.9)
CARD = mat('sv_card', (0.33, 0.30, 0.26), 0.9)               # 火柴盒內盒的紙板
STRIKER = mat('sv_striker', (0.14, 0.05, 0.04), 0.95)
MATCH = mat('sv_match_wood', (0.62, 0.48, 0.30), 0.9)
MATCH_HEAD = mat('sv_match_head', (0.20, 0.025, 0.02), 0.7)


def tex_mat(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(os.path.join(BASE, 'tex', img))
    nt.links.new(t.outputs['Color'], p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.6
    return m


_g = next(n for n in GLASS.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
_g.inputs['Alpha'].default_value = 0.22   # 看得到裡面的燈芯座
GLASS.surface_render_method = 'BLENDED'
CAN_LABEL = tex_mat('sv_can_label', 'can_label.png')
BOX_LABEL = tex_mat('sv_box_label', 'matchbox_label.png')


# ---------------- 工具 ----------------
def obj_from_bm(bm, ms, name='part'):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if not me.uv_layers:   # 每個零件都要有 UVMap：合併時第一個零件沒有的話，整個物件的貼圖座標會被丟掉（罐頭標籤 v2）
        me.uv_layers.new(name='UVMap')
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for m in ms:
        o.data.materials.append(m)
    _parts.append(o)
    return o


def hull(pts, m, paint=None):
    """凸包：石頭、斧頭、劈柴。paint(面中心, 法線) -> 材質序號（ms 清單裡第幾個）"""
    ms = m if isinstance(m, list) else [m]
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    r = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=list({g for g in r['geom_interior'] + r['geom_unused'] if isinstance(g, bmesh.types.BMVert)}), context='VERTS')
    mid = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    for f in bm.faces:   # 凸包：面一律朝外（從中心往外）。recalc_face_normals 在這裡會整顆翻反，雪跑到石頭底下（v6、v7）
        if f.normal.dot(f.calc_center_median() - mid) < 0:
            f.normal_flip()
    if paint:
        for f in bm.faces:
            f.material_index = paint(f.calc_center_median(), f.normal)
    return obj_from_bm(bm, ms)


def lathe(prof, n, m, loc=(0, 0, 0), paint=None, phase=0.0):
    """繞 Z 轉一圈：prof = [(半徑, 高)]，半徑 0 收成一點。paint(第幾段, 第幾格) -> 材質序號"""
    ms = m if isinstance(m, list) else [m]
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r < 1e-6:
            rings.append([bm.verts.new((loc[0], loc[1], loc[2] + z))])
        else:
            rings.append([bm.verts.new((loc[0] + r * math.cos(phase + 2 * math.pi * k / n),
                                        loc[1] + r * math.sin(phase + 2 * math.pi * k / n), loc[2] + z)) for k in range(n)])
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for k in range(n):
            if len(a) == 1:
                vs = (a[0], b[k], b[(k + 1) % n])
            elif len(b) == 1:
                vs = (a[k], a[(k + 1) % n], b[0])
            else:
                vs = (a[k], a[(k + 1) % n], b[(k + 1) % n], b[k])
            f = bm.faces.new(vs)
            if paint:
                f.material_index = paint(j, k)
    for ring in (rings[0], rings[-1]):
        if len(ring) > 1:
            bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, ms)


def sweep(pts, radii, n, m, up=(0, 0, 1), flat=1.0, paint=None):
    """沿折線掃一條管子（鹿角、提把、斧柄、肩帶）。radii 每點半徑；flat < 1 截面壓扁（up 方向那一軸）"""
    ms = m if isinstance(m, list) else [m]
    pts = [Vector(p) for p in pts]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    bm = bmesh.new()
    rings = []
    nrm = Vector(up)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = (nrm - t * nrm.dot(t)).normalized()
        bi = t.cross(nrm)
        rings.append([bm.verts.new(p + radii[i] * (math.cos(2 * math.pi * k / n) * bi + flat * math.sin(2 * math.pi * k / n) * nrm))
                      for k in range(n)])
    for j in range(len(rings) - 1):
        for k in range(n):
            f = bm.faces.new((rings[j][k], rings[j][(k + 1) % n], rings[j + 1][(k + 1) % n], rings[j + 1][k]))
            if paint:
                f.material_index = paint(j, k)
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, ms)


def loft_x(st, n, m):
    """沿 X 的截面串（槍托）：st = [(x, 下緣 z, 上緣 z, 半寬)]，截面是圓角方"""
    bm = bmesh.new()
    rings = []
    for x, lo, hi, hw in st:
        zc, hh = (lo + hi) / 2, (hi - lo) / 2
        ring = []
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            c, s = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((x, hw * math.copysign(abs(c) ** 0.5, c), zc + hh * math.copysign(abs(s) ** 0.5, s))))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(n):
            bm.faces.new((rings[j][k], rings[j][(k + 1) % n], rings[j + 1][(k + 1) % n], rings[j + 1][k]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, [m])


def quad_uv(c, m):
    """一片有貼圖座標的四邊形（貼圖 0..1 對到四個角：左下、右下、右上、左上）"""
    bm = bmesh.new()
    f = bm.faces.new([bm.verts.new(p) for p in c])
    uv = bm.loops.layers.uv.new('UVMap')   # 名字要跟其他零件一樣，合併時才接得上
    for l, t in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uv].uv = t
    return obj_from_bm(bm, [m])


def blob_box(size, loc, cuts=2, jit=0.006, squash=None):
    """帆布：細分的方塊，頂點亂推一點（皺），squash(x, y, z) -> (x, y, z) 調形狀（頂點是 -0.5..0.5 的比例座標）"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        if squash:
            x, y, z = squash(x, y, z)
        v.co = Vector((loc[0] + x * size[0] + rnd.uniform(-jit, jit), loc[1] + y * size[1] + rnd.uniform(-jit, jit),
                       loc[2] + z * size[2] + rnd.uniform(-jit, jit)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, [CANVAS])


def rock_pts(c, r, n, flat_bottom=True, jit=0.08):
    """橢球上均勻撒 n 個點（黃金角螺旋，徑向亂推 jit），r = 三軸半徑，底部壓平。亂撒會有大片空洞、凸包變成金字塔（v2）"""
    pts = []
    for i in range(n):
        u = 1 - 2 * (i + 0.5) / n
        v = i * 2.39996 + rnd.uniform(-0.3, 0.3)
        s = math.sqrt(1 - u * u)
        k = 1 + rnd.uniform(-jit, jit)
        p = Vector((c[0] + k * r[0] * s * math.cos(v), c[1] + k * r[1] * s * math.sin(v), c[2] + k * r[2] * u))
        if flat_bottom:
            p.z = max(p.z, 0.0)
        pts.append(p)
    return pts


# ---------------- 營火 ----------------
def split_log(p0, p1, w, h, twist=0.0):
    """劈開的柴：截面是不規則五邊形（一面平的劈面），兩端切口是灰白的"""
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    side = ax.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(ax)
    sec = [(-0.5, -0.5), (0.5, -0.5), (0.55, 0.15), (0.1, 0.55), (-0.45, 0.3)]
    pts = []
    for end in (p0, p1):
        for a, b in sec:
            ca, sa = math.cos(twist), math.sin(twist)
            a, b = a * ca - b * sa, a * sa + b * ca
            pts.append(end + side * a * w + up * b * h + ax * rnd.uniform(-0.003, 0.003))   # 切口要平：亂推太多會削成尖頭
    return hull(pts, [WOOD, WOOD_END], lambda c, n: 1 if abs(n.dot(ax)) > 0.8 else 0)


def build_campfire():
    for i in range(9):
        a = 2 * math.pi * i / 9 + rnd.uniform(-0.1, 0.1)
        rr = rnd.uniform(0.13, 0.15)
        c = (0.36 * math.cos(a), 0.32 * math.sin(a), rr * 0.8)
        hull(rock_pts(c, (rr, rr * 0.9, rr * 0.75), 16, jit=0.18), STONE[i % 3])
    split_log((0.03, -0.06, 0.0), (-0.07, -0.03, 0.60), 0.16, 0.07, 1.57)  # 高的那根：寬扁、幾乎直立、寬面朝鏡頭，站在柴堆最前面
    # 其他幾根斜靠著，頂端交叉穿過中心再伸出去（收在同一點會變成捆好的柴束，v11）
    split_log((-0.26, 0.0, 0.02), (0.05, -0.03, 0.38), 0.10, 0.08, 1.0)
    split_log((0.22, 0.06, 0.02), (-0.07, -0.01, 0.40), 0.10, 0.08, 2.0)
    split_log((-0.14, -0.17, 0.02), (0.05, 0.06, 0.37), 0.10, 0.08, 0.6)
    split_log((0.15, -0.16, 0.02), (-0.05, 0.07, 0.40), 0.10, 0.08, 2.4)
    split_log((-0.12, 0.12, 0.02), (0.17, -0.02, 0.46), 0.10, 0.08, 3.0)   # 右後方最高那根，頂端伸出高柴右邊
    split_log((-0.22, -0.02, 0.03), (0.20, 0.04, 0.12), 0.07, 0.05, 1.7)       # 底下橫躺的一根
    return finish('Campfire', bevel=0.0, seg=1)


# ---------------- 提燈 ----------------
def build_lantern():
    mm = 0.001
    # 油壺：底緣、壺身、往上收的肩、頸
    lathe([(0, 0), (58, 0), (59, 4), (58, 15), (56, 17), (56, 80), (50, 92), (40, 100), (0, 100)], 12, IRON)
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    lathe([(0, 98), (34, 98), (34, 125), (0, 125)], 12, IRON)
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    cyl(0.009, 0.014, (-0.040, -0.047, 0.072), (math.radians(90), 0, math.radians(-50)), 8, m=IRON)   # 油門旋鈕
    lathe([(0, 125), (58, 125), (58, 140), (0, 140)], 12, IRON)                                   # 玻璃罩底座
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    lathe([(0, 140), (45, 140), (46.5, 192), (45, 245), (0, 245)], 16, GLASS)                     # 玻璃罩
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    lathe([(0, 140), (20, 140), (20, 170), (14, 176), (0, 176)], 6, BRASS)                         # 燈芯座
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    cyl(0.0035, 0.040, (0, 0, 0.188), m=WICK)                                                     # 燈芯管
    for k in range(4):                                                                            # 護欄
        a = math.radians(45 + 90 * k)
        box((0.006, 0.006, 0.11), (0.052 * math.cos(a), 0.052 * math.sin(a), 0.192), m=IRON)
    lathe([(0, 245), (62, 245), (64, 252), (64, 268), (60, 273), (0, 273)], 12, IRON)             # 上面的寬環
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    lathe([(0, 273), (50, 273), (50, 282), (45, 292), (40, 294), (40, 310), (36, 316), (0, 316)], 10, IRON)   # 上蓋兩層
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    lathe([(0, 310), (38, 310), (37, 320), (28, 329), (0, 329)], 8, IRON)                          # 頂蓋
    _parts[-1].data.transform(Matrix.Scale(mm, 4))
    cyl(0.012, 0.014, (0, 0, 0.335), v=6, m=IRON)                                                  # 頂上的鈕
    # 八角提把：從上環兩側的軸往上
    path = [(-0.066, 0, 0.260), (-0.068, 0, 0.320), (-0.062, 0, 0.385), (-0.025, 0, 0.428),
            (0.025, 0, 0.428), (0.062, 0, 0.385), (0.068, 0, 0.320), (0.066, 0, 0.260)]
    sweep(path, 0.0028, 6, IRON, up=(0, 1, 0))
    for sx in (-1, 1):
        cyl(0.007, 0.008, (sx * 0.066, 0, 0.260), (0, math.radians(90), 0), 8, m=IRON)
    return finish('Lantern', bevel=0.0015, seg=1)


# ---------------- 背包 ----------------
def strap(x, y_face, z0, z1, buckle_z):
    """一條垂直的皮帶貼在 y_face 前面，buckle_z 有一個鐵扣"""
    box((0.026, 0.005, z1 - z0), (x, y_face - 0.0025, (z0 + z1) / 2), m=LEATHER)
    box((0.034, 0.007, 0.004), (x, y_face - 0.006, buckle_z + 0.013), m=BUCKLE)    # 方形扣框：上下左右四條
    box((0.034, 0.007, 0.004), (x, y_face - 0.006, buckle_z - 0.013), m=BUCKLE)
    for sx in (-1, 1):
        box((0.004, 0.007, 0.030), (x + sx * 0.015, y_face - 0.006, buckle_z), m=BUCKLE)
    box((0.003, 0.008, 0.026), (x, y_face - 0.007, buckle_z), m=BUCKLE)             # 扣針


def build_backpack():
    W, D, H = 0.34, 0.20, 0.48

    def body(x, y, z):
        # 頂部收窄、底部圓一點；前面（-y）略鼓
        k = 1.0 - 0.22 * (z + 0.5) - (0.25 * (z - 0.3) / 0.2 if z > 0.3 else 0.0)   # 上窄下寬、頂上收成圓頂
        y = y * (1.0 - 0.15 * (z + 0.5) * (z + 0.5))
        if y < 0:
            y *= 1.0 + 0.1 * (1 - 4 * x * x)
        if z > 0.25:   # 圓頂
            q = 1 - 6.0 * (z - 0.25) ** 2
            x, y = x * q, y * q
        if y < 0 and z < 0:   # 下半段往前鼓
            y -= 0.18 * (-z)
        if z < -0.4:   # 底角圓一點
            x *= 0.92
        return x * k, y, z
    blob_box((W, D, H), (0, 0, H / 2), 3, 0.006, body)
    # 上蓋：從背面頂上翻過來蓋到前面，蓋住上面四成
    lid = [(0.04, 0.46), (0.0, 0.50), (-0.085, 0.49), (-0.115, 0.45), (-0.118, 0.36), (-0.115, 0.27)]
    bm = bmesh.new()
    rows = []
    for y, z in lid:
        w = 0.09 if y > -0.01 else (0.11 if z >= 0.47 else (0.13 if z >= 0.45 else 0.15))   # 頂上窄、往下寬：圓頂；背面收進去
        sag = 0.04 if z > 0.40 else 0.0   # 只有上面幾排兩側下垂，下緣維持水平（扣環扣在這條線上）
        rows.append([bm.verts.new((x * w, y, z - sag * x * x)) for x in (-1, -0.5, 0.0, 0.5, 1)])
    for j in range(len(rows) - 1):
        for k in range(4):
            bm.faces.new((rows[j][k], rows[j][k + 1], rows[j + 1][k + 1], rows[j + 1][k]))
    for v in bm.verts:
        v.co += Vector((rnd.uniform(-0.005, 0.005), rnd.uniform(-0.006, 0.006), rnd.uniform(-0.006, 0.006)))
    o = obj_from_bm(bm, [CANVAS])
    sol = o.modifiers.new('s', 'SOLIDIFY')
    sol.thickness = 0.018
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier='s')
    # 前面的口袋＋口袋蓋
    blob_box((0.27, 0.07, 0.17), (0, -0.125, 0.10), 2, 0.004)
    blob_box((0.28, 0.08, 0.05), (0, -0.13, 0.17), 1, 0.004, lambda x, y, z: (x, y, z - (0.3 if y < 0 and z < 0 else 0)))
    # 四條皮帶：上蓋兩條、口袋兩條
    for sx in (-1, 1):
        strap(sx * 0.07, -0.142, 0.24, 0.40, 0.275)
        strap(sx * 0.075, -0.178, 0.07, 0.19, 0.12)
    box((0.045, 0.004, 0.055), (0.15, -0.112, 0.07), m=LEATHER)                       # 皮標
    # 右側肩帶：從背面上面繞到右下
    for sx in (1, -1):   # 左右兩條肩帶（只做一條背不起來，繞一圈才發現，v19）
        sweep([(sx * 0.09, 0.09, 0.40), (sx * 0.15, 0.12, 0.38), (sx * 0.165, 0.14, 0.30), (sx * 0.165, 0.13, 0.16), (sx * 0.15, 0.11, 0.04)],
              0.025, 6, LEATHER, up=(1, 0, 0), flat=0.25)
    return finish('Backpack', bevel=0.0, seg=1)


# ---------------- 積雪大石 ----------------
def build_snowrock():
    # 一整塊凸包（三塊疊會變成兩層蛋糕或像有腳的鳥，v10~v12）。雪：朝上的面一定有、斜面一半有、底部一圈一半有
    snow = lambda c, n: 1 if (n.z > 0.6 and c.z > 0.62) or (0.33 < c.z < 0.48 and c.x < 0.05 and n.z > 0.05 and rnd.random() < 0.7) or (c.z < 0.12 and rnd.random() < 0.7) else 0   # 頂蓋、左側中段一條雪帶、底部
    pts = rock_pts((0, 0, 0.36), (0.44, 0.38, 0.44), 110, jit=0.07)   # 點多面才小，雪帶才會是一條不是一片三角形
    for p in pts:   # 越往上越窄：最寬的地方靠近地面（中心壓低會讓一半的點被壓扁在地上，面變超大，v16）
        k = 1.12 - 0.45 * p.z / 0.8   # 只收上段會變矮胖、雪蓋變小（v20 試過）
        p.x, p.y = p.x * k, p.y * k
        p.z = min(p.z, 0.74 + 0.05 * p.x)   # 頂上削平一點：頂蓋積雪
    hull(pts, [ROCK, SNOW], snow)
    return finish('SnowRock', bevel=0.0, seg=1)


# ---------------- 鹿角 ----------------
def build_antler():
    # 參考圖裁圖座標（像素）換成公尺：角座在 (320, 665)，1 px = 0.8 mm，往右 +X、往上 +Z
    P = lambda x, y, d=0.0: ((x - 320) * 0.0008, d, (665 - y) * 0.0008 + 0.03)
    tip = lambda j, k: 1 if j >= 3 else 0
    beam = [P(320, 665), P(290, 580, -0.04), P(255, 480, -0.03), P(205, 390, -0.01), P(200, 300, 0.01),
            P(235, 220, 0.03), P(265, 150, 0.04), P(300, 95, 0.05), P(350, 30, 0.05)]
    sweep(beam, [0.039, 0.035, 0.031, 0.027, 0.025, 0.021, 0.017, 0.012, 0.004], 7, [ANTLER_BASE, ANTLER_MID, ANTLER, ANTLER_TIP],
          paint=lambda j, k: 0 if j < 2 else (1 if j < 3 else (3 if j >= 6 else 2)))
    sweep([P(200, 300, 0.01), P(180, 220, 0.0), P(165, 160, 0.0), P(155, 100, 0.0)],
          [0.016, 0.012, 0.008, 0.002], 6, [ANTLER, ANTLER_TIP], paint=lambda j, k: 1 if j >= 1 else 0)
    sweep([P(240, 215, 0.03), P(230, 160, 0.03), P(228, 110, 0.03), P(235, 55, 0.03)],
          [0.014, 0.011, 0.007, 0.002], 6, [ANTLER, ANTLER_TIP], paint=lambda j, k: 1 if j >= 1 else 0)
    sweep([P(258, 485, -0.02), P(200, 470, -0.03), P(140, 445, -0.035), P(80, 410, -0.04)],
          [0.022, 0.016, 0.011, 0.003], 6, [ANTLER, ANTLER_TIP], paint=lambda j, k: 1 if j >= 2 else 0)
    # 右邊的分支：從角座往右上
    sweep([P(325, 650), P(400, 565, 0.02), P(465, 480, 0.03), P(505, 380, 0.03), P(525, 300, 0.03), P(535, 230, 0.03)],
          [0.024, 0.021, 0.018, 0.014, 0.009, 0.0025], 7, [ANTLER_BASE, ANTLER, ANTLER_TIP], paint=lambda j, k: 0 if j < 1 else (2 if j >= 3 else 1))
    sweep([P(470, 470, 0.03), P(450, 420, 0.03), P(430, 385, 0.03)], [0.012, 0.008, 0.002], 6,
          [ANTLER, ANTLER_TIP], paint=lambda j, k: 1 if j >= 1 else 0)
    # 角座：一圈凸起的疙瘩＋淺色的斷面
    c = Vector(P(322, 668))
    ax = Vector((0.55, -0.8, 0.1)).normalized()   # 斷面朝右前下方（鏡頭那邊），是一截短柱不是平盤
    side = ax.cross(Vector((0, 1, 0))).normalized()
    up = ax.cross(side)
    pts = []
    for k in range(10):
        a = 2 * math.pi * k / 10
        r = 0.048 * rnd.uniform(0.8, 1.25)
        for d in (-0.03, 0.0):
            pts.append(c + ax * d + (side * math.cos(a) + up * math.sin(a)) * r)
    hull(pts, [ANTLER_BASE, BURR], lambda cc, n: 1 if n.dot(ax) > 0.6 else 0)
    o = finish('Antler', bevel=0.0, seg=1)
    o.data.transform(Matrix.Rotation(math.radians(-15), 4, 'Y'))   # 整支往左上斜，角座偏右下
    return o


# ---------------- 栓式步槍 ----------------
def build_rifle():
    # 槍口朝 +X，右側（槍栓）朝 -Y。槍托底在 x=0
    loft_x([(0.000, -0.150, 0.025, 0.021), (0.01, -0.149, 0.027, 0.022), (0.12, -0.120, 0.024, 0.021),
            (0.24, -0.082, 0.016, 0.019), (0.30, -0.050, 0.010, 0.014), (0.33, -0.075, 0.010, 0.013),
            (0.36, -0.072, 0.012, 0.016), (0.385, -0.055, 0.013, 0.016), (0.41, -0.032, 0.014, 0.017), (0.44, -0.024, 0.014, 0.017), (0.55, -0.022, 0.014, 0.016),
            (0.75, -0.018, 0.014, 0.013), (0.80, -0.014, 0.012, 0.011)], 10, GUNWOOD)
    box((0.006, 0.044, 0.177), (-0.002, 0, -0.062), m=IRON)                                      # 槍托底板
    cyl(0.013, 0.20, (0.45, 0, 0.012), (0, math.radians(90), 0), 10, m=IRON)                       # 機匣
    cyl(0.0095, 0.58, (0.83, 0, 0.016), (0, math.radians(90), 0), 8, m=IRON)                       # 槍管
    cyl(0.013, 0.035, (0.35, 0, 0.014), (0, math.radians(90), 0), 8, m=IRON)                       # 擊錘尾
    box((0.02, 0.012, 0.012), (0.60, 0, 0.028), m=IRON)                                           # 表尺
    box((0.008, 0.004, 0.014), (1.105, 0, 0.028), m=IRON)                                         # 準星
    for x in (0.64, 0.80):                                                                         # 槍管箍
        box((0.010, 0.034, 0.038), (x, 0, 0.002), m=IRON)
    # 槍栓拉柄：從機匣右側往外、往下，尾端一顆球
    sweep([(0.40, -0.012, 0.018), (0.392, -0.026, 0.0), (0.378, -0.030, -0.026)], 0.006, 6, IRON, up=(1, 0, 0))   # 沿槍托側面往下往後彎，從右側看得到
    sphere(0.011, (0.374, -0.031, -0.034), 8, 5, m=IRON)
    cyl(0.009, 0.10, (0.43, -0.004, 0.020), (0, math.radians(90), 0), 8, m=IRON)                  # 槍機
    # 扳機護弓＋扳機
    gd = [(0.401 + 0.030 * math.cos(math.pi * (1 - k / 8)), 0, -0.022 - 0.036 * math.sin(math.pi * k / 8)) for k in range(9)]   # 半圓
    sweep(gd, 0.003, 8, IRON, up=(0, 1, 0))
    sweep([(0.40, 0, -0.022), (0.398, 0, -0.040), (0.392, 0, -0.050)], 0.0025, 5, IRON, up=(0, 1, 0))
    return finish('Rifle', bevel=0.0015, seg=1, smooth_mats=('sv_gunwood',))


# ---------------- 手斧 ----------------
def build_axe():
    # 斧柄沿 Z（尾端在 z=0），斧刃朝 +X。柄微彎：尾端往 -X 翹
    xs = [-0.022, -0.016, -0.006, 0.004, 0.010, 0.010, 0.006, 0.002]   # 平順的 S 彎
    path = [(x, 0, 0.42 * k / 7) for k, x in enumerate(xs)]
    sweep(path, [0.028, 0.022, 0.018, 0.016, 0.015, 0.015, 0.016, 0.017], 8, HANDLE, up=(0, 1, 0), flat=0.7)
    cyl(0.0045, 0.032, (-0.016, 0, 0.03), (math.radians(90), 0, 0), 8, m=mat('sv_hole', (0.02, 0.015, 0.01), 1.0))   # 吊繩孔
    # 斧頭拆兩塊凸包：後段＋斧眼、刃部。兩塊接起來下緣才有凹角（單一凸包下緣只能是直線，像犁頭，v11）
    back, blade = [], []
    for y in (-1, 1):
        back += [(-0.034, y * 0.014, 0.360), (-0.034, y * 0.014, 0.420), (-0.030, y * 0.016, 0.358), (-0.030, y * 0.016, 0.422),
                 (0.010, y * 0.016, 0.358), (0.010, y * 0.016, 0.422)]
        blade += [(0.0, y * 0.012, 0.365), (0.0, y * 0.012, 0.418), (0.05, y * 0.007, 0.350), (0.05, y * 0.007, 0.418),
                  (0.088, y * 0.0025, 0.305), (0.088, y * 0.0025, 0.427),
                  (0.098, y * 0.001, 0.300), (0.102, y * 0.001, 0.365), (0.098, y * 0.001, 0.428)]
    hull(back, AXEHEAD)
    hull(blade, [AXEHEAD, STEEL], lambda c, n: 1 if c.x > 0.090 else 0)   # 刃口一條磨亮的帶子
    return finish('Axe', bevel=0.001, seg=1, smooth_mats=('sv_handle_wood',))


# ---------------- 罐頭 ----------------
def build_can():
    mm = 0.001
    r = 38
    prof = [(0, 3), (36, 3), (40, 1), (r, 0), (r + 2.5, 2), (r + 2.5, 6), (r, 8), (r, 117), (r + 2.5, 119),
            (r + 2.5, 124), (r - 1, 125), (r - 3, 121), (30, 121), (29, 122.5), (20, 122.5), (19, 121), (0, 121)]   # 罐子拉高到 125：上緣跟著往上
    lathe([(a * mm, b * mm) for a, b in prof], 20, TIN)
    # 標籤：一圈有貼圖座標的帶子，u = 0.5 在正面（-Y）
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')   # 名字要跟其他零件一樣，合併時才接得上
    n = 24
    R = (r + 0.4) * mm
    lo = [bm.verts.new((R * math.sin(2 * math.pi * k / n - math.pi), -R * math.cos(2 * math.pi * k / n - math.pi), 10 * mm)) for k in range(n + 1)]
    hi = [bm.verts.new((v.co.x, v.co.y, 115 * mm)) for v in lo]
    for k in range(n):
        f = bm.faces.new((lo[k], lo[k + 1], hi[k + 1], hi[k]))
        for l, t in zip(f.loops, ((k / n, 0), ((k + 1) / n, 0), ((k + 1) / n, 1), (k / n, 1))):
            l[uv].uv = t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:   # 面要朝外
        if f.normal.dot(f.calc_center_median() * Vector((1, 1, 0))) < 0:
            f.normal_flip()
    obj_from_bm(bm, [CAN_LABEL])
    return finish('StewCan', bevel=0.0, seg=1)


# ---------------- 琺瑯杯 ----------------
def build_mug():
    mm = 0.001
    prof = [(0, 0), (40, 0), (44, 3), (45, 6), (45.5, 9), (46, 83.5), (46, 86), (48.5, 90), (46, 93), (43, 93), (42.5, 88), (42, 8), (0, 7)]
    lathe([(a * mm, b * mm) for a, b in prof], 12, [ENAMEL, ENAMEL_RIM, RUST], phase=math.pi / 12)
    o = _parts[-1]
    # 杯身白，底緣和杯口一圈深藍
    for p in o.data.polygons:
        z = sum(o.data.vertices[v].co.z for v in p.vertices) / len(p.vertices)
        p.material_index = 1 if (z > 0.087 or z < 0.006) else 0
    # 掉漆：杯口下緣和杯底一圈鏽邊（波浪：每格隨機要不要）
    for p in o.data.polygons:
        z = p.center.z
        if p.material_index == 0 and p.normal.z < 0.5 and p.center.length > 0.03 and (0.083 < z < 0.0865 and rnd.random() < 0.3 or 0.006 < z < 0.010 and rnd.random() < 0.55):
            p.material_index = 2   # 斷斷續續，不是一整圈
    # 把手：扁的帶子，從杯身右側彎出去
    hd = [(0.045 + 0.028 * math.sin(math.pi * k / 9), 0, 0.052 + 0.026 * math.cos(math.pi * k / 9)) for k in range(10)]   # D 形
    sweep(hd, 0.008, 6, ENAMEL_RIM, up=(0, 0, 1), flat=0.3)   # 扁帶：寬 16mm 沿前後方向、薄的是徑向（up 改 Y 會變成一塊圓餅，v12）
    return finish('Mug', bevel=0.0, seg=1)


# ---------------- 火柴盒 ----------------
def build_matchbox():
    L, Wd, Ht, t = 0.080, 0.055, 0.022, 0.0012
    # 外盒：上下兩片、兩長邊（擦火的那面深褐），兩短邊開口
    box((L, Wd, t), (0, 0, Ht - t / 2), m=CARD)
    box((L, Wd, t), (0, 0, t / 2), m=CARD)
    for sy in (-1, 1):
        box((L, t, Ht), (0, sy * (Wd / 2 - t / 2), Ht / 2), m=CARD)
        box((L - 0.006, 0.0004, Ht - 0.006), (0, sy * (Wd / 2 + 0.0002), Ht / 2), m=STRIKER)   # 擦火面：被紙邊框住
    e = 0.002   # 標籤四邊留一圈紙邊
    quad_uv([(-L / 2 + e, -Wd / 2 + e, Ht + 0.0002), (L / 2 - e, -Wd / 2 + e, Ht + 0.0002), (L / 2 - e, Wd / 2 - e, Ht + 0.0002), (-L / 2 + e, Wd / 2 - e, Ht + 0.0002)], BOX_LABEL)
    # 內盒往 -X 抽出 0.035
    out = -0.035
    iL, iW, iH = L - 0.002, Wd - 2 * t - 0.001, Ht - 2 * t - 0.001
    z0 = t + 0.0005
    box((iL, iW, t), (out, 0, z0 + t / 2), m=CARD)
    for sy in (-1, 1):
        box((iL, t, iH), (out, sy * (iW / 2 - t / 2), z0 + iH / 2), m=CARD)
    for sx in (-1, 1):
        box((t, iW, iH), (out + sx * (iL / 2 - t / 2), 0, z0 + iH / 2), m=CARD)
    # 火柴：四層塞滿，每層 6 根，頭朝抽出來的那端
    for layer in range(4):
        for i in range(6):
            y = -iW / 2 + 0.006 + i * (iW - 0.012) / 5
            z = z0 + t + 0.0015 + layer * 0.0035
            x0 = out - iL / 2 + 0.006
            box((0.068, 0.0026, 0.0026), (x0 + 0.034 + 0.002, y + layer * 0.002, z), m=MATCH)
            sphere(0.0042, (x0 + 0.002, y + layer * 0.002, z), 8, 6, m=MATCH_HEAD)
            _parts[-1].scale = (1.5, 1.0, 1.0)
            bpy.context.view_layer.objects.active = _parts[-1]
            _parts[-1].select_set(True)
            bpy.ops.object.transform_apply(scale=True)
            _parts[-1].select_set(False)
    return finish('Matchbox', bevel=0.0, seg=1)


ORDER = ['Campfire', 'Lantern', 'Backpack', 'SnowRock', 'Antler', 'Rifle', 'Axe', 'StewCan', 'Mug', 'Matchbox']


def build_all():
    obs = [build_campfire(), build_lantern(), build_backpack(), build_snowrock(), build_antler(),
           build_rifle(), build_axe(), build_can(), build_mug(), build_matchbox()]
    for o in obs:   # 原點放到底部中央：步槍、斧頭建的時候原點不在底下，放進遊戲會一半埋進地裡
        o.location = (0, 0, 0)
        vs = [v.co for v in o.data.vertices]
        lo = Vector([min(v[i] for v in vs) for i in range(3)])
        hi = Vector([max(v[i] for v in vs) for i in range(3)])
        o.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    return obs


# ---------------- 預覽 ----------------
# 每樣：參考圖裡的框（左、上、右、下 像素）、相機（水平角：正的往右繞，仰角）、物件在畫面裡轉幾度（繞 Y 軸，正的逆時針）
VIEWS = {
    'Campfire': ((20, 205, 365, 490), 0, 28, 0),
    'Lantern':  ((440, 75, 575, 478), 0, 8, 0),
    'Backpack': ((655, 125, 905, 470), 25, 10, 0),
    'SnowRock': ((950, 210, 1245, 500), 0, 12, 0),
    'Antler':   ((1275, 140, 1510, 500), 0, 5, 0),
    'Rifle':    ((15, 545, 405, 905), 0, 8, 40),
    'Axe':      ((375, 545, 590, 905), 0, 5, -18),
    'StewCan':  ((690, 640, 815, 885), 0, 15, 0),
    'Mug':      ((940, 665, 1160, 900), 0, 25, 0),
    'Matchbox': ((1225, 650, 1510, 880), -15, 40, -15),
}


def preview(obs, path):
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.lens = 85
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 2.2
    sun.data.angle = math.radians(20)
    sun.rotation_euler = (math.radians(40), 0, math.radians(-30))   # 左前上方：右側面稍暗
    sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (1, 1, 1, 1)
    bg.inputs['Strength'].default_value = 0.45
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
        box_, yaw, pitch, roll = VIEWS[o.name]
        for p in obs:
            p.hide_render = p is not o
        o.rotation_euler = (0, math.radians(-roll), 0)
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        c = sum(pts, Vector()) / 8
        R = max((p - c).length for p in pts)
        d = R / math.sin(math.atan(18 / 85)) * 1.05
        yw, pt = math.radians(yaw), math.radians(pitch)
        cam.location = c + Vector((math.sin(yw) * math.cos(pt), -math.cos(yw) * math.cos(pt), math.sin(pt))) * d
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
        w, h = box_[2] - box_[0], box_[3] - box_[1]
        sc.render.resolution_x = sc.render.resolution_y = 900
        f = os.path.join(tmp, o.name + '.png')
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        subprocess.run(['magick', f, '-trim', '+repage', '-resize', '%dx%d' % (w, h), f], check=True)
        args += ['(', f, ')', '-gravity', 'center', '-geometry', '+%d+%d' % ((box_[0] + box_[2]) / 2 - 768, (box_[1] + box_[3]) / 2 - 512),
                 '-composite']
        o.rotation_euler = (0, 0, 0)
    subprocess.run(args + [path], check=True)
    print('preview ->', path)


pipeline.run(build_all, preview, budget={'*': 6000})
