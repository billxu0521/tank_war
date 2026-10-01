# 五種新樹（docs/image/tree_list.png 的 2~6 號），闊葉樹（1 號）已經在 tree.py：
#   TreeMaple   楓樹（秋天）：直樹幹、枝條清楚、橘黃紅三色的小葉團
#   TreePine2   松樹：高樹幹、水平伸出的枝、一層層壓扁的深綠葉團（舊的 TreePine 在 props.py）
#   TreeJoshua  約書亞樹：粗短樹幹一路 Y 字分叉，每個枝端一球放射狀的尖葉
#   TreeDead    枯樹：扭轉的樹幹、一路分叉到細尖的枝，沒有葉子
#   TreeWillow  柳樹：彎的樹幹、圓頂樹冠、一串串往下垂的葉簾
# 原點在樹根、尺寸是實際公尺（遊戲的碰撞圓柱寫在 main.gd 的 TREE_KINDS）。
# 背景跑：REF=docs/image/tree_list.png tools/model_iter.sh grove <版號>（預覽照參考圖的 3×2 排，闊葉樹也放進來對照）
import bpy, bmesh, math, os, random, sys
import numpy as np
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipeline, tree
from pipeline import studio
from tree import *   # 借用 tree.py 的工具（limb、bend、material、葉片卡……）
from tree import rng

rnd = random.Random(11)


def limb(bm, pts, radii, sides, mi, twist=0.0, roots=(), root_k=(1.15, 1.08)):
    """跟 tree.py 的 limb 一樣，但每圈的方向用平行移動（parallel transport）接下去：
    tree.py 的 frame() 在方向接近垂直時會換參考軸，彎的樹幹經過那個角度會整圈轉一下，擰出一圈皺褶"""
    rings, u = [], None
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = frame(d)[0] if u is None else (u - d * u.dot(d)).normalized()
        v = d.cross(u)
        ring = []
        for k in range(sides):
            a = k / sides * math.tau + twist * i / max(len(pts) - 1, 1)
            rr = r * rng.uniform(0.93, 1.07) * (root_k[i] if i < len(root_k) and k in roots else 1.0)
            ring.append(bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * rr))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])).material_index = mi
    bm.faces.new(list(reversed(rings[0]))).material_index = mi
    bm.faces.new(rings[-1]).material_index = mi   # 末端也封起來：細枝的尖端露在葉子外面時，看進管子裡是一個暗方塊
UP = Vector((0, 0, 1))


def gem(bm, c, r, mi, cuts=1, jit=0.12, sq=(1, 1, 1)):
    """一顆多面體：二十面體（cuts=0 是 20 面、1 是 80 面、2 是 180 面），頂點沿徑向亂推、整顆隨機轉，再各軸縮放 sq"""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
    if cuts:
        bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=cuts, use_grid_fill=True)
    rot = Euler([rnd.uniform(0, math.tau) for _ in range(3)]).to_matrix()
    for v in tmp.verts:
        q = (rot @ v.co.normalized()) * r * rnd.uniform(1 - jit, 1 + jit)
        v.co = c + Vector((q.x * sq[0], q.y * sq[1], q.z * sq[2]))
    merge(bm, tmp, mi)


