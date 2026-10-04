# 第一人稱的手：一整張連續的手套皮＋骨架（骨頭照 FNE_project 那隻手：手腕、每指三節、拇指三節、前臂），
# 擺好姿勢後烘成遊戲用的固定網格，名字跟以前 cowboy.py 拼的方塊手一樣，遊戲程式不用改：
#   HandGrip       握槍把的右手（原點在握把軸上、手的中間高度；握把沿 Z 直立，手背朝 +X，食指在上）
#   HandGripThumb  右手拇指（原點在拇指根部的關節，節點位置就是它在 HandGrip 裡的位置；左輪扳擊錘時轉它）
#   HandGripArm    右手前臂、手套袖口、風衣袖子（原點在手腕，往 ARM_R 伸出畫面）
#   HandSupport    托護木的左手（原點在護木軸上；護木沿 Y，掌心朝上托在下面，手指從 +X 側往上包）
#   HandLoad       換彈捏子彈的左手（原點在拇指和食指捏住的那一點，子彈沿 +Y）
#
# 做法：
#   1. 在「手的空間」建手：手腕在原點、手指朝 +Y、手背朝 +Z、右手（拇指在 -X）。
#      手掌和前臂是一圈圈 10 個點的斷面接起來；指節那一圈正好切成四個開口，四根手指從開口長出去；
#      拇指從手掌靠手腕的那一側長出去。手指斷面是方的，最後細分一次變圓（低面數又連續、沒有接縫）。
#   2. 每一圈直接指定屬於哪根骨頭（關節那圈兩根各半），不用自動算權重。
#   3. 握姿：手指一節一節往掌心彎，彎到碰到握把（圓柱）為止，所以換握把粗細不用重調角度。
#   4. 擺好的網格搬到遊戲要的座標、照「零件」屬性切成拇指／前臂／手。
#
# 預覽：tools/model_iter.sh hands <版號>（張開、握槍六格，跟 FNE 的手 docs/image/hand.png 上下對照）
# 匯出：cowboy.py 會 import 這支、把五個網格一起放進 cowboy.glb。
# 跟遊戲共用：各武器的 grip_hand / support_hand（cowboy/weapons/*.tscn）是照這裡的原點擺的；
#            THUMB 的位置改了，weapon.gd 的 thumb_cock 角度要重看。
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Quaternion

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)

# ---------------- 尺寸（公尺，戴手套的成年男人，比真手稍粗） ----------------
# 指節那一圈：四根手指的中心 x（食指在 -X）、開口半寬、指根的 y（中指最前、小指最後，排成弧）。
# 相鄰開口之間留一小段（約手指半徑 0.3 倍）當指縫，不要所有面收到同一個點（收成一點會撕開、指根被掐細）
FINGER_HW = [0.0103, 0.0108, 0.0101, 0.0092]   # 中指根粗一點：同姿勢疊圖量出食指中指間的缺口比參考深
FINGER_GAP = 0.0012                    # 指縫寬（約手指半徑 0.12 倍）：四指根部幾乎靠在一起
KNUCKLE_Y = [0.096, 0.104, 0.100, 0.087]
XS = []                                # 手掌每一圈手背那排 8 個點的 x：四個開口從食指那邊排過去，整排置中
for _w in FINGER_HW:
    _x0 = XS[-1] + FINGER_GAP if XS else 0.0
    XS += [_x0, _x0 + 2 * _w]
XS = [x - (XS[0] + XS[-1]) / 2 for x in XS]
FINGER_X = [(XS[2 * i] + XS[2 * i + 1]) / 2 for i in range(4)]
#           名字      三節長度（從指節關節算）   張開角（度，往小指為正）
# 指尖排成一條平緩的弧，食指只比中指短一點（疊圖：以前中指、無名指長一成多、食指短一成，像中間凸起的尖塔）
def _split(total, ratio):
    t = sum(ratio)
    return tuple(total * r / t for r in ratio)


# 總長照張開疊圖定的；三節怎麼分照參考的比例（關節用骨頭的頭、指尖用皮的最遠點——glTF 不存骨頭尾巴，用尾巴會量錯）（手指握起來每節分開轉，比例錯了握姿就對不上——
# 以前第一節佔一半，參考只佔三分之一多一點，是「手指不像真的」的原因之一）
FINGERS = [('Index',  _split(0.1022, (0.41, 0.335, 0.255)), -5),   # 往外張：疊圖量出食指往中指偏 8~12 px
           ('Middle', _split(0.0924, (0.37, 0.34, 0.29)), 0),
           ('Ring',   _split(0.0849, (0.40, 0.31, 0.29)), 2),
           ('Little', _split(0.0670, (0.37, 0.29, 0.34)), 5)]
# 建模用的姿勢：手指三個關節先彎好這些角度（度）。動作範圍從張開（約 20/30/18）到握緊（約 60/70/65），
# 模型擺在中間，兩頭變形都只要走一半——直的手指一口氣彎到 70 度，關節內側會被壓扁（知識庫：關節環線與中間姿勢建模）。
# 姿勢的角度（bend）仍是從伸直算，程式自己扣掉這個
REST_CURL = (20, 45, 35)
TAPER = (1.0, 1.0, 0.88, 0.74)         # 四個關節（指根、兩個指節、指尖）的粗細倍率（乘開口半寬）：第一個指節之後才收細
WEB = (0.004, 0.010)                   # 指蹼：手指開口在指節前面多遠（手背、掌心）。只有掌心那面有明顯的蹼
# 手掌、手腕、前臂的斷面：(y, 寬度倍率, 手背 z, 掌心 z, 中心 x)
WEB_WIDEN = 0.006                      # 虎口上緣加寬
HEEL = 0.004                           # 掌根（靠手腕那 40%）掌心那面再加厚
HEEL_THENAR = 0.002                    # 拇指根那團肉在離手腕最近那圈再往掌心鼓
# 裸手（照 Hunt 影片）：前臂露出來，往手肘漸粗，袖子捲到前臂後段
PALM = [(-0.380, 0.98, 0.026, -0.027, 0.0),   # 前臂後段（捲起的袖子蓋住這裡；袖子捲到手肘附近，第一人稱看到的是手背和前臂）
        (-0.200, 0.94, 0.025, -0.026, 0.0),   # 前臂肌肉最粗處
        (-0.110, 0.82, 0.021, -0.022, 0.0),
        (-0.050, 0.70, 0.016, -0.0175, 0.0),
        (-0.004, 0.63, 0.0140, -0.0160, -0.001),   # 手腕：比手掌下緣窄一截（皮的斷面偏方，四個角要收進袖口的橢圓裡）
        (0.006, 0.76, 0.0165, -0.0195 - HEEL * 0.3, -0.001),   # 這圈靠袖口，加厚太多皮會從袖口上緣穿出來   # 手腕往手掌過渡那圈（握槍時手腕彎，這裡分攤彎折）
        (0.016, 0.88, 0.019, -0.025 - HEEL, -0.001),     # 掌根：掌心那面加厚 HEEL（疊圖量出這段薄 19~22 px）
        (0.048, 1.00, 0.019, -0.026, -0.001),
        (0.074, 1.01, 0.017, -0.023, 0.0)]
