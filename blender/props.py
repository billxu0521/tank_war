# 鄉村場景物件：穀倉、農舍、筒倉、柵欄、乾草捲、兩種樹、灌木叢、山崖、麥子、草叢、蛋、篷車。
#
# 座標用 Blender 的：X 右、Y 前（= Godot -Z）、Z 上。單位公尺。
# 每個物件都以「自己的原點」為準建在世界原點（匯出後 main.gd 直接拿 mesh 擺）：
#   Barn        牆身，原點在地面中央。基準尺寸 14 寬 × 20 長 × 8 高（牆），遊戲裡照實際大小縮放
#   BarnRoof    屋頂＋山牆三角，原點在牆頂中央。遊戲裡 X、高度用同一個倍率縮，斜度才不會變
#   House       農舍連屋頂和煙囪，10 × 8 × 5（跟 main.gd 的碰撞一樣大，不縮放）
#   SiloBody    筒倉筒身，原點在地面中央，基準高 15（遊戲裡只縮高度）
#   SiloDome    圓頂，原點在筒身頂
#   FenceRail   一段 2.5 公尺的柵欄（一根木樁＋兩根橫木），遊戲裡沿長度排
#   FencePost   柵欄最後收尾的那根木樁
#   HayBale     圓捆乾草，軸是直的（遊戲裡跟碰撞圓柱一起放倒），原點在中心
#   TreeOak / TreePine  原點在樹根，基準樹幹高 5
#   Bush        灌木叢，原點在地面中央，約 2.2 寬 1.5 高（沒有碰撞，只擋視線）
#
# 跟 main.gd 共用的數字（改一邊要改另一邊）：
#   BARN / BARN_PITCH = main.gd _barn() 的基準大小和 _roof() 的 0.55
#   BARN_DOOR_*、BARN_BACK_X、BARN_LOFT、BARN_LADDER_X、HOUSE_PART_Y = main.gd 擺門和梯子的位置
#   BarnCol / HouseCol 是碰撞形狀（遊戲裡看不見），牆和開口在這裡定義一次就好
#   HOUSE / HOUSE_PITCH = _house() 的 (10, 5, 8) 和 0.5；煙囪位置 (3, 6~9)
#   FENCE_H = main.gd FENCE_H，FENCE_SEG = 柵欄一段多長
#
# 重建：Blender 裡 BASE = '<這個資料夾>'; exec(open(BASE + '/props.py').read()); export('<專案>/models')
import bpy, bmesh, math, os
exec(open(BASE + '/common.py').read())

BARN = (14.0, 20.0, 8.0)       # 寬（X）、長（Y）、牆高（Z）
BARN_PITCH = 0.55
BARN_T = 0.25                  # 牆厚
BARN_DOOR_W, BARN_DOOR_H = 5.0, 4.8   # 大門開口（兩扇滑門各一半寬）
BARN_BACK_X = 4.0              # 後門中心的 X（寬 1.2、高 2.2）
BARN_LOFT = 4.0                # 閣樓地板頂面高度（後半部，邊緣在 y=0）
BARN_LADDER_X = -2.5           # 梯子的 X（靠在閣樓邊緣）
HOUSE = (10.0, 8.0, 5.0)
HOUSE_PITCH = 0.5
HOUSE_T = 0.2
HOUSE_PART_Y = 1.0             # 隔間牆在 Blender y=1（Godot z=-1），前面客廳、後面臥室
SILO_R, SILO_H = 3.0, 15.0
FENCE_H, FENCE_SEG = 1.0, 2.5
TRUNK = 5.0

