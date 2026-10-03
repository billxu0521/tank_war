# 農舍三種（docs/image/house.png 左上「房屋完整範例」的風格）：一片片的木板、一排排的瓦片、一顆顆的石頭，
# 紋理靠幾何和每片不同的顏色做出來，不貼圖（照片貼圖會把平面折面洗掉，見 docs/素材流水線/程式建模迭代.md）。
#   House1  前廊農舍：橫向搭接板、山牆朝正面（閣樓窗亮著）、整排前廊另一片緩屋頂、右後石煙囪（參考圖那棟）
#   House2  圓木小屋：圓木交叉疊的牆、牆矮屋頂緩、半邊前廊、左側石煙囪、柴堆
#   House3  直板高屋：直條板留縫、牆高屋頂陡、兩個老虎窗、後面一間斜屋頂的小倉、門口只有小雨遮
#
# 三種的主屋牆都是 10 × 8（跟 main.gd 的 _house() 一樣），門都在正面中央。整棟架高 F（地板高），
# 前廊一樣高，台階的碰撞是一片斜坡。每種匯出三個物件：
#   House<N>     外觀（原點在地面中央）
#   House<N>Col  碰撞：牆、窗洞、地板、屋頂、煙囪、前廊、欄杆、斜坡、大件家具（遊戲裡看不見）
#   HouseDoor    門（三種共用），原點在門軸、門底；遊戲裡擺在地板高 F
# 煙囪頂的位置 CHIMNEY 跟 main.gd 的 HOUSE_CHIMNEY 一樣（冒煙的地方）。
#
# 背景跑：tools/model_iter.sh house <版號>（輸出 models/houses.glb 和對照圖）
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix

BASE = os.path.dirname(os.path.abspath(__file__))
exec(open(BASE + '/common.py').read())
sys.path.insert(0, BASE)
import pipeline

HW, HL = 10.0, 8.0          # 主屋牆外緣：寬（X）、深（Y）
T = 0.2                     # 牆厚
F = 0.45                    # 地板高
DOOR_W, DOOR_H = 1.1, 2.2
PART_Y = 1.0                # 隔間牆（前面客廳、後面臥室）
WIN = (1.1, F + 0.55, F + 1.85)   # 窗寬、下緣、上緣：窗台離外面地面 1 公尺，翻得進去

VARIANTS = {
    'House1': dict(h=4.4, pitch=0.70, ridge='y', siding='plank', porch='full', dormers=0, lean=False,
                   chimney=(HW / 2 + 0.6, 2.0)),
    'House2': dict(h=3.4, pitch=0.50, ridge='x', siding='log', porch='half', dormers=0, lean=False,
                   chimney=(-(HW / 2 + 0.6), 1.8)),
    'House3': dict(h=5.2, pitch=0.78, ridge='x', siding='batten', porch='stoop', dormers=2, lean=True,
                   chimney=(3.4, 1.6)),
}
CHIMNEY = {}                # 名字 -> 煙囪頂 (x, y, z)，建的時候填

rnd = random.Random(20260930)

bpy.ops.wm.read_factory_settings(use_empty=True)
# 顏色都是線性值。每組三個只差亮度（±8%），不變色相：一片片板子看得出來，又不會像拼布
def tones(rgb, k=0.08):
    return [tuple(c * f for c in rgb) for f in (1.0, 1 - k, 1 + k)]


