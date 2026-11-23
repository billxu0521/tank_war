"""以四棟 r005 的逐件組裝資料，在獨立目錄重建 Blender 來源與 GLB。"""

import argparse
import copy
import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "blender"))
import pipeline

ASSETS = ROOT / "models/cd_gbb/envelope_r005"
MATERIALS = {}
BOX_FACES = {
    "X-": (0, 1, 3, 2),
    "X+": (4, 6, 7, 5),
    "Y-": (0, 4, 5, 1),
    "Y+": (2, 3, 7, 6),
    "Z-": (0, 2, 6, 4),
    "Z+": (1, 5, 7, 3),
}


def base_material(name):
    aid, rgb, rough, metal = MATERIALS[name]
    m = bpy.data.materials.get("gbb_" + name)
    if m:
        return m
    m = bpy.data.materials.new("gbb_" + name)
    m.diffuse_color = (*rgb, 0.28 if name == "glass" else 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Specular IOR Level"].default_value = 0.1 if name != "glass" else 0.3
    if name == "glass":
        bs.inputs["Alpha"].default_value = 0.28
        m.surface_render_method = "DITHERED"
    m["asset_id"] = aid
    return m


def cube(part):
    size = part["parameters"]["size_m"]
    bpy.ops.mesh.primitive_cube_add(size=1, location=part["position"])
    o = bpy.context.object
    o.name = part["name"]
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = part["rotation"]
    o.data.materials.append(base_material(part["material"]))
    bevel = part["bevel"]
    if bevel:
        mod = o.modifiers.new("edge_softening", "BEVEL")
        mod.width = min(bevel, min(size) * 0.16)
        mod.segments = 1
        mod.affect = "EDGES"
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o["asset_id"] = part["asset"]
    o["component"] = part["component"]
    o["source_revision"] = "r001"
    o["parameters_json"] = json.dumps(part["parameters"])
    o["assembly_part"] = part["name"]
    o["assembly_group"] = part["group"]
    o["portal_parent"] = part["parent"] or ""
    return o


def material(kind):
    if kind == "glass":
        return base_material("glass")
    family = (
        "wood" if "wood" in kind else ("adobe" if kind in ("adobe", "repair") else kind)
    )
    name = "detail_vertex_" + family
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    base = MATERIALS[kind]
    bs.inputs["Roughness"].default_value = base[2]
    bs.inputs["Metallic"].default_value = base[3]
    node = m.node_tree.nodes.new("ShaderNodeVertexColor")
    node.layer_name = "DetailColor"
    m.node_tree.links.new(node.outputs["Color"], bs.inputs["Base Color"])
    return m


def paint(o, p):
    o.data.materials.clear()
    o.data.materials.append(material(p["material"]))
    if p["material"] != "glass":
        rgb = MATERIALS[p["material"]][1]
        tone = p.get("tone", 1)
        layer = o.data.color_attributes.new(
            name="DetailColor", type="FLOAT_COLOR", domain="CORNER"
        )
        for item in layer.data:
            item.color = (*(c * tone for c in rgb), 1)
    for key, value in [
        ("unit", p.get("unit", "shell")),
        ("assembly_group", p.get("group", "structure")),
        ("component", p.get("component", "detail")),
        ("stable_id", p.get("stable_id", p["name"])),
        ("asset_id", p.get("asset", "local:detail_subpart")),
    ]:
        o[key] = value
    return o


def mesh(p, verts, faces, loc=(0, 0, 0), rot=(0, 0, 0), recalc=False):
    data = bpy.data.meshes.new(p["name"])
    data.from_pydata(verts, [], faces)
    data.update()
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0000001)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(data)
        bm.free()
    o = bpy.data.objects.new(p["name"], data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return paint(o, p)


def visible_box(p):
    x, y, z = [v / 2 for v in p["parameters"]["size_m"]]
    verts = [
        (-x, -y, -z),
        (-x, -y, z),
        (-x, y, -z),
        (-x, y, z),
        (x, -y, -z),
        (x, -y, z),
        (x, y, -z),
        (x, y, z),
    ]
    return mesh(
        p,
        verts,
        [BOX_FACES[k] for k in p["runtime_faces"]],
        p["position"],
        p["rotation"],
    )


def recess_wall(p):
    desc = p["recess"]
    axis = desc["axis"]
    c = desc["center"]
    r = desc["radius"]
    depth = desc["depth"]
    pos = p["position"]
    size = p["parameters"]["size_m"]
    along_axis = 0 if axis == "u" else 1
    depth_axis = 1 - along_axis
    low = pos[along_axis] - size[along_axis] / 2
    high = pos[along_axis] + size[along_axis] / 2
    bottom = pos[2] - size[2] / 2
    top = pos[2] + size[2] / 2
    front = pos[depth_axis] + size[depth_axis] / 2
    back = pos[depth_axis] - size[depth_axis] / 2
    angles = [2 * math.pi * i / 16 for i in range(16)] + [
        math.atan2(z - c[1], a - c[0]) % (2 * math.pi)
        for a, z in [(low, bottom), (high, bottom), (high, top), (low, top)]
    ]
    angles = sorted(angles)
    inner = []
    outer = []

    for i, angle in enumerate(angles):
        da, dz = math.cos(angle), math.sin(angle)
        j = edge_radius(desc["seed_key"], i)
        inner.append((c[0] + da * r[0] * j, c[1] + dz * r[1] * j))
        distances = []
        if abs(da) > 1e-9:
            distances.append(((high - c[0]) if da > 0 else (low - c[0])) / da)
        if abs(dz) > 1e-9:
            distances.append(((top - c[1]) if dz > 0 else (bottom - c[1])) / dz)
        t = min(q for q in distances if q > 0)
        outer.append((c[0] + da * t, c[1] + dz * t))

    def point(a, d, z):
        return (a, d, z) if axis == "u" else (d, a, z)

    verts = []
    faces = []
    n = len(angles)
    for d, loop in [
        (front, outer),
        (front, inner),
        (front - depth, inner),
        (back, outer),
    ]:
        verts.extend(point(a, d, z) for a, z in loop)
    verts.extend([point(c[0], front - depth, c[1]), point(c[0], back, c[1])])
    floor = 4 * n
    rear = floor + 1
    for i in range(n):
        j = (i + 1) % n
        faces += [
            (i, j, n + j, n + i),
            (n + i, n + j, 2 * n + j, 2 * n + i),
            (floor, 2 * n + i, 2 * n + j),
            (rear, 3 * n + j, 3 * n + i),
            (i, 3 * n + i, 3 * n + j, j),
        ]
    return mesh(p, verts, faces, recalc=True)


def make_parts(spec, optimized=False):
    parents = {}
    obs = []
    for portal in spec["portals"]:
        o = bpy.data.objects.new(portal["name"], None)
        bpy.context.collection.objects.link(o)
        o.location = portal["hinge"]
        o.rotation_euler.z = portal["yaw"]
        parents[portal["name"]] = o
    for p0 in spec["parts"]:
        p = dict(p0)
        if (
            optimized
            and p["component"] in ("roof_sheet", "purlin")
            and spec["id"].endswith("07")
            and not spec.get("explicit_roof_parts", False)
        ):
            continue
        if "recess" in p:
            o = recess_wall(p)
        elif optimized and p.get("runtime_faces"):
            o = visible_box(p)
        else:
            if optimized:
                p["bevel"] = 0.008 if p["component"] in ("pillow", "bedroll") else 0
            o = cube(p)
            paint(o, p)
        if p.get("parent"):
            o.parent = parents[p["parent"]]
        obs.append(o)
    for p in spec["mesh_details"]:
        o = mesh(p, p["vertices"], p["faces"])
        if p.get("parent"):
            o.parent = parents[p["parent"]]
        obs.append(o)
    for f in spec["fixings"]:
        n = Vector(f["normal"])
        t = Vector((1, 0, 0)) if abs(n.x) < 0.5 else Vector((0, 1, 0))
        b = n.cross(t)
        s = f["size"] / 2
        c = Vector(f["point"]) + n * 0.0004
        verts = [
            c - t * s - b * s,
            c + t * s - b * s,
            c + t * s + b * s,
            c - t * s + b * s,
        ]
        p = dict(
            name=f["name"],
            material="iron",
            unit=f["unit"],
            parent=f.get("parent"),
            component="nail_head",
            group="structure",
            tone=1,
        )
        o = mesh(p, verts, [(0, 1, 2, 3)])
        if p["parent"]:
            o.parent = parents[p["parent"]]
        obs.append(o)
    return obs, parents


def packed(obs, parents):
    groups = {}
    for o in obs:
        owner = o.parent.name if o.parent else o["unit"]
        groups.setdefault((owner, o.data.materials[0].name), []).append(o)
    result = []
    for (owner, mat), group in sorted(groups.items()):
        bpy.ops.object.select_all(action="DESELECT")
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        if len(group) > 1:
            bpy.ops.object.join()
        group[0].name = owner + "__" + mat
        result.append(group[0])
    return result + list(parents.values())


def edge_radius(part, index):
    key = ["variation-r001", 20261025, "CD-GBB-BLD-01", part, "edge", str(index)]
    digest = hashlib.sha256(
        json.dumps(key, ensure_ascii=False, separators=(",", ":")).encode()
    ).digest()
    unit = (int.from_bytes(digest[:7], "big") >> 3) / (2**53)
    return 0.88 + (1.10 - 0.88) * unit


def plaster_normal():
    name = "local_plaster_isotropic_128"
    image = bpy.data.images.get(name)
    if image is None:
        image = bpy.data.images.load(str(ASSETS / "plaster_normal.png"))
        image.name = name
        image.colorspace_settings.name = "Non-Color"
        image.pack()
    return image


def finish_parts(spec, optimized=False):
    # 保留r002作者／匯出邏輯；新輪件旋轉用矩陣左乘。
    obs, parents = make_parts(spec, optimized)
    byname = {p["name"]: p for p in spec["parts"] + spec["mesh_details"]}
    for o in obs:
        p = byname.get(o.name)
        if not p:
            continue
        if "pre_rotation_x" in p:
            o.rotation_euler = (
                Matrix.Rotation(p["pre_rotation_x"], 3, "X")
                @ o.rotation_euler.to_matrix()
            ).to_euler()
        if p.get("soft_outer_corners"):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            edges = []
            for edge in bm.edges:
                a, b = [o.matrix_world @ v.co for v in edge.verts]
                if (
                    abs(a.x - b.x) + abs(a.y - b.y) < 1e-6
                    and abs(a.z - b.z) > 0.2
                    and any(
                        abs(a.x - x) + abs(a.y - y) < 1e-5
                        for x, y in [(0, 0), (16, 0), (0, 12), (16, 12)]
                    )
                ):
                    edges.append(edge)
            if edges:
                bmesh.ops.bevel(
                    bm, geom=edges, offset=0.035, segments=1, affect="EDGES"
                )
                bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(o.data)
            bm.free()
        if p.get("component") == "plaster_return":
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(o.data)
            bm.free()
        if p.get("plaster_finish"):
            old = o.data.materials[0]
            m = bpy.data.materials.get("detail_vertex_adobe_finish")
            if not m:
                m = old.copy()
                m.name = "detail_vertex_adobe_finish"
                nodes = m.node_tree.nodes
                tex = nodes.new("ShaderNodeTexImage")
                tex.image = plaster_normal()
                normal = nodes.new("ShaderNodeNormalMap")
                normal.inputs["Strength"].default_value = 0.65
                m.node_tree.links.new(tex.outputs["Color"], normal.inputs["Color"])
                m.node_tree.links.new(
                    normal.outputs["Normal"],
                    nodes.get("Principled BSDF").inputs["Normal"],
                )
            o.data.materials[0] = m
            uv = o.data.uv_layers.new(name="PlasterUV")
            o.data.uv_layers.active = uv
            uv.active_render = True
            tex = m.node_tree.nodes.get("Image Texture")
            if tex and not tex.inputs["Vector"].is_linked:
                node = m.node_tree.nodes.new("ShaderNodeUVMap")
                node.uv_map = "PlasterUV"
                m.node_tree.links.new(node.outputs["UV"], tex.inputs["Vector"])
            layer = o.data.color_attributes.get("DetailColor")
            for poly in o.data.polygons:
                n = poly.normal
                axis = max(range(3), key=lambda k: abs(n[k]))
                axes = [k for k in range(3) if k != axis]
                for li in poly.loop_indices:
                    co = (
                        o.matrix_world
                        @ o.data.vertices[o.data.loops[li].vertex_index].co
                    )
                    uv.data[li].uv = (co[axes[0]] / 1.5, co[axes[1]] / 1.5)
                    if layer:
                        # 連續位置取樣的小幅泥灰色差，不讓每塊牆段有不同色方框。
                        t = 1 + 0.025 * math.sin(
                            co.x * 0.65 + co.y * 0.72 + co.z * 0.33
                        )
                        rgb = MATERIALS["adobe"][1]
                        layer.data[li].color = (*(c * t for c in rgb), 1)
    return obs, parents


def furnish(spec, optimized=False):
    obs, parents = finish_parts(spec, optimized)
    # 新自訂輪廓重算法線；舊來源保持不變。
    for o in obs:
        if str(o.get("unit", "")).startswith(
            ("a1_", "a2_", "a3_", "a4_", "a5_", "a6_", "a7_")
        ):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(o.data)
            bm.free()
    byname = {p["name"]: p for p in spec["parts"]}
    for desc in spec["prop_hinges"]:
        obj = bpy.data.objects.new(desc["name"], None)
        bpy.context.collection.objects.link(obj)
        obj.location = desc["pivot"]
        parents[obj.name] = obj
        bpy.context.view_layer.update()
        for o in obs:
            if byname.get(o.name, {}).get("prop_parent") == obj.name:
                transform = o.matrix_world.copy()
                o.parent = obj
                o.matrix_world = transform
    return obs, parents


def color_sections(o, p):
    layer = o.data.color_attributes.get("DetailColor")
    if not layer:
        return
    role = p["component"]
    size = p.get("parameters", {}).get("size_m", [1, 1, 1])
    # 板側／端頭材面與平整板面不同；不按世界光源方向塗黑。
    if role == "cladding":
        grain = 2
        thin = 0 if size[0] < size[1] else 1
    elif role == "table_top":
        grain = 0 if size[0] > size[1] else 1
        thin = 2
    elif role == "door_plank":
        grain = 2
        thin = 1
    elif role in ("frame", "sill"):
        grain = max(range(3), key=lambda k: size[k])
        thin = min(range(3), key=lambda k: size[k])
    else:
        return
    for face in o.data.polygons:
        n = face.normal
        axis = max(range(3), key=lambda k: abs(n[k]))
        factor = 0.66 if axis == grain else (0.79 if axis != thin else 1.0)
        for li in face.loop_indices:
            c = layer.data[li].color
            layer.data[li].color = (c[0] * factor, c[1] * factor, c[2] * factor, c[3])


def bevel_selected(o, p, number):
    role = p["component"]
    size = p.get("parameters", {}).get("size_m", [1, 1, 1])
    edges = []
    bm = bmesh.new()
    bm.from_mesh(o.data)
    if role == "cladding":
        # 選擇少量完整板作外露長邊刨削／輕磨耗；此版16塊，不讓每塊都同款。
        code = int(hashlib.sha256(p["name"].encode()).hexdigest()[:8], 16)
        if code % 6 == 0:
            thin = 0 if size[0] < size[1] else 1
            for e in bm.edges:
                a, b = [v.co for v in e.verts]
                if (
                    abs(a.z - b.z) > 0.5 * size[2]
                    and a[thin]
                    * (1 if p["position"][thin] > (10 if thin == 0 else 5) else -1)
                    > 0
                ):
                    edges.append(e)
            width = 0.0045
    elif role == "table_top":
        for e in bm.edges:
            if all(v.co.z > size[2] * 0.45 for v in e.verts):
                edges.append(e)
        width = 0.009
    elif role == "sill":
        for e in bm.edges:
            if all(v.co.z > size[2] * 0.45 for v in e.verts):
                edges.append(e)
        width = 0.010
    if edges:
        bmesh.ops.bevel(
            bm, geom=edges, offset=width, segments=1, affect="EDGES", clamp_overlap=True
        )
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data)
    bm.free()


