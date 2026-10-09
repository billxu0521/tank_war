import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01N1/2026-10-09-v003/ninola_01N1_jaw_volume_reconstruction.blend';before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();faces=[list(f.vertices) for f in o.data.polygons];mi=[f.material_index for f in o.data.polygons];analysis=json.loads((p/'interface_analysis.json').read_text());first=6709;fixed=[f.copy() for f in faces]
for local in analysis['diagnostic_orientation_only']['new_local_faces_to_reverse']:fixed[first+local].reverse()
records=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json').read_text())['assets']['M7'];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));R=rig.matrix_world.copy();pose0={b.name:b.matrix_basis.copy() for b in rig.pose.bones};rest0=[list(v.co) for v in o.data.vertices]
sc=bpy.data.scenes.new('Temporary_Interface_Audit');sc.world=bpy.data.worlds.new('Temporary_Interface_Background');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1100;sc.render.resolution_y=850;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True;sh.color_type='SINGLE';sh.single_color=(.60,.64,.68)
me=bpy.data.meshes.new('Temporary_Interface_Display');ob=bpy.data.objects.new('Temporary_Interface_Display',me);sc.collection.objects.link(ob);cd=bpy.data.cameras.new('Temporary_Interface_Camera');cam=bpy.data.objects.new('Temporary_Interface_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam;di=Vector((-1,0,0));cd.type='ORTHO';cd.ortho_scale=3.8;cam.location=Vector((0,2.5,1.9))+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler()
report={}
for label,sample in [('original',None),('bite026',records['bite'][26]),('sweep003',records['jaw_sweep'][3])]:
 if sample:
  targets={b.name:R.inverted()@C@Matrix(sample['skeleton_world'])@Matrix(sample['bones'][b.name]) for b in rig.data.bones}
  for b in rig.data.bones:rig.pose.bones[b.name].matrix=targets[b.name];bpy.context.view_layer.update()
 else:
  for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
  bpy.context.view_layer.update()
 ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());coords=[o.matrix_world@v.co for v in ev.data.vertices]
 for variant,ff in [('current',faces),('winding_only_hypothesis',fixed)]:
  me.clear_geometry();me.from_pydata(coords,[],ff);me.update();sc.view_layers[0].update();dest=p/f'{label}_{variant}.png';assert not dest.exists();sc.render.filepath=str(dest);bpy.ops.render.render(write_still=True,scene=sc.name)
 report[label]={'same_evaluated_coordinates_in_both':True,'faces_reversed_in_display_only':len(analysis['diagnostic_orientation_only']['new_local_faces_to_reverse']),'variant_is_not_saved_model':True}
for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert rest0==[list(v.co) for v in o.data.vertices];assert before==hashlib.sha256(src.read_bytes()).hexdigest()
(p/'diagnostic_render_verification.json').write_text(json.dumps({'source_sha256':before,'source_unchanged':True,'source_pose_restored':True,'prototype_mesh_not_edited':True,'rig_not_edited':True,'hypothesis_only_changes_temporary_display_face_order':True,'poses':'previous recorded Godot M7 poses; not a fresh game test','samples':report},indent=2))