def merge(bm, tmp, mi):
    me = bpy.data.meshes.new('tmp')
    tmp.to_mesh(me)
    tmp.free()
    before = set(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for f in bm.faces:
        if f not in before:
            f.material_index = mi


def spike(bm, base, d, length, w, mi):
    """一根尖葉：三角錐，底是寬 w 的扁三角形（一面朝上），往 d 方向長 length"""
    d = d.normalized()
    u, v = frame(d)
    a = [bm.verts.new(base + (u * math.cos(t) + v * math.sin(t) * 0.45) * w) for t in (0, 2.1, 4.2)]
    tip = bm.verts.new(base + d * length)
    for i in range(3):
        bm.faces.new((a[i], a[(i + 1) % 3], tip)).material_index = mi
    bm.faces.new(list(reversed(a))).material_index = mi


def branch(bm, p, d, L, r, depth, cfg, tips, mi=0, kink=0.0):
    """一根枝：分三段往 d 長，微彎、逐段收細；depth > 0 時末端再分 cfg['kids'] 根，角度往外張 cfg['spread']。
    末端的位置和方向記到 tips（葉團或尖葉長在那裡）"""
    d = d.normalized()
    end = p + d * L
    pts = bend(p, end, 3, L * cfg.get('wob', 0.08) * rnd.uniform(-1, 1))
    pts[-1].z += cfg.get('lift', 0.0) * L
    if kink:   # 在一半長度折一下（kink 弧度），枝條才有折角，不是一條平順的弧
        sv = frame(d)[0]
        for j, k in ((2, 0.5), (3, 1.0)):
            pts[j] = pts[j] + sv * L * math.sin(kink) * k
    rr = [r, r * 0.88, r * 0.76, r * (cfg.get('tip', 0.66) if depth == 0 else cfg.get('taper', 0.66))]
    limb(bm, pts, rr, cfg.get('sides', 5), mi, twist=rnd.uniform(-0.4, 0.4))
    if depth == cfg.get('side_at', -1):   # 主枝在 40%、70% 處各長一根側枝（母枝長的 35~45%），兩根方向至少差 120 度，不會交叉
        a = rnd.uniform(0, math.tau)
        for t in (0.4, 0.7):
            q = pts[0].lerp(pts[-1], t)
            u, v = frame(end - p)
            a += rnd.uniform(2.1, 4.2)
            sd = (end - p).normalized() * 0.7 + (u * math.cos(a) + v * math.sin(a))
            branch(bm, q, sd, L * rnd.uniform(0.35, 0.45), r * 0.4, 0, cfg, tips, mi)
    tip_d = (pts[-1] - pts[-2]).normalized()
    if depth == 0:
        tips.append((pts[-1], tip_d, r))
        return pts
    n = cfg['kids'] if isinstance(cfg['kids'], int) else rnd.choice(cfg['kids'])
    yaw0 = rnd.uniform(0, math.tau)
    for i in range(n):
        yaw = yaw0 + i / n * math.tau + rnd.uniform(-0.4, 0.4)
        u, v = frame(tip_d)
        s = math.radians(cfg['spread'] * rnd.uniform(0.7, 1.2))
        nd = tip_d * math.cos(s) + (u * math.cos(yaw) + v * math.sin(yaw)) * math.sin(s)
        nd.z += cfg.get('up', 0.0)
        branch(bm, pts[-1] - tip_d * r * 0.5, nd, L * cfg['shrink'] * rnd.uniform(0.85, 1.1),
               r * cfg['rshrink'], depth - 1, cfg, tips, mi)
    return pts


def trunk(bm, H, r, lean=0.0, bends=0.0, twist=25, flare=1.5, roots=True):
    """主幹：從地面（遊戲會往下埋 0.3）長到 H，根部外擴到 flare 倍漸變收回，往上收細到 0.75。回傳頂端的點和方向"""
    pts, rr = [], []
    side = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)).normalized()
    for t in (0, 0.04, 0.1, 0.18, 0.27, 0.36, 0.46, 0.57, 0.68, 0.79, 0.9, 1.0):   # 圈排密：根部外擴是平順的弧、扭轉分散開，不會折出一圈皺褶
        z = H * t
        off = side * (lean * t * t + math.sin(t * math.pi * 1.6) * bends) * min(1.0, t * 3) ** 2   # 第一段要直：斜的話最底那圈跟著斜，會插進地裡像一塊板
        pts.append(Vector((off.x, off.y, z)))
        k = 1 + (flare - 1) * max(0, 1 - t / 0.3) ** 2
        rr.append(r * k * (1 - 0.25 * t))
    limb(bm, pts, rr, 7, 0, twist=math.radians(twist), roots=(0, 2, 5) if roots else (), root_k=(1.2, 1.16, 1.1, 1.05, 1.0))
    return pts[-1], (pts[-1] - pts[-2]).normalized(), rr[-1]


