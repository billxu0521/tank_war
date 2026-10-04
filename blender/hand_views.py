# 手的六格預覽：參考圖（tools/hand_ref.py 渲染 FNE 的手）和我們的手（hands.py）共用同一套鏡頭，才比得準。
# 鏡頭跟著手自己的方向擺（從骨頭算：手腕→中指根是「前」，小指根→食指根是「側」），
# 大小用手腕到中指尖的長度正規化，兩邊的手不管單位多大，在圖上都一樣大。
# 上排：張開的手（手背、掌心、拇指側）；下排：握槍的手（拇指側、小指側、手背）。
import bpy, os, subprocess
from mathutils import Vector, Matrix

VIEWS = [('open', 'back', '張開・手背'), ('open', 'palm', '張開・掌心'), ('open', 'thumb', '張開・拇指側'),
         ('grip', 'thumb', '握槍・拇指側'), ('grip', 'pinky', '握槍・小指側'), ('grip', 'back', '握槍・手背')]
W, H = 560, 640
FONT = '/System/Library/Fonts/Hiragino Sans GB.ttc'
# 部位圖：每根骨頭一個顏色（不打光渲染），量測工具查像素顏色就知道是哪一節。兩邊共用同一張表
PARTS = ['Hand', 'Arm'] + [f + s for f in ('Thumb', 'Index', 'Middle', 'Ring', 'Little')
                           for s in ('_Proximal', '_Intermediate', '_Distal')]
PALETTE = [c for c in ((r, g, b) for r in (0, 128, 255) for g in (0, 128, 255) for b in (0, 128, 255)) if c != (0, 0, 0)]


def paint_parts(ob, part_of):
    """在網格上寫一個面角顏色屬性 'part_id'：每個面整面一色，取它的點多數屬於哪根骨頭（點取權重最大的那根）。
    part_of(群組名) → PARTS 裡的名字。用面角不用點：點的顏色細分後會在交界漸層，量測工具會認錯"""
    from collections import Counter
    me = ob.data
    names = {g.index: g.name for g in ob.vertex_groups}
    vpart = []
    for v in me.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        part = part_of(names[best.group]) if best else 'Arm'
        vpart.append(part if part in PARTS else 'Arm')
    old = me.color_attributes.get('part_id')
    if old:
        me.color_attributes.remove(old)
    attr = me.color_attributes.new('part_id', 'BYTE_COLOR', 'CORNER')
    for poly in me.polygons:
        part = Counter(vpart[i] for i in poly.vertices).most_common(1)[0][0]
        c = PALETTE[PARTS.index(part)]
        for li in poly.loop_indices:
            attr.data[li].color = (c[0] / 255, c[1] / 255, c[2] / 255, 1)
    me.color_attributes.active_color = attr


def hand_frame(pts):
    """pts：骨頭名（不含編號）→ 世界座標。回傳 (原點, 前, 側, 手背法線, 手長)"""
    wrist = pts['Hand']
    knuckles = (pts['Index_Proximal'] + pts['Middle_Proximal'] + pts['Ring_Proximal'] + pts['Little_Proximal']) / 4
    fwd = (knuckles - wrist).normalized()
    side = (pts['Index_Proximal'] - pts['Little_Proximal'])
    side = (side - fwd * side.dot(fwd)).normalized()
    normal = fwd.cross(side).normalized()          # 右手：前×(往食指) = 手背朝外
    return wrist, fwd, side, normal, (knuckles - wrist).length * 2.0


def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'SINGLE'          # 只比形狀：兩邊同一個顏色
    sh.single_color = (0.62, 0.50, 0.40)
    sh.show_cavity = False
    sh.show_object_outline = True
    sh.object_outline_color = (0.1, 0.07, 0.05)
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.film_transparent = True   # 透明底：另外出一張遮罩給疊圖描輪廓（手的灰跟背景的灰太接近，用顏色分不出來）
    sc.world = sc.world or bpy.data.worlds.new('w')
    sc.display.shading.background_type = 'VIEWPORT'
    sc.display.shading.background_color = (0.93, 0.92, 0.9)
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    cam = bpy.data.objects.get('_hv_cam')
    if not cam:
        cam = bpy.data.objects.new('_hv_cam', bpy.data.cameras.new('_hv_cam'))
        sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    sc.camera = cam
    return cam


