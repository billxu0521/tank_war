"""精修暴龍（docs/image/dinosaur.png）：一整張連續的皮，之後包在精細骨架上做蒙皮。

座標一律用 Godot 順序寫 (x, y上, z後)，進 Blender 前才用 B() 轉。
比例從參考圖側面量（px → 遊戲單位，K = 8.8 / 914）：髖關節在 z=0，snout 在 z≈-3.2，尾尖 z≈+5.6。
boss 場景把恐龍放大 1.5 倍，所以全長 8.8 → 13 公尺，跟參考圖的 12~14 公尺一致。

做法：身體、腿、手用斷面 loft 成管子 → 體素重建（voxel remesh）合成一張皮 → 減面成不規則三角面（參考圖的多面體質感）
→ 面依朝向和位置上色 → 棘刺、牙、爪、眼睛另外放上去（射線打到皮上找位置）。
背景跑一輪：tools/model_iter.sh trex_hd <版號>
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector
from mathutils.bvhtree import BVHTree
BASE = globals().get('BASE') or os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import pipeline
exec(open(BASE + '/common.py').read())

K = 8.8 / 914          # 參考圖側面 1 px = K 單位
CHISEL = 0.065         # 刀削感：頂點沿法線亂推的幅度（單位）。0 = 圓滑。使用者要銳利一點（第 38 版 0.040）
HIP_PX, GROUND_PX = 650, 432
# 腿加長（docs/企劃/尼諾拉.md 骨架規格）：參考設定圖肩高 3.5～4.5 公尺，原本髖關節只有 2.6 公尺。
# 腳以上整隻（軀幹、頭、尾巴、手）往上抬 LEG_EXTRA，腿從腳掌往上拉長補滿。遊戲裡放大 1.5 倍：0.75 → 髖約 3.7 公尺
LEG_EXTRA = 0.0   # 2026-10-03 撤回：設定圖的「肩高 3.5～4.5 公尺」是背頂，不是髖；原本比例（髖 ÷ 全長 0.18）就對得上設定圖（0.19）

def B(g):              # Godot(x, y上, z後) -> Blender(x, y前, z上)
    return Vector((g[0], -g[2], g[1]))

def px(x, y):          # 參考圖側面像素 -> Godot (z, y)；腿加長後腳以上整隻往上抬
    return (x - HIP_PX) * K, (GROUND_PX - y) * K + LEG_EXTRA

# ---- 材質（線性值）----
wipe()   # 要在建材質之前清：wipe 會刪掉沒人用的材質
OLIVE = mat('d_olive', (0.195, 0.159, 0.047), 0.9)   # #7A6F3E
MOSS  = mat('d_moss',  (0.160, 0.135, 0.040), 0.9)
TAN   = mat('d_tan',   (0.392, 0.254, 0.091), 0.9)   # #A88A55 黃褐亮面
TAILD = mat('d_taild', (0.332, 0.235, 0.098), 0.9)   # #9C8558 尾巴下緣後段
TAILU = mat('d_tailu', (0.479, 0.323, 0.162), 0.9)   # #B89A70 尾巴下緣，髖後 1.5 之後漸變
BELLY = mat('d_belly', (0.640, 0.500, 0.320), 0.9)
SPLIT = mat('d_spike_lit', (0.254, 0.102, 0.030), 0.85)   # #8A5A30 棘刺受光面
SPIKE = mat('d_spike', (0.250, 0.140, 0.050), 0.85)
RIDGE = mat('d_ridge', (0.102, 0.042, 0.016), 0.85)   # #5A3A22 深咖啡
BONE  = mat('d_bone',  (0.640, 0.570, 0.420), 0.6)
CLAW  = mat('d_claw',  (0.090, 0.075, 0.060), 0.5)
MOUTH = mat('d_mouth', (0.300, 0.050, 0.045), 0.7)
EYE   = mat('d_eye',   (0.850, 0.560, 0.120), 0.25)
PUPIL = mat('d_pupil', (0.020, 0.015, 0.015), 0.25)
MATS = [OLIVE, MOSS, TAN, TAILU, TAILD, BELLY, SPIKE, SPLIT, RIDGE, BONE, CLAW, MOUTH, EYE, PUPIL]
MI = {m: i for i, m in enumerate(MATS)}

# ---- 軀幹斷面：(參考圖 x, 背線 y, 腹線 y, 半寬單位, 截面形狀指數) ----
# 頭只做上半部（上顎、頭殼），下顎另外一塊，張嘴才乾淨
TRUNK = [
    # 2026-10-03 照 NIBA 設定圖：方塊頭——閉嘴時頭高約頭長的 0.45（以前 0.3，像鱷魚），吻端鈍、方，眉骨隆起，頰部寬
    (318, 100, 136, 0.13, 2.8),     # 吻部前端：鈍、方
    (324,  91, 141, 0.21, 2.7),
    (345,  85, 147, 0.28, 2.6),
    (372,  81, 152, 0.33, 2.5),
    (398,  68, 158, 0.38, 2.5),     # 眉骨：眼睛正上方隆起
    (428,  78, 168, 0.46, 2.5),     # 頰部（咬合肌）寬
    (452,  88, 222, 0.50, 2.7),     # 脖子粗（NIBA 頭和身體之間沒有腰身），喉嚨往下垂
    (472,  94, 250, 0.56, 2.7),     # 脖子要比頭細
    # 2026-10-03 照 NIBA 設定圖（docs/image/ninola/設定圖_調整後設計.jpg 側面，換算到這張表的像素座標）重量：
    # 背在髖上面比較高、比較平（以前太早往尾巴斜下去），肚子深一截，尾巴後段往下垂（尾尖低 70 像素）
    # 寬：上視最寬處約全長 20%（以前 12%，像梭子），胸到髖是肥的橄欖形，斷面方一點（肩膀、腰側飽滿）
    # 胸口（前肢那一段）的腹線往下接到肚子；尾巴中後段粗一點，最後 10% 才收尖
    # 第 3 輪後：斷面指數 3.0 太方，上側邊角在側面變成一條稜、從胸到髖像背了一塊鞍；改回 2.5、加寬也放緩
    # 使用者（第 38 版）：有點太胖——胸到尾根的寬度約 ×0.85；第 40 版再瘦一點：再 ×0.88
    (500, 107, 300, 0.49, 2.5),
    (540, 113, 326, 0.57, 2.5),
    (580, 124, 330, 0.62, 2.5),
    (620, 137, 330, 0.62, 2.5),     # 髖部窄一點，大腿才凸得出身體輪廓（審查第 2 輪）
    (660, 151, 328, 0.60, 2.5),
    (700, 163, 322, 0.58, 2.5),
    (760, 180, 302, 0.70, 2.8),     # 尾根很粗（設定圖「非常粗壯的尾根」，背面看填滿兩條大腿之間）     # 大腿後面腹線往上收（以前一路平拉到尾巴中段，像蠑螈）
    (830, 202, 298, 0.62, 2.6),     # 背線平順往下（以前 760→830 一下掉 34 像素，尾巴根部看得到一個台階）
    (900, 224, 318, 0.48, 2.5),
    (970, 242, 344, 0.48, 2.4),
    (1040, 258, 336, 0.38, 2.3),
    (1110, 270, 322, 0.27, 2.2),
    (1170, 286, 312, 0.15, 2.2),
    (1210, 304, 320, 0.07, 2.2),
    (1236, 323, 325, 0.01, 2.0),
]
# 下顎（閉嘴）：上緣貼著上顎下緣，後端是顎關節
JAW = [
    (346, 141, 154, 0.12, 2.6),     # 下巴往前收、比上顎短一截；跟著頭變高變寬（NIBA 下顎很厚，淺色區往下垂接脖子）
    (352, 142, 171, 0.27, 3.0),
    (362, 145, 185, 0.32, 2.8),
    (396, 152, 207, 0.39, 2.6),
    (430, 162, 229, 0.45, 2.5),
    (458, 172, 235, 0.46, 2.4),
]
# 頭的大小（使用者：頭小一些）。以脖子接頭處 (x=470, y=140) 為中心縮放頭的斷面、下顎、眼睛、牙
HEAD_K = 1.15   # NIBA 的頭比舊參考圖大：頭高約全長 15%、正面頭寬約身體寬 60%（審查第 2 輪：0.95 時頭像小頭針）
HEAD_X, HEAD_Y = 470, 140
def hx(x):
    return HEAD_X - (HEAD_X - x) * HEAD_K if x < HEAD_X else x
def hy(y):
    return HEAD_Y + (y - HEAD_Y) * HEAD_K
def _head_row(r):
    x, top, bot, hw, n = r
    if x >= HEAD_X:
        return r
    return (hx(x), hy(top), hy(bot), hw * HEAD_K, n)
TRUNK = [_head_row(r) for r in TRUNK]
JAW = [_head_row(r) for r in JAW]
JAW_HINGE = px(hx(452), hy(168))
def head_g(gz, gy):
    """Godot (z, y) 的頭部座標跟著縮"""
    zn, yn = px(HEAD_X, HEAD_Y)
    return zn + (gz - zn) * HEAD_K, yn + (gy - yn) * HEAD_K

def smoothstep(e0, e1, v):
    t = max(0.0, min(1.0, (v - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)

def section(c, a, b, n, ring, flat=0.0, keel=False):
    """以 c 為中心的超橢圓斷面（Godot 座標），a 半寬、b 半高；flat > 0 把下半部壓平（肚子）"""
    pts = []
    for i in range(ring):
        t = 2 * math.pi * i / ring
        ct, st = math.cos(t), math.sin(t)
        if keel and st < 0:
            # 軀幹下半部：指數 2（圓）、越往下越窄，正面看最寬在肩和大腿那帶、往下收成 V 字腹甲（審查第 2 輪：以前最寬在肚子底，像水袋）
            x = a * math.copysign(abs(ct), ct) * (1.0 - 0.22 * smoothstep(0.0, 1.0, -st))   # 第 3 輪：從 0.4 才開始收、收到 0.7 會在側面折出一條硬線
            y = b * st
        else:
            x = a * math.copysign(abs(ct) ** (2 / n), ct)
            y = b * math.copysign(abs(st) ** (2 / n), st)
        if y < 0 and flat:
            y *= 1 - flat
        pts.append(Vector((c[0] + x, c[1] + y, c[2])))
    return pts

def loft_rings(rings, name, m=OLIVE):
    """一串斷面（每圈點數相同）接成封閉管子，兩頭補蓋"""
    bm = bmesh.new()
    vs = [[bm.verts.new(B(p)) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(list(reversed(vs[0])))
    bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o

def loft_table(table, name, ring=20, flat=0.0):
    rings = []
    for x, top, bot, hw, n in table:
        z, _ = px(x, 0)
        yt, yb = px(0, top)[1], px(0, bot)[1]
        rings.append(section((0, (yt + yb) / 2, z), hw, (yt - yb) / 2, n, ring, flat, keel=500 <= x <= 830))
    return loft_table_smooth(rings, name)

def loft_table_smooth(rings, name, sub=3):
    """斷面之間用 Catmull-Rom 補幾圈，輪廓才不會一節一節折"""
    out = []
    for i in range(len(rings) - 1):
        p0 = rings[max(i - 1, 0)]; p1 = rings[i]; p2 = rings[i + 1]; p3 = rings[min(i + 2, len(rings) - 1)]
        for s in range(sub):
            t = s / sub
            t2, t3 = t * t, t * t * t
            out.append([0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                        for a, b, c, d in zip(p0, p1, p2, p3)])
    out.append(rings[-1])
    return loft_rings(out, name)

# 腿的粗細（2026-10-03 照 NIBA 設定圖：重型暴龍——大腿是側面最搶眼的大橢圓，小腿、腳踝像柱子；以前像鳥腿）
# (左右, 前後) 兩個方向分開：大腿前後也乘 1.6 的話會從脖子後面一路長到髖（全長 31%，設定圖約 17%），側面像背了一塊鞍
LIMB_K = {'thigh': (0.75, 1.25), 'shin': (1.7, 1.7), 'meta': (1.6, 1.6), 'toe': (1.3, 1.3), 'dew': (1.2, 1.2)}

def limb(points, name, ring=14):
    """四肢：沿一串 (位置, 半徑) 做圓管，半徑可以是 (左右, 上下)"""
    rings = []
    u = None
    for i, (p, r) in enumerate(points):
        p = Vector(p)
        d = (Vector(points[min(i + 1, len(points) - 1)][0]) - Vector(points[max(i - 1, 0)][0])).normalized()
        # 斷面方向沿路平行移動（前一圈的 u 投影到這一圈的平面），轉彎時才不會整圈翻面、把管子扭爛
        if u is None:
            u = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
        u = (u - d * u.dot(d)).normalized()
        v = d.cross(u).normalized()
        rx, ry = (r, r) if not isinstance(r, tuple) else r
        kx, ky = LIMB_K.get(name, (1.0, 1.0))
        rx *= kx
        ry *= ky
        rings.append([p + u * (rx * math.cos(2 * math.pi * k / ring)) + v * (ry * math.sin(2 * math.pi * k / ring))
                      for k in range(ring)])
    return loft_table_smooth(rings, name, sub=2)

# ---- 關節（Godot 座標，左邊 x>0；右邊鏡像）----
BALL  = Vector((0.68, 0.10, -0.10))   # 使用者（第 41 版）：正面收窄——兩腳站近一點（以前 0.82）
# 腿：舊比例的關節從腳掌往上等比拉長，髖抬到原本高度 + LEG_EXTRA（膝、踝的角度不變，只是變長）
_LEG_K = (1.62 + LEG_EXTRA - BALL.y) / (1.62 - BALL.y)
def _leg(v):
    return BALL + (v - BALL) * _LEG_K
HIP   = Vector((0.54, 1.62 + LEG_EXTRA, 0.02))
KNEE  = _leg(Vector((0.62, 0.98, -0.42)))
ANKLE = _leg(Vector((0.66, 0.40, 0.18)))
_UP = Vector((0, LEG_EXTRA, 0))
# 胸口加寬之後（斷面半寬 0.70～0.84）手往外移，不然整隻手埋進胸裡看不到
SHOULDER = Vector((0.57, 1.90, -1.30)) + _UP
ELBOW    = Vector((0.68, 1.60, -1.42)) + _UP
WRIST    = Vector((0.62, 1.58, -1.72)) + _UP   # 手往前下垂、兩指收在胸前（審查第 2 輪：往外戳像鰭）
TOES = ((-26, 0.62), (0, 0.78), (26, 0.62))   # (張開角度, 長度)：三根前趾（第 4 輪：設定圖腳掌大、三趾張開）

def mirror(v, s):
    return Vector((v.x * s, v.y, v.z))

def legs():
    out = []
    for s in (1, -1):
        H, Kn, A, F = (mirror(v, s) for v in (HIP, KNEE, ANKLE, BALL))
        # 大腿是一大塊肌肉：從骨盆上緣長出來，膝蓋收細
        # 大腿肉往外、往上鼓（審查第 2 輪：大腿被身體吃掉看不出來）。關節位置不動，只動外形
        # 第 4 輪：大腿中心在全長約 41%（關節不動，肉往後 0.26）、往外只多 0.10（0.18 背面像鞍袋）、往上 0.20
        TO = Vector((-0.12 * s, 0.20, 0.26))   # 第 39 版：身體變瘦後大腿往外 0.10 太凸，正面看比身體還寬
        # 上端橢圓收頭（前後 1 : 上下 1.3），頂端只到髖上面一點：設定圖大腿頂約在背高的 65～70%，以前頂到背線像一塊鞍
        out.append(limb([(H + TO + Vector((-0.22 * s, 0.10, 0.20)), (0.26, 0.34)),   # 上端往身體裡多埋一點：交界是凹弧，不是一圈邊
                         (H + TO + Vector((0, 0.0, -0.18)), (0.45, 0.86)),
                         ((H * 0.5 + Kn * 0.5) + TO * 0.5 + Vector((0, 0, -0.16)), (0.43, 0.72)),
                         (Kn + Vector((0, 0.14, 0.04)), (0.34, 0.34)),
                         (Kn, (0.29, 0.29))], 'thigh'))
        # 小腿：後面有小腿肚，往踝收細
        out.append(limb([(Kn + Vector((0, 0.06, 0.0)), (0.34, 0.33)),
                         (Kn * 0.7 + A * 0.3 + Vector((0, 0, 0.08)), (0.34, 0.36)),
                         (Kn * 0.3 + A * 0.7, (0.25, 0.26)),
                         (A, (0.19, 0.19))], 'shin'))
        out.append(limb([(A + Vector((0, 0.04, 0.02)), (0.20, 0.20)),
                         (A * 0.5 + F * 0.5, (0.17, 0.16)),
                         (F + Vector((0, 0.03, 0)), (0.21, 0.13))], 'meta'))
        # 三根前趾 + 後趾
        for ang, L in TOES:
            a = math.radians(ang) * s
            d = Vector((math.sin(a) * 0.9 + 0.12 * s, 0, -math.cos(a)))
            tip = F + d * L + Vector((0, -0.04, 0))
            out.append(limb([(F, (0.14, 0.11)), (F + d * L * 0.55 + Vector((0, -0.01, 0)), (0.12, 0.09)),
                             (tip, (0.085, 0.07))], 'toe', ring=10))
        out.append(limb([(F + Vector((0, 0.07, 0.12)), (0.08, 0.07)), (F + Vector((-0.04 * s, 0.02, 0.32)), (0.05, 0.045))], 'dew', ring=8))
    return out

def arms():
    out = []
    for s in (1, -1):
        S_, E, W = (mirror(v, s) for v in (SHOULDER, ELBOW, WRIST))
        out.append(limb([(S_ + Vector((-0.10 * s, 0.10, 0.05)), (0.20, 0.20)), (S_, (0.17, 0.18)),
                         (E, (0.13, 0.13)), (W, (0.10, 0.10)), (W + Vector((0, -0.05, -0.10)), (0.10, 0.08))], 'arm', ring=10))
        for base, tip in fingers(s):     # 兩根手指往前下彎，爪子在 add_claws 接在指尖
            out.append(limb([(base, (0.045, 0.045)), (base * 0.5 + tip * 0.5 + Vector((0, 0, -0.02)), (0.04, 0.04)),
                             (tip, (0.03, 0.03))], 'finger', ring=8))
    return out

def fingers(s):
    """(指根, 指尖)，Godot 座標"""
    W = mirror(WRIST, s)
    hand = W + Vector((0, -0.05, -0.10))
    # 兩指（設定圖：暴龍類二指前肢）
    return [(hand + Vector((dx * s, 0, -0.02)), hand + Vector((dx * s * 1.6, -0.09, -0.07))) for dx in (-0.04, 0.04)]

def chisel(o, amp, seed):
    """刀削感：每個頂點沿法線隨機推進推出（±amp），相鄰三角面的折角變大，稜線才利。
    同一個位置推的量固定（用座標雜湊），重跑結果一樣"""
    me = o.data
    me.calc_normals_split() if hasattr(me, 'calc_normals_split') else None
    from mathutils import noise
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in me.vertices:
        # 低頻雜訊（尺度約 0.6）：相鄰頂點往同一邊推，幾片面合成一塊大切面，折角只出現在轉折處
        h = noise.noise(v.co / 0.6 + off)
        j = _hash(round(v.co.x * 50), round(v.co.y * 50), round(v.co.z * 50), seed) * 2 - 1   # 每頂點一點點：相鄰面之間才有折角
        k = 0.4 if -v.co.y < -1.9 else 1.0          # 頭（Godot z < -1.9）削淺一點
        v.co += v.normal * (h * amp + j * amp * 0.12) * k

def merge_skin(parts, name, voxel, faces):
    """幾塊管子合成一張皮：體素重建 → 減面 → 三角化。減面會留下大小不一的三角面，就是參考圖的多面體質感"""
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    md = o.modifiers.new('rm', 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier='rm')
    # QuadriFlow 重新長一層大小均勻的四邊形（減面會留下又細又長的碎片，刀削感出不來）。
    # 體素重建的結果要先合併重複點、統一法線，不然 QuadriFlow 會說「不是封閉網格」直接取消
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data); bm.free()
    # 2026-10-03 不用 QuadriFlow 了：身體照 NIBA 加粗後，它會把細的尾巴壓成一片緞帶（量過：體素重建後尾巴好好的，
    # QuadriFlow 後尾巴中段高度 0；換三個亂數種子都壞在不同地方）。改用 Decimate 減面
    r = {'CANCELLED'}
    o = bpy.context.object
    if 'FINISHED' not in r:
        print('quadriflow failed, fallback decimate')
        md = o.modifiers.new('dc', 'DECIMATE'); md.ratio = min(1.0, faces / max(1, 2 * len(o.data.polygons)))
        bpy.ops.object.modifier_apply(modifier='dc')
    random_triangulate(o)
    # 美化三角面（細長的薄片翻成接近正三角形）＋頂點沿表面亂推一點，打散 loft 一圈圈的環（第 3 輪：有「電腦減面」的味道）
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.beautify_fill(bm, faces=bm.faces, edges=bm.edges)
    rnd = random.Random(11)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if not v.link_edges:
            continue
        L = sum(e.calc_length() for e in v.link_edges) / len(v.link_edges)
        jt = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * L * 0.18
        v.co += jt - v.normal * jt.dot(v.normal)   # 只沿表面推，不改外形
    bm.to_mesh(o.data); bm.free()
    return o

def random_triangulate(o):
    """四邊形隨機挑一條對角線切成兩個三角形：對角線方向不一致，稜線才不會排成一列一列"""
    bm = bmesh.new(); bm.from_mesh(o.data)
    quads = [f for f in bm.faces if len(f.verts) == 4]
    for f in quads:
        v = f.verts[:]
        c = f.calc_center_median()
        if _hash(round(c.x * 97), round(c.y * 97), round(c.z * 97)) > 0.5:
            v = v[1:] + v[:1]
        bmesh.ops.connect_verts(bm, verts=[v[0], v[2]])
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(o.data); bm.free()

# ---- 上色：每個面依朝向、位置挑顏色，花斑用粗格子雜湊，色塊才成片 ----
def _hash(*v):
    h = 0
    for x in v:
        h = (h * 1000003) ^ (int(x) & 0xffffffff)
    return (h * 2654435761 & 0xffffffff) / 0xffffffff

def paint_skin(o, rnd):
    me = o.data
    me.materials.clear()
    for m in MATS:
        me.materials.append(m)
    hz, hy = JAW_HINGE
    for f in me.polygons:
        c = f.center; n = f.normal          # Blender 座標：y 前、z 上
        gz, gy, gx = -c.y, c.z, c.x
        under = n.z < -0.45
        vw = min(0.45, 0.44 * max(0.0, gy - 1.0))                                    # V 字半寬：離地 1.0 收成尖、1.4 處 0.175、上緣 0.45
        if under and gz < 0.0 and n.y > 0.3:
            under = abs(gx) < vw                                                         # 正面看得到的腹面也照 V 字，下緣才不會是平的
        chest = gz < -0.3 and n.y > 0.12 and n.z < 0.4 and abs(gx) < vw and gy < 2.8    # 胸口、喉嚨（參考圖正面的米色 V）
        tail_under = gz > 0.6 and n.z < -0.35
        if gz < hz - 0.02 and n.z < -0.55 and gy > hy - 0.05 and abs(gx) < 0.7 * _trunk_hw(gz):   # 上顎下面：嘴裡（外緣留皮色）
            f.material_index = MI[MOUTH]
        elif (under or chest or tail_under) and not (n.y < -0.2 and n.z > -0.6):   # 朝後的面不上米白（背面看兩腿之間）
            # 尾巴下側：米白只到髖後 0.3，0.3→1.0 漸變 #B89A70，1.0→尾尖再漸變 #9C8558（背面看得到尾巴下側，不能亮）
            r = rnd.random()
            if gz < 0.3:
                f.material_index = MI[BELLY] if r < 0.88 else MI[TAN]
            elif gz < 1.0:
                f.material_index = MI[TAILU] if r < (gz - 0.3) / 0.7 else MI[BELLY]
            else:
                td = min(1.0, (gz - 1.0) / 1.5) + (0.3 if n.y < -0.3 else 0.0)        # 朝後的面再深一點
                f.material_index = MI[TAILD] if r < td else MI[TAILU]
        elif n.z < -0.05 and n.y > -0.2:                       # 往下斜的面（朝後的不算）：米白 → 棕褐 → 橄欖 漸層（垂直的面不混米白）
            t = (-0.05 - n.z) / 0.40                             # 0 上緣 … 1 接腹面
            r = rnd.random()
            f.material_index = MI[BELLY] if r < t * 0.45 else (MI[TAN] if r < 0.35 + t * 0.4 else MI[MOSS])
        else:
            from mathutils import noise
            nv = noise.noise(Vector((gx, gy, gz)) / 1.2)               # 低頻：色塊成片、大塊，不是一片一片亂跳
            r = rnd.random()
            if nv > 0.25:
                f.material_index = MI[TAN] if r > 0.15 else MI[OLIVE]
            else:
                f.material_index = MI[OLIVE] if nv > -0.25 or r > 0.6 else MI[MOSS]

def paint_jaw(o, rnd):
    me = o.data
    me.materials.clear()
    for m in MATS:
        me.materials.append(m)
    for f in me.polygons:
        n = f.normal
        if n.z > 0.45 and abs(f.center.x) < 0.7 * _jaw_hw(-f.center.y):
            f.material_index = MI[MOUTH]           # 舌頭、口腔底
        else:
            f.material_index = MI[BELLY] if rnd.random() > 0.2 else MI[TAN]   # 參考圖下顎整塊淺色

# ---- 小零件（棘刺、牙、爪）全部塞進一個 bmesh，材質用 index ----
class Bits:
    def __init__(self):
        self.bm = bmesh.new()

    def cone(self, base, d, r, h, m, sides=5, twist=0.0):
        """base、d 是 Blender 座標；d 是方向（會正規化）"""
        d = Vector(d).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, 1, 0))
        u = d.cross(up).normalized(); v = u.cross(d).normalized()
        ring = [self.bm.verts.new(base + (u * math.cos(twist + 2 * math.pi * i / sides) +
                                          v * math.sin(twist + 2 * math.pi * i / sides)) * r) for i in range(sides)]
        tip = self.bm.verts.new(base + d * h)
        for i in range(sides):
            f = self.bm.faces.new((ring[i], ring[(i + 1) % sides], tip)); f.material_index = MI[m]
            if m in (SPIKE, RIDGE):                       # 棘刺雙色：朝上、朝前（Blender +z、+y）的面是受光的橘褐
                nf = f.normal if f.normal.length > 0 else Vector((0, 0, 1))
                f.normal_update()
                if f.normal.z + f.normal.y * 0.6 > 0.35:
                    f.material_index = MI[SPLIT]
        f = self.bm.faces.new(list(reversed(ring))); f.material_index = MI[m]

    def sphere(self, c, r, m, seg=10, ring=7):
        g = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=ring, radius=r)
        for v in g['verts']:
            v.co += c
        for f in {f for v in g['verts'] for f in v.link_faces}:
            f.material_index = MI[m]

    def obj(self, name):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me); self.bm.free()
        for m in MATS:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o

def surface(bvh, origin, target):
    """從 origin 往 target 打射線，回傳皮上的點和法線（Blender 座標）"""
    d = (target - origin)
    hit = bvh.ray_cast(origin, d.normalized(), d.length)
    return (hit[0], hit[1]) if hit[0] is not None else (None, None)

def spine_center(gz):
    """軀幹在 gz 這個位置的中心線 (Godot y, 半高)：從 TRUNK 表內插"""
    zs = [px(r[0], 0)[0] for r in TRUNK]
    for i in range(len(TRUNK) - 1):
        if zs[i] <= gz <= zs[i + 1]:
            t = (gz - zs[i]) / (zs[i + 1] - zs[i])
            a, b = TRUNK[i], TRUNK[i + 1]
            top = a[1] + (b[1] - a[1]) * t; bot = a[2] + (b[2] - a[2]) * t
            yt, yb = px(0, top)[1], px(0, bot)[1]
            return (yt + yb) / 2, (yt - yb) / 2
    return None

def spike_height(gz):
    """背棘高度（Godot 單位）沿身體的分布：肩上最高，頭和尾巴尖小"""
    # NIBA 設定圖：小而密，肩到髖最高約全長 3%、頭頂約 2%、尾尖約 0.8%（全長 8.8 單位）
    keys = [(-3.0, 0.18), (-2.0, 0.22), (-1.4, 0.26), (-0.6, 0.31), (0.6, 0.31), (1.5, 0.25),
            (3.0, 0.17), (4.5, 0.11), (5.3, 0.08), (5.6, 0.0)]   # 第 3 輪：正中一排 ×1.2，肩到髖約全長 3.5%
    for (z0, h0), (z1, h1) in zip(keys, keys[1:]):
        if z0 <= gz <= z1:
            return h0 + (h1 - h0) * (gz - z0) / (z1 - z0)
    return 0.0

def add_spikes(bits, skin, rnd):
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(skin, dg)
    back = Vector((0, -1, 0))                            # 往後（Blender -Y）
    # 每一排：(繞身體的角度, 高度倍數, 間距, 起點 z, 終點 z)
    # 中間一排大的（背面看是一條深色脊）、兩側越外面越稀越矮，只是零星的突起
    # 俐落（使用者）：主排從頸後 0.6 開始，頭和背刺之間留一段乾淨的脖子；側排只留肩到髖、每側約 6 根
    # NIBA 設定圖：正中一排約 55 根（間距約全長 1.8%）從眉骨排到尾尖；兩側各一排從脖子根到全長 75%，矮一半、錯開半個間距
    rows = [(0, 1.0, 0.16, -2.9, 5.4),
            (24, 0.55, 0.30, -1.30, 3.4), (-24, 0.55, 0.30, -1.15, 3.4)]
    for ang, mul, step, z0, z1 in rows:
        z = z0 + rnd.uniform(0, step * 0.3)
        while z < z1:
            sc = spine_center(z)
            if sc:
                cy, _ = sc
                a = math.radians(ang + rnd.uniform(-5, 5))
                center = B((0, cy, z))
                d = Vector((math.sin(a), 0, math.cos(a)))
                p, n = surface(bvh, center + d * 3.0, center)
                if p is not None:
                    h = spike_height(z) * mul * rnd.uniform(0.8, 1.2)
                    if h > 0.025:
                        dirv = (n * 0.87 + back * 0.5).normalized()   # 往後倒約 30 度
                        # 寬底三角板（底長約等於高度），不是細針（第 3 輪：底寬只有高度 30%，遠看像毛）
                        bits.cone(p - n * 0.03, dirv, min(h * 0.5, step * 0.45), h, RIDGE if ang == 0 else SPIKE, sides=4,
                                  twist=rnd.uniform(0, 6.28))
            z += step * rnd.uniform(0.75, 1.25)
    # 頭的兩側、後腦：一圈短角（正面看得到的那排）
    for s in (1, -1):
        for gz, gy, gx, h in ((-2.24, 3.40, 0.06, 0.28), (-2.06, 3.28, 0.06, 0.26)):   # 都在頭骨範圍內（頭關節 z=-2.02 以前），權重才會跟著頭   # 眼後一根、後腦一根，靠中線（離太開正面看像貓耳）
            gz, gy = head_g(gz, gy)
            p, n = surface(bvh, B((gx * s, gy + 3, gz)), B((gx * s, gy - 1, gz)))      # 從正上方打下來
            if p is not None:
                bits.cone(p - n * 0.02, (n * 0.15 + back * 0.82 + Vector((0, 0, 0.57))).normalized(),   # 往後倒約 55 度
                          h * 0.45, h, SPIKE, 4, rnd.uniform(0, 6))

def add_head_bits(bits, skin, jaw, rnd):
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(skin, dg)
    for s in (1, -1):
        # 眼睛：在眉脊下面，從側面打進去找皮
        ez, ey = px(hx(392), hy(101))
        p, n = surface(bvh, B((s * 2, ey, ez)), B((0, ey, ez)))
        if p is not None:
            bits.sphere(p - n * 0.025, 0.055, EYE, 6, 4)
            bits.sphere(p + n * 0.02, 0.026, PUPIL, 4, 3)
            # 眉脊：眼睛上方一道往後的稜
            for k, (dz, h) in enumerate(((0.06, 0.12),)):   # 眉骨一根，往後上方 45 度、不往外橫伸
                q, m = surface(bvh, B((s * 2, ey + 0.10, ez + dz)), B((0, ey + 0.10, ez + dz)))
                if q is not None:
                    bits.cone(q - m * 0.03, (m * 0.25 + Vector((0, -1, 1))).normalized(), h * 0.5, h, SPIKE, 4)
        # 上排牙：沿上顎外緣往下
        for i in range(6):
            t = i / 5
            x = hx(326 + t * (432 - 326))
            gz = px(x, 0)[0]
            ylow = _jaw_top(gz)                        # 唇線（閉嘴時下顎上緣）：上排牙從這裡長出來
            hw = min(_trunk_hw(gz), _jaw_hw(gz)) * 0.92   # 減面後唇線變鈍，牙往外一點才不會埋進皮裡
            h = 0.17 if i < 2 else 0.14 - 0.02 * t     # 前兩對稍長（其他牙的 1.3 倍內），太長像劍齒虎
            bits.cone(B((s * hw, ylow + 0.05, gz)), (0, 0.05, -1), h * 0.30, h + 0.02, BONE, 3)
        # 下排牙：沿下顎上緣往上（在上排內側）
        for i in range(5):
            t = i / 4
            x = hx(346 + t * (428 - 346))
            gz = px(x, 0)[0]
            top = _jaw_top(gz)
            hw = _jaw_hw(gz) * 0.70
            h = 0.19 if i < 2 else 0.14 - 0.02 * t
            bits.cone(B((s * hw, top - 0.02, gz)), (0, 0.05, 1), h * 0.30, h, BONE, 3)

def _interp(table, gz, col):
    zs = [px(r[0], 0)[0] for r in table]
    for i in range(len(table) - 1):
        if zs[i] <= gz <= zs[i + 1]:
            t = (gz - zs[i]) / (zs[i + 1] - zs[i])
            return table[i][col] + (table[i + 1][col] - table[i][col]) * t
    return table[0][col] if gz < zs[0] else table[-1][col]

def _trunk_hw(gz):
    return _interp(TRUNK, gz, 3)

def _jaw_hw(gz):
    return _interp(JAW, gz, 3)

def _jaw_top(gz):
    return px(0, _interp(JAW, gz, 1))[1]

def add_claws(bits, rnd):
    for s in (1, -1):
        F = mirror(BALL, s)
        for ang, L in TOES:
            a = math.radians(ang) * s
            d = Vector((math.sin(a) * 0.9 + 0.12 * s, 0, -math.cos(a)))
            tip = F + d * L + Vector((0, -0.04, 0))
            bits.cone(B(tip - d * 0.05), B(d) + Vector((0, 0, -0.55)), 0.085, 0.30, CLAW, 4)
        bits.cone(B(F + Vector((-0.04 * s, 0.02, 0.30))), Vector((0, -0.6, -0.8)), 0.045, 0.15, CLAW, 4)
        # 手：兩根指爪，往下彎
        for base, tip in fingers(s):
            d = (tip - base).normalized()
            d = (d + Vector((0, -0.6, 0))).normalized()          # 爪子比手指再往下勾一點
            bits.cone(B(tip - d * 0.02), B(d) - B((0, 0, 0)), 0.032, 0.16, CLAW, 4)

EDGE_LINE = 0.022   # 稜線粗細（重心座標，0 = 不畫）；參考圖每塊面之間有一條暗線
EDGE_DARK = 0.78    # 稜線的亮度倍數

def bary_attr(o):
    """每個三角面的三個角標 (1,0,0)/(0,1,0)/(0,0,1)：著色器用最小分量判斷離邊多近，畫面與面之間的暗線。
    存成面角屬性，glTF 匯出成頂點色 COLOR_0（平面著色本來就每面各自一份頂點），Godot 那邊同一招"""
    me = o.data
    at = me.color_attributes.new('bary', 'FLOAT_COLOR', 'CORNER')
    cols = []
    for poly in me.polygons:
        for k in range(poly.loop_total):
            cols += [1.0 if k == 0 else 0.0, 1.0 if k == 1 else 0.0, 1.0 if k == 2 else 0.0, 1.0]
    at.data.foreach_set('color', cols)

def edge_lines(mats):
    """預覽用：材質底色在三角形邊上壓暗（Cycles 沒有 fwidth，線寬隨三角形大小變，夠看）"""
    for m in mats:
        nt = m.node_tree
        p = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        base = tuple(p.inputs['Base Color'].default_value)
        at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = 'bary'
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        m1 = nt.nodes.new('ShaderNodeMath'); m1.operation = 'MINIMUM'
        m2 = nt.nodes.new('ShaderNodeMath'); m2.operation = 'MINIMUM'
        st = nt.nodes.new('ShaderNodeMath'); st.operation = 'SMOOTH_MIN'
        stp = nt.nodes.new('ShaderNodeMapRange'); stp.inputs['From Min'].default_value = EDGE_LINE * 0.5
        stp.inputs['From Max'].default_value = EDGE_LINE
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
        dk = EDGE_DARK if m.name in ('d_belly', 'd_bone') else EDGE_DARK - 0.08
        mix.inputs['A'].default_value = tuple(c * dk for c in base[:3]) + (1,)
        mix.inputs['B'].default_value = base
        nt.links.new(at.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs[0], m1.inputs[0]); nt.links.new(sep.outputs[1], m1.inputs[1])
        nt.links.new(m1.outputs[0], m2.inputs[0]); nt.links.new(sep.outputs[2], m2.inputs[1])
        nt.links.new(m2.outputs[0], stp.inputs['Value'])
        nt.links.new(stp.outputs['Result'], mix.inputs['Factor'])
        nt.links.new(mix.outputs['Result'], p.inputs['Base Color'])

def strip_unused(o):
    """只留有面在用的材質欄位（自動檢查會擋空欄位）"""
    me = o.data
    used = sorted({f.material_index for f in me.polygons})
    remap = {old: new for new, old in enumerate(used)}
    keep = [me.materials[i] for i in used]
    idx = [remap[f.material_index] for f in me.polygons]
    me.materials.clear()          # clear 會把每個面的材質 index 一起清掉，先記下來再寫回
    for m in keep:
        me.materials.append(m)
    me.polygons.foreach_set('material_index', idx)

def build():
    rnd = random.Random(7)
    trunk = loft_table(TRUNK, 'trunk', ring=22, flat=0.18)
    parts = [trunk] + legs() + arms()
    skin = merge_skin(parts, "TrexSkin", 0.07, 2000)   # 使用者：銳利一點——面少一點、每面大一點，折面才清楚（第 38 版 8000 → 第 40 版 3500 → 2000）
    paint_skin(skin, random.Random(3))
    chisel(skin, CHISEL, 1)          # 先照原本的朝向上色，再削：顏色才不會被亂推的法線打散
    jaw = merge_skin([loft_table(JAW, 'jaw', ring=16, flat=0.3)], 'TrexJaw', 0.03, 240)
    paint_jaw(jaw, random.Random(5))
    chisel(jaw, CHISEL, 2)
    bits = Bits()
    add_spikes(bits, skin, rnd)
    add_head_bits(bits, skin, jaw, rnd)
    add_claws(bits, rnd)
    det = bits.obj('TrexBits')
    arm = make_armature()
    trex = skin_to(skin, jaw, det, arm)
    strip_unused(trex)
    if EDGE_LINE:
        bary_attr(trex)
        edge_lines([m for m in trex.data.materials if m.name not in ('d_eye', 'd_pupil')])
    return [trex, arm]


# ---- 骨架 ----
# 名字沿用舊的 trex.gd（root、spine1、spine2、neck、head、jaw、tail1~、thigh_l…），程式動畫才接得回去。
# 左右：_l 在 +x。一律 Godot 座標寫，B() 轉進 Blender。
def _spine_pt(z, dy=0.0):
    cy, _ = spine_center(z)
    return Vector((0, cy + dy, z))

TAIL_Z = (0.30, 0.90, 1.55, 2.25, 2.95, 3.65, 4.35, 5.00, 5.55)

def bone_table():
    """[(名字, 父骨, 頭, 尾)]，Godot 座標"""
    jz, jy = JAW_HINGE
    t = [
        ('root',   '',       _spine_pt(0.30), _spine_pt(-0.35)),
        ('spine1', 'root',   _spine_pt(-0.35), _spine_pt(-0.85)),
        ('spine2', 'spine1', _spine_pt(-0.85), _spine_pt(-1.35)),
        ('neck',   'spine2', _spine_pt(-1.35), _spine_pt(-1.70, 0.05)),
        ('neck2',  'neck',   _spine_pt(-1.70, 0.05), _spine_pt(-2.02, 0.12)),
        ('head',   'neck2',  _spine_pt(-2.02, 0.12), Vector((0, px(0, hy(115))[1], px(hx(322), 0)[0]))),
        ('jaw',    'head',   Vector((0, jy, jz)), Vector((0, px(0, hy(152))[1], px(hx(344), 0)[0]))),
    ]
    prev = 'root'
    for i in range(len(TAIL_Z) - 1):
        name = 'tail%d' % (i + 1)
        t.append((name, prev, _spine_pt(TAIL_Z[i]), _spine_pt(TAIL_Z[i + 1])))
        prev = name
    for s, sx in ((1, '_l'), (-1, '_r')):
        H, Kn, A, F = (mirror(v, s) for v in (HIP, KNEE, ANKLE, BALL))
        t += [('thigh' + sx, 'root', H, Kn), ('shin' + sx, 'thigh' + sx, Kn, A), ('foot' + sx, 'shin' + sx, A, F)]
        for k, (ang, L) in enumerate(TOES):
            a = math.radians(ang) * s
            d = Vector((math.sin(a) * 0.9 + 0.12 * s, 0, -math.cos(a)))
            mid = F + d * L * 0.5 + Vector((0, -0.02, 0)); tip = F + d * L + Vector((0, -0.04, 0))
            t += [('toe%d_1%s' % (k + 1, sx), 'foot' + sx, F, mid), ('toe%d_2%s' % (k + 1, sx), 'toe%d_1%s' % (k + 1, sx), mid, tip)]
        t.append(('dew' + sx, 'foot' + sx, F + Vector((0, 0.07, 0.12)), F + Vector((-0.04 * s, 0.02, 0.32))))
        S_, E, W = (mirror(v, s) for v in (SHOULDER, ELBOW, WRIST))
        hand = W + Vector((0, -0.05, -0.10))
        t += [('arm' + sx, 'spine2', S_, E), ('forearm' + sx, 'arm' + sx, E, W), ('hand' + sx, 'forearm' + sx, W, hand)]
        for k, (b, tip) in enumerate(fingers(s)):
            t.append(('finger%d%s' % (k + 1, sx), 'hand' + sx, b, tip))
    return t

def make_armature():
    arm = bpy.data.objects.new('TrexRig', bpy.data.armatures.new('TrexRig'))
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    for name, parent, h, tl in bone_table():
        b = eb.new(name)
        b.head, b.tail = B(h), B(tl)
        b.roll = 0
        if parent:
            b.parent = eb[parent]
        if name in ('head', 'jaw', 'thigh_l', 'thigh_r', 'arm_l', 'arm_r', 'tail1', 'spine1'):
            b.use_deform = True
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm

def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length

def fill_weights(o, arm, only_empty=True, exclude=('jaw',)):
    """距離權重：離骨頭線段越近越重（1/d^4，取最近 3 根）。自動權重失敗的點用這個補"""
    bones = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones if b.name not in exclude]
    groups = {g.name: g for g in o.vertex_groups}
    for name, _, _ in bones:
        if name not in groups:
            groups[name] = o.vertex_groups.new(name=name)
    n = 0
    for v in o.data.vertices:
        if only_empty and any(g.weight > 1e-4 for g in v.groups):
            continue
        d = sorted(((_seg_dist(v.co, h, t), name) for name, h, t in bones))[:3]
        w = [1.0 / (x ** 4 + 1e-6) for x, _ in d]
        tot = sum(w)
        for (x, name), wi in zip(d, w):
            groups[name].add([v.index], wi / tot, 'REPLACE')
        n += 1
    return n

def skin_to(skin, jaw, det, arm):
    """皮用 Blender 的自動權重（熱擴散），失敗的點用距離補；下顎整塊給 jaw；小零件一塊一塊抄最近皮的權重"""
    bpy.ops.object.select_all(action='DESELECT')
    skin.select_set(True); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    # 下顎不給自動權重：嘴角的皮被下顎骨拉走會撕開；jaw 骨只動下顎那塊
    if 'jaw' in skin.vertex_groups:
        skin.vertex_groups.remove(skin.vertex_groups['jaw'])
    missing = fill_weights(skin, arm)
    print('skin weights: auto ok, filled %d empty verts by distance' % missing)
    g = jaw.vertex_groups.new(name='jaw')
    g.add([v.index for v in jaw.data.vertices], 1.0, 'REPLACE')
    # 小零件：每個連通塊抄「離它最近的皮或下顎頂點」的整組權重，整塊剛性跟著走（牙、棘不會被拉長）
    from mathutils.kdtree import KDTree
    src = [(skin, v) for v in skin.data.vertices] + [(jaw, v) for v in jaw.data.vertices]
    kd = KDTree(len(src))
    for i, (_, v) in enumerate(src):
        kd.insert(v.co, i)
    kd.balance()
    bm = bmesh.new(); bm.from_mesh(det.data); bm.verts.ensure_lookup_table()
    seen = set(); islands = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; isl = []
        seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index); stack.append(y)
        islands.append(isl)
    cos = [v.co.copy() for v in bm.verts]
    bm.free()
    dg = {}
    for isl in islands:
        c = sum((cos[i] for i in isl), Vector()) / len(isl)
        base = min(isl, key=lambda i: (cos[i] - c).length)      # 零件靠皮那一端大概在質心附近
        _, j, _ = kd.find(cos[base])
        ob, v = src[j]
        for ge in v.groups:
            name = ob.vertex_groups[ge.group].name
            if name not in dg:
                dg[name] = det.vertex_groups.new(name=name)
            dg[name].add(isl, ge.weight, 'REPLACE')
    # 合成一個網格：Godot 那邊只有一個 MeshInstance3D + Skin
    bpy.ops.object.select_all(action='DESELECT')
    for o in (jaw, det, skin):
        o.select_set(True)
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.join()
    skin.name = 'Trex'
    return skin

# ---- 姿勢（只給預覽用；匯出是靜止姿勢）----
def rot_world(arm, name, axis, deg):
    """骨頭繞自己的頭、沿世界（Blender）軸轉 deg 度。父骨先轉，子骨會跟著"""
    from mathutils import Matrix
    pb = arm.pose.bones[name]
    M = pb.matrix.copy()
    piv = M.translation.copy()
    R = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv)
    pb.matrix = R @ M
    bpy.context.view_layer.update()

def pose_reset(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()

def pose_roar(arm):
    """參考圖的吼叫：頭微抬、嘴大開"""
    rot_world(arm, 'jaw', 'X', -30)

def pose_stride(arm):
    """參考圖側面：右腳（靠鏡頭）往前跨、左腳往後蹬"""
    rot_world(arm, 'thigh_r', 'X', 30); rot_world(arm, 'shin_r', 'X', -36); rot_world(arm, 'foot_r', 'X', 8)
    rot_world(arm, 'thigh_l', 'X', -30); rot_world(arm, 'shin_l', 'X', 4); rot_world(arm, 'foot_l', 'X', 30)

# ---- 預覽：照參考圖排（上排 正面｜側面｜背面，下排 上視｜下視），同一個比例尺 ----
PPU = 150   # 每單位幾 px

def _render(path, rot, loc, w, h, ppu=None):
    sc = bpy.context.scene
    cam = sc.camera
    cam.rotation_euler = [math.radians(a) for a in rot]
    cam.location = loc
    cam.data.ortho_scale = max(w, h) / (ppu or PPU)
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def setup_studio():
    """正交相機＋兩盞平行光＋環境光、Cycles。preview 和局部特寫（tools/trex_hd_close.py）共用"""
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    sc.collection.objects.link(cam); sc.camera = cam
    for rot, e in (((45, 0, 150), 5.5), ((60, 0, -30), 1.2), ((170, 0, 0), 1.0)):
        sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
        sun.data.energy = e; sun.data.color = (1.0, 0.9, 0.75)
        sun.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w'); world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.55, 0.55, 0.5, 1); bg.inputs['Strength'].default_value = 0.22
    sc.world = world
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 48
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'METAL'; prefs.get_devices()
        for d in prefs.devices: d.use = True
        sc.cycles.device = 'GPU'
    except TypeError:
        pass
    sc.view_settings.view_transform = 'Standard'
    sc.render.film_transparent = True

def preview(obs, path):
    setup_studio()
    base = path[:-4]
    cy = 1.75 + LEG_EXTRA * 0.5   # 畫面中心高度（Blender z）；腿加長後整隻變高
    hh = 3.7 + LEG_EXTRA
    views = [
        ('front', (90, 0, 180), (0, 30, cy), 2.9 * PPU, hh * PPU),
        ('side',  (90, 0, -90), (-30, -1.2, cy), 9.6 * PPU, hh * PPU),
        ('back',  (90, 0, 0),   (0, -30, cy), 2.9 * PPU, hh * PPU),
        ('top',   (0, 0, -90),  (0, -1.2, 30), 9.6 * PPU, 2.6 * PPU),
        ('bottom', (180, 0, -90), (0, -1.2, -30), 9.6 * PPU, 2.6 * PPU),
    ]
    arm = next(o for o in obs if o.type == 'ARMATURE')
    for name, rot, loc, w, h in views:
        pose_reset(arm); pose_roar(arm)
        if name == 'side':
            pose_stride(arm)
        _render(f'{base}_{name}.png', rot, loc, int(w), int(h))
    pose_reset(arm)
    # 站著不擺姿勢的側面：比例跟設定圖比用（上面那張是吼叫＋跨步的姿勢，上半身是仰的）
    _render(f'{base}_neutral.png', (90, 0, -90), (-30, -1.2, cy), int(9.6 * PPU), int(hh * PPU))
    print('preview views ->', base + '_*.png')

def export(obs, out):
    path = os.path.join(os.path.dirname(out) or '.', 'trex_hd.glb')
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    # 預覽的稜線是節點接出來的，glTF 讀不懂會整個掉色（進遊戲變白）：匯出前拆掉，只留底色。
    # 稜線用的頂點色也不匯出（Godot 會把它當顏色乘上去）；遊戲裡的稜線另外做
    for m in bpy.data.materials:
        if m.node_tree:
            p = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if p:
                for l in list(p.inputs['Base Color'].links):
                    m.node_tree.links.remove(l)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_vertex_color='NONE')
    print('exported ->', path)

if __name__ == '__main__':
    pipeline.run(build, preview, budget=16000, export_fn=export, preview_first=True)
