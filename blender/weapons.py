# 牛仔的三把槍：左輪、單管散彈、槓桿步槍。
#
# 座標直接用 Blender 的：X 右、Y 前（= Godot -Z，槍口方向）、Z 上。單位公尺，真實尺寸。
# 原點 = 扳機位置。視角模型的擺位（cowboy/weapons/*.tscn）以這點為準。
#
# 會動的零件各自一個物件，原點放在轉軸上，匯出後節點位置就是轉軸：
#   左輪  Revolver / RevolverCylinder（開槍轉 60 度）/ RevolverHammer（扳擊錘）
#   散彈  Shotgun / ShotgunBarrel（換彈時繞鉸鏈折開）/ ShotgunHammer
#   步槍  Rifle / RifleLever（拉桿上膛）/ RifleHammer
# PIVOT 和 SIGHT 兩張表跟遊戲共用：改了要去 cowboy/weapon_model.gd 和武器場景對一下。
#
# 重建：Blender 裡 BASE = '<這個資料夾>'; exec(open(BASE + '/weapons.py').read())
import bpy, bmesh, math, os
from mathutils import Vector
exec(open(BASE + '/common.py').read())

X90 = (math.pi / 2, 0, 0)   # 圓柱預設沿 Z，轉到沿 Y（槍管方向）
Y90 = (0, math.pi / 2, 0)   # 沿 X（橫軸，鉸鏈和插銷）

PIVOT = {
    'RevolverCylinder': (0, 0.030, 0.035),
    'RevolverHammer':   (0, -0.012, 0.030),
    'ShotgunBarrel':    (0, 0.066, 0.016),
    'ShotgunHammer':    (0, -0.006, 0.034),
    'RifleLever':       (0, 0.060, -0.006),
    'RifleHammer':      (0, -0.028, 0.030),
}
# 準星連線的高度（Z）。遊戲裡舉槍時把這條線對到鏡頭中心
SIGHT = {'Revolver': 0.058, 'Shotgun': 0.061, 'Rifle': 0.058}

# wipe() 靠選取來刪，藏起來的物件選不到會殘留，重跑就多一份 .001——直接從資料刪
for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o)
wipe()
BLUED = mat('blued', (0.07, 0.08, 0.10), 0.35, 0.85)
CASE  = mat('case',  (0.28, 0.24, 0.22), 0.40, 0.85)   # 表面硬化的機匣，比槍管亮一點
BRASS = mat('brass', (0.72, 0.52, 0.20), 0.30, 0.90)
WOOD  = mat('wood',  (0.36, 0.18, 0.08), 0.55)
WOOD2 = mat('wood2', (0.24, 0.12, 0.05), 0.60)         # 握把片、槍托底，深一點才分得出零件
BORE  = mat('bore',  (0.01, 0.01, 0.01), 0.9)


def ring(R, r, loc, m=None):
    """扳機護弓、拉桿環：軸沿 X 的圓環（環面在 Y-Z 平面）"""
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=20,
                                     minor_segments=6, location=loc, rotation=Y90)
    return _push(bpy.context.object, m)


def taper(o, back_scale, front_scale, axis_z=True):
    """沿 Y 由後往前縮放高度（或寬度）。槍托、握把、護木都是前細後粗或反過來"""
    ys = [v.co.y for v in o.data.vertices]
    y0, y1 = min(ys), max(ys)
    for v in o.data.vertices:
        t = (v.co.y - y0) / max(y1 - y0, 1e-6)
        k = back_scale + (front_scale - back_scale) * t
        if axis_z:
            v.co.z *= k
        else:
            v.co.x *= k
    return o


def local_box(size, loc, rot=(0, 0, 0), m=None):
    """box 但在原點建好再縮放/旋轉，最後才搬過去——taper 要在物件自己的座標裡做"""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.rotation_euler = rot
    o.location = loc
    return _push(o, m)


def loft(stations, m=None, n=20, e=0.55):
    """木頭件（槍托、護木）：沿 Y 在幾個位置訂斷面，接成一條圓角實體。
    stations = [(y, 上緣 z, 下緣 z, 半寬)]，由後往前。e 越小斷面越方（1＝橢圓）。
    方塊疊出來的槍托像積木，木頭的弧度要靠這個"""
    bm = bmesh.new()
    rings = []
    for (y, zt, zb, hw) in stations:
        zc, hz = (zt + zb) / 2, (zt - zb) / 2
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            c, s_ = math.cos(a), math.sin(a)
            x = hw * math.copysign(abs(c) ** e, c)
            z = zc + hz * math.copysign(abs(s_) ** e, s_)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('loft')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('loft', me)
    bpy.context.collection.objects.link(o)
    return _push(o, m)


