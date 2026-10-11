# 尼諾拉（Tripo 生成版）：docs/素材/dinosaur 3d model.glb（一整塊、沒骨架、沒顏色、嘴張開）綁到尼諾拉的骨架上，
# 匯出 models/ninola_tripo.glb，trex.gd 的動作程式直接用（骨頭名字、父子都一樣）。
# 做的事：
#   1. 拿核可 01R2 v005 blend 的骨架 TrexRig（只讀、不存），原本的網格刪掉
#   2. 新模型轉成頭朝 +Y、縮到尼諾拉的高度；寬度多縮一點讓兩腳對到骨架的腳，前後平移讓腳掌對齊
#   3. 骨頭位置挪到新模型的關節上（脖子、頭、下顎、手、尾巴）：腿照原本的，動作程式從骨架的靜止姿勢讀長度
#   4. 照區域上色（沿用尼諾拉的材質）、Blender 自動權重綁骨架
# 背景跑：Blender --background --factory-startup --python blender/ninola_tripo.py -- --out models/ninola_tripo.glb [--preview 資料夾]
# ponytail: 上色照位置和法線粗分，不是貼圖；要細再回 Tripo 出貼圖或手刷
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
RIG_SRC = os.path.join(BASE, 'ninola', 'working', '01R2', '2026-10-09-v005', 'ninola_01R2_gold_slit_eye.blend')
SRC = os.path.join(BASE, '..', 'docs', '素材', 'dinosaur 3d model.glb')
HEIGHT = 3.573        # 尼諾拉的高度（模型單位）
FOOT_X = 0.68         # 骨架腳掌（toe2_1）的左右位置
FOOT_Y = 0.10         # 骨架腳掌的前後位置

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
out = args[args.index('--out') + 1] if '--out' in args else None
prev = args[args.index('--preview') + 1] if '--preview' in args else None

bpy.ops.wm.open_mainfile(filepath=RIG_SRC)
rig = bpy.data.objects['TrexRig']


def centers(pts):
    """每 0.25 公尺一段，身體中線附近（|x| 小）的中心高度：底緣和頂緣的中點（頂緣取 85% 高，去掉背上的尖刺），
    再跟前後兩段平均。不用點的平均：尖刺、牙齒那些地方點特別密，會把平均拉偏"""
    d = {}
    for c in pts:
        if abs(c.x) < 0.35:
            d.setdefault(round(c.y * 4), []).append(c.z)
    mid = {}
    for k, v in d.items():
        v.sort()
        mid[k] = (v[int(len(v) * 0.05)] + v[int(len(v) * 0.85)]) / 2
    return {k: sum(mid.get(j, mid[k]) for j in (k - 1, k, k + 1)) / 3 for k in mid}


def center_at(cs, y):
    k = round(y * 4)
    while k not in cs:   # 頭尾外面沒有網格：用最近的那段
        k += 1 if k < min(cs) else -1
    return cs[k]


old = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.vertices and len(o.data.vertices) > 1000)
old_pts = [old.matrix_world @ v.co for v in old.data.vertices]
old_c = centers(old_pts)
old_y = (min(c.y for c in old_pts), max(c.y for c in old_pts))
for o in list(bpy.data.objects):
    if o is not rig:
        bpy.data.objects.remove(o, do_unlink=True)
for b in rig.pose.bones:
    b.custom_shape = None
    b.rotation_quaternion = (1, 0, 0, 0)
    b.rotation_euler = (0, 0, 0)
    b.location = (0, 0, 0)

bpy.ops.import_scene.gltf(filepath=SRC)
src = next(o for o in bpy.context.selected_objects if o.type == 'MESH')
bm = bmesh.new()
bm.from_mesh(src.data)
bm.transform(src.matrix_world)
bm.transform(Matrix.Rotation(math.pi, 4, 'Z'))   # 原檔頭朝 -Y
zs = [v.co.z for v in bm.verts]
s = HEIGHT / (max(zs) - min(zs))
bm.transform(Matrix.Translation((0, 0, -min(zs))))
low = [v.co for v in bm.verts if v.co.z - min(zs) < 0.02 * (max(zs) - min(zs))]
foot_x = sum(abs(c.x) for c in low) / len(low)
foot_y = sum(c.y for c in low) / len(low)
sx = FOOT_X / (foot_x * s)
bm.transform(Matrix.Diagonal((s * sx, s, s, 1)))
bm.transform(Matrix.Translation((0, FOOT_Y - foot_y * s, 0)))
print('scale %.3f, x extra %.3f' % (s, sx))
for o in list(bpy.data.objects):
    if o.type != 'ARMATURE':
        bpy.data.objects.remove(o, do_unlink=True)

