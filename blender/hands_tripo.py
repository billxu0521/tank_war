# 試驗：第一人稱的手換成 Tripo 生成的網格，骨架、握姿照舊由 hands.py 擺（骨頭名字不變，遊戲程式不用改）。
# 流程：
#   1. 拍圖：hands.py 的手擺成「手指伸直微張、拇指照靜止姿勢」，拍前後左右四張（--views）
#   2. Tripo 照四張圖生成（multiview，低面數白模）：做出來的手跟我們的骨架同一個姿勢、比例，
#      拇指往前收、虎口小（文字生成的手拇指往側面張，握槍時虎口被撐成一大片擋住左輪）
#   3. 這支：照拍圖的方向擺回「手的空間」→ 逐步貼合（ICP）小修 → 骨架的靜止姿勢改成拍圖那個姿勢 →
#      自動權重 → 換掉 hands.build_rig，其餘流程（握姿、烘、匯出 Rig*）不動
# 用法：
#   拍圖  Blender --background --factory-startup --python blender/hands_tripo.py -- --views <資料夾>
#         tripo make front.png back.png left.png right.png --model tripo-p1 -p face_limit=10000 -p texture=false -p pbr=false
#         生成的 model.glb 放到 docs/素材/hand_tripo.glb
#   預覽  Blender --background --factory-startup --python blender/hands_tripo.py -- --preview <png>
#   遊戲  HANDS_TRIPO=1 跑 blender/cowboy.py（cowboy.py 會呼叫 install()）
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hands

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', '素材', 'hand_tripo.glb')
MV_SPLAY = (-8, -2, 5, 12)   # 拍圖時四指微張的角度（Tripo 才分得出四根手指）
VIEW_C, VIEW_SIZE = Vector((0, 0.04, 0)), 0.34   # 拍圖的取景：中心、正交寬度（手的空間，公尺）
OUR_ARM_END = -0.372         # hands.py 的前臂末端 y
FACES = 6000                 # cowboy.glb 每塊 8000 面的預算
THIN = 0.82                  # 往骨頭中心線縮多少（1 = 不縮）
orig_build_rig = hands.build_rig
orig_bend = hands.bend


def bend(arm, name, flex, splay=0.0):
    """hands.bend 換成這個：靜止姿勢的四指已經張開 MV_SPLAY，張開角度扣掉"""
    base = name.split('_')[0]
    if name.endswith('_Proximal') and base in hands.FINGER_NAMES:
        splay -= MV_SPLAY[hands.FINGER_NAMES.index(base)]
    orig_bend(arm, name, flex, splay)


def mv_pose(arm):
    """拍圖的姿勢：四指伸直微張，拇指照靜止姿勢"""
    hands.reset(arm)
    for n, sp in zip(hands.FINGER_NAMES, MV_SPLAY):
        orig_bend(arm, n + '_Proximal', 0, sp)
        orig_bend(arm, n + '_Intermediate', 0)
        orig_bend(arm, n + '_Distal', 0)
    bpy.context.view_layer.update()


def views(out):
    """拍前後左右四張給 Tripo（圖上手指朝上；前＝手背、左＝拇指側）"""
    skin, arm = orig_build_rig()
    mv_pose(arm)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'SINGLE'
    sc.display.shading.single_color = (0.75, 0.62, 0.52)
    sc.render.resolution_x = sc.render.resolution_y = 1024
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = VIEW_SIZE
    for nm, d in (('front', (0, 0, 1)), ('back', (0, 0, -1)), ('left', (-1, 0, 0)), ('right', (1, 0, 0))):
        zc = Vector(d)
        xc = Vector((0, 1, 0)).cross(zc).normalized()
        cam.location = VIEW_C + zc * 2
        cam.rotation_euler = Matrix((xc, zc.cross(xc), zc)).transposed().to_euler()
        sc.render.filepath = os.path.join(out, nm + '.png')
        bpy.ops.render.render(write_still=True)