THENAR = 0.004                         # 拇指根那團肉：手掌靠拇指那側的掌心再鼓出來
KNUCKLE_Z = (0.0128, -0.0048)          # 指節那圈的手背、掌心 z（手指根部的厚度跟手指一樣粗才不會掐一圈；整圈往手背抬 4 mm，
                                       # 手背到指節才是一條直線再折下去，不然手背是一顆蛋、看不出第一節從哪開始）
THUMB_PORT = (6, 7)                    # 拇指從第 4、5 圈之間的側面長出去（PALM 的索引，含前臂）
THUMB_PORT_FOLLOW = 0.7   # 拇指開口那圈跟拇指走的比例
THUMB_ROOT = (-0.0204, 0.0427, -0.0223)   # 參考：手腕為原點，往前 0.23、往食指側 0.11、往掌心 0.12 個手長（手長 0.186 m）
THUMB_LEN = _split(0.093, (0.24, 0.45, 0.30))   # 照參考骨架比例：掌骨短、後兩節長（以前掌骨佔四成）      # 掌骨要夠長，握緊時拇指才搆得到中指（短了只能平伸出去）      # 掌骨露出來的那段、第一節、第二節
THUMB_R = 0.0155
THUMB_TAPER = (1.05, 1.0, 0.9, 0.75)   # 根部那圈放大，融進拇指根那團肉（虎口才有曲線）
# 張開時拇指的方向：往前、往掌心，只往外一點（疊圖：往側邊張 45 度像海星，參考圖的拇指收在手掌前方）
THUMB_DIR = Vector((-0.20, 0.62, -0.76)).normalized()   # 從手背看拇指要藏在手掌後面（x 小）
_n = Vector((-0.80, -0.10, 0.45))
THUMB_NAIL = (_n - THUMB_DIR * _n.dot(THUMB_DIR)).normalized()   # 拇指指甲朝哪（拇指自己的手背方向，跟拇指垂直）


NAILS = {}   # 四指每節骨頭的「指甲朝哪」（彎好的手指每節不一樣，骨頭的彎曲軸照它定）


def _ring(c, d, up, hw, hh, lift=0.0):
    """方形斷面：中心 c、沿 d、上面朝 up；回傳 4 個點（順序：上右、上左、下左、下右）。
    lift：整圈往手背那面推（關節那圈手背凸一點）"""
    d = d.normalized()
    s = up.cross(d).normalized()          # 右手邊
    u = d.cross(s).normalized()
    c = c + u * lift
    return [c + s * hw + u * hh, c - s * hw + u * hh, c - s * hw - u * hh, c + s * hw - u * hh]


