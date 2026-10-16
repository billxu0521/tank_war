# Tripo 生成的三把槍（docs/素材/：左輪、散彈、炸彈長矛）轉成遊戲用的 glb，零件名字和轉軸照 weapons.py，
# 所以 weapon.gd 的程式動畫（轉輪轉、擊錘、裝填門、退殼桿、散彈折槍管、魚叉射出去）直接套用。
# 做法：一整塊的模型 → 擺正（槍口 +Y、上 +Z）、縮放平移到跟舊槍的關鍵位置對齊（左輪：轉輪中心和槍口；
#   散彈：槍托尾到槍口；長矛：握把到矛尖）→ 照位置切成會動的零件 → 沒顏色的照位置上色 →
#   子彈、霰彈殼直接拿舊 glb 的。輸出 models/<槍>_tripo.glb，遊戲裡 WEAPONS_OLD=1 切回舊的。
# ponytail: 零件和顏色都是照位置的粗略切法（盒子範圍），模型換了要重量重切
# 背景跑：Blender --background --factory-startup --python blender/weapons_tripo.py -- --out models [--preview 資料夾]
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, '..', 'docs', '素材')
OLD = os.path.join(BASE, '..', 'models')

# 轉軸（跟 weapons.py 的 PIVOT 一樣：遊戲裡轉零件就是繞這點）
PIVOT = {
    'Revolver': (0, 0, 0), 'RevolverCylinder': (0, 0.030, 0.035), 'RevolverHammer': (0, -0.012, 0.030),
    'RevolverGate': (0.0205, 0.004, 0.0255), 'RevolverEjector': (0.0075, 0.158, 0.0360),
    'Shotgun': (0, 0, 0), 'ShotgunBarrel': (0, 0.066, 0.016), 'ShotgunHammer': (0, -0.006, 0.034),
    'Lance': (0, 0, 0), 'LanceHarpoon': (0, 0.50, 0.0),
}

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    m.diffuse_color = (*rgb, 1)
    return m


# 顏色沿用 weapons.py（線性值；金屬不做金屬度，跟全場同一套純色）
STEEL = mat('steel', (0.06, 0.06, 0.07))
DARK = mat('steel_dark', (0.02, 0.02, 0.025))
WOOD = mat('wood', (0.145, 0.052, 0.021))
IRON = mat('lance_iron', (0.045, 0.040, 0.034), 0.85)
IRON2 = mat('lance_iron2', (0.075, 0.068, 0.058))
CLOTH = mat('lance_cloth', (0.30, 0.19, 0.08), 0.95)
WOODR = mat('wood_red', (0.16, 0.05, 0.02))
BRASS = mat('brass', (0.40, 0.26, 0.07), 0.7)
ALL_MATS = [STEEL, DARK, WOOD, IRON, IRON2, CLOTH, WOODR, BRASS]


def load(name):
    """匯入一個 Tripo glb，回傳 (物件, 頂點座標 numpy)"""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name))
    o = next(o for o in bpy.data.objects if o not in before and o.type == 'MESH')
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix()
    return o


def xform(o, m):
    o.data.transform(m)


def verts(o):
    return np.array([tuple(v.co) for v in o.data.vertices])