def tripo_build_rig():
    vl = bpy.context.view_layer
    skin, arm = orig_build_rig()
    mv_pose(arm)
    dg = bpy.context.evaluated_depsgraph_get()
    me = skin.evaluated_get(dg).to_mesh()
    S = np.array([tuple(skin.matrix_world @ v.co) for v in me.vertices])
    skin.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(skin)

    # ---- 匯入、減面 ----
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SRC)
    new = set(bpy.data.objects) - before
    ob = next(o for o in new if o.type == 'MESH')
    ob.data.transform(ob.matrix_world)
    ob.parent = None
    ob.matrix_world = Matrix()
    for o in new:
        if o != ob:
            bpy.data.objects.remove(o)
    ob.name = ob.data.name = 'hand_skin'
    bm = bmesh.new()   # Tripo 的網格在貼圖接縫處點是分開的：不合併的話自動權重（bone heat）整個算不出來
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(ob.data)
    bm.free()
    d = ob.modifiers.new('dec', 'DECIMATE')
    d.ratio = min(1.0, FACES / len(ob.data.polygons))
    vl.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=d.name)

    # ---- 照拍圖的方向擺回手的空間 ----
    # Tripo 的模型：圖上「往上」→ +Z，最長邊縮成 1；手的寬（拇指那側）→ ±Y、厚 → ±X。
    # 拇指在 Tripo 的哪一側看手中段離中線最遠的點；手背朝哪側（鏡射與否）兩種都貼合一次、取貼得近的
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    s = (S[:, 1].max() - (VIEW_C.y - VIEW_SIZE / 2)) / np.ptp(P[:, 2])   # 圖的底邊到指尖＝Tripo 的全高
    mid = P[(P[:, 2] > P[:, 2].min() + 0.4 * np.ptp(P[:, 2])) & (P[:, 2] < P[:, 2].min() + 0.75 * np.ptp(P[:, 2]))]
    sx = -1.0 if mid[np.argmax(np.abs(mid[:, 1])), 1] > 0 else 1.0   # 拇指要在 -X
    ref = S[S[:, 1] > -0.02][::2]

    def icp(Q, it=25):
        """只轉動、平移（縮放的話縮小永遠貼得比較近，會把手縮成一半）"""
        M = np.eye(4)
        q = Q[Q[:, 1] > -0.02][::5]
        for _ in range(it):
            qq = q @ M[:3, :3].T + M[:3, 3]
            nn = ref[np.argmin(((qq[:, None, :] - ref[None, :, :]) ** 2).sum(-1), axis=1)]
            mq, mr = qq.mean(0), nn.mean(0)
            U, D, Vt = np.linalg.svd((nn - mr).T @ (qq - mq))
            R = U @ np.diag([1, 1, np.sign(np.linalg.det(U @ Vt))]) @ Vt
            Mi = np.eye(4)
            Mi[:3, :3] = R
            Mi[:3, 3] = mr - R @ mq
            M = Mi @ M
        qq = q @ M[:3, :3].T + M[:3, 3]
        return M, np.sqrt(((qq[:, None, :] - ref[None, :, :]) ** 2).sum(-1).min(1)).mean()

    best = None
    for sz in (1.0, -1.0):
        A = np.array([[0, sx, 0], [0, 0, 1], [sz, 0, 0]], float) * s   # 手的空間 = A @ Tripo
        Q = P @ A.T
        Q += np.array([0, S[:, 1].max() - Q[:, 1].max(), 0])           # 指尖對齊
        Q += np.r_[(ref[:, [0]].mean() - Q[Q[:, 1] > -0.02][:, [0]].mean()), 0, (ref[:, 2].mean() - Q[Q[:, 1] > -0.02][:, 2].mean())]
        M, err = icp(Q)
        print('朝向 sz=%+d：貼合差 %.4f' % (sz, err))
        if best is None or err < best[0]:
            best = (err, A, Q[0] - P[0] @ A.T, M, np.linalg.det(A) < 0)
    err, A, t0, M, mirrored = best
    Mt = np.eye(4)
    Mt[:3, :3] = A
    Mt[:3, 3] = t0
    ob.data.transform(Matrix((M @ Mt).tolist()))
    if mirrored:   # 鏡射過面會翻過來
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
        bm.free()
    print('貼合差 %.4f 公尺%s' % (err, '（鏡射）' if mirrored else ''))

    # 前臂拉長到跟 hands.py 的一樣（拍圖只拍到手腕下一段）：不然遊戲裡伸向鏡頭的那頭會看到斷面
    y0 = -0.02
    yl = min(v.co.y for v in ob.data.vertices)
    for v in ob.data.vertices:
        if v.co.y < y0:
            v.co.y = y0 + (v.co.y - y0) * (OUR_ARM_END - y0) / (yl - y0)

    # ---- 骨架的靜止姿勢改成拍圖的姿勢（網格就是照這個姿勢生成的）；彎曲量不用再扣靜止時的彎度 ----
    pose = {pb.name: pb.matrix.copy() for pb in arm.pose.bones}
    vl.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for n, m in pose.items():
        e = arm.data.edit_bones[n]
        e.use_connect = False
        e.matrix = m
    bpy.ops.object.mode_set(mode='OBJECT')
    hands.reset(arm)
    hands.REST_CURL = (0, 0, 0)   # 靜止姿勢的四指是伸直的
    hands.bend = bend             # 張開角度也從拍圖的微張算起

    # ---- 自動權重、零件編號（0 手、1 拇指、2 前臂；切遊戲網格用） ----
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    arm.select_set(True)
    vl.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    gname = {g.index: g.name for g in ob.vertex_groups}
    # 手腕：手掌、前臂兩根骨頭的權重照高度平順交接（hands.py 也是這樣：手腕那圈各半）。
    # 自動權重在手腕交接得太急，握槍時手腕彎最多，皮被壓扁成一片、還折出一條線（左輪腰射最明顯）
    gH, gL = ob.vertex_groups['Hand'], ob.vertex_groups['LowerArm']
    for v in ob.data.vertices:
        ws = {gname[g.group]: g.weight for g in v.groups}
        hl = ws.get('Hand', 0) + ws.get('LowerArm', 0)
        if hl > 0.5 and -0.03 < v.co.y < 0.03:
            k = min(max((v.co.y + 0.02) / 0.04, 0.0), 1.0)
            k = k * k * (3 - 2 * k)
            gH.add([v.index], hl * k, 'REPLACE')
            gL.add([v.index], hl * (1 - k), 'REPLACE')
    # 瘦一圈：Tripo 做的手指、拇指、手腕比我們的粗兩成（遊戲裡左輪的手看起來大一號）。
    # 每個點往它的骨頭中心線拉近（各骨頭照權重混合），形狀不變
    segs = {b.name: (np.array(b.head_local), np.array(b.tail_local)) for b in arm.data.bones}
    for v in ob.data.vertices:
        p = np.array(v.co)
        tot, acc = 0.0, np.zeros(3)
        for g in v.groups:
            h, t = segs[gname[g.group]]
            u = np.clip((p - h) @ (t - h) / ((t - h) @ (t - h)), 0, 1)
            acc += g.weight * (h + u * (t - h))
            tot += g.weight
        if tot > 0:
            v.co = Vector(tuple(p + (1 - THIN) * (acc / tot - p)))
    dom = []
    for v in ob.data.vertices:
        gs = sorted(v.groups, key=lambda x: -x.weight)
        dom.append(gname[gs[0].group] if gs else 'Hand')
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    part = bm.faces.layers.int.new('part')
    for f in bm.faces:
        ns = [dom[v.index] for v in f.verts]
        f[part] = 1 if sum(n.startswith('Thumb') for n in ns) * 2 > len(ns) else (2 if sum(n == 'LowerArm' for n in ns) * 2 > len(ns) else 0)
        f.material_index = 0
    bm.to_mesh(ob.data)
    bm.free()
    return ob, arm


def install():
    hands.build_rig = tripo_build_rig


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    if args[0] == '--views':
        views(args[1])
    else:   # --preview <png>：六格預覽（張開、握槍）
        install()
        mt = [bpy.data.materials.new('c_hand'), bpy.data.materials.new('c_shirt')]
        hands.build(mt, keep_rig=True)
        hands.preview(args[1])
