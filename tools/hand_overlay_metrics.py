# 疊圖的數字版：參考（藍）和我們（紅）哪裡不合，直接從遮罩和關節位置算，不用眼睛估。
#   python3 tools/hand_overlay_metrics.py 24
# 輸入：docs/image/hand_mask.png、hand_joints.json（tools/hand_ref.py 渲染時存）
#       docs/image/hands_iter/v<N>_mask.png、v<N>_joints.json（tools/model_iter.sh hands <N> 存）
# 輸出：
#   1. 每格：輪廓重疊、紅離藍／藍離紅最遠幾 px（只量手腕以上，袖子比參考前臂粗是刻意的）
#   2. 關節：每個關節在畫面上差幾 px（關節位置來自骨架，不是看圖）
#   3. 差異：紅藍不重疊的像素，查渲染時存的部位圖（*_parts.png，每節一色）知道是哪一節，依節加總厚度和面積
#      （「食指第二節，我們多出 14 px」）。不用畫面上離哪根骨頭近來猜：彎起來的手指在畫面上骨頭會疊在一起
#   4. docs/image/hands_iter/v<N>_diff/<格>.png：一格一張、放大兩倍；紅 = 我們多出來、藍 = 參考有我們沒有，區塊編號跟文字對得上
# 給審查子代理看的就是這些分開的圖＋文字，不是整張大圖。
import json, os, subprocess, sys

N = sys.argv[1]
W, H, LABEL = 560, 640, 44
STEP = 2
VIEWS = ['張開・手背', '張開・掌心', '張開・拇指側', '握槍・拇指側', '握槍・小指側', '握槍・手背']
FINGER = {'Thumb': '拇指', 'Index': '食指', 'Middle': '中指', 'Ring': '無名指', 'Little': '小指'}
SEG = {'Proximal': '第一節', 'Intermediate': '第二節', 'Distal': '第三節'}
THUMB_SEG = {'Proximal': '掌骨', 'Intermediate': '第一節', 'Distal': '第二節'}
JOINT = {'Proximal': '指根關節', 'Intermediate': '第一指節', 'Distal': '第二指節', 'tip': '指尖'}
THUMB_JOINT = {'Proximal': '根部', 'Intermediate': '掌骨末端', 'Distal': '指節', 'tip': '指尖'}
PALM_NAME = {'Thumb': '拇指根', 'Index': '手掌食指側', 'Middle': '手掌中間', 'Ring': '手掌中間', 'Little': '手掌小指側'}
MIN_THICK = 10         # 比這薄的差異不列（描邊、細分造成的鋸齒）
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, 'docs/image/hand')
OURS = os.path.join(ROOT, 'docs/image/hands_iter/v%s' % N)


def load(path):
    raw = subprocess.run(['magick', path, '-colorspace', 'gray', '-depth', '8', 'gray:-'],
                         capture_output=True, check=True).stdout
    w = int(subprocess.run(['magick', 'identify', '-format', '%w', path], capture_output=True, text=True).stdout)
    return raw, w


def load_rgb(path):
    raw = subprocess.run(['magick', path, '-depth', '8', 'rgb:-'], capture_output=True, check=True).stdout
    w = int(subprocess.run(['magick', 'identify', '-format', '%w', path], capture_output=True, text=True).stdout)
    return raw, w


PARTS = ['Hand', 'Arm'] + [f + s for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little')
                           for s in ('_Proximal', '_Intermediate', '_Distal')]   # 跟 blender/hand_views.py 同一張表
PALETTE = [c for c in ((r, g, b) for r in (0, 128, 255) for g in (0, 128, 255) for b in (0, 128, 255)) if c != (0, 0, 0)]
PALETTE = [tuple(188 if v == 128 else v for v in c) for c in PALETTE]   # 渲染出來 128 會變 188（色彩轉換把它當線性值），照實際的對


def part_name(n):
    if n == 'Hand':
        return '手掌'
    if n == 'Arm':
        return '手腕前臂'
    f, s = n.split('_')
    return FINGER[f] + (THUMB_SEG if f == 'Thumb' else SEG)[s]


def part_at(img, x, y):
    """部位圖上 (x, y) 是哪一節：取最接近的調色盤顏色；邊緣的黑（背景、反鋸齒）往四周找最近的有色像素"""
    raw, w = img
    for r in (0, 2, 4, 6, 8):
        for dx, dy in ((0, 0), (r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)):
            i = ((y + dy) * w + x + dx) * 3
            if i < 0 or i + 3 > len(raw):
                continue
            c = raw[i:i + 3]
            d, k = min((sum((c[t] - PALETTE[j][t]) ** 2 for t in range(3)), j) for j in range(len(PARTS)))
            if d <= 30 ** 2:   # 只認跟色票幾乎一樣的；邊緣反鋸齒跟黑底混過的顏色會像別的節（調暗的青 ≈ 拇指的藍綠）
                return PARTS[k]
        if r == 0:
            continue
    return None


