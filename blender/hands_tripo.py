# 試驗：Tripo 生成的裸手＋前臂（docs/素材/hand_tripo.glb）套進 hands.py 的骨架，骨頭名字不變，握姿照舊由 hands.py 擺。
# 做法：手套對齊到「手的空間」（手腕原點、手指 +Y、手背 +Z、拇指 -X）→ 照手套的手指重擺關節 →
#       Blender 自動算權重 → 換掉 hands.build_rig，其餘流程（握姿、烘、匯出 Rig*）不動。
# 用法：cowboy.py 在 HANDS_TRIPO=1 時呼叫 install()。手部預覽：見檔尾。
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hands

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', '素材', 'hand_tripo.glb')
orig_build_rig = hands.build_rig
OUR_ARM_END = -0.372   # hands.py 的前臂末端 y
WRIST_RATIO = 2.87   # hands.py 的手：指尖到手腕 ÷ 指尖到指縫（0.221 / 0.077）

def tripo_build_rig():
    vl = bpy.context.view_layer
    skin, arm = orig_build_rig()
    # 我們的手伸直時：指尖高度、手腕那段的中心（對齊用）
    hands.reset(arm)
    for n in hands.FINGER_NAMES:
        for s in ('_Proximal', '_Intermediate', '_Distal'):
            hands.bend(arm, n + s, 0)
    vl.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = skin.evaluated_get(dg).to_mesh()
    S = np.array([tuple(skin.matrix_world @ v.co) for v in me.vertices])
    skin.evaluated_get(dg).to_mesh_clear()
    our_tip = S[:, 1].max()
    our_wrist = S[(S[:, 1] > -0.04) & (S[:, 1] < -0.02)].mean(0)
    hands.reset(arm)
    bpy.data.objects.remove(skin)

    # ---- 手套對齊 ----
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
    d = ob.modifiers.new('dec', 'DECIMATE')   # 生成的 9600 面超過 cowboy.glb 每塊 8000 的預算
    d.ratio = 6000 / len(ob.data.polygons)
    vl.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=d.name)
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    c = P.mean(0)
    w, V = np.linalg.eigh(np.cov((P - c).T))
    ax = V[:, 2] * (1 if V[2, 2] > 0 else -1)   # ponytail: 生成時說「手朝上」，手指那頭在 +Z
    pr = (P - c) @ ax
    hi = pr.max()
    # 手腕＝離指尖 35%～80% 之間最細的那段（Tripo 單位）；先照「指尖到手腕」縮，量出手掌寬度後再照寬度縮一次
    L = np.ptp(pr)
    ds = np.arange(0.35, 0.80, 0.02) * L
    u1 = np.cross(ax, [0, 0, 1] if abs(ax[2]) < 0.9 else [1, 0, 0])
    u1 /= np.linalg.norm(u1)
    u2 = np.cross(ax, u1)
    def area(m):   # 這一段的截面大小（兩個方向的寬度相乘）：手掌扁、手腕細又圓，只量一邊會量到手掌的厚度
        return np.ptp(P[m] @ u1) * np.ptp(P[m] @ u2) if m.sum() >= 30 else 9   # 前臂是長三角，點太少的那段量不準
    wd = [area((pr <= hi - d) & (pr > hi - d - 0.02 * L)) for d in ds]
    WR = ds[int(np.argmin(wd))]
    print('手腕離指尖 %.3f（全長 %.3f）' % (WR, L))
    s = (our_tip - our_wrist[1]) / WR
    wrist = P[(pr < hi - WR + 0.02) & (pr > hi - WR - 0.02)].mean(0)
    band = P[(pr < hi - 0.28) & (pr > hi - 0.36)]   # 拇指那段：離手臂軸最遠的點＝拇指
    off = band - wrist
    off = off - np.outer(off @ ax, ax)
    th = off[np.argmax(np.linalg.norm(off, axis=1))]
    fr = P[pr > hi - 0.24] - c                      # 四指張開那段最寬的方向＝手掌左右
    fr = fr - np.outer(fr @ ax, ax)
    X = np.linalg.eigh(np.cov(fr.T))[1][:, 2]
    if X @ th > 0:
        X = -X
    Y = ax
    Z = np.cross(X, Y)
    X = np.cross(Y, Z)
    R = Matrix((tuple(X), tuple(Y), tuple(Z))).to_4x4()
    M = Matrix.Translation(Vector(tuple(our_wrist))) @ Matrix.Scale(s, 4) @ R @ Matrix.Translation(Vector(tuple(-wrist)))
    ob.data.transform(M)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.to_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    T = np.array([tuple(v.co) for v in bm.verts])

    # ---- 找手指：指縫以上切開，四根手指各是一塊 ----
    def comps(mask):
        idx = set(np.nonzero(mask)[0])
        seen, out = set(), []
        for i in idx:
            if i in seen:
                continue
            st, grp = [i], []
            seen.add(i)
            while st:
                a = st.pop()
                grp.append(a)
                for e in bm.verts[a].link_edges:
                    b = e.other_vert(bm.verts[a]).index
                    if b in idx and b not in seen:
                        seen.add(b)
                        st.append(b)
            out.append(grp)
        return sorted(out, key=len, reverse=True)
    y_c = None
    for y in np.arange(T[:, 1].max() - 0.03, 0.0, -0.002):   # 往下找：四指還分開的最低高度＝指縫
        cs = [g for g in comps((T[:, 1] > y) & (T[:, 0] > -0.085)) if len(g) > 30]
        if len(cs) >= 4:
            y_c = y
        elif y_c is not None:
            break
    fingers = sorted(comps((T[:, 1] > y_c) & (T[:, 0] > -0.085))[:4], key=lambda g: T[g, 0].mean())
    # 手掌轉正：四個指根（各手指最低那 1 公分的中心）連成的線＝手掌左右（X）。第一次用手指散開的方向估，
    # 手指微彎、張得不平均時會偏，整隻手繞前臂轉歪（遊戲裡左輪的手背斜對鏡頭，一大團）
    roots = [T[g][T[g][:, 1] < y_c + 0.01].mean(0) for g in fingers]
    xd = roots[3] - roots[0]
    xd[1] = 0
    xd /= np.linalg.norm(xd)
    tw = math.atan2(-xd[2], xd[0])   # 繞 Y 轉多少，指根線才平躺在 X 軸上
    print('手掌繞前臂轉正 %.1f 度' % math.degrees(tw))
    Rw = Matrix.Translation(Vector(tuple(our_wrist))) @ Matrix.Rotation(-tw, 4, 'Y') @ Matrix.Translation(Vector(tuple(-our_wrist)))
    ob.data.transform(Rw)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    T = np.array([tuple(v.co) for v in bm.verts])
    # 手腕扳直：Tripo 的手在手腕往手背翹、前臂往掌心斜，我們的骨架是一直線（握姿的角度全照這個算）。
    # 先整隻轉到「手腕→指根中心」朝 +Y，再把前臂（手腕以下，4 公分內漸變）轉回 -Y
    wv = np.array(our_wrist)
    v = np.mean(roots, axis=0) - wv
    a1 = math.atan2(v[2], v[1])
    ob.data.transform(Matrix.Translation(Vector(tuple(wv))) @ Matrix.Rotation(a1, 4, 'X') @ Matrix.Translation(Vector(tuple(-wv))))
    F = np.array([tuple(p.co) for p in ob.data.vertices])
    near = F[(F[:, 1] < wv[1] - 0.04) & (F[:, 1] > wv[1] - 0.07)].mean(0)
    end = F[F[:, 1] < F[:, 1].min() + 0.03].mean(0)   # 末端封口點多，用主軸會被它帶歪，改用兩段中心連線
    d = end - near
    a2 = math.atan2(d[2], -d[1])
    print('手腕扳直：手掌 %.1f 度、前臂 %.1f 度' % (math.degrees(a1), math.degrees(a2)))
    for p in ob.data.vertices:
        w = min(max((wv[1] - p.co.y) / 0.04, 0.0), 1.0)
        if w > 0:
            p.co = Matrix.Translation(Vector(tuple(wv))) @ Matrix.Rotation(-a2 * w, 4, 'X') @ Matrix.Translation(Vector(tuple(-wv))) @ p.co
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    T = np.array([tuple(v.co) for v in bm.verts])
    # 左右手：拇指尖在掌心那側（-Z）才是右手。Tripo 有時做成左手 → 掌心手背對調（Z 鏡射，拇指仍在 -X）
    root = np.array(hands.THUMB_ROOT)
    TH = T[(T[:, 0] < T[fingers[0], 0].min() - 0.01) & (T[:, 1] < y_c)]
    mirror = TH[np.argmax(np.linalg.norm(TH - root, axis=1))][2] > 0
    # 手腕＝指尖往下「指尖到指縫」的 WRIST_RATIO 倍；手腕截面中心、指尖對到我們的手（第一次對齊的手腕只是估的）
    tip_y = T[:, 1].max()
    y_w = tip_y - WRIST_RATIO * (tip_y - y_c)
    wc = T[np.abs(T[:, 1] - y_w) < 0.01].mean(0)
    wc[1] = y_w
    k = (our_tip - our_wrist[1]) / (tip_y - y_w)
    print('左手→鏡射' if mirror else '右手', '手腕 y %.3f，再縮 %.2f 倍' % (y_w, k))
    W = Matrix.Translation(Vector(tuple(our_wrist))) @ Matrix.Scale(k, 4) @ \
        (Matrix.Scale(-1, 4, Vector((0, 0, 1))) if mirror else Matrix.Identity(4)) @ Matrix.Translation(Vector(tuple(-wc)))
    ob.data.transform(W)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    if mirror:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    T = np.array([tuple(v.co) for v in bm.verts])
    # 手掌厚度、中心對到我們的手（量 y 0.04～0.08 那段）：Tripo 的手背高 1.5 公分，左輪離鏡頭近，手背整片擋住槍
    def band(Q):
        q = Q[(Q[:, 1] > 0.04) & (Q[:, 1] < 0.08) & (Q[:, 0] > -0.04)]
        return (q[:, 2].min() + q[:, 2].max()) / 2, np.ptp(q[:, 2])
    zc_o, th_o = band(S)
    zc_t, th_t = band(T)
    kz = th_o / th_t
    print('手掌厚 %.3f → %.3f（壓 %.2f 倍）' % (th_t, th_o, kz))
    for p in ob.data.vertices:
        w = min(max((p.co.y + 0.02) / 0.03, 0.0), 1.0)   # 手腕以下不動，往手掌 3 公分漸變
        p.co.z += w * (zc_o + (p.co.z - zc_t) * kz - p.co.z)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    T = np.array([tuple(v.co) for v in bm.verts])
    y_c = None
    for y in np.arange(T[:, 1].max() - 0.02, 0.0, -0.002):
        cs = [g for g in comps((T[:, 1] > y) & (T[:, 0] > -0.085)) if len(g) > 30]
        if len(cs) >= 4:
            y_c = y
        elif y_c is not None:
            break
    fingers = sorted(comps((T[:, 1] > y_c) & (T[:, 0] > -0.085))[:4], key=lambda g: T[g, 0].mean())
    print('指縫高度 %.3f' % y_c)
    joints = {}
    for (name, lens, _), g in zip(hands.FINGERS, fingers):
        F = T[g]
        fc = F.mean(0)
        d = np.linalg.eigh(np.cov((F - fc).T))[1][:, 2]
        if d[1] < 0:
            d = -d
        tip = fc + d * ((F - fc) @ d).max()
        root = fc + d * ((y_c - 0.012 - fc[1]) / d[1])   # 指根關節在指縫下面約 1.2 公分
        L = np.linalg.norm(tip - root)
        r = np.cumsum([0] + list(lens)) / sum(lens)
        pts = [root + (tip - root) * k for k in r]
        for k, sfx in enumerate(('_Proximal', '_Intermediate', '_Distal')):
            joints[name + sfx] = (Vector(tuple(pts[k])), Vector(tuple(pts[k + 1])))
        print(name, '長 %.3f' % L)
    # 拇指：手掌食指側外面那團
    root = Vector(hands.THUMB_ROOT)
    TH = T[(T[:, 0] < T[fingers[0], 0].min() - 0.01) & (T[:, 1] < y_c) & (T[:, 1] > root.y - 0.01)]
    far = TH[np.argmax(np.linalg.norm(TH - np.array(root), axis=1))]
    r = np.cumsum([0] + list(hands.THUMB_LEN)) / sum(hands.THUMB_LEN)
    pts = [np.array(root) + (far - np.array(root)) * k for k in r]
    for k, sfx in enumerate(('_Proximal', '_Intermediate', '_Distal')):
        joints['Thumb' + sfx] = (Vector(tuple(pts[k])), Vector(tuple(pts[k + 1])))
    print('Thumb 長 %.3f' % np.linalg.norm(far - np.array(root)))

    # 前臂拉長到跟 hands.py 的一樣（Tripo 的只到手腕下 12 公分）：不然遊戲裡伸向鏡頭的那頭會看到斷面
    y0 = -0.02
    yl = T[:, 1].min()
    for v in ob.data.vertices:
        if v.co.y < y0:
            v.co.y = y0 + (v.co.y - y0) * (OUR_ARM_END - y0) / (yl - y0)
    # ---- 骨架改到 Tripo 手的手指上；手指是直的，彎曲量不用再扣靜止時的彎度 ----
    vl.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for n, (h, t) in joints.items():
        e = arm.data.edit_bones[n]
        e.use_connect = False
        e.head, e.tail = h, t
        e.align_roll(hands.THUMB_NAIL if n.startswith('Thumb') else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    hands.REST_CURL = (0, 0, 0)
    hands.NAILS.clear()

    # ---- 自動權重、零件編號（0 手、1 拇指、2 前臂；切遊戲網格用） ----
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    arm.select_set(True)
    vl.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    # 拇指掌骨（Thumb_Proximal）藏在手掌裡：自動權重把拇指根那一大塊手掌都分給它，遊戲裡左輪扳擊錘轉拇指時
    # 半個手掌被拉出去（畫面下方一大團）。掌骨前半段以內的權重漸漸還給 Hand
    th = arm.data.bones['Thumb_Proximal']
    h0, h1 = arm.matrix_world @ th.head_local, arm.matrix_world @ th.tail_local
    gp, gh = ob.vertex_groups['Thumb_Proximal'], ob.vertex_groups['Hand']
    for v in ob.data.vertices:
        w = next((g.weight for g in v.groups if g.group == gp.index), 0.0)
        if w > 0:
            t = (v.co - h0).dot(h1 - h0) / (h1 - h0).length_squared
            keep = min(max((t - 0.3) / 0.5, 0.0), 1.0)
            gp.add([v.index], w * keep, 'REPLACE')
            gh.add([v.index], w * (1 - keep), 'ADD')
    gname = {g.index: g.name for g in ob.vertex_groups}
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
    print('權重群組', sorted(g.name for g in ob.vertex_groups))
    return ob, arm



def install():
    hands.build_rig = tripo_build_rig


if __name__ == '__main__':   # 手部六格預覽：Blender --background --factory-startup --python blender/hands_tripo.py -- <png>
    install()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    mt = [bpy.data.materials.new('c_glove'), bpy.data.materials.new('c_shirt')]
    hands.build(mt, keep_rig=True)
    hands.preview(sys.argv[sys.argv.index('--') + 1])
