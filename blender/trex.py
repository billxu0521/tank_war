import bpy, math
from mathutils import Vector
exec(open(BASE + '/common.py').read())

wipe()
BODY  = mat('t_body',  (0.34, 0.58, 0.27), 0.75)
BELLY = mat('t_belly', (0.56, 0.69, 0.40), 0.75)
DARK  = mat('t_dark',  (0.21, 0.36, 0.18), 0.75)
BONE  = mat('t_bone',  (0.90, 0.88, 0.78), 0.40)
EYE   = mat('t_eye',   (0.85, 0.55, 0.10), 0.20)
PUPIL = mat('t_pupil', (0.04, 0.03, 0.03), 0.20)

# trex.gd 的 _rig()：[骨頭, 父骨, 相對父骨位置(Godot), 方塊尺寸(Godot), 方塊中心(Godot)]
RIG = [
    ("root",    "",        (0, 2.3, 0),        (1.4, 1.3, 1.4), (0, 0, 0)),
    ("spine1",  "root",    (0, 0.05, -0.65),   (1.4, 1.3, 1.2), (0, 0.02, -0.3)),
    ("spine2",  "spine1",  (0, 0.10, -0.70),   (1.2, 1.1, 1.1), (0, 0.05, -0.3)),
    ("neck",    "spine2",  (0, 0.30, -0.55),   (0.8, 0.8, 0.9), (0, 0.05, -0.35)),
    ("head",    "neck",    (0, 0.15, -0.60),   (0.8, 0.7, 1.4), (0, 0.10, -0.55)),
    ("jaw",     "head",    (0, -0.20, -0.25),  (0.7, 0.28, 1.1),(0, -0.05, -0.5)),
    ("arm_l",   "spine2",  (0.42, -0.35, -0.30),  (0.22, 0.22, 0.65), (0, -0.12, -0.25)),
    ("arm_r",   "spine2",  (-0.42, -0.35, -0.30), (0.22, 0.22, 0.65), (0, -0.12, -0.25)),
    ("tail1",   "root",    (0, 0.05, 0.65),    (1.0, 1.0, 1.1), (0, 0, 0.35)),
    ("tail2",   "tail1",   (0, -0.05, 0.75),   (0.8, 0.8, 1.1), (0, 0, 0.35)),
    ("tail3",   "tail2",   (0, -0.05, 0.75),   (0.55, 0.55, 1.0),(0, 0, 0.35)),
    ("tail4",   "tail3",   (0, -0.05, 0.70),   (0.32, 0.32, 1.0),(0, 0, 0.35)),
    ("thigh_l", "root",    (0.52, -0.20, 0.10),   (0.7, 1.2, 0.95), (0, -0.45, 0)),
    ("shin_l",  "thigh_l", (0, -0.85, 0.08),   (0.42, 1.1, 0.5), (0, -0.45, 0)),
    ("foot_l",  "shin_l",  (0, -0.80, -0.10),  (0.5, 0.24, 1.1), (0, -0.06, -0.3)),
    ("thigh_r", "root",    (-0.52, -0.20, 0.10),  (0.7, 1.2, 0.95), (0, -0.45, 0)),
    ("shin_r",  "thigh_r", (0, -0.85, 0.08),   (0.42, 1.1, 0.5), (0, -0.45, 0)),
    ("foot_r",  "shin_r",  (0, -0.80, -0.10),  (0.5, 0.24, 1.1), (0, -0.06, -0.3)),
]

def B(g):            # Godot(x, y上, z後) -> Blender(x, y前, z上)
    return Vector((g[0], -g[2], g[1]))

def S(g):            # 尺寸 Godot(寬, 高, 長) -> Blender(寬, 長, 高)
    return (g[0], g[2], g[1])

_box_raw = box       # 這支檔案裡的尺寸一律用 Godot 順序寫，進 Blender 前自動轉
def box(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None):
    return _box_raw(S(size), loc, rot, m)

WORLD = {}
for name, parent, off, _s, _c in RIG:
    WORLD[name] = (WORLD[parent] if parent else Vector((0, 0, 0))) + B(off)

