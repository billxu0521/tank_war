# 石頭（docs/image/rock.png 的風格）：一塊塊大平面的低多邊形岩石，稜邊有小缺角，紅褐色。
# 單顆和石頭堆共 16 種，照參考圖三排的排法，匯出成 rocks.glb（Rock01..Rock16，原點在底部中央）。
#
# 不用開 Blender 視窗、不用 MCP，直接在背景跑：
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
#       --python blender/rock.py -- --out models/rocks.glb --preview /tmp/rock.png
# 反覆修改時用 tools/model_iter.sh rock <版號>（做法見 docs/程式建模迭代.md）
#
# 造型：在橢球上撒十幾個點取凸包（convex hull），點少面就大；底部壓平坐在地上；
# 再把轉折大的稜邊切一小刀（bevel），就是參考圖邊緣那種小缺角。
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipeline

SEED = 11
PX = 0.01            # 參考圖一像素 = 1 公分：預覽跟參考圖同尺寸同構圖，上下對照對得齊
IMG_W, IMG_H = 1672, 940

# 每顆：(參考圖中心 x 像素, 底部 y 像素, 零件)
# 零件 (相對中心的 x 像素, 寬, 深, 高, 點數, 形狀[, 墊高 px, 前後 px, 個別調整])：前後負的是往鏡頭（前面）
# 個別調整：apex 頂點放在寬度幾成處、press_right 右上角往下壓、lift_right 右半頂部往上抬、
# step 左上壓出一個凹折台階（凸包之後才壓：凸包一定把凹處填平；兩個零件疊則會留一條接縫，v16~v19）
# 形狀：dome 圓頂、wide 寬平頂（頂上還有七成寬）、round 低矮的小圓頂、side 大石旁邊黏的矮副塊（頂往外斜）、wedge 山峰偏一邊的斜坡、
# slab 扁平（邊緣往外變薄）、peak 尖頂、pyramid 三角錐（斜稜是直線）、spire 立石。每顆各自指定，不要一種頂形套全部
# 石頭堆的規則：小石頭擺在大石前面、壓住大石的底部，不是左右並排
ROCKS = [
    # 第一排：大石
    (292, 410, [(0, 610, 440, 355, 18, 'dome', 0, 0, {'step': True})]),   # 左上一個凹折台階             # 左邊黏一塊比較矮的：左上的台階是凹折，單一凸包做不出來（v14、v15）
    (740, 400, [(0, 437, 330, 295, 18, 'wide')]),
    (1156, 400, [(0, 377, 300, 252, 16, 'wedge')]),
    (1500, 400, [(-20, 150, 110, 135, 10, 'round', 0, 120),                 # 撐住上面那顆的石頭：躲在前面那顆正後方（預覽是正面正交，往後移擋不住，v13），只從左邊縫裡露一條
                 (45, 220, 180, 140, 14, 'dome', 0, -40),                  # 右前方的下面那顆
                 (-20, 320, 180, 144, 14, 'dome', 120, 35)]),             # 疊在上面的扁長大石：右端壓在前面那顆上
    # 第二排：單顆
    (152, 615, [(0, 255, 210, 177, 16, 'dome')]),
    (466, 615, [(0, 303, 230, 130, 14, 'slab')]),
    (767, 615, [(-10, 230, 200, 185, 14, 'peak')]),
    (1030, 615, [(0, 225, 180, 150, 14, 'dome', 0, 0, {'apex': 0.48, 'press_right': True})]),
    (1254, 615, [(0, 152, 130, 112, 12, 'dome')]),
    (1440, 610, [(0, 165, 130, 100, 10, 'pyramid')]),   # 小三角錐
    (1602, 610, [(0, 100, 85, 65, 10, 'round')]),
    # 第三排：石頭堆
    (215, 845, [(0, 200, 170, 185, 14, 'peak'), (-120, 120, 100, 80, 12, 'round', 0, -20),
                (105, 110, 95, 80, 12, 'round', 0, 60), (80, 95, 80, 62, 10, 'round', 0, -75)]),
    (590, 830, [(-30, 200, 150, 117, 14, 'round'), (95, 125, 105, 85, 12, 'round', 0, -20),
                (-120, 90, 80, 55, 10, 'round', 0, -30), (0, 42, 36, 26, 8, 'round', 0, -95)]),
    (915, 835, [(15, 163, 120, 90, 12, 'dome', 0, 0, {'apex': 0.42, 'lift_right': True}), (-80, 70, 60, 45, 10, 'round', 0, -30),
                (80, 60, 50, 38, 8, 'round', 0, -30), (-15, 65, 55, 48, 8, 'round', 0, -85),
                (40, 35, 30, 25, 8, 'round', 0, -95)]),
    (1220, 840, [(-25, 170, 140, 75, 14, 'slab'), (60, 110, 90, 70, 12, 'round', 0, 30),
                 (22, 95, 80, 60, 10, 'round', 0, -80), (-110, 60, 50, 38, 10, 'round', 0, -30),
                 (125, 80, 70, 55, 10, 'round', 0, -40), (95, 20, 18, 14, 8, 'round', 0, -95),
                 (165, 13, 12, 10, 8, 'round', 0, -80)]),
    (1520, 845, [(25, 160, 120, 160, 12, 'spire'), (-65, 80, 70, 60, 10, 'round', 0, -30),
                 (85, 45, 40, 35, 8, 'round', 0, -30), (70, 45, 40, 38, 8, 'round', 0, 60),
                 (55, 35, 30, 22, 8, 'round', 0, -80)]),
]

