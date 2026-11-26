"""背景重建果場基礎件。以本專案 kits.glb 的材質與木箱為來源。"""
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "models/orchard_loading"
ART = ROOT / "docs/image/modeling-tests/orchard-loading/2026-11-23-v1"
LAYOUT = json.loads((ASSETS / "layout.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0

kit = (ROOT / "models/kits.glb").read_bytes()
header = json.loads(kit[20:20 + struct.unpack_from("<I", kit, 12)[0]])
palette = {m["name"]: m["pbrMetallicRoughness"]["baseColorFactor"] for m in header["materials"]}
timber = bpy.data.materials.new("Orchard_kit_wood")
timber.use_nodes = True
bsdf = timber.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.9
vc = timber.node_tree.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "KitColor"
timber.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])


def blender_point(x, y, z):
    return (x, -z, y)


class Timbers:
    def __init__(self):
        self.vertices, self.faces, self.colors, self.parts = [], [], [], []

    def prism(self, name, x0, x1, z0, z1, low, high, key):
        """直板、斜板與填芯共用相同的面朝向。上下表面可各自設定坡度。"""
        i = len(self.vertices)
        for edge in (low, high):
            h0, h1 = edge if isinstance(edge, tuple) else (edge, edge)
            self.vertices.extend(blender_point(x, y, z) for x, y, z in
                                 [(x0,h0,z0),(x0,h0,z1),(x1,h1,z1),(x1,h1,z0)])
        self.parts.append((name, list(range(i,i+8))))
        for face in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:
            self.faces.append(tuple(i+j for j in face))
            self.colors.append(palette[key])

    def object(self, name):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(timber)
        color = mesh.color_attributes.new(name="KitColor", type="FLOAT_COLOR", domain="CORNER")
        for poly, shade in zip(mesh.polygons, self.colors):
            for idx in poly.loop_indices:
                color.data[idx].color = shade
        for label, indices in self.parts:
            obj.vertex_groups.new(name=label).add(indices, 1, "REPLACE")
        return obj


def wood(i):
    return "h_wood" + str((0,1,0,2,1,0,2)[i % 7])


def build_deck():
    b = Timbers()
    b.prism("closed_core", -4.46,4.46,-2.94,2.94,0,2.32,"h_dark")
    # 厚木封板圍住臺下。接縫落在柱位，柱頭承邊梁，臺面板跨內部橫梁。
    for side in (-1,1):
        z = side*2.965
        for bay in range(4):
            x0 = -4.48 + bay*2.24
            for course in range(8):
                y = .18 + course*.252
                b.prism(f"skirt_{side}_{bay}_{course}",x0+.007,x0+2.233,z-.024,z+.024,y,y+.244,wood(bay+course))
        for post in range(5):
            x = -4.375 + post*2.1875
            b.prism(f"bent_{side}_{post}",x-.09,x+.09,z-.034,z+.034,.07,2.24,"h_post")
        b.prism(f"edge_beam_{side}",-4.50,4.50,z-.034,z+.034,2.19,2.315,"h_trim")
        b.prism(f"sill_{side}",-4.49,4.49,z-.03,z+.03,.02,.17,"h_stone0")
    for end in (-1,1):
        x = end*4.471
        for course in range(9):
            y = .04+course*.25
            b.prism(f"end_board_{end}_{course}",x-.028,x+.028,-2.98,2.98,y,y+.241,wood(course))
    # 同一橫梁上的板端錯縫；端面比臺面低一板厚。
    for j in range(38):
        x = -4.5+j*9/38
        seam = (-.9,.9,0)[j%3]
        for k,(a,c) in enumerate([(-3,seam-.005),(seam+.005,3)]):
            b.prism(f"deck_board_{j}_{k}",x+.004,x+9/38-.004,a,c,2.315,2.4,wood(3*j+k))
    for side in (-1,1):
        def slope(x):
            return max(0, (13.5-abs(x))*2.4/9)
        start = -13.5 if side<0 else 4.5
        a,c = start+.001,start+9-.001
        b.prism(f"ramp_core_{side}",a,c,-1.68,1.68,-.013,(max(-.010,slope(a)-.08),max(-.010,slope(c)-.08)),"h_dark")
        for j in range(39):
            a=start+j*9/39+.003
            c=start+(j+1)*9/39-.003
            h=(slope(a),slope(c))
            b.prism(f"ramp_board_{side}_{j}",a,c,-1.75,1.75,(max(-.012,h[0]-.078),max(-.012,h[1]-.078)),h,wood(j+4))
        for k,z in enumerate((-1.66,0,1.66)):
            a,c=start+.008,start+9-.008
            b.prism(f"ramp_stringer_{side}_{k}",a,c,z-.058,z+.058,
                    (max(-.02,slope(a)-.29),max(-.02,slope(c)-.29)),
                    (max(-.012,slope(a)-.08),max(-.012,slope(c)-.08)),"h_trim")
        for j in range(6):
            x=side*(5.1+j*1.39)
            for z in (-1.64,1.64):
                top=slope(x)-.25
                if top>.12:
                    b.prism(f"ramp_frame_{side}_{j}_{z}",x-.073,x+.073,z-.074,z+.074,.009,top,"h_post")
    return b.object("LoadingDeck")