def segments(j):
    """骨頭線段（拼圖座標）：名字 → (起點, 終點)。掌 = 手腕到各指根"""
    out = {}
    for f in FINGER:
        names = [f + '_Proximal', f + '_Intermediate', f + '_Distal', f + '_tip']
        if not all(n in j for n in names):
            continue
        out[PALM_NAME[f]] = (j['Hand'][:2], j[names[0]][:2])
        for k, s in enumerate(('Proximal', 'Intermediate', 'Distal')):
            out[FINGER[f] + (THUMB_SEG if f == 'Thumb' else SEG)[s]] = (j[names[k]][:2], j[names[k + 1]][:2])
    return out


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L))
    return ((p[0] - ax - t * dx) ** 2 + (p[1] - ay - t * dy) ** 2) ** 0.5


def nearest_bone(p, segs):
    return min(segs, key=lambda n: seg_dist(p, *segs[n]))


ref_img, our_img = load(REF + '_mask.png'), load(OURS + '_mask.png')
ref_parts, our_parts = load_rgb(REF + '_parts.png'), load_rgb(OURS + '_parts.png')
ref_j, our_j = json.load(open(REF + '_joints.json')), json.load(open(OURS + '_joints.json'))
os.makedirs(OURS + '_diff', exist_ok=True)
report = {'views': [], 'joints': []}

