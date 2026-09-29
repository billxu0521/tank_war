# 牛仔的三把槍：左輪、單管散彈、槓桿步槍。
#
# 座標直接用 Blender 的：X 右、Y 前（= Godot -Z，槍口方向）、Z 上。單位公尺，真實尺寸。
# 原點 = 扳機位置。視角模型的擺位（cowboy/weapons/*.tscn）以這點為準。
#
# 會動的零件各自一個物件，原點放在轉軸上，匯出後節點位置就是轉軸：
#   左輪  Revolver / RevolverCylinder（開槍轉 60 度）/ RevolverHammer（扳擊錘）/
#         RevolverGate（裝填門）/ RevolverEjector（退殼桿）/ RevolverRound（子彈）
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
    'RevolverGate':     (0.0205, 0.004, 0.0255),     # 裝填門的鉸鏈（下緣，軸沿槍管）
    'RevolverEjector':  (0.0075, 0.158, 0.0360),     # 退殼桿推鈕
    'RevolverRound':    (0, 0, 0),                   # 子彈（遊戲裡程式擺位置）
    'ShotgunBarrel':    (0, 0.066, 0.016),
    'ShotgunShell':     (0, 0, 0),                   # 霰彈（換彈時右手拿著，遊戲裡程式擺位置）
    'RifleRound':       (0, 0, 0),                   # 步槍子彈（同上）
    'ShotgunHammer':    (0, -0.006, 0.034),
    'RifleLever':       (0, 0.060, -0.006),
    'RifleHammer':      (0, -0.028, 0.030),
}
# 準星連線的高度（Z）。遊戲裡舉槍時把這條線對到鏡頭中心
SIGHT = {'Revolver': 0.0655, 'Shotgun': 0.061, 'Rifle': 0.058}

# wipe() 靠選取來刪，藏起來的物件選不到會殘留，重跑就多一份 .001——直接從資料刪
for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o)
wipe()
BLUED = mat('blued', (0.045, 0.045, 0.054), 0.8)          # 金屬一律不做金屬度：純色平面著色，跟全場同一套（金屬反射天空會變粉彩塑膠）
CASE  = mat('case',  (0.075, 0.068, 0.064), 0.8)   # 表面硬化的機匣，比槍管亮一點
BRASS = mat('brass', (0.40, 0.26, 0.07), 0.7)
WOOD  = mat('wood',  (0.145, 0.052, 0.021), 0.8)          # sRGB 約 #6A4028
WOOD2 = mat('wood2', (0.09, 0.032, 0.013), 0.8)         # 握把片、槍托底，深一點才分得出零件
BORE  = mat('bore',  (0.01, 0.01, 0.01), 0.9)
STEEL = mat('steel', (0.06, 0.06, 0.07), 0.8)    # Pax 是沒烤藍的鋼：灰亮、有反光
DARK  = mat('steel_dark', (0.02, 0.02, 0.025), 0.8)  # 螺絲、扳手紋路
GUNMETAL = mat('gunmetal', (0.05, 0.05, 0.06), 0.8)   # 步槍側板、底板：比烤藍亮一點才分得出零件
WOODR = mat('wood_red', (0.16, 0.05, 0.02), 0.8)       # 散彈的槍托偏紅
HULL  = mat('hull',  (0.85, 0.68, 0.18), 0.6)        # 霰彈的黃色紙殼（影片裡那顆）
HULL2 = mat('hull2', (0.55, 0.42, 0.10), 0.7)
LEAD  = mat('lead',  (0.45, 0.44, 0.42), 0.5, 0.3)


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
    o = finish(name, bevel=bevel, seg=2, smooth_mats=('wood', 'wood2', 'wood_red'))
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)
    o['pivot'] = pivot
    return o


