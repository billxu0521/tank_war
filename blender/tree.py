# 闊葉樹（docs/image/tree.png 的風格）：粗短的樹幹、往上分叉的枝幹、十幾團多面體葉團堆成的寬樹冠。
# 平面著色（flat shading）的低多邊形，一面一個顏色。
#
# 不用開 Blender 視窗、不用 MCP，直接在背景跑：
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
#       --python blender/tree.py -- --out models/trees.glb --preview /tmp/tree.png
# 反覆修改時用 tools/model_iter.sh tree <版號>：建模、存預覽、做成跟參考圖上下對照的圖
#
# 跟遊戲的約定（main.gd _tree() 的 TREE_KINDS）：原點在樹根、尺寸就是實際公尺，遊戲只做 ±10% 的隨機縮放。
# 碰撞圓柱的半徑和高度照各棵的樹幹粗細、分叉高度寫在 TREE_KINDS，這裡改了樹幹那邊要跟著改。
import bpy, bmesh, math, random, sys
from mathutils import Vector, Matrix, Euler, noise

SEED = 7
# 三種大小各自長，不是同一棵等比縮放，尺寸直接用公尺寫（照參考圖量的比例）：
# height 總高、trunk 樹幹粗細倍率、fork 主幹分叉高度（對總高）、main 主枝長、reach 次枝伸到多遠。
# 葉團每層 (個數, 離中心, 中心高度, 半徑, 起始方位角)。外圈八團交錯：正對四個視角的四團抬高（底緣約 45%），
# 露出中間的枝幹；斜角的四團往下垂（底緣約 33%）。中圈推到樹冠半寬 0.75 倍：兩側從 33% 到 70% 幾乎垂直，
# 頂部寬圓、正中央一顆最大的頂團突出來。stretch：以外圈底緣為準把樹冠整體往上拉高。
# 樹冠底面是拱形：正向外圈底緣約 49%、中圈底緣不低於 46%，只有斜角那四團垂到 33%，中間露出枝幹。葉團半徑約樹冠寬的 0.14~0.19 倍，第三層（中圈）裡相鄰兩團放大成 big（大小約 1.4 比 1）
SIZES = {
    'TreeOak': {'height': 9.6, 'trunk': 0.85, 'fork': 0.17, 'main': 3.2, 'reach': 3.6, 'big': 1.9, 'stretch': 1.21,
                'layers': [(4, 3.4, 6.05, 1.35, 0), (4, 3.4, 4.52, 1.35, 45), (6, 3.5, 5.7, 1.35, 300),
                           (4, 2.1, 7.3, 1.5, 15), (1, 0.0, 7.5, 2.0, 0), (1, 0.0, 6.6, 1.6, 0)]},
    'TreeOakM': {'height': 7.2, 'trunk': 0.85, 'fork': 0.17, 'main': 2.4, 'reach': 2.6, 'big': 1.35,
                 'layers': [(4, 2.5, 4.53, 1.0, 0), (4, 2.5, 3.38, 1.0, 45), (4, 2.3, 4.6, 1.0, 30),
                            (1, 0.0, 5.95, 1.4, 0)]},
    'TreeOakS': {'height': 4.8, 'trunk': 0.5, 'fork': 0.21, 'main': 1.4, 'reach': 1.4, 'big': 0.85,
                 'layers': [(4, 1.2, 2.62, 0.7, 45), (4, 1.1, 3.2, 0.7, 0), (1, 0.0, 3.9, 0.8, 0)]},
}

rng = random.Random(SEED)


def args():
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = {'--out': None, '--preview': None}
    for k in out:
        if k in a:
            out[k] = a[a.index(k) + 1]
    return out


def material(name, rgb, rough=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    # 不要高光：朝太陽的面會疊一層白色反光，把黃色沖成灰卡其，折面的明暗差就被吃掉了
    for key in ('Specular IOR Level', 'Specular'):
        if key in p.inputs:
            p.inputs[key].default_value = 0.0
    m.diffuse_color = (*rgb, 1)
    return m


def frame(d):
    """跟方向 d 垂直的兩個軸，拿來排一圈頂點"""
    d = d.normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    u = d.cross(up).normalized()
    return u, d.cross(u).normalized()


def limb(bm, pts, radii, sides, mi, twist=0.0, roots=(), root_k=(1.15, 1.08)):
    """沿著一串點蓋一截錐形的多稜柱。每圈頂點的半徑亂一點、逐圈轉 twist 弧度，稜線才會斜斜繞上去。
    roots：這幾條稜線在最底下幾圈多往外推（每圈倍率 root_k），做出根部隆起"""
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        u, v = frame(d)
        ring = []
        for k in range(sides):
            a = k / sides * math.tau + twist * i / max(len(pts) - 1, 1)
            rr = r * rng.uniform(0.93, 1.07) * (root_k[i] if i < len(root_k) and k in roots else 1.0)
            ring.append(bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * rr))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            f = bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
            f.material_index = mi
    cap = bm.faces.new(list(reversed(rings[0])))   # 底部封起來：從下面看不會看到空心
    cap.material_index = mi