WOOD = [mat('h_wood%d' % i, c, 0.9) for i, c in enumerate(tones((0.145, 0.09, 0.048), 0.12))]   # 舊木頭：受光面要比地面暗
LOG = [mat('h_log%d' % i, c, 0.9) for i, c in enumerate(tones((0.15, 0.095, 0.05), 0.1))]
SHING = [mat('h_shing%d' % i, c, 0.95) for i, c in enumerate(tones((0.069, 0.047, 0.032), 0.06))]   # 約 #4A3D32，比牆暗很多
SHADE = mat('h_shade', (0.038, 0.026, 0.018), 1.0)     # 瓦片下緣露出的那面（約 #3A2E24）：排線靠它
STONE = [mat('h_stone%d' % i, c, 0.95) for i, c in enumerate(tones((0.107, 0.098, 0.087), 0.2))]   # 灰石頭（約 #5C5853）
TRIM = mat('h_trim', (0.19, 0.12, 0.065), 0.9)
POST = mat('h_post', (0.21, 0.135, 0.072), 0.9)
MORTAR = mat('h_mortar', (0.048, 0.044, 0.038), 1.0)    # 石頭之間的暗縫（約 #3E3A36）
LAP = mat('h_lap', (0.16, 0.10, 0.053), 0.9)           # 搭接板下緣：比板面暗一截
DARK = mat('h_dark', (0.075, 0.050, 0.032), 1.0)        # 板縫、瓦縫：牆芯和屋頂底板的顏色
CHINK = mat('h_chink', (0.44, 0.38, 0.29), 1.0)         # 圓木之間的填縫
INNER = mat('h_inner', (0.30, 0.20, 0.12), 0.9)         # 牆芯（室內看到的那面）
PLANK = mat('h_plank', (0.40, 0.29, 0.19), 0.9)
IRON = mat('h_iron', (0.060, 0.055, 0.050), 0.9)
CLOTH = mat('h_cloth', (0.55, 0.18, 0.14), 0.95)
LINEN = mat('h_linen', (0.85, 0.83, 0.76), 0.95)
LIT = mat('h_lit', (1.0, 0.72, 0.38), 0.5)              # 亮著的窗和提燈
_b = next(n for n in LIT.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
_b.inputs['Emission Color'].default_value = (1.0, 0.62, 0.26, 1.0)
_b.inputs['Emission Strength'].default_value = 1.2   # 遊戲裡太強會亮成純白


def pick(ms):
    return ms[rnd.randrange(len(ms))]


def frame(u, v, n):
    """三個方向（Vector）-> box() 要的歐拉角"""
    return Matrix((u, v, n)).transposed().to_euler('XYZ')


def on_wall(axis, at, out, u, z, du, dz, dn, off, m, rot=0.0):
    """貼在牆外面的板子：axis='x' 是沿 X 的牆（y=at），'y' 是沿 Y 的牆（x=at）；out=±1 牆外朝哪邊。
    u 沿牆位置、z 高度（都是中心）、du dz dn 三個方向的大小、off 離牆面多遠（中心）。rot 繞沿牆方向傾斜（搭接板下緣翹出來）"""
    if axis == 'x':
        box((du, dn, dz), (u, at + out * off, z), (-out * rot, 0, 0), m=m)
    else:
        box((dn, du, dz), (at + out * off, u, z), (0, out * rot, 0), m=m)


def cuts(ops, z0, z1, pad=0.04):
    """高度 z0~z1 這一條會碰到的開口，回傳要挖掉的沿牆範圍"""
    return sorted((c - w / 2 - pad, c + w / 2 + pad) for (c, w, b, top) in ops if z1 > b and z0 < top)


def spans(a0, a1, holes):
    out, u = [], a0
    for c0, c1 in holes + [(a1, a1)]:
        if c0 - u > 0.08:
            out.append((u, min(c0, a1)))
        u = max(u, c1)
    return out


def gable_half(g, z):
    """山牆：高度 z 那裡的半寬（g = (中心, 底半寬, 底高, 高)）"""
    c, half, zb, rise = g
    return half * max(0.0, 1 - (z - zb) / rise)


def clad(axis, at, out, a0, a1, z0, z1, ops, style, gable=None):
    """外牆的板子（開口處斷開）。gable 給了就是山牆三角形，板子照高度收窄"""
    if style in ('plank', 'log_gable'):
        step, bh = 0.30, 0.27
        z = z0
        while z + 0.1 < z1:
            top = min(z + bh, z1)
            lo, hi = a0, a1
            if gable:
                hw = gable_half(gable, top)
                lo, hi = max(a0, gable[0] - hw), min(a1, gable[0] + hw)
            for s0, s1 in spans(lo, hi, cuts(ops, z, top)):
                # 一片板從頭通到尾，超過 6 公尺才在中間接一次（位置每排錯開）
                js = [s0, s0 + (s1 - s0) * rnd.uniform(0.35, 0.65), s1] if s1 - s0 > 6 else [s0, s1]
                for u, e in zip(js, js[1:]):
                    on_wall(axis, at, out, (u + e) / 2, (z + top) / 2, e - u - 0.02, top - z, 0.045,
                            0.04 + (0.015 if style == 'plank' else 0), pick(WOOD), 0.11 if style == 'plank' else 0.0)
                    if style == 'plank':                  # 下緣那一面：暗一截的細條
                        on_wall(axis, at, out, (u + e) / 2, z + 0.012, e - u - 0.02, 0.024, 0.03, 0.078, LAP)
            z += step
    elif style == 'batten':
        step = 0.32                              # 板寬 0.30、板縫 2 公分（看進去是深色底）
        u = a0
        while u < a1 - 0.05:
            e = min(a1, u + step)
            top = z1 if not gable else gable[2] + gable[3] * (1 - max(abs(u - gable[0]), abs(e - gable[0])) / gable[1])
            if top - z0 > 0.1:
                segs = [(z0, top)]
                for (c, w, b, t) in ops:
                    if e > c - w / 2 - 0.02 and u < c + w / 2 + 0.02:
                        segs = [(p, q) for (p, q) in ((z0, b - 0.04), (t + 0.04, top)) if q - p > 0.08]
                for p, q in segs:
                    on_wall(axis, at, out, (u + e) / 2, (p + q) / 2, e - u - 0.03, q - p, 0.05, 0.045, pick(WOOD))
            u = e
    elif style == 'log':
        r, step, ext = 0.17, 0.32, 0.38
        z = z0
        while z + step <= z1 + 0.02:                 # 最上面那根不能高過牆頂，不然會從屋面穿出來
            zc = z + step / 2
            for s0, s1 in spans(a0 - ext, a1 + ext, cuts(ops, z, z + step, 0.02)):
                L = s1 - s0
                rot = (0, math.pi / 2, 0) if axis == 'x' else (math.pi / 2, 0, 0)
                loc = ((s0 + s1) / 2, at + out * 0.04, zc) if axis == 'x' else (at + out * 0.04, (s0 + s1) / 2, zc)
                cyl(r, L, loc, rot, 8, m=pick(LOG))
            z += step
        if z1 - z > 0.02:                            # 最上面剩下的空隙補一條壓頂木，不然露出淺色填縫
            on_wall(axis, at, out, (a0 + a1) / 2, (z + z1) / 2, a1 - a0 + 0.3, z1 - z, 0.3, 0.05, pick(LOG))


def backer(axis, at, out, a0, a1, z0, z1, ops, m):
    """牆面外面薄薄一層深色：板子之間的縫看進去是暗的"""
    for s0, s1 in spans(a0, a1, cuts(ops, z0, z1, 0.0)):
        hs = [(z0, z1)]
        for (c, w, b, t) in ops:
            if s1 > c - w / 2 and s0 < c + w / 2:
                pass
        on_wall(axis, at, out, (s0 + s1) / 2, (z0 + z1) / 2, s1 - s0, z1 - z0, 0.01, 0.005, m)
    for (c, w, b, t) in ops:                      # 開口上下那兩塊
        for p, q in ((z0, b), (t, z1)):
            if q - p > 0.02:
                on_wall(axis, at, out, c, (p + q) / 2, w, q - p, 0.01, 0.005, m)


def casing(axis, at, out, c, w, b, t, lit=False, shutters=False, sill=True):
    """門窗的框：兩側和上面一圈板、下面窗台。lit=True 裝上亮著的玻璃和十字窗櫺（閣樓窗、老虎窗，不能進出）"""
    on_wall(axis, at, out, c, t + 0.06, w + 0.24, 0.12, 0.08, 0.09, TRIM)
    for s in (-1, 1):
        on_wall(axis, at, out, c + s * (w / 2 + 0.06), (b + t) / 2, 0.12, t - b, 0.08, 0.09, TRIM)
    if sill:
        on_wall(axis, at, out, c, b - 0.04, w + 0.44, 0.08, 0.18, 0.1, TRIM)
    if lit:
        on_wall(axis, at, out, c, (b + t) / 2, w, t - b, 0.01, 0.015, LIT)   # 在深色底板前面、窗框後面
        on_wall(axis, at, out, c, (b + t) / 2, 0.05, t - b, 0.05, 0.03, TRIM)
        on_wall(axis, at, out, c, (b + t) / 2, w, 0.05, 0.05, 0.03, TRIM)
    if shutters:
        for s in (-1, 1):
            for k in range(3):                    # 三片直板拼成一扇
                on_wall(axis, at, out, c + s * (w / 2 + 0.2 + (k - 1) * 0.17), (b + t) / 2, 0.16, t - b + 0.05,
                        0.04, 0.09, pick(WOOD))
            on_wall(axis, at, out, c + s * (w / 2 + 0.2), b + 0.3, 0.52, 0.08, 0.03, 0.12, TRIM)
            on_wall(axis, at, out, c + s * (w / 2 + 0.2), t - 0.3, 0.52, 0.08, 0.03, 0.12, TRIM)


def roof_slope(o, u, v, ulen, vlen, thick=0.22, col=True, shingle=True, row=0.45):
    """一片屋頂斜面：o 是上表面、屋簷那條邊的中點，u 沿屋簷、v 往上坡（單位向量）。
    底板＋一排排錯開的長木片瓦（每片寬度、亮度、高低、角度都有一點不同，下緣翹起來做出一階階的陰影）"""
    n = u.cross(v)
    rot = frame(u, v, n)
    c = o + v * (vlen / 2) - n * (thick / 2)
    (solid if col else box)((ulen, vlen, thick), tuple(c), tuple(rot), m=DARK)
    if not shingle:
        return
    rows = int(vlen / row)
    for k in range(rows):
        s = k * row
        x = -ulen / 2 - (0.65 if k % 2 else 0.0) - rnd.uniform(0.0, 0.2)   # 相鄰兩排錯開半片
        # 每排下緣一條暗色的邊：純色平面著色也看得出一排一排
        pe = o + v * (s + 0.03) + n * 0.035
        box((ulen, 0.03, 0.10), tuple(pe), tuple(rot), m=SHADE)
        while x < ulen / 2:
            w = rnd.uniform(0.9, 1.8)
            x0, x1 = max(x, -ulen / 2), min(x + w, ulen / 2)
            gap = 0.03 if rnd.random() < 0.1 else 0.0   # 一成的片跟隔壁留縫，縫裡看到暗色
            if x1 - x0 > 0.15:
                a = 0.14 + rnd.uniform(-0.02, 0.02)      # 比屋面平一點：下緣翹起來（約 0.10 公尺的高低差）
                tw = rnd.uniform(-0.035, 0.035)           # 每片隨機斜 ±2 度
                vt = v * math.cos(a) - n * math.sin(a)
                ut = u * math.cos(tw) + vt * math.sin(tw)
                vt = vt * math.cos(tw) - u * math.sin(tw)
                p = o + u * ((x0 + x1) / 2) + v * (s + row * 0.62 + rnd.uniform(-0.04, 0.04)) + n * 0.07
                box((x1 - x0 - 0.03 - gap, row * 1.3, 0.08), tuple(p), tuple(frame(ut, vt, ut.cross(vt))), m=pick(SHING))
            x += w


def gable_roof(h, rise, x0, x1, y0, y1, along='x', eave=0.55, end=0.55, col=True, main=True, thick=0.22):
    """人字屋頂：屋脊沿 along（'x' 或 'y'），牆頂 h、牆的範圍 x0~x1、y0~y1。end 是山牆那頭的出挑。
    main=True 加封簷板和屋簷下的椽頭。回傳斜度"""
    A = Vector((1, 0, 0)) if along == 'x' else Vector((0, 1, 0))
    E = Vector((0, 1, 0)) if along == 'x' else Vector((1, 0, 0))
    Z = Vector((0, 0, 1))
    ctr = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
    length = (x1 - x0) if along == 'x' else (y1 - y0)
    run = ((y1 - y0) if along == 'x' else (x1 - x0)) / 2
    p = math.atan2(rise, run)
    vlen = (run + eave) / math.cos(p)
    for s in (-1, 1):
        v = -s * math.cos(p) * E + math.sin(p) * Z
        n = s * math.sin(p) * E + math.cos(p) * Z
        u = v.cross(n)
        o = ctr + E * (s * (run + eave)) + Z * (h - eave * math.tan(p))
        roof_slope(o, u, v, length + 2 * end, vlen + 0.05, thick=thick, col=col, row=0.45 if main else 0.36)
        if main:
            k = 0
            while -length / 2 + k * 0.6 <= length / 2 + 0.01:     # 椽頭：屋簷底下一根根伸出來
                at = -length / 2 + k * 0.6
                c = ctr + A * at + E * (s * (run + eave / 2 - 0.04)) + Z * (h - (eave / 2 - 0.04) * math.tan(p)) - n * (thick + 0.09)
                box((0.12, (eave - 0.08) / math.cos(p), 0.18), tuple(c), tuple(frame(u, v, n)), m=TRIM)
                k += 1
            # 屋簷封板：沿屋簷一條，椽頭的端面收在它後面，底面不低過它
            c = ctr + E * (s * (run + eave - 0.04)) + Z * (h - (eave - 0.04) * math.tan(p)) - n * (thick / 2 + 0.1)
            box((length + 2 * end, 0.08, 0.30), tuple(c) if along == 'x' else tuple(c),
                (0, 0, 0) if along == 'x' else (0, 0, math.pi / 2), m=TRIM)
            for d in (-1, 1):                                        # 山牆邊的封簷板
                c = ctr + A * (d * (length / 2 + end)) + E * (s * (run + eave) / 2) + \
                    Z * (h + rise - (run + eave) / 2 * math.tan(p)) - n * 0.08
                box((0.08, vlen, 0.25), tuple(c), tuple(frame(A, v, A.cross(v))), m=TRIM)
    for s in (-1, 1):                                                                           # 屋脊壓條：兩片蓋住兩邊斜面各 0.1
        v = -s * math.cos(p) * E + math.sin(p) * Z
        n = s * math.sin(p) * E + math.cos(p) * Z
        c = ctr + Z * (h + rise) - v * 0.1 + n * 0.16
        box((length + 2 * end + 0.1, 0.22, 0.12), tuple(c), tuple(frame(A, v, A.cross(v))) if along == 'x'
            else tuple(frame(A, v, A.cross(v))), m=SHADE)
    return p


def prism_y(xc, y, w, zb, rise, depth, m):
    """正面朝 ±Y 的三角形牆（山牆），底邊中點 (xc, y, zb)"""
    bm = bmesh.new()
    pts = [(-w / 2, 0), (w / 2, 0), (0, rise)]
    f = [bm.verts.new((xc + a, y - depth / 2, zb + b)) for a, b in pts]
    k = [bm.verts.new((xc + a, y + depth / 2, zb + b)) for a, b in pts]
    bm.faces.new(f); bm.faces.new(k[::-1])
    for i in range(3):
        j = (i + 1) % 3
        bm.faces.new((f[i], k[i], k[j], f[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('tri'); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('tri', me)
    bpy.context.collection.objects.link(o)
    return _push(o, m)


def prism_x(x, yc, w, zb, rise, depth, m):
    o = prism_y(0, 0, w, 0, rise, depth, m)
    o.rotation_euler = (0, 0, math.pi / 2)
    o.location = (x, yc, zb)
    return o


def stone_stack(x0, x1, y0, y1, z0, z1, core=True):
    """石頭砌的一段：牆芯＋外面一顆顆石頭（每排高度、每顆寬度和凸出量都不一樣）"""
    if core:
        box((x1 - x0 - 0.06, y1 - y0 - 0.06, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), m=MORTAR)
    z = z0
    row = 0
    while z < z1 - 0.05:
        rh = min(rnd.uniform(0.22, 0.34), z1 - z)
        wx, wy = (0.1, -0.1) if row % 2 else (-0.1, 0.1)    # 轉角一排包前後面、一排包側面，才不會有一條直縫
        row += 1
        for axis, at, out, a0, a1 in (('x', y0, -1, x0 - wx, x1 + wx), ('x', y1, 1, x0 - wx, x1 + wx),
                                      ('y', x0, -1, y0 - wy, y1 + wy), ('y', x1, 1, y0 - wy, y1 + wy)):
            u = a0 + rnd.uniform(-0.15, 0.0)
            while u < a1 - 0.02:
                w = rnd.uniform(0.25, 0.5)
                e = min(u + w, a1)
                if a1 - e < 0.12:
                    e = a1
                s0 = max(u, a0)
                d = rnd.uniform(0.0, 0.03)
                on_wall(axis, at, out, (s0 + e) / 2, z + rh / 2, e - s0 - 0.04, rh - 0.04, 0.12, -0.03 + d, pick(STONE))
                u = e
        z += rh


def chimney(x, y, top, outside, h):
    """石煙囪：outside=True 貼在山牆外面（底下粗、肩膀往上收），否則從屋頂穿出來。頂上一片石板帽"""
    if outside:
        sx = 1 if x > 0 else -1
        stone_stack(x - 0.75, x + 0.75, y - 0.8, y + 0.8, 0.0, h * 0.62)
        solid((1.5, 1.6, h * 0.62), (x, y, h * 0.31))
        for k in range(3):                         # 肩膀：一階階往上收
            t = k / 3
            hw, hd = 0.75 - 0.2 * (k + 1) / 3, 0.8 - 0.25 * (k + 1) / 3
            z = h * 0.62 + k * 0.18
            box((hw * 2 + 0.04, hd * 2 + 0.04, 0.1), (x, y, z + 0.05), m=pick(STONE))
        stone_stack(x - 0.5, x + 0.5, y - 0.5, y + 0.5, h * 0.62 + 0.54, top)
        box((0.9, 0.9, top - h * 0.62), (x, y, (top + h * 0.62) / 2), m=DARK)
        solid((1.0, 1.0, top - h * 0.62), (x, y, (top + h * 0.62) / 2))
    else:
        z0 = h + 0.5
        stone_stack(x - 0.5, x + 0.5, y - 0.5, y + 0.5, z0, top)
        solid((1.0, 1.0, top - z0), (x, y, (top + z0) / 2))
    box((1.2, 1.2, 0.12), (x, y, top + 0.06), m=STONE[1])        # 石板帽：出挑 0.1，上面再收一層小的
    box((0.9, 0.9, 0.14), (x, y, top + 0.19), m=STONE[0])
    box((0.5, 0.5, 0.1), (x, y, top + 0.23), m=DARK)             # 煙道口


def lantern(loc, hook=0.0):
    x, y, z = loc
    box((0.2, 0.2, 0.28), (x, y, z), m=LIT)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.03, 0.03, 0.32), (x + sx * 0.1, y + sy * 0.1, z), m=IRON)
    box((0.26, 0.26, 0.04), (x, y, z - 0.15), m=IRON)
    cone(0.18, 0.04, 0.1, (x, y, z + 0.19), (0, 0, math.pi / 4), 4, m=IRON)
    if hook:
        box((0.03, hook, 0.03), (x, y + hook / 2, z + 0.28), m=IRON)


def barrel(x, y, z0=0.0):
    cyl(0.3, 0.85, (x, y, z0 + 0.425), (0, 0, rnd.uniform(0, 1)), 10, m=pick(WOOD))
    for z in (0.12, 0.42, 0.72):
        cyl(0.315, 0.05, (x, y, z0 + z), (0, 0, 0), 10, m=IRON)


def crate(x, y, z0=0.0, s=0.6):
    box((s, s, s), (x, y, z0 + s / 2), (0, 0, rnd.uniform(-0.3, 0.3)), m=pick(WOOD))
    o = _parts[-1]
    for sx in (-1, 1):                             # 四邊框＋對角的 X 撐，只做正面和側面一圈
        box((s + 0.02, 0.04, 0.08), (x, y, z0 + (0.04 if sx < 0 else s - 0.04)), o.rotation_euler, m=TRIM)


def rail(x0, y0, x1, y1, z0, hgt=0.9, col=True):
    """前廊欄杆：上下兩根橫木＋一根根直木（間距 0.22）。碰撞一塊薄板，翻得過去"""
    L = math.hypot(x1 - x0, y1 - y0)
    ang = math.atan2(y1 - y0, x1 - x0)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    box((L, 0.12, 0.09), (mx, my, z0 + hgt), (0, 0, ang), m=TRIM)
    box((L, 0.08, 0.07), (mx, my, z0 + 0.14), (0, 0, ang), m=TRIM)
    n = max(1, int(L / 0.20))
    for k in range(1, n):
        t = k / n
        box((0.07, 0.07, hgt - 0.16), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + 0.14 + (hgt - 0.14) / 2), (0, 0, ang), m=POST)
    if col:
        COL.append(((L, 0.1, hgt), (mx, my, z0 + hgt / 2), (0, 0, ang)))


def deck(x0, x1, y0, y1, along='x'):
    """前廊地板：深色底＋一條條地板，碰撞一整塊從地面到 F"""
    box((x1 - x0, y1 - y0, F - 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, (F - 0.06) / 2), m=DARK)
    COL.append(((x1 - x0, y1 - y0, F), ((x0 + x1) / 2, (y0 + y1) / 2, F / 2), (0, 0, 0)))   # 碰撞頂面跟屋裡地板一樣高，走上來沒有小坎
    if along == 'x':
        y = y0
        while y < y1 - 0.05:
            e = min(y + 0.2, y1)
            box((x1 - x0 + 0.08, e - y - 0.025, 0.06), ((x0 + x1) / 2, (y + e) / 2, F - 0.03), m=pick(WOOD))
            y = e
    box((x1 - x0, 0.1, 0.25), ((x0 + x1) / 2, y0 - 0.03, F - 0.125), m=TRIM)           # 前緣的封板


def steps(xc, y_front, w, n=3):
    """前面的台階：n 階到 F。碰撞是一片斜坡（角色走得上去）"""
    rise = F / n
    for k in range(n):
        top = rise * (k + 1)
        d = 0.32
        yy = y_front - (n - k) * d
        box((w, d * (n - k), 0.06), (xc, yy + d * (n - k) / 2, top - 0.03), m=pick(WOOD))
        box((w, 0.04, top - 0.06), (xc, yy + 0.02, (top - 0.06) / 2), m=DARK)
    for s in (-1, 1):                              # 兩邊的斜梁
        box((0.08, n * 0.32, 0.12), (xc + s * (w / 2 + 0.04), y_front - n * 0.16, F / 2),
            (-math.atan2(F, n * 0.32), 0, 0), m=TRIM)
    run = n * 0.32 + 0.1
    a = math.atan2(F, run)
    COL.append(((w, math.hypot(run, F), 0.1), (xc, y_front - run / 2, F / 2 - 0.05), (a, 0, 0)))


def post(x, y, z0, z1, brace=None):
    box((0.20, 0.20, z1 - z0), (x, y, (z0 + z1) / 2), m=POST)
    box((0.28, 0.28, 0.1), (x, y, z0 + 0.05), m=TRIM)
    for d in (brace or ()):                        # 斜撐：往 ±X 撐住橫樑，長 0.6、截面 0.1
        box((0.10, 0.10, 0.6), (x + d * 0.25, y, z1 - 0.25), (0, d * 0.785, 0), m=POST)


def piers(xs, ys):
    for x in xs:
        for y in ys:
            stone_stack(x - 0.22, x + 0.22, y - 0.22, y + 0.22, 0.0, F - 0.02, core=False)


def interior(h):
    """室內（前面客廳、後面臥室），全部坐在地板 F 上"""
    y0 = -HL / 2 + T
    for x in [(-HW / 2 + T) + 0.25 + k * 0.5 for k in range(int((HW - 2 * T) / 0.5))]:   # 地板縫
        box((0.02, HL - 2 * T, 0.01), (x, 0, F + 0.004), m=DARK)
    wall('x', PART_Y, -HW / 2 + T, HW / 2 - T, h, 0.12, [(2.5, 1.0, 0.0, F + DOOR_H)], INNER)
    box((2.6, 1.8, 0.02), (-1.6, -1.8, F + 0.01), m=CLOTH)                               # 地毯
    solid((1.6, 0.9, 0.06), (-1.6, -1.8, F + 0.78), m=PLANK)                            # 餐桌
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.07, 0.07, 0.75), (-1.6 + sx * 0.7, -1.8 + sy * 0.35, F + 0.375), m=POST)
    for sx in (-1, 1):
        box((0.45, 0.45, 0.05), (-1.6 + sx * 1.1, -1.8, F + 0.47), m=POST)
        box((0.05, 0.45, 0.5), (-1.6 + sx * 1.33, -1.8, F + 0.72), m=POST)
        for dx in (-0.18, 0.18):
            for dy in (-0.18, 0.18):
                box((0.04, 0.04, 0.45), (-1.6 + sx * 1.1 + dx, -1.8 + dy, F + 0.225), m=POST)
    lantern((-1.6, -1.8, F + 0.95))
    solid((0.8, 0.6, 0.8), (3.4, -0.2, F + 0.4), m=IRON)                                 # 鑄鐵爐
    cyl(0.09, h - 0.8 - F, (3.4, -0.2, F + 0.8 + (h - 0.8 - F) / 2), (0, 0, 0), 10, m=IRON)
    for k in range(3):                                                                  # 書架
        box((0.3, 1.4, 0.04), (-HW / 2 + T + 0.15, -2.2, F + 0.6 + k * 0.55), m=PLANK)
        for j in range(5):
            box((0.22, 0.08, 0.3), (-HW / 2 + T + 0.15, -2.8 + j * 0.25 + k * 0.07, F + 0.77 + k * 0.55),
                m=CLOTH if (j + k) % 2 else LINEN)
    solid((1.2, 2.0, 0.45), (-3.2, 2.7, F + 0.225), m=POST)                             # 床
    box((1.1, 1.6, 0.12), (-3.2, 2.5, F + 0.51), m=LINEN)
    box((0.8, 0.35, 0.12), (-3.2, 3.45, F + 0.55), m=LINEN)
    box((1.2, 0.08, 0.9), (-3.2, 3.72, F + 0.45), m=POST)
    solid((1.0, 0.5, 1.6), (3.3, 3.45, F + 0.8), m=PLANK)                               # 衣櫃
    box((0.6, 0.45, 0.8), (1.4, 3.5, F + 0.4), m=POST)                                   # 臉盆架
    cyl(0.2, 0.08, (1.4, 3.5, F + 0.84), (0, 0, 0), 12, m=LINEN)