# 骨頭挪到新模型的關節：中線上的骨頭（脊椎、脖子、頭、下顎、手、尾巴）照新模型伸長縮短、照中線高度差補高低；腿不動
new_pts = [v.co.copy() for v in bm.verts]
new_c = centers(new_pts)
new_y = (min(c.y for c in new_pts), max(c.y for c in new_pts))
NECK0, TAIL0 = 1.35, -0.30   # 脖子根、尾巴根（這兩點之間是身體，不伸縮）
k_head = (new_y[1] - NECK0) / (old_y[1] - NECK0)
k_tail = (new_y[0] - TAIL0) / (old_y[0] - TAIL0)
print('head x%.3f tail x%.3f' % (k_head, k_tail))


def refit(p):
    y = p.y
    if y > NECK0:
        y = NECK0 + (y - NECK0) * k_head
    elif y < TAIL0:
        y = TAIL0 + (y - TAIL0) * k_tail
    return Vector((p.x, y, p.z + center_at(new_c, y) - center_at(old_c, p.y)))


LEGS = ('thigh', 'shin', 'foot', 'dew', 'toe')
ARMS = ('arm', 'forearm', 'hand', 'finger')
# 手臂關節（左手，右手 x 取負）：從網格量的（胸口前面凸出去的那塊，側面看肩膀在胸前 2.0 高、手肘幾乎在正下方、
# 前臂往前下到手腕、手掌和兩根爪往前下）。以前整條平移，上臂從肩膀後 0.3 公尺的身體裡開始、手肘埋在肚子裡
ARM_JOINTS = {
    'arm': ((0.36, 1.83, 2.02), (0.37, 1.86, 1.82)),
    'forearm': ((0.37, 1.86, 1.82), (0.35, 2.05, 1.60)),
    'hand': ((0.35, 2.05, 1.60), (0.35, 2.12, 1.47)),
    'finger1': ((0.32, 2.12, 1.47), (0.32, 2.13, 1.32)),
    'finger2': ((0.39, 2.12, 1.47), (0.41, 2.13, 1.32)),
}
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
inv = rig.matrix_world.inverted()
for eb in rig.data.edit_bones:
    if eb.name.startswith(LEGS):
        continue
    h, t = rig.matrix_world @ eb.head, rig.matrix_world @ eb.tail
    eb.use_connect = False
    eb.head, eb.tail = inv @ refit(h), inv @ refit(t)
    if eb.name.startswith(ARMS):   # 手臂照新模型量到的關節放（下面 ARM_JOINTS）
        side = 1 if eb.name.endswith('_l') else -1
        n = eb.name[:-2]
        h, t = ARM_JOINTS[n]
        eb.head = inv @ Vector((h[0] * side, h[1], h[2]))
        eb.tail = inv @ Vector((t[0] * side, t[1], t[2]))
# 下顎：新模型嘴是張開的，照嘴巴的縫重放。頭的中線一段一段往前看，上下兩片中間空著的就是嘴；
# 最後面有縫的地方是下顎關節，縫下面那片最前端是下巴
from mathutils.bvhtree import BVHTree
tree = BVHTree.FromBMesh(bm)
gaps = []
for k in range(int(NECK0 * 10), int(new_y[1] * 10)):
    y = k / 10 + 0.05
    hits, z = [], -1.0
    while True:   # 沿中線從下往上打，記下每一層皮的高度
        loc, _, _, _ = tree.ray_cast(Vector((0, y, z)), Vector((0, 0, 1)))
        if loc is None:
            break
        hits.append(loc.z)
        z = loc.z + 1e-3
    if len(hits) >= 4:   # 閉著的頭只有上下兩層；張開的嘴是下巴底、下顎上緣、上顎下緣、頭頂四層
        gaps.append((y, hits[1], hits[2]))
print('mouth slices', [(round(g[0], 2), round(g[1], 2), round(g[2], 2)) for g in gaps])
# 從嘴尖往後只留連續的那段
gaps.sort(key=lambda g: -g[0])
keep = [gaps[0]]
for g in gaps[1:]:
    if keep[-1][0] - g[0] > 0.15:
        break
    keep.append(g)
gaps = keep[::-1]
hinge = Vector((0, gaps[0][0], (gaps[0][1] + gaps[0][2]) / 2))
lower = [c for c in new_pts if abs(c.x) < 0.2 and c.y > hinge.y and c.z < gaps[-1][1] + 0.05]
chin = max(lower, key=lambda c: c.y)
print('mouth gaps %d, hinge (%.2f, %.2f), chin (%.2f, %.2f)' % (len(gaps), hinge.y, hinge.z, chin.y, chin.z))
jaw = rig.data.edit_bones['jaw']
jaw.head, jaw.tail = inv @ hinge, inv @ Vector((0, chin.y, chin.z))
bpy.ops.object.mode_set(mode='OBJECT')