def shoot(cam, frame, view, path):
    wrist, fwd, side, normal, L = frame
    d = {'back': normal, 'palm': -normal, 'thumb': side, 'pinky': -side}[view]
    center = wrist + fwd * (L * 0.30)
    cam.location = center + d * L * 4
    z = d.normalized()                    # 鏡頭的 +Z 朝後（指向鏡頭自己）
    y = (fwd - z * fwd.dot(z)).normalized()   # 手指朝畫面上方
    x = y.cross(z)
    cam.matrix_world = Matrix((x, y, z)).transposed().to_4x4()
    cam.location = center + d * L * 4
    cam.data.ortho_scale = L * 2.0
    cam.data.clip_end = L * 20
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def sheet(paths, out):
    """六張拼成兩排三格，每格上面寫視角名稱。另外存 <out>_mask.png：同樣排法、手是白的其他是黑的（疊圖用）"""
    def grid(items, dst, bg):
        args = ['magick', '-background', bg]
        for r in range(2):
            row = ['(']
            for (_, _, label), p in list(zip(VIEWS, items))[r * 3:r * 3 + 3]:
                row += ['('] + p + ['-gravity', 'north', '-splice', '0x44', '-font', FONT, '-pointsize', '28',
                                    '-fill', 'black', '-annotate', '+0+6', label, ')']
            args += row + ['+append', ')']
        args += ['-append', '+repage', dst]
        subprocess.run(args, check=True)
    grid([[p, '-background', 'rgb(194,194,193)', '-flatten'] for p in paths], out, 'white')
    grid([[p, '-alpha', 'extract'] for p in paths], os.path.splitext(out)[0] + '_mask.png', 'black')


def grid_plain(items, dst):
    """部位圖拼成跟六格圖一樣的排法（標字那條留黑），不壓字、不混色"""
    args = ['magick', '-background', 'black']
    for r in range(2):
        args += ['(']
        for p in items[r * 3:r * 3 + 3]:
            args += ['(', p, '-background', 'black', '-flatten', '-gravity', 'north', '-splice', '0x44', ')']
        args += ['+append', ')']
    subprocess.run(args + ['-append', '+repage', dst], check=True)


def render_sheet(pose_fn, bone_pts, out):
    """pose_fn('open'|'grip') 把模型擺好姿勢；bone_pts() 回傳目前姿勢下的骨頭世界座標（關節＋各指 <名>_tip 指尖）。
    存成 out（六格拼圖）＋ <out>_mask.png（遮罩）＋ <out>_joints.json（每格每個關節在拼圖上的像素位置，給量測工具把差異對到骨頭）"""
    import json
    from bpy_extras.object_utils import world_to_camera_view
    cam = setup_scene()
    import tempfile
    tmp = tempfile.mkdtemp()
    paths = []
    ids = []
    joints = []
    sc = bpy.context.scene
    for i, (pose, view, _) in enumerate(VIEWS):
        pose_fn(pose)
        bpy.context.view_layer.update()
        p = os.path.join(tmp, '%d.png' % i)
        pts = bone_pts()
        shoot(cam, hand_frame(pts), view, p)
        # 部位圖：同一個鏡頭、不打光、用 part_id 顏色，色彩轉換關掉（顏色才準）
        sh = sc.display.shading
        old = (sh.light, sh.color_type, sh.show_object_outline, sc.view_settings.view_transform, sc.render.filepath,
               sc.display.render_aa, sc.render.dither_intensity)
        sh.light, sh.color_type, sh.show_object_outline = 'FLAT', 'VERTEX', False
        sc.view_settings.view_transform = 'Standard'
        sc.display.render_aa = 'OFF'          # 不要反鋸齒、不要抖動：邊上混色會被認成別的節
        sc.render.dither_intensity = 0
        sc.render.filepath = os.path.join(tmp, 'id%d.png' % i)
        bpy.ops.render.render(write_still=True)
        (sh.light, sh.color_type, sh.show_object_outline, sc.view_settings.view_transform, sc.render.filepath,
         sc.display.render_aa, sc.render.dither_intensity) = old
        ids.append(os.path.join(tmp, 'id%d.png' % i))
        bpy.context.view_layer.update()
        x0, y0 = (i % 3) * W, (i // 3) * (H + 44) + 44
        cell = {}
        for n, co in pts.items():
            v = world_to_camera_view(sc, cam, co)
            cell[n] = [round(x0 + v.x * W, 1), round(y0 + (1 - v.y) * H, 1), round(v.z, 4)]   # z：離鏡頭多遠（前後遮擋用）
        # 每根手指張多開：指尖到手腕 ÷ 指根到手腕（握住的手指指尖會收回手掌附近，比值小）
        cell['_open'] = {f: round((pts[f + '_tip'] - pts['Hand']).length / (pts[f + '_Proximal'] - pts['Hand']).length, 2)
                         for f in ('Index', 'Middle', 'Ring', 'Little')}
        joints.append(cell)
        paths.append(p)
    sheet(paths, out)
    grid_plain(ids, os.path.splitext(out)[0] + '_parts.png')
    json.dump(joints, open(os.path.splitext(out)[0] + '_joints.json', 'w'), ensure_ascii=False)
    print('sheet ->', out)