for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o)
wipe()
RED    = mat('p_red',    (0.50, 0.13, 0.10), 0.85)
RED_D  = mat('p_red_d',  (0.38, 0.09, 0.07), 0.85)
TRIM   = mat('p_trim',   (0.86, 0.84, 0.78), 0.8)
ROOF   = mat('p_roof',   (0.30, 0.29, 0.28), 0.6, 0.5)   # 鐵皮屋頂
STONE  = mat('p_stone',  (0.45, 0.43, 0.40), 0.95)
WOOD   = mat('p_wood',   (0.48, 0.36, 0.24), 0.9)
WOOD_D = mat('p_wood_d', (0.28, 0.20, 0.14), 0.9)
GLASS  = mat('p_glass',  (0.10, 0.12, 0.14), 0.2)
WHITE  = mat('p_white',  (0.82, 0.79, 0.72), 0.9)        # 農舍的白色護牆板
SHUT   = mat('p_shut',   (0.20, 0.30, 0.22), 0.8)        # 百葉窗
SHING  = mat('p_shing',  (0.30, 0.30, 0.32), 0.9)        # 瓦片
BRICK  = mat('p_brick',  (0.50, 0.25, 0.18), 0.95)
SILO   = mat('p_silo',   (0.62, 0.62, 0.60), 0.5, 0.6)
BAND   = mat('p_band',   (0.42, 0.42, 0.42), 0.4, 0.8)
HAY    = mat('p_hay',    (0.80, 0.68, 0.36), 1.0)
HAY_D  = mat('p_hay_d',  (0.62, 0.50, 0.25), 1.0)
TWINE  = mat('p_twine',  (0.35, 0.28, 0.18), 0.9)
BARK   = mat('p_bark',   (0.30, 0.22, 0.16), 1.0)
LEAF1  = mat('p_leaf1',  (0.22, 0.34, 0.14), 0.9)
LEAF2  = mat('p_leaf2',  (0.30, 0.40, 0.16), 0.9)
PINE   = mat('p_pine',   (0.13, 0.25, 0.14), 0.9)


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


# ---- 碰撞：蓋牆的時候順便記一份，最後變成 *Col 物件給遊戲當碰撞形狀 ----
# 牆、門洞、窗洞只定義一次，畫面和碰撞一定對得上
COL = []


def solid(size, loc, rot=(0, 0, 0), m=None):
    """有碰撞的方塊：牆、閣樓地板、柱子、家具"""
    COL.append((size, loc, rot))
    return box(size, loc, rot, m=m)


def make_col(name):
    """把記下來的碰撞方塊合成一個物件（沒有倒角、沒有材質，遊戲裡只拿來做形狀）"""
    global COL
    for size, loc, rot in COL:
        box(size, loc, rot)
    COL = []
    return finish(name, bevel=0.0, seg=1)


def wall(axis, at, a0, a1, h, t, openings, m):
    """一面有開口的牆。axis='x'：沿 X 的牆（前後牆），在 y=at；axis='y'：沿 Y 的牆（側牆），在 x=at。
    openings = [(中心, 寬, 下緣, 上緣)]。開口兩側整片、開口上下各補一塊"""
    def piece(u0, u1, z0, z1):
        if u1 - u0 < 0.01 or z1 - z0 < 0.01:
            return
        cu, cz = (u0 + u1) / 2, (z0 + z1) / 2
        if axis == 'x':
            solid((u1 - u0, t, z1 - z0), (cu, at, cz), m=m)
        else:
            solid((t, u1 - u0, z1 - z0), (at, cu, cz), m=m)
    u = a0
    for (c, w, b, top) in sorted(openings):
        piece(u, c - w / 2, 0, h)
        piece(c - w / 2, c + w / 2, 0, b)
        piece(c - w / 2, c + w / 2, top, h)
        u = c + w / 2
    piece(u, a1, 0, h)


def clear_of(u, openings, pad=0.1):
    """u 這個位置有沒有落在某個開口的寬度裡；有就回傳那個開口（護牆板要在那裡斷開）"""
    for o in openings:
        if abs(u - o[0]) < o[1] / 2 + pad:
            return o
    return None


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
IRON = mat('p_iron', (0.12, 0.12, 0.13), 0.5, 0.7)
CLOTH = mat('p_cloth', (0.55, 0.18, 0.14), 0.95)
LINEN = mat('p_linen', (0.85, 0.83, 0.76), 0.95)
PLANK = mat('p_plank', (0.40, 0.29, 0.19), 0.9)


