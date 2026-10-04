# 手指關節有沒有被壓扁：握槍、張開兩個姿勢下，每個關節那一圈（兩根骨頭各半的那 4 個點）的斷面積，跟沒擺姿勢時比剩幾成。
# 套骨架、不細分，直接量骨架網格。REST=0,0,0 量「手指伸直建模」的對照組。
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/hand_joint_check.py
#   REST=0,0,0 /Applications/Blender.app/... （同上）
import bpy, os, sys, itertools
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'blender'))
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
import hands as H
if os.environ.get('REST'):
    H.REST_CURL = tuple(float(x) for x in os.environ['REST'].split(','))
skin, arm = H.build_rig()
skin.modifiers['round'].show_viewport = False
groups = {g.index: g.name for g in skin.vertex_groups}


def area(ps):
    """四個點的斷面積：三種配對裡對角線外積最大的那種（四邊形面積 = 對角線外積的一半）"""
    return max(0.5 * ((ps[a] - ps[b]).cross(ps[c] - ps[d])).length
               for a, b, c, d in ((0, 2, 1, 3), (0, 1, 2, 3), (0, 3, 1, 2)))


rings = {}
for v in skin.data.vertices:
    ws = sorted((groups[g.group], round(g.weight, 2)) for g in v.groups if g.weight > 0)
    if len(ws) == 2 and all(w == 0.5 for _, w in ws) and all(n.split('_')[0] in H.FINGER_NAMES for n, _ in ws):
        rings.setdefault(tuple(n for n, _ in ws), []).append(v.index)


def coords():
    dg = bpy.context.evaluated_depsgraph_get()
    me = skin.evaluated_get(dg).to_mesh()
    out = {k: [me.vertices[i].co.copy() for i in idx] for k, idx in rings.items()}
    skin.evaluated_get(dg).to_mesh_clear()
    return out


H.reset(arm)
rest = coords()
for name, fn in (('握槍', H.pose_grip), ('張開', H.pose_open)):
    fn(arm)
    now = coords()
    vals = [area(now[k]) / area(rest[k]) for k in sorted(rings)]
    for k, r in zip(sorted(rings), vals):
        print('%-34s %s時斷面剩 %3.0f%%' % (' / '.join(k), name, r * 100))
    print('REST_CURL', H.REST_CURL, name, '平均 %.0f%%  最小 %.0f%%' % (sum(vals) / len(vals) * 100, min(vals) * 100))
