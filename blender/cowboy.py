# 牛仔：別人眼中的你（第一人稱看不到自己）、沙盒的靶。
#
# 座標用 Blender 的：X 右、Y 前（= Godot -Z）、Z 上。單位公尺，身高 1.8（跟碰撞膠囊一樣）。
# 兩個物件：
#   CowboyBody  原點在腳底，掛在 cowboy.tscn 的 Body 節點（蹲下時整個沿 Y 壓扁）
#   CowboyLegL/R 兩條腿，原點在髖關節（±0.10, 0.88），遊戲裡走路時前後擺
#   HandGrip / HandGripThumb / HandGripArm / HandSupport / HandLoad 第一人稱的手：見 hands.py
#   CowboyHead  原點在眼睛高度（1.6，= Head 節點的位置），掛在 Head/Face——
#               頭跟著上下看的角度轉，別人才看得出你在看哪裡
# EYE 跟 cowboy.tscn 的 Head 高度共用，改了要一起改。爆頭判定也是從 Head 往下算的。
#
# 重建：Blender 裡 BASE = '<這個資料夾>'; exec(open(BASE + '/cowboy.py').read()); export('<專案>/models')
import bpy, bmesh, math, os, sys
BASE = globals().get('BASE') or os.path.dirname(os.path.abspath(__file__))   # Blender 裡 exec 時自己給 BASE；背景跑時從檔案位置算
sys.path.insert(0, BASE)
import pipeline
exec(open(BASE + '/common.py').read())

EYE = 1.6
X90 = (math.pi / 2, 0, 0)

for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o)
wipe()
SKIN   = mat('c_skin',   (0.72, 0.52, 0.40), 0.7)
GLOVE  = mat('c_glove',  (0.075, 0.045, 0.028), 0.75)   # 深色皮手套（線性值；0.2 進遊戲是淺褐，被夕陽照成一片粉白）
HAT    = mat('c_hat',    (0.22, 0.16, 0.11), 0.8)
BAND   = mat('c_band',   (0.10, 0.08, 0.07), 0.6)
DUSTER = mat('c_duster', (0.11, 0.08, 0.05), 0.85)   # 深褐長風衣（第一人稱的袖子被夕陽照到的那面，淺色會比地面還亮、一片白）
VEST   = mat('c_vest',   (0.20, 0.17, 0.15), 0.8)
HAND   = mat('c_hand',   (0.22, 0.12, 0.06), 0.7)   # 第一人稱的裸手（線性值；影片受光的皮膚約 sRGB (0.70, 0.60, 0.57)）
SHIRT  = mat('c_shirt',  (0.70, 0.66, 0.58), 0.8)
DENIM  = mat('c_denim',  (0.20, 0.24, 0.32), 0.85)
LEATHER= mat('c_leather',(0.30, 0.18, 0.10), 0.6)
BOOT   = mat('c_boot',   (0.16, 0.10, 0.07), 0.55)
SCARF  = mat('c_scarf',  (0.55, 0.12, 0.10), 0.8)   # 領巾：遠遠看一眼就知道是牛仔
METAL  = mat('c_metal',  (0.55, 0.55, 0.55), 0.3, 0.9)
EYEC   = mat('c_eye',    (0.05, 0.04, 0.04), 0.3)


