# 環境小物件（2026-10-09 使用者：增加環境物件豐富度）。清單和參考圖是 GPT 給的：docs/image/clutter/（gpt_suggestions.json、ref_*.png）
#   WaterTrough   飲水槽：木板槽＋兩端立柱，槽裡一層暗水。低掩體（約 2.0 × 0.7 × 0.55）
#   Outhouse      戶外廁所：直板小屋、斜屋頂、門上挖月亮。高掩體（1.2 × 1.2 × 2.3）
#   LogPile       柴堆：圓木疊成三角＋旁邊一個樹樁插著斧頭。低掩體（2.0 × 1.0 × 1.0）
#   SignPost      吊牌指示柱：立柱、橫臂、兩條鏈子吊一塊木牌（只有外觀，高 2.5）
#   CollapsedShed 倒塌的小屋：矮牆殘段、斜塌的屋頂板、散落的木板。中掩體（3.5 × 2.5 × 1.4）
#   DinoSkull     半埋的恐龍頭骨：大顱骨、吻、眼窩、上下排牙，下半埋在沙堆裡。掩體（約 3.2 × 1.7 × 1.6）
#   MineCart      礦車＋一小段鐵軌：梯形車斗、四個輪子、軌道和枕木。低掩體（1.2 × 0.8 × 0.9，軌道 3 公尺）
# 原點在地面中央、Blender X 右 Y 前 Z 上，公尺。材質沿用 house.py 的（h_wood、h_post、h_iron…），遊戲裡自動套像素材質（main.gd PIXEL_RULES）。
# 擺放：main.gd 的 _clutter_field（照雜訊的密度撒，CLUTTER 表）
#   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python blender/clutter.py -- --out models/clutters.glb --preview /tmp/c.png
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline, house
from house import *
from house import _parts, _push

house.rnd = random.Random(20261009)
rnd = house.rnd
BONE = [mat('c_bone%d' % i, c, 1.0) for i, c in enumerate(tones((0.42, 0.30, 0.15), 0.08))]   # 舊骨頭：暖骨白偏土黃（太白像塑膠、太灰像石頭）
BONE_D = mat('c_bone_dark', (0.03, 0.02, 0.015), 1.0)   # 眼窩、鼻孔、嘴裡
WATER = mat('c_water', (0.05, 0.10, 0.09), 0.3)   # 暗藍綠（全黑看不出是水）
SAND = mat('c_sand', (0.22, 0.11, 0.045), 1.0)            # 頭骨埋住的土丘：跟地面同色（亮了像水泥底座）
LOG = [mat('h_log%d' % i, c, 0.9) for i, c in enumerate(tones((0.15, 0.095, 0.05), 0.1))]
LOG_END = mat('c_log_end', (0.33, 0.22, 0.12), 0.9)      # 圓木切面：比樹皮亮


def plank(size, loc, rot=(0, 0, 0)):
    return box(size, loc, rot, m=pick(WOOD))


def trough():
    L, W, H = 2.1, 0.7, 0.45   # 長寬比 3:1、矮：短邊看過去才不像箱子
    for sy in (-1, 1):                                    # 兩長邊各三片橫板
        for k in range(3):
            plank((L, 0.05, H / 3 - 0.01), (0, sy * (W / 2 - 0.025), 0.06 + (k + 0.5) * (H - 0.06) / 3))
    for sx in (-1, 1):
        plank((0.05, W - 0.1, H - 0.06), (sx * (L / 2 - 0.025), 0, 0.06 + (H - 0.06) / 2))
        box((0.12, W + 0.1, 0.12), (sx * (L / 2 + 0.02), 0, H - 0.04), m=POST)   # 兩端壓條
        box((0.12, 0.12, 0.06), (sx * (L / 2 - 0.1), 0, 0.03), m=POST)
    plank((L - 0.1, W - 0.1, 0.05), (0, 0, 0.08))           # 槽底
    box((L - 0.1, W - 0.1, 0.02), (0, 0, H - 0.08), m=WATER)
    box((0.1, 0.1, 0.9), (L / 2 - 0.15, 0, 0.45), m=POST)    # 一端的抽水立柱
    box((0.4, 0.06, 0.06), (L / 2 - 0.3, 0, 0.85), (0, 0.3, 0), m=IRON)
    return finish('WaterTrough', bevel=0.0, seg=1)


