"""灌渠農莊風格試樣的兩名角色。座標採 Blender 的公尺與 Z 朝上。"""
from collections import deque
from math import atan2, cos, pi, sin
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree


# 以原材質分區轉繪。數值是顯示器 sRGB，建立材質時轉成線性色。
PALETTE = {
    "d_olive": "7b853c", "d_belly": "e1b87b", "d_spike": "9c692f",
    "d_mouth": "843c36", "d_claw": "684c32", "tooth": "f2dba1",
    "iris": "e8ad35", "pupil": "302b27", "peg": "d4a269", "peg_ring": "80603d",
    "c_hat": "ad814c", "c_skin": "c68c65", "c_hand": "9a654a",
    "c_scarf": "bc5440", "c_duster": "795038", "c_shirt": "e8d7b7",
    "c_leather": "825339", "c_denim": "496877", "c_boot": "593e34",
    "c_glove": "623e30", "steel": "747f85", "brass": "bc985b",
    "gunmetal": "444d56", "lead": "606267", "grip": "7a4a31", "socket": "524737",
}
WOOD_COLORS = {
    "d_olive": "86905a", "d_belly": "edc693", "d_spike": "a07949",
    "c_duster": "a26d4b", "c_hat": "c49a67", "steel": "788082",
}


def _rgb(code):
    srgb = [int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [(c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in srgb]


def _material(style, key):
    name = "Cast · " + style + " · " + key
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    wood = style.endswith("+02")
    base = _rgb((WOOD_COLORS.get(key) if wood else None) or PALETTE[key])
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*base, 1)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*base, 1)
    shader.inputs["Roughness"].default_value = 0.81 if wood else 0.89
    shader.inputs["Specular IOR Level"].default_value = 0.24
    if wood and key not in ("pupil", "socket"):
        tex = nodes.new("ShaderNodeTexCoord")
        scale = nodes.new("ShaderNodeVectorMath")
        scale.operation = "MULTIPLY"
        # 以每件自己的包圍盒控制刷紋，讓近鏡手臂與二十公尺的龍都讀得到。
        scale.inputs[1].default_value = (23, 3, 18)
        links.new(tex.outputs["Generated"], scale.inputs[0])
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 1.8
        noise.inputs["Detail"].default_value = 2.0
        noise.inputs["Roughness"].default_value = 0.52
        links.new(scale.outputs[0], noise.inputs[0])
        ramp = nodes.new("ShaderNodeValToRGB")
        for element, point, strength in zip(ramp.color_ramp.elements, (0.27, 0.72), (0.72, 1.18)):
            element.position = point
            element.color = (*[min(c * strength, 1.0) for c in base], 1)
        links.new(noise.outputs["Fac"], ramp.inputs[0])
        links.new(ramp.outputs[0], shader.inputs["Base Color"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.12
        bump.inputs["Distance"].default_value = 0.001
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return mat


def _empty(name):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.empty_display_size = 0.1
    return ob


def _object(name, mesh):
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _read(project, filename):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(project / "models" / (filename + ".glb")))
    return sorted(set(bpy.data.objects) - before, key=lambda obj: obj.name)


def _key(name):
    return name.split(".")[0]


def _pose_axis(rig, bone, axis, angle):
    pb = rig.pose.bones[bone]
    basis = (rig.matrix_world @ pb.bone.matrix_local).to_quaternion()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = basis.inverted() @ Quaternion(axis, angle) @ basis


def _surface(objects, transform, role, style):
    """合併當前姿勢，以來源三角形的材質及外形為基準。"""
    vertices, faces, labels, names = [], [], [], []
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        mat = transform @ ev.matrix_world
        offset = len(vertices)
        vertices.extend(mat @ v.co for v in mesh.vertices)
        local_names = [_key(m.name) for m in mesh.materials]
        for poly in mesh.polygons:
            key = local_names[poly.material_index]
            if role == "gun" and key == "steel":
                if (ev.matrix_world @ poly.center).z < -0.012:
                    key = "grip"
                elif _key(obj.name) in ("RevolverCylinder","RevolverHammer"):
                    key = "gunmetal"
            if key not in names:
                names.append(key)
            faces.append(tuple(offset + v for v in poly.vertices))
            labels.append(names.index(key))
        ev.to_mesh_clear()
    mesh = bpy.data.meshes.new(role)
    mesh.from_pydata(vertices, [], faces)
    for key in names:
        mesh.materials.append(_material(style, key))
    mesh.polygons.foreach_set("material_index", labels)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.000001)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return _object(role, mesh)