def vloft(stations, m=None, n=24, e=0.75):
    """直立的放樣：stations = [(z, 半寬, 半厚)] 由下往上，斷面是圓角的橢圓。外套用"""
    bm = bmesh.new()
    rings = []
    for (z, hw, hd) in stations:
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n
            c, s_ = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((hw * math.copysign(abs(c) ** e, c),
                                      hd * math.copysign(abs(s_) ** e, s_), z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('vloft')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('vloft', me)
    bpy.context.collection.objects.link(o)
    return _push(o, m)


def rbox(size, loc, rot=(0, 0, 0), m=None, taper_top=1.0):
    """box，可以讓上緣比下緣窄（taper_top<1）或寬（>1）：肩膀、風衣下擺都要"""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if taper_top != 1.0:
        for v in o.data.vertices:
            if v.co.z > 0:
                v.co.x *= taper_top
                v.co.y *= taper_top
    o.rotation_euler = rot
    o.location = loc
    return _push(o, m)


# ================= 身體（原點在腳底） =================
# 功能零件：靴子（鞋跟、鞋頭）、牛仔褲兩條腿、槍帶＋皮帶扣＋右腰槍套和左輪握把、
# 襯衫、背心、長風衣（肩、敞開的前襟、垂到膝蓋的下擺）、手臂、手
rbox((0.30, 0.18, 0.16), (0, 0.0, 0.90), m=DENIM)                        # 臀（包在風衣裡）
rbox((0.05, 0.02, 0.04), (0, 0.132, 0.95), m=METAL)                      # 皮帶扣
# 右腰槍套掛在風衣外面（風衣下擺往後撥開），握把往後翹，一眼看得出帶著槍
rbox((0.05, 0.08, 0.20), (0.235, 0.03, 0.84), (0, 0.10, 0), m=LEATHER)   # 槍套
rbox((0.03, 0.035, 0.07), (0.24, 0.01, 0.97), (0.35, 0.10, 0), m=HAT)    # 左輪握把
# 長風衣：從下擺到肩膀一層一層的斷面接成一件（下擺散開、腰收、胸寬、肩膀斜下來接脖子）。
# 平板拼的風衣看起來像衣櫃，外套的弧度要靠這個
vloft([(0.47, 0.225, 0.135), (0.62, 0.215, 0.130), (0.82, 0.200, 0.125),
       (1.00, 0.188, 0.118), (1.22, 0.205, 0.122), (1.38, 0.222, 0.118),
       (1.44, 0.170, 0.100), (1.47, 0.090, 0.075)], m=DUSTER)
# 前襟敞開那一條：露出背心、襯衫、皮帶扣。貼在風衣正面外一點點
rbox((0.13, 0.012, 0.44), (0, 0.120, 1.17), m=VEST)                      # 背心
rbox((0.05, 0.012, 0.36), (0, 0.126, 1.21), m=SHIRT)                     # 襯衫
for k in range(3):
    sphere(0.006, (0, 0.133, 1.30 - k * 0.08), 6, 4, m=METAL)            # 背心扣子
rbox((0.14, 0.012, 0.045), (0, 0.124, 0.95), m=LEATHER)                  # 前面露出的槍帶
for sx in (-1, 1):
    rbox((0.035, 0.02, 0.50), (sx * 0.075, 0.123, 1.16), (0, 0, -sx * 0.06), m=DUSTER)  # 前襟邊緣
    rbox((0.06, 0.02, 0.13), (sx * 0.085, 0.118, 1.37), (0, 0, sx * 0.45), m=DUSTER)     # 翻領
# 手臂：垂在身側，手肘微彎；風衣袖子包到手腕
for sx in (-1, 1):
    x = sx * 0.27
    sphere(0.066, (sx * 0.245, 0.0, 1.38), 14, 10, m=DUSTER)             # 肩頭：接住手臂，不然袖子像另外插上去的
    cyl(0.058, 0.32, (x, 0.0, 1.24), (0.05, sx * 0.08, 0), 12, m=DUSTER)  # 上臂
    cyl(0.052, 0.30, (x + sx * 0.01, 0.04, 0.95), (-0.25, 0, 0), 12, m=DUSTER)  # 前臂
    cyl(0.058, 0.04, (x + sx * 0.01, 0.075, 0.81), (-0.25, 0, 0), 12, m=DUSTER)  # 袖口
    sphere(0.045, (x + sx * 0.01, 0.09, 0.76), 12, 8, m=GLOVE)             # 手
cyl(0.055, 0.10, (0, 0.0, 1.50), (0, 0, 0), 12, m=SKIN)                   # 脖子
cyl(0.075, 0.06, (0, 0.005, 1.47), (0, 0, 0), 14, m=SCARF)                # 領巾（圍一圈）
cone(0.07, 0.01, 0.10, (0, 0.06, 1.42), (math.pi, 0, 0), 4, m=SCARF)      # 領巾前面垂下的三角
body = finish('CowboyBody', bevel=0.006, seg=1, smooth_mats=('c_skin', 'c_scarf', 'c_duster'))

# ================= 兩條腿（原點在髖關節，遊戲裡繞這裡前後擺） =================
HIP = 0.88
legs = {}
for sx, name in ((-1, 'CowboyLegL'), (1, 'CowboyLegR')):
    x = sx * 0.10
    rbox((0.11, 0.26, 0.09), (x, 0.03, 0.045), m=BOOT)                  # 鞋身
    rbox((0.10, 0.06, 0.05), (x, -0.08, 0.025), m=BOOT)                 # 鞋跟（馬靴高跟）
    cyl(0.062, 0.26, (x, 0.0, 0.20), (0, 0, 0), 14, m=BOOT)             # 靴筒
    cyl(0.068, HIP - 0.25, (x, 0.0, 0.25 + (HIP - 0.25) / 2), (0, 0, 0), 14, m=DENIM)   # 褲管
    sphere(0.07, (x, 0.0, HIP), 14, 8, m=DENIM)                         # 髖關節（擺動時上端不會露出斷面）
    legs[name] = finish(name, bevel=0.006, seg=1, smooth_mats=('c_denim',))
    # 第一人稱自己看的版本：只有靴子。整條腿從正上方看只看得到褲管頂端（兩個藍色圓盤），
    # 只留靴子，低頭看到的是靴筒和往前伸的鞋頭。原點一樣在髖關節，擺動一樣
    rbox((0.11, 0.26, 0.09), (x, 0.03, 0.045), m=BOOT)
    rbox((0.10, 0.06, 0.05), (x, -0.08, 0.025), m=BOOT)
    cyl(0.062, 0.26, (x, 0.0, 0.20), (0, 0, 0), 14, m=BOOT)
    legs[name.replace('Leg', 'Shin')] = finish(name.replace('Leg', 'Shin'), bevel=0.006, seg=1, smooth_mats=('c_denim',))

# ================= 第一人稱的手 =================
# HandGrip / HandGripThumb / HandGripArm / HandSupport / HandLoad 由 hands.py 建：
# 一整張連續的手套皮＋手指骨架，擺好握姿再烘成網格，原點已經放好
import hands
hands.build([HAND, SHIRT])   # 裸手、捲起的襯衫袖子（照 Hunt 影片）


# ================= 頭（原點在眼睛高度） =================
# 功能零件：頭、鼻子、眼睛、耳朵、八字鬍、帽子（帽頂中間壓凹、帽帶、往上捲的寬帽簷）
sphere(0.105, (0, 0.0, 1.62), 20, 14, m=SKIN)                             # 頭
sphere(0.07, (0, 0.04, 1.55), 16, 10, m=SKIN)                              # 下巴
for sx in (-1, 1):                                                         # 八字鬍：兩撇往下垂
    rbox((0.045, 0.018, 0.014), (sx * 0.024, 0.103, 1.572), (0, sx * 0.35, 0), m=BAND)
cone(0.018, 0.006, 0.04, (0, 0.11, 1.60), (-X90[0], 0, 0), 8, m=SKIN)     # 鼻子
for sx in (-1, 1):
    sphere(0.012, (sx * 0.038, 0.095, 1.625), 8, 6, m=EYEC)               # 眼睛
    sphere(0.022, (sx * 0.104, 0.0, 1.61), 8, 6, m=SKIN)                  # 耳朵
cyl(0.24, 0.014, (0, 0.0, 1.72), (0, 0, 0), 28, m=HAT)                    # 帽簷
for sx in (-1, 1):                                                         # 帽簷兩側往上捲
    rbox((0.06, 0.34, 0.012), (sx * 0.215, 0.0, 1.745), (0, sx * 0.55, 0), m=HAT)
cone(0.120, 0.100, 0.15, (0, 0.0, 1.80), (0, 0, 0), 24, m=HAT)            # 帽頂（上窄下寬）
rbox((0.025, 0.14, 0.02), (0, 0.0, 1.872), m=BAND)                         # 帽頂中間壓凹的那道縫
cyl(0.121, 0.03, (0, 0.0, 1.74), (0, 0, 0), 20, m=BAND)                   # 帽帶
head = finish('CowboyHead', bevel=0.004, seg=1, smooth_mats=('c_skin', 'c_hat'))
# join 完原點停在第一個零件上（身體是左腳靴子），遊戲只拿 mesh，原點不對整個人就歪掉。
# 旋轉先烘進網格，再把原點搬到該在的地方：身體在腳底中央、頭在眼睛
for o, anchor in ((body, (0, 0, 0)), (head, (0, 0, EYE)), (legs['CowboyLegL'], (-0.10, 0, HIP)),
                  (legs['CowboyLegR'], (0.10, 0, HIP)), (legs['CowboyShinL'], (-0.10, 0, HIP)),
                  (legs['CowboyShinR'], (0.10, 0, HIP))):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = anchor
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.select_all(action='DESELECT')


def export(out_dir):
    """一個 cowboy.glb。遊戲只拿 mesh 不拿節點位置，原點都已經搬到該轉的地方"""
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.select_set(True)
    path = os.path.join(out_dir, 'cowboy.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    print('exported ->', path)


if __name__ == '__main__':   # 背景跑：tools/model_iter.sh cowboy <版號>（輸出 --out 資料夾裡的 cowboy.glb）
    pipeline.run(lambda: [o for o in bpy.data.objects if o.type == 'MESH'], None,
                 budget=8000, export_fn=lambda obs, out: export(os.path.dirname(out) or '.'))