def split(o, part_of, color_of, pivots, cuts=()):
    """照每個面的中心分零件（part_of 回傳零件名）、上色（color_of 回傳材質，None = 保留原本的貼圖材質）。
    每個零件一個物件，原點在轉軸。cuts：[(軸 0/1/2, 值)]，先沿這些平面把網格真的剖開再分，切口補平
    （不剖的話跨過切線的長三角被硬分兩邊，射出去之後管口留一排鋸齒，審查第 1 條）。
    全部改平面著色：Tripo 的圓滑法線在遊戲裡反光偏淺灰、描線斷成碎段（審查第 4、6 條）"""
    if cuts:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        for ax, val in cuts:
            co, no = Vector(), Vector()
            co[ax], no[ax] = val, 1.0
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
        bm.to_mesh(o.data)
        bm.free()
    # 沒貼圖的：材質槽換成上色用的那幾個；有貼圖的保留原本的。要在 to_mesh 之前放好，不然超出槽數的編號會被夾掉
    slots = list(o.data.materials) if color_of is None else ALL_MATS
    out = {}
    for name in set(pivots):
        me = o.data.copy()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        me.materials.clear()
        for m in slots:
            me.materials.append(m)
        bm = bmesh.new()
        bm.from_mesh(me)
        for f in list(bm.faces):
            c = f.calc_center_median()
            if part_of(c) != name:
                bm.faces.remove(f)
            elif color_of:
                f.material_index = slots.index(color_of(c))
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        if cuts:
            edge = [e for e in bm.edges if e.is_boundary and any(all(abs(v.co[ax] - val) < 1e-4 for v in e.verts) for ax, val in cuts)]
            bmesh.ops.holes_fill(bm, edges=edge, sides=0)
        for f in bm.faces:
            f.smooth = False
        p = Vector(pivots[name])
        bmesh.ops.translate(bm, verts=bm.verts, vec=-p)
        bm.to_mesh(me)
        bm.free()
        ob.location = p
        ob['gun'] = gun_of(name)
        out[name] = ob
    bpy.data.objects.remove(o)
    return out


def gun_of(name):
    return next(g for g in ('Revolver', 'Shotgun', 'Lance') if name.startswith(g))


def borrow(glb, names):
    """舊 glb 裡的零件（子彈、霰彈殼）原封不動拿過來"""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OLD, glb))
    for o in set(bpy.data.objects) - before:
        if o.name in names:
            o.parent = None
            o['gun'] = gun_of(o.name)
        else:
            bpy.data.objects.remove(o)


def inside(c, lo, hi):
    return all(lo[i] <= c[i] <= hi[i] for i in range(3))


# ================= 左輪 =================
# 原檔：槍管沿 +X、上 +Z、高度從 0 起。轉輪是最寬的那段（|y| > 0.06）
o = load('revolver_v2 3d model.glb')   # 2026-10-16 Tripo CLI 重做（blender/revolver_v2_prep.py 減面擺正）；舊版原檔 revolver 3d model.glb
P = verts(o)
cyl = P[np.abs(P[:, 1]) > 0.065]
cyl_c = Vector(((cyl[:, 0].min() + cyl[:, 0].max()) / 2, 0, (cyl[:, 2].min() + cyl[:, 2].max()) / 2))
muzzle_x = P[:, 0].max()
old_cyl = Vector(PIVOT['RevolverCylinder'])
s = (0.213 - old_cyl.y) / (muzzle_x - cyl_c.x)   # 轉輪中心到槍口的距離跟舊的一樣
# 擺正：+X → +Y（繞 Z 轉 90 度），再把轉輪中心搬到舊的轉輪轉軸
m = Matrix.Translation(old_cyl) @ Matrix.Scale(s, 4) @ Matrix.Rotation(math.pi / 2, 4, 'Z') @ Matrix.Translation(-cyl_c)
xform(o, m)
# 準星頂對到舊的準星高度（weapons.py 的 SIGHT）：舉槍瞄準靠這條線，比轉輪位置要緊
dz = 0.0655 - verts(o)[:, 2].max()
xform(o, Matrix.Translation((0, 0, dz)))
REV = dict(PIVOT)
for k in ('RevolverCylinder', 'RevolverHammer', 'RevolverGate', 'RevolverEjector'):   # 轉軸跟著網格一起下移，才會繞自己的根部轉
    REV[k] = (PIVOT[k][0], PIVOT[k][1], PIVOT[k][2] + dz)
CZ = old_cyl.z + dz
print('revolver scale %.3f, dz %.4f, cylinder z %.4f' % (s, dz, CZ))
CYL_R = 0.022