# ================= 穀倉（空心：大門、後門、側窗都是開口，裡面有閣樓和梯子） =================
# 功能零件：石頭牆基、直條護牆板（開口處斷開）、白色轉角包邊、大門門框和滑軌（門板是另外的物件）、
# 側窗、閣樓（地板、邊緣大樑、撐住它的柱子）、梯子、馬廄隔間和飼料槽、乾草、木桶、
# 工作台和工具、掛在牆上的車輪、吊在閣樓下的提燈
W, L, H = BARN
T = BARN_T
FRONT = [(0.0, BARN_DOOR_W, 0.0, BARN_DOOR_H)]                  # 大門
BACK = [(BARN_BACK_X, 1.2, 0.0, 2.2)]                            # 後門
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
for sx in (-1, 1):                                                             # 側牆直條板（窗那段斷開）
    for k in range(int(L)):
        y = -L / 2 + 0.5 + k
        o = clear_of(y, SIDE)
        segs = [(0.6, H)] if not o else [(0.6, o[2] - 0.1), (o[3] + 0.1, H)]
        for z0, z1 in segs:
            box((0.06, 0.12, z1 - z0), (sx * (W / 2 + 0.03), y, (z0 + z1) / 2), m=RED_D)
for sy, ops in ((-1, FRONT), (1, BACK)):                                       # 前後牆直條板（門那段斷開）
    for k in range(int(W)):
        x = -W / 2 + 0.5 + k
        o = clear_of(x, ops)
        segs = [(0.6, H)] if not o else [(o[3] + 0.1, H)]
        for z0, z1 in segs:
            box((0.12, 0.06, z1 - z0), (x, sy * (L / 2 + 0.03), (z0 + z1) / 2), m=RED_D)
for sx in (-1, 1):                                                             # 轉角白包邊
    for sy in (-1, 1):
        box((0.28, 0.28, H), (sx * W / 2, sy * L / 2, H / 2), m=TRIM)
box((W + 0.1, 0.2, 0.25), (0, -L / 2 - 0.08, H - 0.12), m=TRIM)                # 前牆頂的橫帶
for sx in (-1, 1):                                                             # 大門門框
    box((0.25, 0.2, BARN_DOOR_H), (sx * (BARN_DOOR_W / 2 + 0.12), -L / 2 - 0.02, BARN_DOOR_H / 2), m=TRIM)
box((BARN_DOOR_W + 0.5, 0.2, 0.25), (0, -L / 2 - 0.02, BARN_DOOR_H + 0.12), m=TRIM)
box((BARN_DOOR_W * 2 + 0.6, 0.12, 0.18), (0, -L / 2 - 0.26, BARN_DOOR_H + 0.25), m=BAND)   # 滑門軌道（門往兩邊拉）
for sx in (-1, 1):                                                             # 後門門框
    box((0.12, 0.16, 2.3), (BARN_BACK_X + sx * 0.66, L / 2 + 0.02, 1.15), m=TRIM)
box((1.44, 0.16, 0.12), (BARN_BACK_X, L / 2 + 0.02, 2.26), m=TRIM)
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
barn = finish('Barn', bevel=0.02, seg=1)
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
slide = finish('BarnDoorSlide', bevel=0.02, seg=1)
box((1.2, 0.08, 2.2), (0.6, 0, 1.1), m=RED_D)                                   # 後門：原點在門軸
for z in (0.4, 1.8):
    box((1.1, 0.1, 0.12), (0.6, 0, z), m=TRIM)
box((1.2, 0.1, 0.1), (0.6, 0, 1.1), (0, math.atan2(1.4, 1.1), 0), m=TRIM)
sphere(0.04, (1.05, -0.07, 1.05), 8, 6, m=BAND)
back_door = finish('BarnBackDoor', bevel=0.01, seg=1)

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
roof = finish('BarnRoof', bevel=0.02, seg=1)

# ================= 農舍（空心：門、窗是開口，裡面分客廳和臥室） =================
# 功能零件：石頭牆基、橫向護牆板（開口處斷開）、轉角板、窗框和綠色百葉、門框（門是另外的物件）、
# 前廊、瓦片屋頂、山牆、磚煙囪；室內：地板、隔間牆（有門洞）、地毯、餐桌椅、油燈、鑄鐵爐和煙管、
# 書架、床、衣櫃、臉盆架
HW, HL, HH = HOUSE     # 寬 X、深 Y、牆高 Z
T = HOUSE_T
HFRONT = [(0.0, 1.1, 0.0, 2.2), (-3.0, 1.1, 1.0, 2.2), (3.0, 1.1, 1.0, 2.2)]   # 門＋兩扇窗（窗台 1 公尺，翻得過去）
HBACK = [(-3.0, 1.1, 1.0, 2.2), (3.0, 1.1, 1.0, 2.2)]
HSIDE = [(0.0, 1.1, 1.0, 2.2)]
wall('x', -HL / 2 + T / 2, -HW / 2, HW / 2, HH, T, HFRONT, WHITE)
wall('x', HL / 2 - T / 2, -HW / 2, HW / 2, HH, T, HBACK, WHITE)
for sx in (-1, 1):
    wall('y', sx * (HW / 2 - T / 2), -HL / 2 + T, HL / 2 - T, HH, T, HSIDE, WHITE)
