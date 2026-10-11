# 牛仔（Tripo 生成版）：docs/素材/cowboy.glb（T 字站姿、沒顏色、沒骨架的一整塊）轉成遊戲用的四塊，
# 名字和原點跟 cowboy.py 一樣，cowboy.gd 的 _skin() 直接換上：
#   CowboyBody（腳底）、CowboyHead（眼睛 1.6）、CowboyLegL/R（髖關節 ±0.10, 0.88）、CowboyShinL/R（自己低頭看的靴子）
# 做的事：轉成面向 +Y（Blender 的前）、縮到 1.85 公尺、手臂從 T 字擺成端槍（CowboyArms 另外一塊，原點在肩膀 1.35）、
#   照高度和位置切塊、照區域上色（帽子、皮膚、外套、襯衫、皮帶、褲子、靴子）。
# ponytail: 上色和切塊都是照位置的粗略判斷，不是貼圖；要細緻再回 Tripo 出貼圖或手刷頂點色
# 背景跑：Blender --background --factory-startup --python blender/cowboy_tripo.py -- --out models/cowboy_tripo.glb [--preview 資料夾]
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Quaternion

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, '..', 'docs', '素材', 'cowboy.glb')
HEIGHT = 1.85      # 帽頂（原檔高度 1）
EYE, HIP = 1.6, 0.88
SHOULDER = (0.16, 0.26)       # |x| 從這裡開始彎、到這裡完全彎（公尺，縮放後）
NECK = 1.50                   # 以上是頭
SHIN = 0.38                   # 以下是靴子（自己低頭看的版本）
ARM_PIVOT = 1.35              # 手臂整組（和槍）上下轉的軸心高度：肩膀
HIP_CUT = 0.80                # 以下、兩腳分開的是腿

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    m.diffuse_color = (*rgb, 1)   # 預覽（Workbench）看這個
    return m


# 顏色沿用 cowboy.py（線性值）
MATS = {
    'hat': mat('c_hat', (0.22, 0.16, 0.11), 0.8),
    'skin': mat('c_skin', (0.72, 0.52, 0.40)),
    'scarf': mat('c_scarf', (0.55, 0.12, 0.10), 0.8),
    'coat': mat('c_duster', (0.11, 0.08, 0.05), 0.85),
    'shirt': mat('c_shirt', (0.70, 0.66, 0.58), 0.8),
    'leather': mat('c_leather', (0.30, 0.18, 0.10), 0.6),
    'denim': mat('c_denim', (0.20, 0.24, 0.32), 0.85),
    'boot': mat('c_boot', (0.16, 0.10, 0.07), 0.55),
    'glove': mat('c_glove', (0.075, 0.045, 0.028), 0.75),
}
ORDER = list(MATS)

bpy.ops.import_scene.gltf(filepath=SRC)
src = next(o for o in bpy.data.objects if o.type == 'MESH')
bm = bmesh.new()
bm.from_mesh(src.data)
bm.transform(src.matrix_world)
# 原檔臉朝 -Y：轉 180 度；縮到身高
bm.transform(Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Scale(HEIGHT, 4))


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# 手臂擺成端槍：T 字站姿裡手臂沿 x 伸直，|x| 就是「沿著手臂走多遠」，拿它分肩膀、手肘兩個關節的權重，
# 先繞手肘轉前臂、再繞肩膀轉整隻手臂（關節附近權重漸變，不會撕開）。原位置記下來，切塊和上色照原位置判斷
ELBOW = (0.40, 0.47)          # |x| 從這裡開始彎、到這裡完全彎：手肘
# 每隻手臂：[上臂指向, 前臂指向]（Blender 座標：+X 右、+Y 前、+Z 上）。右手握槍把在腰前，左手往前托槍身
POSE = {
    1: [Vector((0.10, -0.05, -1.0)), Vector((0.25, 1.0, 0.15))],
    -1: [Vector((0.0, 1.2, -1.0)), Vector((0.20, 1.0, 0.05))],
}
arm_z = [v.co.z for v in bm.verts if abs(v.co.x) > 0.35]
SH_Z = sum(arm_z) / len(arm_z)   # 手臂中心高度
ARMPIT = SH_Z - 0.09   # 腋下：再低是外套的側邊，不能跟著轉
ROT = {}
for s, (up, fore) in POSE.items():
    out = Vector((s, 0, 0))
    q_sh = out.rotation_difference(up.normalized())
    q_el = q_sh.inverted() @ out.rotation_difference(fore.normalized())   # 前臂整體朝 fore：扣掉上臂已經轉的
    ROT[s] = (q_sh, q_el)