def shell(bm, c, rad, n, rr, mi, skip=0.0, zmin=-1.0, sq=(1, 1, 1), cuts=1):
    """在中心 c、半徑 rad 的橢球殼上用黃金角撒 n 顆葉團（z 分量低於 zmin 的不放、skip 機率空掉）"""
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        a = i * 2.39996
        w = math.sqrt(1 - z * z)
        if z < zmin or rnd.random() < skip:
            continue
        q = c + Vector((w * math.cos(a) * rad[0], w * math.sin(a) * rad[1], z * rad[2]))
        q += Vector([rnd.uniform(-0.2, 0.2) for _ in range(3)])
        gem(bm, q, rnd.uniform(*rr), mi(), cuts=cuts, jit=0.15, sq=sq)


def mats(*spec):
    return [material(n, c) for n, c in spec]


def obj(name, bm, ms):
    """bmesh 變成物件：平面著色，葉片卡的面改用記下來的法線（apply_card_normals，在 tree.py）"""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ms:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    apply_card_normals(ob)
    return ob


# ---- 顏色（線性值）：比照 tree.py 的闊葉樹，參考圖的顏色大約乘 0.3，進遊戲的暖光裡才不會過亮
BARK = (0.133, 0.055, 0.024)
MAPLE = ((0.34, 0.12, 0.012), (0.38, 0.21, 0.025), (0.40, 0.075, 0.012))   # 橘、黃橘、紅橘
PINE = (0.042, 0.062, 0.019)   # 遊戲的光比預覽暗，背光面會黑掉：比參考圖的暗綠再亮一點
PINE_BARK = (0.105, 0.055, 0.032)
PINE_CORE = (0.1, 0.1, 0.042)   # 芯：葉色最暗那階（偏綠的橄欖，線性值）   # 葉簇的芯：松針最暗那階（偏黃的橄欖深綠）   # 比闊葉樹的樹皮灰一點：太橘
YUCCA = (0.12, 0.145, 0.025)
YUCCA_DEAD = (0.11, 0.07, 0.03)
DEAD_BARK = (0.12, 0.085, 0.058)
WILLOW = (0.13, 0.16, 0.026)


def maple():
    rnd.seed(21)
    ms = mats(('tree_bark_maple', BARK),) + [card_material('tree_leafcard_maple', 'leaf_maple.png')] + mats(('tree_leaf_maple_core', (0.45, 0.15, 0.02)))
    bm = bmesh.new()
    top, d, r = trunk(bm, 3.2, 0.45, flare=1.4)
    tips = []
    for i in range(3):   # 樹幹頂 Y 字分成三根主枝（主幹的 65%），每根再分兩次，枝尖都收在樹冠裡
        yaw = i / 3 * math.tau + rnd.uniform(-0.3, 0.3)
        nd = Vector((math.cos(yaw) * 0.8, math.sin(yaw) * 0.8, 1))
        branch(bm, top - d * 0.3, nd, 2.2, r * 0.65, 2, {'kids': 2, 'spread': 30, 'shrink': 0.62, 'rshrink': 0.62,
                                                     'up': 0.25}, tips)
    # 樹冠底緣在 38% 高度、寬是高的 1.2 倍（照參考圖量）。葉子是葉片卡（一張畫了一簇楓葉的透明圖，兩片交叉）：
    # 分成九個子團塊（八個在樹冠殼上、一個在頂）再加中心一塊填滿，外緣凹凸但裡面不透空；卡片大小差 1.4 倍，大致朝外
    c0 = Vector((0, 0, 5.9))
    for k in range(10):
        z = 1 - 2 * (k + 0.5) / 8 if k < 8 else (0.85 if k == 8 else 0.0)
        z = max(min(z, 0.75), -0.8) if k < 8 else z
        a = k * 2.39996
        w = math.sqrt(1 - z * z) * (k != 9)
        cc = c0 + Vector((w * math.cos(a) * 2.1, w * math.sin(a) * 2.1, z * 2.1))
        core(bm, cc, 0.45, 2, sq=(1, 1, 0.85))   # 每團一顆暗色的芯（卡片的 45%），卡片貼著芯的表面：團裡不透空、輪廓是圓的
        on_core(bm, cc, 0.55, 28, 1.55, 1, rnd, sq=(1, 1, 0.85), spread=0.2, push=0.05, cross=False, fan=55)   # 葉子往外翻開
    # 頂端中央補三團（最高點是一個圓鈍的尖頂，不會中間凹下去像愛心），70% 高度正面再補一團填洞
    for off in ((-0.7, 0, 2.0), (0, 0, 2.4), (0.7, 0, 2.0), (0.5, -0.9, 1.0)):
        q = c0 + Vector(off) + Vector((0, rnd.uniform(-0.3, 0.3), 0))
        core(bm, q, 0.4, 2)
        on_core(bm, q, 0.5, 15, 1.4, 1, rnd, spread=0.2, push=0.05, cross=False, fan=55)
    return obj('TreeMaple', bm, ms)


