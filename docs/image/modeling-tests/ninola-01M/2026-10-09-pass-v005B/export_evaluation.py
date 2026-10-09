import bpy,json,sys,hashlib,importlib.util
from pathlib import Path
r=Path.cwd();out=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v005B/dynamic';spec=importlib.util.spec_from_file_location('ninola_pipeline',r/'blender/pipeline.py');pipeline=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipeline)
items=[('M5B','blender/ninola/working/01M5B/2026-10-09-v002/ninola_01M5B_face_mass_gaze.blend','01M5B_Face_Mass_Gaze')];records=[]
for tag,path,name in items:
 src=r/path;before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));ob=bpy.data.objects[name];rig=bpy.data.objects['TrexRig'];problems=pipeline.check([ob],budget=None);print('PIPELINE',tag,problems);assert not problems,problems
 for o in bpy.context.scene.objects:o.select_set(False)
 saved_world=ob.matrix_world.copy();ob.parent=rig;ob.matrix_world=saved_world
 ob.hide_set(False);ob.hide_viewport=False;ob.select_set(True);rig.hide_set(False);rig.hide_viewport=False;rig.select_set(True);bpy.context.view_layer.objects.active=ob
 dest=out/'test-project/models'/f'{tag}_eight_weights.glb';assert not dest.exists();bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_all_influences=True,export_yup=True)
 bones={b.name:{'parent':b.parent.name if b.parent else None,'rest':[list(row) for row in rig.matrix_world@b.matrix_local]} for b in rig.data.bones}
 records.append({'asset':tag,'source':path,'source_sha256':before,'object':name,'triangles':sum(len(f.vertices)-2 for f in ob.data.polygons),'bones':bones,'pipeline_check':'CHECK OK','budget':None,'export_path':str(dest.relative_to(r)),'export_sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'note':'evaluation only; armature modifier may be baked by exporter to rest-state mesh; verify import coordinates and stored pose before simulation'});assert before==hashlib.sha256(src.read_bytes()).hexdigest()
(out/'export_records.json').write_text(json.dumps(records,indent=2));print('CHECK OK evaluation exports only')
