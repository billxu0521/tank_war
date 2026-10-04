# 手的參考圖：把 FNE_project 的手臂（Sketchfab「Low poly FPS Pistol Animated」，CC-BY，只拿來當參考不放進遊戲）
# 用 blender/hand_views.py 同一套鏡頭渲染成 docs/image/hand.png。張開 = 骨架的靜止姿勢，握槍 = Pistol_IDLE 第一格。
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/hand_ref.py
import bpy, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'blender'))
import hand_views

SRC = os.path.expanduser('~/project/FNE_project/assets/models/pistol/scene.gltf')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
import bmesh


def ref_part(g):
    m = re.match(r'([A-Za-z]+(?:_[A-Za-z]+)?)_R_\d+$', g)
    n = m.group(1) if m else g
    return n if n in hand_views.PARTS else 'Arm'


for o in bpy.data.objects:
    if o.type == 'MESH':
        if o.parent == arm and any(m.type == 'ARMATURE' for m in o.modifiers) and o.dimensions.x > 1:
            # 只留右手：左手臂的點（靜止姿勢在世界 +X 那半邊）刪掉，不然握槍那排會被左手擋住
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if (o.matrix_world @ v.co).x > 0], context='VERTS')
            bm.to_mesh(o.data)
            hand_views.paint_parts(o, ref_part)
        else:
            o.hide_render = True
act = bpy.data.actions['Pistol_IDLE']


def pose(p):
    if p == 'open':
        arm.data.pose_position = 'REST'
    else:
        arm.data.pose_position = 'POSE'
        arm.animation_data_create()
        arm.animation_data.action = act
        if arm.animation_data.action_slot is None and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        bpy.context.scene.frame_set(int(act.frame_range[0]))


SKIN = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == arm and not o.hide_render)


def pts():
    """關節＝骨頭的頭（glTF 存的是真的）；指尖不能用骨頭的尾巴（glTF 不存尾巴，匯入時用猜的，拇指的猜到手掌外面去），
    改用皮：最後一節骨頭帶動的點裡，離那節關節最遠的一點"""
    out = {}
    for b in arm.pose.bones:
        m = re.match(r'([A-Za-z]+(?:_[A-Za-z]+)?)_R_\d+$', b.name)
        if m:
            out[m.group(1)] = arm.matrix_world @ b.head
    dg = bpy.context.evaluated_depsgraph_get()
    me = SKIN.evaluated_get(dg).to_mesh()
    names = {g.index: g.name for g in SKIN.vertex_groups}
    for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little'):
        gname = next(n for n in names.values() if n.startswith(f + '_Distal_R'))
        gi = next(k for k, n in names.items() if n == gname)
        head = out[f + '_Distal']
        cands = [SKIN.matrix_world @ me.vertices[v.index].co for v in SKIN.data.vertices
                 if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
        out[f + '_tip'] = max(cands, key=lambda c: (c - head).length)
    SKIN.evaluated_get(dg).to_mesh_clear()
    return out


hand_views.render_sheet(pose, pts, os.path.join(ROOT, 'docs/image/hand.png'))

# 參考握槍姿勢的「每節骨頭方向」，換算成手自己的座標（前、側、手背法線），存起來給 hands.py 抄：
# 兩邊擺成一模一樣的姿勢再疊圖，握槍那排比的才是形狀，不是姿勢（docs/image/hand_pose_grip.json）
import json
pose('grip')
bpy.context.view_layer.update()
P = pts()
wrist, fwd, side, normal, L = hand_views.hand_frame(P)
dirs = {}
for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little'):
    seq = [f + s for s in ('_Proximal', '_Intermediate', '_Distal', '_tip')]
    for a, b in zip(seq, seq[1:]):
        d = (P[b] - P[a]).normalized()
        dirs[a] = [d.dot(fwd), d.dot(side), d.dot(normal)]
# 關節位置也存（手腕為原點、手長為單位，張開姿勢）：拇指根長在手上的哪裡，方向一樣、起點不同整根就平移了
pose('open')
bpy.context.view_layer.update()
P = pts()
wrist, fwd, side, normal, L = hand_views.hand_frame(P)
dirs['_open'] = {}
for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little'):
    seq = [f + s2 for s2 in ('_Proximal', '_Intermediate', '_Distal', '_tip')]
    for a2, b2 in zip(seq, seq[1:]):
        d = (P[b2] - P[a2]).normalized()
        dirs['_open'][a2] = [d.dot(fwd), d.dot(side), d.dot(normal)]
dirs['_pos'] = {k: [(v - wrist).dot(fwd) / L, (v - wrist).dot(side) / L, (v - wrist).dot(normal) / L]
                for k, v in P.items() if k.split('_')[0] in ('Thumb', 'Index', 'Middle', 'Ring', 'Little')}
json.dump(dirs, open(os.path.join(ROOT, 'docs/image/hand_pose_grip.json'), 'w'), indent=1)
print('pose ->', 'docs/image/hand_pose_grip.json')