def pine():
    rnd.seed(22)
    # 葉簇是松針的葉片卡（一撮往外放射的松針），裡面墊一顆暗色實心的芯：卡片之間看進去不會透空
    ms = mats(('tree_bark_pine', PINE_BARK), ('tree_pine_leaf', PINE_CORE)) + [card_material('tree_leafcard_pine', 'leaf_pine.png')]
    bm = bmesh.new()
    H = 11.0
    top, d, r = trunk(bm, H * 0.82, 0.46, lean=0.0, twist=15)   # 不斜：斜了上段整片偏一邊，像問號
    # 枝：從 30% 高度往上一圈圈伸出，越高越短，接近水平微微往上；枝端一團壓扁的葉團，枝中段再一團小的
    tiers = 8
    idx = 0
    PA, PB, PC = 1.15, 0.95, 1.3   # 枝長補償（全部、58~72% 高度、72% 以上）：自動試幾組、量預覽圖的輪廓挑出來的
    for t in range(tiers):
        f = t / (tiers - 1)
        n = 3   # 24 團：團太少的話一根枝伸長整個輪廓就歪
        for i in range(n):   # 每層繞樹幹亂轉、每簇高度錯開 ±30% 層距
            # 先決定雲團（枝端）在哪個高度，再倒推枝從樹幹哪裡長出來：枝往上斜，雲團會比枝根高
            zt = H * (0.3 + 0.6 * f) + rnd.uniform(-0.3, 0.3) * H * 0.6 / (tiers - 1)
            idx += 1
            yaw = idx * 2.39996 + rnd.uniform(-0.2, 0.2)   # 團依序用黃金角轉開：團數少，亂轉的話輪廓會一邊大一邊小
            out = Vector((math.cos(yaw), math.sin(yaw), 0))
            # 整棵照參考圖量出來的輪廓：最寬是樹高 0.75 倍、在 45~50% 高度；以最寬為 1，70% 高 0.77、80% 高 0.52、90% 高 0.28。
            # 水平伸出 = 那個高度的半寬扣掉雲團半徑，雲團外緣剛好落在輪廓上
            w = 0.72 * (1.2 - 0.45 * f) * 1.64   # 團寬約樹高的 0.18，團跟團之間留得出縫
            prof = float(np.interp(zt / H, (0.25, 0.35, 0.47, 0.6, 0.7, 0.8, 0.9, 1.0), (0.55, 0.85, 1.0, 0.9, 0.77, 0.52, 0.28, 0.08)))
            if zt / H > 0.72:   # 上段的團小一點：團太大，80% 高度的寬度會被團本身撐開
                w *= 0.55
            reach = max(0.25, H * 0.375 * prof * rnd.uniform(0.9, 1.0) - w * 1.2)
            # 枝朝四面八方長，朝前後的枝投影到畫面上會變短：量預覽圖的寬度再補回來（全部 ×1.22，55~72% 高度再 ×1.25、72% 以上 ×0.8（雲團比枝端高，畫面上會往上移一截），量過預覽圖定的）
            reach *= PA * (PB if 0.58 <= zt / H <= 0.72 else (PC if zt / H > 0.72 else 1.0))
            reach *= 0.8 if 0.5 <= zt / H < 0.58 else (1.12 if 0.36 <= zt / H < 0.5 else 1.0)   # 最寬處壓在 42~52% 高度（雲團在畫面上比 zt 高一截）
            el = math.radians(25)   # 枝往上斜 25 度，末段再往上彎 10 度：不會像梯子的橫桿
            L = reach / math.cos(el)
            z = min(max(zt - L * (math.sin(el) + 0.3 * math.sin(math.radians(10))), H * 0.22), H * 0.8)
            p0 = Vector((0, 0, z))
            pts = bend(p0, p0 + (out * math.cos(el) + Vector((0, 0, math.sin(el)))) * L, 3, 0.12)
            pts[-1] = pts[-1] + Vector((0, 0, L * 0.3 * math.sin(math.radians(10))))
            limb(bm, pts, [0.12 * (1.3 - f), 0.1 * (1.3 - f), 0.07, 0.05], 5, 0)
            side = Vector((-out.y, out.x, 0))
            # 三顆扁雲片（暗色實心的芯），每顆表面貼幾組短松針的葉片卡：讀起來是一片圓潤、表面有細紋的扁雲
            # 每根枝一團雲（枝端一大顆、往內一小顆靠在一起），團跟團之間留縫、看得到枝條和樹幹；枝的末端藏在團裡
            for tt, dy, dz, k in ((1.0, 0, 0.3, 1.2),):   # 每根枝一團，團跟團之間才有縫
                q = p0.lerp(pts[-1], tt) + side * dy * w + Vector((0, 0, dz))
                gr = w * k * rnd.uniform(0.9, 1.1)
                sq = (1.05, 1.05, 0.6)   # 圓蓬蓬的團（參考圖的松樹是一團團圓的葉簇，不是扁盤）
                core(bm, q, gr * 0.45, 1, sq, subdiv=1)   # 芯是卡片的 35%，蓋得住
                on_core(bm, q, gr * 0.45, 16, gr * 1.3, 2, rnd, spread=0.1, sq=sq, top=0.7, up=0.6, cross=False, push=0.05, bottom=0.3, fan=35)   # 上圓下平的一團，葉子微微往外翻開
    # 尖頂：四簇往上疊（第一簇偏一邊、在 83% 高度，補起頂團下面那段只看得到樹幹的「脖子」），其他對準樹幹軸線
    for k, (off, rr) in enumerate((((0.5, 0.3, -0.1), 0.75), ((0, 0, 0.4), 1.0), ((0, 0, 1.0), 0.9), ((0, 0, 1.55), 0.55))):
        q = top + Vector(off)
        core(bm, q, rr * 0.65, 1, (1.1, 1.1, 0.35), subdiv=1)   # 頂團的芯小一點，頂上才不會露出一片灰色平面
        on_core(bm, q, rr * 0.72, 10, rr * 1.25, 2, rnd, spread=0.1, sq=(1.1, 1.1, 0.35), top=0.7, up=0.6, cross=False, push=0.05, bottom=0.3, fan=35)
    return obj('TreePine2', bm, ms)