# ================= 左輪（單動式，照 Hunt 的 Caldwell Pax） =================
# 功能零件：框（轉輪卡在窗裡）、後面圓形的擋彈板、轉輪（六個彈巢，最上面那個對準槍管）、
# 擊錘＋有紋路的大扳手、扳機＋護弓、頂條的照門槽、準星片、框側的螺絲、
# 退殼桿套管、犁柄木握把（前後有鋼條）
# 會動的：轉輪（開槍轉 60 度）、擊錘、裝填門（換彈往右翻開）、退殼桿（往後推把彈殼頂出去）、
# 子彈（換彈時左手捏著塞進去；另一顆當退出來的空殼）
CYL_Z = PIVOT['RevolverCylinder'][2]
CHAMBER = 0.0125                      # 彈巢離轉輪軸多遠
BORE_Z = CYL_Z + CHAMBER              # 最上面那個彈巢＝槍管的高度

box((0.026, 0.020, 0.044), (0, -0.003, 0.034), m=STEEL)               # 後框：擋彈板後面那一段
cyl(0.0225, 0.006, (0, 0.006, CYL_Z), X90, 24, m=STEEL)               # 擋彈板（轉輪後面那片圓的）
box((0.022, 0.056, 0.012), (0, 0.030, 0.010), m=STEEL)                # 下框
box((0.024, 0.010, 0.036), (0, 0.056, 0.042), m=STEEL)                # 前框（鎖槍管）
box((0.018, 0.064, 0.006), (0, 0.023, 0.0595), m=STEEL)               # 頂條
box((0.006, 0.010, 0.004), (0.0055, -0.004, 0.0635), m=STEEL)         # 照門：頂條尾端兩片夾一道槽
box((0.006, 0.010, 0.004), (-0.0055, -0.004, 0.0635), m=STEEL)
cyl(0.0092, 0.150, (0, 0.136, BORE_Z), X90, 24, m=STEEL)              # 槍管
cyl(0.0102, 0.012, (0, 0.066, BORE_Z), X90, 24, m=STEEL)              # 槍管根部粗一圈
cyl(0.0042, 0.152, (0, 0.137, BORE_Z), X90, 12, m=BORE)               # 膛線孔
box((0.0025, 0.012, 0.0095), (0, 0.203, BORE_Z + 0.0132), m=STEEL)    # 準星片：頂端＝SIGHT＝照門兩片的頂，要高過頂條才看得到
cyl(0.0052, 0.098, (0.0075, 0.110, BORE_Z - 0.0115), X90, 12, m=STEEL)  # 退殼桿套管（槍管右下）
cyl(0.0028, 0.010, (0, 0.062, 0.026), X90, 10, m=DARK)                # 轉輪軸插銷頭
for sx in (1, -1):                                                    # 框側三顆螺絲
    for (yy, zz) in ((-0.004, 0.020), (0.012, 0.012), (-0.018, 0.012)):
        cyl(0.0028, 0.002, (sx * 0.014, yy, zz), Y90, 10, m=DARK)
box((0.004, 0.005, 0.020), (0, 0.006, 0.002), (0.30, 0, 0), m=DARK)   # 扳機
ring(0.017, 0.0026, (0, 0.006, -0.002), m=STEEL)                      # 護弓


def sweep(path, m=None, n=18, e=0.6):
    """沿 Y-Z 平面上的一條曲線放樣，斷面跟著曲線轉。path = [(y, z, 半寬 x, 半深)]。
    犁柄握把是往後彎的，loft 只能沿直線，疊方塊又像積木"""
    bm = bmesh.new()
    rings = []
    for i, (y, z, hw, hd) in enumerate(path):
        a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        t = Vector((0, b[0] - a[0], b[1] - a[1])).normalized()
        nrm = Vector((0, -t.z, t.y))                                   # 曲線在 Y-Z 平面的法線
        ring = []
        for k in range(n):
            ang = 2 * math.pi * k / n
            c, s_ = math.cos(ang), math.sin(ang)
            off = Vector((hw * math.copysign(abs(c) ** e, c), 0, 0)) + nrm * hd * math.copysign(abs(s_) ** e, s_)
            ring.append(bm.verts.new(Vector((0, y, z)) + off))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('sweep')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('sweep', me)
    bpy.context.collection.objects.link(o)
    return _push(o, m)


# 犁柄握把：從擊錘後面往後拱、再往下收，底部往前勾。單動左輪一眼認得出來就靠這個輪廓
# 擊錘套＋背條：一條鋼從頂條後端繞過擊錘、沿握把背面下來（前後鋼條夾住木頭）
sweep([(-0.004, 0.060, 0.009, 0.004), (-0.016, 0.056, 0.010, 0.005), (-0.024, 0.046, 0.011, 0.006),
       (-0.028, 0.030, 0.011, 0.006), (-0.030, 0.012, 0.010, 0.005)], m=STEEL)