def outhouse():
    S, H = 1.2, 2.1
    for (ax, sgn) in (('x', -1), ('x', 1), ('y', 1)):     # 三面牆：直條板（前面是門）
        for k in range(6):
            u = -S / 2 + (k + 0.5) * S / 6
            h = H - (0.15 if ax == 'y' else 0.0) - (sgn * u * 0.12 if ax == 'x' else 0.0)
            if ax == 'x':
                plank((0.05, S / 6 - 0.012, H), (sgn * S / 2, u, H / 2))
            else:
                plank((S / 6 - 0.012, 0.05, H - 0.15), (u, S / 2, (H - 0.15) / 2))
    for k in range(5):                                    # 門：直板＋上下橫檔，稍微開一條縫
        plank((S / 5 - 0.015, 0.05, H - 0.2), (-S / 2 + (k + 0.5) * S / 5, -S / 2, (H - 0.2) / 2 + 0.02))
    for z in (0.35, H - 0.45):
        box((S - 0.1, 0.05, 0.1), (0, -S / 2 - 0.04, z), m=TRIM)
    box((0.2, 0.06, 0.2), (0, -S / 2 - 0.05, H - 0.7), m=DARK)   # 門上的月亮洞（暗）
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.1, 0.1, H), (sx * S / 2, sy * S / 2, H / 2), m=POST)
    box((S + 0.2, S + 0.25, 0.08), (0, 0, H + 0.12), (0.12, 0, 0), m=pick(SHING))   # 往後斜的屋頂（出簷短：背靠房子時不插進牆）
    box((S, S, 0.05), (0, 0, 0.03), m=DARK)
    return finish('Outhouse', bevel=0.0, seg=1)


def log_pile():
    """柴堆（照參考圖）：短圓木 3-2-1 疊成三角，前面一個樹樁插著斧頭"""
    r = 0.18
    for n, j in ((3, 0), (2, 1), (1, 2)):
        for k in range(n):
            x = (k - (n - 1) / 2) * r * 2.05
            z = r + j * r * 1.75
            L = 1.1 + rnd.uniform(-0.08, 0.08)
            cyl(r * rnd.uniform(0.92, 1.05), L, (x - 0.35, 0.2 + rnd.uniform(-0.05, 0.05), z), (math.pi / 2, 0, 0), 9, m=pick(LOG))
            for sy in (-1, 1):                             # 兩端切面
                cyl(r * 0.85, 0.02, (x - 0.35, 0.2 + sy * (L / 2 + 0.01), z), (math.pi / 2, 0, 0), 9, m=LOG_END)
    cyl(0.3, 0.5, (0.65, -0.45, 0.25), (0, 0, 0), 9, m=pick(LOG))   # 樹樁：放在前面，不被柴堆擋住
    cyl(0.27, 0.02, (0.65, -0.45, 0.5), (0, 0, 0), 9, m=LOG_END)
    box((0.05, 0.05, 0.75), (0.65, -0.5, 0.82), (0.4, 0, 0), m=POST)   # 斧柄（往後斜）
    box((0.05, 0.28, 0.2), (0.65, -0.38, 0.52), (0.4, 0, 0), m=IRON)   # 斧刃：大一點，砍進樹樁
    return finish('LogPile', bevel=0.0, seg=1)


def sign_post():
    H = 2.5
    box((0.16, 0.16, H), (0, 0, H / 2), m=POST)
    box((1.1, 0.12, 0.14), (0.5, 0, H - 0.2), m=POST)       # 橫臂
    box((0.5, 0.08, 0.08), (0.22, 0, H - 0.45), (0, -0.785, 0), m=POST)   # 斜撐
    for x in (0.55, 0.95):
        for k in range(4):                                 # 鏈子：四節小方塊
            box((0.025, 0.025, 0.06), (x, 0, H - 0.33 - k * 0.07), (0, 0, k * 0.785), m=IRON)
    for k in range(2):                                     # 吊牌：兩片橫板
        plank((0.75, 0.05, 0.17), (0.75, 0, H - 0.72 - k * 0.18))
    box((0.3, 0.3, 0.08), (0, 0, 0.04), m=TRIM)
    return finish('SignPost', bevel=0.0, seg=1)


