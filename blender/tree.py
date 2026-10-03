# 闊葉樹（docs/image/tree.png 的風格）：粗短的樹幹、往上分叉的枝幹、十幾團葉子堆成的寬樹冠。
# 樹幹平面著色（flat shading）；葉子是葉片卡（card、core、on_core，grove.py 也用這裡的工具）。
#
# 不用開 Blender 視窗、不用 MCP，直接在背景跑：
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
#       --python blender/tree.py -- --out models/trees.glb --preview /tmp/tree.png
# 反覆修改時用 tools/model_iter.sh tree <版號>：建模、存預覽、做成跟參考圖上下對照的圖
#
# 跟遊戲的約定（main.gd _tree() 的 TREE_KINDS）：原點在樹根、尺寸就是實際公尺，遊戲只做 ±10% 的隨機縮放。
# 碰撞圓柱的半徑和高度照各棵的樹幹粗細、分叉高度寫在 TREE_KINDS，這裡改了樹幹那邊要跟著改。
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, Euler, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pipeline
from pipeline import studio

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
    bm.faces.new(rings[-1]).material_index = mi   # 末端也封起來：細枝的尖端露在葉子外面時，看進管子裡是一個暗方塊


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


TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'textures')


def card_material(name, png):
    """葉片卡的材質：透明底的貼圖（tools/make_leaf_card.py 畫的），顏色直接用貼圖，alpha 一刀切挖空。
    剔背面（卡片正反兩面是分開的兩組面，法線都朝外）。名字要有 leafcard：main.gd 認這個字設透明、不接收影子"""
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(TEX, png))
    nt.links.new(tex.outputs['Color'], p.inputs['Base Color'])
    clip = nt.nodes.new('ShaderNodeMath')   # 透明度一刀切（>0.5 就是實的），跟遊戲裡的 alpha scissor 一樣
    clip.operation = 'GREATER_THAN'
    clip.inputs[1].default_value = 0.5
    nt.links.new(tex.outputs['Alpha'], clip.inputs[0])
    nt.links.new(clip.outputs[0], p.inputs['Alpha'])
    p.inputs['Roughness'].default_value = 1.0
    for key in ('Specular IOR Level', 'Specular'):
        if key in p.inputs:
            p.inputs[key].default_value = 0.0
    m.use_backface_culling = True
    return m


def _card_quad(bm, corners, uvs, mi, nc):
    """一片卡：正反兩面各一組面（點分開），UV 照 uvs；每個點記一個「從 nc 往外、偏上一點」的法線"""
    uv = bm.loops.layers.uv.verify()
    ln = bm.verts.layers.float_vector.get('lnorm') or bm.verts.layers.float_vector.new('lnorm')
    for order in (range(len(corners)), range(len(corners) - 1, -1, -1)):
        order = list(order)
        vs = []
        for i in order:
            v = bm.verts.new(corners[i])
            v[ln] = ((corners[i] - nc).normalized() + Vector((0, 0, 0.3))).normalized()   # 偏上一點：每團上亮下暗，底部不會全黑
            vs.append(v)
        f = bm.faces.new(vs)
        f.material_index = mi
        for loop, i in zip(f.loops, order):
            loop[uv].uv = uvs[i]


def card(bm, c, nrm, size, mi, nc, rand=None, cross=True):
    """一組葉片卡：兩片交叉的正方形（中心 c、邊長 size、第一片朝 nrm），UV 貼滿整張圖。
    nc 是這團葉子的中心：法線從那裡往外，整團像一顆球一樣受光，不會每片各自一個亮暗、讀起來一片雜訊"""
    rand = rand or rng
    nrm = nrm.normalized()
    u, v = frame(nrm)
    spin = rand.uniform(0, math.tau)
    u, v = u * math.cos(spin) + v * math.sin(spin), -u * math.sin(spin) + v * math.cos(spin)
    h = size * 0.5
    for a, b in ((u, v), (u, nrm))[:2 if cross else 1]:   # 第二片沿 u 軸轉 90 度：側面看不會變成一條線（貼在芯上的不用，會戳出去變成刺）
        _card_quad(bm, [c - a * h - b * h, c + a * h - b * h, c + a * h + b * h, c - a * h + b * h],
                   [(0, 0), (1, 0), (1, 1), (0, 1)], mi, nc)