box((0.024, 0.022, 0.030), (0, -0.016, 0.028), m=STEEL)               # 擊錘套側板（擊錘在中間的槽裡）
GRIP = [(-0.013, 0.012, 0.0130, 0.0140), (-0.022, -0.004, 0.0142, 0.0160),
        (-0.029, -0.022, 0.0150, 0.0175), (-0.033, -0.040, 0.0152, 0.0185),
        (-0.034, -0.055, 0.0150, 0.0185), (-0.031, -0.066, 0.0138, 0.0165),
        (-0.027, -0.072, 0.0110, 0.0120), (-0.024, -0.074, 0.0060, 0.0060)]
sweep(GRIP, m=WOOD)
sweep([(y - hd + 0.001, z, 0.009, 0.0026) for (y, z, _, hd) in GRIP[:-2]], m=STEEL)   # 背條
sweep([(y + hd - 0.001, z, 0.009, 0.0024) for (y, z, _, hd) in GRIP[:-3]], m=STEEL)   # 前條
part('Revolver')

cyl(0.0210, 0.040, PIVOT['RevolverCylinder'], X90, 32, m=STEEL)       # 轉輪
for dy in (-0.0215, 0.0215):                                          # 前後倒圓角：Pax 的轉輪是圓鼓鼓的
    cyl(0.0195, 0.003, (0, 0.030 + dy, CYL_Z), X90, 32, m=STEEL)
for k in range(6):
    a = math.pi / 2 + 2 * math.pi * k / 6                             # 從最上面開始排，才會對準槍管
    cx, cz = CHAMBER * math.cos(a), CYL_Z + CHAMBER * math.sin(a)
    cyl(0.0056, 0.047, (cx, 0.030, cz), X90, 12, m=BORE)              # 彈巢，前後都看得到
    b = a + math.pi / 6                                               # 彈巢之間的卡榫凹口
    box((0.003, 0.005, 0.003), (0.0208 * math.cos(b), 0.034, CYL_Z + 0.0208 * math.sin(b)),
        (0, -b, 0), m=DARK)
part('RevolverCylinder', PIVOT['RevolverCylinder'])

# 擊錘：建的是扳起來的樣子（遊戲裡開槍時往前打下去）。扳手要大，Hunt 裡拇指扳它是招牌動作
box((0.008, 0.012, 0.030), (0, -0.018, 0.044), (-0.35, 0, 0), m=STEEL)
box((0.012, 0.014, 0.005), (0, -0.030, 0.054), (-0.25, 0, 0), m=STEEL)  # 扳手：頂端要低於準星線，不然擋照門
box((0.012, 0.010, 0.005), (0, -0.040, 0.0525), (0.25, 0, 0), m=STEEL)   # 扳手尾端往下勾
for k in range(4):
    box((0.012, 0.0015, 0.0012), (0, -0.036 + k * 0.004, 0.0567 - k * 0.001), (-0.25, 0, 0), m=DARK)
part('RevolverHammer', PIVOT['RevolverHammer'])

# 裝填門：擋彈板右下那一格（最上面彈巢往右轉兩格＝-30 度），鉸鏈在下緣、軸沿槍管
box((0.004, 0.010, 0.013), (0.0205, 0.004, CYL_Z - 0.004), m=STEEL)
part('RevolverGate', PIVOT['RevolverGate'])

cyl(0.0022, 0.100, (0.0075, 0.112, BORE_Z - 0.0115), X90, 8, m=DARK)  # 退殼桿
cyl(0.0040, 0.008, (0.0115, 0.158, BORE_Z - 0.0115), Y90, 12, m=STEEL)  # 推鈕，往右突出給拇指推
part('RevolverEjector', PIVOT['RevolverEjector'])

