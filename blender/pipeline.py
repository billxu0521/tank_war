# 建模腳本共用的入口：讀參數、送審前的自動檢查、匯出、預覽渲染。每支腳本只寫「怎麼建」和「預覽怎麼排」。
#
#   import pipeline
#   pipeline.run(build_all, preview, budget=8000)
#
# build_all() 回傳要匯出的物件；preview(obs, path) 自己排版後呼叫 studio() 渲染（或直接用 scene_preview）。
# 背景跑：Blender --background --factory-startup --python blender/<名字>.py -- --out x.glb --preview x.png
# 自動檢查沒過會印「CHECK FAIL」、不匯出也不渲染，tools/model_iter.sh 看到就停，不送審（見 docs/程式建模迭代.md）。
import bpy, bmesh, math, os, sys
from mathutils import Vector


def args():
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    return {k: (a[a.index(k) + 1] if k in a else None) for k in ('--out', '--preview')}


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def export(obs, path):
    """選取 obs 匯出成一個 glb（旋轉、縮放烘進網格；y 朝上）"""
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    print('exported ->', path)


def check(obs, budget=None):
    """送審前自動檢查，回傳問題清單（空的就是過了）。抓的都是以前要等審查、甚至進遊戲才發現的錯：
    - 面數超過預算（budget：一個數字，或 {名字: 數字, '*': 其他}）
    - 有材質但沒有任何面用它：該長出來的東西沒長出來（仙人掌的刺曾經兩版都沒生成）
    - 葉片卡（材質名有 leafcard）沒有渲染用的貼圖座標：葉子整片取到透明的角落、消失
    - 封閉的零件是反面（體積是負的）：光照整個相反，看起來是一片暗"""
    probs = []
    for o in obs:
        if o.type != 'MESH':
            continue
        me = o.data
        n = tris(o)
        if n == 0:
            probs.append('%s 沒有任何面' % o.name)
            continue
        cap = budget.get(o.name, budget.get('*')) if isinstance(budget, dict) else budget
        if cap and n > cap:
            probs.append('%s 面數 %d 超過預算 %d' % (o.name, n, cap))
        used = {p.material_index for p in me.polygons}
        for i, m in enumerate(me.materials):
            if m and i not in used:
                probs.append('%s 的材質 %s 沒有任何面（該長的東西沒長出來？）' % (o.name, m.name))
        if any(m and 'leafcard' in m.name for m in me.materials):
            if not me.uv_layers or not any(l.active_render for l in me.uv_layers):
                probs.append('%s 有葉片卡但沒有渲染用的貼圖座標' % o.name)
        flipped = _flipped_parts(me)
        if flipped:
            probs.append('%s 有 %d 塊封閉零件是反面' % (o.name, flipped))
    return probs


def _flipped_parts(me):
    """封閉（每條邊剛好兩個面）的零件裡，體積算出來是負的有幾塊"""
    bm = bmesh.new()
    bm.from_mesh(me)
    seen, bad = set(), 0
    for f in bm.faces:
        if f.index in seen:
            continue
        island, stack = [], [f]
        seen.add(f.index)
        while stack:
            g = stack.pop()
            island.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        edges = {e for g in island for e in g.edges}
        if len(island) < 4 or any(len(e.link_faces) != 2 for e in edges):
            continue
        vol = 0.0
        for g in island:
            vs = [v.co for v in g.verts]
            for i in range(1, len(vs) - 1):
                vol += vs[0].dot(vs[i].cross(vs[i + 1]))
        if vol < -1e-6:
            bad += 1
    bm.free()
    return bad


def studio(path, ortho, loc, res=(1680, 940), side=False):
    """正交相機從 -Y 往 +Y 看（side=True 從 +X 往 -X 看）、暖色斜光、Cycles 渲染到 path（白底由 tools/model_iter.sh 墊）"""
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ortho
    cam.location = loc
    cam.rotation_euler = (math.radians(90), 0, math.radians(90) if side else 0)
    sc.collection.objects.link(cam)
    sc.camera = cam

    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy = 8.0
    sun.data.color = (1.0, 0.83, 0.58)                               # 淡暖黃（約 #FFEBC8）：受光面金黃、側面還留得住橄欖綠，太橘整棵會變芥末色
    sun.rotation_euler = (math.radians(35), 0, math.radians(35))   # 右前上方仰角約 55 度：每團都有亮面和暗面
    sc.collection.objects.link(sun)

    world = bpy.data.worlds.new('w')
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (0.58, 0.6, 0.48, 1)        # 約 #C8CCB8 帶一點綠的環境光，暗面才是深橄欖不是灰藍
    bg.inputs['Strength'].default_value = 0.28   # 太弱暗面會變黑
    sc.world = world

    # Cycles：光線追蹤才有葉團之間的暗縫和互相投影，跟參考圖一樣（EEVEE 預設沒有，整團會糊成一片）
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 64
    sc.cycles.transparent_max_bounces = 128   # 葉片卡一疊幾十層透明，預設 8 層穿不過去會變黑
    prefs = bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type = 'METAL'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = 'GPU'
    except TypeError:
        pass   # 沒有 Metal 就用 CPU
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('preview ->', path)


def scene_preview(obs, path, res=(1680, 940), side=False):
    """沒有自己排版的腳本用這個：物件照現在的位置，相機從正面（side=True 從右側）框住全部"""
    pts = [o.matrix_world @ Vector(c) for o in obs if o.type == 'MESH' for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2
    across = (hi.y - lo.y) if side else (hi.x - lo.x)
    size = max(across, (hi.z - lo.z) * res[0] / res[1]) * 1.1
    studio(path, size, (hi.x + 50, c.y, c.z) if side else (c.x, lo.y - 50, c.z), res, side)


def run(build, preview=None, budget=None, export_fn=None, preview_first=False):
    """讀參數 → 建模 → 印面數 → 自動檢查（沒過就停） → 匯出 → 預覽。
    export_fn(obs, out)：自己的匯出（一支腳本出好幾個 glb 的）；preview_first：匯出會搬動物件的（恐龍），先渲染再匯出"""
    a = args()
    obs = build()
    for o in obs:
        if o.type == 'MESH':
            print(o.name, 'tris:', tris(o), 'size:', tuple(round(x, 2) for x in o.dimensions))
    probs = check(obs, budget)
    if probs:
        for p in probs:
            print('CHECK FAIL:', p)
        return
    print('CHECK OK')
    if a['--preview'] and preview_first:
        (preview or scene_preview)(obs, a['--preview'])
    if a['--out']:
        (export_fn or export)(obs, a['--out'])
    if a['--preview'] and not preview_first:
        (preview or scene_preview)(obs, a['--preview'])
