# 鄉村場景物件：穀倉、筒倉、柵欄、乾草捲、兩種樹、灌木叢、麥子、草叢、蛋、篷車。
#
# 座標用 Blender 的：X 右、Y 前（= Godot -Z）、Z 上。單位公尺。
# 每個物件都以「自己的原點」為準建在世界原點（匯出後 main.gd 直接拿 mesh 擺）：
#   Barn        牆身，原點在地面中央。基準尺寸 14 寬 × 20 長 × 8 高（牆），遊戲裡照實際大小縮放
#   BarnRoof    屋頂＋山牆三角，原點在牆頂中央。遊戲裡 X、高度用同一個倍率縮，斜度才不會變
#   SiloBody    筒倉筒身，原點在地面中央，基準高 15（遊戲裡只縮高度）
#   SiloDome    圓頂，原點在筒身頂
#   HayBale     圓捆乾草，軸是直的（遊戲裡跟碰撞圓柱一起放倒），原點在中心
#   TreePine          原點在樹根，基準樹幹高 5（闊葉樹在 tree.py）
#   Bush        灌木叢，原點在地面中央，約 2.2 寬 1.5 高（沒有碰撞，只擋視線）
#
# 跟 main.gd 共用的數字（改一邊要改另一邊）：
#   BARN / BARN_PITCH = main.gd _barn() 的基準大小和 _roof() 的 0.55
#   BARN_DOOR_*、BARN_BACK_X、BARN_LOFT、BARN_LADDER_X = main.gd 擺門和梯子的位置
#   BarnCol 是碰撞形狀（遊戲裡看不見），牆和開口在這裡定義一次就好
#   農舍在 house.py（另外輸出成 houses.glb）
#
# 重建：Blender 裡 BASE = '<這個資料夾>'; exec(open(BASE + '/props.py').read()); export('<專案>/models')
import bpy, bmesh, math, os, sys
BASE = globals().get('BASE') or os.path.dirname(os.path.abspath(__file__))   # Blender 裡 exec 時自己給 BASE；背景跑時從檔案位置算
sys.path.insert(0, BASE)
import pipeline
exec(open(BASE + '/common.py').read())

BARN = (14.0, 20.0, 8.0)       # 寬（X）、長（Y）、牆高（Z）
BARN_PITCH = 0.55
BARN_T = 0.25                  # 牆厚
BARN_DOOR_W, BARN_DOOR_H = 5.0, 4.8   # 大門開口（兩扇滑門各一半寬）
BARN_BACK_X = 4.0              # 後門中心的 X
# 後門開口。穀倉會照實際大小縮放（最小 0.86 倍寬、0.875 倍高），這個大小縮完還是站著過得去；
# 小棚子（0.57 倍、0.5 倍）縮完約 0.9 × 1.4，蹲著鑽得過
BARN_BACK_W, BARN_BACK_H = 1.6, 2.8
BARN_LOFT = 4.0                # 閣樓地板頂面高度（後半部，邊緣在 y=0）
BARN_LADDER_X = -2.5           # 梯子的 X（靠在閣樓邊緣）
SILO_R, SILO_H = 3.0, 15.0
TRUNK = 5.0

for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o)
wipe()
RED    = mat('p_red',    (0.288, 0.192, 0.128), 0.85)   # 穀倉牆板：風化的褐色木頭（名字留著，遊戲的材質表認這個名字）
RED_D  = mat('p_red_d',  (0.208, 0.136, 0.088), 0.85)
TRIM   = mat('p_trim',   (0.368, 0.272, 0.176), 0.8)
ROOF   = mat('p_roof',   (0.156, 0.093, 0.058), 0.9)   # 鐵皮屋頂（不要金屬：金屬會反射天空變成紫灰）
STONE  = mat('p_stone',  (0.254, 0.162, 0.098), 0.95)
WOOD   = mat('p_wood',   (0.384, 0.288, 0.192), 0.9)
WOOD_D = mat('p_wood_d', (0.224, 0.160, 0.112), 0.9)
GLASS  = mat('p_glass',  (0.060, 0.050, 0.045), 1.0)
SHUT   = mat('p_shut',   (0.24, 0.17, 0.11), 0.8)        # 百葉窗
SILO   = mat('p_silo',   (0.282, 0.188, 0.106), 0.9)
BAND   = mat('p_band',   (0.200, 0.180, 0.160), 0.9)
HAY    = mat('p_hay',    (0.434, 0.254, 0.065), 1.0)   # 金黃乾草
HAY_D  = mat('p_hay_d',  (0.254, 0.145, 0.034), 1.0)
BARK   = mat('p_bark',   (0.18, 0.12, 0.08), 1.0)
LEAF1  = mat('p_leaf1',  (0.055, 0.068, 0.018), 0.9)   # 跟樹冠（tree.py 的 tree_leaf）同色
LEAF2  = mat('p_leaf2',  (0.066, 0.078, 0.020), 0.9)
PINE   = mat('p_pine',   (0.055, 0.075, 0.030), 0.9)   # 跟闊葉樹同一片林子的暗綠


