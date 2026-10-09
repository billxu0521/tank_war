import bpy,json,hashlib
from pathlib import Path
p=Path(__file__).resolve().parent;r=Path.cwd();src=r/'blender/ninola/working/01Q1/2026-10-09-v002/ninola_01Q1_tail_taper.blend';dst=r/'blender/ninola/working/01R-spine/2026-10-09-v001/ninola_Q1_approved_spine_palette.blend';assert not dst.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01Q1_Tail_Taper'];o=a.copy();o.data=a.data.copy();o.name='01Q1_Approved_Spine_Palette';bpy.context.scene.collection.objects.link(o);names=[m.name for m in o.data.materials];changes=[]
for f in o.data.polygons:
 if names[f.material_index] not in ['d_spike','d_spike_lit','d_ridge']:continue
 c=sum((a.matrix_world@o.data.vertices[i].co for i in f.vertices),__import__('mathutils').Vector())/len(f.vertices)
 if c.y<=1.85:continue
 n=(a.matrix_world.to_3x3()@f.normal).normalized();new=names.index('d_spike_lit') if n.z>.25 and n.y>.05 else names.index('d_ridge') if n.z<.15 else names.index('d_spike')
 if f.material_index!=new:changes.append({'source_face':f.index,'old':names[f.material_index],'new':names[new]});f.material_index=new
assert [list(v.co) for v in o.data.vertices]==[list(v.co) for v in a.data.vertices]
assert [list(f.vertices) for f in o.data.polygons]==[list(f.vertices) for f in a.data.polygons]
for x in bpy.context.scene.objects:
 if x.type=='MESH':x.hide_render=x!=o;x.hide_set(x!=o);x.select_set(x==o)
bpy.context.view_layer.objects.active=o;dst.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dst));assert sha(src)==before
(p/'approved_spine_palette.json').write_text(json.dumps({'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dst.relative_to(r)),'sha256':sha(dst),'object':o.name,'geometry_exact':True,'rig_edited':False,'source_unchanged':True,'status':'user_approved_spine_face_palette_only; Q1_geometry_preserved','material_assignments':changes},indent=2));print('Approved spine palette checkpoint saved separately from rejected geometry')