def joshua():
    rnd.seed(23)
    ms = mats(('tree_bark_joshua', BARK),) + [card_material('tree_leafcard_yucca', 'leaf_yucca.png')] + mats(('tree_leaf_yucca_dead', YUCCA_DEAD))
    bm = bmesh.new()
    top, d, r = trunk(bm, 1.7, 0.48, flare=1.3, bends=0.12)
    tips = []
    cfg = {'kids': 2, 'spread': 34, 'shrink': 0.78, 'rshrink': 0.7, 'wob': 0.35, 'up': 0.35, 'taper': 0.85, 'tip': 0.85}
    for i in range(4):   # 四根主枝各分兩次 → 約 14 顆刺球（有的枝會分三根）
        yaw = i / 4 * math.tau + rnd.uniform(-0.3, 0.3)
        branch(bm, top - d * 0.2, Vector((math.cos(yaw) * 1.2, math.sin(yaw) * 1.2, 1)), 1.6, r * 0.55, 2, cfg, tips)
    # 每個枝端：一球放射狀的尖葉（往上、往外多，往下少），底下一圈往下垂的枯葉
    for p, dd, rr in tips:
        c = p + dd * 0.15
        for k in range(3):   # 三組放射尖葉的葉片卡，方向亂轉：從哪個角度看都是一球刺
            card(bm, c, Vector([rnd.uniform(-1, 1) for _ in range(3)]) + Vector((0, 0, 0.3)), 1.35, 1, c, rnd)
        for k in range(10):
            a = k / 10 * math.tau
            v = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -1))
            spike(bm, c - dd * 0.15 + v.normalized() * 0.1, v, 0.4, 0.08, 2)
    return obj('TreeJoshua', bm, ms)