def remove_hidden(obs, spec):
    byname = {p["name"]: p for p in spec["parts"]}
    solids = []
    for o in obs:
        p = byname.get(o.name)
        if (
            not p
            or p.get("unit") != "shell"
            or p.get("recess")
            or p.get("soft_outer_corners")
            or p.get("readable_long_edges")
            or p.get("readable_top_edge")
            or p.get("parent")
            or p["component"] in ("glass_pane", "sill")
        ):
            continue
        # 判斷使用原實體盒，不使用空心桶／輪等自訂mesh的包絡冒充實體。
        size = p["parameters"]["size_m"]
        inv = o.matrix_world.inverted()
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector([min(v[k] for v in pts) for k in range(3)])
        hi = Vector([max(v[k] for v in pts) for k in range(3)])
        solids.append((o, inv, Vector(size) / 2, lo, hi))
    removed = 0
    spec["runtime_occlusion_audit"] = []
    for o in obs:
        if (
            o.get("unit") != "shell"
            or o.name not in byname
            or byname[o.name].get("parent")
        ):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = []
        for f in bm.faces:
            wn = (o.matrix_world.to_3x3() @ f.normal).normalized()
            pts = [o.matrix_world @ v.co + wn * 0.00005 for v in f.verts]
            lo = Vector([min(v[k] for v in pts) for k in range(3)])
            hi = Vector([max(v[k] for v in pts) for k in range(3)])
            for other, inv, half, a, b in solids:
                if other == o or any(
                    hi[k] < a[k] - 0.000001 or lo[k] > b[k] + 0.000001 for k in range(3)
                ):
                    continue
                if all(
                    all(abs((inv @ q)[k]) <= half[k] + 0.000001 for k in range(3))
                    for q in pts
                ):
                    spec["runtime_occlusion_audit"].append(
                        dict(
                            target=o.name,
                            occluder=other.name,
                            triangles=max(0, len(f.verts) - 2),
                            target_parent=byname[o.name].get("parent"),
                            occluder_unit=byname[other.name].get("unit"),
                        )
                    )
                    kill.append(f)
                    break
        removed += sum(max(0, len(f.verts) - 2) for f in kill)
        if kill:
            bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(o.data)
        bm.free()
    return removed


