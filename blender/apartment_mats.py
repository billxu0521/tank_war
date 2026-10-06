# 台灣老公寓（apartment.py）的程式材質：在 Blender 裡把平面顏色換成有髒污、流痕、鏽、褪色的節點材質。
# 不用貼圖照片，全用雜訊（Noise）和漸層算；座標用物件座標（3D 雜訊不需要 UV，合併後的網格也能用）。
# ponytail: glb 匯出只認圖片貼圖，節點算出來的花紋不會跟過去 → 只在預覽和 Blender 場景用（apartment.py 的 preview 呼叫），
#   遊戲用的 apartments.glb 維持平面色。要進遊戲再把這些材質烘焙（bake）成貼圖。
import bpy

# 每種材質：底色從原本材質拿，下面的參數決定加什麼
#   mottle 大斑塊深淺、streak 垂直雨水流痕、ground 底部潮濕變暗、rust 鏽斑（顏色）、fade 褪色變白（浪板）、bump 表面凹凸
RECIPES = {
    # B 的米褐牆：剝落露出更淺的米白（同色系的米褐斑在米褐牆上看不到，v12）。要排在 ap_wall 前面，先比對到
    'ap_wall_b':   dict(mottle=0.6, peel=0.8, peel_col=((0.48, 0.42, 0.33), (0.13, 0.09, 0.055)), streak=0.75, stain=0.6, ground=0.75, ground_h=2.4, bump=0.15, rough=0.95),
    'ap_wall':     dict(mottle=0.6, peel=0.85, streak=0.75, stain=0.6, ground=0.75, ground_h=2.4, bump=0.15, rough=0.95),   # 2026-10-07 使用者：髒污要更明顯
    'ap_trim':     dict(peel=0.7, mottle=0.5, streak=0.6, stain=0.4, ground=0.5, bump=0.1, rough=0.95),
    'ap_band':     dict(peel=0.6, mottle=0.35, streak=0.3, fade=0.25, bump=0.05, rough=0.9),
    'ap_awning':   dict(mottle=0.25, fade=0.55, rust=(0.22, 0.09, 0.03), rust_amt=0.35, bump=0.05, rough=0.55),
    'ap_iron':     dict(mottle=0.2, rust=(0.35, 0.12, 0.03), rust_amt=0.6, bump=0.2, rough=0.75),
    'ap_ac':       dict(mottle=0.2, streak=0.5, ground=0.0, bump=0.02, rough=0.6),
    'ap_shutter':  dict(mottle=0.25, streak=0.4, rust=(0.25, 0.1, 0.04), rust_amt=0.3, rough=0.5),
    'ap_pave':     dict(mottle=0.5, bump=0.25, rough=0.95, scale=0.6),
    'ap_curb':     dict(mottle=0.4, bump=0.2, rough=0.95),
    'ap_pole':     dict(mottle=0.5, streak=0.6, ground=0.6, bump=0.15, rough=0.9),
    'ap_tank':     dict(mottle=0.2, streak=0.3, fade=0.15, rough=0.45),
    'ap_cabinet':  dict(mottle=0.25, streak=0.35, fade=0.2, rust=(0.25, 0.1, 0.04), rust_amt=0.2, rough=0.6),
    'ap_frame':    dict(mottle=0.3, rough=0.8),
    'ap_door_wood': dict(mottle=0.35, streak=0.2, bump=0.1, rough=0.8),
    'ap_breeze':   dict(mottle=0.45, streak=0.55, bump=0.15, rough=0.95),
    'ap_tiles':    dict(mottle=0.4, streak=0.65, stain=0.45, ground=0.35),   # 有貼圖：疊在貼圖上
}


def _recipe(name):
    for k, r in RECIPES.items():
        if name.startswith(k):
            return r
    return None


def upgrade():
    """把場景裡用到的 ap_* 材質換成節點材質（原地改，名字不變）。重複呼叫只會做一次"""
    for m in bpy.data.materials:
        r = _recipe(m.name)
        if r is None or m.get('procedural'):
            continue
        _build(m, r)
        m['procedural'] = True