def rev_part(c):
    if abs(c.y - 0.030) < 0.024 and math.hypot(c.x, c.z - CZ) < CYL_R + 0.002 and abs(c.x) > 0.004:
        return 'RevolverCylinder'
    if c.y < -0.006 and c.z > CZ + 0.002:
        return 'RevolverHammer'   # 只要擊錘本體：放寬會把轉輪後面那塊機匣一起帶著轉（審查第 2 條）
    if inside(c, (-0.02, 0.07, -0.01), (0.02, 0.13, CZ + 0.012)):   # v2 的退殼桿到 0.125 就停，再過去是槍管下緣
        return 'RevolverEjector'   # 槍管下面那根退殼桿
    if inside(c, (0.012, -0.002, CZ - 0.012), (0.03, 0.010, CZ + 0.004)):
        return 'RevolverGate'
    return 'Revolver'


def rev_color(c):
    return WOOD if c.z < CZ - 0.028 and c.y < -0.012 else STEEL


split(o, rev_part, rev_color, {k: v for k, v in REV.items() if k.startswith('Revolver')},
      cuts=[(1, -0.006), (2, CZ + 0.002)])   # 擊錘的兩條切線剖開：照面中心切的話擊錘一轉開，根部露出鋸齒（第二輪審查）
# v2 的轉輪換成手工那顆（weapons.py）：Tripo 的轉輪跟機匣黏成一塊、減面又壓爛凹槽，挖出來一轉就露縫和尖刺。
# 兩顆大小位置幾乎一樣（半徑 0.022、中心 y 0.030），挖掉的面直接丟
bpy.data.objects.remove(bpy.data.objects['RevolverCylinder'])
borrow('revolver.glb', {'RevolverRound', 'RevolverCylinder'})

# ================= 散彈 =================
# 原檔斜放（俯看偏了一個角度）：用主軸轉正。槍口在 +X。長度縮到跟舊的一樣（槍托尾 -0.39 到槍口 0.788）
o = load('sawed-off+shotgun+3d+model.glb')
P = verts(o)
c0 = P.mean(0)
xy = P[:, :2] - c0[:2]
w, v = np.linalg.eigh(xy.T @ xy)
ax = v[:, -1] if v[0, -1] > 0 else -v[:, -1]   # 主軸朝槍口（+X 那頭）
yaw = math.atan2(ax[1], ax[0])
xform(o, Matrix.Rotation(-yaw, 4, 'Z'))
P = verts(o)
L = P[:, 0].max() - P[:, 0].min()
s = (0.788 + 0.39) / L
mz = P[P[:, 0] > P[:, 0].max() - 0.03]   # 槍口那一圈：高度對到舊槍管中心 0.035
m = Matrix.Translation((0, -0.39, 0.035)) @ Matrix.Scale(s, 4) @ Matrix.Rotation(math.pi / 2, 4, 'Z') \
    @ Matrix.Translation((-P[:, 0].min(), -(mz[:, 1].mean()), -(mz[:, 2].min() + mz[:, 2].max()) / 2))
xform(o, m)
# 扳機（護弓中間，y≈0.05）搬到原點：右手照舊的握把位置擺；準星頂（槍口上緣 0.08）往下對齊舊的瞄準線
xform(o, Matrix.Translation((0, -0.05, -0.009)))
print('shotgun yaw %.1f deg, scale %.3f' % (math.degrees(yaw), s))
# 折開的鉸鏈：機匣前緣下方（新模型的機匣比舊的長，鉸鏈往前挪）。左手托的位置在 shotgun.tscn 的 tripo_overrides
SG = dict(PIVOT)
SG['ShotgunBarrel'] = (0, 0.12, -0.03)


def sg_part(c):
    if c.y > SG['ShotgunBarrel'][1] and c.z > -0.04:
        return 'ShotgunBarrel'
    if inside(c, (-0.012, -0.06, 0.03), (0.012, -0.005, 0.08)):
        return 'ShotgunHammer'
    return 'Shotgun'