def finish_shell(spec, number, optimized):
    obs, parents = (furnish if number == 1 else finish_parts)(spec, optimized)
    print("CONSTRUCT_BASE", number, optimized, len(obs), flush=True)
    byname = {p["name"]: p for p in spec["parts"]}
    bpy.context.view_layer.update()
    for o in obs:
        p = byname.get(o.name)
        if p:
            if number == 1 and p.get("soft_outer_corners"):
                inv = o.matrix_world.inverted()
                for vertex in o.data.vertices:
                    co = o.matrix_world @ vertex.co
                    for x, y in ((0, 0), (16, 0), (0, 12), (16, 12)):
                        if abs(co.x - x) <= 0.0351 and abs(co.y - y) <= 0.0351:
                            co.x = x + (co.x - x) * (0.065 / 0.035)
                            co.y = y + (co.y - y) * (0.065 / 0.035)
                            vertex.co = inv @ co
                            break
            bevel_selected(o, p, number)
            color_sections(o, p)
            # 土坯洞口保留連續抹面，框材的端頭、窄側與牆面分層，不畫假磚縫。
        if o.get("component") in ("plaster_return", "plaster_patch"):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            bm.to_mesh(o.data)
            bm.free()
    print("BEVEL_DONE", number, optimized, flush=True)
    removed = remove_hidden(obs, spec) if optimized else 0
    empty = [o for o in obs if not o.data.polygons]
    for o in empty:
        obs.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    return obs, parents, removed