# 隔間牆：前面客廳、後面臥室，門洞在右邊
wall('x', HOUSE_PART_Y, -HW / 2 + T, HW / 2 - T, HH, 0.12, [(2.5, 1.0, 0.0, 2.2)], WHITE)
for sy in (-1, 1):                                                             # 石頭牆基
    box((HW + 0.2, 0.35, 0.4), (0, sy * HL / 2, 0.2), m=STONE)
for sx in (-1, 1):
    box((0.35, HL + 0.2, 0.4), (sx * HW / 2, 0, 0.2), m=STONE)
box((HW - 2 * T, HL - 2 * T, 0.04), (0, 0, 0.02), m=PLANK)                      # 木地板
def strips(axis, at, a0, a1, z, ops):
    """一條橫向護牆板：高度 z 落在某個開口上下緣之間的，那一段就斷開"""
    cuts = sorted((c - w / 2, c + w / 2) for (c, w, b, top) in ops if b <= z <= top)
    u = a0
    for c0, c1 in cuts + [(a1, a1)]:
        if c0 - u > 0.05:
            if axis == 'x':
                box((c0 - u, 0.04, 0.05), ((u + c0) / 2, at, z), m=TRIM)
            else:
                box((0.04, c0 - u, 0.05), (at, (u + c0) / 2, z), m=TRIM)
        u = max(u, c1)


for k in range(1, int(HH / 0.3)):                                              # 護牆板：一條一條橫的，開口處斷開
    z = 0.4 + k * 0.3
    strips('x', -(HL / 2 + 0.02), -HW / 2, HW / 2, z, HFRONT)
    strips('x', HL / 2 + 0.02, -HW / 2, HW / 2, z, HBACK)
    for sx in (-1, 1):
        strips('y', sx * (HW / 2 + 0.02), -HL / 2, HL / 2, z, HSIDE)
for sx in (-1, 1):
    for sy in (-1, 1):
        box((0.22, 0.22, HH), (sx * HW / 2, sy * HL / 2, HH / 2), m=TRIM)     # 轉角板
for (c, w, b, top) in HFRONT[1:]:
    window(c, -HL / 2 - 0.02, (b + top) / 2, -1, h=top - b, shutters=True)
for (c, w, b, top) in HBACK:
    window(c, HL / 2 + 0.02, (b + top) / 2, 1, h=top - b, shutters=True)
for sx in (-1, 1):
    window(sx * (HW / 2 + 0.02), 0, 1.6, 'x+' if sx > 0 else 'x-', h=1.2)
box((1.4, 0.14, 0.14), (0, -HL / 2 - 0.08, 2.27), m=TRIM)                      # 門框
for sx in (-1, 1):
    box((0.14, 0.14, 2.3), (sx * 0.62, -HL / 2 - 0.08, 1.15), m=TRIM)
# 前廊：地板很薄（8 公分）——遊戲裡沒有碰撞，走上去腳只陷一點點
box((HW, 2.2, 0.08), (0, -HL / 2 - 1.1, 0.04), m=WOOD)
for x in (-4.8, -1.6, 1.6, 4.8):
    box((0.16, 0.16, 2.7), (x, -HL / 2 - 2.1, 1.35), m=TRIM)                     # 柱子
box((HW + 0.4, 2.6, 0.12), (0, -HL / 2 - 1.2, 2.75), (-0.15, 0, 0), m=SHING)   # 前廊的小屋頂
# ---- 客廳（前面，Blender y < HOUSE_PART_Y） ----
box((2.6, 1.8, 0.02), (-1.6, -1.8, 0.05), m=CLOTH)                             # 地毯
solid((1.6, 0.9, 0.06), (-1.6, -1.8, 0.78), m=WOOD)                            # 餐桌
for sx in (-1, 1):
    for sy in (-1, 1):
        box((0.07, 0.07, 0.75), (-1.6 + sx * 0.7, -1.8 + sy * 0.35, 0.375), m=WOOD_D)
