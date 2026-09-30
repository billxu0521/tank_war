# 荒野的矮植物（docs/image/plante.png 左邊兩區：仙人掌、荒草叢），匯出成 floras.glb：
#   Saguaro / SaguaroS   柱狀仙人掌大（5 公尺）小（2.6 公尺）：八條稜（稜頂亮一階）、圓頂、U 形彎肘的手臂、稜上黃刺
#   BarrelCactus         扁球形仙人掌，十二條深稜，頂上一朵兩層花瓣的橘紅花
#   PricklyPear          仙人掌片：九片扁橢圓掌片一片接一片長，頂緣有紅果和花
#   GrassTall            高的乾草叢：寬的矛尖葉，外圈往外彎、最外幾片垂下來
#   GrassDense           矮密的乾草叢：寬的圓丘，內高外低
#   GrassSmall           小草叢：往外張的扇形
#   DesertBush           葉子灌木：十幾根紅褐色枝條從底部放射出去，兩側對生菱形葉
#   ScrubBush            橘黃褐的矮丘，短寬、頭鈍的葉片
# 草葉分三段三種顏色：葉根黃綠、中段、葉尖淺黃褐。
# 原點在底部中央、尺寸是實際公尺；草和灌木沒碰撞、會用 MultiMesh 撒很多，每叢 1000 個三角形以內。
# 背景跑：REF=docs/image/flora.png tools/model_iter.sh flora <版號>（flora.png 是 plante.png 左上兩區裁下來的）
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
_src = open(BASE + '/grove.py', encoding='utf-8').read()
exec(_src[:_src.index('\na = args()')])   # grove.py 自己又借了 tree.py：gem、spike、mats、obj、studio……

rnd = random.Random(31)
# 顏色（線性值），比照樹的暗度（參考圖的顏色約乘 0.55）
CACTUS = (0.075, 0.12, 0.03)       # 稜的斜面和溝：暗一階的綠（不能黑）
CACTUS_RIB = (0.11, 0.165, 0.035)   # 稜頂：亮一階、偏黃綠
SPINE = (0.42, 0.33, 0.10)
FLOWER = (0.55, 0.12, 0.02)
FLOWER_C = (0.45, 0.30, 0.03)
FLOWER_P = (0.6, 0.094, 0.018)   # 仙人掌片的花：偏橘（#e0602a）
DRY = ((0.12, 0.15, 0.03), (0.22, 0.19, 0.045), (0.35, 0.24, 0.06))     # 葉根黃綠 → 葉尖淺黃褐
SCRUB = ((0.40, 0.21, 0.058), (0.59, 0.31, 0.084), (0.62, 0.37, 0.10))   # 葉尖往 #e0b060
BUSH = ((0.19, 0.24, 0.04), (0.36, 0.33, 0.06))
STEM = (0.09, 0.03, 0.013)