def build(name, v):
    h, style = v['h'], v['siding']
    front = [(0.0, DOOR_W, F, F + DOOR_H), (-3.0, WIN[0], WIN[1], WIN[2]), (3.0, WIN[0], WIN[1], WIN[2])]
    back = [(3.0, WIN[0], WIN[1], WIN[2])] + ([] if v['lean'] else [(-3.0, WIN[0], WIN[1], WIN[2])])
    side = [(0.0, WIN[0], WIN[1], WIN[2])]
    ridge = v['ridge']
    run = HL / 2 if ridge == 'x' else HW / 2
    rise = run * math.tan(v['pitch'])
    # 牆芯（有碰撞）：室內看到的那面
    wall('x', -HL / 2 + T / 2, -HW / 2, HW / 2, h, T, front, INNER)
    wall('x', HL / 2 - T / 2, -HW / 2, HW / 2, h, T, back, INNER)
    for sx in (-1, 1):
        wall('y', sx * (HW / 2 - T / 2), -HL / 2 + T, HL / 2 - T, h, T, side, INNER)
    solid((HW - 2 * T, HL - 2 * T, F), (0, 0, F / 2), m=PLANK)                          # 地板（整塊墊高）
    # 山牆三角：屋脊沿 X 的山牆在左右兩側，沿 Y 的在前後
    for sd in (-1, 1):
        if ridge == 'x':
            prism_x(sd * (HW / 2 - T / 2), 0, HL, h, rise, T, DARK)   # 山牆芯用暗色：板子邊上露出來也看不出
        else:
            prism_y(0, sd * (HL / 2 - T / 2), HW, h, rise, T, DARK)
    # 外牆：深色底＋一片片的板（或圓木）
    zb = F - 0.05                                   # 板子從地板高度下面一點開始，下面是牆基
    seam = CHINK if style == 'log' else DARK
    walls = [('x', -HL / 2, -1, -HW / 2, HW / 2, front), ('x', HL / 2, 1, -HW / 2, HW / 2, back)] + \
            [('y', sx * HW / 2, sx, -HL / 2, HL / 2, side) for sx in (-1, 1)]
    for axis, at, out, a0, a1, ops in walls:
        backer(axis, at, out, a0, a1, zb, h, ops, seam)
        z0 = zb + (0.16 if (style == 'log' and axis == 'y') else 0.0)   # 圓木：側牆錯開半根，轉角才是交叉疊
        clad(axis, at, out, a0, a1, z0, h, ops, style)
    gstyle = 'log_gable' if style == 'log' else style
    attic = (0.0, 1.0, h + 0.55, h + 1.85) if rise > 3.5 else (0.0, 0.9, h + 0.35, h + 1.35) if rise > 1.9 else None
    for sd in (-1, 1):                                                                  # 山牆的板
        ops = [attic] if attic else []
        if ridge == 'x':
            prism_x(sd * (HW / 2 + 0.005), 0, HL, h, rise, 0.01, DARK)
            gw = ('y', sd * HW / 2, sd, -HL / 2, HL / 2, (0.0, HL / 2, h, rise))
        else:
            prism_y(0, sd * (HL / 2 + 0.005), HW, h, rise, 0.01, DARK)
            gw = ('x', sd * HL / 2, sd, -HW / 2, HW / 2, (0.0, HW / 2, h, rise))
        clad(gw[0], gw[1], gw[2], gw[3], gw[4], h, h + rise, ops, gstyle, gable=gw[5])
        if attic:
            casing(gw[0], gw[1], gw[2], *attic, lit=True)
    if style == 'batten':                                                               # 橫腰板：一樓和二樓之間
        zbelt = F + 2.75
        for axis, at, out, a0, a1, ops in walls:
            on_wall(axis, at, out, (a0 + a1) / 2, zbelt, a1 - a0 + 0.2, 0.2, 0.06, 0.1, TRIM)
    if style != 'log':
        for sx in (-1, 1):                                                              # 轉角板
            for sy in (-1, 1):
                box((0.22, 0.22, h - zb), (sx * (HW / 2 + 0.06), sy * (HL / 2 + 0.06), (h + zb) / 2), m=TRIM)
    # 牆基：石墩＋中間深色的裙板（地板架高，底下是暗的）
    for axis, at, out, a0, a1, ops in walls:
        on_wall(axis, at, out, (a0 + a1) / 2, (zb) / 2, a1 - a0, zb, 0.02, -0.05, DARK)
    piers([-HW / 2, -HW / 4, 0, HW / 4, HW / 2], [-HL / 2, HL / 2])
    piers([-HW / 2, HW / 2], [-HL / 4, 0, HL / 4])
    # 門窗框
    for axis, at, out, a0, a1, ops in walls:
        for (c, w, b, t) in ops:
            door = b <= F + 0.01
            casing(axis, at, out, c, w, b, t, shutters=(not door and style != 'batten'), sill=not door)
    # 屋頂
    p = gable_roof(h, rise, -HW / 2, HW / 2, -HL / 2, HL / 2, along=ridge)
    top_ridge = h + rise
    # 煙囪
    cx, cy = v['chimney']
    outside = abs(cx) > HW / 2
    top = top_ridge + 1.2
    chimney(cx, cy, top, outside, h)
    CHIMNEY[name] = (cx, cy, top + 0.3)
    # 老虎窗（House3）
    for k in range(v['dormers']):
        dx = (-2.6, 2.6)[k]
        yf = -HL / 2 + 1.1                          # 老虎窗正面的位置
        zr = h + rise - abs(yf) * math.tan(p)       # 那裡的屋頂面高度
        dw, dh, dr = 1.7, 1.45, 0.75
        box((dw, 2.6, dh + 0.3), (dx, yf + 1.3, zr + dh / 2 - 0.15), m=pick(WOOD))
        backer('x', yf, -1, dx - dw / 2, dx + dw / 2, zr - 0.1, zr + dh, [], DARK)
        win = (dx, 0.9, zr + 0.25, zr + 1.2)
        clad('x', yf, -1, dx - dw / 2, dx + dw / 2, zr - 0.1, zr + dh, [win], style)
        casing('x', yf, -1, *win, lit=True)
        prism_y(dx, yf + 0.1, dw, zr + dh, dr, 0.2, INNER)
        clad('x', yf, -1, dx - dw / 2, dx + dw / 2, zr + dh, zr + dh + dr, [], 'plank', gable=(dx, dw / 2, zr + dh, dr))
        gable_roof(zr + dh, dr, dx - dw / 2, dx + dw / 2, yf - 0.3, yf + 2.4, along='y', eave=0.25, end=0,
                   col=False, main=False, thick=0.15)
    # 後面的小倉（House3）：斜屋頂，整塊實心
    if v['lean']:
        lx0, lx1, ly0, ly1, lh = -HW / 2 + 0.3, 0.8, HL / 2, HL / 2 + 2.8, 2.9
        solid((lx1 - lx0, ly1 - ly0, lh), ((lx0 + lx1) / 2, (ly0 + ly1) / 2, lh / 2), m=INNER)
        ld = [((lx0 + lx1) / 2 + 1.0, 1.1, F, F + 2.0)]
        for axis, at, out, a0, a1, ops in (('x', ly1, 1, lx0, lx1, ld), ('y', lx0, -1, ly0, ly1, []), ('y', lx1, 1, ly0, ly1, [])):
            backer(axis, at, out, a0, a1, zb, lh, ops, DARK)
            clad(axis, at, out, a0, a1, zb, lh, ops, style)
        c, w, b, t = ld[0]
        on_wall('x', ly1, 1, c, (b + t) / 2, w, t - b, 0.05, 0.02, pick(WOOD))           # 關著的門
        for zz in (b + 0.35, t - 0.35):
            on_wall('x', ly1, 1, c, zz, w - 0.1, 0.1, 0.03, 0.06, TRIM)
        casing('x', ly1, 1, c, w, b, t, sill=False)
        sp = math.atan2(0.8, ly1 - ly0 + 0.4)
        roof_slope(Vector(((lx0 + lx1) / 2, ly1 + 0.4, lh + 0.05)), Vector((-1, 0, 0)),
                   Vector((0, -math.cos(sp), math.sin(sp))), lx1 - lx0 + 0.5, (ly1 - ly0 + 0.4) / math.cos(sp) + 0.1)
        piers([lx0, lx1], [ly1])
    # 前廊
    kind = v['porch']
    yw = -HL / 2
    if kind in ('full', 'half'):
        px = (-HW / 2 - 0.2, HW / 2 + 0.2) if kind == 'full' else (-2.8, 2.8)
        pd = 2.4 if kind == 'full' else 2.0
        yf = yw - pd
        deck(px[0], px[1], yf, yw)
        piers([px[0] + 0.1, px[1] - 0.1] + ([-2.9, 2.9] if kind == 'full' else []), [yf + 0.15])
        steps(0.0, yf, 1.5)
        zt = h - 0.3 if kind == 'full' else h - 0.35                   # 前廊屋頂靠牆那邊（跟主屋頂分開，看得到斷開的線）
        pp = 0.31                                                     # 約 18 度，比主屋頂緩
        zf = zt - (pd + 0.35) * math.tan(pp)
        xs = [px[0] + 0.15, -0.9, 0.9, px[1] - 0.15] + ([-2.9, 2.9] if kind == 'full' else [])
        for x in sorted(xs):
            post(x, yf + 0.15, F, zf - 0.1, brace=[d for d in (-1, 1) if px[0] + 0.5 < x + d * 0.5 < px[1] - 0.5])
        box((px[1] - px[0] + 0.1, 0.2, 0.25), ((px[0] + px[1]) / 2, yf + 0.15, zf - 0.08), m=POST)   # 通長橫樑
        box((px[1] - px[0], 0.14, 0.14), ((px[0] + px[1]) / 2, yw - 0.05, zt - 0.1), m=POST)          # 靠牆的樑
        x = px[0]
        while x <= px[1] + 0.01:                                                      # 前廊屋頂下的椽子，伸出橫樑外
            L = pd + 0.3
            box((0.12, L / math.cos(pp), 0.18), (x, yw - L / 2, zt - L / 2 * math.tan(pp) - 0.12), (pp, 0, 0), m=TRIM)
            x += 0.6
        roof_slope(Vector(((px[0] + px[1]) / 2, yf - 0.35, zf + 0.12)), Vector((1, 0, 0)),
                   Vector((0, math.cos(pp), math.sin(pp))), px[1] - px[0] + 0.5, (pd + 0.35) / math.cos(pp) + 0.1,
                   thick=0.14, col=False, row=0.36)
        box((px[1] - px[0] + 0.3, 0.24, 0.12), ((px[0] + px[1]) / 2, yw - 0.08, zt + 0.16), (-pp, 0, 0), m=SHADE)   # 前廊屋頂接牆的壓條
        for x0, x1 in ((px[0] + 0.15, -0.9), (0.9, px[1] - 0.15)):                  # 正面欄杆（台階那裡留口）
            rail(x0 + 0.09, yf + 0.15, x1 - 0.09, yf + 0.15, F)
        for x in px:                                                                  # 兩側欄杆
            rail(x + (0.15 if x < 0 else -0.15), yf + 0.24, x + (0.15 if x < 0 else -0.15), yw - 0.05, F)
        lantern((-0.95, yw - 0.18, F + 2.45), hook=0.18)
        barrel(px[1] - 0.7, yw - 0.5, F)
        crate(px[0] + 0.7, yw - 0.55, F)
        if kind == 'half':                                                            # 柴堆：左邊牆腳
            for k in range(4):
                for j in range(6 - k):
                    cyl(0.1, 0.9, (-HW / 2 + 0.9 + j * 0.2 + k * 0.1, yw - 0.5, 0.1 + k * 0.18),
                        (math.pi / 2, 0, 0), 6, m=pick(LOG))
            box((0.5, 0.5, 0.5), (-HW / 2 - 0.9, 3.0, 0.25), m=pick(LOG))            # 劈柴墩
    else:                                                                             # 只有小平台和雨遮
        yf = yw - 1.3
        deck(-1.1, 1.1, yf, yw)
        steps(0.0, yf, 1.4)
        for s in (-1, 1):                                                             # 雨遮的托架
            box((0.1, 0.9, 0.1), (s * 0.95, yw - 0.45, F + 2.75), m=POST)
            box((0.08, 0.1, 0.8), (s * 0.95, yw - 0.6, F + 2.5), (0.8, 0, 0), m=POST)
        prism_y(0, yw - 1.0, 2.2, F + 2.8, 0.6, 0.08, pick(WOOD))
        gable_roof(F + 2.8, 0.6, -1.1, 1.1, yw - 1.0, yw + 0.05, along='y', eave=0.2, end=0,
                   col=False, main=False, thick=0.15)
        lantern((0.95, yw - 0.18, F + 2.3), hook=0.18)
        for x, y in ((3.0, yw - 0.6), (3.6, yw - 0.5)):
            barrel(x, y)
    interior(h)
    o = finish(name, bevel=0.0, seg=1)
    c = make_col(name + 'Col')
    return [o, c]