for sx in (-1, 1):                                                             # 兩張椅子
    box((0.45, 0.45, 0.05), (-1.6 + sx * 1.1, -1.8, 0.47), m=WOOD_D)
    box((0.05, 0.45, 0.5), (-1.6 + sx * 1.33, -1.8, 0.72), m=WOOD_D)
    for dx in (-0.18, 0.18):
        for dy in (-0.18, 0.18):
            box((0.04, 0.04, 0.45), (-1.6 + sx * 1.1 + dx, -1.8 + dy, 0.225), m=WOOD_D)
lantern((-1.6, -1.8, 0.93))                                                     # 桌上的油燈
solid((0.8, 0.6, 0.8), (3.4, -0.2, 0.4), m=IRON)                                # 鑄鐵爐（煙管接到煙囪）
cyl(0.09, HH - 0.8, (3.4, -0.2, 0.8 + (HH - 0.8) / 2), (0, 0, 0), 10, m=IRON)
for k in range(3):                                                              # 靠左牆的書架
    box((0.3, 1.4, 0.04), (-HW / 2 + T + 0.15, -2.2, 0.6 + k * 0.55), m=WOOD)
    for j in range(5):
        box((0.22, 0.08, 0.3), (-HW / 2 + T + 0.15, -2.8 + j * 0.25 + (k * 0.07), 0.77 + k * 0.55), m=CLOTH if (j + k) % 2 else PLANK)
for sy in (-1, 1):                                                             # 隔間牆兩面的木頭護牆板
    box((HW - 2 * T, 0.03, 0.9), (0, HOUSE_PART_Y + sy * 0.075, 0.45), m=PLANK)
    box((HW - 2 * T, 0.05, 0.06), (0, HOUSE_PART_Y + sy * 0.08, 0.92), m=WOOD_D)
for x, (w, h) in ((-2.8, (0.7, 0.5)), (-0.6, (0.5, 0.65))):                     # 客廳這面的兩幅畫
    box((w + 0.08, 0.03, h + 0.08), (x, HOUSE_PART_Y - 0.08, 1.8), m=WOOD_D)
    box((w, 0.03, h), (x, HOUSE_PART_Y - 0.09, 1.8), m=LINEN if x < -1 else SHUT)
box((0.3, 0.12, 0.5), (0.8, HOUSE_PART_Y - 0.12, 1.9), m=WOOD_D)                # 掛鐘
cyl(0.1, 0.02, (0.8, HOUSE_PART_Y - 0.19, 2.0), (math.pi / 2, 0, 0), 12, m=LINEN)
# ---- 臥室（後面） ----
solid((1.2, 2.0, 0.45), (-3.2, 2.7, 0.225), m=WOOD_D)                          # 床
box((1.1, 1.6, 0.12), (-3.2, 2.5, 0.51), m=LINEN)                               # 被子
box((0.8, 0.35, 0.12), (-3.2, 3.45, 0.55), m=LINEN)                             # 枕頭
box((1.2, 0.08, 0.9), (-3.2, 3.72, 0.45), m=WOOD_D)                             # 床頭板
solid((1.0, 0.5, 1.6), (3.3, 3.45, 0.8), m=WOOD)                                # 衣櫃
box((0.04, 0.02, 1.4), (3.3, 3.19, 0.8), m=WOOD_D)                              # 衣櫃門縫
box((0.6, 0.45, 0.8), (1.4, 3.5, 0.4), m=WOOD_D)                                # 臉盆架
cyl(0.2, 0.08, (1.4, 3.5, 0.84), (0, 0, 0), 12, m=LINEN)                        # 臉盆
rise = gable_roof(HW, HL, HOUSE_PITCH, SHING, rib=None)
for o in _parts[-2:]:
    o.location.z += HH
