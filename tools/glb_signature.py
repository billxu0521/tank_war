# 印出 glb 裡每個物件的幾何簽名（點數、面數、位置、座標總和、材質），比對兩次匯出的模型是不是一樣。
# glb 檔的位元組每次匯出都可能不同（house、kit、town、props、trex），比幾何才準：
#   Blender --background --factory-startup --python tools/glb_signature.py -- a.glb > a.txt；再 diff 兩份
import bpy, sys
path = sys.argv[sys.argv.index('--') + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for o in sorted(bpy.data.objects, key=lambda o: o.name):
    if o.type != 'MESH':
        continue
    me = o.data
    s = [0.0, 0.0, 0.0]
    for v in me.vertices:
        for i in range(3):
            s[i] += v.co[i]
    print('SIG', o.name, len(me.vertices), len(me.polygons), tuple(round(x, 3) for x in o.location),
          tuple(round(x, 2) for x in s), sorted(m.name for m in me.materials if m))
