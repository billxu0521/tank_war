# 牛仔人形：Tripo 綁好骨架（舊版人形、Mixamo 骨頭名）＋套好的預設動作，合成一個 glb 給 Godot（別人眼中的牛仔）。
# 來源：docs/素材/cowboy_anim/*.glb（每個檔是同一副骨架，各帶幾個動作）。
# 做的事：
#   上色（照 T 字站姿的位置分區，配色同 cowboy_tripo.py）
#   每個動作的臀部水平位置歸零（Tripo 原地動作還是各偏一段，走和跑差 1.4，切動作會瞬移）
#   加兩段：hold（端槍的手臂，遊戲裡蓋在上半身）、ladder（climb 去掉往上升，爬梯和翻越用，位置交給遊戲移動）；jump 也去掉上下
#   轉成面向 Godot 的 -Z、縮到 1.85 公尺
# 跑：Blender --background --python blender/cowboy_anim.py
import bpy, glob, math, os
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'models/cowboy_anim.glb')
HEIGHT = 1.85

bpy.ops.wm.read_factory_settings(use_empty=True)
keep = None
for f in sorted(glob.glob(os.path.join(ROOT, 'docs/素材/cowboy_anim/*.glb'))):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = set(bpy.data.objects) - before
    if keep is None:   # 第一個檔的骨架和外皮留下，其他檔只要動作
        keep = new
        continue
    for o in new:
        bpy.data.objects.remove(o)
arm = next(o for o in keep if o.type == 'ARMATURE')
for o in list(keep):
    if o.type == 'MESH' and o.parent != arm:   # Tripo 附的 Icosphere
        bpy.data.objects.remove(o)
skin = next(o for o in bpy.data.objects if o.type == 'MESH')
skin.name = 'CowboyRig'


def fcurves(a):
    return [fc for l in a.layers for s in l.strips for cb in s.channelbags for fc in cb.fcurves]


# ---- 臀部水平位置歸零：Hips 的 location 第 0、2 軸是水平（第 1 軸沿骨頭朝上，跳、蹲要留著）----
for a in bpy.data.actions:
    for fc in fcurves(a):
        if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
            v0 = fc.keyframe_points[0].co[1]
            for k in fc.keyframe_points:
                k.co[1] -= v0
                k.handle_left[1] -= v0
                k.handle_right[1] -= v0

# ---- 上下位置交給遊戲移動的動作：Hips 第 1 軸壓平在第一格 ----
# ladder＝climb 去掉往上升（爬梯和翻越用）；jump 本身也會把臀部抬高，疊上遊戲裡真的跳起來會飄
ladder = bpy.data.actions['climb'].copy()
ladder.name = 'ladder'
for a in (ladder, bpy.data.actions['jump']):
    for fc in fcurves(a):
        if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index == 1:
            v0 = fc.keyframe_points[0].co[1]
            for k in fc.keyframe_points:
                k.co[1] = k.handle_left[1] = k.handle_right[1] = v0

# ---- hold：端槍的手臂。方向同 cowboy_tripo.py 的 POSE，換到這副骨架的座標（臉朝 -Y、右手在 -X）----
# 每隻手臂 [上臂指向, 前臂指向]；右手握槍把在腰前（前臂往身體中間收，這副骨架肩膀比較寬），左手往前托槍身
POSE = {
    'Right': [Vector((-0.05, -0.15, -1.0)), Vector((0.45, -1.0, 0.05))],
    'Left': [Vector((0.0, -1.2, -1.0)), Vector((-0.20, -1.0, 0.05))],
}
arm.animation_data_create()
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)
bpy.context.view_layer.update()
hold = bpy.data.actions.new('hold')
arm.animation_data.action = hold
for side, dirs in POSE.items():
    for bone, d in zip(('Arm', 'ForeArm'), dirs):
        pb = arm.pose.bones['mixamorig:%s%s' % (side, bone)]
        q = (pb.tail - pb.head).normalized().rotation_difference(d.normalized())
        pb.matrix = Matrix.Translation(pb.head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-pb.head) @ pb.matrix
        bpy.context.view_layer.update()
    for bone in ('Shoulder', 'Arm', 'ForeArm', 'Hand'):
        arm.pose.bones['mixamorig:%s%s' % (side, bone)].keyframe_insert('rotation_quaternion', frame=1)
for side in POSE:
    print('hold 手腕 %s' % side, tuple(round(x, 3) for x in arm.pose.bones['mixamorig:%sHand' % side].head))
arm.animation_data.action = None

# ---- 上色：T 字站姿（靜止姿勢）的位置分區，換成 cowboy_tripo.py 的座標（面向 +Y、右手 +X、1.85 公尺）再判斷 ----
# ponytail: 分區規則從 cowboy_tripo.py 的 region() 抄來，那邊改了這裡要跟著改
def mat(name, rgb, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    m.diffuse_color = (*rgb, 1)
    return m


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
P = [Vector((-v.co.x, -v.co.y, v.co.z)) * HEIGHT for v in skin.data.vertices]
arm_z = [p.z for p in P if abs(p.x) > 0.35]
ARMPIT = sum(arm_z) / len(arm_z) - 0.09
NECK = 1.50


def color(c, arm_face):
    if arm_face:
        return 'glove' if abs(c.x) > 0.62 else 'coat'
    if NECK < c.z < 1.57 and (c.y < -0.03 or abs(c.x) > 0.075):
        return 'coat'
    if c.z > NECK:
        return 'hat' if c.z > 1.64 or abs(c.x) > 0.13 else 'skin'
    if c.z > 1.36 and abs(c.x) < 0.06 and c.y > 0.0:
        return 'scarf'
    if c.z > 1.08:
        return 'coat' if abs(c.x) > 0.09 or c.y < 0.0 else 'shirt'
    if c.z > 1.0 and c.y < 0.0:
        return 'coat'
    if c.z > 0.88:
        return 'leather' if 0.92 < c.z < 0.99 else 'shirt'
    if c.z > 0.80 and abs(c.x) < 0.03:
        return 'denim'
    return 'leather' if c.x > 0.2 and c.z > 0.62 else ('boot' if c.z < 0.38 else 'denim')


skin.data.materials.clear()
for m in MATS.values():
    skin.data.materials.append(m)
for f in skin.data.polygons:
    c = sum((P[i] for i in f.vertices), Vector()) / len(f.vertices)
    is_arm = all(abs(P[i].x) > 0.26 and ARMPIT < P[i].z < 1.42 for i in f.vertices)
    f.material_index = ORDER.index(color(c, is_arm))
    f.use_smooth = False

# ---- 每個動作一條 NLA 軌，匯出時各成一段動畫 ----
for a in sorted(bpy.data.actions, key=lambda a: a.name):
    a.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new()
    tr.name = a.name
    tr.strips.new(a.name, int(a.frame_range[0]), a)
    print('動作', a.name, tuple(round(x) for x in a.frame_range))

# 原檔臉朝 -Y：轉 180 度（匯出後朝 Godot 的 -Z）；縮到身高
arm.rotation_mode = 'XYZ'   # 匯入的物件是四元數模式，不改的話設 euler 沒作用
arm.rotation_euler = (0, 0, math.pi)
arm.scale = (HEIGHT,) * 3
bpy.ops.export_scene.gltf(filepath=OUT, export_animation_mode='NLA_TRACKS', export_yup=True)
print('->', OUT)