# 子彈：原點在彈殼中間、沿 +Y。塞彈時左手捏著它
cyl(0.0056, 0.028, (0, 0, 0), X90, 12, m=BRASS)
cyl(0.0068, 0.0016, (0, -0.0148, 0), X90, 14, m=BRASS)                # 彈底緣
cyl(0.0052, 0.006, (0, 0.017, 0), X90, 12, m=LEAD)
sphere(0.0052, (0, 0.020, 0), 12, 6, m=LEAD)
part('RevolverRound', PIVOT['RevolverRound'])


# ================= 單管散彈（折開式，照 Hunt 的 Romero 77） =================
# 功能零件：圓潤的鋼機匣（側面開膛滑鈕、橢圓徽章、螺絲）、鉸鏈軸、外露擊錘、扳機＋圓護弓、
# 英式直托（腕部有防滑紋、鋼底板）、槍管（後粗前細、鉸鏈處一圈加厚）、長前護木、準星珠
# 機匣：側面平、上下圓，前端接鉸鏈、後端收進槍托
loft([(-0.030, 0.049, 0.012, 0.0165), (-0.020, 0.055, 0.005, 0.0180),
      (0.052, 0.055, 0.004, 0.0180), (0.066, 0.050, 0.012, 0.0165)], m=STEEL, e=0.35)
cyl(0.0060, 0.040, (0, 0.066, 0.016), Y90, 12, m=DARK)                # 鉸鏈軸（橫穿）
box((0.004, 0.014, 0.007), (-0.0185, 0.000, 0.040), m=DARK)           # 開膛滑鈕（左側，往前推就折開）
for k in range(3):
    box((0.0012, 0.002, 0.007), (-0.0205, -0.005 + k * 0.005, 0.040), m=STEEL)
for sx in (1, -1):
    cyl(0.0095, 0.0015, (sx * 0.0182, 0.028, 0.028), Y90, 20, m=DARK)  # 橢圓徽章（外框）
    cyl(0.0075, 0.0018, (sx * 0.0182, 0.028, 0.028), Y90, 20, m=STEEL)
    for (yy, zz) in ((0.050, 0.020), (-0.012, 0.018)):
        cyl(0.0022, 0.0018, (sx * 0.0182, yy, zz), Y90, 8, m=DARK)      # 螺絲
box((0.004, 0.005, 0.022), (0, 0.004, 0.002), (0.25, 0, 0), m=DARK)  # 扳機
ring(0.021, 0.0030, (0, 0.006, -0.004), m=STEEL)                      # 圓護弓
box((0.006, 0.045, 0.003), (0, -0.046, 0.0035), (0.30, 0, 0), m=STEEL)  # 下護弓尾巴（貼著槍托腕部下緣）
box((0.010, 0.045, 0.003), (0, -0.050, 0.0470), (0.22, 0, 0), m=STEEL)  # 上尾板（機匣往後壓在槍托上）
# 英式直托：接機匣處跟機匣一樣高、腕部收細給手握、往後托身變寬變深、底部抵肩
loft([(-0.378, 0.027, -0.100, 0.021), (-0.300, 0.029, -0.085, 0.021),
      (-0.200, 0.032, -0.056, 0.019), (-0.120, 0.036, -0.022, 0.016),
      (-0.070, 0.041, -0.003, 0.0145), (-0.030, 0.050, 0.010, 0.0165)], m=WOODR)
loft([(-0.115, 0.0365, -0.020, 0.0163), (-0.070, 0.0415, -0.001, 0.0148)], m=WOOD2)   # 腕部防滑紋（深一圈）
loft([(-0.390, 0.027, -0.101, 0.0215), (-0.378, 0.027, -0.101, 0.0215)], m=DARK)    # 鋼底板
cyl(0.0025, 0.050, (0.021, -0.30, -0.03), Y90, 6, m=DARK)             # 背帶環
part('Shotgun')