# 木紋貼圖在第一人稱被調色推成粉紅（審查第 3 條）：偏紅的像素（木頭）調暗、降飽和，往舊槍的咖啡色 #6A4028 靠
img = next(n.image for n in o.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE')
px = np.array(img.pixels[:]).reshape(-1, 4)
wood = px[:, 0] > px[:, 2] + 0.08
lum = px[wood, :3] @ np.array([0.3, 0.59, 0.11])
px[wood, :3] = (px[wood, :3] * 0.6 + lum[:, None] * 0.4) * np.array([0.78, 0.62, 0.5])
img.pixels[:] = px.ravel()
img.pack()
split(o, sg_part, None, {k: v for k, v in SG.items() if k.startswith('Shotgun')})
borrow('shotgun.glb', {'ShotgunShell'})

# ================= 炸彈長矛 =================
# 原檔：沿 +Y（矛尖在 +Y）、管子中心高 0.15。後面握把（往下伸的那根，y≈-0.28）對到原點，縮到全長 1.27（跟舊的一樣）
o = load('bomb lance launcher 3d model.glb')
P = verts(o)
s = 1.27 / (P[:, 1].max() - P[:, 1].min())
tube = P[(P[:, 1] > -0.2) & (P[:, 1] < 0.0)]
tz = np.median(tube[:, 2])
xform(o, Matrix.Scale(s, 4) @ Matrix.Translation((0, 0.28, -tz)))
print('lance scale %.3f' % s)
HARPOON_Y = 0.50


def lance_part(c):
    return 'LanceHarpoon' if c.y > HARPOON_Y else 'Lance'


def lance_color(c):
    if c.y > 0.80:
        return IRON2          # 矛頭
    if c.y > HARPOON_Y and c.z < -0.03:
        return WOODR          # 掛在下面的炸藥包
    if c.y > HARPOON_Y:
        return BRASS if abs(c.x) > 0.03 else IRON
    if -0.08 < c.y < 0.08 and c.z < -0.03:
        return CLOTH          # 握把
    return IRON


split(o, lance_part, lance_color, {k: v for k, v in PIVOT.items() if k.startswith('Lance')}, cuts=[(1, HARPOON_Y)])

for ob in bpy.data.objects:
    print('  %-18s tris %5d  pos %s' % (ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons), tuple(round(x, 3) for x in ob.location)))

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
out = args[args.index('--out') + 1] if '--out' in args else None
prev = args[args.index('--preview') + 1] if '--preview' in args else None
if prev:
    # 每把槍側面：零件分開上色看切得對不對（tint），和一般材質（mat）；舊槍的外框疊在上面比位置
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1000, 500
    sc.world = bpy.data.worlds.new('w')
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = 'ORTHO'
    pal = [(0.9, 0.3, 0.2, 1), (0.2, 0.7, 0.3, 1), (0.2, 0.4, 0.9, 1), (0.9, 0.8, 0.2, 1), (0.8, 0.3, 0.8, 1), (0.3, 0.8, 0.8, 1)]
    for i, ob in enumerate(o for o in bpy.data.objects if o.type == 'MESH'):
        ob.color = (0.75, 0.75, 0.75, 1) if ob.name == ob['gun'] else pal[i % len(pal)]
    for g, (cy, cz, size) in {'Revolver': (0.08, 0.0, 0.34), 'Shotgun': (0.2, 0.0, 1.30), 'Lance': (0.33, 0.0, 1.40)}.items():
        for ob in bpy.data.objects:
            if ob.type == 'MESH':
                ob.hide_render = ob['gun'] != g
        cam.data.ortho_scale = size
        cam.location = (3, cy, cz)
        cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
        for mode in ('MATERIAL', 'OBJECT'):
            sc.display.shading.color_type = mode if g != 'Shotgun' or mode == 'OBJECT' else 'TEXTURE'
            sc.render.filepath = os.path.join(prev, '%s_%s.png' % (g, mode.lower()))
            bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
if out:
    for g in ('Revolver', 'Shotgun', 'Lance'):
        bpy.ops.object.select_all(action='DESELECT')
        for ob in bpy.data.objects:
            ob.select_set(ob.type == 'MESH' and ob['gun'] == g)
        path = os.path.join(out, g.lower() + '_tripo.glb')
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True)
        print('exported ->', path)
