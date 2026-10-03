"""blender/pipeline.py 的送審前自動檢查，自己的測試：故意做出四種錯，每種都要被抓到；正常的方塊不能被誤判。
   /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/test_pipeline_check.py
"""
import os, sys
import bpy, bmesh

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender'))
import pipeline


def cube(name, flip=False, mats=(), uv=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    if flip:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if not uv:
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
    for m in mats:
        me.materials.append(bpy.data.materials.new(m))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


bpy.ops.wm.read_factory_settings(use_empty=True)
ok = cube('Ok', mats=('a',))
assert pipeline.check([ok], budget=100) == [], pipeline.check([ok], budget=100)
assert any('超過預算' in p for p in pipeline.check([ok], budget=10))                        # 12 個三角形 > 10
assert any('沒有任何面' in p for p in pipeline.check([cube('Unused', mats=('a', 'spine'))]))  # 刺的材質沒用到
assert any('反面' in p for p in pipeline.check([cube('Flip', flip=True)]))
assert any('貼圖座標' in p for p in pipeline.check([cube('Card', mats=('tree_leafcard_x',), uv=False)]))
print('PIPELINE CHECK TEST OK')