for sx in (-1, 1):                                                             # 瓦片：一排一排疊
    run = HW / 2
    for k in range(1, 9):
        t = k / 9
        box((0.05, HL + 1.0, 0.06),
            (sx * run * (1 - t) - sx * 0.02, 0, HH + rise * t + 0.2 - 0.03),
            (0, sx * HOUSE_PITCH, 0), m=BRICK if k % 4 == 0 else SHING)
for sy in (-1, 1):
    prism(HW, rise, 0.2, (0, sy * (HL / 2 - 0.1), HH), m=WHITE)
box((0.9, 0.9, 3.0), (3.0, 0, 7.5), m=BRICK)                                    # 煙囪（碰撞在 main.gd）
box((1.1, 1.1, 0.18), (3.0, 0, 9.0), m=STONE)                                   # 煙囪帽
house = finish('House', bevel=0.015, seg=1)
house_col = make_col('HouseCol')
box((1.1, 0.08, 2.2), (0.55, 0, 1.1), m=WOOD_D)                                 # 農舍的門：原點在門軸
for z in (0.5, 1.7):
    box((0.9, 0.1, 0.5), (0.55, 0, z), m=WOOD)                                  # 門板上的兩塊鑲板
sphere(0.05, (0.95, -0.07, 1.05), 8, 6, m=BAND)                                  # 門把
hdoor = finish('HouseDoor', bevel=0.01, seg=1)

# ================= 筒倉 =================
# 功能零件：水泥底座、筒身、一圈圈的鐵箍、側面的爬梯（兩根扶手＋橫檔）、圓頂＋頂上的通風帽
cyl(SILO_R + 0.25, 0.6, (0, 0, 0.3), (0, 0, 0), 32, m=STONE)
cyl(SILO_R, SILO_H, (0, 0, SILO_H / 2), (0, 0, 0), 32, m=SILO)
for k in range(1, int(SILO_H / 1.5)):
    cyl(SILO_R + 0.04, 0.12, (0, 0, k * 1.5), (0, 0, 0), 32, m=BAND)
for sy in (-1, 1):                                                             # 爬梯
    box((0.08, 0.08, SILO_H - 1.0), (SILO_R + 0.25, sy * 0.25, SILO_H / 2 + 0.5), m=BAND)
for k in range(int((SILO_H - 1.0) / 0.4)):
    box((0.05, 0.5, 0.05), (SILO_R + 0.25, 0, 1.2 + k * 0.4), m=BAND)
for k in range(int(SILO_H / 1.5)):                                             # 爬梯固定架
    box((0.3, 0.06, 0.06), (SILO_R + 0.12, 0, 1.5 + k * 1.5), m=BAND)
silo = finish('SiloBody', bevel=0.02, seg=1)

sphere(SILO_R + 0.1, (0, 0, 0), 32, 12, m=SILO)
for v in _parts[-1].data.vertices:                                             # 壓成扁圓頂、只留上半
    v.co.z = max(v.co.z, 0.0) * (1.6 / (SILO_R + 0.1))
cyl(0.35, 0.5, (0, 0, 1.75), (0, 0, 0), 12, m=BAND)                            # 通風帽
cone(0.55, 0.05, 0.35, (0, 0, 2.15), (0, 0, 0), 12, m=SILO)
dome = finish('SiloDome', bevel=0.02, seg=1)

# ================= 柵欄 =================
# 功能零件：木樁（頂端削斜，雨水才流得掉）、兩根圓木橫木、橫木釘在木樁上的鐵釘
def post(x):
    box((0.15, 0.15, FENCE_H + 0.1), (x, 0, (FENCE_H + 0.1) / 2), m=WOOD_D)
    cone(0.11, 0.02, 0.10, (x, 0, FENCE_H + 0.15), (0, 0, math.pi / 4), 4, m=WOOD_D)

post(-FENCE_SEG / 2)
for z, tilt in ((0.45, 0.02), (0.90, -0.015)):                                 # 橫木稍微歪一點，看起來是手工釘的
    cyl(0.055, FENCE_SEG + 0.1, (0, 0.10, z), (tilt, math.pi / 2, 0), 8, m=WOOD)
    sphere(0.02, (-FENCE_SEG / 2 + 0.05, 0.16, z), 6, 4, m=BAND)
rail = finish('FenceRail', bevel=0.01, seg=1)
post(0)
fpost = finish('FencePost', bevel=0.01, seg=1)