def finish_pair(spec, optimized=False):
    obs, parents = furnish(spec, optimized)
    byname = {p["name"]: p for p in spec["parts"]}
    for o in obs:
        p = byname.get(o.name)
        if p:
            bevel_selected(o, p, int(spec["id"].split("-")[-1]))
            color_sections(o, p)
    return obs, parents


def finish_building(s, n, optimized=True):
    if n in [1, 7]:
        obs, parents, _ = finish_shell(s, n, optimized)
    else:
        obs, parents = finish_pair(s, optimized)
    for o in obs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(o.data)
        bm.free()
    return obs, parents


def construct(s, n, optimized):
    spec = copy.deepcopy(s)
    if optimized:
        for p in spec["mesh_details"]:
            if "runtime_face_indices" in p:
                p["faces"] = [p["faces"][i] for i in p["runtime_face_indices"]]
            if "runtime_mesh" in p:
                p["vertices"] = p["runtime_mesh"]["vertices"]
                p["faces"] = p["runtime_mesh"]["faces"]
    obs, parents = finish_building(spec, n, optimized)
    if optimized and n in [2, 15]:
        bpy.context.view_layer.update()
        occlusion = copy.deepcopy(spec)
        # 自訂三角山牆／坡道也可作為檢查目標，但其包圍盒絕不當實體遮擋物。
        for p in spec["mesh_details"]:
            if p["unit"] == "shell":
                occlusion["parts"].append(dict(p, readable_long_edges=True))
        removed = remove_hidden(obs, occlusion)
        s["envelope_hidden_face_audit"] = occlusion["runtime_occlusion_audit"]
        empty = [o for o in obs if not o.data.polygons]
        for o in empty:
            obs.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
        print("ENVELOPE_HIDDEN", n, removed, flush=True)
    return obs, parents