def dead():
    rnd.seed(24)
    ms = mats(('tree_bark_dead', DEAD_BARK),)
    bm = bmesh.new()
    top, d, r = trunk(bm, 3.4, 0.72, bends=0.45, twist=25, flare=1.2, roots=False)
    # 五條往外張的根（長是樹幹直徑的 0.6~0.9 倍），根跟根之間有缺口
    for i in range(5):
        a = i / 5 * math.tau + rnd.uniform(-0.25, 0.25)
        o = Vector((math.cos(a), math.sin(a), 0))
        L = 2 * r * rnd.uniform(0.6, 0.9)
        z0 = rnd.uniform(0.5, 0.9)   # 每條從不同高度、貼著樹幹表面斜斜長出來，不會在同一高度圍成一圈
        limb(bm, [o * r * 0.7 + Vector((0, 0, z0)), o * (r * 1.05 + L * 0.3) + Vector((0, 0, z0 * 0.25)), o * (r + L) + Vector((0, 0, -0.05))],
             [r * 0.22, r * 0.17, r * 0.05], 5, 0)
    tips = []
    cfg = {'kids': (2, 2, 3), 'spread': 40, 'shrink': 0.62, 'rshrink': 0.5, 'wob': 0.25, 'up': 0.05, 'taper': 0.62,
           'tip': 0.12}   # 不長側枝：側枝朝鏡頭時看起來是一根根短刺
    mains = []
    for i in range(3):
        yaw = i / 3 * math.tau + rnd.uniform(-0.3, 0.3)
        mains.append(branch(bm, top - d * 0.2, Vector((math.cos(yaw) * 1.0, math.sin(yaw) * 1.0, 1)), 2.8, r * 0.7, 2, cfg, tips,
                            kink=math.radians(18) if i == 1 else 0.0))
    # 預覽（轉 20 度、從 -Y 看）裡最左邊那根已經夠密，另外兩根加側枝
    side_x = lambda q: q.x * math.cos(math.radians(20)) - q.y * math.sin(math.radians(20))
    left = min(mains, key=lambda q: side_x(q[-1]))
    for pts in mains:
        if pts is left:
            continue
        # 另外兩根主枝各在 45%、70% 長一根側枝（母枝 35~45%）：往上仰 50~70 度幾乎往上長，
        # 從哪個水平角度看都是一根往上的枝，不會縮成一根短刺或躲到後面
        myaw = math.atan2(pts[-1].y - pts[0].y, pts[-1].x - pts[0].x)
        for t, sgn in ((0.45, 1), (0.7, -1)):
            sy = myaw + sgn * math.radians(rnd.uniform(60, 120))
            el = math.radians(rnd.uniform(50, 70))
            q = pts[1].lerp(pts[2], (t - 0.33) * 3) if t < 0.66 else pts[2].lerp(pts[3], (t - 0.66) * 3)
            branch(bm, q, Vector((math.cos(sy) * math.cos(el), math.sin(sy) * math.cos(el), math.sin(el))),
                   2.8 * rnd.uniform(0.35, 0.45), r * 0.7 * 0.45, 0, cfg, tips)
    return obj('TreeDead', bm, ms)


def strand(bm, p, L, w, out, mi, bulge=0.3, nc=None):
    """一條垂枝：柳條的長條葉片卡（貼圖是一根細枝兩側交錯長柳葉），分 4 節往下掛、中段微微往外鼓。
    寬是 w 的 5.2 倍（貼圖並排三條柳條）；nc 是法線的中心（樹冠中心）"""
    pts = [p + out * (bulge * math.sin(math.pi * t * 0.75)) + Vector((0, 0, -L * t)) for t in (k / 4 for k in range(5))]
    side = Vector((-out.y, out.x, 0)) if out.length > 1e-6 else Vector((1, 0, 0))
    ribbon(bm, pts, w * 5.2, side, mi, nc if nc is not None else p - out)   # 一張卡並排三條柳條