def part(name, pivot=(0, 0, 0), bevel=0.0015):
    """合併成一個物件，原點立刻搬到轉軸。join 完原點停在第一個零件上、
    旋轉也還沒烘進網格——不先整好，之後任何移動都會把零件帶偏"""
    o = finish(name, bevel=bevel, seg=2, smooth_mats=('wood', 'wood2'))
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)
    o['pivot'] = pivot
    return o


# ================= 左輪（單動式，1873 那種） =================
# 功能零件：框（轉輪卡在窗裡）、轉輪（六個彈巢）、擊錘＋扳手、扳機＋護弓、頂條的照門槽、準星、
# 退殼桿套管＋推鈕、裝填門、轉輪軸插銷、握把片＋背條
# 機匣是一個框：轉輪卡在中間的窗裡，前後上下各一段
box((0.030, 0.036, 0.046), (0, -0.009, 0.030), m=CASE)                # 後框（擋住彈底）
box((0.022, 0.052, 0.010), (0, 0.030, 0.010), m=CASE)                 # 下框
box((0.024, 0.010, 0.040), (0, 0.056, 0.034), m=CASE)                 # 前框（鎖槍管）
box((0.020, 0.050, 0.006), (0, 0.030, 0.056), m=BLUED)                # 頂條
box((0.020, 0.006, 0.004), (0, 0.004, 0.061), m=BLUED)                # 照門（兩片夾一道槽）
box((0.007, 0.006, 0.010), (0.007, 0.001, 0.061), m=BLUED)
box((0.007, 0.006, 0.010), (-0.007, 0.001, 0.061), m=BLUED)
cyl(0.0095, 0.140, (0, 0.122, 0.042), X90, 24, m=BLUED)               # 槍管
cyl(0.0045, 0.142, (0, 0.123, 0.042), X90, 10, m=BORE)                # 膛線孔
box((0.003, 0.010, 0.008), (0, 0.186, 0.054), m=BLUED)                # 準星
cyl(0.0050, 0.100, (0.007, 0.110, 0.026), X90, 10, m=BLUED)           # 退殼桿套管
sphere(0.0045, (0.007, 0.160, 0.026), 10, 6, m=BLUED)                 # 退殼推鈕
cyl(0.0030, 0.010, (0, 0.053, 0.022), X90, 8, m=BLUED)                # 轉輪軸插銷頭
box((0.004, 0.016, 0.018), (0.016, 0.028, 0.033), m=BLUED)            # 裝填門（右側）
box((0.004, 0.005, 0.020), (0, 0.004, 0.004), (0.25, 0, 0), m=BLUED)  # 扳機
ring(0.016, 0.0025, (0, 0.006, 0.000), m=BRASS)                       # 護弓
# 犁柄握把：沿一段往後彎的弧線一片一片疊，越往下越寬、越往後，底部一顆圓頭。
# 單動左輪一眼認得出來就靠這個輪廓，直的方塊會像自動手槍
GRIP_ARC = [(-0.012, 0.008), (-0.018, -0.008), (-0.025, -0.024), (-0.032, -0.040),
            (-0.039, -0.055), (-0.046, -0.068), (-0.052, -0.079)]
for k in range(len(GRIP_ARC) - 1):
    (y0, z0), (y1, z1) = GRIP_ARC[k], GRIP_ARC[k + 1]
    ang = math.atan2(y1 - y0, z0 - z1)             # 這一片往後傾多少（負的＝底部往後）
    depth = 0.030 + 0.006 * k / len(GRIP_ARC)       # 越往下越厚，握起來才塞滿手掌
    mid = (0, (y0 + y1) / 2, (z0 + z1) / 2)
    local_box((0.027, depth, 0.019), mid, (ang, 0, 0), m=WOOD)                     # 握把木片
    local_box((0.018, 0.005, 0.019), (0, mid[1] - depth / 2, mid[2]), (ang, 0, 0), m=BLUED)   # 背條
cyl(0.017, 0.025, (0, -0.050, -0.080), Y90, 16, m=WOOD)                # 握把底的圓頭
cyl(0.004, 0.030, (0, -0.030, -0.030), Y90, 8, m=BLUED)                # 握把螺絲
part('Revolver')

cyl(0.0200, 0.042, PIVOT['RevolverCylinder'], X90, 18, m=BLUED)       # 轉輪
cyl(0.0205, 0.004, (0, 0.012, 0.035), X90, 18, m=BLUED)               # 後緣
for k in range(6):                                                    # 六個彈巢，從前面看得到
    a = 2 * math.pi * k / 6
    cyl(0.0052, 0.044, (0.0125 * math.cos(a), 0.030, 0.035 + 0.0125 * math.sin(a)),
        X90, 10, m=BORE)
    # 彈巢之間的凹槽：減重的溝，也是一眼認得出是轉輪的特徵
    b = a + math.pi / 6
    box((0.004, 0.028, 0.004), (0.0195 * math.cos(b), 0.032, 0.035 + 0.0195 * math.sin(b)),
        (0, -b, 0), m=BORE)
