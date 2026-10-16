# Tripo 生成的左輪（低面數 P1）→ Tripo 智慧拆零件（smartsegment）拆成 5 塊 → 這裡補破口、取名字、擺正，
# 存成 docs/素材/revolver_parts.glb，再交給 weapons_tripo.py 組裝。
# 擺正跟舊原檔一樣：槍管 +X、上 +Z、寬度沿 Y、高度從 0 起。
# 背景跑：Blender --background --factory-startup --python blender/revolver_parts_prep.py -- <seg_model.glb>
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Matrix

# ponytail: 拆出來的編號是看分色圖對的（這一顆專用），換一顆要重看
NAMES = {'tripo_part_0': 'Frame', 'tripo_part_1': 'Cylinder', 'tripo_part_2': 'Grip', 'tripo_part_3': 'Hammer', 'tripo_part_4': 'Trigger'}
src = sys.argv[sys.argv.index('--') + 1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', '素材', 'revolver_parts.glb')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
parts = [o for o in bpy.data.objects if o.type == 'MESH']
for o in parts:
    o.data.transform(o.matrix_world)
    o.parent = None
    o.matrix_world = Matrix()
    o.name = o.data.name = NAMES[o.name]
    # 拆開的地方是破口（零件互相貼著的面沒做）：補平。轉輪轉起來、擊錘扳開才不會看到裡面
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    if o.name == 'Cylinder':   # 轉輪那塊有兩個細長的錯誤三角形從轉輪拉到槍口（轉輪本身才 0.16 長）
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if max(e.calc_length() for e in f.edges) > 0.25], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    print('%s faces %d open edges left %d' % (o.name, len(bm.faces), sum(e.is_boundary for e in bm.edges)))
    bm.to_mesh(o.data)
    bm.free()
for o in [o for o in bpy.data.objects if o.type != 'MESH']:
    bpy.data.objects.remove(o)

# Tripo 的槍管朝 -Y：繞 Z 轉 90 度到 +X，再置中、底部放到 0
m = Matrix.Rotation(math.pi / 2, 4, 'Z')
for o in parts:
    o.data.transform(m)
P = np.array([tuple(v.co) for o in parts for v in o.data.vertices])
t = Matrix.Translation((-(P[:, 0].min() + P[:, 0].max()) / 2, -(P[:, 1].min() + P[:, 1].max()) / 2, -P[:, 2].min()))
for o in parts:
    o.data.transform(t)
# 轉輪本體在 x -0.22～-0.058；槍尾那邊還黏著一小塊（轉輪一轉會跟著繞圈），範圍外的面丟掉
cyl = bpy.data.objects['Cylinder']
bm = bmesh.new()
bm.from_mesh(cyl.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if not -0.23 < f.calc_center_median().x < -0.05], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(cyl.data)
bm.free()
for o in parts:
    Q = np.array([tuple(v.co) for v in o.data.vertices])
    print('%s min %s max %s' % (o.name, Q.min(0).round(3), Q.max(0).round(3)))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True)
print('exported ->', out)