# ================= 乾草捲 =================
# 功能零件：捲起來的草（兩個端面一圈圈的年輪）、綁草的麻繩、端面邊緣收圓
cyl(0.70, 1.20, (0, 0, 0), (0, 0, 0), 32, m=HAY)
for sz in (-1, 1):
    cyl(0.66, 0.06, (0, 0, sz * 0.62), (0, 0, 0), 32, m=HAY)                   # 端面收圓一點
    for r in (0.18, 0.34, 0.50):                                               # 端面的一圈圈捲痕
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.018, major_segments=24,
                                         minor_segments=4, location=(0, 0, sz * 0.655))
        _push(bpy.context.object, HAY_D)
for z in (-0.35, 0.0, 0.35):                                                   # 麻繩
    bpy.ops.mesh.primitive_torus_add(major_radius=0.705, minor_radius=0.014, major_segments=32,
                                     minor_segments=4, location=(0, 0, z))
    _push(bpy.context.object, TWINE)
bale = finish('HayBale', bevel=0.03, seg=2, smooth_mats=('p_hay',))

# ================= 樹 =================
# 橡樹：樹根往外撐、樹幹、三根分枝、七團樹葉（一團團而不是一顆球，輪廓才像樹）
cone(0.60, 0.35, 0.8, (0, 0, 0.4), (0, 0, 0), 10, m=BARK)                        # 根部
cyl(0.35, TRUNK, (0, 0, TRUNK / 2), (0, 0, 0), 10, m=BARK)
for ang, tilt in ((0.3, 0.6), (2.4, 0.7), (4.3, 0.55)):
    dx, dy = math.cos(ang), math.sin(ang)
    cyl(0.14, 2.2, (dx * 0.6, dy * 0.6, TRUNK - 0.3), (tilt * -dy, tilt * dx, 0), 8, m=BARK)
for (x, y, z, r, m) in ((0, 0, 7.2, 2.3, LEAF1), (1.6, 0.4, 6.3, 1.7, LEAF2), (-1.5, 0.8, 6.4, 1.8, LEAF1),
                        (0.4, -1.6, 6.5, 1.7, LEAF2), (-0.6, 1.4, 7.6, 1.5, LEAF2), (1.0, -0.7, 7.8, 1.5, LEAF1),
                        (-1.2, -1.0, 6.0, 1.4, LEAF2)):
    sphere(r, (x, y, z), 12, 8, m=m)
oak = finish('TreeOak', bevel=0.0, seg=1)

# 松樹：直的樹幹，四層往上縮的錐形樹冠
cyl(0.30, TRUNK + 2.0, (0, 0, (TRUNK + 2.0) / 2), (0, 0, 0), 8, m=BARK)
for k in range(4):
    r = 2.6 - k * 0.55
    cone(r, 0.05, 2.8, (0, 0, 3.2 + k * 1.5), (0, 0, k * 0.4), 10, m=PINE)
pine = finish('TreePine', bevel=0.0, seg=1)

# 灌木叢：九團壓扁的葉團疊成一叢，約 2.2 寬、1.5 高——站著露出頭、蹲下整個藏住。
# 沒有碰撞（跟 Hunt 一樣只擋視線、不擋子彈，人也走得進去）
BUSH_DARK = mat('p_bush', (0.20, 0.30, 0.13), 0.9)
for (x, y, z, r, sz, m) in ((0, 0, 0.75, 0.80, 0.85, LEAF1), (0.65, 0.25, 0.55, 0.62, 0.8, LEAF2),
                            (-0.60, 0.30, 0.58, 0.65, 0.8, BUSH_DARK), (0.15, -0.60, 0.52, 0.60, 0.8, LEAF2),
                            (-0.25, 0.65, 0.50, 0.55, 0.8, LEAF1), (0.55, -0.35, 0.95, 0.48, 0.9, LEAF1),
                            (-0.45, -0.40, 0.90, 0.50, 0.9, BUSH_DARK), (0.10, 0.20, 1.15, 0.50, 0.85, LEAF2),
                            (0.85, 0.55, 0.35, 0.42, 0.75, BUSH_DARK)):
    o = sphere(r, (x, y, z), 9, 6, m=m)
    o.scale = (1.0, 1.0, sz)