part('RevolverCylinder', PIVOT['RevolverCylinder'])

box((0.008, 0.012, 0.030), (0, -0.016, 0.046), (-0.30, 0, 0), m=BLUED)  # 擊錘
box((0.013, 0.016, 0.004), (0, -0.028, 0.061), (-0.25, 0, 0), m=BLUED)  # 扳手（有紋路的拇指處）
for k in range(3):
    box((0.013, 0.002, 0.0012), (0, -0.034 + k * 0.005, 0.0635), (-0.25, 0, 0), m=BORE)
part('RevolverHammer', PIVOT['RevolverHammer'])


# ================= 單管散彈（折開式） =================
# 功能零件：鉸鏈軸、槍管底下的閉鎖凸耳、頂部開膛扳、外露擊錘、準星珠、
# 扳機＋護弓、槍托握把＋托身＋底板、護木（跟著槍管一起折）
box((0.036, 0.092, 0.050), (0, 0.020, 0.030), m=CASE)                 # 機匣
cyl(0.0060, 0.040, (0, 0.066, 0.016), Y90, 12, m=BLUED)               # 鉸鏈軸（橫穿）
box((0.012, 0.042, 0.005), (0, -0.012, 0.0555), (0, 0, 0.35), m=BLUED) # 開膛扳（往右撥）；要低於準星珠，不然擋瞄準線
box((0.004, 0.005, 0.022), (0, 0.004, 0.002), (0.25, 0, 0), m=BLUED)  # 扳機
ring(0.022, 0.0028, (0, 0.006, -0.004), m=BLUED)                      # 護弓
# 直托（英式）：接機匣處跟機匣一樣高、腕部收細給手握、往後托身變寬變深、底部抵肩
loft([(-0.378, 0.027, -0.100, 0.021), (-0.300, 0.029, -0.085, 0.021),
      (-0.200, 0.032, -0.056, 0.019), (-0.120, 0.036, -0.022, 0.016),
      (-0.070, 0.040, -0.003, 0.0145), (-0.022, 0.052, 0.008, 0.017)], m=WOOD)
loft([(-0.390, 0.027, -0.101, 0.0215), (-0.378, 0.027, -0.101, 0.0215)], m=WOOD2)  # 槍托底板
cyl(0.0025, 0.050, (0.021, -0.30, -0.03), Y90, 6, m=BLUED)            # 背帶環
part('Shotgun')

cyl(0.0140, 0.720, (0, 0.426, 0.046), X90, 18, m=BLUED)               # 槍管
cyl(0.0100, 0.722, (0, 0.427, 0.046), X90, 12, m=BORE)                # 膛口
sphere(0.0032, (0, 0.780, 0.0625), 8, 6, m=BRASS)                     # 準星珠
box((0.018, 0.045, 0.022), (0, 0.090, 0.026), m=BLUED)                # 閉鎖凸耳（掛在鉸鏈上）
loft([(0.108, 0.040, 0.012, 0.016), (0.150, 0.040, 0.008, 0.0175),
      (0.285, 0.040, 0.014, 0.015), (0.315, 0.038, 0.024, 0.011)], m=WOOD)  # 護木（前端收圓）
part('ShotgunBarrel', PIVOT['ShotgunBarrel'])

# 擊錘頂端要低於準星珠（SIGHT 0.061），不然舉槍時擋在瞄準線上
box((0.008, 0.012, 0.022), (0, -0.012, 0.045), (-0.35, 0, 0), m=BLUED)
box((0.012, 0.014, 0.004), (0, -0.020, 0.055), (-0.30, 0, 0), m=BLUED)
part('ShotgunHammer', PIVOT['ShotgunHammer'])