def collapsed_shed():
    """倒塌的小屋（照參考圖）：後牆和一面側牆還立著（後牆有門洞），屋頂一大片從後牆頂斜塌到地上（約 30 度），
    前面和另一側地上散著亂木板。第一版只剩一排直板，看起來像破圍牆"""
    W, D, H = 3.2, 2.4, 1.8
    for k in range(int(W / 0.2)):                          # 後牆：直板，中間留門洞
        u = -W / 2 + (k + 0.5) * 0.2
        if abs(u) < 0.45:
            continue
        plank((0.18, 0.05, H + rnd.uniform(-0.15, 0.05)), (u, D / 2, H / 2))
    box((1.0, 0.08, 0.12), (0, D / 2, H - 0.1), m=TRIM)   # 門楣
    for k in range(int(D / 0.2)):                          # 左側牆：越往前越矮（斷掉）
        v = -D / 2 + (k + 0.5) * 0.2
        h = max(0.3, H * (0.35 + 0.65 * (v + D / 2) / D) + rnd.uniform(-0.15, 0.05))
        plank((0.05, 0.18, h), (-W / 2, v, h / 2))
    for sx in (-1, 1):
        box((0.12, 0.12, H + 0.1), (sx * W / 2, D / 2, (H + 0.1) / 2), m=POST)
    box((0.12, 0.12, 0.7), (-W / 2, -D / 2, 0.35), m=POST)   # 前面斷掉的柱子
    ang = math.atan2(H, D + 0.8)                           # 屋頂：從後牆頂斜到前面地上
    Ls = math.hypot(H, D + 0.8)
    for k in range(10):
        x = -W / 2 + 0.2 + k * (W - 0.4) / 9
        plank((0.3, Ls, 0.05), (x + rnd.uniform(-0.04, 0.04), D / 2 - (D + 0.8) / 2, H / 2), (ang + rnd.uniform(-0.05, 0.05), rnd.uniform(-0.1, 0.1), rnd.uniform(-0.06, 0.06)))
    box((0.14, Ls + 0.3, 0.14), (0.4, D / 2 - (D + 0.8) / 2, H / 2 + 0.08), (ang, 0.15, 0.1), m=POST)   # 屋脊樑歪著
    for k in range(8):                                     # 地上的亂木板
        a = rnd.uniform(0, math.tau)
        x = rnd.choice((-1, 1)) * rnd.uniform(W * 0.55, W * 0.9) if k % 2 else rnd.uniform(-W * 0.6, W * 0.6)
        y = -D / 2 - rnd.uniform(0.9, 1.5) if k % 2 == 0 else rnd.uniform(-D / 2, D / 2)
        plank((rnd.uniform(0.8, 1.5), 0.17, 0.04), (x, y, 0.03 + k * 0.012), (rnd.uniform(-0.15, 0.15), rnd.uniform(-0.1, 0.1), a))
    return finish('CollapsedShed', bevel=0.0, seg=1)


def frustum(x0, x1, w0, h0, w1, h1, z0, z1, m):
    """沿 X 從 x0 到 x1 的方截錐（兩端各一個長方形：寬 w、高 h，底 z）：做頭骨的稜角塊"""
    bm = bmesh.new()
    vs = []
    for x, w, h, z in ((x0, w0, h0, z0), (x1, w1, h1, z1)):
        vs.append([bm.verts.new((x, sy * w / 2, z + sz * h)) for sy, sz in ((-1, 0), (1, 0), (1, 1), (-1, 1))])
    a, b = vs
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    for i in range(4):
        bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)   # x0 > x1 時繞向會反，統一朝外
    me = bpy.data.meshes.new('fr')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('fr', me)
    bpy.context.scene.collection.objects.link(o)
    _push(o, m)
    return o


def loft(sections, m, n=8):
    """沿 X 疊一圈圈的截面接成一條（每圈 n 點）：sections = [(x, 中心 z, 半寬, 上半高, 下半高)]，截面上半圓、下半扁。
    做頭骨、下顎這種圓弧的長條（方塊拼起來太像建築）"""
    bm = bmesh.new()
    rings = []
    for x, cz, w, hu, hd in sections:
        ring = []
        for k in range(n):
            a = k / n * math.tau
            y, z = math.cos(a) * w, math.sin(a)
            ring.append(bm.verts.new((x, y, cz + z * (hu if z > 0 else hd))))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('loft')
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new('loft', me)
    bpy.context.scene.collection.objects.link(o)
    return _push(o, m)