def ribbed(bm, pts, radii, ribs, mi, mi_rib, groove=0.8, spines=None, spine_len=0.3):
    """稜柱：沿 pts 一圈圈蓋。每條稜三個點：稜頂左右兩點（外圈）夾一條窄的稜頂面（mi_rib，亮一階），
    再往內斜到溝底（groove 倍半徑）。最後一圈留六成半徑、中間一點微微凸起，頂端是圓頂不是尖。
    每圈的方向用平行移動（parallel transport）接下去，轉彎的手臂才不會扭成麻花。
    spines=(材質, 間隔)：沿長度每隔「間隔 × 半徑」在稜頂長一圈小黃刺（照弧長等距）；轉彎處朝彎曲中心那半圈不長"""
    n = ribs * 3
    rings = []
    u = None
    run, next_at = 0.0, 0.0
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = frame(d)[0] if u is None else (u - d * u.dot(d)).normalized()
        v = d.cross(u)
        run += (p - pts[i - 1]).length if i > 0 else 0.0
        spine_here = spines and 0 < i < len(pts) - 1 and run >= next_at
        if spine_here:
            next_at = run + spines[1] * r
        bendv = (pts[min(i + 1, len(pts) - 1)] - p) - (p - pts[max(i - 1, 0)])   # 指向彎曲中心
        ring = []
        for k in range(n):
            rib, part = divmod(k, 3)
            a = (rib + (-0.12, 0.12, 0.5)[part]) / ribs * math.tau
            o = u * math.cos(a) + v * math.sin(a)
            ring.append(bm.verts.new(p + o * r * (groove if part == 2 else 1.0)))
            ao = (rib / ribs) * math.tau
            oo = u * math.cos(ao) + v * math.sin(ao)
            if spine_here and part == 0 and not (bendv.length > r * 0.05 and oo.dot(bendv.normalized()) > 0.2):
                tipv = p + oo * r * 0.97 + (oo + d * 0.35).normalized() * r * spine_len
                for w in (oo.cross(d).normalized() * r * 0.05, d * r * 0.05):   # 兩片十字交叉的三角形：從哪個角度看都看得到
                    bm.faces.new((bm.verts.new(p + oo * r * 0.97 + w), bm.verts.new(p + oo * r * 0.97 - w), bm.verts.new(tipv))).material_index = spines[0]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            f = bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
            f.material_index = mi_rib if k % 3 == 0 else mi
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.3)
    for k in range(n):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % n], tip)).material_index = mi_rib if k % 3 == 0 else mi
    bm.faces.new(list(reversed(rings[0]))).material_index = mi


def column(z0, H, R, steps, top=0.2):
    """直柱＋圓頂：回傳 (點, 半徑)。直的部分分 steps 段；頂上 top 比例的高度是圓頂：60% 處半徑 80%、最上面 40%"""
    straight = H * (1 - top)
    pts = [Vector((0, 0, z0 + straight * i / steps)) for i in range(steps + 1)]
    rr = [R] * (steps + 1)
    for f, k in ((0.6, 0.8), (1.0, 0.4)):
        pts.append(Vector((0, 0, z0 + straight + H * top * f)))
        rr.append(R * k)
    return pts, rr


def arm(bm, base, out, reach, rise, R):
    """仙人掌的手：從主幹側面往上斜 20 度伸出，圓順的 U 形彎肘（半徑 1.5 倍手臂粗、分五段）轉成直的，再往上長 rise"""
    bendr = R * 1.5
    straight = max(reach - bendr, 0.05)
    up = Vector((0, 0, 1))
    pts, rr = [base, base + (out * math.cos(0.35) + up * math.sin(0.35)) * straight], [R, R]
    for i in range(1, 6):   # 方向從仰角 20 度轉到 90 度，每段走一小段弧長
        a = math.radians(20 + 70 * (i - 0.5) / 5)
        pts.append(pts[-1] + (out * math.cos(a) + up * math.sin(a)) * bendr * math.radians(14))
        rr.append(R)
    q, r2 = column(0, rise, R, 3, top=0.35)
    elbow = pts[-1]
    for p, r in zip(q[1:], r2[1:]):
        pts.append(elbow + p)
        rr.append(r)
    ribbed(bm, pts, rr, 8, 0, 1, spines=(2, 1.0))


def saguaro(name, H, R, arms, seed):
    rnd.seed(seed)
    ms = mats(('flora_cactus', CACTUS), ('flora_cactus_rib', CACTUS_RIB), ('flora_spine', SPINE))
    bm = bmesh.new()
    pts, rr = column(-0.1, H + 0.1, R, int(H * 2.2), top=0.1)
    ribbed(bm, pts, rr, 8, 0, 1, spines=(2, 1.0))
    for h, yaw, reach, rise, k in arms:   # (接點高度比例, 方位, 水平伸出, 往上長, 手臂粗細對主幹)
        out = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0))
        arm(bm, Vector((0, 0, H * h)) + out * R * 0.5, out, reach, rise, R * k)
    return obj(name, bm, ms)


