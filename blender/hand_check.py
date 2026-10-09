# 拿影片抓到的手骨架（tools/hand_skeleton.py 的 _skel.json）檢驗、調整 rig 的姿勢。
# 每組姿勢：我們的姿勢（hands.py 的 pose_grip / pose_support / pose_load）跟影片那幾格平均的姿勢，
#   1. 每節骨頭方向差幾度（手自己的座標，跟 hand_views.hand_frame 同一套）→ 印出來＋存 <out>.json
#   2. 同一套鏡頭各拍三個角度，每組兩排：上我們、下影片（影片的姿勢用 pose_ref 直接套到同一隻 rig 上）
#      <out>.png        打光的樣子
#      <out>_parts.png  區塊：每節骨頭一個顏色（不打光），看每節的形狀、長度、有沒有穿插
#      <out>_bones.png  骨架：紅 = 我們、藍 = 影片，疊在同一格（鏡頭跟著手擺，兩邊手腕、手掌對齊）
#   Blender --background --factory-startup --python blender/hand_check.py -- 骨架.json 輸出 grip=16,18 support=70,122 load=182
# 數字 = _skel.json 裡第幾格（從 0 數）。偵測本身就有 15~25 度的誤差（拿 docs/image/hand.png 驗過），差不到 25 度別急著改
import bpy, json, math, os, subprocess, sys, tempfile
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
import hands, hand_views

FINGERS = ('Thumb', 'Index', 'Middle', 'Ring', 'Little')
SEGS = ('_Proximal', '_Intermediate', '_Distal')
POSES = {'grip': hands.pose_grip, 'support': hands.pose_support, 'load': hands.pose_load}
LABEL = {'grip': '握槍把', 'support': '托護木', 'load': '拿子彈'}
VIEWS = [('thumb', '拇指側'), ('pinky', '小指側'), ('back', '手背'), ('palm', '掌心')]
WARN = 25   # 度：超過才算真的不一樣
W, H = hand_views.W, hand_views.H


def rig_dirs(arm):
    pts = hands.rig_points(arm)
    _, fwd, side, normal, _ = hand_views.hand_frame(pts)
    out = {}
    for f in FINGERS:
        names = [f + s for s in SEGS] + [f + '_tip']
        for a, b in zip(names, names[1:]):
            d = (pts[b] - pts[a]).normalized()
            out[a] = [d.dot(fwd), d.dot(side), d.dot(normal)]
    return out


def mean_dirs(frames, ids):
    acc = {}
    for i in ids:
        h = max(frames[i]['hands'], key=lambda h: h['score'])
        for k, v in h['dirs'].items():
            acc[k] = acc.get(k, Vector()) + Vector(v)
    return {k: list(v.normalized()) for k, v in acc.items()}


def shoot_parts(cam, frame, view, path):
    """同 hand_views.render_sheet 的部位圖：不打光、每節一色"""
    sc = bpy.context.scene
    sh = sc.display.shading
    old = (sh.light, sh.color_type, sh.show_object_outline, sc.view_settings.view_transform, sc.display.render_aa)
    sh.light, sh.color_type, sh.show_object_outline = 'FLAT', 'VERTEX', False
    sc.view_settings.view_transform = 'Standard'
    sc.display.render_aa = 'OFF'
    hand_views.shoot(cam, frame, view, path)
    sh.light, sh.color_type, sh.show_object_outline, sc.view_settings.view_transform, sc.display.render_aa = old


def bone_lines(cam, pts):
    """骨架投影到畫面上的線段（像素）"""
    sc = bpy.context.scene

    def px(n):
        v = world_to_camera_view(sc, cam, pts[n])
        return v.x * W, (1 - v.y) * H
    segs = []
    for f in FINGERS:
        chain = ['Hand'] + [f + s for s in SEGS] + [f + '_tip']
        segs += [(px(a), px(b)) for a, b in zip(chain, chain[1:])]
    return segs


def add_shell(center, axis, r=None, length=None):
    """圓柱（預設散彈大小 hands.SHELL_R / SHELL_LEN；握把、護木給半徑和長度），部位圖裡是白色"""
    bpy.ops.mesh.primitive_cylinder_add(radius=r or hands.SHELL_R, depth=length or hands.SHELL_LEN, vertices=16, location=center)
    ob = bpy.context.object
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(axis)
    ca = ob.data.color_attributes.new('part_id', 'BYTE_COLOR', 'CORNER')
    for c in ca.data:
        c.color = (1, 1, 1, 1)
    ob.data.color_attributes.active_color = ca
    return ob