def dino_skull():
    """半埋的暴龍頭骨（照參考圖）：圓弧的顱頂、往前收窄的圓鈍吻、側面大橢圓眼窩和往前斜的眼前孔、顴骨稜，
    嘴張開（下顎往下 25 度），牙齒中間大兩端小、往後彎。後半埋進跟地面同色的圓緩土丘。
    v1 球＋圓錐（像石頭）、v2 方塊（像廂型車）、v3 直角楔形（像公車、碉堡）"""
    loft([(1.6, 0.72, 0.22, 0.18, 0.15), (1.35, 0.75, 0.45, 0.35, 0.3), (1.0, 0.8, 0.62, 0.62, 0.35), (0.5, 0.75, 0.6, 0.6, 0.35),
          (0.0, 0.62, 0.48, 0.45, 0.28), (-0.6, 0.5, 0.36, 0.32, 0.2), (-1.2, 0.42, 0.26, 0.22, 0.14),
          (-1.65, 0.38, 0.14, 0.12, 0.08)], pick(BONE), 10)                    # 上顎＋顱
    for sy in (-1, 1):
        sphere(0.27, (0.62, sy * 0.47, 0.92), 8, 6, m=BONE_D)               # 眼窩：大橢圓
        _parts[-1].scale = (1.0, 0.45, 1.25)
        sphere(0.2, (-0.15, sy * 0.4, 0.68), 7, 5, m=BONE_D)                # 眼前孔：往前斜的長橢圓
        _parts[-1].scale = (1.9, 0.4, 0.75)
        _parts[-1].rotation_euler = (0, 0.25, 0)
        sphere(0.1, (-1.5, sy * 0.1, 0.48), 6, 4, m=BONE_D)                 # 鼻孔
        loft([(1.0, 0.55, 0.06, 0.07, 0.07), (0.2, 0.5, 0.07, 0.07, 0.07), (-0.4, 0.42, 0.05, 0.05, 0.05)], pick(BONE), 6)   # 顴骨稜
        _parts[-1].location = (0, sy * 0.52, 0)
        for k, sz in enumerate((0.16, 0.22, 0.3, 0.36, 0.36, 0.3, 0.24, 0.18)):   # 上排牙：中間大兩端小、往後彎一點
            x = -1.5 + k * 0.27 + rnd.uniform(-0.04, 0.04)
            cone(0.035 + sz * 0.2, 0.0, sz, (x, sy * (0.13 + k * 0.035), 0.32 - sz / 2), (math.pi + 0.2, 0, 0), 4, m=pick(BONE))
    # 下顎：往下張 25 度，從側面看得到一半
    jaw = loft([(1.05, 0.0, 0.48, 0.14, 0.16), (0.3, 0.0, 0.42, 0.12, 0.13), (-0.5, 0.0, 0.3, 0.1, 0.1), (-1.25, 0.0, 0.16, 0.07, 0.07)], pick(BONE), 8)
    jaw.location = (0, 0, 0.3)
    jaw.rotation_euler = (0, -0.44, 0)
    for sy in (-1, 1):
        for k, sz in enumerate((0.14, 0.22, 0.26, 0.22, 0.14)):           # 下排牙
            x = -0.95 + k * 0.32
            cone(0.03 + sz * 0.2, 0.0, sz, (x, sy * (0.12 + k * 0.03), 0.3 + x * math.sin(0.44) + 0.12 + sz / 2), (0, 0, 0), 4, m=pick(BONE))
    sphere(1.7, (1.35, 0, -0.6), 16, 8, m=SAND)               # 土丘：扁、寬、緩，包住後腦（後腦埋在土裡），嘴巴前面不堆
    _parts[-1].scale = (1.0, 1.0, 0.55)
    return finish('DinoSkull', bevel=0.0, seg=1)


def mine_cart():
    for sy in (-1, 1):                                     # 鐵軌＋枕木：4 公尺，一頭伸進石頭旁的碎石堆
        box((4.0, 0.06, 0.08), (0.4, sy * 0.3, 0.12), m=IRON)
    for k in range(9):
        plank((0.18, 0.95, 0.07), (-1.4 + k * 0.45, 0, 0.04))
    for k in range(9):                                     # 軌道盡頭的碎石堆（礦場的線索）
        sphere(rnd.uniform(0.18, 0.35), (2.1 + rnd.uniform(-0.4, 0.5), rnd.uniform(-0.6, 0.6), 0.05), 6, 4, m=pick(STONE))
    z0 = 0.3
    for sy in (-1, 1):                                     # 四個輪子
        for sx in (-1, 1):
            cyl(0.15, 0.06, (sx * 0.38, sy * 0.3, z0), (math.pi / 2, 0, 0), 10, m=IRON)
    box((0.95, 0.55, 0.06), (0, 0, z0 + 0.12), m=DARK)      # 底
    for sy in (-1, 1):                                     # 兩側：往外斜的板
        plank((1.15, 0.05, 0.5), (0, sy * 0.33, z0 + 0.4), (sy * 0.18, 0, 0))
    for sx in (-1, 1):
        plank((0.05, 0.7, 0.5), (sx * 0.57, 0, z0 + 0.4), (0, -sx * 0.18, 0))
    for sx in (-1, 1):                                     # 鐵角
        for sy in (-1, 1):
            box((0.06, 0.06, 0.55), (sx * 0.56, sy * 0.36, z0 + 0.4), m=IRON)
    box((0.9, 0.5, 0.2), (0, 0, z0 + 0.5), m=pick(STONE))    # 裝著的礦石
    return finish('MineCart', bevel=0.0, seg=1)


def build_all():
    obs = [trough(), outhouse(), log_pile(), sign_post(), collapsed_shed(), dino_skull(), mine_cart()]
    for o in obs:                                          # 旋轉、縮放烘進網格；原點在世界原點（地面中央）
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obs


def preview(obs, path):
    for i, o in enumerate(obs):
        o.location = ((i - 3) * 4.0, 0, 0)
    pipeline.scene_preview(obs, path)
    for o in obs:
        o.location = (0, 0, 0)


if __name__ == '__main__':
    pipeline.run(build_all, preview, budget=3000)
