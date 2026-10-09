# 第一人稱的手：一整張連續的手套皮＋骨架（骨頭照 FNE_project 那隻手：手腕、每指三節、拇指三節、前臂），
# 擺好姿勢後烘成遊戲用的固定網格，名字跟以前 cowboy.py 拼的方塊手一樣，遊戲程式不用改：
#   HandGrip       握槍把的右手（原點在握把軸上、手的中間高度；握把沿 Z 直立，手背朝 +X，食指在上）
#   HandGripThumb  右手拇指（原點在拇指根部的關節，節點位置就是它在 HandGrip 裡的位置；左輪扳擊錘時轉它）
#   HandGripArm    右手前臂、手套袖口、風衣袖子（原點在手腕，往 ARM_R 伸出畫面）
#   HandSupport    托護木的左手（原點在護木軸上；護木沿 Y，掌心朝上托在下面，手指從 +X 側往上包）
#   HandLoad       換彈拿子彈的左手（原點在子彈中心，子彈沿 +Y：拇指頂彈底、食指中指搭在側面）
#
# 做法：
#   1. 在「手的空間」建手：手腕在原點、手指朝 +Y、手背朝 +Z、右手（拇指在 -X）。
#      照 ShionMgr 的分件擠出法（知識庫「分件擠出的手」）：手掌是一塊扁方塊，寬度一根手指三欄（左、中、右），
#      側面中間一個點；指節那面是 3×3 的格子，每根手指挖掉中間那點、剩 8 個點的洞，手指是八邊形柱子從洞長出去；
#      相鄰兩根手指之間留一欄窄的指縫面，不共用頂點。拇指從手掌側面 2×2 的洞長出去。
#      關節前後各一圈支撐圈（線集中在關節）；指甲是指尖上面兩片內縮再往下壓。最後細分一次。
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
XS3 = [x for i in range(4) for x in (XS[2 * i], FINGER_X[i], XS[2 * i + 1])]   # 手掌手背那排 12 欄：每根手指左、中、右
NP = len(XS3)
RING_N = 2 * NP + 2    # 指節那圈：手背 12（食指 → 小指）、小指側 1、掌心 12（小指 → 食指）、食指側 1
SIDE_I = RING_N - 1    # 指節那圈食指側那點
SIDE_L = NP            # 指節那圈小指側那點
# 手掌、前臂的圈只有指縫兩邊那 8 欄（面數：手指的中間欄只在指節那圈出現，接上去是五邊形）
NPP = len(XS)
RING_P = 2 * NPP + 2
SIDE_PI = RING_P - 1   # 手掌圈食指側那點（拇指的洞在這一側）
DIAG = 0.80            # 八邊形斜角那四點離中心多遠（0.707 是正八邊形）：方一點，手背那面有自己的受光面
NAIL = (0.0009, 0.00055)  # 審查：0.6 mm 像挖一個洞、0.3 mm 正常大小看不到   # 指甲：內縮多寬、往下壓多深（公尺）
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
# 前臂的厚度（手背到掌心）照參考量：拇指側看手腕 85 px、往手肘到 140 px，以前只有 58～68 px（使用者：太細）。
# 參考的手背那面從手背到前臂幾乎是一直線，變厚都長在掌心那面（前臂的肌肉）；手背 z 不動、掌心 z 往下長
PALM = [(-0.380, 1.30, 0.028, -0.072, 0.0),   # 前臂後段：往手肘漸粗、變厚（捲起的袖子蓋在這裡）
        (-0.110, 0.92, 0.024, -0.060, 0.0),   # 前臂肌肉開始鼓起的地方。前臂的圈一圈 26 點，只留三圈控制形狀（面數）
        (-0.004, 0.68, 0.0235, -0.0265, -0.001),   # 手腕：寬照舊（疊圖手背看剛好），厚多四成
        (0.006, 0.71, 0.0190, -0.0215 - HEEL * 0.3, -0.001),   # 手腕往手掌過渡那圈（握槍時手腕彎，這裡分攤彎折）
        (0.016, 0.78, 0.019, -0.025 - HEEL, -0.001),   # 手腕往上收窄早一點（手背看這段比參考寬 15%）     # 掌根：掌心那面加厚 HEEL（疊圖量出這段薄 19~22 px）
        (0.032, 0.94, 0.019, -0.0255 - HEEL * 0.5, -0.001),   # 拇指的洞是 2×2：要三圈
        (0.048, 1.00, 0.019, -0.026, -0.001)
]
THENAR = 0.0055                        # 拇指根那團肉：手掌靠拇指那側的掌心再鼓出來
KNUCKLE_Z = (0.0128, -0.0048)          # 指節那圈的手背、掌心 z（手指根部的厚度跟手指一樣粗才不會掐一圈；整圈往手背抬 4 mm，
                                       # 手背到指節才是一條直線再折下去，不然手背是一顆蛋、看不出第一節從哪開始）
THUMB_PORT = (4, 5, 6)                 # 拇指的洞：這三圈食指側的上下兩片面（2×2），中間那點不要（PALM 的索引，含前臂）
THUMB_PORT_FOLLOW = 0.7   # 拇指開口那圈跟拇指走的比例
KNUCKLE_BUMP = (0.0035, 0.0012)   # 指節那圈往手背抬：每根手指中間那點、左右兩點（1.5 mm 只抬中間被細分抹平，審查第 30 版）
JOINT_SHRINK = 0.95       # 手指兩個關節那圈的粗細
JOINT_LIFT = (0.0008, 0.0005)   # 兩個關節那圈往手背推多少
THUMB_ROOT = (-0.0204, 0.0427, -0.0223)   # 參考：手腕為原點，往前 0.23、往食指側 0.11、往掌心 0.12 個手長（手長 0.186 m）
THUMB_LEN = _split(0.093, (0.24, 0.45, 0.30))   # 照參考骨架比例：掌骨短、後兩節長（以前掌骨佔四成）      # 掌骨要夠長，握緊時拇指才搆得到中指（短了只能平伸出去）      # 掌骨露出來的那段、第一節、第二節
THUMB_R = 0.0155
THUMB_TAPER = (1.05, 1.0, 0.9, 0.75)   # 根部那圈放大，融進拇指根那團肉（虎口才有曲線）
# 張開時拇指的方向：往前、往掌心，只往外一點（疊圖：往側邊張 45 度像海星，參考圖的拇指收在手掌前方）
THUMB_DIR = Vector((-0.20, 0.62, -0.76)).normalized()   # 從手背看拇指要藏在手掌後面（x 小）
_n = Vector((-0.80, -0.10, 0.45))
THUMB_NAIL = (_n - THUMB_DIR * _n.dot(THUMB_DIR)).normalized()   # 拇指指甲朝哪（拇指自己的手背方向，跟拇指垂直）


