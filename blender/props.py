# 鄉村場景物件：穀倉、農舍、筒倉、柵欄、乾草捲、兩種樹、山崖、麥子、草叢、蛋、篷車。
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
#
# 跟 main.gd 共用的數字（改一邊要改另一邊）：
#   BARN / BARN_PITCH = main.gd _barn() 的基準大小和 _roof() 的 0.55
#   HOUSE / HOUSE_PITCH = _house() 的 (10, 5, 8) 和 0.5；煙囪位置 (3, 6~9)
#   FENCE_H = main.gd FENCE_H，FENCE_SEG = 柵欄一段多長
#
# 重建：Blender 裡 BASE = '<這個資料夾>'; exec(open(BASE + '/props.py').read()); export('<專案>/models')
import bpy, bmesh, math, os
exec(open(BASE + '/common.py').read())

BARN = (14.0, 20.0, 8.0)       # 寬（X）、長（Y）、牆高（Z）
BARN_PITCH = 0.55
HOUSE = (10.0, 8.0, 5.0)
HOUSE_PITCH = 0.5
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


def window(x, y, z, face, w=1.1, h=1.3, shutters=False):
    """窗：深色玻璃、白色窗框、十字窗櫺。face = +1/-1 是朝 ±Y 的牆，'x+' / 'x-' 是朝 ±X"""
    def at(dx, dz, size, m, out=0.0):
        if face in (1, -1):
            box(size, (x + dx, y + face * out, z + dz), m=m)
        else:
            s = 1 if face == 'x+' else -1
            box((size[1], size[0], size[2]), (x + s * out, y + dx, z + dz), m=m)
    at(0, 0, (w, 0.10, h), GLASS, 0.02)
    at(0, h / 2 + 0.06, (w + 0.24, 0.14, 0.12), TRIM, 0.04)
    at(0, -h / 2 - 0.06, (w + 0.30, 0.18, 0.12), TRIM, 0.05)
    for sx in (-1, 1):
        at(sx * (w / 2 + 0.05), 0, (0.10, 0.14, h), TRIM, 0.04)
    at(0, 0, (0.05, 0.12, h), TRIM, 0.05)
    at(0, 0, (w, 0.12, 0.05), TRIM, 0.05)
    if shutters:
        for sx in (-1, 1):
            at(sx * (w / 2 + 0.38), 0, (0.52, 0.08, h + 0.1), SHUT, 0.04)


# ================= 穀倉 =================
# 功能零件：石頭地基、直條護牆板、白色轉角包邊、兩扇大門（白色 X 橫檔、門框、上方滑軌）、
# 側牆的窗、屋頂（鐵皮浪板、屋脊蓋、屋頂中間的通風塔）、山牆（閣樓門、吊草料的橫樑）
W, L, H = BARN
box((W + 0.3, L + 0.3, 0.6), (0, 0, 0.3), m=STONE)                            # 地基
box((W, L, H), (0, 0, H / 2), m=RED)                                           # 牆身
for sx in (-1, 1):                                                             # 側牆直條板
    for k in range(int(L)):
        box((0.06, 0.12, H - 0.7), (sx * (W / 2 + 0.03), -L / 2 + 0.5 + k, H / 2 + 0.3), m=RED_D)
for sy in (-1, 1):                                                             # 前後牆直條板
    for k in range(int(W)):
        box((0.12, 0.06, H - 0.7), (-W / 2 + 0.5 + k, sy * (L / 2 + 0.03), H / 2 + 0.3), m=RED_D)
for sx in (-1, 1):                                                             # 轉角白包邊
    for sy in (-1, 1):
        box((0.28, 0.28, H), (sx * W / 2, sy * L / 2, H / 2), m=TRIM)