me = bpy.data.meshes.new('NinolaTripo')
bm.to_mesh(me)
bm.free()
ob = bpy.data.objects.new('NinolaTripo', me)
bpy.context.scene.collection.objects.link(ob)
co = [v.co for v in me.vertices]
ys = [c.y for c in co]
print('bbox y %.2f..%.2f  z %.2f..%.2f  x %.2f' % (min(ys), max(ys), min(c.z for c in co), max(c.z for c in co), max(c.x for c in co)))

# 上色（沿用尼諾拉的材質）：背上的尖刺、肚子、嘴裡、爪子，其他是身體
MATS = ['d_olive', 'd_belly', 'd_spike', 'd_mouth', 'd_claw']
for n in MATS:
    me.materials.append(bpy.data.materials[n])
top = {}
for k in {round(c.y * 4) for c in co}:
    zs = sorted(c.z for c in co if round(c.y * 4) == k and abs(c.x) < 0.5)
    if zs:
        top[k] = zs[int(len(zs) * 0.8)]
gap_at = {round(g[0] * 10 - 0.5): (g[1], g[2]) for g in gaps}   # 每 0.1 公尺一段，嘴巴縫的上下緣
for f in me.polygons:
    c, n = f.center, f.normal
    m = 'd_olive'
    gap = gap_at.get(round(c.y * 10 - 0.5))
    if gap and gap[0] - 0.1 < c.z < gap[1] + 0.1 and abs(c.x) < 0.3 and abs(n.z) > 0.3 \
            and ((c.z > (gap[0] + gap[1]) / 2) == (n.z < 0)):
        m = 'd_mouth'   # 嘴裡：上顎朝下、下顎朝上的面
    elif c.z < 0.18 and c.y > FOOT_Y + 0.45:
        m = 'd_claw'
    elif abs(c.x) < 0.45 and c.z > top.get(round(c.y * 4), 99) + 0.05:
        m = 'd_spike'
    elif n.z < -0.45 and 0.5 < c.z < center_at(new_c, c.y):   # 肚子：中線以下、面朝下（只看面朝下會在身體兩側撒一堆碎三角）
        m = 'd_belly'
    f.material_index = MATS.index(m)
    f.use_smooth = False

# 綁骨架：Blender 自動權重（熱擴散）。Tripo 的網格有破洞、重疊，直接算會失敗，
# 所以複製一份重新包成密封的外殼（體素重建）來算，再把權重抄回原網格（每個點抄最近的面）
proxy = ob.copy()
proxy.data = ob.data.copy()
bpy.context.scene.collection.objects.link(proxy)
rm = proxy.modifiers.new('remesh', 'REMESH')
rm.mode = 'VOXEL'
rm.voxel_size = 0.04
for o in bpy.context.scene.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = proxy
proxy.select_set(True)
bpy.ops.object.modifier_apply(modifier='remesh')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
print('proxy verts %d, weighted %d' % (len(proxy.data.vertices), sum(1 for v in proxy.data.vertices if any(g.weight > 0.01 for g in v.groups))))
for g in proxy.vertex_groups:
    ob.vertex_groups.new(name=g.name)
dt = ob.modifiers.new('dt', 'DATA_TRANSFER')
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'
for o in bpy.context.scene.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.modifier_apply(modifier='dt')
bpy.data.objects.remove(proxy, do_unlink=True)
for o in bpy.context.scene.objects:
    o.select_set(False)
ob.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_NAME')   # 掛到骨架下（權重已經有了，不重算）
names = [g.name for g in ob.vertex_groups]
bare = [v.index for v in me.vertices if not any(g.weight > 0.01 for g in v.groups)]
if bare:
    from mathutils.geometry import intersect_point_line
    segs = {b.name: (b.head_local, b.tail_local) for b in rig.data.bones}
    def dist(p, h, t):
        _, f = intersect_point_line(p, h, t)
        f = min(max(f, 0.0), 1.0)
        return (p - (h + (t - h) * f)).length
    for i in bare:
        p = me.vertices[i].co
        b = min(segs, key=lambda n: dist(p, *segs[n]))
        (ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)).add([i], 1.0, 'REPLACE')
# 自動權重會讓手臂、手指骨抓到胸口的皮（長吼揮手時胸口被拉長 13 倍，trex_skin_check 量的）：
# 手臂整條只管離它 0.2 公尺內的皮，0.35 公尺外全部轉給胸口的 spine2，中間漸變
from mathutils.geometry import intersect_point_line as _ipl