def _match(prev, ring):
    """把 ring 的順序轉成跟 prev 最對齊（兩圈接起來才不會扭成麻花）"""
    best = min(range(4), key=lambda k: sum((ring[(i + k) % 4] - prev[i]).length for i in range(4)))
    return [ring[(i + best) % 4] for i in range(4)]


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.part = self.bm.faces.layers.int.new('part')   # 0 手、1 拇指、2 前臂
        self.soft = self.bm.faces.layers.int.new('soft')   # 1：這面不套硬邊（指尖圓頂、指縫、拇指根的肉）
        self.hard = self.bm.edges.layers.int.new('hard')   # 1：一定是硬邊（手掌兩側的長邊）
        self.groups = []

    def g(self, name):
        if name not in self.groups:
            self.groups.append(name)
        return self.groups.index(name)

    def vert(self, co, weights):
        v = self.bm.verts.new(co)
        for b, w in weights:
            v[self.dl][self.g(b)] = w
        return v

    def quad(self, a, b, c, d, part=0, mat=0, soft=0):
        f = self.bm.faces.new((a, b, c, d))
        f[self.part] = part
        f[self.soft] = soft
        f.material_index = mat
        return f

    def bridge(self, r0, r1, part=0, mat=0, soft=0):
        n = len(r0)
        for i in range(n):
            self.quad(r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i], part, mat, soft)

    def tube(self, root, joints, radii, nail_up, names, part0, part_from=1, cap=True, bump=False, soft_root=False):
        """從 root（已經存在的 4 個點）沿關節 joints=[J0, J1, J2, J3] 長一根方管手指。
        names = 三節骨頭的名字。每節兩端各一圈支撐圈全屬那節（骨節是直的），只有關節那圈兩節各半，
        彎曲只發生在關節前後幾 mm——不然細分後整根手指彎成一條平滑的弧，像水管，看不出一節一節。指尖三圈收小再封口。
        part0：從第 part_from 節開始算成 part0 這個零件（拇指的掌骨那節算手）。
        soft_root：第一節不套硬邊（拇指根那團肉接手掌，套了會折出一道細線）"""
        prev = [v.co.copy() for v in root]
        root_c = sum(prev, Vector()) / 4
        rings = [root]
        stations = []
        if bump:   # 指節：開口最前端再過去 3 mm 那圈往兩旁寬一點（握拳時拳頭上緣那排連成一條；往手背凸的話張開時會變一道折痕）。
            # 開口是斜的（掌心那面的指蹼比較長），放在開口中心後面會落到開口裡面、折回來把指根掐出一圈細脖子
            d0 = (joints[1] - joints[0]).normalized()
            front = max((v.co - root_c).dot(d0) for v in root)
            stations.append((root_c + d0 * (front + 0.003), d0, (radii[0] * 1.05, radii[0] * 0.95),
                             [(names[0], 1.0)], 0, 0.002))   # 全跟第一節走：指根的大關節才折得出角度；往手背凸，握拳時是一排指節
        G = 0.0015   # 支撐圈離關節多遠：越近轉角越利（2.8 mm 時還像彎過的軟管）
        for k in range(3):
            a, b = joints[k], joints[k + 1]
            e = (b - a).normalized()
            r_a, r_b = radii[k], radii[k + 1]
            pk = part0 if k >= part_from else 0
            w = [(names[k], 1.0)]
            if k > 0:   # 這節的起點支撐圈
                stations.append((a + e * G, b - a, r_a, w, pk, 0.0))
            if (a.lerp(b, 0.5) - root_c).dot(b - a) > 0.004:   # 開口已經在這節中間之後（指蹼）就不加
                stations.append((a.lerp(b, 0.5), b - a, (r_a + r_b) / 2 * 0.96, w, pk, 0.0))
            if k < 2:   # 這節的終點支撐圈，再來是關節那圈（兩節各半；彎 90 度時會被壓扁，先放大一點、手背那面凸一點當指節）
                stations.append((b - e * G, b - a, r_b, w, pk, 0.0))
                lift = 0.0004 if k == 0 else 0.0   # 伸直時關節不能凸，不然硬邊會把整節切出來（掌心那面像戴了頂針）
                stations.append((b, joints[k + 2] - a, r_b * 1.0, [(names[k], 0.5), (names[k + 1], 0.5)], pk, lift))
        a, b = joints[2], joints[3]
        e = (b - a).normalized()   # 指尖：三圈收口（0.92 → 0.58 → 0.25），不是一顆比手指還大的球
        stations.append((b - e * 0.005, b - a, radii[3] * 0.92, [(names[2], 1.0)], part0, 0.0))
        stations.append((b - e * 0.001, b - a, radii[3] * 0.58, [(names[2], 1.0)], part0, 0.0))
        stations.append((b + e * 0.0015, b - a, radii[3] * 0.25, [(names[2], 1.0)], part0, 0.0))
        # 落在開口後面（或離開口不到 4 mm）的圈不建：轉軸在手掌深處時（拇指根），那幾圈會在開口後面摺回來、掐出一道凹痕
        d0 = (joints[-1] - joints[0]).normalized()
        n_all = len(stations)
        stations = [st for k, st in enumerate(stations) if k >= n_all - 3 or (st[0] - root_c).dot(d0) > 0.004]
        n_tip = 3   # 最後三圈是指尖圓頂：不套硬邊（套了會切成幾塊平面，朝下那幾面暗掉，像戴頂針）
        for i, (c, d, r, w, pk, lift) in enumerate(stations):
            hw, hh = r if isinstance(r, tuple) else (r, r * 0.85)   # 斷面偏扁：手背那面有自己的受光面
            pts = _match(prev, _ring(c, d, nail_up, hw, hh, lift))
            ring = [self.vert(p, w) for p in pts]
            first = soft_root and w[0][0] == names[0] and len(w) == 1
            self.bridge(rings[-1], ring, pk, soft=int(i >= len(stations) - n_tip or first))
            rings.append(ring)
            prev = pts
        if cap:
            f = self.bm.faces.new(rings[-1])
            f[self.part] = part0
            f[self.soft] = 1
        return rings