# ---- 有機外型小工具 ----
def blob(size, loc, m=None, shape=None, seg=14, ring=10):
    o = sphere(0.5, loc, seg, ring, m)   # 頂點是本地座標，別再減 loc
    for v in o.data.vertices:
        sz = S(size)
        c = Vector((v.co.x*sz[0], v.co.y*sz[1], v.co.z*sz[2]))
        v.co = shape(c) if shape else c
    return o

def seg(size, loc, m=None, front=1.0, back=1.0, v=18, n=3.0):
    """軀幹用的一節：中段飽滿、兩端收圓，接起來才不會一節一節像毛毛蟲。
    size 是 Godot 的(寬, 高, 長)"""
    o = sphere(0.5, loc, v, 12, m)
    for vt in o.data.vertices:
        x, y, z = vt.co
        u = max(-1.0, min(1.0, y / 0.5))
        r0 = math.sqrt(max(1e-6, 1.0 - u*u))            # 球原本的半徑
        r1 = (1.0 - abs(u)**n) ** (1.0/n)               # 改成比較飽滿的輪廓
        sc = r1 / r0
        k = back + (front - back) * ((u + 1.0) * 0.5)   # +Y 是前
        vt.co = Vector((x*sc*size[0]*k, y*size[2], z*sc*size[1]*k))
    return o

def taper_y(front=1.0, back=1.0, half=0.5):
    """沿 +Y（前）方向收縮"""
    def f(c):
        t = (c.y / half + 1) * 0.5          # 0 後 -> 1 前
        k = back + (front - back) * max(0.0, min(1.0, t))
        return Vector((c.x*k, c.y, c.z*k))
    return f

def spike(base, h, loc, rot=(0,0,0), m=None):
    return cone(base, base*0.12, h, loc, rot, 6, m)

def claw(size, loc, rot, m=BONE):
    c = cone(size, size*0.08, size*4.2, loc, rot, 6, m)
    return c

def tooth(r, h, loc, rot=(0,0,0)):
    return cone(r, r*0.1, h, loc, rot, 5, BONE)