def ribbon(bm, pts, width, side, mi, nc):
    """一條長條卡（柳條）：沿 pts 由上往下，寬 width，兩條交叉（一條沿 side、一條轉 90 度）。貼圖的上緣在第一個點"""
    down = (pts[-1] - pts[0]).normalized()
    for s in (side.normalized(), down.cross(side).normalized()):
        n = len(pts)
        for i in range(n - 1):
            q = [pts[i] - s * width * 0.5, pts[i] + s * width * 0.5, pts[i + 1] + s * width * 0.5, pts[i + 1] - s * width * 0.5]
            v0, v1 = 1 - i / (n - 1), 1 - (i + 1) / (n - 1)
            _card_quad(bm, q, [(0, v0), (1, v0), (1, v1), (0, v1)], mi, nc)


def core(bm, c, r, mi, sq=(1, 1, 1), subdiv=2):
    """一團葉子的芯：實心的暗色多面體（subdiv 2 是 80 面、1 是 20 面），墊在葉片卡底下：卡片之間看進去不透空，整團有亮頂暗底"""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
    for v in tmp.verts:
        q = v.co * rng.uniform(0.92, 1.08)
        v.co = c + Vector((q.x * r * sq[0], q.y * r * sq[1], q.z * r * sq[2]))
    me = bpy.data.meshes.new('tmp')
    tmp.to_mesh(me)
    tmp.free()
    before = set(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    for f in bm.faces:
        if f not in before:
            f.material_index = mi


def on_core(bm, c, cr, n, size, mi, rand=None, spread=0.25, sq=(1, 1, 1), top=0.6, push=0.1, up=0.0, cross=True, bottom=1.0, maxel=90, cap=None, fan=0.0):
    """在芯（中心 c、半徑 cr）的表面撒 n 組葉片卡，卡片大致貼著表面（法線跟芯的法線差不到 30 度）。
    bottom：下半球壓扁的倍率（松樹的團上圓下平）。top：放在上半球的比例（下半也要鋪，不然團的下半是裸露的芯）；push：卡片再往外推卡片大小的幾成，
    葉子的邊緣蓋過芯的輪廓，團的外緣才是葉子的鋸齒、不是多面體的直邊。up：卡片朝上的偏向（松樹的扁雲要平鋪）。
    fan：卡片從貼著表面往外翻幾度，並把卡片往外推半張的 sin(fan)，葉子像一叢張開、往外伸出去，不是一片片往內包"""
    rand = rand or rng
    for k in range(n):
        d = Vector([rand.uniform(-1, 1) for _ in range(3)])
        d.z = abs(d.z) if rand.random() < top else -abs(d.z)
        d = d.normalized()
        # cap=(往外推, 大小倍率)：團頂上 35% 的卡片（從樹下往上看都是側面）縮在輪廓裡，不會伸出去被看成一條條
        on_cap = cap is not None and d.z > 0.3
        q = c + Vector((d.x * sq[0], d.y * sq[1], d.z * sq[2] * (bottom if d.z < 0 else 1))) * cr * rand.uniform(0.9, 1.05) + d * size * (cap[0] if on_cap else push)
        nrm = (d + Vector((0, 0, up if d.z >= 0 else 0.0)) + Vector([rand.uniform(-spread, spread) for _ in range(3)])).normalized()
        el = math.radians(maxel)   # 卡片法線的仰角上限：頂上水平的卡片從地面往上看剛好側面朝鏡頭，會被拉成一條條
        if nrm.z > math.sin(el):
            h = nrm.xy.normalized() if nrm.xy.length > 1e-6 else Vector((1, 0))
            nrm = Vector((h.x * math.cos(el), h.y * math.cos(el), math.sin(el)))
        if fan:
            f = math.radians(fan * rand.uniform(0.8, 1.2))
            t = d.cross(Vector([rand.uniform(-1, 1) for _ in range(3)])).normalized()   # 隨便一個切線方向
            nrm = (nrm * math.cos(f) + t * math.sin(f)).normalized()
            q = q + d * size * 0.5 * math.sin(f)
        card(bm, q, nrm, size * rand.uniform(0.85, 1.15) * (cap[1] if on_cap else 1), mi, c, rand, cross)


def apply_card_normals(ob):
    """葉片卡的面改用 _card_quad 記下來的法線（平滑著色），其他面維持平面著色"""
    me = ob.data
    if me.uv_layers:   # 合併物件（樹幹＋葉子）之後，貼圖座標不一定是「渲染用的那組」，不設的話整張取到透明的角落、葉子全消失
        me.uv_layers[0].active = me.uv_layers[0].active_render = True
    cardmats = {i for i, m in enumerate(me.materials) if m and 'leafcard' in m.name}
    for p in me.polygons:
        p.use_smooth = p.material_index in cardmats
    attr = me.attributes.get('lnorm')
    if attr is None:
        return
    if cardmats:
        normals = []
        for p in me.polygons:
            for li in p.loop_indices:
                normals.append(Vector(attr.data[me.loops[li].vertex_index].vector) if p.material_index in cardmats
                               else p.normal.copy())
        me.normals_split_custom_set(normals)
    me.attributes.remove(attr)


def materials():
    # 線性值。換成 sRGB 約：樹皮 #816145、葉子 #6F7938。比照參考圖定案時略亮、略綠：遊戲的光比預覽暗又暖，固有色往反方向補。
    # 葉子只用一種顏色：每團顏色不同看起來像拼貼，明暗交給光照
    # 葉子是葉片卡（一張畫了一簇橡樹葉的透明圖，tools/make_leaf_card.py）
    return [material('tree_bark', (0.133, 0.055, 0.024)), card_material('tree_leafcard_oak', 'leaf_oak.png'),
            material('tree_leaf_core', (0.15, 0.18, 0.03))]   # 芯：接近葉子的中間色（葉子往外翻開後會看到，太暗像一個洞）


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

    # 每個葉團拆成三顆小葉簇，往外、往上推（樹冠裡面空出來，看得到枝幹），細枝從葉團中心連過去。
    # 每顆小葉簇：一顆暗色實心的芯，表面平貼一層單片葉片卡（不交叉，才不會一片垂直戳出去變成刺），
    # 法線從簇中心往外、偏上：每簇上面亮、下面暗
    leaves = bmesh.new()
    axis = Vector((0, 0, 0))
    for c, r in blobs:
        out = (c - Vector((0, 0, c.z))) * 0.6 + Vector((0, 0, r * 0.8))
        for j in range(3):
            d = (out.normalized() + Vector([rng.uniform(-0.9, 0.9) for _ in range(3)])).normalized()
            if d.z < -0.3:
                d.z = -d.z
            q = c + d * r * 0.4
            sr = r * rng.uniform(0.74, 0.84)
            limb(bm, [c - d * r * 0.2, c.lerp(q, 0.5), q], [0.09 * k, 0.07 * k, 0.05 * k], 4, 0)   # 細枝
            core(leaves, q, sr * 0.5, 2, subdiv=1)
            on_core(leaves, q, sr * 0.5, int(5 + 7 * sr), sr * 1.25, 1, spread=0.2, top=0.7, up=0.5, cross=False, push=0.05, maxel=45, fan=55)   # 葉子從芯的表面往外翻約 55 度張開：太斜會被拉成長條

    wood = to_object(name, bm, 1.0)
    crown = to_object(name + '_leaves', leaves, 1.0)
    ctx = bpy.context
    for o in ctx.scene.objects:
        o.select_set(o in (wood, crown))
    ctx.view_layer.objects.active = wood
    bpy.ops.object.join()
    apply_card_normals(wood)   # 樹幹平面著色（一面一個顏色），葉片卡用記下來的法線
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
        o.visible_shadow = False   # 葉片卡不互投影子（遊戲裡葉片不接收影子），不然樹冠裡面全黑
    for o in obs:
        o.hide_render = True

    studio(path, 58, (0, -60, -0.5))


def build_all():
    global MATS
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS = materials()
    return [build(n, c) for n, c in SIZES.items()]


if __name__ == '__main__':
    pipeline.run(build_all, preview, budget=6000)