FOLD = 0.025    # 大面裡加的點往外推多遠（對石頭最小邊長）：大面微微折開。全面加點（v5、v6）面會大小平均，變成蛋
CHAMFER = 0.035 # 每個角往鄰點拉多遠：稜邊的小折面。不用 bevel，bevel 在凸包上會切出凹痕（v1、v2）
BAND = 0.04     # 主稜（夾角 > 25 度）的倒角寬度（對石頭最小邊長）：主稜要軟，明暗有一段過渡
CHIP = 0.045    # 稜線上 15% 的角拉多一點當缺角。拉 9% 會切出窄長斜面，側光下像大面中間凹一塊（v6）

# 圓頂的寬度曲線 [(高度比例, 寬度倍率)]：25% 高最寬，往上緩緩收。round 是小石頭，收得更多
DOME = [(0.0, 1.0), (0.25, 1.0), (0.6, 0.88), (0.85, 0.7), (1.0, 0.45)]
ROUND = [(0.0, 1.0), (0.05, 1.0), (0.6, 0.88), (0.85, 0.65), (1.0, 0.4)]
WIDE = [(0.0, 1.0), (0.25, 1.0), (0.6, 0.95), (0.85, 0.85), (1.0, 0.7)]   # 寬平頂：收得少，頂上還有七成寬
SIDE = [(0.0, 1.0), (0.25, 1.0), (0.6, 0.9), (0.85, 0.7), (1.0, 0.5)]    # 大石旁邊黏的矮副塊
CURVES = {'dome': DOME, 'round': ROUND, 'wide': WIDE, 'side': SIDE}


def profile(f, curve):
    for (f0, k0), (f1, k1) in zip(curve, curve[1:]):
        if f <= f1:
            return k0 + (k1 - k0) * (f - f0) / (f1 - f0)
    return curve[-1][1]


rng = random.Random(SEED)


def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = 1.0
    for key in ('Specular IOR Level', 'Specular'):   # 不要高光：會把受光面沖白，吃掉折面的明暗差
        if key in p.inputs:
            p.inputs[key].default_value = 0.0
    m.diffuse_color = (*rgb, 1)
    return m


