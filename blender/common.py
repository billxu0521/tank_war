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
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
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

def finish(name, bevel=0.012, seg=2):
    """把 _parts 裡的東西合成一個物件，加倒角"""
    global _parts
    parts = [p for p in _parts if p.name in bpy.data.objects]
    _parts = []
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    bpy.ops.object.shade_smooth()
    for p in o.data.polygons: p.use_smooth = False
    b = o.modifiers.new('bevel', 'BEVEL')
    b.width = bevel; b.segments = seg; b.limit_method = 'ANGLE'; b.angle_limit = math.radians(35)
    b.harden_normals = False
    return o