def palm_ring(st, knuckle=False):
    """手掌一圈 16 個點：手背 8 個（食指 → 小指）、掌心 8 個（小指 → 食指）"""
    y, s, zt, zb, cx = st
    top, bot = [], []
    for j, x in enumerate(XS):
        x2 = cx + x * s
        if knuckle:
            yk = KNUCKLE_Y[j // 2]
            top.append(Vector((x2, yk + WEB[0], zt)))
            bot.append(Vector((x2, yk + WEB[1], zb)))
            continue
        if y < 0:   # 手腕和前臂：圓的斷面（方的四個角會穿出袖口）
            th = math.pi * (1 - (j + 0.5) / 8)
            hw, hh, cz = XS[-1] * s, (zt - zb) / 2, (zt + zb) / 2
            top.append(Vector((cx + hw * math.cos(th), y, cz + hh * math.sin(th))))
            bot.append(Vector((cx + hw * math.cos(th), y, cz - hh * math.sin(th))))
            continue
        if j == 0 and y > 0.03:   # 虎口上緣（食指根下方、靠拇指那側）往外寬一點：疊圖量出這段窄 15~18 px
            x2 -= WEB_WIDEN
        edge = j in (0, 7)
        arch = 0.0016 * (1 - (2 * j / 7 - 1) ** 2)   # 手背幾乎是平的：側面看得到手背在指節處折下去
        thenar = (THENAR if (j <= 2 and 0.01 < y < 0.06) else 0.0) + (HEEL_THENAR if (j <= 2 and 0.01 < y < 0.02) else 0.0)
        top.append(Vector((x2, y, zt + arch - (0.003 if edge else 0))))
        bot.append(Vector((x2, y, zb - thenar + (0.003 if edge else 0))))
    return top + bot[::-1]


def build_rig():
    """建手的網格和骨架（手的空間、靜止姿勢）。回傳 (網格物件, 骨架物件, 關節表)"""
    B = Builder()
    joints = {}
    # 手掌＋前臂
    rings = []
    for i, st in enumerate(PALM):
        # 手腕那圈（袖口裡面）全跟前臂走：手腕彎的時候皮才不會被推出袖口（以前袖口前緣的鋸齒就是這個）
        # 手腕和手掌之間那圈兩根骨頭各半：握槍時手腕彎得最多，只有兩圈的話彎折處會折出一個角
        w = [('LowerArm', 1.0)] if st[0] < 0.0 else ([('LowerArm', 0.5), ('Hand', 0.5)] if st[0] < 0.01 else [('Hand', 1.0)])
        ring = [B.vert(p, w) for p in palm_ring(st)]
        if rings:
            part = 2 if st[0] <= 0.0 else 0
            for k in range(16):
                if (i - 1, i) == THUMB_PORT and k == 15:   # 拇指那側（掌心食指 → 手背食指那條邊）留給拇指
                    continue
                B.quad(rings[-1][k], rings[-1][(k + 1) % 16], ring[(k + 1) % 16], ring[k], part,
                       soft=int(i in THUMB_PORT and k >= 13))   # 拇指根那團肉
            if st[0] > 0.01:   # 手掌兩側的長邊（手背轉到側面那條）是硬邊：側面讀成一個平面，跟分面的手指同一種風格
                for k in (7,):   # 只有小指那側（食指那側接拇指根，硬邊會變一條鋸齒裂痕）
                    B.bm.edges.get((rings[-1][k], ring[k]))[B.hard] = 1
        rings.append(ring)
    # 指節那圈（手指開口）：三成跟手、七成跟自己那根手指的第一節。全跟手的話，握拳時指縫那段被兩邊手指拉扯，折出碎三角形
    kn = [B.vert(p, [('Hand', 0.3), (FINGERS[(j if j < 8 else 15 - j) // 2][0] + '_Proximal', 0.7)])
          for j, p in enumerate(palm_ring((0, 1, KNUCKLE_Z[0], KNUCKLE_Z[1], 0), knuckle=True))]
    B.bridge(rings[-1], kn)
    # 前臂後端封口（藏在袖子裡，封起來匯出才不會看到裡面）
    f = B.bm.faces.new(rings[0][::-1])
    f[B.part] = 2
    joints['Hand'] = (Vector((0, 0, 0)), Vector((0, 0.05, 0)))
    joints['LowerArm'] = (Vector((0, 0, 0)), Vector((0, -0.26, 0)))
    # 四根手指：開口是指節那圈上下各兩個點
    for i in range(3):   # 指縫：相鄰兩個開口之間那一小段
        B.quad(kn[2 * i + 1], kn[2 * i + 2], kn[15 - (2 * i + 2)], kn[15 - (2 * i + 1)], soft=1)
    for i, (name, lens, splay) in enumerate(FINGERS):
        top_a, top_b = kn[2 * i], kn[2 * i + 1]
        bot_b, bot_a = kn[15 - (2 * i + 1)], kn[15 - 2 * i]
        root = [top_b, top_a, bot_a, bot_b]
        c = sum((v.co for v in root), Vector()) / 4
        d = Matrix.Rotation(math.radians(-splay), 3, 'Z') @ Vector((0, 1, 0))
        js = [c - d * (sum(WEB) / 2 + 0.004)]          # 指節關節在開口後面（手掌裡）
        names = [name + s for s in ('_Proximal', '_Intermediate', '_Distal')]
        axis = d.cross(Vector((0, 0, 1))).normalized()   # 彎曲軸（往掌心彎是繞它轉負角）
        cum = 0.0
        for k, L in enumerate(lens):   # 每一節照 REST_CURL 往掌心彎好
            cum += REST_CURL[k]
            rot = Matrix.Rotation(math.radians(-cum), 3, axis)
            js.append(js[-1] + rot @ d * L)
            NAILS[names[k]] = rot @ Vector((0, 0, 1))
        radii = [FINGER_HW[i] * t for t in TAPER]
        B.tube(root, js, radii, Vector((0, 0, 1)), names, 0, bump=True)
        for k, n in enumerate(names):
            joints[n] = (js[k], js[k + 1])
    # 拇指：從手掌側面那個開口長出去
    a, b = THUMB_PORT
    root = [rings[a][0], rings[b][0], rings[b][15], rings[a][15]]
    # 開口那圈一部分跟拇指走：拇指的轉軸在手掌深處，開口只跟手的話，拇指一轉接縫就被扯出凹痕
    for v in root:
        v[B.dl][B.g('Hand')] = 1.0 - THUMB_PORT_FOLLOW
        v[B.dl][B.g('Thumb_Proximal')] = THUMB_PORT_FOLLOW
    c = sum((v.co for v in root), Vector()) / 4
    # 拇指根部的關節（掌骨跟手腕接的地方）：照參考骨架放在手掌中間偏深處，不是開口旁邊。
    # 以前放在開口內一點，離手腕近 9 mm、偏外 15 mm、淺 9 mm，彎起來整根拇指平移到圈外
    j0 = Vector(THUMB_ROOT)
    # 沒擺姿勢時拇指從轉軸「穿過開口」往外長：轉軸在手掌深處，照舊方向長的話骨頭那條線離開口 2.5 公分，
    # 皮要先橫跨過去、在接縫摺出凹痕。各姿勢都會重新設拇指方向，所以這個方向只影響皮順不順
    tdir = (c + THUMB_DIR * 0.02 - j0).normalized()
    js = [j0]
    for L in THUMB_LEN:
        js.append(js[-1] + tdir * L)
    names = ['Thumb' + s for s in ('_Proximal', '_Intermediate', '_Distal')]
    nail = (THUMB_NAIL - tdir * THUMB_NAIL.dot(tdir)).normalized()
    NAILS.update({n: nail for n in names})
    B.tube(root, js, [THUMB_R * t for t in THUMB_TAPER], nail, names, 1, part_from=1, soft_root=True)
    for k, n in enumerate(names):
        joints[n] = (js[k], js[k + 1])
    # 掌骨那段的根部也算手（權重一半給手，彎拇指時手掌那塊肉跟著動一點）
    bmesh.ops.recalc_face_normals(B.bm, faces=B.bm.faces)
    me = bpy.data.meshes.new('hand_skin')
    B.bm.to_mesh(me)
    ob = bpy.data.objects.new('hand_skin', me)
    bpy.context.scene.collection.objects.link(ob)
    for name in B.groups:
        ob.vertex_groups.new(name=name)
    # 骨架
    ad = bpy.data.armatures.new('hand_rig')
    arm = bpy.data.objects.new('hand_rig', ad)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for n in ['Hand', 'LowerArm'] + [f[0] + s for f in FINGERS for s in ('_Proximal', '_Intermediate', '_Distal')] + names:
        h, t = joints[n]
        e = ad.edit_bones.new(n)
        e.head, e.tail = h, t
        e.align_roll(NAILS.get(n, Vector((0, 0, 1))))   # 骨頭的 X 軸 = 彎曲軸
        eb[n] = e
    eb['LowerArm'].parent = eb['Hand']
    for f in FINGERS + [('Thumb',)]:
        seq = [f[0] + s for s in ('_Proximal', '_Intermediate', '_Distal')]
        eb[seq[0]].parent = eb['Hand']
        eb[seq[1]].parent = eb[seq[0]]
        eb[seq[2]].parent = eb[seq[1]]
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
    ob.parent = arm
    mod = ob.modifiers.new('rig', 'ARMATURE')
    mod.object = arm
    sub = ob.modifiers.new('round', 'SUBSURF')
    sub.levels = sub.render_levels = 1
    return ob, arm


def build_wear(arm):
    """手套的寬袖口（牛仔的長手套）和風衣袖子：一圈圈的管子，全部跟前臂走"""
    bm = bmesh.new()
    dl = bm.verts.layers.deform.verify()
    part = bm.faces.layers.int.new('part')
    N = 12

    def ring(y, rx, rz, cz=-0.001):
        vs = []
        for i in range(N):
            a = 2 * math.pi * i / N
            v = bm.verts.new((rx * math.cos(a), y, cz + rz * math.sin(a)))
            v[dl][0] = 1.0
            vs.append(v)
        return vs

    def loft(spec, mat):
        rs = [ring(*s) for s in spec]
        for r0, r1 in zip(rs, rs[1:]):
            for i in range(N):
                f = bm.faces.new((r0[i], r0[(i + 1) % N], r1[(i + 1) % N], r1[i]))
                f[part] = 2
                f.material_index = mat

    # 捲起來的袖子：前臂後段一圈鼓起的布捲，後面接袖子伸出畫面
    loft([(-0.335, 0.0315, 0.0305), (-0.342, 0.0365, 0.0355), (-0.370, 0.0385, 0.0375), (-0.398, 0.0365, 0.0355),
          (-0.402, 0.0335, 0.0325), (-0.420, 0.0340, 0.0330), (-0.550, 0.0370, 0.0360)], 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('hand_wear')
    bm.to_mesh(me)
    ob = bpy.data.objects.new('hand_wear', me)
    bpy.context.scene.collection.objects.link(ob)
    ob.vertex_groups.new(name='LowerArm')
    ob.parent = arm
    ob.modifiers.new('rig', 'ARMATURE').object = arm
    for p in ob.data.polygons:   # 袖口、袖子是圓筒，全平滑
        p.use_smooth = True
    return ob


SHARP = 50   # 度：面跟面夾角超過這個就是硬邊。方形手指細分後是八角形、相鄰面夾 45 度，
#             門檻 35 時手指沿長邊全變硬邊、像八角鉛筆（Blender 裡轉到掌心才看得到）；關節彎 60~70 度的折角還是硬的


def smooth_by_angle(ob):
    """平滑打光，但夾角超過 SHARP 的邊是硬邊：手背、手掌平順（全平面著色會照出細分的棋盤格），
    關節折角處明暗斷開，手指才看得出一節一節（全平滑會像水管）。擺好姿勢烘完才算（角度跟姿勢有關）"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    part = bm.faces.layers.int.get('part')
    soft = bm.faces.layers.int.get('soft')
    hard = bm.edges.layers.int.get('hard')
    for e in bm.edges:
        fs = e.link_faces
        if hard is not None and e[hard]:
            e.smooth = False
        elif any(f[part] == 2 for f in fs) or (soft is not None and any(f[soft] for f in fs)):
            e.smooth = True   # 袖口、袖子是圓筒（不然切出直的明暗線）；指尖、指縫、拇指根
        else:
            e.smooth = not (e.is_manifold and e.calc_face_angle(0) > math.radians(SHARP))
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)


# ---------------- 擺姿勢 ----------------
FINGER_NAMES = [f[0] for f in FINGERS]


def reset(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, 0)
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def bend(arm, name, flex, splay=0.0):
    """往掌心彎 flex 度（從伸直算）、往小指張 splay 度（骨頭的 X 軸是彎曲軸）。
    四指的模型已經彎好 REST_CURL，這裡扣掉"""
    pb = arm.pose.bones[name]
    pb.rotation_mode = 'XYZ'
    for k, s in enumerate(('_Proximal', '_Intermediate', '_Distal')):
        if name.endswith(s) and not name.startswith('Thumb'):
            flex -= REST_CURL[k]
    pb.rotation_euler = (math.radians(-flex), 0, math.radians(-splay))


def tip(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].tail


def head(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].head


def _axis_dist(p, P, A):
    v = p - P
    return (v - A * v.dot(A)).length


CURL = (1.0, 1.17, 1.08)   # 握東西時三個關節的彎曲比例：平均分給三節，手指才會沿著握把貼一圈（不是指根折 90 度的勾子）


def wrap(arm, finger, P, A, R, rad, splay=0.0):
    """三個關節照 CURL 的比例一起彎，彎到手指碰到圓柱（軸過 P、方向 A、半徑 R）為止"""
    names = [finger + s for s in ('_Proximal', '_Intermediate', '_Distal')]
    best = (1e9, 0)
    for deg in range(0, 101, 2):
        for n, k in zip(names, CURL):
            bend(arm, n, deg * k, splay if n == names[0] else 0)
        bpy.context.view_layer.update()
        pts = [arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t) for n in names for t in (0.5, 1.0)]
        d = min(_axis_dist(p, P, A) for p in pts)
        if d <= R + rad:
            best = (d, deg)
            break
        best = min(best, (d, deg))
    for n, k in zip(names, CURL):
        bend(arm, n, best[1] * k, splay if n == names[0] else 0)
    bpy.context.view_layer.update()


def aim_forearm(arm, d):
    """前臂從手腕往 d（手的空間）伸出去"""
    pb = arm.pose.bones['LowerArm']
    rest = (pb.bone.tail_local - pb.bone.head_local).normalized()
    q = rest.rotation_difference(d.normalized())
    m = pb.bone.matrix_local.copy()
    pb.matrix = Matrix.Translation(m.translation) @ q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()
    bpy.context.view_layer.update()


THUMB_IN = 0.75   # 握槍時拇指指尖目標從食指關節往握把軸拉多少（0~1）
MC_PULL = (0.0, 0.0)   # 掌骨末端：往掌心前面的懲罰、往小指那側的懲罰（thumb_to 的 mc_pull）
HUG = 0.0   # 握槍時拇指掌骨往握把貼的力道（thumb_to 的 hug）
# 遊戲裡的手縮成這個倍率：照真人尺寸做的手比以前的方塊手大三成，舉槍瞄準時槍托貼近臉，手會擋到準星。
# 握把、護木的半徑先除掉這個倍率再擺姿勢，縮完剛好貼合槍把
SCALE = 1.0
# 握槍把：握把軸從掌根（小指那側）斜到虎口，跟指節連線差約 15 度
GRIP_R = 0.0165 / SCALE
GRIP_AXIS = Vector((-math.cos(math.radians(15)), math.sin(math.radians(15)), 0)).normalized()
GRIP_P = Vector((0.0, 0.072, -0.012 - GRIP_R))
# 托護木：護木比較粗，斜得更多（從掌根斜到虎口）
SUP_R = 0.021 / SCALE
SUP_AXIS = Vector((-math.cos(math.radians(30)), math.sin(math.radians(30)), 0)).normalized()
SUP_P = Vector((0.0, 0.066, -0.014 - SUP_R))


OPEN_SPLAY = (-5, 0, 6, 9)


def pose_open(arm):
    reset(arm)
    # 四指幾乎平行（散成扇形看起來像在比「五」）；指根只微彎，食指中指最直（疊圖：彎多了手指往前倒、看起來變短）
    # 張開幅度：疊圖量出四指往中指靠攏 10~15 px，食指、無名指、小指再往外張
    for n, sp, p0, p1 in zip(FINGER_NAMES, OPEN_SPLAY, (0, 0, 8, 18), (20, 20, 30, 30)):
        bend(arm, n + '_Proximal', p0, sp)
        bend(arm, n + '_Intermediate', p1)
        bend(arm, n + '_Distal', 18)
    bpy.context.view_layer.update()
    pose_ref(arm, '_open', ('Thumb',), keep=True)   # 張開的拇指照抄參考張開時的方向（拇指根位置照參考擺了，角度也跟著抄）


def thumb_to(arm, target, P, A, R, rad=0.010, tip_bend=0, apart=0.0, hug=0.0, mc_pull=None):
    """拇指在幾個角度裡找：指尖最靠近 target、又不穿進握把（圓柱）的姿勢"""
    best = None
    pb = arm.pose.bones['Thumb_Proximal']
    index_tip = tip(arm, 'Index_Distal')
    for f in range(0, 91, 10):                 # 往掌心彎
        for tw in range(-45, 46, 15):          # 繞自己轉（對掌時拇指會轉過來）
            for o in range(-40, 91, 10):       # 往掌心那側擺
                for m in (10, 30, 50, 70):
                    pb.rotation_euler = (math.radians(-f), math.radians(tw), math.radians(o))
                    bend(arm, 'Thumb_Intermediate', m)
                    bend(arm, 'Thumb_Distal', m * 0.6 + tip_bend)
                    bpy.context.view_layer.update()
                    pts = [arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t)
                           for n in ('Thumb_Intermediate', 'Thumb_Distal') for t in (0.5, 1.0)]
                    pen = max(0.0, R + rad - min(_axis_dist(q, P, A) for q in pts))
                    cost = (pts[-1] - target).length + pen * 10
                    if mc_pull:   # 掌骨末端少往掌心前面（-Z）、多往食指那側（-X）：握槍時拇指根才不會在圈外凸一團
                        mc = arm.matrix_world @ arm.pose.bones['Thumb_Proximal'].tail
                        cost += mc_pull[0] * max(0.0, -mc.z) + mc_pull[1] * mc.x
                    if hug:   # 掌骨那節貼近握把：不然拇指根往外張成一個弧，握槍時在圈外凸一團（疊圖量出 20 px）
                        mc = arm.matrix_world @ arm.pose.bones['Thumb_Proximal'].tail
                        cost += hug * _axis_dist(mc, P, A)
                    if apart:   # 拇指尖離食指尖至少 apart（黏在一起看不出是兩根手指）
                        cost += max(0.0, apart - (pts[-1] - index_tip).length) * 10
                    if best is None or cost < best[0]:
                        best = (cost, f, tw, o, m)
    _, f, tw, o, m = best
    pb.rotation_euler = (math.radians(-f), math.radians(tw), math.radians(o))
    bend(arm, 'Thumb_Intermediate', m)
    bend(arm, 'Thumb_Distal', m * 0.6 + tip_bend)
    bpy.context.view_layer.update()


def far_side(P, A, R, along, gap=0.009):
    """握把上跟手指相反那一側的點（拇指要去的地方）：沿軸 along 公尺、離軸 R + gap"""
    u = Vector((0, 0, -1))
    u = (u - A * u.dot(A)).normalized()          # 掌心 → 握把
    w = A.cross(u).normalized()                  # 手指從 -w 那側包過去，拇指在 +w
    return P + A * along + w * (R + gap)


def over_finger(arm, P, A, finger='Middle_Intermediate', gap=0.016):
    """握緊時拇指壓的地方：中指第二節根部的外側（從握把軸往外推）。
    放在第二節中間會讓拇指尖跟食指尖頂在一起，兩根融成一團"""
    pb = arm.pose.bones[finger]
    q = arm.matrix_world @ pb.head.lerp(pb.tail, 0.15)
    v = q - P
    out = (v - A * v.dot(A)).normalized()
    return q + out * gap


def pose_grip(arm, P=GRIP_P, A=GRIP_AXIS, R=GRIP_R, thumb_along=None):
    """thumb_along=None：拇指壓在中指上（握槍把）；給數字：拇指放在握把另一側、沿軸那麼遠（托護木）"""
    reset(arm)
    for n, sp in zip(FINGER_NAMES, (0, 0, 0, 0)):   # 握緊時四指不往中間靠（靠了拳頭比參考窄兩成）
        wrap(arm, n, P, A, R, 0.0085, sp)
    if thumb_along is None:
        # 拇指貼著握把另一側繞過去，指尖停在食指指尖旁邊，跟食指合成一個圈（參考圖的握法）。
        # 以前要它離握把 2.4 公分以上、壓到中指外面，結果繞不回來，平平往外伸（疊圖看得最清楚）
        q = head(arm, 'Index_Distal')
        on_axis = P + A * (q - P).dot(A)
        thumb_to(arm, q.lerp(on_axis, THUMB_IN), P, A, R, rad=0.008, tip_bend=10, apart=0.008, hug=HUG, mc_pull=MC_PULL)   # 指尖到食指最後一個關節旁，圈才合得起來   # 不穿進四指那圈；最後一節多彎，輪廓看得到
    else:
        thumb_to(arm, far_side(P, A, R, thumb_along), P, A, R)


def pose_ref(arm, which=None, fingers=('Thumb', 'Index', 'Middle', 'Ring', 'Little'), keep=False):
    """比對專用：照抄參考握槍時每節骨頭的方向（docs/image/hand_pose_grip.json，tools/hand_ref.py 存的，手自己的座標），
    兩邊姿勢一樣，疊圖比的才是形狀。遊戲不用這個姿勢"""
    import json, hand_views
    dirs = json.load(open(os.path.join(os.path.dirname(BASE), 'docs/image/hand_pose_grip.json')))
    if which:   # '_open'：參考張開時的方向
        dirs = dirs[which]
    if not keep:
        reset(arm)
    wrist, fwd, side, normal, L = hand_views.hand_frame(rig_points(arm))
    for f in fingers:
        for s in ('_Proximal', '_Intermediate', '_Distal'):
            pb = arm.pose.bones[f + s]
            bpy.context.view_layer.update()
            d = dirs[f + s]
            want = (fwd * d[0] + side * d[1] + normal * d[2]).normalized()
            m = pb.matrix.copy()
            cur = (m.to_3x3() @ Vector((0, 1, 0))).normalized()   # 骨頭沿自己的 +Y
            q = cur.rotation_difference(want)
            pb.matrix = Matrix.Translation(m.translation) @ q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def pose_support(arm):
    pose_grip(arm, SUP_P, SUP_AXIS, SUP_R, thumb_along=0.045)


def pose_load(arm):
    """捏子彈：拇指和食指指尖碰在一起，其他三指收進掌心"""
    reset(arm)
    for n in ('Middle', 'Ring', 'Little'):
        bend(arm, n + '_Proximal', 75, 3)
        bend(arm, n + '_Intermediate', 95)
        bend(arm, n + '_Distal', 60)
    bpy.context.view_layer.update()
    # 食指彎幾種角度，每種讓拇指去碰（跟握槍同一個搜尋；沒有握把要避開，軸放在很遠的地方），留指尖最近的
    best = None
    for p0 in (30, 45, 60, 75):
        for p1 in (30, 50, 70):
            bend(arm, 'Index_Proximal', p0, -2)
            bend(arm, 'Index_Intermediate', p1)
            bend(arm, 'Index_Distal', p1 * 0.5)
            bpy.context.view_layer.update()
            thumb_to(arm, tip(arm, 'Index_Distal'), Vector((9, 9, 9)), Vector((0, 0, 1)), 0.0, rad=0.0)
            d = (tip(arm, 'Thumb_Distal') - tip(arm, 'Index_Distal')).length
            if best is None or d < best[0]:
                best = (d, p0, p1)
    _, p0, p1 = best
    bend(arm, 'Index_Proximal', p0, -2)
    bend(arm, 'Index_Intermediate', p1)
    bend(arm, 'Index_Distal', p1 * 0.5)
    bpy.context.view_layer.update()
    thumb_to(arm, tip(arm, 'Index_Distal'), Vector((9, 9, 9)), Vector((0, 0, 1)), 0.0, rad=0.0)
    return (tip(arm, 'Thumb_Distal') + tip(arm, 'Index_Distal')) / 2


# ---------------- 烘成遊戲用的網格 ----------------
def _basis(a, b, c):
    return Matrix((a, b, c)).transposed()


def place(src_a, src_u, dst_a, dst_u, origin):
    """手的空間 → 遊戲座標：src_a 對到 dst_a、src_u（垂直 a 的部分）對到 dst_u，origin 搬到原點"""
    a = src_a.normalized()
    u = (src_u - a * src_u.dot(a)).normalized()
    da = dst_a.normalized()
    du = (dst_u - da * dst_u.dot(da)).normalized()
    R = _basis(da, du, da.cross(du)) @ _basis(a, u, a.cross(u)).inverted()
    return R.to_4x4() @ Matrix.Translation(-origin)


def bake(objs, M, mirror=False, scale=SCALE):
    """把目前姿勢的網格（套完骨架和細分）乘上 M，回傳 {零件: bmesh}"""
    dg = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    for o in objs:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        me.transform(o.matrix_world)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        me2 = bpy.data.meshes.new('tmp')
        tmp.to_mesh(me2)
        bm.from_mesh(me2)
        bpy.data.meshes.remove(me)
        bpy.data.meshes.remove(me2)
    M = Matrix.Scale(scale, 4) @ M
    if mirror:
        M = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ M
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    if mirror:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    return bm


def split(bm, parts):
    """照 part 屬性切開：parts = {名字: (零件編號們)}"""
    lay = bm.faces.layers.int.get('part')
    out = {}
    for name, ids in parts.items():
        b = bm.copy()
        l2 = b.faces.layers.int.get('part')
        bmesh.ops.delete(b, geom=[f for f in b.faces if f[l2] not in ids], context='FACES')
        out[name] = b
    return out


def to_object(name, bm, mats, origin=Vector()):
    bmesh.ops.translate(bm, vec=-origin, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)   # 鏡射過的左手要翻回來
    used = sorted({f.material_index for f in bm.faces})
    for f in bm.faces:
        f.material_index = used.index(f.material_index)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    for i in used:
        me.materials.append(mats[i])
    ob = bpy.data.objects.new(name, me)
    ob.location = origin
    bpy.context.scene.collection.objects.link(ob)
    smooth_by_angle(ob)
    return ob


ARM_R = Vector((0.22, -0.55, -0.80))   # 跟以前一樣：長槍舉起來時握把在鏡頭正下方，手臂往右後下方伸出畫面
ARM_L = Vector((-0.20, -0.85, -0.45))   # 托護木：前臂順著手掌往後下方，手腕不要折出一個平台


def build(mats, keep_rig=False):
    """mats = [手套, 風衣]。回傳五個遊戲用的物件"""
    skin, arm = build_rig()
    wear = build_wear(arm)
    objs = [skin, wear]
    out = []

    # 握槍：握把軸 → +Z（食指在上），掌心朝握把 → -X（手在握把右側）
    pose_grip(arm)
    M = place(GRIP_AXIS, Vector((0, 0, -1)), Vector((0, 0, 1)), Vector((-1, 0, 0)), Vector())
    c = GRIP_P + GRIP_AXIS * ((Vector((0.0, 0.05, 0)) - GRIP_P).dot(GRIP_AXIS) + 0.009)   # 原點：握把軸上、手的中段偏上（手低一點，瞄準時不擋準星）
    M = M @ Matrix.Translation(-c)
    aim_forearm(arm, (M.to_3x3().inverted() @ ARM_R))
    parts = split(bake(objs, M), {'HandGrip': (0,), 'HandGripThumb': (1,), 'HandGripArm': (2,)})
    thumb_at = Matrix.Scale(SCALE, 4) @ M @ head(arm, 'Thumb_Intermediate')   # 轉軸也要跟著縮（bake 裡縮的）
    wrist_at = Matrix.Scale(SCALE, 4) @ M @ Vector((0, 0, 0))
    out.append(to_object('HandGrip', parts['HandGrip'], mats))
    out.append(to_object('HandGripThumb', parts['HandGripThumb'], mats, thumb_at))
    out.append(to_object('HandGripArm', parts['HandGripArm'], mats, wrist_at))

    # 托護木（左手）：先用右手擺，最後鏡射。護木軸 → +Y，掌心朝上 → +Z
    pose_support(arm)
    M = place(SUP_AXIS, Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector())
    c = SUP_P + SUP_AXIS * (Vector((0.0, 0.05, 0)) - SUP_P).dot(SUP_AXIS)
    M = M @ Matrix.Translation(-c)
    mirror = Vector((-ARM_L.x, ARM_L.y, ARM_L.z))
    aim_forearm(arm, (M.to_3x3().inverted() @ mirror))
    out.append(to_object('HandSupport', bake(objs, M, mirror=True), mats))

    # 捏子彈（左手）：指尖朝前上方，手背朝左上
    pinch = pose_load(arm)
    M = place(Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((-0.25, 0.85, 0.45)), Vector((0.75, 0.1, 0.65)), pinch)
    aim_forearm(arm, (M.to_3x3().inverted() @ Vector((-ARM_L.x, ARM_L.y, ARM_L.z))))
    out.append(to_object('HandLoad', bake(objs, M, mirror=True), mats))

    reset(arm)
    if keep_rig:   # 預覽要拿骨架擺姿勢
        for o in (skin, wear, arm):
            o.hide_render = True
        globals()['RIG'] = (skin, wear, arm)
    else:          # cowboy.py 匯出全部網格，骨架和原始的皮不能留
        for o in (skin, wear, arm):
            bpy.data.objects.remove(o)
    return out


def rig_points(arm):
    out = {n: arm.matrix_world @ pb.head for n, pb in arm.pose.bones.items()}
    for n, pb in arm.pose.bones.items():
        if n.endswith('_Distal'):   # 指尖
            out[n.split('_')[0] + '_tip'] = arm.matrix_world @ pb.tail
    return out


def preview(path):
    """六格對照預覽（跟 docs/image/hand.png 同一套鏡頭）"""
    import hand_views
    skin, wear, arm = RIG
    hand_views.paint_parts(skin, lambda g: g if g in hand_views.PARTS else ('Arm' if g == 'LowerArm' else g))
    hand_views.paint_parts(wear, lambda g: 'Arm')
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = True
    mats = [bpy.data.materials.new('pv0'), bpy.data.materials.new('pv1')]

    def pose(p):   # 擺好姿勢後烘一份跟遊戲一樣的網格（含硬邊）來渲染，預覽 = 遊戲
        # HAND_GRIP=ref：握槍那排改用參考的姿勢（比對形狀用，tools/model_iter.sh 出的圖檔名自己加 ref）
        (pose_open if p == 'open' else (pose_ref if os.environ.get('HAND_GRIP') == 'ref' else pose_grip))(arm)
        old = bpy.data.objects.get('_preview')
        if old:
            bpy.data.objects.remove(old)
        pv = to_object('_preview', bake([skin, wear], Matrix.Identity(4), scale=1.0), mats)
        if pv.data.color_attributes.get('part_id'):
            pv.data.color_attributes.active_color = pv.data.color_attributes['part_id']
    hand_views.render_sheet(pose, lambda: rig_points(arm), path)


if __name__ == '__main__':
    import pipeline
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)

    def m(name, rgb):
        mt = bpy.data.materials.new(name)
        mt.diffuse_color = (*rgb, 1)
        return mt
    MATS = [m('c_glove', (0.075, 0.045, 0.028)), m('c_duster', (0.11, 0.08, 0.05))]
    pipeline.run(lambda: build(MATS, keep_rig=True), lambda obs, p: preview(p), budget=4000, export_fn=lambda obs, out: None)