def willow():
    rnd.seed(25)
    # 垂枝是柳條的葉片卡；圓丘是暗一點的實心體，墊在垂枝後面撐出圓頂的體積
    ms = mats(('tree_bark_willow', BARK), ('tree_leaf_willow', tuple(x * 0.7 for x in WILLOW))) + [card_material('tree_leafcard_willow', 'leaf_willow.png')]
    bm = bmesh.new()
    H = 9.0
    top, d, r = trunk(bm, 4.0, 0.45, lean=0.9, bends=0.35)   # S 形往一邊斜，主軸偏約樹高 10%
    tips = []
    for i in range(4):
        yaw = i / 4 * math.tau + rnd.uniform(-0.3, 0.3)
        branch(bm, top - d * 0.2, Vector((math.cos(yaw) * 0.9, math.sin(yaw) * 0.9, 1)), 2.2, r * 0.6, 1,
               {'kids': 2, 'spread': 30, 'shrink': 0.7, 'rshrink': 0.6, 'up': 0.2}, tips)
    # 傘形樹冠：頂上六個低矮圓丘（高約樹冠寬 8%），外面一圈圈垂枝。垂枝位置亂偏間距的四成、長度 ±25%，
    # 起點越外圈越低；中段往外鼓（鐘形），最寬處在樹冠頂以下約四成，比頂部寬 15%。外圈垂到 15~27% 高度
    R, ztop = 3.3, H - 0.5
    c = Vector((top.x, top.y, 0))
    nc0 = Vector((top.x, top.y, ztop - 2.0))   # 垂枝法線的中心
    # 實心圓丘（跟葉子同色）鋪滿樹冠：外圈九顆、內圈四顆、中間一顆。垂條從圓丘表面披下來把它蓋住，
    # 頂部輪廓是一串圓弧，垂條之間的縫看進去是圓丘不是空的
    start_z = lambda f: ztop - 0.3 - 2.2 * f * f   # 樹冠頂的圓弧：圓丘和垂條起點都照這條
    mounds = []
    # 三圈都照 start_z 的圓弧擺高度，側面看頂部是一條連續的圓弧；外圈放在 75% 半徑，外緣蓋過最外面的垂條起點
    for n, fm, rr0 in ((9, 0.75, 0.57), (7, 0.58, 0.6), (5, 0.4, 1.0), (1, 0.0, 1.1)):   # 外圈圓丘小：外緣不會凸起成台階；58% 那圈補中間的凹口
        for k in range(n):
            a = k / n * math.tau + rnd.uniform(-0.2, 0.2)
            rr = rr0 * rnd.uniform(0.95, 1.1)
            hh = rr * 0.5
            q = c + Vector((math.cos(a), math.sin(a), 0)) * R * fm
            q.z = start_z(fm) + 0.4 * hh
            gem(bm, q, rr * 0.35, 1, cuts=0, jit=0.08, sq=(1, 1, 0.45))   # 實心的芯很小、顏色最暗，整個藏在短垂枝後面
            mounds.append((q, rr, hh))
            for j in range(10 if fm == 0 else (7 if fm == 0.4 else 5)):   # 圓丘表面鋪一層短垂條（長約樹冠高 12~18%）往外往下披，把圓丘蓋住：頂部讀起來是垂條不是實心體
                u = math.sqrt(rnd.random()) * 0.9
                aa = rnd.uniform(0, math.tau)
                sp = q + Vector((math.cos(aa), math.sin(aa), 0)) * rr * u
                sp.z = q.z + hh * math.sqrt(1 - u * u) + 0.02
                o = (sp - c).xy.to_3d()
                strand(bm, sp, rnd.uniform(0.8, 1.2), 0.2, o.normalized() if o.length > 0.1 else Vector((1, 0, 0)), 2, bulge=0.3, nc=nc0)
    n = 101
    for i in range(n):
        f = 0.35 + 0.65 * math.sqrt((i + 0.5) / n) + rnd.uniform(-0.06, 0.06)
        a = i * 2.39996 + rnd.uniform(-0.2, 0.2)
        # 正面（-Y 偏 20 度，預覽的視角）外圈留兩三道縫，露出樹幹
        if f > 0.8 and any(abs((math.degrees(a) - g + 180) % 360 - 180) < 9 for g in (-118, -80)):
            continue
        if math.sin(a + math.radians(20)) > 0 and rnd.random() < 0.33:   # 背面（預覽看不到的那半邊）砍三成：約 95 條、六成在正面
            continue
        out = Vector((math.cos(a), math.sin(a), 0))
        p = c + out * R * f
        # 起點在六個低圓丘的曲面上：整體往外降成圓頂，再疊上六瓣的起伏（高約樹冠寬 8%）
        p.z = start_z(f) + rnd.uniform(-0.1, 0.1)
        for q, rr, hh in mounds:   # 在圓丘上面就從圓丘表面開始披
            d2 = ((p.xy - q.xy).length / rr) ** 2
            if d2 < 1:
                p.z = max(p.z, q.z + hh * math.sqrt(1 - d2) - 0.2)   # 起點藏在短垂條層底下

        if f > 0.82:   # 外圈垂到 15~25% 高度，越外圈越短一點：下緣往內收的弧
            L = (p.z - H * (0.15 + 0.6 * (f - 0.82))) * rnd.uniform(0.8, 1.0)
        else:
            L = (1.2 + 3.0 * (f - 0.35)) * rnd.uniform(0.55, 1.0)
        strand(bm, p, L, 0.23, out, 2, bulge=0.55 * f, nc=nc0)
    # 正面（預覽視角）的 14 條長垂條掛在 35~60% 半徑：擋在樹幹和主枝正前方，正中間只剩兩道窄縫
    for i in range(14):
        a = math.radians(-110 + rnd.uniform(-45, 45))
        if any(abs((math.degrees(a) - g + 180) % 360 - 180) < 4 for g in (-118, -80)):
            a += math.radians(9)
        f = rnd.uniform(0.35, 0.6)
        out = Vector((math.cos(a), math.sin(a), 0))
        p = c + out * R * f
        p.z = start_z(f) - 0.2
        strand(bm, p, (p.z - H * rnd.uniform(0.2, 0.3)), 0.23, out, 2, bulge=0.55 * f, nc=nc0)
    return obj('TreeWillow', bm, ms)