def label(img, text):
    return ['(', *img, '-stroke', 'none', '-fill', 'black', '-gravity', 'north', '-splice', '0x40', '-font', hand_views.FONT, '-pointsize', '26',
            '-annotate', '+0+4', text, ')']


def main(skel, out, groups):
    frames = json.load(open(skel))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    skin, arm = hands.build_rig()[:2]
    hand_views.paint_parts(skin, lambda g: g if g in hand_views.PARTS else 'Arm')
    skin.data.color_attributes.active_color = skin.data.color_attributes['part_id']
    cam = hand_views.setup_scene()
    tmp = tempfile.mkdtemp()
    report = {}
    rows = {'': [], '_parts': [], '_bones': []}
    for name, ids in groups:
        want = mean_dirs(frames, ids)
        POSES[name](arm)
        have = rig_dirs(arm)
        err = {k: round(math.degrees(Vector(have[k]).angle(Vector(want[k])))) for k in have}
        report[name] = {'frames': ids, 'error': err, 'video_dirs': want}
        bad = {k: v for k, v in err.items() if v >= WARN}
        print(f'== {LABEL[name]}（影片第 {ids} 格）平均差 {sum(err.values()) / len(err):.0f} 度；'
              f'超過 {WARN} 度：{bad or "沒有"}')
        lines = {v: {} for v, _ in VIEWS}
        for who, pose in (('我們', lambda: POSES[name](arm)), ('影片', lambda: hands.pose_ref(arm, dirs=want))):
            res = pose()
            bpy.context.view_layer.update()
            shell = None   # 我們那排把手裡的東西也放進去（子彈、握把、護木），穿不穿模、握不握得住一眼看得出來
            if who == '我們':
                if name == 'load':
                    shell = add_shell(*res)
                else:
                    P, A, R = (hands.GRIP_P, hands.GRIP_AXIS, hands.GRIP_R) if name == 'grip' else (hands.SUP_P, hands.SUP_AXIS, hands.SUP_R)
                    shell = add_shell(P, A, R, 0.14)
                    if name == 'grip':   # 扳機：握把前面、食指指根高度（hands.trigger_finger 的扳機點）
                        u = Vector((0, 0, -1))
                        u = (u - A * u.dot(A)).normalized()
                        root = hands.head(arm, 'Index_Proximal')
                        trig = add_shell(P + A * (root - P).dot(A) + u * (R + hands.TRIGGER_OUT), u, 0.003, 0.012)
                        shell = [shell, trig]
            frame = hand_views.hand_frame(hands.rig_points(arm))
            cells, pcells = [], []
            for v, vl in VIEWS:
                p, pp = os.path.join(tmp, f'{name}_{who}_{v}.png'), os.path.join(tmp, f'{name}_{who}_{v}_p.png')
                hand_views.shoot(cam, frame, v, p)
                lines[v][who] = bone_lines(cam, hands.rig_points(arm))
                shoot_parts(cam, frame, v, pp)
                cells += label([p, '-background', 'rgb(194,194,193)', '-flatten'], f'{LABEL[name]}・{who}・{vl}')
                pcells += label([pp, '-background', 'rgb(60,60,60)', '-flatten'], f'{LABEL[name]}・{who}・{vl}')
            for ob in (shell if isinstance(shell, list) else [shell] if shell else []):
                bpy.data.objects.remove(ob)
            rows[''] += ['('] + cells + ['+append', ')']
            rows['_parts'] += ['(', '-background', 'black'] + pcells + ['+append', ')']
        bcells = []
        for v, vl in VIEWS:
            draw = []
            for who, color in (('影片', 'rgb(40,90,230)'), ('我們', 'rgb(220,40,40)')):
                draw += ['-stroke', color, '-strokewidth', '4']
                for (x0, y0), (x1, y1) in lines[v][who]:
                    draw += ['-draw', f'line {x0:.0f},{y0:.0f} {x1:.0f},{y1:.0f}']
            bcells += label(['-size', f'{W}x{H}', 'xc:white', *draw], f'{LABEL[name]}・{vl}（紅我們 藍影片）')
        rows['_bones'] += ['('] + bcells + ['+append', ')']
    for suf, r in rows.items():
        subprocess.run(['magick', '-background', 'white'] + r + ['-append', out + suf + '.png'], check=True)
    json.dump(report, open(out + '.json', 'w'), ensure_ascii=False, indent=1)
    print('→', out + '.png', out + '_parts.png', out + '_bones.png')


if __name__ == '__main__':
    a = sys.argv[sys.argv.index('--') + 1:]
    main(a[0], a[1], [(g.split('=')[0], [int(x) for x in g.split('=')[1].split(',')]) for g in a[2:]])