cone(0.0120, 0.0152, 0.700, (0, 0.436, 0.046), X90, 20, m=BLUED)      # 槍管：後粗前細（cone 的 radius1 在前）
cyl(0.0172, 0.070, (0, 0.101, 0.046), X90, 20, m=BLUED)               # 膛室那一段加厚（從鉸鏈接到槍管）
cyl(0.0100, 0.722, (0, 0.427, 0.046), X90, 12, m=BORE)                # 膛口
sphere(0.0032, (0, 0.780, 0.0605), 8, 6, m=BRASS)                     # 準星珠
box((0.018, 0.045, 0.022), (0, 0.090, 0.026), m=BLUED)                # 閉鎖凸耳（掛在鉸鏈上）
# 長前護木：從鉸鏈前面一路到槍管三分之一，前端收圓（Romero 的護木很長）
loft([(0.100, 0.036, 0.012, 0.0160), (0.140, 0.036, 0.006, 0.0175),
      (0.340, 0.037, 0.012, 0.0150), (0.395, 0.038, 0.022, 0.0115)], m=WOODR)
cyl(0.0035, 0.034, (0, 0.200, 0.020), Y90, 8, m=DARK)                 # 護木固定螺絲
part('ShotgunBarrel', PIVOT['ShotgunBarrel'])

# 擊錘頂端要低於準星珠（SIGHT 0.061），不然舉槍時擋在瞄準線上
box((0.008, 0.012, 0.022), (0, -0.012, 0.045), (-0.35, 0, 0), m=STEEL)
box((0.012, 0.016, 0.004), (0, -0.022, 0.055), (-0.30, 0, 0), m=STEEL)  # 扳手
for k in range(3):
    box((0.012, 0.0015, 0.0012), (0, -0.027 + k * 0.004, 0.0575 - k * 0.0012), (-0.30, 0, 0), m=DARK)
part('ShotgunHammer', PIVOT['ShotgunHammer'])

# 霰彈：黃色紙殼＋黃銅底，原點在中間、沿 +Y（彈頭朝前）。換彈時右手拿著塞進膛室
cyl(0.0105, 0.050, (0, 0.008, 0), X90, 16, m=HULL)
cyl(0.0108, 0.016, (0, -0.025, 0), X90, 16, m=BRASS)
cyl(0.0116, 0.0016, (0, -0.0325, 0), X90, 16, m=BRASS)               # 底緣
cyl(0.0085, 0.001, (0, 0.0335, 0), X90, 16, m=HULL2)                 # 前端的摺口
part('ShotgunShell', PIVOT['ShotgunShell'])


# ================= 槓桿步槍（照 Hunt 的 Winfield 1873） =================
# 功能零件：烤藍鋼機匣（側板、螺絲、右側裝填門、頂上防塵蓋）、上下尾板、圓槍管（後粗前細）、
# 管狀彈匣＋前蓋、槍管箍、準星＋羊角照門、擊錘、拉桿環、扳機、護木＋前蓋、槍托＋月牙鋼底板
# 機匣：側面平、上緣平、下緣前面往上彎接護木，後面收進槍托
loft([(-0.036, 0.042, -0.002, 0.0160), (-0.028, 0.048, -0.008, 0.0170),
      (0.080, 0.048, -0.008, 0.0170), (0.092, 0.047, 0.000, 0.0165),
      (0.098, 0.044, 0.008, 0.0150)], m=BLUED, e=0.3)
for sx in (1, -1):
    box((0.0015, 0.070, 0.036), (sx * 0.0172, 0.040, 0.022), m=GUNMETAL)  # 側板（微微凸出一片）
    for (yy, zz) in ((0.014, 0.012), (0.066, 0.012), (0.040, 0.034)):
        cyl(0.0024, 0.0018, (sx * 0.0182, yy, zz), Y90, 8, m=DARK)      # 側板螺絲
box((0.003, 0.034, 0.014), (0.0185, 0.070, 0.010), m=DARK)            # 裝填門（右側前下方）
box((0.020, 0.060, 0.004), (0, 0.030, 0.050), m=GUNMETAL)             # 頂上防塵蓋
for k in range(4):
    box((0.018, 0.0015, 0.0012), (0, 0.004 + k * 0.004, 0.0525), m=DARK)   # 防塵蓋後端的止滑紋