def _build(m, r):
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    bsdf = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
    img = next((n for n in N if n.type == 'TEX_IMAGE'), None)
    base = tuple(bsdf.inputs['Base Color'].default_value)
    sc = r.get('scale', 1.0)

    coord = N.new('ShaderNodeTexCoord')
    def noise(scale, detail=4.0, rough=0.6, stretch=(1, 1, 1)):
        mp = N.new('ShaderNodeMapping')
        mp.inputs['Scale'].default_value = stretch
        L.new(coord.outputs['Object'], mp.inputs['Vector'])
        n = N.new('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale * sc
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = rough
        L.new(mp.outputs['Vector'], n.inputs['Vector'])
        return n.outputs['Fac']

    def ramp(fac, lo, hi):
        """把 0..1 的雜訊壓成 lo..hi 之間的硬一點的遮罩"""
        cr = N.new('ShaderNodeValToRGB')
        cr.color_ramp.elements[0].position = lo
        cr.color_ramp.elements[1].position = hi
        L.new(fac, cr.inputs['Fac'])
        return cr.outputs['Color']

    def mix(a, b, fac, blend='MIX'):
        mx = N.new('ShaderNodeMix')
        mx.data_type = 'RGBA'
        mx.blend_type = blend
        if isinstance(fac, float):
            mx.inputs['Factor'].default_value = fac
        else:
            L.new(fac, mx.inputs['Factor'])
        for sock, v in ((mx.inputs[6], a), (mx.inputs[7], b)):
            if isinstance(v, tuple):
                sock.default_value = v if len(v) == 4 else (*v, 1)
            else:
                L.new(v, sock)
        return mx.outputs[2]

    col = img.outputs['Color'] if img else base
    dark = tuple(c * 0.42 for c in base[:3])
    light = tuple(min(1.0, c * 1.35 + 0.02) for c in base[:3])

    # 大斑塊：同一面牆深淺不一（參考圖的手繪斑駁）
    if r.get('mottle'):
        f = ramp(noise(0.35, 6, 0.65), 0.35, 0.7)
        col = mix(col, mix(dark if not img else (0.55, 0.53, 0.5), light if not img else (1, 1, 1), f), r['mottle'], 'MULTIPLY' if img else 'MIX')
    # 剝落斑：漆掉了露出底下的米褐水泥，一塊塊邊緣清楚（參考圖最明顯的就是這個，不是深色髒污，v10）
    if r.get('peel'):
        f = ramp(noise(0.4, 6, 0.7), 0.53, 0.56)   # 0.6 門檻幾乎不會觸發（雜訊大多落在 0.35~0.65，v11）
        c1, c2 = r.get('peel_col', ((0.30, 0.24, 0.16), (0.36, 0.30, 0.21)))
        col = mix(col, c1, _mulf(N, L, f, r['peel']))
        f2 = ramp(noise(1.2, 6, 0.7), 0.6, 0.63)   # 小塊的
        col = mix(col, c2, _mulf(N, L, f2, r['peel']))
    # 垂直流痕：雜訊在 Z 方向拉長 → 一條條往下流的暗痕
    if r.get('streak'):
        f = ramp(noise(1.3, 3, 0.5, (1.0, 1.0, 0.06)), 0.5, 0.68)   # 寬一點，遊戲距離才看得到
        col = mix(col, (0.045, 0.04, 0.03), _mulf(N, L, f, r['streak']))
    # 大片水漬：寬的、往下拉長的褐黑色水痕（樓板、窗台下面流下來的那種）
    if r.get('stain'):
        f = ramp(noise(0.9, 5, 0.6, (1.0, 1.0, 0.25)), 0.55, 0.85)
        col = mix(col, (0.07, 0.06, 0.04), _mulf(N, L, f, r['stain']))
    # 底部潮濕：靠地面一米內變暗（雨水濺、青苔）
    if r.get('ground'):
        sep = N.new('ShaderNodeSeparateXYZ')
        L.new(coord.outputs['Object'], sep.inputs['Vector'])
        mr = N.new('ShaderNodeMapRange')
        mr.inputs['From Min'].default_value = 0.3
        mr.inputs['From Max'].default_value = r.get('ground_h', 1.6)
        mr.inputs['To Min'].default_value = r['ground']
        mr.inputs['To Max'].default_value = 0.0
        L.new(sep.outputs['Z'], mr.inputs['Value'])
        col = mix(col, (0.05, 0.06, 0.04), mr.outputs['Result'])
    # 褪色：曬白的一塊塊（浪板、招牌）
    if r.get('fade'):
        f = ramp(noise(1.2, 4, 0.6), 0.5, 0.8)
        col = mix(col, (0.75, 0.75, 0.68), _mulf(N, L, f, r['fade']))
    # 鏽斑：小點狀，邊緣硬
    if r.get('rust'):
        f = ramp(noise(6.0, 8, 0.7), 0.6, 0.68)
        col = mix(col, r['rust'], _mulf(N, L, f, r['rust_amt']))
    L.new(col, bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = r.get('rough', 0.8)
    # 表面凹凸：小尺度雜訊
    if r.get('bump'):
        bp = N.new('ShaderNodeBump')
        bp.inputs['Strength'].default_value = r['bump']
        bp.inputs['Distance'].default_value = 0.02
        L.new(noise(14.0, 6, 0.6), bp.inputs['Height'])
        L.new(bp.outputs['Normal'], bsdf.inputs['Normal'])


def _mulf(N, L, color_out, k):
    """遮罩（顏色）× 強度 → 一個數字"""
    mt = N.new('ShaderNodeMath')
    mt.operation = 'MULTIPLY'
    mt.inputs[1].default_value = k
    L.new(color_out, mt.inputs[0])
    return mt.outputs['Value']


def bake(o, path, size=4096):
    """把 o 的所有材質（節點算的花紋、招牌字、磁磚貼圖）烘焙成一張顏色貼圖，換成只用這張圖的單一材質。
    步驟：自動展一套新的 UV（BakeUV）→ 每個材質放一個圖片節點當烘焙目標 → Cycles 只烤「漫射顏色」（不含光影）→ 存檔、換材質。
    原本的 UVMap（招牌、磁磚用）留著給圖片節點讀，烘焙寫進 BakeUV"""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 4
    for ob in sc.objects:
        ob.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    me = o.data
    if 'UVMap' not in me.uv_layers:
        me.uv_layers.new(name='UVMap')
    for m in me.materials:   # 原本的圖片節點固定讀 UVMap（等一下 BakeUV 會變成作用中的那套）
        for n in list(m.node_tree.nodes):
            if n.type == 'TEX_IMAGE' and not n.inputs['Vector'].is_linked:
                uvn = m.node_tree.nodes.new('ShaderNodeUVMap')
                uvn.uv_map = 'UVMap'
                m.node_tree.links.new(uvn.outputs['UV'], n.inputs['Vector'])
    uv = me.uv_layers.new(name='BakeUV')
    me.uv_layers.active = uv
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')
    img = bpy.data.images.new(o.name + '_bake', size, size)
    for m in me.materials:
        tn = m.node_tree.nodes.new('ShaderNodeTexImage')
        tn.image = img
        uvn = m.node_tree.nodes.new('ShaderNodeUVMap')
        uvn.uv_map = 'BakeUV'
        m.node_tree.links.new(uvn.outputs['UV'], tn.inputs['Vector'])
        for n in m.node_tree.nodes:
            n.select = False
        tn.select = True
        m.node_tree.nodes.active = tn
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=4, use_clear=True)
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    # 換成單一材質：BakeUV 讀這張圖。舊的 UV 拿掉，glb 只帶一套
    bm = bpy.data.materials.new(o.name + '_baked')
    bm.use_nodes = True
    p = next(n for n in bm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Roughness'].default_value = 0.85
    t = bm.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = img
    bm.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    me.materials.clear()
    me.materials.append(bm)
    for poly in me.polygons:
        poly.material_index = 0
    me.uv_layers.remove(me.uv_layers['UVMap'])
    print('baked ->', path)