print('第 %s 版：參考（藍）vs 我們（紅），px 是預覽原圖的像素' % N)
for i, name in enumerate(VIEWS):
    x0, y0 = (i % 3) * W, (i // 3) * (H + LABEL) + LABEL
    rj, oj = ref_j[i], our_j[i]
    cut = max(rj['Hand'][1], oj['Hand'][1]) - y0 + 12      # 手腕以下不量
    hand_len = ((rj['Middle_tip'][0] - rj['Hand'][0]) ** 2 + (rj['Middle_tip'][1] - rj['Hand'][1]) ** 2) ** 0.5

    def cellset(img):
        raw, w = img
        return {(x, y) for y in range(0, int(cut), STEP) for x in range(0, W, STEP) if raw[(y0 + y) * w + x0 + x] > 127}

    r, o = cellset(ref_img), cellset(our_img)
    nb = ((STEP, 0), (-STEP, 0), (0, STEP), (0, -STEP))
    er = [p for p in r if any((p[0] + dx, p[1] + dy) not in r for dx, dy in nb)]
    eo = [p for p in o if any((p[0] + dx, p[1] + dy) not in o for dx, dy in nb)]
    iou = len(r & o) / max(1, len(r | o))

    # 差異：每個只在紅（我們多出）或只在藍（我們少了）的像素，歸到最近的那根骨頭，再依骨頭加總。
    # 不用連通塊：連在一起的兩種差異（例如參考伸直的食指和手背那條）會被算成同一塊、名字只剩一個
    # 握槍格：參考是鬆鬆圍成一圈（手裡是空的），我們握緊真的握把。每根手指張多開（指尖到手腕 ÷ 指根到手腕）差 0.2 以上，
    # 那根手指的差異是姿勢不同、不是形狀不同——形狀以張開那排為準，握槍那排只看手掌、手背、拇指
    loose = [f for f in ('Index', 'Middle', 'Ring', 'Little')
             if i >= 3 and rj['_open'][f] - oj['_open'][f] >= 0.2]
    blobs = []
    for side, only, other_edge, pimg in (('我們多出', o - r, er, our_parts), ('我們少了', r - o, eo, ref_parts)):
        groups = {}
        for q in only:   # 查部位圖：這個像素是哪一節（我們多出的查我們的、少了的查參考的）
            pn = part_at(pimg, x0 + q[0], y0 + q[1])
            if pn:
                groups.setdefault(pn, []).append(q)
        for bone, comp in groups.items():
            if len(comp) * STEP * STEP < 60:
                continue
            sample = comp[::max(1, len(comp) // 200)]
            thick, far_pt = 0, comp[0]
            for q in sample:
                d = min((q[0] - u) ** 2 + (q[1] - v) ** 2 for u, v in other_edge) ** 0.5 if other_edge else 0
                if d > thick:
                    thick, far_pt = d, q
            if thick < MIN_THICK:
                continue
            note = ''
            if bone.split('_')[0] in loose:
                note = '（姿勢不同：參考 %.2f、我們 %.2f）' % (rj['_open'][bone.split('_')[0]], oj['_open'][bone.split('_')[0]])
            blobs.append({'side': side, 'bone': part_name(bone), 'thick': round(thick), 'area': len(comp) * STEP * STEP,
                          'far': list(far_pt), 'note': note})
    blobs.sort(key=lambda b: -b['thick'])

    # 關節：每個關節差幾 px（同一格畫面上的 2D 距離）
    jd = []
    for f in FINGER:
        for s in ('Proximal', 'Intermediate', 'Distal', 'tip'):
            n = '%s_%s' % (f, s)
            if n in rj and n in oj:
                d = ((rj[n][0] - oj[n][0]) ** 2 + (rj[n][1] - oj[n][1]) ** 2) ** 0.5
                jd.append((round(d), FINGER[f] + (THUMB_JOINT if f == 'Thumb' else JOINT)[s]))
    jd.sort(reverse=True)

    print('\n【%d %s】重疊 %.0f%%，手長 %.0f px' % (i + 1, name, iou * 100, hand_len))
    print('  差異（每根骨頭附近加總，最厚 ≥ %d px，依厚度排）：' % MIN_THICK)
    real = [b for b in blobs if not b['note']]
    print('  ＝ 形狀不合的地方 %d 處，最厚 %d px' % (len(real), real[0]['thick'] if real else 0))
    if loose:
        print('  （手指張開程度 參考／我們：%s；差 ≥ 0.2 的手指只是姿勢不同，不算）' %
              '、'.join('%s %.2f／%.2f' % (FINGER[f], rj['_open'][f], oj['_open'][f]) for f in ('Index', 'Middle', 'Ring', 'Little')))
    blobs = real[:6]
    for k, b in enumerate(blobs, 1):
        print('   #%d %s %s：最厚 %d px（在 %d, %d）、面積 %d px²%s' %
              (k, b['bone'], b['side'], b['thick'], b['far'][0], b['far'][1], b['area'], b['note']))
    if not blobs:
        print('   （沒有）')
    print('  關節差最多的五個：' + '、'.join('%s %d px' % (n, d) for d, n in jd[:5]))
    report['views'].append({'view': name, 'iou': round(iou, 3), 'blobs': blobs, 'joints': jd})

    # 一格一張差異圖：灰 = 重疊、紅 = 我們多出來、藍 = 參考有我們沒有；編號標在最厚那點
    out_png = os.path.join(OURS + '_diff', '%d_%s.png' % (i + 1, name))
    draw = []
    for k, b in enumerate(blobs, 1):
        draw += ['-fill', 'black', '-stroke', 'none', '-pointsize', '18',
                 '-annotate', '+%d+%d' % (b['far'][0] + 6, b['far'][1] - 6), '#%d' % k,
                 '-stroke', 'none', '-fill', 'black', '-draw', 'circle %d,%d %d,%d' % (b['far'][0], b['far'][1], b['far'][0] + 3, b['far'][1])]
    crop = '%dx%d+%d+%d' % (W, H, x0, y0)
    m_r = ['(', REF + '_mask.png', '-crop', crop, '+repage', '-colorspace', 'gray', '-threshold', '50%', ')']
    m_o = ['(', OURS + '_mask.png', '-crop', crop, '+repage', '-colorspace', 'gray', '-threshold', '50%', ')']
    both = ['(', *m_r, *m_o, '-compose', 'Multiply', '-composite', ')']
    # 紅色通道 = 我們、綠色 = 兩邊都有、藍色 = 參考：重疊是白、只有我們是紅、只有參考是藍
    subprocess.run(['magick', *m_o, *both, *m_r, '-combine', '-colorspace', 'sRGB',
                    '-fill', 'rgb(150,150,150)', '-opaque', 'white', '-fill', 'rgb(235,235,235)', '-opaque', 'black',
                    '-fill', 'rgb(230,30,30)', '-opaque', 'rgb(255,0,0)', '-fill', 'rgb(40,90,255)', '-opaque', 'rgb(0,0,255)',
                    '-fill', 'none', '-stroke', 'rgb(220,170,0)', '-draw', 'line 0,%d %d,%d' % (cut, W, cut),
                    *draw, '-resize', '200%',
                    '-gravity', 'north', '-background', 'white', '-splice', '0x40', '-stroke', 'none', '-fill', 'black',
                    '-font', '/System/Library/Fonts/Hiragino Sans GB.ttc', '-pointsize', '26',
                    '-annotate', '+0+6', '第 %s 版 %s：紅 = 我們多出、藍 = 我們少了、灰 = 重疊、黃線以下不量' % (N, name), out_png], check=True)
    # 問題區域裁大：每格前三處形狀不合，各裁一張（差異圖上以最厚那點為中心 320×320，也就是原圖 160×160 放大兩倍）
    for k, b in enumerate([b for b in blobs if not b['note']][:3], 1):
        cx, cy = b['far'][0] * 2, b['far'][1] * 2 + 40
        subprocess.run(['magick', out_png, '-crop', '320x320+%d+%d' % (max(0, cx - 160), max(40, cy - 160)), '+repage',
                        '-gravity', 'north', '-background', 'white', '-splice', '0x34', '-fill', 'black',
                        '-font', '/System/Library/Fonts/Hiragino Sans GB.ttc', '-pointsize', '20',
                        '-annotate', '+0+6', '%s #%d %s %s %d px' % (name, k, b['bone'], b['side'], b['thick']),
                        os.path.join(OURS + '_diff', '%d_%s_#%d.png' % (i + 1, name, k))], check=True)

json.dump(report, open(OURS + '_diff/report.json', 'w'), ensure_ascii=False, indent=1)
print('\n-> %s_diff/（一格一張差異圖＋report.json）' % OURS)