box((W + 0.1, 0.2, 0.25), (0, -L / 2 - 0.08, H - 0.12), m=TRIM)                # 前牆頂的橫帶
# 正門（朝 -Y，= Godot +Z，跟 main.gd 以前的門同一面）：兩扇門板＋白色 X＋門框＋滑軌
for sx in (-1, 1):
    cx = sx * 1.3
    box((2.5, 0.16, 4.8), (cx, -L / 2 - 0.10, 2.4), m=RED_D)
    diag = math.atan2(4.4, 2.3)
    for d in (-1, 1):
        box((5.0, 0.08, 0.22), (cx, -L / 2 - 0.20, 2.4), (0, d * diag, 0), m=TRIM)
    box((2.5, 0.08, 0.22), (cx, -L / 2 - 0.20, 4.7), m=TRIM)
    box((2.5, 0.08, 0.22), (cx, -L / 2 - 0.20, 0.12), m=TRIM)
    box((0.22, 0.08, 4.8), (cx + sx * 1.14, -L / 2 - 0.20, 2.4), m=TRIM)
box((0.22, 0.10, 4.8), (0, -L / 2 - 0.21, 2.4), m=TRIM)                        # 兩扇門中間
box((6.2, 0.12, 0.18), (0, -L / 2 - 0.26, 5.05), m=BAND)                        # 滑門軌道
for sx in (-1, 1):                                                             # 側牆的窗
    for k in (-6, 0, 6):
        window(sx * (W / 2 + 0.02), k, 5.4, 'x+' if sx > 0 else 'x-')
barn = finish('Barn', bevel=0.02, seg=1)

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

# ================= 農舍 =================
# 功能零件：石頭地基、橫向護牆板、轉角板、窗（窗框、十字窗櫺、綠色百葉）、門和門框、
# 前廊（地板、柱子、小屋頂）、瓦片屋頂（一排排）、山牆、磚煙囪和煙囪帽
HW, HL, HH = HOUSE     # 寬 X、深 Y、牆高 Z
box((HW + 0.2, HL + 0.2, 0.4), (0, 0, 0.2), m=STONE)
box((HW, HL, HH), (0, 0, HH / 2), m=WHITE)
for k in range(1, int(HH / 0.3)):                                              # 護牆板：一條一條橫的
    z = 0.4 + k * 0.3
    for sy in (-1, 1):
        box((HW + 0.02, 0.04, 0.05), (0, sy * (HL / 2 + 0.02), z), m=TRIM)
    for sx in (-1, 1):
        box((0.04, HL + 0.02, 0.05), (sx * (HW / 2 + 0.02), 0, z), m=TRIM)
for sx in (-1, 1):
    for sy in (-1, 1):
        box((0.22, 0.22, HH), (sx * HW / 2, sy * HL / 2, HH / 2), m=TRIM)     # 轉角板
for x in (-3.0, 3.0):
    window(x, -HL / 2 - 0.02, 3.0, -1, shutters=True)                          # 正面的窗
    window(x, HL / 2 + 0.02, 3.0, 1, shutters=True)
window(HW / 2 + 0.02, 0, 3.0, 'x+')
window(-HW / 2 - 0.02, 0, 3.0, 'x-')
box((1.1, 0.12, 2.2), (0, -HL / 2 - 0.06, 1.1), m=WOOD_D)                      # 門
box((1.4, 0.14, 0.14), (0, -HL / 2 - 0.08, 2.27), m=TRIM)
for sx in (-1, 1):
    box((0.14, 0.14, 2.3), (sx * 0.62, -HL / 2 - 0.08, 1.15), m=TRIM)
sphere(0.05, (0.4, -HL / 2 - 0.16, 1.1), 8, 6, m=BAND)                          # 門把
# 前廊：地板很薄（8 公分）——遊戲裡沒有碰撞，走上去腳只陷一點點
box((HW, 2.2, 0.08), (0, -HL / 2 - 1.1, 0.04), m=WOOD)
for x in (-4.8, -1.6, 1.6, 4.8):
    box((0.16, 0.16, 2.7), (x, -HL / 2 - 2.1, 1.35), m=TRIM)                     # 柱子
box((HW + 0.4, 2.6, 0.12), (0, -HL / 2 - 1.2, 2.75), (-0.15, 0, 0), m=SHING)   # 前廊的小屋頂
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
LAYOUT = {'Barn': 0, 'BarnRoof': 0, 'House': 22, 'SiloBody': 38, 'SiloDome': 38,
          'FenceRail': 48, 'FencePost': 48, 'HayBale': 53, 'TreeOak': 60, 'TreePine': 70,
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