NAILS = {}   # 四指每節骨頭的「指甲朝哪」（彎好的手指每節不一樣，骨頭的彎曲軸照它定）


_OCT = [(-1, 0), (-DIAG, DIAG), (0, 1), (DIAG, DIAG), (1, 0), (DIAG, -DIAG), (0, -1), (-DIAG, -DIAG)]


def _ring(c, d, up, hw, hh, lift=0.0):
    """八邊形斷面：中心 c、沿 d、上面朝 up；回傳 8 個點（繞一圈）。
    lift：整圈往手背那面推（關節那圈手背凸一點）"""
    d = d.normalized()
    s = up.cross(d).normalized()          # 右手邊
    u = d.cross(s).normalized()
    c = c + u * lift
    return [c + s * (hw * x) + u * (hh * z) for x, z in _OCT]


def _match(prev, ring):
    """把 ring 的順序轉成跟 prev 最對齊（兩圈接起來才不會扭成麻花）；繞的方向相反也試"""
    n = len(ring)
    cands = [ring[k:] + ring[:k] for k in range(n)]
    rev = ring[::-1]
    cands += [rev[k:] + rev[:k] for k in range(n)]
    return min(cands, key=lambda r: sum((r[i] - prev[i]).length for i in range(n)))


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.part = self.bm.faces.layers.int.new('part')   # 0 手、1 拇指、2 前臂
        self.soft = self.bm.faces.layers.int.new('soft')   # 1：這面不套硬邊（指尖圓頂、指縫、拇指根的肉）
        self.hard = self.bm.edges.layers.int.new('hard')   # 1：一定是硬邊（手掌兩側的長邊）
        self.groups = []
        self.nails = []   # 要內縮成指甲的面

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
        return [self.quad(r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i], part, mat, soft) for i in range(n)]

    def tube(self, root, joints, radii, nail_up, names, part0, part_from=1, cap=True, bump=False, soft_root=False):
        """從 root（已經存在的 8 個點）沿關節 joints=[J0, J1, J2, J3] 長一根方管手指。
        names = 三節骨頭的名字。每節兩端各一圈支撐圈全屬那節（骨節是直的），只有關節那圈兩節各半，
        彎曲只發生在關節前後幾 mm——不然細分後整根手指彎成一條平滑的弧，像水管，看不出一節一節。指尖三圈收小再封口。
        part0：從第 part_from 節開始算成 part0 這個零件（拇指的掌骨那節算手）。
        soft_root：第一節不套硬邊（拇指根那團肉接手掌，套了會折出一道細線）"""
        prev = [v.co.copy() for v in root]
        root_c = sum(prev, Vector()) / len(prev)
        rings = [root]
        stations = []
        if bump:   # 指節：開口最前端再過去 3 mm 那圈往兩旁寬一點（握拳時拳頭上緣那排連成一條；往手背凸的話張開時會變一道折痕）。
            # 開口是斜的（掌心那面的指蹼比較長），放在開口中心後面會落到開口裡面、折回來把指根掐出一圈細脖子
            d0 = (joints[1] - joints[0]).normalized()
            front = max((v.co - root_c).dot(d0) for v in root)
            stations.append((root_c + d0 * (front + 0.003), d0, (radii[0] * 1.05, radii[0] * 0.95),
                             [(names[0], 1.0)], 0, 0.002))   # 全跟第一節走：指根的大關節才折得出角度；往手背凸，握拳時是一排指節
        nail_from = None
        G = 0.0015   # 支撐圈離關節多遠：越近轉角越利（2.8 mm 時還像彎過的軟管）
        for k in range(3):
            a, b = joints[k], joints[k + 1]
            e = (b - a).normalized()
            r_a, r_b = radii[k], radii[k + 1]
            pk = part0 if k >= part_from else 0
            w = [(names[k], 1.0)]
            if k > 0:   # 這節的起點支撐圈（最後一節也要：第 29 版拿掉後最後一個關節的折痕不見，只看得出兩節）
                stations.append((a + e * G, b - a, r_a, w, pk, 0.0))
            # 每節中間不加圈（八邊形本來就圓，線集中在關節前後）；只有最後一節要一圈給指甲起頭
            # （最後一節離開口很遠，不用檢查指蹼；手指先彎好了，用這節方向量會是負的、反而把這圈丟掉）
            if k == 2:
                stations.append((a.lerp(b, 0.5), b - a, (r_a + r_b) / 2 * 0.96, w, pk, 0.0))
                nail_from = len(stations) - 1   # 指甲從最後一節中間開始
            if k < 2:   # 這節的終點支撐圈，再來是關節那圈（兩節各半；彎 90 度時會被壓扁，先放大一點、手背那面凸一點當指節）
                stations.append((b - e * G, b - a, r_b, w, pk, 0.0))
                # 關節那圈縮一點、往手背推：形狀上有內收和凸起，手背、拇指側也看得出三節（審查：只有深淺像水管）。
                # 推太多伸直時硬邊會把整節切出來（掌心那面像戴了頂針），所以只推 0.5～0.8 mm
                lift = JOINT_LIFT[k]
                stations.append((b, joints[k + 2] - a, r_b * JOINT_SHRINK, [(names[k], 0.5), (names[k + 1], 0.5)], pk, lift))
        a, b = joints[2], joints[3]
        e = (b - a).normalized()   # 指尖：三圈收口（0.92 → 0.58 → 0.25），不是一顆比手指還大的球
        nail_to = len(stations)   # 指甲：最後一節中間那圈到指尖這圈之間
        # 指尖只留一圈，直接用八邊形封口：細分後自己會變圓頂（以前三圈收口；面數不夠，加指甲之後砍掉）
        stations.append((b - e * 0.003, b - a, radii[3] * 0.92, [(names[2], 1.0)], part0, 0.0))
        # 落在開口後面（或離開口不到 4 mm）的圈不建：轉軸在手掌深處時（拇指根），那幾圈會在開口後面摺回來、掐出一道凹痕
        d0 = (joints[-1] - joints[0]).normalized()
        n_all = len(stations)
        keep = [k for k in range(n_all) if k >= n_all - 1 or (stations[k][0] - root_c).dot(d0) > 0.004]
        nail_from = keep.index(nail_from) if nail_from in keep else None
        nail_to = keep.index(nail_to)
        stations = [stations[k] for k in keep]
        n_tip = 0   # 指尖圓頂只有封口那片，封口本來就不套硬邊（套了會切成幾塊平面，像戴頂針）
        for i, (c, d, r, w, pk, lift) in enumerate(stations):
            hw, hh = r if isinstance(r, tuple) else (r, r * 0.85)   # 斷面偏扁：手背那面有自己的受光面
            # 斷面的「上面」照這圈所屬骨頭的指甲方向：手指先彎好了，最後一節彎過 90 度，
            # 用固定的 nail_up 會把手背、掌心弄反（第 29 版指甲長在掌心那面）
            up = sum((NAILS.get(bn, nail_up) * bw for bn, bw in w), Vector())
            up = up.normalized() if up.length > 1e-6 else nail_up
            pts = _match(prev, _ring(c, d, up, hw, hh, lift))
            ring = [self.vert(p, w) for p in pts]
            first = soft_root and w[0][0] == names[0] and len(w) == 1
            # 從開口接到第一圈那段算手：拇指的轉軸在手掌深處，前幾圈落在開口後面被濾掉，
            # 這段被拉長的面算成拇指的話，切開後拇指根會多一片尖尖的皮（MCP 繞一圈看到的）
            fs = self.bridge(rings[-1], ring, pk if i > 0 else 0, soft=int(i >= len(stations) - n_tip or first))
            if nail_from is not None and nail_from < i <= nail_to:   # 指甲：手背那面正中兩片（烘之前才內縮，見 build_rig）
                u = d.normalized().cross(up.cross(d.normalized())).normalized()
                cc = sum(pts, Vector()) / len(pts)
                dn = d.normalized()
                def radial(f):   # 面中心離軸的方向（扣掉沿手指那個分量：面在兩圈中間，不扣的話往後偏、永遠不算朝上）
                    v = f.calc_center_median() - cc
                    return (v - dn * v.dot(dn)).normalized()
                self.nails += [f for f in fs if radial(f).dot(u) > 0.75]
            rings.append(ring)
            prev = pts
        if cap:
            f = self.bm.faces.new(rings[-1])
            f[self.part] = part0
            f[self.soft] = 1
        return rings