# ================= 槓桿步槍（1873） =================
# 功能零件：黃銅機匣、右側裝填門、八角槍管、管狀彈匣＋前蓋、槍管箍、
# 準星＋羊角照門、擊錘、拉桿環（手指伸進去拉）、扳機、護木、槍托＋月牙底板
box((0.034, 0.130, 0.056), (0, 0.030, 0.020), m=BRASS)                # 機匣
box((0.003, 0.034, 0.014), (0.0185, 0.034, 0.010), m=BLUED)           # 裝填門
cyl(0.0115, 0.600, (0, 0.395, 0.034), X90, 8, m=BLUED)                # 八角槍管
cyl(0.0048, 0.602, (0, 0.396, 0.034), X90, 10, m=BORE)
cyl(0.0082, 0.540, (0, 0.365, 0.012), X90, 14, m=BLUED)               # 管狀彈匣
cyl(0.0090, 0.012, (0, 0.638, 0.012), X90, 14, m=BLUED)               # 彈匣前蓋
box((0.026, 0.012, 0.042), (0, 0.620, 0.023), m=BLUED)                # 槍管箍
box((0.003, 0.012, 0.010), (0, 0.688, 0.051), m=BLUED)                # 準星
box((0.022, 0.005, 0.010), (0, 0.205, 0.048), m=BLUED)                # 羊角照門（底座）
box((0.005, 0.005, 0.012), (0.0085, 0.205, 0.056), (0, 0.3, 0), m=BLUED)
box((0.005, 0.005, 0.012), (-0.0085, 0.205, 0.056), (0, -0.3, 0), m=BLUED)
loft([(0.098, 0.034, -0.004, 0.016), (0.140, 0.034, -0.006, 0.0165),
      (0.300, 0.032, -0.003, 0.015), (0.328, 0.030, 0.004, 0.012)], m=WOOD)  # 護木（包住彈匣）
box((0.004, 0.005, 0.018), (0, 0.004, 0.000), (0.25, 0, 0), m=BLUED)  # 扳機
# 槍托：腕部細、托身往後變深。拉桿環就在腕部下面，腕部要夠細手指才伸得進環
loft([(-0.372, 0.020, -0.100, 0.021), (-0.330, 0.021, -0.095, 0.021),
      (-0.220, 0.024, -0.074, 0.019), (-0.130, 0.028, -0.040, 0.016),
      (-0.080, 0.031, -0.020, 0.014), (-0.034, 0.040, -0.006, 0.016)], m=WOOD)
# 月牙底板：黃銅，上下兩個尖角勾住肩膀（1873 的招牌），中間凹進去
box((0.042, 0.008, 0.100), (0, -0.376, -0.040), m=BRASS)
for zz, rr in ((0.018, 0.5), (-0.098, -0.5)):
    box((0.040, 0.020, 0.008), (0, -0.382, zz), (rr, 0, 0), m=BRASS)
part('Rifle')

box((0.008, 0.100, 0.008), (0, 0.020, -0.012), m=BLUED)               # 拉桿前段（貼著機匣底，接到環）
ring(0.030, 0.0042, (0, -0.030, -0.040), m=BLUED)                     # 手指伸進去的環
part('RifleLever', PIVOT['RifleLever'])

# 擊錘頂端要低於照門（SIGHT 0.058），不然舉槍時擋在瞄準線上
box((0.008, 0.012, 0.022), (0, -0.032, 0.042), (-0.35, 0, 0), m=BLUED)
box((0.012, 0.014, 0.004), (0, -0.040, 0.051), (-0.30, 0, 0), m=BLUED)
part('RifleHammer', PIVOT['RifleHammer'])


# ================= 排版看圖、匯出 =================
LAYOUT = {'Revolver': 0.0, 'Shotgun': -0.25, 'Rifle': -0.5}   # 只是讓三把在視窗裡不重疊


def group_of(name):
    return next(k for k in LAYOUT if name.startswith(k))


def show_layout(only=None):
    """從右側看時三把上下錯開；only 給名字就只顯示那一把"""
    for o in bpy.data.objects:
        if o.type == 'MESH':
            g = group_of(o.name)
            p = o['pivot']
            o.location = (p[0], p[1], p[2] + LAYOUT[g])
            o.hide_viewport = only is not None and g != only


def side_view(center, dist):
    """正側面、正交、SOLID 著色——沒貼圖的近距離檢查就靠這個"""
    from mathutils import Quaternion, Vector
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces[0]
            sp.shading.type = 'SOLID'
            r3 = sp.region_3d
            r3.view_rotation = Quaternion((0.5, 0.5, 0.5, 0.5))
            r3.view_location = Vector(center)
            r3.view_distance = dist
            r3.view_perspective = 'ORTHO'


def export(out_dir):
    """每把槍一個 .glb。節點位置＝轉軸位置，遊戲裡轉那個節點就是繞軸轉。"""
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.location = o['pivot']
            o.hide_viewport = False
    for g in LAYOUT:
        bpy.ops.object.select_all(action='DESELECT')
        for o in bpy.data.objects:
            if o.type == 'MESH' and group_of(o.name) == g:
                o.select_set(True)
        path = os.path.join(out_dir, g.lower() + '.glb')
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                                  export_apply=True, export_yup=True)
        print('exported ->', path)