box((0.012, 0.048, 0.003), (0, -0.058, 0.0370), (0.20, 0, 0), m=BLUED)  # 上尾板（壓在槍托腕部上）
box((0.010, 0.048, 0.003), (0, -0.058, -0.0135), (0.30, 0, 0), m=BLUED)  # 下尾板
cone(0.0105, 0.0125, 0.600, (0, 0.395, 0.034), X90, 20, m=BLUED)      # 圓槍管：後粗前細
cyl(0.0048, 0.602, (0, 0.396, 0.034), X90, 10, m=BORE)
cyl(0.0082, 0.540, (0, 0.365, 0.012), X90, 14, m=BLUED)               # 管狀彈匣
cyl(0.0090, 0.012, (0, 0.638, 0.012), X90, 14, m=GUNMETAL)            # 彈匣前蓋
box((0.026, 0.012, 0.042), (0, 0.620, 0.023), m=GUNMETAL)             # 槍管箍
box((0.003, 0.012, 0.010), (0, 0.688, 0.051), m=BLUED)                # 準星
box((0.022, 0.005, 0.010), (0, 0.205, 0.048), m=BLUED)                # 羊角照門（底座）
box((0.005, 0.005, 0.012), (0.0085, 0.205, 0.056), (0, 0.3, 0), m=BLUED)
box((0.005, 0.005, 0.012), (-0.0085, 0.205, 0.056), (0, -0.3, 0), m=BLUED)
loft([(0.098, 0.034, -0.004, 0.0160), (0.140, 0.034, -0.006, 0.0165),
      (0.300, 0.032, -0.003, 0.0150), (0.320, 0.030, 0.002, 0.0125)], m=WOOD)  # 護木（包住彈匣）
loft([(0.320, 0.031, 0.001, 0.0130), (0.330, 0.030, 0.004, 0.0120)], m=GUNMETAL)  # 護木前蓋
box((0.004, 0.005, 0.018), (0, 0.004, 0.000), (0.25, 0, 0), m=DARK)   # 扳機
# 槍托：腕部細、托身往後變深。拉桿環就在腕部下面，腕部要夠細手指才伸得進環
loft([(-0.372, 0.020, -0.100, 0.021), (-0.330, 0.021, -0.095, 0.021),
      (-0.220, 0.024, -0.074, 0.019), (-0.130, 0.028, -0.040, 0.016),
      (-0.080, 0.031, -0.020, 0.014), (-0.034, 0.040, -0.006, 0.016)], m=WOOD)
# 月牙底板：鋼的，上下兩個尖角勾住肩膀（1873 的招牌），中間凹進去
box((0.042, 0.008, 0.100), (0, -0.376, -0.040), m=GUNMETAL)
for zz, rr in ((0.018, 0.5), (-0.098, -0.5)):
    box((0.040, 0.020, 0.008), (0, -0.382, zz), (rr, 0, 0), m=GUNMETAL)
part('Rifle')

box((0.008, 0.100, 0.008), (0, 0.020, -0.012), m=BLUED)               # 拉桿前段（貼著機匣底，接到環）
ring(0.030, 0.0042, (0, -0.030, -0.040), m=BLUED)                     # 手指伸進去的環
cyl(0.0035, 0.012, (0, -0.012, -0.018), Y90, 8, m=DARK)               # 拉桿栓
part('RifleLever', PIVOT['RifleLever'])

# 擊錘頂端要低於照門（SIGHT 0.058），不然舉槍時擋在瞄準線上
box((0.008, 0.012, 0.022), (0, -0.032, 0.042), (-0.35, 0, 0), m=GUNMETAL)
box((0.012, 0.014, 0.004), (0, -0.040, 0.051), (-0.30, 0, 0), m=GUNMETAL)
for k in range(3):
    box((0.012, 0.0015, 0.0012), (0, -0.045 + k * 0.004, 0.0535 - k * 0.0012), (-0.30, 0, 0), m=DARK)
part('RifleHammer', PIVOT['RifleHammer'])

# 步槍子彈：黃銅彈殼＋鉛彈頭，原點在中間、沿 +Y。換彈時右手從右側裝填門壓進去
cyl(0.0059, 0.033, (0, -0.004, 0), X90, 12, m=BRASS)
cyl(0.0067, 0.0016, (0, -0.0205, 0), X90, 12, m=BRASS)
cyl(0.0054, 0.008, (0, 0.016, 0), X90, 12, m=LEAD)
sphere(0.0054, (0, 0.020, 0), 12, 6, m=LEAD)
part('RifleRound', PIVOT['RifleRound'])


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