IDENT = Quaternion()
orig = {}
for v in bm.verts:
    orig[v.index] = v.co.copy()
    if v.co.z >= 1.42:
        continue
    w = smooth(*SHOULDER, abs(v.co.x)) * smooth(ARMPIT, ARMPIT + 0.04, v.co.z)
    if w <= 0:
        continue
    s = 1 if v.co.x > 0 else -1
    q_sh, q_el = ROT[s]
    sh = Vector((s * SHOULDER[0], 0, SH_Z))
    el = Vector((s * sum(ELBOW) / 2, 0, SH_Z))
    p = el + IDENT.slerp(q_el, smooth(*ELBOW, abs(v.co.x))) @ (v.co - el)
    v.co = sh + IDENT.slerp(q_sh, w) @ (p - sh)
is_arm = {i: abs(c.x) > SHOULDER[1] and ARMPIT < c.z < 1.42 for i, c in orig.items()}
print('shoulder z %.3f' % SH_Z)

bm.faces.ensure_lookup_table()


def region(f):
    """這一面屬於哪一塊、什麼顏色（照原本 T 字站姿的位置）"""
    c = sum((orig[v.index] for v in f.verts), Vector()) / len(f.verts)
    arm = all(is_arm[v.index] for v in f.verts)
    if arm:
        return 'arms', 'glove' if abs(c.x) > 0.62 else 'coat'
    if NECK < c.z < 1.57 and (c.y < -0.03 or abs(c.x) > 0.075):
        return 'body', 'coat'   # 立起來的外套領子：不跟著頭轉
    if c.z > NECK:
        return 'head', 'hat' if c.z > 1.64 or abs(c.x) > 0.13 else 'skin'
    if c.z > 1.36 and abs(c.x) < 0.06 and c.y > 0.0:
        return 'body', 'scarf'
    if c.z > 1.08:
        return 'body', 'coat' if abs(c.x) > 0.09 or c.y < 0.0 else 'shirt'
    if c.z > 1.0 and c.y < 0.0:
        return 'body', 'coat'   # 外套後襬比前面長
    if c.z > 0.88:
        return 'body', 'leather' if 0.92 < c.z < 0.99 else 'shirt'
    if c.z > HIP_CUT and abs(c.x) < 0.03:
        return 'body', 'denim'
    part = 'legL' if c.x < 0 else 'legR'
    col = 'leather' if c.x > 0.2 and c.z > 0.62 else ('boot' if c.z < SHIN else 'denim')   # 槍套綁在右大腿外側
    return part, col


groups = {}
for f in bm.faces:
    p, col = region(f)
    groups.setdefault(p, []).append(f)
    f.material_index = ORDER.index(col)


def make(name, faces, anchor):
    b2 = bmesh.new()
    vmap = {}
    for f in faces:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = b2.verts.new(v.co - Vector(anchor))
            vs.append(vmap[v])
        nf = b2.faces.new(vs)
        nf.material_index = f.material_index
        nf.smooth = False
    me = bpy.data.meshes.new(name)
    b2.to_mesh(me)
    b2.free()
    for m in MATS.values():
        me.materials.append(m)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = anchor
    return o


bpy.data.objects.remove(src)
make('CowboyBody', groups['body'], (0, 0, 0))
make('CowboyHead', groups['head'], (0, 0, EYE))
make('CowboyArms', groups['arms'], (0, 0, ARM_PIVOT))   # 掛在 Body 的 Arms 節點，跟著上下看的角度轉
for s in (1, -1):   # 手的位置（遊戲裡槍擺這裡）：Godot 座標 = (x, z, -y)，相對 Arms 原點
    g = [v.co for f in groups['arms'] for v in f.verts if abs(orig[v.index].x) > 0.70 and orig[v.index].x * s > 0]
    c = sum(g, Vector()) / len(g)
    print('hand %s godot (%.3f, %.3f, %.3f)' % ('R' if s > 0 else 'L', c.x, c.z - ARM_PIVOT, -c.y))
for s, n in ((-1, 'L'), (1, 'R')):
    fs = groups['leg' + n]
    make('CowboyLeg' + n, fs, (s * 0.10, 0, HIP))
    make('CowboyShin' + n, [f for f in fs if f.calc_center_median().z < SHIN], (s * 0.10, 0, HIP))
for o in bpy.data.objects:   # 沒用到的材質槽拿掉
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.material_slot_remove_unused()
    o.select_set(False)
print('tris', {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects})

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
out = args[args.index('--out') + 1] if '--out' in args else None
prev = args[args.index('--preview') + 1] if '--preview' in args else None
if prev:
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = 500, 700
    sc.world = bpy.data.worlds.new('w')
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.0
    for name, loc in (('front', (0, 5, 0.95)), ('side', (5, 0, 0.95)), ('back', (0, -5, 0.95))):
        cam.location = loc
        cam.rotation_euler = (Vector((0, 0, 0.95)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(prev, name + '.png')
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
if out:
    for o in bpy.data.objects:
        o.select_set(o.type == 'MESH')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
    print('exported ->', out)