def door():
    """門（三種共用）：直條板＋Z 字撐，原點在門軸、門底"""
    w, hh = DOOR_W, DOOR_H
    n = 5
    for k in range(n):
        box((w / n - 0.015, 0.06, hh), ((k + 0.5) * w / n, 0, hh / 2), m=pick(WOOD))
    for z in (0.35, hh - 0.35):
        box((w - 0.1, 0.05, 0.14), (w / 2, -0.05, z), m=TRIM)
    L = math.hypot(w - 0.2, hh - 0.9)
    box((L, 0.05, 0.12), (w / 2, -0.05, hh / 2), (0, -math.atan2(hh - 0.9, w - 0.2), 0), m=TRIM)
    sphere(0.05, (w - 0.14, -0.1, 1.05), 8, 6, m=IRON)
    for z in (0.35, hh - 0.35):
        box((0.3, 0.02, 0.06), (0.15, -0.085, z), m=IRON)
    return finish('HouseDoor', bevel=0.0, seg=1)


def settle(obs):
    for o in obs:
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.context.scene.cursor.location = (0, 0, 0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')


def preview(houses, path):
    """參考圖那棟的角度（左前上方看）：上排三種的正面，下排轉 180 度看背面。正交相機、暖色斜光"""
    sc = bpy.context.scene
    yaw, elev = math.radians(-38), math.radians(22)
    fwd = Vector((math.sin(-yaw) * math.cos(elev) * -1, math.cos(yaw) * math.cos(elev), -math.sin(elev)))
    fwd = Vector((-math.sin(yaw) * math.cos(elev), math.cos(yaw) * math.cos(elev), -math.sin(elev)))
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd).normalized()
    for i, src in enumerate(houses):
        for j, turn in enumerate((0, math.pi)):
            o = src.copy()
            sc.collection.objects.link(o)
            o.rotation_euler = (0, 0, turn)
            o.location = right * ((i - 1) * 18.5) + up * (7.0 - j * 14.5) - up * 3.5
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name.startswith(('House',)) and o.name.count('.') == 0:
            o.hide_render = True
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 56
    cam.location = -fwd * 80
    cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
    sc.collection.objects.link(cam)
    sc.camera = cam
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 5.0
    sun.data.color = (1.0, 0.88, 0.70)
    sun.data.angle = math.radians(3)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-40))    # 左前上方打光（參考圖亮面在正面和左側）
    sc.collection.objects.link(sun)
    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.85, 0.82, 0.78, 1)
    bg.inputs['Strength'].default_value = 0.55
    sc.world = world
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = 'GPU'
    except TypeError:
        pass
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = 1680, 940
    sc.render.film_transparent = True
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('preview ->', path)


def build_all():
    obs = []
    for name, v in VARIANTS.items():
        obs += build(name, v)
    obs.append(door())
    settle(obs)
    print('CHIMNEY', CHIMNEY)
    return obs


if __name__ == '__main__':
    pipeline.run(build_all, lambda obs, path: preview([o for o in obs if o.name in VARIANTS], path), budget=25000)
