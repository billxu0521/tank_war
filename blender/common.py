import bpy, bmesh, math
from mathutils import Vector, Matrix

# Blender: X=right, Y=forward(Godot -Z), Z=up(Godot +Y)

def wipe():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures):
        for b in list(c):
            if b.users == 0:
                c.remove(b)

def mat(name, rgb, rough=0.6, metal=0.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    # 用類型找不用名字：Blender 介面是中文時節點名字也會被翻譯
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*rgb, 1)   # 視窗的 SOLID 模式看這個，不設的話截圖全是灰的
    return m

_parts = []

def _push(o, m):
    if m: o.data.materials.append(m)
    _parts.append(o)
    return o

def box(size, loc=(0,0,0), rot=(0,0,0), m=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _push(o, m)

def cyl(r, h, loc=(0,0,0), rot=(0,0,0), v=16, m=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    return _push(bpy.context.object, m)

def tube(r, ri, h, loc=(0,0,0), rot=(0,0,0), v=16, m=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.inset_individual(bm, faces=[f for f in bm.faces if abs(f.normal.z) > 0.9], thickness=r-ri)
    bm.to_mesh(o.data); bm.free()
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for f in o.data.polygons:
        c = o.data.vertices[f.vertices[0]].co
        if abs(f.normal.z) > 0.9 and Vector((c.x, c.y, 0)).length < ri + 1e-3:
            f.select = True
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.delete(type='FACE')
    bpy.ops.object.mode_set(mode='OBJECT')
    return _push(o, m)

def sphere(r, loc=(0,0,0), seg=16, ring=8, m=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=r, location=loc)
    return _push(bpy.context.object, m)

def cone(r1, r2, h, loc=(0,0,0), rot=(0,0,0), v=16, m=None):
    bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return _push(bpy.context.object, m)

def scale_verts(o, fn):
    """fn(co) -> co ; 用來做斜面、錐形"""
    for v in o.data.vertices:
        v.co = fn(v.co)
    return o

def finish(name, bevel=0.012, seg=2, smooth=False, smooth_mats=()):
    """把 _parts 裡的東西合成一個物件，加倒角。
    smooth=False 是硬表面（槍、坦克）：每個面平面著色，邊角才利。
    smooth=True 是生物：整顆平滑著色，不然球面一格一格像多面體。
    smooth_mats：硬表面物件裡要平滑的材質名（槍的木頭部分：金屬邊要利、木頭要圓）
    bevel=0 不加倒角。建築和場景小物件都是 0：一塊木板加一段倒角，三角形從 12 變 44，一棟房子 2 萬變 8 萬，
    遠看又看不出差別（2026-10-03 量過，docs/效能.md）。只有拿在手上近看的槍、牛仔保留"""
    parts = [p for p in _parts if p.name in bpy.data.objects]
    _parts.clear()   # 原地清空：import 這支工具的腳本拿的是同一份清單
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    bpy.ops.object.shade_smooth()
    if not smooth:
        names = [s.material.name if s.material else '' for s in o.material_slots]
        for p in o.data.polygons:
            p.use_smooth = bool(names) and names[p.material_index] in smooth_mats
    b = o.modifiers.new('bevel', 'BEVEL')
    b.width = bevel; b.segments = seg; b.limit_method = 'ANGLE'; b.angle_limit = math.radians(35)
    b.harden_normals = False
    return o

# ---- 碰撞：蓋牆的時候順便記一份，最後變成 *Col 物件給遊戲當碰撞形狀 ----
# 牆、門洞、窗洞只定義一次，畫面和碰撞一定對得上
COL = []


def solid(size, loc, rot=(0, 0, 0), m=None):
    """有碰撞的方塊：牆、閣樓地板、柱子、家具"""
    COL.append((size, loc, rot))
    return box(size, loc, rot, m=m)


def make_col(name):
    """把記下來的碰撞方塊合成一個物件（沒有倒角、沒有材質，遊戲裡只拿來做形狀）"""
    for size, loc, rot in COL:
        box(size, loc, rot)
    COL.clear()
    return finish(name, bevel=0.0, seg=1)


def wall(axis, at, a0, a1, h, t, openings, m):
    """一面有開口的牆。axis='x'：沿 X 的牆（前後牆），在 y=at；axis='y'：沿 Y 的牆（側牆），在 x=at。
    openings = [(中心, 寬, 下緣, 上緣)]。開口兩側整片、開口上下各補一塊"""
    def piece(u0, u1, z0, z1):
        if u1 - u0 < 0.01 or z1 - z0 < 0.01:
            return
        cu, cz = (u0 + u1) / 2, (z0 + z1) / 2
        if axis == 'x':
            solid((u1 - u0, t, z1 - z0), (cu, at, cz), m=m)
        else:
            solid((t, u1 - u0, z1 - z0), (at, cu, cz), m=m)
    u = a0
    for (c, w, b, top) in sorted(openings):
        piece(u, c - w / 2, 0, h)
        piece(c - w / 2, c + w / 2, 0, b)
        piece(c - w / 2, c + w / 2, top, h)
        u = c + w / 2
    piece(u, a1, 0, h)


def clear_of(u, openings, pad=0.1):
    """u 這個位置有沒有落在某個開口的寬度裡；有就回傳那個開口（護牆板要在那裡斷開）"""
    for o in openings:
        if abs(u - o[0]) < o[1] / 2 + pad:
            return o
    return None


def view(eye, target, persp=True):
    """視窗從 eye 看向 target（Blender 座標）。截圖檢查用，比手調四元數可靠"""
    eye, target = Vector(eye), Vector(target)
    d = target - eye
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces[0]
            sp.shading.type = 'SOLID'
            sp.shading.color_type = 'MATERIAL'
            sp.overlay.show_floor = False
            sp.overlay.show_axis_x = False
            sp.overlay.show_axis_y = False
            r3 = sp.region_3d
            r3.view_perspective = 'PERSP' if persp else 'ORTHO'
            r3.view_rotation = d.to_track_quat('-Z', 'Y')
            r3.view_location = target
            r3.view_distance = d.length
    bpy.ops.object.select_all(action='DESELECT')