def prism(w, rise, depth, loc, m=None):
    """山牆的三角形：底 w、高 rise、厚 depth（沿 Y），底邊中點在 loc"""
    bm = bmesh.new()
    pts = [(-w / 2, 0), (w / 2, 0), (0, rise)]
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('prism')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('prism', me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return _push(o, m)


def gable_roof(w, length, pitch, m_panel, rib=None, overhang=0.5, thick=0.3):
    """人字屋頂兩片斜板，擺法跟 main.gd 的 _roof() 一模一樣（碰撞就是照那個算的）。
    原點在牆頂中央。rib 給材質就在鐵皮上加一條條浪板的稜"""
    run = w / 2
    rise = run * math.tan(pitch)
    pw = run / math.cos(pitch) + overhang
    for sx in (-1, 1):
        cx, cz = sx * run / 2, rise / 2
        box((pw, length + 1.0, thick), (cx, 0, cz), (0, sx * pitch, 0), m=m_panel)
        if rib:
            # 浪板的稜：沿著斜面往下，一公尺一條
            nx, nz = sx * math.sin(pitch), math.cos(pitch)      # 斜板往外（往上）的法線
            for k in range(int(length) + 1):
                y = -length / 2 + k
                box((pw, 0.07, 0.07), (cx + nx * (thick / 2 + 0.03), y, cz + nz * (thick / 2 + 0.03)),
                    (0, sx * pitch, 0), m=rib)
    return rise


def window(x, y, z, face, w=1.1, h=1.3, shutters=False, glass=False):
    """窗框：白色窗框、十字窗櫺。face = +1/-1 是朝 ±Y 的牆，'x+' / 'x-' 是朝 ±X。
    glass=False（預設）是開口：可以從窗戶開槍、翻進翻出——Hunt 的房子就是這樣打的"""
    def at(dx, dz, size, m, out=0.0):
        if face in (1, -1):
            box(size, (x + dx, y + face * out, z + dz), m=m)
        else:
            s = 1 if face == 'x+' else -1
            box((size[1], size[0], size[2]), (x + s * out, y + dx, z + dz), m=m)
    if glass:
        at(0, 0, (w, 0.10, h), GLASS, 0.02)
    at(0, h / 2 + 0.06, (w + 0.24, 0.14, 0.12), TRIM, 0.04)
    at(0, -h / 2 - 0.06, (w + 0.30, 0.18, 0.12), TRIM, 0.05)
    for sx in (-1, 1):
        at(sx * (w / 2 + 0.05), 0, (0.10, 0.14, h), TRIM, 0.04)
    if shutters:
        for sx in (-1, 1):
            at(sx * (w / 2 + 0.38), 0, (0.52, 0.08, h + 0.1), SHUT, 0.04)


def lantern(loc, hang=0.0):
    """提燈：鐵框＋會發光的玻璃罩。hang > 0 就從上面垂一條繩子"""
    cyl(0.09, 0.22, loc, (0, 0, 0), 8, m=LAMP)
    for k in (-1, 1):
        box((0.2, 0.02, 0.02), (loc[0], loc[1], loc[2] + k * 0.12), m=BAND)
    cone(0.10, 0.03, 0.08, (loc[0], loc[1], loc[2] + 0.16), (0, 0, 0), 8, m=BAND)
    if hang > 0:
        box((0.015, 0.015, hang), (loc[0], loc[1], loc[2] + 0.2 + hang / 2), m=BAND)


LAMP = mat('p_lamp', (1.0, 0.78, 0.40), 0.3)
_bsdf = next(n for n in LAMP.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
_bsdf.inputs['Emission Color'].default_value = (1.0, 0.70, 0.30, 1.0)
_bsdf.inputs['Emission Strength'].default_value = 4.0
IRON = mat('p_iron', (0.060, 0.055, 0.050), 0.9)
PLANK = mat('p_plank', (0.320, 0.232, 0.152), 0.9)


# ================= 穀倉（空心：大門、後門、側窗都是開口，裡面有閣樓和梯子） =================
# 功能零件：石頭牆基、直條護牆板（開口處斷開）、白色轉角包邊、大門門框和滑軌（門板是另外的物件）、
# 側窗、閣樓（地板、邊緣大樑、撐住它的柱子）、梯子、馬廄隔間和飼料槽、乾草、木桶、
# 工作台和工具、掛在牆上的車輪、吊在閣樓下的提燈
W, L, H = BARN
T = BARN_T
FRONT = [(0.0, BARN_DOOR_W, 0.0, BARN_DOOR_H)]                  # 大門
BACK = [(BARN_BACK_X, BARN_BACK_W, 0.0, BARN_BACK_H)]                          # 後門
SIDE = [(y, 1.1, 4.75, 6.05) for y in (-6.0, 0.0, 6.0)]          # 側窗（閣樓高度，趴在閣樓往外打）
wall('x', -L / 2 + T / 2, -W / 2, W / 2, H, T, FRONT, RED)
wall('x', L / 2 - T / 2, -W / 2, W / 2, H, T, BACK, RED)
for sx in (-1, 1):
    wall('y', sx * (W / 2 - T / 2), -L / 2 + T, L / 2 - T, H, T, SIDE, RED)
for sx in (-1, 1):                                                             # 石頭牆基（只沿著牆）
    box((0.45, L + 0.3, 0.5), (sx * W / 2, 0, 0.25), m=STONE)
for sy in (-1, 1):
    for x0, x1 in ((-W / 2, -BARN_DOOR_W / 2), (BARN_DOOR_W / 2, W / 2)) if sy < 0 else ((-W / 2, W / 2),):
        box((x1 - x0, 0.45, 0.5), ((x0 + x1) / 2, sy * L / 2, 0.25), m=STONE)
box((W - 2 * T, L - 2 * T, 0.04), (0, 0, 0.02), m=PLANK)                        # 地板
PLANK_STEP = 3.5   # 直條板間距：一面牆 4~6 條寬板（一公尺一條太密，跟樹和石頭的大稜面不是同一套）
for sx in (-1, 1):                                                             # 側牆直條板（窗那段斷開）
    for k in range(int(L / PLANK_STEP)):
        y = -L / 2 + PLANK_STEP / 2 + k * PLANK_STEP
        o = clear_of(y, SIDE)
        segs = [(0.6, H)] if not o else [(0.6, o[2] - 0.1), (o[3] + 0.1, H)]
        for z0, z1 in segs:
            box((0.06, 0.25, z1 - z0), (sx * (W / 2 + 0.03), y, (z0 + z1) / 2), m=RED_D)
for sy, ops in ((-1, FRONT), (1, BACK)):                                       # 前後牆直條板（門那段斷開）
    for k in range(int(W / PLANK_STEP)):
        x = -W / 2 + PLANK_STEP / 2 + k * PLANK_STEP
        o = clear_of(x, ops)
        segs = [(0.6, H)] if not o else [(o[3] + 0.1, H)]
        for z0, z1 in segs:
            box((0.25, 0.06, z1 - z0), (x, sy * (L / 2 + 0.03), (z0 + z1) / 2), m=RED_D)
for sx in (-1, 1):                                                             # 轉角白包邊
    for sy in (-1, 1):
        box((0.28, 0.28, H), (sx * W / 2, sy * L / 2, H / 2), m=TRIM)
box((W + 0.1, 0.2, 0.25), (0, -L / 2 - 0.08, H - 0.12), m=TRIM)                # 前牆頂的橫帶
for sx in (-1, 1):                                                             # 大門門框
    box((0.25, 0.2, BARN_DOOR_H), (sx * (BARN_DOOR_W / 2 + 0.12), -L / 2 - 0.02, BARN_DOOR_H / 2), m=TRIM)
box((BARN_DOOR_W + 0.5, 0.2, 0.25), (0, -L / 2 - 0.02, BARN_DOOR_H + 0.12), m=TRIM)
box((BARN_DOOR_W * 2 + 0.6, 0.12, 0.18), (0, -L / 2 - 0.26, BARN_DOOR_H + 0.25), m=BAND)   # 滑門軌道（門往兩邊拉）
for sx in (-1, 1):                                                             # 後門門框
    box((0.12, 0.16, BARN_BACK_H + 0.1), (BARN_BACK_X + sx * (BARN_BACK_W / 2 + 0.06), L / 2 + 0.02, (BARN_BACK_H + 0.1) / 2), m=TRIM)
box((BARN_BACK_W + 0.24, 0.16, 0.12), (BARN_BACK_X, L / 2 + 0.02, BARN_BACK_H + 0.06), m=TRIM)
for sx in (-1, 1):
    for y, _w, b, top in SIDE:
        window(sx * (W / 2 + 0.02), y, (b + top) / 2, 'x+' if sx > 0 else 'x-', h=top - b)
# 閣樓：後半部（Blender +Y）。地板頂面在 BARN_LOFT，邊緣在 y=0
LOFT = BARN_LOFT
solid((W - 2 * T, L / 2 - T, 0.2), (0, (L / 2 - T) / 2, LOFT - 0.1), m=PLANK)
for k in range(int(W - 2 * T) * 2):                                           # 閣樓木板的縫
    box((0.02, L / 2 - T, 0.01), (-W / 2 + T + 0.25 + k * 0.5, (L / 2 - T) / 2, LOFT + 0.005), m=WOOD_D)
box((W - 2 * T, 0.25, 0.35), (0, 0.12, LOFT - 0.37), m=WOOD_D)                 # 邊緣大樑
for x in (-5.0, 0.0, 5.0):                                                     # 撐閣樓的柱子
    solid((0.25, 0.25, LOFT - 0.2), (x, 0.2, (LOFT - 0.2) / 2), m=WOOD_D)
    box((0.9, 0.15, 0.15), (x, 0.2, LOFT - 0.6), (0, 0.6, 0), m=WOOD_D)         # 斜撐
# 梯子：靠在閣樓邊緣（遊戲裡 F 可以爬），一直伸到地板上面一公尺，爬到頂才抓得到東西
for sx in (-1, 1):
    box((0.07, 0.07, LOFT + 1.0), (BARN_LADDER_X + sx * 0.25, -0.15, (LOFT + 1.0) / 2), m=WOOD)
for k in range(int((LOFT + 0.9) / 0.3)):
    box((0.5, 0.05, 0.05), (BARN_LADDER_X, -0.15, 0.3 + k * 0.3), m=WOOD)
# 馬廄：右側前半，三格隔間（1.3 公尺高，蹲下躲得進去）＋飼料槽
for y in (-7.5, -4.5, -1.5):
    solid((3.0, 0.1, 1.3), (W / 2 - T - 1.5, y, 0.65), m=WOOD)
    box((0.12, 0.12, 1.5), (W / 2 - T - 3.0, y, 0.75), m=WOOD_D)                 # 隔間柱
    box((0.5, 1.6, 0.35), (W / 2 - T - 0.35, y - 1.5, 0.55), m=WOOD_D)           # 飼料槽
    sphere(0.55, (W / 2 - T - 1.2, y - 1.4, 0.0), 10, 6, m=HAY_D)                # 地上的草
# 閣樓上的方草捆（疊起來可以當掩體）
for i, (x, y, z) in enumerate(((-5, 8.5, 0), (-3.9, 8.5, 0), (-5, 8.5, 1), (-4.4, 7.4, 0),
                               (4.8, 8.5, 0), (3.7, 8.5, 0), (4.8, 8.5, 1), (2.0, 8.8, 0))):
    solid((1.0, 0.5, 0.45) if i % 2 else (1.0, 0.5, 0.45), (x, y, LOFT + 0.225 + z * 0.45), m=HAY)
sphere(1.6, (-4.5, -6.0, 0.0), 14, 8, m=HAY)                                    # 一樓的乾草堆
for v in _parts[-1].data.vertices:
    v.co.z *= 0.45
# 木桶、工作台、工具、牆上的車輪
for (x, y) in ((-6.0, -8.8), (-5.3, -9.0), (-6.1, -8.0)):
    cyl(0.3, 0.9, (x, y, 0.45), (0, 0, 0), 12, m=WOOD)
    for z in (0.15, 0.75):
        cyl(0.31, 0.05, (x, y, z), (0, 0, 0), 12, m=BAND)
    COL.append(((0.6, 0.6, 0.9), (x, y, 0.45), (0, 0, 0)))
solid((0.8, 2.2, 0.9), (-W / 2 + T + 0.4, -3.5, 0.45), m=WOOD)                 # 工作台
for k, (dy, sz) in enumerate(((-0.6, 0.35), (0.1, 0.5), (0.7, 0.3))):
    box((0.08, 0.04, sz), (-W / 2 + T + 0.05, -3.5 + dy, 1.4 + sz / 2), m=BAND)  # 掛在牆上的工具
bpy.ops.mesh.primitive_torus_add(major_radius=0.6, minor_radius=0.05, major_segments=20, minor_segments=4,
                                 location=(-W / 2 + T + 0.06, 3.0 - 6.0, 2.2), rotation=(0, math.pi / 2, 0))
_push(bpy.context.object, WOOD_D)
for sx in (-1, 1):                                                             # 內牆的橫樑：牆板釘在這上面
    for z in (2.0, 6.6):
        box((0.12, L - 2 * T, 0.18), (sx * (W / 2 - T - 0.06), 0, z), m=WOOD_D)
for sy in (-1, 1):
    for z in (6.6,):
        box((W - 2 * T, 0.12, 0.18), (0, sy * (L / 2 - T - 0.06), z), m=WOOD_D)
lantern((0.0, -0.3, LOFT - 1.0), hang=0.4)                                       # 閣樓下的提燈
lantern((-W / 2 + T + 0.4, -3.5, 1.05))                                          # 工作台上的提燈
barn = finish('Barn', bevel=0.0, seg=1)
barn_col = make_col('BarnCol')

# 門（各自一個物件，遊戲裡會動）：原點在門的轉軸或底部中央
box((BARN_DOOR_W / 2, 0.16, BARN_DOOR_H), (0, 0, BARN_DOOR_H / 2), m=RED_D)    # 滑門：兩扇一樣，遊戲裡放兩片
diag = math.atan2(BARN_DOOR_H - 0.4, BARN_DOOR_W / 2 - 0.2)
for d in (-1, 1):
    box((math.hypot(BARN_DOOR_H - 0.4, BARN_DOOR_W / 2 - 0.2), 0.08, 0.22), (0, -0.1, BARN_DOOR_H / 2), (0, d * diag, 0), m=TRIM)
for z in (0.12, BARN_DOOR_H - 0.12):
    box((BARN_DOOR_W / 2, 0.08, 0.22), (0, -0.1, z), m=TRIM)
for sx in (-1, 1):
    box((0.22, 0.08, BARN_DOOR_H), (sx * (BARN_DOOR_W / 4 - 0.11), -0.1, BARN_DOOR_H / 2), m=TRIM)
cyl(0.08, 0.1, (0, 0, BARN_DOOR_H + 0.2), (math.pi / 2, 0, 0), 10, m=BAND)      # 吊輪
slide = finish('BarnDoorSlide', bevel=0.0, seg=1)
BW, BH = BARN_BACK_W, BARN_BACK_H
box((BW, 0.08, BH), (BW / 2, 0, BH / 2), m=RED_D)                                # 後門：原點在門軸
for z in (0.4, BH - 0.4):
    box((BW - 0.1, 0.1, 0.12), (BW / 2, 0, z), m=TRIM)
box((math.hypot(BW - 0.1, BH - 0.8), 0.1, 0.1), (BW / 2, 0, BH / 2), (0, math.atan2(BH - 0.8, BW - 0.1), 0), m=TRIM)
sphere(0.04, (BW - 0.15, -0.07, BH / 2), 8, 6, m=BAND)
back_door = finish('BarnBackDoor', bevel=0.0, seg=1)

rise = gable_roof(W, L, BARN_PITCH, ROOF, rib=BAND)
for sy in (-1, 1):                                                             # 山牆三角
    prism(W, rise, 0.25, (0, sy * (L / 2 - 0.12), 0), m=RED)
    for k in range(1, int(W)):                                                 # 山牆直條板
        x = -W / 2 + k
        hh = rise * (1 - abs(x) / (W / 2))
        if hh > 0.3:
            box((0.12, 0.06, hh - 0.1), (x, sy * (L / 2 + 0.03), (hh - 0.1) / 2), m=RED_D)
box((0.5, L + 1.2, 0.35), (0, 0, rise + 0.05), m=ROOF)                          # 屋脊蓋
# 閣樓門和吊草料的橫樑（草料從這裡吊上閣樓）
box((2.2, 0.14, 2.0), (0, -L / 2 - 0.08, rise * 0.30 + 0.2), m=RED_D)
for d in (-1, 1):
    box((2.8, 0.06, 0.16), (0, -L / 2 - 0.17, rise * 0.30 + 0.2), (0, d * math.atan2(1.8, 2.0), 0), m=TRIM)
box((0.3, 1.8, 0.3), (0, -L / 2 - 0.6, rise * 0.72), m=WOOD_D)
cyl(0.12, 0.2, (0, -L / 2 - 1.4, rise * 0.72 - 0.25), (0, math.pi / 2, 0), 12, m=BAND)   # 滑輪
# 屋脊中間的通風塔
box((1.6, 1.6, 1.5), (0, 0, rise + 0.75), m=RED)
for sx in (-1, 1):
    for k in range(4):
        box((0.06, 1.3, 0.08), (sx * 0.82, 0, rise + 0.35 + k * 0.28), (0.0, 0.4 * sx, 0), m=WOOD_D)  # 百葉
gable_roof(2.2, 2.0, 0.6, ROOF, overhang=0.2, thick=0.15)
for o in _parts[-2:]:
    o.location.z += rise + 1.5
roof = finish('BarnRoof', bevel=0.0, seg=1)

# ================= 筒倉 =================
# 功能零件：水泥底座、筒身、一圈圈的鐵箍、側面的爬梯（兩根扶手＋橫檔）、圓頂＋頂上的通風帽
cyl(SILO_R + 0.25, 0.6, (0, 0, 0.3), (0, 0, 0), 12, m=STONE)   # 12 邊平面著色，跟樹和石頭同一套稜面感
cyl(SILO_R, SILO_H, (0, 0, SILO_H / 2), (0, 0, 0), 12, m=SILO)
for k in range(1, 5):                                                          # 環箍只留 4 道（很多條細線太碎）
    cyl(SILO_R + 0.04, 0.2, (0, 0, k * SILO_H / 5), (0, 0, 0), 12, m=BAND)
for sy in (-1, 1):                                                             # 爬梯
    box((0.08, 0.08, SILO_H - 1.0), (SILO_R + 0.25, sy * 0.25, SILO_H / 2 + 0.5), m=BAND)
for k in range(int((SILO_H - 1.0) / 0.4)):
    box((0.05, 0.5, 0.05), (SILO_R + 0.25, 0, 1.2 + k * 0.4), m=BAND)
for k in range(int(SILO_H / 1.5)):                                             # 爬梯固定架
    box((0.3, 0.06, 0.06), (SILO_R + 0.12, 0, 1.5 + k * 1.5), m=BAND)
silo = finish('SiloBody', bevel=0.0, seg=1)

sphere(SILO_R + 0.1, (0, 0, 0), 32, 12, m=SILO)
for v in _parts[-1].data.vertices:                                             # 壓成扁圓頂、只留上半
    v.co.z = max(v.co.z, 0.0) * (1.6 / (SILO_R + 0.1))
cyl(0.35, 0.5, (0, 0, 1.75), (0, 0, 0), 12, m=BAND)                            # 通風帽
cone(0.55, 0.05, 0.35, (0, 0, 2.15), (0, 0, 0), 12, m=SILO)
dome = finish('SiloDome', bevel=0.0, seg=1)

# 柵欄在 kit.py（跟 house.png 同一套：方木樁＋三條橫板）

# ================= 乾草捲 =================
# 功能零件：捲起來的草（兩個端面一圈圈的年輪）、綁草的麻繩、端面邊緣收圓
cyl(0.70, 1.20, (0, 0, 0), (0, 0, 0), 12, m=HAY)                           # 12 邊平面著色（平滑的圓柱是舊風格）
for sz in (-1, 1):
    cyl(0.62, 0.06, (0, 0, sz * 0.62), (0, 0, 0), 12, m=HAY)                   # 端面收一圈
    cyl(0.40, 0.04, (0, 0, sz * 0.66), (0, 0, 0), 12, m=HAY_D)                 # 捲痕：兩圈大的內縮面，不刻細線
    cyl(0.18, 0.04, (0, 0, sz * 0.69), (0, 0, 0), 12, m=HAY)
bale = finish('HayBale', bevel=0.0, seg=1)

# ================= 樹 =================
# 闊葉樹在 tree.py（另外輸出成 trees.glb）

# 松樹：直的樹幹，四層往上縮的錐形樹冠
cyl(0.30, TRUNK + 2.0, (0, 0, (TRUNK + 2.0) / 2), (0, 0, 0), 8, m=BARK)
for k in range(4):
    r = 2.6 - k * 0.55
    cone(r, 0.05, 2.8, (0, 0, 3.2 + k * 1.5), (0, 0, k * 0.4), 10, m=PINE)
pine = finish('TreePine', bevel=0.0, seg=1)

# 灌木叢：十九團葉子疊成一叢，約 2.2 寬、1.5 高——站著露出頭、蹲下整個藏住。
# 沒有碰撞（跟 Hunt 一樣只擋視線、不擋子彈，人也走得進去）。
# 葉子用樹的做法（tree.py 的 core／on_core）：每團一顆暗色的芯，表面撒葉片卡（透明底的一簇葉子圖，往外翻開），
# 輪廓是一片片葉子的鋸齒。以前是一團團純色的球（使用者 2026-10-09：一個色塊，改成跟樹葉一樣）
import random
from tree import core as _core, on_core as _on_core, card_material as _card_material, apply_card_normals as _card_normals
BUSH_DARK = mat('p_bush', (0.13, 0.15, 0.03), 0.9)   # 芯：接近葉子的中間色（樹的芯也是）；太暗的話卡片之間看進去是一顆顆黑石頭
BUSH_CARD = _card_material('p_bush_leafcard', 'leaf_oak.png')   # 名字有 leafcard：main.gd 換成會隨風擺的葉子材質
_br = random.Random(11)
_lumps = [(0, 0, 0.75, 0.80, 0.85), (0.65, 0.25, 0.55, 0.62, 0.8), (-0.60, 0.30, 0.58, 0.65, 0.8), (0.15, -0.60, 0.52, 0.60, 0.8),
          (-0.25, 0.65, 0.50, 0.55, 0.8), (0.55, -0.35, 0.95, 0.48, 0.9), (-0.45, -0.40, 0.90, 0.50, 0.9), (0.10, 0.20, 1.15, 0.50, 0.85),
          (0.85, 0.55, 0.35, 0.42, 0.75)]
for k in range(10):                                   # 外圍再補十團小的，輪廓才毛毛的
    a = k * math.tau / 10 + _br.uniform(-0.2, 0.2)
    rr = _br.uniform(0.75, 1.05)
    _lumps.append((rr * math.cos(a), rr * math.sin(a), _br.uniform(0.35, 1.0), _br.uniform(0.28, 0.40), 1.0))
_bm = bmesh.new()
# 底下一圈貼地的團（裙邊）：葉子只撒在上面的話，下三分之一透得過去，蹲著藏不住人，看起來也像浮在草上（審查）
for k in range(8):
    a = k * math.tau / 8 + _br.uniform(-0.2, 0.2)
    rr = _br.uniform(0.55, 0.85)
    _lumps.append((rr * math.cos(a), rr * math.sin(a), 0.25, _br.uniform(0.38, 0.48), 0.8))
for (x, y, z, r, sz) in _lumps:
    c = Vector((x, y, z))
    _core(_bm, c, r * 0.5, 0, sq=(1, 1, sz), subdiv=1)
    _on_core(_bm, c, r * 0.8, max(10, int(34 * r)), r * 0.95, 1, _br, sq=(1, 1, sz), spread=0.2, push=0.0, cross=False, fan=35, bottom=0.6,
             top=0.6 if z > 0.45 else 0.35)   # 低的團多撒在下半球，底下才密   # 卡片太大、翻太開整叢會長到 2.5 公尺高，蹲下藏不住
# 整叢縮到約 2.6 寬、1.6 高（跟以前一樣：站著露出頭、蹲下藏住），葉片卡往外翻會把大小撐大，最後統一縮
_lo = Vector([min(v.co[i] for v in _bm.verts) for i in range(3)])
_hi = Vector([max(v.co[i] for v in _bm.verts) for i in range(3)])
_k = 2.6 / max(_hi.x - _lo.x, _hi.y - _lo.y)
bmesh.ops.scale(_bm, vec=(_k, _k, 1.6 / (_hi.z - max(_lo.z, 0.0))), verts=_bm.verts)
_me = bpy.data.meshes.new('Bush')
_bm.to_mesh(_me)
_bm.free()
_me.materials.append(BUSH_DARK)
_me.materials.append(BUSH_CARD)
bush = bpy.data.objects.new('Bush', _me)
bpy.context.scene.collection.objects.link(bush)
_card_normals(bush)

# ================= 麥子、草叢（沒有碰撞，遊戲裡用 MultiMesh 撒幾千叢） =================
# 三片交叉的葉片＋穗，三十幾個三角形。一叢一叢的輪廓比一塊平板像田
WHEAT = mat('p_wheat', (0.22, 0.20, 0.035), 1.0)   # 偏黃綠：黃昏的橘光照上去才會是參考圖那種乾草色
GRASS = mat('p_grass', (0.40, 0.34, 0.16), 1.0)   # 枯黃的草叢
for k in range(4):                                    # 四根粗麥稈，各自往外歪一點，頂端一顆麥穗（七根細的俯瞰像白色雜訊）
    a = k * math.tau / 4 + 0.3
    r = 0.06 + 0.05 * (k % 3)
    tilt = 0.10 + 0.05 * (k % 2)
    h = 0.72 + 0.06 * ((k * 3) % 4)
    x, y = r * math.cos(a), r * math.sin(a)
    box((0.036, 0.036, h), (x, y, h / 2), (-tilt * math.sin(a), tilt * math.cos(a), 0), m=WHEAT)
    box((0.07, 0.07, 0.16), (x + tilt * h * math.cos(a), y + tilt * h * math.sin(a), h + 0.05),
        (-tilt * math.sin(a), tilt * math.cos(a), a), m=WHEAT)
wheat = finish('WheatTuft', bevel=0.0, seg=1)
for k in range(6):                                    # 六片細長的草葉往外散開
    a = k * math.tau / 6
    tilt = 0.35 + 0.1 * (k % 2)
    box((0.05, 0.012, 0.38), (0.06 * math.cos(a), 0.06 * math.sin(a), 0.17),
        (-tilt * math.sin(a), tilt * math.cos(a), a), m=GRASS)
grass = finish('GrassClump', bevel=0.0, seg=1)

# ================= 恐龍蛋 =================
# 下胖上尖的蛋形＋深色斑點。原點在中心
EGG   = mat('p_egg',   (0.93, 0.89, 0.78), 0.5)
SPOT  = mat('p_spot',  (0.45, 0.38, 0.28), 0.6)
sphere(0.35, (0, 0, 0), 24, 16, m=EGG)
for v in _parts[-1].data.vertices:                    # 拉長、上半收尖
    z = v.co.z * 1.35
    k = 1.0 - 0.18 * max(z, 0) / 0.47
    v.co.x *= k
    v.co.y *= k
    v.co.z = z
random.seed(20260927)                                 # 固定 seed：每次重建斑點位置一樣
for i in range(14):                                   # 斑點：貼在蛋殼上的扁球
    th = random.uniform(0, math.tau)
    zz = random.uniform(-0.35, 0.35)
    rr = 0.35 * math.sqrt(max(0.0, 1 - (zz / 0.47) ** 2)) * (1.0 - 0.18 * max(zz, 0) / 0.47)
    sphere(random.uniform(0.03, 0.06), (rr * math.cos(th), rr * math.sin(th), zz), 8, 6, m=SPOT)
    for v in _parts[-1].data.vertices:
        v.co.x *= 0.5 if abs(math.cos(th)) > 0.7 else 1.0
        v.co.y *= 0.5 if abs(math.sin(th)) > 0.7 else 1.0
egg = finish('Egg', bevel=0.0, seg=1, smooth_mats=('p_egg', 'p_spot'))

# ================= 篷車（撤離點的地標） =================
# 功能零件：車斗、四個有輻條的木輪＋車軸、帆布篷（一道道木拱撐著）、車轅
CANVAS = mat('p_canvas', (0.86, 0.82, 0.70), 0.95)
box((1.6, 3.6, 0.5), (0, 0, 1.05), m=WOOD)                     # 車斗
box((1.7, 3.7, 0.08), (0, 0, 0.80), m=WOOD_D)                  # 車斗底板
for sy, r in ((-1, 0.62), (1, 0.52)):                          # 前輪小、後輪大
    y = sy * 1.3
    cyl(0.05, 1.9, (0, y, r), (0, math.pi / 2, 0), 8, m=WOOD_D)                 # 車軸
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=r - 0.04, minor_radius=0.05, major_segments=20,
                                         minor_segments=4, location=(sx * 0.92, y, r), rotation=(0, math.pi / 2, 0))
        _push(bpy.context.object, WOOD_D)
        for k in range(6):                                                        # 輻條
            box((0.04, 0.04, (r - 0.05) * 2), (sx * 0.92, y, r), (k * math.pi / 6, 0, 0), m=WOOD)
        cyl(0.10, 0.14, (sx * 0.92, y, r), (0, math.pi / 2, 0), 10, m=BAND)      # 輪轂
for k in range(5):                                             # 木拱＋帆布
    y = -1.6 + k * 0.8
    bpy.ops.mesh.primitive_torus_add(major_radius=0.82, minor_radius=0.04, major_segments=16,
                                     minor_segments=4, location=(0, y, 1.3), rotation=(math.pi / 2, 0, 0))
    _push(bpy.context.object, WOOD_D)
sphere(0.85, (0, 0, 1.3), 20, 10, m=CANVAS)                    # 帆布：拉長的半球
for v in _parts[-1].data.vertices:
    v.co.z = max(v.co.z, 0.0) * 1.0
    v.co.y *= 2.2
box((0.10, 2.2, 0.10), (0, -2.9, 0.55), (0.12, 0, 0), m=WOOD_D)  # 車轅
wagon = finish('Wagon', bevel=0.0, seg=1, smooth_mats=('p_canvas',))

# 每個物件的原點都在世界原點（上面就是照這樣建的），旋轉烘進網格
for o in bpy.data.objects:
    if o.type == 'MESH':
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.select_all(action='DESELECT')

# 看圖用的排版：沿 X 排開（匯出前會歸位）
LAYOUT = {'Barn': 0, 'BarnRoof': 0, 'BarnCol': -30, 'BarnDoorSlide': 0, 'BarnBackDoor': 4,
          'SiloBody': 38, 'SiloDome': 38,
          'HayBale': 53, 'TreePine': 70, 'Bush': 76,
          'WheatTuft': 80, 'GrassClump': 82, 'Egg': 85, 'Wagon': 90}
LIFT = {'BarnRoof': BARN[2], 'SiloDome': SILO_H, 'HayBale': 0.7, 'Egg': 0.5}


def show_layout(only=None):
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.location = (LAYOUT[o.name], 0, LIFT.get(o.name, 0))
            o.hide_viewport = only is not None and not o.name.startswith(only)


def export(out_dir):
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.location = (0, 0, 0)
            o.hide_viewport = False
            o.select_set(True)
    path = os.path.join(out_dir, 'props.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    print('exported ->', path)


if __name__ == '__main__':   # 背景跑：tools/model_iter.sh prop <版號>（輸出 --out 資料夾裡的 props.glb）
    pipeline.run(lambda: [o for o in bpy.data.objects if o.type == 'MESH'],
                 lambda obs, path: (show_layout(), pipeline.scene_preview(obs, path)),
                 budget=20000, export_fn=lambda obs, out: export(os.path.dirname(out) or '.'))