def preview(obs, oak, path):
    """照參考圖的 3×2 排：上排闊葉樹、楓樹、松樹，下排約書亞樹、枯樹、柳樹。每棵縮放成一樣高，跟參考圖比形狀"""
    spots = [(8.5, 21.6), (27.5, 21.6), (47.5, 21.6), (8.5, 1.9), (27.5, 1.9), (47.5, 1.9)]
    for o, (x, z) in zip([oak] + obs, spots):
        c = o.copy()
        bpy.context.scene.collection.objects.link(c)
        s = 15.8 / o.dimensions.z
        c.scale = (s, s, s)
        c.location = (x, 0, z)
        c.rotation_euler = (0, 0, math.radians(20))
        # 有葉片卡的樹不投影子：遊戲裡葉片卡不接收影子（main.gd 的 _flatten_models），不然一層層互遮，整個樹冠裡面全黑
        c.visible_shadow = not any('leafcard' in m.name for m in o.data.materials)
    for o in [oak] + obs:
        o.hide_render = True
    studio(path, 60, (30, -60, 20), (1680, 1120))



def build_all():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return [maple(), pine(), joshua(), dead(), willow()]


def preview_all(trees, path):
    tree.MATS = tree.materials()   # 闊葉樹（tree.py 建）也放進來一起對照
    preview(trees, tree.build('TreeOak', tree.SIZES['TreeOak']), path)


if __name__ == '__main__':
    pipeline.run(build_all, preview_all, budget=8000)