def rebuild(number, destination):
    stem = f"bld_{number:02d}"
    spec = json.loads((ASSETS / f"{stem}_assembly.json").read_text(encoding="utf-8"))
    if spec["revision"] != "envelope-r005" or spec["id"] != f"CD-GBB-BLD-{number:02d}":
        raise ValueError(f"組裝資料版本或建築編號不符：{stem}")
    MATERIALS.clear()
    MATERIALS.update(spec["materials"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    author_parts, author_pivots = construct(spec, number, False)
    for part in author_parts:
        part.hide_set(True)
        part.hide_render = True
        part.name = "author_" + part.name
    for pivot in author_pivots.values():
        pivot.name = "author_" + pivot.name
    objects, pivots = construct(spec, number, True)
    bpy.context.view_layer.update()
    problems = pipeline.check(objects, budget=150000)
    if problems:
        raise ValueError(problems)
    if number == 2:
        for obj in objects:
            if obj["unit"].startswith("grain_"):
                obj["unit"] = "grain_batch"
    result = packed(objects, pivots)
    bpy.ops.wm.save_as_mainfile(filepath=str(destination / f"{stem}.blend"))
    pipeline.export(result, str(destination / f"{stem}.glb"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="新輸出目錄")
    parser.add_argument(
        "--building", nargs="+", choices=(1, 2, 7, 15), type=int, default=(1, 2, 7, 15)
    )
    args = parser.parse_args(
        sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    )
    destination = args.out.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    if any(
        (destination / f"bld_{n:02d}.{suffix}").exists()
        for n in args.building
        for suffix in ("blend", "glb")
    ):
        parser.error("輸出目錄已有同名模型，請選另一個目錄")
    for number in dict.fromkeys(args.building):
        rebuild(number, destination)


if __name__ == "__main__":
    main()