# ---- 每根骨頭長什麼樣 ----
def build(name):
    W = WORLD[name]
    def P(gx, gy, gz):                       # 相對骨頭的 Godot 座標 -> Blender 世界
        return tuple(W + B((gx, gy, gz)))

    if name == "root":                       # 骨盆：撐住整隻的重量
        blob((1.30, 1.45, 1.25), P(0, 0, 0), BODY, taper_y(0.85, 1.0, 0.72))
        for sx in (-1, 1):                   # 髖臼（大腿插進去的地方）
            blob((0.42, 0.50, 0.46), P(sx*0.50, -0.14, 0.08), BODY)
        blob((0.22, 0.46, 0.90), P(0, 0.50, 0.0), DARK)         # 腸骨脊
        blob((1.05, 0.95, 0.55), P(0, -0.52, 0.05), BELLY)      # 肚子

    elif name == "spine1":                   # 胸廓：肋骨包住內臟
        seg((1.34, 1.24, 1.34), P(0, 0.02, -0.30), BODY, front=0.90, back=1.0)
        blob((1.00, 0.62, 0.92), P(0, -0.42, -0.30), BELLY)
        for z in (0.05, -0.25, -0.55):                          # 背脊突起
            cone(0.12, 0.02, 0.22, P(0, 0.62, z), (0, 0, 0), 4, m=DARK)

    elif name == "spine2":                   # 肩帶：前肢從這裡長出來
        seg((1.16, 1.08, 1.20), P(0, 0.05, -0.30), BODY, front=0.84, back=1.0)
        blob((0.86, 0.54, 0.80), P(0, -0.36, -0.28), BELLY)
        for sx in (-1, 1):                                      # 肩膀：前肢掛在這裡
            blob((0.34, 0.52, 0.46), P(sx*0.42, -0.18, -0.26), BODY)
            blob((0.26, 0.26, 0.26), P(sx*0.44, -0.36, -0.30), DARK)   # 肩關節窩
        for z in (0.0, -0.30, -0.58):                           # 背脊突起
            cone(0.11, 0.02, 0.20, P(0, 0.54, z), (0, 0, 0), 4, m=DARK)

    elif name == "neck":                     # 脖子：頸椎 + 撐頭的肌肉
        seg((0.88, 0.86, 1.16), P(0, 0.04, -0.35), BODY, front=0.86, back=1.04)
        blob((0.60, 0.40, 0.90), P(0, -0.26, -0.36), BELLY)     # 喉嚨下垂肉
        for z in (-0.08, -0.34, -0.60):                         # 頸椎骨節
            cone(0.09, 0.02, 0.16, P(0, 0.38, z), (0, 0, 0), 4, m=DARK)

    elif name == "head":                     # 頭骨：吻部、眉脊、眼、鼻孔、上排牙
        blob((0.78, 0.68, 0.62), P(0, 0.12, -0.26), BODY)           # 腦殼
        blob((0.74, 0.60, 0.52), P(0, 0.02, -0.42), BODY)           # 咬肌（咬合力靠這塊）
        blob((0.56, 0.50, 1.00), P(0, 0.04, -0.86), BODY, taper_y(0.52, 1.0, 0.50))  # 吻部
        blob((0.60, 0.26, 0.94), P(0, -0.12, -0.80), BELLY, taper_y(0.55, 1.0, 0.47))# 上顎肉
        blob((0.24, 0.14, 0.60), P(0, 0.18, -0.96), DARK)           # 鼻梁脊
        blob((0.34, 0.16, 0.44), P(0, 0.38, -0.30), DARK)           # 頭頂骨脊
        for sx in (-1, 1):
            blob((0.17, 0.16, 0.34), P(sx*0.26, 0.29, -0.54), DARK)           # 眉脊（暴龍的招牌）
            blob((0.14, 0.30, 0.30), P(sx*0.25, 0.19, -0.55), DARK)          # 眼窩
            sphere(0.115, tuple(W + B((sx*0.30, 0.19, -0.57))), 12, 8, EYE)  # 眼球
            sphere(0.062, tuple(W + B((sx*0.345, 0.19, -0.61))), 8, 6, PUPIL)
            blob((0.10, 0.09, 0.13), P(sx*0.12, 0.12, -1.14), DARK, seg=8, ring=6)  # 鼻孔
            blob((0.08, 0.14, 0.11), P(sx*0.30, 0.06, -0.20), DARK)          # 耳孔
            for i in range(7):                                               # 上排牙（往下咬）
                z = -0.50 - i*0.100
                big = 1 <= i <= 3
                tooth(0.042 if big else 0.030, 0.20 if big else 0.13,
                      P(sx*(0.26 - i*0.020), -0.20, z), (math.radians(180), 0, 0))

    elif name == "jaw":                      # 下顎：後端有關節才張得開
        blob((0.62, 0.38, 1.06), P(0, -0.04, -0.54), BODY, taper_y(0.55, 1.0, 0.52))
        blob((0.46, 0.18, 0.84), P(0, -0.10, -0.52), BELLY, taper_y(0.6, 1.0, 0.42))  # 喉部
        blob((0.28, 0.22, 0.22), P(0, -0.02, -1.00), BODY)          # 下巴
        for sx in (-1, 1):
            blob((0.20, 0.28, 0.34), P(sx*0.24, 0.06, -0.10), BODY)  # 下頜枝
            blob((0.17, 0.20, 0.18), P(sx*0.26, 0.12, 0.02), DARK)   # 頜關節
            for i in range(7):                                       # 下排牙（往上咬）
                z = -0.50 - i*0.100
                big = 1 <= i <= 3
                tooth(0.036 if big else 0.026, 0.16 if big else 0.11,
                      P(sx*(0.21 - i*0.016), 0.06, z), (0, 0, 0))

    elif name.startswith("arm"):             # 前肢：上臂、前臂、兩根指頭 + 爪
        s = 1 if name.endswith("_l") else -1
        blob((0.26, 0.26, 0.42), P(0, -0.08, -0.16), BODY)      # 上臂
        blob((0.20, 0.20, 0.34), P(0, -0.20, -0.40), BODY)      # 前臂
        blob((0.15, 0.14, 0.13), P(0, -0.26, -0.55), BODY)      # 腕
        for k, sx in enumerate((-0.055, 0.055)):                # 兩指（暴龍就兩指）
            blob((0.075, 0.075, 0.16), P(sx, -0.29, -0.65), DARK)
            claw(0.045, P(sx, -0.31, -0.78), (math.radians(-72), 0, 0))

    elif name.startswith("tail"):            # 尾巴：越後面越細，背上有棘、下面有人字骨
        i = int(name[-1])
        w = (1.02, 0.82, 0.58, 0.34)[i-1]
        h = (1.02, 0.82, 0.58, 0.34)[i-1]
        col = DARK if i == 4 else BODY
        seg((w, h, 1.24), P(0, 0, 0.35), col, front=1.02, back=0.80)
        n = 3 if i < 4 else 2
        for k in range(n):
            z = 0.05 + k*0.30
            cone(0.10*w, 0.02, 0.24*h, P(0, 0.44*h, z), (0, 0, 0), 4, m=DARK)          # 神經棘
            cone(0.09*w, 0.02, 0.18*h, P(0, -0.42*h, z), (math.radians(180), 0, 0), 4, m=DARK)  # 人字骨

    elif name.startswith("thigh"):           # 大腿：跑起來全靠這塊肌肉
        blob((0.76, 1.26, 1.02), P(0, -0.42, 0.02), BODY, taper_y(1.0, 1.0, 0.5))
        blob((0.60, 0.50, 0.74), P(0, -0.02, 0.06), BODY)       # 臀肌隆起
        blob((0.44, 0.36, 0.46), P(0, -0.80, 0.02), BODY)       # 膝關節
        box((0.30, 0.16, 0.20), P(0, -0.84, -0.20), m=DARK)     # 膝蓋骨

    elif name.startswith("shin"):            # 小腿：上粗下細
        blob((0.46, 1.14, 0.56), P(0, -0.44, 0), BODY, taper_y(1.0, 1.0, 0.55))
        blob((0.42, 0.40, 0.50), P(0, -0.14, 0.02), BODY)       # 腓腸肌
        blob((0.26, 0.24, 0.28), P(0, -0.82, -0.02), DARK)      # 踝關節
        cyl(0.055, 0.70, P(0, -0.42, 0.14), (math.radians(4), 0, 0), 8, m=DARK)   # 跟腱

    elif name.startswith("foot"):            # 腳：三根趾頭撐地 + 後爪
        blob((0.42, 0.22, 0.44), P(0, -0.04, -0.06), BODY)      # 蹠骨
        for k, sx in enumerate((-0.16, 0.0, 0.16)):             # 三趾，中趾最長
            L = 0.52 if k == 1 else 0.42
            blob((0.15, 0.15, L), P(sx, -0.08, -0.30 - (0.04 if k == 1 else 0)), BODY)
            blob((0.13, 0.13, 0.14), P(sx*1.15, -0.09, -0.52 - (0.06 if k == 1 else 0)), DARK)
            claw(0.055, P(sx*1.2, -0.10, -0.66 - (0.06 if k == 1 else 0)),
                 (math.radians(-100), 0, math.radians(-10*sx/0.16 if sx else 0)))
        blob((0.11, 0.11, 0.22), P(-0.0, -0.06, 0.14), BODY)    # 後趾
        claw(0.04, P(0, -0.08, 0.26), (math.radians(-250), 0, 0))
        for sx in (-0.16, 0.0, 0.16):                           # 腳掌肉墊
            blob((0.17, 0.09, 0.17), P(sx, -0.15, -0.22), BELLY)

for name, _p, _o, _s, _c in RIG:
    build(name)
    o = finish(name, bevel=0.008, seg=1)
    bpy.context.scene.cursor.location = WORLD[name]
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.context.scene.cursor.location = (0, 0, 0)
print('trex ok:', len(bpy.data.objects), 'parts')