def barrel():
    rnd.seed(33)
    ms = mats(('flora_cactus_b', CACTUS), ('flora_cactus_b_rib', CACTUS_RIB), ('flora_spine_b', SPINE),
              ('flora_flower', FLOWER), ('flora_flower_c', FLOWER_C))
    bm = bmesh.new()
    R = 0.42
    H = 0.9 * 2 * R   # 扁球：高是寬的 0.9；最寬在一半高度，底部收到 75%，頂上收到 35%
    pts, rr = [], []
    for i in range(11):
        t = i / 10
        e = ((t - 0.5) / 0.5) ** 2
        pts.append(Vector((0, 0, -0.04 + H * t)))
        rr.append(R * math.sqrt(1 - e * (0.4375 if t < 0.5 else 0.88)))
    ribbed(bm, pts, rr, 12, 0, 1, groove=0.74, spines=(2, 0.3), spine_len=0.15)
    # 頂上的花（寬約本體四成）：外層八片、內層六片尖花瓣往外往上張開，中間一顆黃心
    c = pts[-1] + Vector((0, 0, 0.03))
    for ring, (n, el, L, w) in enumerate(((8, 20, 0.21, 0.085), (6, 45, 0.16, 0.07))):   # 外層上翹 20 度（寬約本體四成）、內層 45 度：一團有高度的花
        for k in range(n):
            a = k / n * math.tau + ring * 0.4
            e = math.radians(el)
            petal(bm, c + Vector((0, 0, 0.01 * ring)), Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))), L, w, 3)
    gem(bm, c + Vector((0, 0, 0.04)), 0.05, 4, cuts=0)
    return obj('BarrelCactus', bm, ms)


def petal(bm, c, d, L, w, mi):
    """一片圓頭寬花瓣：五邊形（根、兩側最寬、頭留 40% 寬），三個三角形，面朝上（雙面材質）"""
    d = d.normalized()
    side = d.cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    vs = [bm.verts.new(c + d * L * t + side * w * k) for t, k in ((0, 0), (0.55, -1), (1, -0.4), (1, 0.4), (0.55, 1))]
    bm.faces.new(vs).material_index = mi


def flower(bm, c, up, s, mi):
    """一朵小花：六片圓頭花瓣從 c 往外、往上翹 30 度"""
    u, v = frame(up)
    for k in range(6):
        a = k / 6 * math.tau
        petal(bm, c, up * 0.58 + u * math.cos(a) + v * math.sin(a), s, s * 0.5, mi)


def pad(bm, m, w, h, mi):
    """一片仙人掌掌片：外圈 10 點的橢圓（半寬 w、半高 h），正反面各一條直的中稜凸起（厚是寬的 25%），
    所以每面是左右兩大片斜面。m 是掌片的位置和朝向"""
    ring = [bm.verts.new(m @ Vector((math.cos(i / 10 * math.tau) * w, 0, math.sin(i / 10 * math.tau) * h))) for i in range(10)]
    for side in (1, -1):
        A = bm.verts.new(m @ Vector((0, side * w * 0.25, h * 0.45)))
        B = bm.verts.new(m @ Vector((0, side * w * 0.25, -h * 0.45)))
        faces = [(ring[i], ring[i + 1], A) for i in range(5)] + [(ring[i], ring[(i + 1) % 10], B) for i in range(5, 10)]
        faces += [(ring[0], A, B), (ring[5], B, A)]
        for f in faces:
            f = f if side < 0 else f[::-1]
            bm.faces.new(f).material_index = mi