import random
_br = random.Random(11)
for k in range(10):                                   # 外圍再補十團小的，輪廓才毛毛的
    a = k * math.tau / 10 + _br.uniform(-0.2, 0.2)
    rr = _br.uniform(0.75, 1.05)
    sphere(_br.uniform(0.28, 0.40), (rr * math.cos(a), rr * math.sin(a), _br.uniform(0.35, 1.0)), 7, 5,
           m=(LEAF1, LEAF2, BUSH_DARK)[k % 3])
bush = finish('Bush', bevel=0.0, seg=1)
# 每個頂點隨機推進推出：一團團圓球看起來像葡萄，推亂了才像葉子
for v in bush.data.vertices:
    v.co += Vector((_br.uniform(-1, 1), _br.uniform(-1, 1), _br.uniform(-1, 1))) * 0.07

# ================= 山崖（圍牆的外觀） =================
# 一段 40 公尺寬。內側面在 y=0、岩塊都往 +Y（牆外）長，才不會凸進場地——
# 碰撞是 main.gd 的平面牆，凸進來的石頭會變成看得到、摸不到的東西
import random
random.seed(20260927)
ROCK1 = mat('p_rock1', (0.40, 0.36, 0.31), 0.95)
ROCK2 = mat('p_rock2', (0.33, 0.30, 0.27), 0.95)
MOSS  = mat('p_moss',  (0.30, 0.36, 0.20), 1.0)
CW = 40.0
for i in range(22):                                   # 大岩塊：底下寬、往上收，頂端參差
    x = -CW / 2 + random.uniform(0, CW)
    h = random.uniform(26, 46)
    w = random.uniform(7, 13)
    d = random.uniform(6, 12)
    box((w, d, h), (x, d / 2 - 0.2, h / 2), (random.uniform(-0.08, 0.08), random.uniform(-0.12, 0.12),
        random.uniform(-0.3, 0.3)), m=random.choice((ROCK1, ROCK2)))
for i in range(26):                                   # 牆腳的碎石堆（貼著內側面）
    x = -CW / 2 + random.uniform(0, CW)
    r = random.uniform(1.0, 2.6)
    box((r * 1.6, r * 1.2, r), (x, r * 0.5, r * 0.45), (0, 0, random.uniform(0, 1.5)), m=ROCK2)
for i in range(12):                                   # 頂上的草皮
    x = -CW / 2 + random.uniform(0, CW)
    box((random.uniform(4, 9), 6, 0.8), (x, 4, random.uniform(38, 45)), m=MOSS)
cliff = finish('Cliff', bevel=0.3, seg=1)

# ================= 麥子、草叢（沒有碰撞，遊戲裡用 MultiMesh 撒幾千叢） =================
# 三片交叉的葉片＋穗，三十幾個三角形。一叢一叢的輪廓比一塊平板像田
WHEAT = mat('p_wheat', (0.82, 0.70, 0.36), 1.0)
GRASS = mat('p_grass', (0.33, 0.42, 0.20), 1.0)
for k in range(7):                                    # 七根麥稈，各自往外歪一點，頂端一顆麥穗
    a = k * math.tau / 7 + 0.3
    r = 0.06 + 0.05 * (k % 3)
    tilt = 0.10 + 0.05 * (k % 2)
    h = 0.72 + 0.06 * ((k * 3) % 4)
    x, y = r * math.cos(a), r * math.sin(a)
    box((0.018, 0.018, h), (x, y, h / 2), (-tilt * math.sin(a), tilt * math.cos(a), 0), m=WHEAT)
    box((0.045, 0.045, 0.14), (x + tilt * h * math.cos(a), y + tilt * h * math.sin(a), h + 0.05),
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
wagon = finish('Wagon', bevel=0.01, seg=1, smooth_mats=('p_canvas',))

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
          'House': 22, 'HouseCol': -50, 'HouseDoor': 22, 'SiloBody': 38, 'SiloDome': 38,
          'FenceRail': 48, 'FencePost': 48, 'HayBale': 53, 'TreeOak': 60, 'TreePine': 70, 'Bush': 76,
          'Cliff': 100, 'WheatTuft': 80, 'GrassClump': 82, 'Egg': 85, 'Wagon': 90}
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
