# 牛仔人形：Tripo 綁好骨架（舊版人形、Mixamo 骨頭名）＋套好的預設動作，合成一個 glb 給 Godot。
# 來源：docs/素材/cowboy_anim/*.glb（每個檔是同一副骨架，各帶幾個動作）。
# 跑：Blender --background --python blender/cowboy_anim.py
import bpy, glob, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'models/cowboy_anim.glb')

bpy.ops.wm.read_factory_settings(use_empty=True)
keep = None
for f in sorted(glob.glob(os.path.join(ROOT, 'docs/素材/cowboy_anim/*.glb'))):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = set(bpy.data.objects) - before
    if keep is None:   # 第一個檔的骨架和外皮留下，其他檔只要動作
        keep = new
        continue
    for o in new:
        bpy.data.objects.remove(o)
for o in list(keep):
    if o.type == 'MESH' and not o.vertex_groups:   # Tripo 附的 Icosphere 之類雜物
        bpy.data.objects.remove(o)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
arm.animation_data_create()
arm.animation_data.action = None
for a in sorted(bpy.data.actions, key=lambda a: a.name):   # 每個動作放一條 NLA 軌，匯出時各成一段動畫
    a.use_fake_user = True
    tr = arm.animation_data.nla_tracks.new()
    tr.name = a.name
    tr.strips.new(a.name, int(a.frame_range[0]), a)
    print('動作', a.name, tuple(round(x) for x in a.frame_range))
bpy.ops.export_scene.gltf(filepath=OUT, export_animation_mode='NLA_TRACKS', export_yup=True)
print('->', OUT)