def pear():
    rnd.seed(34)
    ms = mats(('flora_cactus_p', CACTUS), ('flora_spine_p', SPINE), ('flora_flower_p', FLOWER_P))
    bm = bmesh.new()
    # 九片掌片：(接在哪一片, 從那片的正上方偏幾度長出來, 半高)。底下兩片最大，往上一片比一片小。
    # 子片的底部插進母片邊緣 15%，片跟片接在一起
    spec = [(-1, 0, 0.3), (0, -28, 0.26), (0, 25, 0.25), (1, -5, 0.2), (1, 30, 0.19), (2, 10, 0.19),
            (2, -25, 0.18), (0, 70, 0.22), (3, -15, 0.15)]
    pads = []
    for parent, ang, h in spec:
        yaw = rnd.uniform(-25, 25)
        if parent < 0:
            c, tilt = Vector((0, 0, h * 0.95)), 0.0
        else:
            pc, pt, ph, _ = pads[parent]
            tilt = pt + ang
            dvec = Vector((math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
            pw = ph / 1.3   # 母片在那個方向的半徑（橢圓），子片沿自己的長軸：兩片邊緣疊 15%
            prad = 1 / math.sqrt((math.sin(math.radians(ang)) / pw) ** 2 + (math.cos(math.radians(ang)) / ph) ** 2)
            c = pc + dvec * (prad * 0.85 + h * 0.85)
        pads.append((c, tilt, h, yaw))
        m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(tilt), 4, 'Y')
        w = h / 1.3
        pad(bm, m, w, h, 0)
        for k in range(8):   # 片面上的刺點
            a = rnd.uniform(0, math.tau)
            fy = rnd.choice((-1, 1))
            nrm = (m.to_3x3() @ Vector((0, fy, 0))).normalized()
            spike(bm, m @ Vector((math.cos(a) * w * 0.55, fy * w * 0.14, math.sin(a) * h * 0.55)), nrm, 0.04, 0.009, 1)
        if h < 0.21:   # 上面幾片的頂緣：紅果或花
            up = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
            side = (m.to_3x3() @ Vector((1, 0, 0))).normalized()
            for k in range(rnd.randint(1, 2)):   # 頂緣一兩朵花，直徑約掌片寬的 35%
                p = c + up * h * 0.95 + side * rnd.uniform(-0.4, 0.4) * w
                flower(bm, p, up, w * 0.6, 2)
    return obj('PricklyPear', bm, ms)


def blade(bm, base, out, L, w, lean, curve, mis, blunt=0.0, thick=0.3):
    """一根草葉：三段三種顏色（mis 由根到尖），最寬在 30% 長度處，往上收尖（blunt > 0 時葉尖留那麼寬、頭鈍）。
    葉子從垂直往 out 方向斜 lean 度，越往上越彎（尖端再多彎 curve 度）。斷面是扁三角，從哪面看都不會消失"""
    cuts = (0.0, 0.3, 0.65, 1.0)
    wid = (0.55, 1.0, 0.7, blunt)
    up = Vector((0, 0, 1))
    side = up.cross(out).normalized()
    pts, p = [base], base
    for i in range(1, 4):
        a = math.radians(lean + curve * cuts[i] ** 1.5)
        p = p + (up * math.cos(a) + out * math.sin(a)) * L * (cuts[i] - cuts[i - 1])
        pts.append(p)
    rings = []
    for i, (q, k) in enumerate(zip(pts, wid)):
        if k == 0:
            rings.append([bm.verts.new(q)])
            continue
        nrm = (pts[min(i + 1, 3)] - pts[max(i - 1, 0)]).normalized().cross(side)
        rings.append([bm.verts.new(q + side * w * k), bm.verts.new(q - side * w * k), bm.verts.new(q + nrm * w * k * thick)])
    for i, (a, b) in enumerate(zip(rings, rings[1:])):
        for j in range(3):
            if len(b) == 1:
                bm.faces.new((a[j], a[(j + 1) % 3], b[0])).material_index = mis[i]
            else:
                bm.faces.new((a[j], a[(j + 1) % 3], b[(j + 1) % 3], b[j])).material_index = mis[i]
    if len(rings[-1]) == 3:   # 鈍頭：中間多一個點微微凸起成淺尖，不是一刀平切
        d3 = (pts[3] - pts[2]).normalized()
        apex = bm.verts.new(pts[3] + d3 * w * blunt * 1.2)
        for j in range(3):
            bm.faces.new((rings[-1][j], rings[-1][(j + 1) % 3], apex)).material_index = mis[2]


def tuft(name, n, L, lean, w, curve, colors, seed, core=0.1, outer=1.0, blunt=0.0, droop=0, maxang=65, jit=5, short=1.0, thick=0.3,
         squash=1.0, crown=1.0):
    """草叢：n 根葉子，由中心往外（f 從 0 到 1）越來越斜（lean 範圍）、越來越彎、長度乘到 outer 倍；
    最外 droop 根多彎 45 度垂下來（長度乘 short）。葉尖離垂直不超過 maxang 度；jit 是每根傾斜的亂數。
    crown：中心前四根的長度倍率（中間最高）；squash：整叢水平方向縮放（高度不動）"""
    rnd.seed(seed)
    ms = mats(*[('flora_%s%d' % (name.lower(), i), c) for i, c in enumerate(colors)])
    bm = bmesh.new()
    for i in range(n):
        a = i * 2.39996 + rnd.uniform(-0.2, 0.2)
        f = math.sqrt((i + 0.5) / n)
        out = Vector((math.cos(a), math.sin(a), 0))
        base = out * core * f + Vector((0, 0, -0.03))
        le = lean[0] + (lean[1] - lean[0]) * f + rnd.uniform(-jit, jit)
        cv = min(curve * f + (45 if i >= n - droop else 0), maxang - le)
        ln = L * rnd.uniform(0.6 if jit > 5 else 0.8, 1.0) * (1 + (outer - 1) * f) * (short if i >= n - droop else 1) * (crown if i < 4 else 1)
        blade(bm, base, out, ln, w * rnd.uniform(0.85, 1.15), le, cv,
              (0, 1, 2), blunt, thick)
    for v in bm.verts:
        v.co.x *= squash
        v.co.y *= squash
    return obj(name, bm, ms)


def leaf(bm, base, dvec, side, L, w, mi):
    """一片菱形葉：兩個三角形。材質是雙面的（Blender 預設不剔背面，glTF 匯出 doubleSided），反面也看得到"""
    a, b = bm.verts.new(base), bm.verts.new(base + dvec * L)
    mid = base + dvec * L * 0.4
    l, r = bm.verts.new(mid + side * w), bm.verts.new(mid - side * w)
    f1, f2 = (a, l, b), (a, b, r)
    if (l.co - a.co).cross(b.co - a.co).z < 0:   # 法線朝上：正面受光，不會從上面看到暗的背面
        f1, f2 = (a, b, l), (a, r, b)
    bm.faces.new(f1).material_index = mi
    bm.faces.new(f2).material_index = mi


def desert_bush():
    """二十二根紅褐色枝條從底部放射出去（仰角 20~75 度、末端往上彎），每根兩側各對生七片菱形葉，越往末端越小"""
    rnd.seed(38)
    ms = mats(('flora_bush_leaf0', BUSH[0]), ('flora_bush_leaf1', BUSH[1]), ('flora_bush_stem', STEM))
    bm = bmesh.new()
    dark = lambda: 0 if rnd.random() < 0.3 else 1   # 暗色葉三成
    for i in range(25):   # 前四根在中間直立，接著十六根仰角 10~60 度平均分布（貼地的圓丘，最寬在四成高），最後五根短的補中心和下半部
        a = i * 2.39996
        el = math.radians(82 + rnd.uniform(-5, 5) if i < 4 else (10 + 50 * ((i - 4) / 15) if i < 20 else rnd.uniform(20, 55)))
        out = Vector((math.cos(a), math.sin(a), 0))
        dvec = out * math.cos(el) + Vector((0, 0, math.sin(el)))
        Lb = rnd.uniform(0.75, 1.0) if i < 20 else rnd.uniform(0.4, 0.55)
        o = out * 0.12 * (i >= 4)
        pts = [o + Vector((0, 0, -0.02)), o + dvec * Lb * 0.5, o + dvec * Lb + Vector((0, 0, 0.12))]
        limb(bm, pts, [0.03, 0.02, 0.01], 3, 2)
        bd = (pts[2] - pts[0]).normalized()
        sd = bd.cross(Vector((0, 0, 1))).normalized()
        for k in range(5):
            t = 0.15 + 0.85 * k / 4
            p = pts[0].lerp(pts[1], t * 2) if t < 0.5 else pts[1].lerp(pts[2], t * 2 - 1)
            s = 1.0 - 0.5 * t   # 越往末端越小：外圈的葉子不會戳出輪廓
            for sgn in (1, -1):
                ld = (bd * 0.6 + sd * sgn + Vector((0, 0, 0.35))).normalized()
                ld = Matrix.Rotation(math.radians(rnd.uniform(-60, 60)), 3, bd) @ ld   # 繞枝條亂轉，不要全部平貼同一面
                leaf(bm, p, ld, bd.cross(ld).normalized(), 0.55 * s, 0.14 * s, dark())
        leaf(bm, pts[2], (pts[2] - pts[1]).normalized(), sd, 0.35, 0.1, dark())
    return obj('DesertBush', bm, ms)


def preview(obs, path):
    """照參考圖（1020×480 的裁圖）排：1 像素 = 1 公分，每樣縮放成參考圖裡的高度、底部對齊參考圖的位置"""
    spots = {'Saguaro': (150, 445, 355, 0), 'BarrelCactus': (255, 462, 118, -1), 'SaguaroS': (335, 405, 172, 1),
             'PricklyPear': (440, 462, 130, -1), 'GrassTall': (630, 272, 142, 0), 'DesertBush': (840, 332, 158, 0),
             'GrassDense': (640, 422, 140, 0), 'ScrubBush': (815, 462, 96, 0), 'GrassSmall': (935, 412, 78, 0)}
    for o in obs:
        x, y, h, depth = spots[o.name]
        c = o.copy()
        bpy.context.scene.collection.objects.link(c)
        s = h / 100 / o.dimensions.z
        c.scale = (s, s, s)
        c.location = (x / 100, depth, 4.8 - y / 100)
        c.rotation_euler = (0, 0, math.radians(15))
        o.hide_render = True
    studio(path, 10.2, (5.1, -30, 2.4), (1680, 790))


a = args()
bpy.ops.wm.read_factory_settings(use_empty=True)
plants = [
    # 手臂：(接點高度比例, 方位, 水平伸出, 往上長, 粗細)。左臂接得低、右臂高
    saguaro('Saguaro', 5.0, 0.48, [(0.36, 180, 1.0, 1.4, 0.72), (0.52, 0, 0.8, 1.1, 0.68)], 31),
    saguaro('SaguaroS', 2.6, 0.3, [(0.45, 190, 0.65, 0.55, 0.72), (0.35, -10, 0.6, 0.45, 0.7)], 32),
    barrel(), pear(),
    tuft('GrassTall', 18, 1.0, (0, 25), 0.06, 30, DRY, 35, core=0.1, droop=3, short=0.6),
    tuft('GrassDense', 30, 0.75, (5, 45), 0.055, 20, DRY, 36, core=0.18, outer=0.6, maxang=50),
    tuft('GrassSmall', 18, 0.4, (10, 45), 0.04, 20, DRY, 37, core=0.05, droop=2, short=0.7),
    desert_bush(),
    tuft('ScrubBush', 47, 0.35, (15, 40), 0.048, 10, SCRUB, 39, core=0.3, outer=0.65, blunt=0.3, maxang=40, jit=15, thick=0.1, squash=0.56, crown=1.3),
]
for t in plants:
    print(t.name, 'tris:', sum(len(p.vertices) - 2 for p in t.data.polygons), 'size:', tuple(round(x, 2) for x in t.dimensions))
if a['--out']:
    export(plants, a['--out'])
if a['--preview']:
    preview(plants, a['--preview'])