def build_open_crate():
    b = Timbers()
    for j in range(5):
        x=-.393+j*.1574
        b.prism(f"floor_{j}",x+.002,x+.155,-.343,.343,.009,.043,wood(j))
    for side in (-1,1):
        x,z=side*.38,side*.333
        for j in range(4):
            y=.038+j*.109
            b.prism(f"side_{side}_{j}",-.394,.394,z-.010,z+.010,y,y+.098,wood(j+1))
            if j==3:
                for k,(a,c) in enumerate([(-.322,-.104),(.104,.322)]):
                    b.prism(f"handle_end_{side}_{k}",x-.013,x+.013,a,c,y,y+.098,"h_trim")
                b.prism(f"handle_grip_{side}",x-.013,x+.013,-.104,.104,y+.048,y+.098,"h_trim")
            else:
                b.prism(f"end_{side}_{j}",x-.013,x+.013,-.322,.322,y,y+.098,wood(j))
        for back in (-1,1):
            a,c=sorted([side*.368,side*.332])
            d,e=sorted([back*.322,back*.282])
            b.prism(f"stacking_post_{side}_{back}",a,c,d,e,0,.475,"h_post")
    return b.object("OpenFruitCrate")


def closed_from_kit():
    # 保留原木箱的板面、斜撐和頂蓋，只將封箱調到與週轉筐相同的堆疊外廓。
    previous=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"models/kits.glb"),loglevel=3)
    imported=set(bpy.data.objects)-previous
    src=next(o for o in imported if o.name=="Crate" and o.type=="MESH")
    raw=[src.matrix_world @ v.co for v in src.data.vertices]
    lo=[min(v[i] for v in raw) for i in range(3)]
    hi=[max(v[i] for v in raw) for i in range(3)]
    b=Timbers()
    b.vertices=[tuple((v[i]-lo[i])/(hi[i]-lo[i])*span-offset for i,(span,offset) in
                      enumerate(((.788,.394),(.686,.343),(.475,0)))) for v in raw]
    for face in src.data.polygons:
        b.faces.append(tuple(face.vertices))
        key=src.data.materials[face.material_index].name.split(".")[0]
        b.colors.append(palette[key])
    for o in imported:
        bpy.data.objects.remove(o,do_unlink=True)
    return b.object("ClosedTransitCrate")


def export(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/filename),use_selection=True,
                              export_format="GLB",export_yup=True,export_vertex_color="MATERIAL",
                              export_skins=False,export_animations=False)


def render():
    # 從交付的 GLB 重新匯入再排圖，從同一布局資料實例化筐列。
    for obj in list(bpy.context.scene.objects):
        bpy.data.objects.remove(obj,do_unlink=True)
    def read(filename):
        bpy.ops.import_scene.gltf(filepath=str(ASSETS/filename),loglevel=3)
        return next(o for o in bpy.context.selected_objects if o.type=='MESH')
    read("deck.glb")
    opened=read("open_crate.glb")
    closed=read("closed_crate.glb")
    a=math.radians(-9)
    for s in LAYOUT["stacks"]:
        x,z=s["xz"]
        wx=-14.3+x*math.cos(a)-z*math.sin(a)
        wz=-4.5+x*math.sin(a)+z*math.cos(a)
        for k,typ in enumerate(s["tiers"]):
            o=(opened if typ=="open" else closed).copy()
            bpy.context.collection.objects.link(o)
            o.location=blender_point(wx,k*.475,wz)
            o.rotation_euler.z=-a
    for o in (opened,closed):
        bpy.data.objects.remove(o,do_unlink=True)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025))
    mat=bpy.data.materials.new("PreviewEarth")
    mat.diffuse_color=(.30,.24,.15,1)
    bpy.context.object.data.materials.append(mat)
    sc=bpy.context.scene
    sc.world=bpy.data.worlds.new("Daylight")
    sc.world.color=(.52,.52,.52)
    bpy.ops.object.light_add(type="SUN",rotation=(.37,-.55,-.45))
    bpy.context.object.data.energy=3.4
    bpy.context.object.data.angle=math.radians(15)
    sc.render.engine="CYCLES"
    sc.cycles.device="CPU"
    sc.cycles.samples=10
    sc.render.threads_mode="FIXED"
    sc.render.threads=4
    sc.view_settings.view_transform="AgX"
    sc.render.resolution_x=1200
    sc.render.resolution_y=660
    sc.render.resolution_percentage=100
    bpy.ops.object.camera_add()
    sc.camera=bpy.context.object
    def take(name,p,target,ortho):
        camera=sc.camera
        camera.location=blender_point(*p)
        camera.rotation_euler=(Vector(blender_point(*target))-camera.location).to_track_quat("-Z","Y").to_euler()
        camera.data.type="ORTHO"
        camera.data.ortho_scale=ortho
        sc.render.filepath=str(ART/(name+".png"))
        bpy.ops.render.render(write_still=True)
    take("platform",(-23,13,-29),(-1.7,.95,-1.3),34)
    take("crates",(-19,3.8,-9),(-14,.88,-4.4),6.3)


deck=build_deck()
opened=build_open_crate()
closed=closed_from_kit()
for obj,filename in [(deck,"deck.glb"),(opened,"open_crate.glb"),(closed,"closed_crate.glb")]:
    export(obj,filename)
opened.location=(-7,4,0)
closed.location=(-6,4,0)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).with_name("loading_kit.blend")))
render()