def bend(p0, p1, n, wobble):
    """p0 到 p1 之間 n 段，中間往旁邊歪一點，枝幹才不會直得像水管"""
    pts = []
    side = frame(p1 - p0)[0]
    for i in range(n + 1):
        t = i / n
        p = p0.lerp(p1, t) + side * math.sin(t * math.pi) * wobble
        pts.append(p)
    return pts


def blob(bm, c, r, mi):
    """一團葉子：頻率 3 的 geodesic 球（二十面體每條邊切三段，180 面），每條稜邊約是直徑的 1/5。
    頂點沿徑向亂推 ±9%，每團再隨機轉一個角度：各團的折面紋路不一樣，讀起來是一塊塊大折面而不是細碎雜點"""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=1.0)
    bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=2, use_grid_fill=True)
    rot = Euler((rng.uniform(0, math.tau), rng.uniform(0, math.tau), rng.uniform(0, math.tau))).to_matrix()
    for v in tmp.verts:
        v.co = c + (rot @ v.co.normalized()) * r * rng.uniform(0.91, 1.09)
    me = bpy.data.meshes.new('tmp')
    tmp.to_mesh(me)
    tmp.free()
    before = set(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for f in bm.faces:
        if f not in before:
            f.material_index = mi


def inside(p, blobs):
    """枝的末端拉進最近那團葉子裡（離中心六成半徑內）：伸出樹冠外的枝尖一看就是穿模"""
    c, r = min(blobs, key=lambda b: (b[0] - p).length - b[1])
    d = p - c
    return p if d.length <= r * 0.6 else c + d.normalized() * r * 0.6


def materials():
    # 線性值。換成 sRGB 約：樹皮 #816145、葉子 #6F7938。比照參考圖定案時略亮、略綠：遊戲的光比預覽暗又暖，固有色往反方向補。
    # 葉子只用一種顏色：每團顏色不同看起來像拼貼，明暗交給光照
    return [material('tree_bark', (0.133, 0.055, 0.024)), material('tree_leaf', (0.055, 0.068, 0.018))]


def build(name, cfg):
    rng.seed(SEED + len(name))
    bm = bmesh.new()
    H = cfg['height']
    k = H / 9.6 * cfg['trunk']                     # 樹幹、枝的粗細跟著樹高和倍率走
    fork = H * cfg['fork']

    # 輪廓要有凹凸、左右不對稱：每團沿徑向亂偏 ±12% 樹冠半徑、方位亂偏 ±15 度，上面兩層整個往一側偏
    half = max(d + r for n, d, z, r, yaw0 in cfg['layers'])
    lean = Vector((rng.choice((-1, 1)) * half * 0.12, 0, 0))
    blobs = []
    base = min(z - r for n, d, z, r, yaw0 in cfg['layers'])   # 樹冠最低的底緣
    for li, (n, d, z, r, yaw0) in enumerate(cfg['layers']):
        z = base + (z - base) * cfg.get('stretch', 1.0)
        for i in range(n):
            yaw = math.radians(yaw0) + i / n * math.tau
            rr = cfg['big'] if li == 2 and i < 2 else r
            if n > 1:
                yaw += math.radians(rng.uniform(-15, 15))
            dd = d + (rng.uniform(-0.12, 0.12) * half if d > 0 else 0)
            p = Vector((dd * math.cos(yaw), dd * math.sin(yaw), z + rng.uniform(-0.08, 0.08) * r))
            if li == 2:
                p.z = max(p.z, H * 0.46 + rr)   # 中圈底緣不低於 46%，拱形的底面
            if li >= len(cfg['layers']) - 2:
                p += lean
            blobs.append((p, rr * rng.uniform(0.97, 1.03)))

    # 樹幹：幾乎垂直的七稜柱，從地面一路連續收細到分叉點：根部外擴分四圈（0、4、9、15% 高度，
    # 1.5 → 1.3 → 1.15 → 1.05 倍），之後線性收到分叉點。三條根稜多推出去的量從地面 20% 一路遞減到 15% 高度歸零，
    # 不會在某一圈突然截斷（截斷會看起來像底下墊了一個台座）。一路扭轉約 25 度，頂端伸過分叉點收到 80%，藏進主枝裡
    rf = 0.62 * k
    trunk = [Vector((0, 0, -0.3 * k)), Vector((0, 0, 0)), Vector((0, 0, H * 0.04)), Vector((0.01 * k, 0, H * 0.09)),
             Vector((0.02 * k, 0, H * 0.15)), Vector((0.03 * k, 0, fork)), Vector((0.03 * k, 0, fork + 0.5 * k))]
    limb(bm, trunk, [rf * x for x in (1.55, 1.5, 1.3, 1.15, 1.05, 1.0, 0.8)], 7, 0,
         twist=math.radians(25), roots=(0, 2, 5), root_k=(1.2, 1.2, 1.147, 1.08, 1.0))

    # 主枝：Y 字分叉成三根，根部約主幹的 65%，分四段一路彎（仰角 75 → 40 度），逐段收細。
    # 兩根次枝在主枝 40%~72% 的不同高度錯開分出去，根部是主枝在那裡粗細的 55%，往外斜 35~55 度，末端埋進葉團
    L = cfg['main']
    main_r = [rf * x for x in (0.65, 0.6, 0.55, 0.47, 0.4)]   # 前六成不低於主幹一半，到樹冠底下還有四成：粗壯的 Y 字
    for i in range(3):
        yaw = i / 3 * math.tau + math.radians(30) + rng.uniform(-0.2, 0.2)
        out = Vector((math.cos(yaw), math.sin(yaw), 0))
        pts = [Vector((0.03 * k, 0, fork - 0.15 * k))]
        for elev in (65, 58, 48, 40):   # 第一段 65 度，Y 字從四個面都露得出來
            e = math.radians(elev + rng.uniform(-3, 3))
            pts.append(pts[-1] + (out * math.cos(e) + Vector((0, 0, math.sin(e)))) * L / 4)
        pts[-1] = inside(pts[-1], blobs)
        limb(bm, pts, main_r, 6, 0)
        for t, side in ((rng.uniform(0.4, 0.5), -1), (rng.uniform(0.62, 0.72), 1)):   # 每根主枝兩根次枝
            f = t * 4
            j = min(int(f), 3)
            start = pts[j].lerp(pts[j + 1], f - j)
            r0 = (main_r[j] + (main_r[j + 1] - main_r[j]) * (f - j)) * 0.55
            sy = yaw + side * math.radians(rng.uniform(35, 55))
            sout = Vector((math.cos(sy), math.sin(sy), 0))
            flat = max(cfg['reach'] - start.xy.length, 0.5 * k)
            end = start + sout * flat + Vector((0, 0, flat * math.tan(math.radians(rng.uniform(35, 55)))))
            end = inside(end, blobs)
            limb(bm, bend(start, end, 3, 0.1 * k), [r0, r0 * 0.75, r0 * 0.5, r0 * 0.3], 5, 0)

    leaves = bmesh.new()
    for c, r in blobs:
        blob(leaves, c, r, 1)

    wood = to_object(name, bm, 1.0)
    crown = to_object(name + '_leaves', leaves, 1.0)
    ctx = bpy.context
    for o in ctx.scene.objects:
        o.select_set(o in (wood, crown))
    ctx.view_layer.objects.active = wood
    bpy.ops.object.join()
    for p in wood.data.polygons:
        p.use_smooth = False   # 平面著色：一面一個顏色
    return wood


def to_object(name, bm, s):
    if s != 1.0:
        bmesh.ops.scale(bm, vec=(s, s, s), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in MATS:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def export(obs, path):
    for o in bpy.context.scene.objects:
        o.select_set(o in obs)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    print('exported ->', path)


def preview(obs, path):
    """照參考圖的排法：上排正、右、背、左四個面，下排大中小三棵。正交相機、白底、暖色斜光"""
    sc = bpy.context.scene
    copies = []
    ob = obs[0]
    for i, yaw in enumerate((0, 90, 180, 270)):
        o = ob.copy()
        o.location = (i * 12 - 18, 0, 4)
        o.rotation_euler = (0, 0, math.radians(yaw))
        copies.append(o)
    for i, src in enumerate(obs):
        o = src.copy()
        o.location = ((-15, -3, 7)[i], 0, -13)
        copies.append(o)
    for o in copies:
        sc.collection.objects.link(o)
    for o in obs:
        o.hide_render = True

    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 58
    cam.location = (0, -60, -0.5)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam

    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 8.0
    sun.data.color = (1.0, 0.83, 0.58)                               # 淡暖黃（約 #FFEBC8）：受光面金黃、側面還留得住橄欖綠，太橘整棵會變芥末色
    sun.rotation_euler = (math.radians(35), 0, math.radians(35))   # 右前上方仰角約 55 度：每團都有亮面和暗面，樹冠也不會把樹幹上段整段遮黑
    sc.collection.objects.link(sun)

    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.58, 0.6, 0.48, 1)        # 約 #C8CCB8 帶一點綠的環境光，暗面才是深橄欖不是灰藍
    bg.inputs['Strength'].default_value = 0.28   # 太弱暗面會變黑，參考圖的暗面還是深橄欖綠   # 環境光弱一點，暗面才看得出層次
    sc.world = world

    # Cycles：光線追蹤才有葉團之間的暗縫和互相投影，跟參考圖一樣（EEVEE 預設沒有，整團會糊成一片）
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 64
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = 'GPU'
    except TypeError:
        pass   # 沒有 Metal 就用 CPU
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = 1680, 940
    sc.render.film_transparent = True   # 背景由 tools/model_iter.sh 墊成白色
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('preview ->', path)


a = args()
bpy.ops.wm.read_factory_settings(use_empty=True)
MATS = materials()
trees = [build(n, c) for n, c in SIZES.items()]
for t in trees:
    print(t.name, 'tris:', sum(len(p.vertices) - 2 for p in t.data.polygons))
if a['--out']:
    export(trees, a['--out'])
if a['--preview']:
    preview(trees, a['--preview'])