def _seg(p, h, t):
    _, f = _ipl(p, h, t)
    f = min(max(f, 0.0), 1.0)
    return (p - (h + (t - h) * f)).length


vg = ob.vertex_groups
for side in ('l', 'r'):
    chain = [n + '_' + side for n in ('arm', 'forearm', 'hand', 'finger1', 'finger2')]
    segs = [(rig.data.bones[n].head_local, rig.data.bones[n].tail_local) for n in chain]
    for v in me.vertices:
        ws = {vg[g.group].name: g.weight for g in v.groups}
        armw = sum(ws.get(n, 0.0) for n in chain)
        if armw <= 0.0:
            continue
        d = min(_seg(v.co, *sg) for sg in segs)
        t = min(max((d - 0.2) / 0.15, 0.0), 1.0)
        if t <= 0.0:
            continue
        for n in chain:
            if n in ws:
                vg[n].add([v.index], ws[n] * (1 - t), 'REPLACE')
        vg['spine2'].add([v.index], ws.get('spine2', 0.0) + armw * t, 'REPLACE')
# 嘴：自動權重把上顎也大半綁給下顎骨（下顎骨離整個嘴都近，頭骨只到後腦），下顎一閉上顎也跟著動，嘴永遠閉不起來。
# 以嘴縫中線為界：嘴角往前，界線以上全給頭、以下全給下顎；嘴角往後 0.3 公尺內漸變回原本的
split = sorted(((g[0], (g[1] + g[2]) / 2) for g in gaps if g[2] - g[1] > 0.08))   # 最前面上下牙碰在一起的那段縫太窄，不準


def split_z(y):
    if y <= split[0][0]:
        return split[0][1]
    for (y0, z0), (y1, z1) in zip(split, split[1:]):
        if y <= y1:
            return z0 + (z1 - z0) * (y - y0) / (y1 - y0)
    return split[-1][1]


for v in me.vertices:
    c = v.co
    if c.y < hinge.y - 0.3 or abs(c.x) > 0.8:
        continue
    k = min((c.y - (hinge.y - 0.3)) / 0.3, 1.0)   # 嘴角後 0.3 公尺：0 → 嘴角：1
    ws = {vg[g.group].name: g.weight for g in v.groups}
    hj = ws.get('head', 0.0) + ws.get('jaw', 0.0)
    if hj <= 0.0:
        continue
    to = 'jaw' if c.z < split_z(c.y) else 'head'
    other = 'head' if to == 'jaw' else 'jaw'
    moved = ws.get(other, 0.0) * k
    vg[to].add([v.index], ws.get(to, 0.0) + moved, 'REPLACE')
    vg[other].add([v.index], ws.get(other, 0.0) - moved, 'REPLACE')
print('auto weights: %d verts, %d had none (filled by nearest bone)' % (len(me.vertices), len(bare)))

if prev:
    os.makedirs(prev, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 1400, 700
    ob.color = (0.7, 0.7, 0.7, 0.5)
    sc.display.shading.show_xray = not os.environ.get('NO_XRAY')
    sc.display.shading.xray_alpha = 0.6
    dots = []
    for b in rig.data.bones:   # 骨頭頭尾畫成紅點、連線（預覽用，匯出前刪掉）
        h, t = rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local
        cu = bpy.data.curves.new('c', 'CURVE')
        cu.dimensions = '3D'
        cu.bevel_depth = 0.03
        sp = cu.splines.new('POLY')
        sp.points.add(1)
        sp.points[0].co = (*h, 1)
        sp.points[1].co = (*t, 1)
        c = bpy.data.objects.new('bone_' + b.name, cu)
        c.color = (1, 0.1, 0.1, 1)
        sc.collection.objects.link(c)
        dots.append(c)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 10.5
    sc.world = bpy.data.worlds.new('w')
    for name, loc, look in (('side', (30, -0.9, 1.8), (0, -0.9, 1.8)), ('front', (0, 30, 1.8), (0, 0, 1.8)), ('top', (0, -0.9, 30), (0, -0.9, 0))):
        cam.location = loc
        cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y' if name != 'top' else 'Y').to_euler()
        sc.render.filepath = os.path.join(prev, name + '.png')
        bpy.ops.render.render(write_still=True)
    for c in dots + [cam]:
        bpy.data.objects.remove(c, do_unlink=True)

if out:
    for o in bpy.context.scene.objects:
        o.select_set(o in (ob, rig))
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), export_format='GLB', use_selection=True, export_animations=False,
                              export_skins=True, export_all_influences=True, export_yup=True)
    print('exported ->', out)