def stone(bm, x, y, w, d, h, n, shape, opts):
    """一顆石頭加進 bm，兩段式：
    1. 十幾個點取凸包 → 五到八個大主平面（參考圖的明暗交界落在主稜線上，靠的就是這幾個大面）
    2. 每個大面裡加一兩個點、只往外推一點點 → 大面微微折開，但還讀得出是一整面
    最後把主要的角往相鄰點各拉一點重新取凸包：角變成一圈小折面（倒角），稜線上少數幾個角拉多一點當缺角。
    全程都是凸包，一定是凸的，不會像 bevel 那樣切出凹痕"""
    size = min(w, d, h)
    pts = []
    n = min(n, 18) if shape != 'pyramid' else 0
    if shape == 'pyramid':           # 三角錐：左坡長而緩、右坡短而陡，每個坡只有兩三個大面，尖峰是一個小鈍面（v13 太工整像 Cone）
        a = 0.0
        for i in range(6):
            a += math.tau / 6 * rng.uniform(0.8, 1.2)
            k = rng.uniform(0.85, 1.15)
            pts.append(Vector((math.cos(a) * w / 2 * k, math.sin(a) * d / 2 * k, 0)))
        for i in range(4):
            a = i / 4 * math.tau + rng.uniform(-0.3, 0.3)
            pts.append(Vector((math.cos(a) * w * 0.3 - w * 0.12, math.sin(a) * d * 0.3, h * rng.uniform(0.35, 0.55))))
        for dx, dy in ((0, 0), (-0.03, 0.02), (0.02, -0.03)):
            pts.append(Vector((w * (0.07 + dx), d * dy, h * (1 if dx == 0 else 0.97))))
    for i in range(n):
        a = i / n * math.tau + rng.uniform(-0.25, 0.25)
        el = rng.uniform(-0.35, 1.0)
        r = math.sqrt(max(0.0, 1 - el * el))
        k = rng.uniform(0.9, 1.08)
        p = Vector((math.cos(a) * r * w / 2 * k, math.sin(a) * r * d / 2 * k, (0.42 + el * 0.58) * h))
        f = p.z / h
        if shape == 'slab':          # 扁平：最高在中間偏左，往邊緣變薄到四成；兩端是鈍的圓頭，不收成一點（v10 像梭子）
            rn = min(1.0, math.hypot((p.x + w * 0.08) / (w / 2), p.y / (d / 2)))
            p.z = min(p.z, h * (1 - 0.6 * rn * rn))
            if abs(p.x) > w * 0.35:
                p.y = math.copysign(max(abs(p.y), d * 0.35 / 2), p.y) if abs(p.y) > 1e-6 else p.y
        elif shape == 'wedge':       # 斜坡：左三分之一是鈍峰，往右長長的緩坡，右端是圓肩
            t = (p.x / (w / 2) + 1) / 2
            p.z *= 1.0 - 0.4 * max(0.0, t - 0.3) / 0.7
            if t > 0.85:
                p.x *= 0.9; p.z *= 1.1
        elif shape == 'spire':       # 立石：高、頂端稍微收
            p.x *= 1 - 0.25 * f; p.y *= 1 - 0.25 * f
        elif shape in CURVES:        # 圓頂：照寬度曲線一路緩緩拱起，側面不垂直（平台會變方塊，v10）
            k = profile(f, CURVES[shape])
            p.x *= k; p.y *= k
        elif shape == 'peak':        # 尖頂：一路往中心收 45%，頂上一個尖
            shrink = 1 - 0.45 * max(0.0, f - 0.15) / 0.85
            p.x *= shrink; p.y *= shrink
        if opts.get('press_right') and p.x > w * 0.25 and f > 0.7:
            p.z *= 0.85              # 右上角往下壓：最高點不要跑到右邊變成楔形
        if shape == 'side' and f > 0.5:   # 副塊：頂面往左下斜約 15 度（高點貼著主體那側），左上的直角削成斜面
            p.z -= math.tan(math.radians(15)) * (w / 2 - p.x) * (f - 0.5) * 2
            if p.x < -w * 0.3:
                p.x *= 0.88
        if shape == 'side' and f < 0.4 and p.x > 0:
            p.x += w * 0.1           # 副塊下半段往右埋進主體：從正面看不會在兩塊中間夾出一道溝（v18）
        if opts.get('lift_right') and p.x > w * 0.1 and f > 0.5:
            p.z = min(p.z * 1.2, h * 0.95)   # 右半頂部抬高：右肩約總高七成，不要往右趴
        p.z = max(p.z, 0.0)
        pts.append(p)
    if shape == 'peak':              # 頂上一個主稜交會點：尖峰要讀得出來，所以頂點不倒角
        apex = Vector((w * 0.07, rng.uniform(-0.05, 0.05) * d, h))
        pts.append(apex)
    elif shape == 'wedge':
        pts.append(Vector((-w * 0.17, 0, h)))
    elif shape == 'slab':            # 兩端是鈍的端面：厚度約中間的一半，不收成一點（v10、v11 正面看像梭子）
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts += [Vector((sx * w * 0.47, sy * d * 0.17, 0)), Vector((sx * w * 0.45, sy * d * 0.15, h * 0.47))]
    elif shape == 'spire':           # 斜切的鈍頂：左高右低
        pts += [Vector((w * 0.12, 0, h)), Vector((-w * 0.2, 0, h * 0.82))]   # 往左斜切
    if 'apex' in opts:               # 指定最高點的位置（寬度幾成）
        pts.append(Vector((w * (opts['apex'] - 0.5), 0, h * 1.02)))
    for a in (0.3, 1.9, 3.5, 5.0) if shape != 'pyramid' else ():   # 底部一圈，坐得穩
        pts.append(Vector((math.cos(a) * w * 0.4, math.sin(a) * d * 0.4, 0)))

    def hull(points):
        t = bmesh.new()
        vs = [t.verts.new(p) for p in points]
        bmesh.ops.convex_hull(t, input=vs)
        for v in [v for v in t.verts if not v.link_faces]:
            t.verts.remove(v)
        return t

    tmp = hull(pts)
    # 第二段：大面裡加點，只往外推 ≤ FOLD，讓大面微微折開
    corners = [v.co.copy() for v in tmp.verts]
    ridge = set()                    # 主稜線上的角（相鄰面夾角 > 30 度）：缺角只挑這些
    for v in tmp.verts:
        if any(len(e.link_faces) == 2 and e.calc_face_angle() > math.radians(30) for e in v.link_edges):
            ridge.add(tuple(v.co))
    extra = []
    big = sorted(tmp.faces, key=lambda f: -f.calc_area())[:8]
    for f in big:
        if f.normal.z < -0.5:
            continue                 # 底面不用
        vs = [v.co for v in f.verts]
        for _ in range(rng.randint(3, 4)):
            wts = [rng.random() for _ in vs]
            c = sum((v * wt for v, wt in zip(vs, wts)), Vector()) / sum(wts)
            extra.append(c + f.normal * rng.uniform(0.3, 1.0) * FOLD * size)
    tmp.free()
    tmp = hull(corners + extra)
    # 角往每個相鄰點拉 CHAMFER（角變成一圈小折面）；稜線上 15% 的角拉 CHIP 當缺角。大面裡加的點不動，省面。
    # 尖錐（pyramid）的尖峰不動
    main = {tuple(c) for c in corners}
    cut = []
    for v in tmp.verts:
        if tuple(v.co) not in main or (shape == 'pyramid' and v.co.z > 0.9 * h):
            cut.append(v.co.copy())
            continue
        t = CHIP if tuple(v.co) in ridge and rng.random() < 0.15 else (0.05 if v.co.z < 0.1 * h else CHAMFER)
        for e in v.link_edges:
            u = e.other_vert(v)
            cut.append(v.co.lerp(u.co, min(t * size / max((u.co - v.co).length, 1e-6), 0.45)))
    tmp.free()
    tmp = hull(cut)
    # 底部往內收：取完凸包之後才收（收在點上會被凸包吃掉，v9 看不出來）。最下面 10% 越低收越多，到地面收 10%
    for v in tmp.verts:
        if v.co.z < 0.1 * h:
            k = 1 - 0.1 * (1 - v.co.z / (0.1 * h))
            v.co.x *= k; v.co.y *= k
    # 碎面清掉：太近的點焊在一起、幾乎共平面的面合併，不然會長出細長的亮縫（v12、v13）
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts[:], dist=0.015 * size)
    bmesh.ops.dissolve_limit(tmp, angle_limit=math.radians(4), verts=tmp.verts[:], edges=tmp.edges[:])
    if opts.get('step'):
        # 台階：在寬度 26% 處切一條摺線，左邊高 55% 以上的點往下壓，越往左壓越多（到左緣 22% 總高；14% 在畫面上看不出來，v20）
        xs = -w / 2 + w * 0.26
        bmesh.ops.bisect_plane(tmp, geom=tmp.verts[:] + tmp.edges[:] + tmp.faces[:], plane_co=Vector((xs, 0, 0)),
                               plane_no=Vector((1, 0, 0)))
        for v in tmp.verts:
            if v.co.x < xs - 1e-4 and v.co.z > 0.55 * h:
                t = min(1.0, (xs - v.co.x) / (w * 0.26)) ** 0.5   # 摺線旁邊就壓下去，台階才明顯
                v.co.z -= 0.22 * h * t * min(1.0, (v.co.z - 0.55 * h) / (0.1 * h))
    # 主稜倒角：凸包做完之後才對轉折大的邊 bevel（在點上加倒角帶會被加進大面的點拆成好幾段小角度，達不到門檻，v13 沒生效）。
    # 尖錐的斜稜要直，不倒
    if shape != 'pyramid' and w >= 100 * PX:   # 小石頭（畫面寬度 < 100px）不倒角：看不出差別，省面
        edges = [e for e in tmp.edges if len(e.link_faces) == 2 and e.calc_face_angle() > math.radians(25)
                 and e.calc_face_angle_signed() > 0   # 只倒凸稜，台階的凹折不倒
                 and min(v.co.z for v in e.verts) > 0.1 * h]
        if edges:
            bmesh.ops.bevel(tmp, geom=edges, offset=BAND * size, segments=1, affect='EDGES', profile=0.5,
                            clamp_overlap=True)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
    bmesh.ops.translate(tmp, vec=Vector((x, y, 0)), verts=tmp.verts[:])
    me = bpy.data.meshes.new('tmp')
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def build(i, parts, mat):
    rng.seed(SEED * 100 + i)
    bm = bmesh.new()
    for part in parts:
        dx, w, d, h, n, shape = part[:6]
        extra = list(part[6:])
        lift, dy, opts = (extra + [0, 0, {}][len(extra):])[:3]
        if w < 100:   # 小石頭：低矮圓頂（高寬比 ≤ 0.65），點少了會變方塊
            h, n = min(h, w * 0.65), max(n, 14)
        before = set(bm.verts)
        stone(bm, dx * PX, dy * PX, w * PX, d * PX, h * PX, n, shape, opts)
        if lift:   # 疊在別顆上面：墊高
            bmesh.ops.translate(bm, vec=Vector((0, 0, lift * PX)), verts=[v for v in bm.verts if v not in before])
    name = 'Rock%02d' % (i + 1)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False   # 平面著色：一面一個顏色
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def preview(obs, path):
    """照參考圖一模一樣的構圖：每顆擺到參考圖上的位置，正交相機、同解析度，上下對照對得齊"""
    sc = bpy.context.scene
    for o, (cx, by, parts) in zip(obs, ROCKS):
        o.location = ((cx - IMG_W / 2) * PX, 0, (IMG_H / 2 - by) * PX)

    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = IMG_W * PX
    tilt = math.radians(12)   # 稍微俯視，看得到石頭頂面（參考圖也是）
    cam.rotation_euler = (math.radians(90) - tilt, 0, 0)
    cam.location = (0, -30 * math.cos(tilt), 30 * math.sin(tilt))
    sc.collection.objects.link(cam)
    sc.camera = cam

    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 6.0
    sun.data.color = (1.0, 0.72, 0.45)                             # 暖橘：受光面是橘色
    sun.rotation_euler = (math.radians(50), 0, math.radians(80))   # 右邊偏前、仰角約 22 度：右側面橘亮、左側面紫暗（跟參考圖一樣），頂面不會最亮
    sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.254, 0.238, 0.39, 1)     # 約 #8A86A8 的紫灰環境光：背光面是紫灰，不是紅褐
    bg.inputs['Strength'].default_value = 2.4   # 陰影面要是中明度的紫灰，不是深紅褐
    # 不放接影子的地面：三排上下疊著，上一排的地會把下一排整排擋暗（v7）
    sc.world = world

    sc.render.engine = 'CYCLES'   # 光追：跟參考圖同一種渲染，接觸陰影和明暗才對得上
    sc.cycles.samples = 64
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
    sc.render.resolution_x, sc.render.resolution_y = IMG_W, IMG_H
    sc.render.film_transparent = True   # 背景由 tools/model_iter.sh 墊成白色
    # 三排分開渲染再疊起來：三排在場景裡上下疊著，一起渲染上一排會把影子投到下一排身上（v7、v8 第二排整排發暗）
    import numpy as np
    rows = [range(0, 4), range(4, 11), range(11, 16)]
    out = None
    for k, row in enumerate(rows):
        for i, o in enumerate(obs):
            o.hide_render = i not in row
        sc.render.filepath = path + '.row%d.png' % k
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(sc.render.filepath)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(IMG_H, IMG_W, 4)
        bpy.data.images.remove(img)
        os.remove(sc.render.filepath)
        if out is None:
            out = px
        else:                                        # 疊上去（透明背景，照 alpha 混）
            a = px[..., 3:4]
            out[..., :3] = px[..., :3] * a + out[..., :3] * (1 - a)
            out[..., 3:4] = a + out[..., 3:4] * (1 - a)
    img = bpy.data.images.new('preview', IMG_W, IMG_H, alpha=True)
    img.pixels[:] = out.ravel()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    print('preview ->', path)


def build_all():
    global MAT
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MAT = material('rock_stone', (0.153, 0.083, 0.039))   # 線性值。比參考圖定案時略亮、紅綠比低一點：遊戲的光比預覽暗又暖，固有色往反方向補
    return [build(i, parts, MAT) for i, (cx, by, parts) in enumerate(ROCKS)]


if __name__ == '__main__':
    pipeline.run(build_all, preview, budget=2500)