def palm_ring(st, knuckle=False):
    """手掌一圈：手背（食指 → 小指）、小指側 1、掌心（小指 → 食指）、食指側 1。
    指節那圈每根手指三欄（左中右，共 12），其他圈只有指縫兩邊（共 8）"""
    y, s, zt, zb, cx = st
    xs = XS3 if knuckle else XS
    n = len(xs)
    if y < 0:   # 手腕和前臂：圓的斷面（方的四個角會穿出袖口），點平均分在橢圓上
        hw, hh, cz = xs[-1] * s, (zt - zb) / 2, (zt + zb) / 2
        th = [math.pi - (j + 1) * math.pi / (n + 1) for j in range(n)] + [0.0] + \
             [-(j + 1) * math.pi / (n + 1) for j in range(n)] + [math.pi]
        return [Vector((cx + hw * math.cos(t), y, cz + hh * math.sin(t))) for t in th]
    top, bot = [], []
    for j, x in enumerate(xs):
        x2 = cx + x * s
        if knuckle:
            yk = KNUCKLE_Y[j // 3]
            # 每根手指中間那點往手背抬：握拳時手背讀得出四顆指節（審查：拿掉指節凸圈後像連指手套）
            top.append(Vector((x2, yk + WEB[0], zt + KNUCKLE_BUMP[0 if j % 3 == 1 else 1])))
            bot.append(Vector((x2, yk + WEB[1], zb)))
            continue
        if j == 0 and y > 0.03:   # 虎口上緣（食指根下方、靠拇指那側）往外寬一點：疊圖量出這段窄 15~18 px
            x2 -= WEB_WIDEN
        edge = j in (0, n - 1)
        arch = 0.0016 * (1 - (2 * j / (n - 1) - 1) ** 2)   # 手背幾乎是平的：側面看得到手背在指節處折下去
        thenar = (THENAR if (j <= 2 and 0.01 < y < 0.06) else 0.0) + (HEEL_THENAR if (j <= 2 and 0.01 < y < 0.02) else 0.0)
        top.append(Vector((x2, y, zt + arch - (0.003 if edge else 0))))
        bot.append(Vector((x2, y, zb - thenar + (0.003 if edge else 0))))
    # 側面中間那點：上下兩點的中間再往外 1.5 mm，側面才是圓的（不是一條折線）
    def side(t, b_, out):
        if knuckle:
            return Vector((t.x, (t.y + b_.y) / 2, (t.z + b_.z) / 2))
        return (t + b_) / 2 + Vector((out, 0, 0))
    return top + [side(top[-1], bot[-1], 0.0015)] + bot[::-1] + [side(top[0], bot[0], -0.0015)]


def _to_knuckle():
    """手掌圈（RING_P 點）每個點對到指節圈（RING_N 點）的哪個點：指縫兩邊的欄對到每根手指的左、右欄"""
    t = [3 * (j // 2) + (0 if j % 2 == 0 else 2) for j in range(NPP)]
    return t + [SIDE_L] + [2 * NP - t[NPP - 1 - q] for q in range(NPP)] + [SIDE_I]


def build_rig():
    """建手的網格和骨架（手的空間、靜止姿勢）。回傳 (網格物件, 骨架物件, 關節表)"""
    B = Builder()
    joints = {}
    # 手掌＋前臂
    rings = []
    port = set(zip(THUMB_PORT, THUMB_PORT[1:]))
    for i, st in enumerate(PALM):
        # 手腕那圈（袖口裡面）全跟前臂走：手腕彎的時候皮才不會被推出袖口（以前袖口前緣的鋸齒就是這個）
        # 手腕和手掌之間那圈兩根骨頭各半：握槍時手腕彎得最多，只有兩圈的話彎折處會折出一個角
        w = [('LowerArm', 1.0)] if st[0] < 0.0 else ([('LowerArm', 0.5), ('Hand', 0.5)] if st[0] < 0.01 else [('Hand', 1.0)])
        ring = [B.vert(p, w) for p in palm_ring(st)]
        if rings:
            part = 2 if st[0] <= 0.0 else 0
            for k in range(RING_P):
                if (i - 1, i) in port and k in (SIDE_PI - 1, SIDE_PI):   # 食指側上下兩片留給拇指的洞
                    continue
                # 食指那側（側面那點上下兩片＋掌心最外一片）不套硬邊：拇指根的肉往掌心鼓，夾角超過門檻，
                # 從小指側看握槍的手，掌心會有一條長長的黑線（審查第 29、30 版）
                B.quad(rings[-1][k], rings[-1][(k + 1) % RING_P], ring[(k + 1) % RING_P], ring[k], part,
                       soft=int((i in THUMB_PORT or st[0] > 0.0) and k >= SIDE_PI - 3))
            if st[0] > 0.01:   # 手掌兩側的長邊（手背轉到側面那條）是硬邊：側面讀成一個平面，跟分面的手指同一種風格
                B.bm.edges.get((rings[-1][NPP - 1], ring[NPP - 1]))[B.hard] = 1   # 只有小指那側（食指那側接拇指根，硬邊會變一條鋸齒裂痕）
        rings.append(ring)

    # 指節那面：3×3 的格子。指節那圈三成跟手、七成跟自己那根手指的第一節（全跟手的話，握拳時指縫被兩邊拉扯，折出碎三角形）
    def fw(i):
        return [('Hand', 0.3), (FINGERS[i][0] + '_Proximal', 0.7)]
    kp = palm_ring((0, 1, KNUCKLE_Z[0], KNUCKLE_Z[1], 0), knuckle=True)
    owner = [j // 3 for j in range(NP)] + [3] + [(NP - 1 - j) // 3 for j in range(NP)] + [0]
    kn = [B.vert(p, fw(owner[j])) for j, p in enumerate(kp)]
    # 手掌最後一圈（8 欄）接指節那圈（12 欄）：每根手指那格多一個中間點，是五邊形
    m = _to_knuckle()
    last = rings[-1]
    for k in range(RING_P):
        a_, b_ = m[k], m[(k + 1) % RING_P]
        span = [kn[(a_ + t) % RING_N] for t in range((b_ - a_) % RING_N + 1)]
        f = B.bm.faces.new([last[k], last[(k + 1) % RING_P]] + span[::-1])
        f[B.part] = 0
    bot = lambda j: kn[2 * NP - j]   # 掌心那排第 j 欄（食指 → 小指數）
    mid = []   # 每根手指左、右的中間點（食指左 = 食指側那點、小指右 = 小指側那點）
    for i in range(4):
        def mpt(j):
            t, b_ = kn[j].co, bot(j).co
            return B.vert((t + b_) / 2, fw(i))
        mid.append((kn[SIDE_I] if i == 0 else mpt(3 * i), kn[SIDE_L] if i == 3 else mpt(3 * i + 2)))
    for i in range(3):   # 指縫：相鄰兩根手指之間一欄窄的面（上下兩片），不共用頂點
        B.quad(kn[3 * i + 2], kn[3 * i + 3], mid[i + 1][0], mid[i][1], soft=1)
        B.quad(mid[i][1], mid[i + 1][0], bot(3 * i + 3), bot(3 * i + 2), soft=1)
    # 前臂後端封口：會動的手轉前臂時（weapon.gd 的 pinch_arm_dir）會從開口看進去，出現一圈白線
    f = B.bm.faces.new(rings[0][::-1])
    f[B.part] = 2
    joints['Hand'] = (Vector((0, 0, 0)), Vector((0, 0.05, 0)))
    joints['LowerArm'] = (Vector((0, 0, 0)), Vector((0, -0.26, 0)))
    # 四根手指：每根從自己 8 個點的洞長出去（上排左中右、右中、下排右中左、左中）
    for i, (name, lens, splay) in enumerate(FINGERS):
        j = 3 * i
        root = [kn[j], kn[j + 1], kn[j + 2], mid[i][1], bot(j + 2), bot(j + 1), bot(j), mid[i][0]]
        c = sum((v.co for v in root), Vector()) / len(root)
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
        B.tube(root, js, radii, Vector((0, 0, 1)), names, 0)   # 不加指節凸圈：3×3 的洞本身就撐出指節的形
        for k, n in enumerate(names):
            joints[n] = (js[k], js[k + 1])
    # 拇指：從手掌食指側 2×2 的洞長出去（中間那點不用）
    ra, rb, rc = (rings[k] for k in THUMB_PORT)
    root = [ra[0], rb[0], rc[0], rc[SIDE_PI], rc[SIDE_PI - 1], rb[SIDE_PI - 1], ra[SIDE_PI - 1], ra[SIDE_PI]]
    B.bm.verts.remove(rb[SIDE_PI])
    # 開口那圈一部分跟拇指走：拇指的轉軸在手掌深處，開口只跟手的話，拇指一轉接縫就被扯出凹痕
    for v in root:
        # 靠手腕那圈（ra）只跟一半：拇指洞下緣離手腕只有 1 公分，跟太多會把手腕拇指側扯出夾縫（審查第 30 版）
        f_ = THUMB_PORT_FOLLOW * (0.5 if v in ra else 1.0)
        v[B.dl][B.g('Hand')] = 1.0 - f_
        v[B.dl][B.g('Thumb_Proximal')] = f_
    c = sum((v.co for v in root), Vector()) / len(root)
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
    # 指甲：手背那面正中兩片內縮一圈、再往下壓（影片 0:52）。法線要先算好，往下壓才是往裡
    bmesh.ops.inset_region(B.bm, faces=B.nails, thickness=NAIL[0], depth=-NAIL[1], use_even_offset=True)
    # 指甲外框：細分會把內縮抹平（第 28 版完全看不到），外框設成細分不磨圓（crease）＋硬邊
    crease = B.bm.edges.layers.float.get('crease_edge') or B.bm.edges.layers.float.new('crease_edge')
    nails = set(B.nails)
    for e in {e for f in nails for e in f.edges}:
        if sum(f in nails for f in e.link_faces) == 1:
            e[crease] = 1.0
            e[B.hard] = 1
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


def forearm_at(y):
    """前臂在 y（手的空間，手腕往後是負的）的半寬、半厚、中心高度：照 PALM 前臂那幾圈線性內插，超出就沿用最後一圈"""
    st = [p for p in PALM if p[0] < 0.0]
    y = min(max(y, st[0][0]), st[-1][0])
    for a, b in zip(st, st[1:]):
        if a[0] <= y <= b[0]:
            t = (y - a[0]) / (b[0] - a[0])
            sc, zt, zb = (a[k] + (b[k] - a[k]) * t for k in (1, 2, 3))
            return XS[-1] * sc, (zt - zb) / 2, (zt + zb) / 2
    a = st[0]
    return XS[-1] * a[1], (a[2] - a[3]) / 2, (a[2] + a[3]) / 2


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
        f = bm.faces.new(rs[-1])   # 袖子尾端封口（轉前臂時看得到開口）
        f[part] = 2
        f.material_index = mat

    # 捲起來的袖子：前臂後段一圈鼓起的布捲，後面接袖子伸出畫面。大小照那裡的前臂粗細乘倍率
    # （以前寫死的半徑比前臂還細，袖子整個埋在手臂裡看不到）
    def around(y, k):
        hw, hh, cz = forearm_at(y)
        return (y, hw * k, hh * k, cz)
    loft([around(-0.335, 1.03), around(-0.342, 1.14), around(-0.370, 1.20), around(-0.398, 1.14),
          around(-0.402, 1.07), around(-0.550, 1.12)], 1)
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


SEG_RAD = (0.0085, 0.0075, 0.006)   # 手指三節的粗細（半徑，指根最粗）：都用指根的粗細的話指尖永遠差幾公釐碰不到


def wrap_video(arm, f, dirs, P, A, R, max_splay=10):
    """照影片握圓柱（軸過 P、方向 A、半徑 R）：指根先照影片的方向（dirs，tools/hand_skeleton.py 抓的），
    再找指根多彎幾度、後兩節一共彎幾度（照 CURL 的比例分），讓中間那節和指尖都貼著圓柱、不穿進去，又盡量像影片。
    影片手指在握把後面被擋住的那幾節是猜的，所以只拿來當「盡量接近」，碰到圓柱優先。
    指根往側邊張最多 max_splay 度：握緊時手指往內收，照抄影片小指會往外張 22 度（第一輪骨架審查）"""
    pose_ref(arm, dirs=dirs, fingers=(f,), keep=True)
    pb = arm.pose.bones[f + '_Proximal']
    lim = math.radians(max_splay)
    x0, z0 = pb.rotation_euler.x, max(-lim, min(lim, pb.rotation_euler.z))
    names = [f + s for s in ('_Proximal', '_Intermediate', '_Distal')]
    want = sum(math.degrees(Vector(dirs[a]).angle(Vector(dirs[b]))) for a, b in zip(names, names[1:]))
    k1, k2 = CURL[1] / (CURL[1] + CURL[2]), CURL[2] / (CURL[1] + CURL[2])
    best = None
    for extra in range(-20, 41, 5):
        for total in range(20, 181, 10):
            pb.rotation_euler.x = x0 - math.radians(extra)
            pb.rotation_euler.z = z0
            bend(arm, f + '_Intermediate', total * k1)
            bend(arm, f + '_Distal', total * k2)
            bpy.context.view_layer.update()
            # 每節取中點和末端，各用那節的粗細
            ds = [_axis_dist(arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t), P, A) - R - r
                  for n, r in zip(names, SEG_RAD) for t in (0.5, 1.0)]
            pen = sum(max(0.0, -d) for d in ds)
            gap = max(0.0, ds[2]) + max(0.0, ds[5])   # 中間那節中點、指尖都要碰到（只看最近一點的話指尖會翹起來）
            c = pen * 10 + gap + (abs(extra) + abs(total - want)) * 2e-4
            if best is None or c < best[0]:
                best = (c, extra, total)
    _, extra, total = best
    pb.rotation_euler.x = x0 - math.radians(extra)
    pb.rotation_euler.z = z0
    bend(arm, f + '_Intermediate', total * k1)
    bend(arm, f + '_Distal', total * k2)
    bpy.context.view_layer.update()


TRIGGER_OUT = 0.015   # 扳機在握把前面離握把表面多遠
INDEX_MAX = (90, 100, 80)   # 食指三個關節最多彎幾度（人體上限）


def trigger_finger(arm, P, A, R):
    """食指搭在扳機上：扳機點在握把前面（掌心的另一側）、食指指根那個高度、離表面 TRIGGER_OUT。
    從伸直往上彎，讓最後一節的指腹碰到扳機點，不插進握把、不超過關節上限。
    以前包緊整根，跟拇指圍成一圈看不出在扳機上（第二輪區塊審查）；改成從 100 度往下找又把食指捲進掌心（第二輪骨架審查）"""
    u = Vector((0, 0, -1))
    u = (u - A * u.dot(A)).normalized()                     # 掌心 → 握把 → 握把前面
    root = head(arm, 'Index_Proximal')
    trig = P + A * (root - P).dot(A) + u * (R + TRIGGER_OUT)
    names = ('Index_Proximal', 'Index_Intermediate', 'Index_Distal')
    best = None
    for deg in range(0, 101, 4):
        flex = [min(deg * k, m) for k, m in zip(CURL, INDEX_MAX)]
        for n, d in zip(names, flex):
            bend(arm, n, d)
        bpy.context.view_layer.update()
        ds = [_axis_dist(arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t), P, A) - R - r
              for n, r in zip(names, SEG_RAD) for t in (0.25, 0.5, 1.0)]
        pb = arm.pose.bones['Index_Distal']
        pad_dir = -(arm.matrix_world.to_3x3() @ pb.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
        q = arm.matrix_world @ pb.head.lerp(pb.tail, 0.6) + pad_dir * SEG_RAD[2]
        c = (q - trig).length + sum(max(0.0, -d) for d in ds) * 10
        if best is None or c < best[0]:
            best = (c, flex)
    for n, d in zip(names, best[1]):
        bend(arm, n, d)
    bpy.context.view_layer.update()


def thumb_video(arm, dirs, P, A, R):
    """拇指照影片：指尖往影片拇指尖那個方向（繞握把的角度），但一律放到握把表面外 0.8 公分
    （影片的點懸在握把外 2.4 公分，拇指要貼握把就到不了、卡在格子邊界）；
    角度限制在離正前方 15～45 度：拇指沿握把側面往前上方伸、停在扳機上方的槍身旁（真人握左輪的位置）。
    再往前會壓到扳機上的食指；夾在 60～90 度拇指搆不到、三個轉角卡在格子邊界（第三、四輪骨架審查）"""
    pose_ref(arm, dirs=dirs, fingers=('Thumb',), keep=True)
    q = tip(arm, 'Thumb_Distal')
    on = P + A * (q - P).dot(A)
    front = Vector((0, 0, -1))
    front = (front - A * front.dot(A)).normalized()          # 掌心 → 握把 → 握把前面（扳機那側）
    side = A.cross(front).normalized()
    v = (q - on).normalized()
    ang = math.degrees(math.atan2(v.dot(side), v.dot(front)))
    ang = math.copysign(min(45.0, max(15.0, abs(ang))), ang)
    d = front * math.cos(math.radians(ang)) + side * math.sin(math.radians(ang))
    thumb_to(arm, on + d * (R + 0.008), P, A, R, rad=0.008, apart=0.008)


def aim_forearm(arm, d, max_dev=None):
    """前臂從手腕往 d（手的空間）伸出去。
    max_dev（度）：手腕往側邊（拇指、小指方向，手的空間 X）最多歪多少，多的不要。
    真人只能歪 20 度左右，托護木的左手照 ARM_L 伸會歪 52 度，看起來像手腕斷掉（使用者：左手扭曲很嚴重）；
    上下彎（掌心、手背方向）真人可以到 70 度，不限"""
    d = d.normalized()
    if max_dev is not None:
        rest_len = math.hypot(d.y, d.z)
        lim = math.tan(math.radians(max_dev)) * rest_len
        d = Vector((max(-lim, min(lim, d.x)), d.y, d.z)).normalized()
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
# 護木斜躺在掌心：從掌根（小指側）斜到食指根，跟手指方向差 35 度。以前 30 度（幾乎橫過手掌）時前臂只能跟槍垂直，
# 怎麼轉都伸不到鏡頭這邊，只能扳手腕（使用者：左手扭曲很嚴重、像反握）
SUP_ANGLE = 55
SUP_AXIS = Vector((-math.cos(math.radians(SUP_ANGLE)), math.sin(math.radians(SUP_ANGLE)), 0)).normalized()
SUP_P = Vector((0.0, 0.066, -0.014 - SUP_R))


OPEN_SPLAY = (-5, 0, 6, 9)


def pose_open(arm):
    reset(arm)
    # 四指幾乎平行（散成扇形看起來像在比「五」）；指根只微彎，食指中指最直（疊圖：彎多了手指往前倒、看起來變短）
    # 張開幅度：疊圖量出四指往中指靠攏 10~15 px，食指、無名指、小指再往外張
    for n, sp, p0, p1 in zip(FINGER_NAMES, OPEN_SPLAY, (0, 0, 8, 18), (14, 14, 24, 24)):   # 疊圖：拇指側看手指比參考多彎約 10 px
        bend(arm, n + '_Proximal', p0, sp)
        bend(arm, n + '_Intermediate', p1)
        bend(arm, n + '_Distal', 14)
    bpy.context.view_layer.update()
    pose_ref(arm, '_open', ('Thumb',), keep=True)   # 張開的拇指照抄參考張開時的方向（拇指根位置照參考擺了，角度也跟著抄）


def thumb_to(arm, target, P, A, R, rad=0.010, tip_bend=0, apart=0.0, hug=0.0, mc_pull=None, face=None, shell=None):
    """拇指在幾個角度裡找：指尖最靠近 target、又不穿進握把（圓柱）的姿勢。
    face：拇指指腹要朝這個方向（拿子彈時頂彈底；不給的話會用指甲那面頂）。
    shell=(彈底, 軸)：拿子彈用——避開的是那顆有限長的子彈（握把是無限長圓柱，拇指會永遠到不了彈底後面），
    格子也放寬（拇指要往外擺、伸直，原本的格子會被截在邊界，第六輪骨架審查）"""
    best = None
    pb = arm.pose.bones['Thumb_Proximal']
    index_tip = tip(arm, 'Index_Distal')
    for f in range(0, 91, 10):                 # 往掌心彎
        for tw in range(-45, 46, 15):          # 繞自己轉（對掌時拇指會轉過來）
            for o in range(-70 if shell else -40, 91, 10):       # 往掌心那側擺
                for m in ((0, 10, 30, 50, 70) if shell else (10, 30, 50, 70)):
                    pb.rotation_euler = (math.radians(-f), math.radians(tw), math.radians(o))
                    bend(arm, 'Thumb_Intermediate', m)
                    bend(arm, 'Thumb_Distal', m * 0.6 + tip_bend)
                    bpy.context.view_layer.update()
                    pts = [arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t)
                           for n in ('Thumb_Intermediate', 'Thumb_Distal') for t in (0.5, 1.0)]
                    if shell:
                        pts += [arm.matrix_world @ arm.pose.bones[n].head.lerp(arm.pose.bones[n].tail, t)
                                for n in ('Thumb_Intermediate', 'Thumb_Distal') for t in (0.25, 0.75)]
                        pen = sum(max(0.0, THUMB_PAD - 0.001 - _shell_dist(q, *shell)[0]) for q in pts)   # 比目標距離小，不然越靠近越罰、拇指會逃走
                    else:
                        pen = max(0.0, R + rad - min(_axis_dist(q, P, A) for q in pts))
                    cost = (pts[-1] - target).length + pen * 10
                    if mc_pull:   # 掌骨末端少往掌心前面（-Z）、多往食指那側（-X）：握槍時拇指根才不會在圈外凸一團
                        mc = arm.matrix_world @ arm.pose.bones['Thumb_Proximal'].tail
                        cost += mc_pull[0] * max(0.0, -mc.z) + mc_pull[1] * mc.x
                    if hug:   # 掌骨那節貼近握把：不然拇指根往外張成一個弧，握槍時在圈外凸一團（疊圖量出 20 px）
                        mc = arm.matrix_world @ arm.pose.bones['Thumb_Proximal'].tail
                        cost += hug * _axis_dist(mc, P, A)
                    if face is not None:   # 指腹（最後一節 -Z）朝 face，差 45 度以上開始罰
                        n = -(arm.matrix_world.to_3x3() @ arm.pose.bones['Thumb_Distal'].matrix.to_3x3() @ Vector((0, 0, 1)))
                        cost += max(0.0, 0.7 - n.normalized().dot(face)) * 0.5
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
    if thumb_along is None:   # 中指、無名指、小指照影片（docs/movie/pax.mov 握左輪）；食指放在扳機上（使用者選的）
        import json
        dirs = json.load(open(os.path.join(os.path.dirname(BASE), 'docs/image/hand_pose_grip_video.json')))
        for n in ('Middle', 'Ring', 'Little'):
            wrap_video(arm, n, dirs, P, A, R)
    if thumb_along is None:
        # 拇指：指尖去影片拇指尖的位置（影片是從握把後面繞過去），不穿進握把。
        # 以前是指尖停在食指指尖旁邊、跟食指合成一個圈（FNE 參考圖的握法）
        trigger_finger(arm, P, A, R)   # 食指先上扳機，拇指再找位置，才會避開扳機上的食指
        thumb_video(arm, dirs, P, A, R)
    else:
        thumb_to(arm, far_side(P, A, R, thumb_along), P, A, R)


def pose_ref(arm, which=None, fingers=('Thumb', 'Index', 'Middle', 'Ring', 'Little'), keep=False, dirs=None):
    """比對專用：照抄參考握槍時每節骨頭的方向（docs/image/hand_pose_grip.json，tools/hand_ref.py 存的，手自己的座標），
    兩邊姿勢一樣，疊圖比的才是形狀。遊戲不用這個姿勢。
    dirs：直接給方向表（同格式，例如 tools/hand_skeleton.py 從影片抓的，見 hand_check.py）"""
    import json, hand_views
    if dirs is None:
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
    # 掌心朝上托護木（舊做法）。2026-10-09 試過照影片改成從上面握：影片那幾格（LEVER-ACTION_RIFLES 180～184）其實是換彈時
    # 扶槍的握法，腰射時前臂不是往上翻就是從手往下穿過槍，使用者：「手臂上下顛倒」「還是很怪」，退回
    pose_grip(arm, SUP_P, SUP_AXIS, SUP_R, thumb_along=0.045)


# 拿子彈：子彈用最粗的散彈定（步槍、左輪細，留一點空隙比穿模好）
SHELL_R, SHELL_LEN = 0.0105, 0.065
PAD = 0.007   # 指腹厚度：骨頭末端到皮膚表面
THUMB_PAD = 0.006   # 拇指尖骨頭到彈底：量皮膚調的（0.0045 拇指皮膚插進彈底 3 公釐、0.008 離 2 公釐）
THUMB_SKIN = 0.010   # 拇指骨頭到最外面的皮膚（指尖那團肉）：彈底要離拇指骨頭這麼遠才不會插進拇指
# 拿子彈時四指後兩節一共彎幾度（中間關節六成、指尖四成）。影片抓到的這兩節不連動（審查說像鳥嘴），只留影片的指根方向。
# 無名指、小指彎到 70 以上指尖會捲進放子彈的地方（區塊審查）
LOAD_CURL = {'Index': 45, 'Middle': 45, 'Ring': 55, 'Little': 60}   # 食指中指是起始值，pose_load 會再找


def _seg_pts(arm, f):
    return [arm.matrix_world @ arm.pose.bones[f + s].head.lerp(arm.pose.bones[f + s].tail, t)
            for s in ('_Proximal', '_Intermediate', '_Distal') for t in (0.0, 0.5, 1.0)]


def _shell_dist(q, base, axis):
    """點到子彈表面的距離（負 = 在子彈裡面）、沿軸在哪（0 = 彈底）"""
    v = q - base
    along = v.dot(axis)
    side = (v - axis * along).length
    if 0 <= along <= SHELL_LEN:
        return side - SHELL_R, along
    return ((max(-along, along - SHELL_LEN)) ** 2 + max(0.0, side - SHELL_R) ** 2) ** 0.5, along


def _curl(arm, f, extra, total, lean=0):
    """指根在影片的方向上多彎 extra 度、往食指那側靠 lean 度，後兩節一共彎 total 度（六四分）"""
    pb = arm.pose.bones[f + '_Proximal']
    pb.rotation_euler.x = pb['_ref_x'] - math.radians(extra)
    pb.rotation_euler.z = pb['_ref_z'] + math.radians(lean)
    bend(arm, f + '_Intermediate', total * 0.6)
    bend(arm, f + '_Distal', total * 0.4)
    bpy.context.view_layer.update()


def pose_load(arm):
    """拿子彈塞進去：照影片（docs/image/hand_pose_load.json，散彈換彈那兩格抓的骨架）——拇指指腹從後面頂住彈底，
    子彈大致順著拇指往前；食指中指指尖搭在彈殼側面靠底，無名指小指自然彎著。以前是拇指食指捏成圈、其他三指握拳（使用者選了影片的做法）。
    拇指、四指指根照抄影片；子彈軸在拇指方向附近找、食指中指再找彎多少，讓指尖剛好碰到彈殼、整隻手不穿進去。
    回傳 (子彈中心, 子彈軸)：遊戲的 HandLoad 原點就在子彈中心、子彈沿 +Y"""
    import json
    dirs = json.load(open(os.path.join(os.path.dirname(BASE), 'docs/image/hand_pose_load.json')))
    reset(arm)
    pose_ref(arm, dirs=dirs, keep=True)
    for f in FINGER_NAMES:
        pb = arm.pose.bones[f + '_Proximal']
        pb['_ref_x'], pb['_ref_z'] = pb.rotation_euler.x, pb.rotation_euler.z
    for f in FINGER_NAMES:
        _curl(arm, f, 0, LOAD_CURL[f])

    def pad(f, t=0.9):
        """指尖那團肉上的點和朝向（骨頭 +Z 是指背，指腹朝 -Z）。影片的食指是用指尖肉搭在彈底銅邊，不是整個指腹平貼"""
        pb = arm.pose.bones[f + '_Distal']
        n = -(arm.matrix_world.to_3x3() @ pb.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
        return arm.matrix_world @ pb.head.lerp(pb.tail, t) + n * PAD, n

    def pen(base, axis, fingers):
        return sum(max(0.0, PAD - _shell_dist(q, base, axis)[0]) for f in fingers for q in _seg_pts(arm, f))

    def contact(f, base, axis):
        """指尖肉要貼在彈殼表面、搭在彈殼前六成（靠底），而且是指腹那面朝著子彈（指背碰到不算，第四輪骨架審查）"""
        q, n = pad(f)
        d, along = _shell_dist(q, base, axis)
        v = q - base
        to_axis = -(v - axis * v.dot(axis)).normalized()
        return abs(d) + max(0.0, along - SHELL_LEN * 0.6) + max(0.0, -along) + max(0.0, 0.3 - n.dot(to_axis)) * 0.05

    def fit(f, base, axis):
        """手指去配合子彈：指根照影片 -10~+15、後兩節六四連動一共 25~60 度、往食指靠 0~10。
        後兩節不准低於 25（夾菸）；中指往食指靠不准超過 10、跟食指皮膚至少隔 3 公釐（兩指黏成一根）"""
        best = None
        for e in (-10, -5, 0, 5, 10, 15):
            for t in range(25, 61, 5):
                for l in ((0, 5, 10) if f == 'Middle' else (0,)):
                    _curl(arm, f, e, t, l)
                    c = contact(f, base, axis) + pen(base, axis, (f,)) * 10 + (abs(e) + l) * 1e-4
                    if f == 'Middle':   # 指根最粗：骨頭中心距要 2 × 0.9 公分＋3 公釐（用 2 × PAD 指根還是黏著）
                        gap = min((q1 - q2).length for q1 in _seg_pts(arm, 'Index') for q2 in _seg_pts(arm, 'Middle'))
                        c += max(0.0, 2 * 0.009 + 0.003 - gap)
                    if best is None or c < best[0]:
                        best = (c, e, t, l)
        _curl(arm, f, *best[1:])
        return best[0]

    # 順序：子彈先放在食指指尖肉下面 → 中指去搭 → 拇指最後去頂彈底（v6，區塊審查通過的版本）。
    # 試過的死路：子彈綁在影片拇指的方向上（v3～v5，不是橫過去就是豎起來）；子彈再往前抬（軸·前 ≥ 0.55，比較像影片）
    # 拇指就搆不到彈底（差 2.6 公分，拇指根轉到極限）；彈底改放在拇指尖，食指中指又搭不到（差 0.7、3 公分）
    import hand_views
    _, fwd, _, back, _ = hand_views.hand_frame(rig_points(arm))
    thumb = (tip(arm, 'Thumb_Distal') - head(arm, 'Thumb_Distal')).normalized()
    index = (head(arm, 'Index_Intermediate') - head(arm, 'Index_Proximal')).normalized()
    _curl(arm, 'Index', 0, LOAD_CURL['Index'])

    def shell_under_index(axis):
        """食指指尖肉貼在彈殼頂上、離彈底 1.2 公分（影片：搭在銅邊）"""
        q, n = pad('Index')
        n = (n - axis * n.dot(axis)).normalized()
        return q + n * SHELL_R - axis * 0.012

    # 子彈軸：往前（遠離手腕）、往掌心、跟食指方向差 45 度以內——不往前會豎起來像蠟燭（v4）、倒著指手腕（v5）
    best = None
    for tilt in range(0, 61, 10):
        for spin in range(0, 360, 30 if tilt else 360):
            axis = Matrix.Rotation(math.radians(tilt), 3, Matrix.Rotation(math.radians(spin), 3, thumb) @ thumb.orthogonal().normalized()) @ thumb
            if axis.dot(fwd) < 0.3 or axis.dot(back) > 0 or math.degrees(axis.angle(index)) > 45:
                continue
            base = shell_under_index(axis)
            if pen(base, axis, ('Ring', 'Little')) > 0:
                continue
            # 食指整根不穿進去（指尖肉本來就貼著，量骨頭點會差一點點，留 2 公釐）、中指搭得上、拇指尖離彈底不要太遠
            c = (fit('Middle', base, axis) + (tip(arm, 'Thumb_Distal') - base).length * 0.2 + tilt * 1e-5
                 + sum(max(0.0, PAD - 0.002 - _shell_dist(q, base, axis)[0]) for q in _seg_pts(arm, 'Index')) * 10)
            if best is None or c < best[0]:
                best = (c, axis, base)
    _, axis, base = best
    fit('Middle', base, axis)
    # 拇指尖那團肉去頂彈底中心、指腹朝著子彈
    thumb_to(arm, base - axis * THUMB_PAD, None, None, 0.0, rad=0.0, face=axis, shell=(base, axis))
    for _ in range(8):   # 拇指皮膚陷進彈底的話彈底往前退（最多 8 公釐，區塊審查：退 3～4 公釐只剩肉被壓扁一點）
        if min(_shell_dist(q, base, axis)[0] for q in _seg_pts(arm, 'Thumb')) >= THUMB_PAD:
            break
        base = base + axis * 0.001
    for f in FINGER_NAMES:   # 暫存的不要跟著骨架匯出
        pb = arm.pose.bones[f + '_Proximal']
        del pb['_ref_x'], pb['_ref_z']
    return base + axis * (SHELL_LEN / 2), axis


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


def make_rig(name, skin, wear, arm, M, mats, mirror=False, scale=SCALE):
    """把目前姿勢連骨架一起留一份給遊戲用（左輪的手要會動：拇指扳擊錘、食指扣扳機、捏子彈）。
    皮套完骨架和細分烘成這個姿勢，再把這個姿勢設成骨架的靜止姿勢、重新綁回去：
    遊戲裡骨頭不轉就是這個握姿，程式只在上面加小角度（weapon.gd 的 _rig_pose）。
    整組的位置＝bake 的 M（右手）或再鏡射（左手），所以 weapon.gd 擺的位置跟原本的固定網格一樣。
    回傳骨架物件；名字 name，皮叫 name + 'Skin'、袖子叫 name + 'Sleeve'（兩塊各一個材質，綁同一副骨架）"""
    vl = bpy.context.view_layer
    a2 = arm.copy()
    a2.data = arm.data.copy()
    a2.name = a2.data.name = name
    bpy.context.scene.collection.objects.link(a2)
    for pb, src in zip(a2.pose.bones, arm.pose.bones):
        pb.matrix_basis = src.matrix_basis.copy()
    parts = []
    for o, mt, suffix in ((skin, mats[0], 'Skin'), (wear, mats[1], 'Sleeve')):
        o2 = o.copy()
        o2.data = o.data.copy()
        o2.name = o2.data.name = name + suffix
        bpy.context.scene.collection.objects.link(o2)
        o2.hide_render = False
        o2.data.materials.clear()
        o2.data.materials.append(mt)
        for p_ in o2.data.polygons:
            p_.material_index = 0
        for md in o2.modifiers:
            if md.type == 'ARMATURE':
                md.object = a2
        o2.parent = None
        o2.matrix_world = o.matrix_world.copy()
        vl.update()
        vl.objects.active = o2
        for md in list(o2.modifiers):   # 骨架（擺好的姿勢）、細分依序套用
            bpy.ops.object.modifier_apply(modifier=md.name)
        parts.append(o2)
    smooth_by_angle(parts[0])
    for p_ in parts[1].data.polygons:   # 袖子是圓筒，全平滑
        p_.use_smooth = True
    # 這個姿勢變成靜止姿勢
    bpy.ops.object.select_all(action='DESELECT')
    a2.select_set(True)
    vl.objects.active = a2
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    for sk in parts:
        sk.parent = a2
        sk.matrix_parent_inverse = Matrix.Identity(4)
        sk.matrix_world = a2.matrix_world.copy()
        sk.modifiers.new('rig', 'ARMATURE').object = a2
    Mw = Matrix.Scale(scale, 4) @ M
    if mirror:
        Mw = Matrix.Scale(-1, 4, Vector((1, 0, 0))) @ Mw
    a2.matrix_world = Mw
    vl.update()
    return a2


ARM_R = Vector((0.22, -0.55, -0.80))   # 跟以前一樣：長槍舉起來時握把在鏡頭正下方，手臂往右後下方伸出畫面
ARM_L = Vector((-0.20, -0.85, -0.45))
SUP_WRIST_DEV = 15   # 托護木的左手手腕往側邊最多歪幾度（見 aim_forearm）   # 托護木：前臂順著手掌往後下方，手腕不要折出一個平台


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
    rigs = [make_rig('RigGrip', skin, wear, arm, M, mats)]

    # 托護木（左手）：先用右手擺，最後鏡射。護木軸 → +Y，掌心朝上 → +Z
    pose_support(arm)
    M = place(SUP_AXIS, Vector((0, 0, -1)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector())
    c = SUP_P + SUP_AXIS * (Vector((0.0, 0.05, 0)) - SUP_P).dot(SUP_AXIS)
    M = M @ Matrix.Translation(-c)
    mirror = Vector((-ARM_L.x, ARM_L.y, ARM_L.z))
    aim_forearm(arm, (M.to_3x3().inverted() @ mirror), max_dev=SUP_WRIST_DEV)
    out.append(to_object('HandSupport', bake(objs, M, mirror=True), mats))
    rigs.append(make_rig('RigSupport', skin, wear, arm, M, mats, mirror=True))

    # 捏子彈（左手）：指尖朝前上方，手背朝左上
    shell, axis = pose_load(arm)
    M = place(axis, Vector((0, 0, 1)), Vector((0, 1, 0)), Vector((0.75, 0.1, 0.65)), shell)   # 子彈軸 → +Y、手背朝右上
    aim_forearm(arm, (M.to_3x3().inverted() @ Vector((-ARM_L.x, ARM_L.y, ARM_L.z))))
    out.append(to_object('HandLoad', bake(objs, M, mirror=True), mats))
    rigs.append(make_rig('RigLoad', skin, wear, arm, M, mats, mirror=True))

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
