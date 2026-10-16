# Tripo CLI 生成的新左輪（143 萬面）→ 減面、擺成跟舊原檔一樣的方向（槍管 +X、上 +Z、高度從 0 起），
# 存成 docs/素材/revolver_v2 3d model.glb，再交給 weapons_tripo.py 切零件。
# 背景跑：Blender --background --factory-startup --python blender/revolver_v2_prep.py -- <tripo 的 model.glb>
import bpy, math, os, sys
import numpy as np
from mathutils import Matrix

FACES = 12000   # 舊原檔 4862 面；6000 面時機匣碎成尖角，拿在手上的槍 1.2 萬面不貴
src = sys.argv[sys.argv.index('--') + 1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', '素材', 'revolver_v2 3d model.glb')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
o = next(o for o in bpy.data.objects if o.type == 'MESH')
o.data.transform(o.matrix_world)
o.matrix_world = Matrix()
d = o.modifiers.new('dec', 'DECIMATE')
d.ratio = FACES / len(o.data.polygons)
bpy.context.view_layer.objects.active = o
bpy.ops.object.modifier_apply(modifier=d.name)

# Tripo 給的是槍管沿 ±Y：轉到 +X。槍口那頭只有槍管、上下很薄；握把那頭往下長，看兩端的高度範圍分辨
P = np.array([tuple(v.co) for v in o.data.vertices])
lo, hi = P[:, 1].min(), P[:, 1].max()
end = 0.08 * (hi - lo)
h_lo = np.ptp(P[P[:, 1] < lo + end][:, 2])
h_hi = np.ptp(P[P[:, 1] > hi - end][:, 2])
o.data.transform(Matrix.Rotation(-math.pi / 2 if h_hi < h_lo else math.pi / 2, 4, 'Z'))
P = np.array([tuple(v.co) for v in o.data.vertices])
o.data.transform(Matrix.Translation((-(P[:, 0].min() + P[:, 0].max()) / 2, -(P[:, 1].min() + P[:, 1].max()) / 2, -P[:, 2].min())))
for img in bpy.data.images:   # 貼圖縮到 1024：weapons_tripo.py 反正重新上純色，原檔不用 2048
    if img.size[0] > 1024:
        img.scale(1024, 1024)
P = np.array([tuple(v.co) for v in o.data.vertices])
print('faces %d  min %s  max %s' % (len(o.data.polygons), P.min(0).round(3), P.max(0).round(3)))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_yup=True)
print('exported ->', out)