def _dispose(objects):
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)


def _bounds(obj):
    data = np.array([tuple(v.co) for v in obj.data.vertices])
    return data.min(0), data.max(0)


def _tree(obj):
    return BVHTree.FromPolygons([v.co for v in obj.data.vertices],
                                [p.vertices[:] for p in obj.data.polygons])


def _carve(obj, target):
    mod = obj.modifiers.new("削面", "DECIMATE")
    mod.ratio = min(target / len(obj.data.polygons), 1)
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = bpy.data.meshes.new_from_object(ev)
    obj.modifiers.clear()
    obj.data = mesh
    for poly in mesh.polygons:
        poly.use_smooth = False


def _fit_bounds(obj, bounds):
    low, high = bounds
    current_low, current_high = _bounds(obj)
    scale = (high - low) / (current_high - current_low)
    for v in obj.data.vertices:
        v.co = low + (np.array(v.co) - current_low) * scale
    obj.data.update()


def _voxelize(obj, step):
    """以來源表面最近點保留薄片，輸出相鄰格之間不重疊的外殼。"""
    lo, hi = _bounds(obj)
    count = np.maximum(1, np.rint((hi - lo) / step).astype(int))
    delta = (hi - lo) / count
    tree = _tree(obj)
    filled = {}
    for idx in np.ndindex(tuple(count)):
        center = Vector(lo + (np.array(idx) + 0.5) * delta)
        hit, normal, face, dist = tree.find_nearest(center)
        # 有些原始三角形的法線朝內，不能由單一面的朝向推斷整格內外。
        if hit is not None and dist < delta.max() * 0.69:
            filled[idx] = obj.data.polygons[face].material_index
    # 從包圍盒外填入空氣，其餘空格屬於封閉的內部。
    bottom = (-1,-1,-1)
    queue, air = deque([bottom]), {bottom}
    neighbors = ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1))
    while queue:
        x,y,z = queue.popleft()
        for dx,dy,dz in neighbors:
            cell = (x+dx,y+dy,z+dz)
            if cell in air or cell in filled or any(v < -1 or v > n for v,n in zip(cell,count)):
                continue
            air.add(cell)
            queue.append(cell)
    for idx in np.ndindex(tuple(count)):
        if idx not in air and idx not in filled:
            filled[idx] = 0
    faces, labels, verts, corner_map = [], [], [], {}
    sides = (
        ((-1,0,0), ((0,0,0),(0,0,1),(0,1,1),(0,1,0))),
        ((1,0,0), ((1,0,0),(1,1,0),(1,1,1),(1,0,1))),
        ((0,-1,0), ((0,0,0),(1,0,0),(1,0,1),(0,0,1))),
        ((0,1,0), ((0,1,0),(0,1,1),(1,1,1),(1,1,0))),
        ((0,0,-1), ((0,0,0),(0,1,0),(1,1,0),(1,0,0))),
        ((0,0,1), ((0,0,1),(1,0,1),(1,1,1),(0,1,1))),
    )
    for (i,j,k), label in filled.items():
        for (a,b,c), corners in sides:
            if (i+a,j+b,k+c) in filled:
                continue
            face = []
            for x,y,z in corners:
                corner = (i+x,j+y,k+z)
                if corner not in corner_map:
                    corner_map[corner] = len(verts)
                    verts.append(lo + np.array(corner)*delta)
                face.append(corner_map[corner])
            faces.append(face)
            labels.append(label)
    mesh = bpy.data.meshes.new(obj.name + " · 方格")
    mesh.from_pydata(verts, [], faces)
    for mat in obj.data.materials:
        mesh.materials.append(mat)
    mesh.polygons.foreach_set("material_index", labels)
    mesh.update()
    obj.data = mesh


def _peg(root, style, center, axis, radius, depth, key, name, square=False):
    axis = Vector(axis).normalized()
    rot = axis.to_track_quat("Z", "Y")
    n = 4 if square else 12
    vertices = []
    for along, r in ((-depth/2, radius), (depth/3, radius), (depth/2, radius*0.87)):
        for i in range(n):
            angle = 2*pi*i/n + (pi/4 if square else 0)
            vertices.append(Vector(center) + rot @ Vector((r*cos(angle),r*sin(angle),along)))
    faces = [tuple(reversed(range(n))), tuple(range(2*n,3*n))]
    faces.extend((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i)
                 for j in range(2) for i in range(n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(_material(style,key))
    ob = _object(name,mesh)
    ob.parent = root
    return ob


def _tail_joints(obj, style):
    """完整削獸分成四段，各段在原尺寸內留端木色截面。"""
    cuts = [-3.85,-2.55,-1.35]
    original = obj.data
    parts = []
    for i, (low, high) in enumerate(zip([None]+cuts, cuts+[None])):
        bm = bmesh.new()
        bm.from_mesh(original)
        for y, inside in ((low, True),(high, False)):
            if y is None:
                continue
            plane = y + (0.013 if inside else -0.013)
            result = bmesh.ops.bisect_plane(bm,geom=bm.verts[:]+bm.edges[:]+bm.faces[:],
                plane_co=(0,plane,0),plane_no=(0,1,0),clear_inner=inside,clear_outer=not inside,dist=1e-6)
            edges = [e for e in result["geom_cut"] if isinstance(e,bmesh.types.BMEdge) and e.is_valid and e.is_boundary]
            if edges:
                fill = bmesh.ops.holes_fill(bm,edges=edges)
                for face in fill["faces"]:
                    face.material_index = len(original.materials)
        bm.normal_update()
        mesh = original.copy()
        mesh.materials.append(_material(style,"peg"))
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        if i==3:
            obj.data = mesh
        else:
            parts.append(_object("尼諾拉 · 尾節",mesh))
    return parts


def _plant_soles(obj, blend_height):
    # 每側各依實際最低點貼齊同一地面。補償量往腳踝以上平順減到零。
    vertices = obj.data.vertices
    for side in (-1,1):
        foot = [v for v in vertices if side*v.co.x > 0 and v.co.z < blend_height]
        if foot:
            floor = min(v.co.z for v in foot)
            for v in foot:
                v.co.z -= floor * max(0, (blend_height-v.co.z)/(blend_height-floor))


def _tooth(root, style, center, radius, height, side, square):
    x,y,z = center
    # 齒根嵌入唇緣，尖端稍往口內與後方收。
    vertices = [(x+dx*radius,y+dy*radius,z+.009) for dx,dy in ((-0.6,-1),(.6,-1),(.6,1),(-.6,1))]
    if square:
        vertices += [(px,py-.013,pz-height) for px,py,pz in vertices]
        faces = [(3,2,1,0),(4,5,6,7)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]
    else:
        vertices.append((x-side*.018,y-.019,z-height))
        faces = [(0,1,2,3)]+[((i+1)%4,i,4) for i in range(4)]
    mesh = bpy.data.meshes.new("牙")
    mesh.from_pydata(vertices,[],faces)
    mesh.materials.append(_material(style,"tooth"))
    ob = _object("尼諾拉 · 齒",mesh)
    ob.parent = root


def _facing(root, loc, target):
    root.location = loc
    d = Vector(target) - Vector(loc)
    root.rotation_euler.z = atan2(-d.x, d.y)


def _game_grip_matrix():
    # Godot revolver.tscn 的 grip_hand，換成 Blender Z 朝上座標。
    basis = Matrix(((.7648,0,-.6442,0),(.1904,.9553,.2260,-.018),
                    (.6154,-.2955,.7307,.024),(0,0,0,1)))
    convert = Matrix.Rotation(pi/2,4,'X')
    return convert @ basis @ convert.inverted()


def build_cast(style, project, cowboy_xyz, dino_xyz, cowboy_target_xyz, dino_target_xyz):
    if style not in {"02+06", "02+02", "07+06"}:
        raise ValueError(style)
    project = Path(project)
    voxel = style.startswith("07")
    dino_root, cowboy_root, view_root = [_empty(name) for name in ("尼諾拉","牛仔","第一人稱左輪")]
    _facing(dino_root, dino_xyz, dino_target_xyz)
    _facing(cowboy_root, cowboy_xyz, cowboy_target_xyz)
    source = _read(project,"ninola_tripo")
    rig = next(o for o in source if o.type=="ARMATURE")
    # 原始嘴張約 44 度。半闔顎保留兩排負形，雙足維持原地。
    _pose_axis(rig,"jaw",(1,0,0),0.33)
    for bone in ("tail3","tail4","tail5","tail6"):
        _pose_axis(rig,bone,(0,0,1),0.045)
    for bone, angle in (("neck",0.055), ("head",0.035)):
        _pose_axis(rig,bone,(0,0,1),angle)
    skin = next(o for o in source if o.type=="MESH" and o.data.materials)
    dino = _surface([skin],Matrix.Identity(4),"尼諾拉身體",style)
    _dispose(source)
    original = _tree(dino)
    extras = []
    for side in (-1,1):
        def lateral(y,z):
            point, normal, _, _ = original.ray_cast((side*4,y,z),(-side,0,0),8)
            return point, normal
        eye, normal = lateral(2.63,3.08)
        if eye is not None:
            extras.append(_peg(dino_root,style,eye,normal,0.104,0.045,"socket","眼窩",voxel))
            extras.append(_peg(dino_root,style,eye+normal*.029,normal,.072,.022,"iris","眼珠",voxel))
            extras.append(_peg(dino_root,style,eye+normal*.047,normal,.035,.020,"pupil","瞳孔",voxel))
        for index,y in enumerate((3.16,3.27,3.39,3.5,3.60,3.69)):
            point,_ = lateral(y,2.77)
            if point is not None:
                point.x -= side*.019
                _tooth(dino_root,style,point,.041,.10 if index % 2 else .13,side,voxel)
        if not voxel:
            for y,z,radius in ((-.04,1.56,.155),(.30,.94,.09),(1.77,2.0,.08),(2.2,2.81,.088)):
                point,_ = lateral(y,z)
                if point is None:
                    continue
                axis = Vector((side,0,0))
                extras.append(_peg(dino_root,style,point,axis,radius,.06,"peg_ring","木銷暗圈"))
                extras.append(_peg(dino_root,style,point+axis*.038,axis,radius*.72,.05,"peg","木銷端面"))
    if voxel:
        _voxelize(dino,.122)
    else:
        bounds = _bounds(dino)
        _carve(dino,1250)
        _fit_bounds(dino,bounds)
        extras.extend(_tail_joints(dino,style))
    _plant_soles(dino,.35)
    dino.parent = dino_root
    for ob in extras:
        ob.parent = dino_root
    dino_root.scale = (2.222222,)*3

    source = _read(project,"cowboy_anim")
    rig = next(o for o in source if o.type=="ARMATURE")
    anim = next(tr.strips[0].action for tr in rig.animation_data.nla_tracks
                if tr.strips and _key(tr.strips[0].action.name)=="hold")
    rig.animation_data_clear()
    track = rig.animation_data_create()
    track.action = anim
    track.action_slot = anim.slots[0]
    # 動作 hold 是一格定格；直接取本幀，不動場景時間。
    bpy.context.view_layer.update()
    def joint(suffix):
        return rig.matrix_world @ rig.pose.bones["mixamorig:"+suffix].head
    def hand(side):
        wrist = joint(side+"Hand")
        return wrist + (wrist-joint(side+"ForeArm")).normalized()*.04
    r, l = hand("Right"), hand("Left")
    elbows = [joint(s+"ForeArm") for s in ("Left","Right")]
    skin = next(o for o in source if o.type=="MESH" and o.data.materials)
    cowboy = _surface([skin],Matrix.Identity(4),"牛仔身體",style)
    _dispose(source)
    lo, hi = _bounds(cowboy)
    for v in cowboy.data.vertices:
        v.co.z -= lo[2]
    if voxel:
        _voxelize(cowboy,.043)
    else:
        bounds = _bounds(cowboy)
        _carve(cowboy,1150)
        _fit_bounds(cowboy,bounds)
        tree = _tree(cowboy)
        for side,elbow in zip((-1,1),elbows):
            p,_,_,_ = tree.ray_cast((side,elbow.y,elbow.z),(-side,0,0),2)
            if p is not None:
                _peg(cowboy_root,style,p,(side,0,0),.038,.02,"peg","牛仔肘銷")
    _plant_soles(cowboy,.25)
    cowboy.parent = cowboy_root

    source = _read(project,"revolver_tripo")
    pieces = [o for o in source if o.type=="MESH" and _key(o.name)!="RevolverRound"]
    gun = _surface(pieces,Matrix.Identity(4),"gun",style)
    _dispose(source)
    low, high = _bounds(gun)
    if voxel:
        _voxelize(gun,.0068)
    else:
        _carve(gun,2250)
    held = _object("牛仔腰射左輪",gun.data)
    held.parent = cowboy_root
    direction = (l-r).normalized()
    rotation = direction.to_track_quat('Y','Z')
    center = Vector(((low[0]+high[0])/2,low[1]+(high[1]-low[1])*.3,(low[2]+high[2])/2))
    held.location = r - rotation @ center - Vector((0,0,lo[2]))
    held.rotation_mode = "QUATERNION"
    held.rotation_quaternion = rotation

    source = _read(project,"cowboy")
    rig = next(o for o in source if o.type=="ARMATURE" and _key(o.name)=="RigGrip")
    _pose_axis(rig,"LowerArm",(0,0,1),.7)
    pieces = [o for o in source if o.type=="MESH" and _key(o.name) in ("RigGripSkin","RigGripSleeve")]
    arm = _surface(pieces,_game_grip_matrix(),"第一人稱手與袖口",style)
    _dispose(source)
    if voxel:
        _voxelize(arm,.0088)
    else:
        _carve(arm,1100)
    arm.parent = view_root
    gun.parent = view_root
    # 相機本地 +Y 朝上，-Z 向前。視角物件仍沿遊戲腰射偏移放置。
    view_root.location = (.047,-.075,-.150)
    view_root.rotation_euler.x = -pi/2 + .02
    for ob in (gun,arm):
        ob.visible_shadow = False
    state = {"cowboy":cowboy_root, "ninola":dino_root, "viewmodel":view_root}
    set_view(state,"observer",None)
    return state


def set_view(state, view, camera):
    if view not in ("cowboy","ninola","observer"):
        raise ValueError(view)
    fps = view=="cowboy"
    if fps and camera is None:
        raise ValueError("牛仔視角需要 Blender 相機")
    if camera is not None:
        state["viewmodel"].parent = camera
    for root, hidden in ((state["cowboy"],fps),(state["viewmodel"],not fps)):
        for ob in [root,*root.children_recursive]:
            ob.hide_render = hidden
            ob.hide_viewport = hidden
    bpy.context.view_layer.update()
