import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;records=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json').read_text())['assets']['M7'];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));positions={};result={}
changedids={i for ch in json.loads((p/'refined-v003/edit_mask.json').read_text())['changes'] for i in ch['vertex_ids']}
for version in ['baseline','O2v003']:
 src=r/('blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend' if version=='baseline' else 'blender/ninola/working/01O2/2026-10-09-v003/ninola_01O2_ventral_belly_tuck.blend');before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction' if version=='baseline' else '01O2_Ventral_Belly_Tuck'];rig=bpy.data.objects['TrexRig'];R=rig.matrix_world.copy();pose0={b.name:b.matrix_basis.copy() for b in rig.pose.bones};faces=[list(f.vertices) for f in o.data.polygons]
 sc=bpy.data.scenes.new('Temporary_Winding_Comparison');sc.world=bpy.data.worlds.new('Temporary_Winding_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1100;sc.render.resolution_y=850;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True;sh.color_type='SINGLE';sh.single_color=(.6,.64,.68);me=bpy.data.meshes.new('Temporary_Winding_Display');ob=bpy.data.objects.new('Temporary_Winding_Display',me);sc.collection.objects.link(ob);cd=bpy.data.cameras.new('Temporary_Winding_Camera');cam=bpy.data.objects.new('Temporary_Winding_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam
 frames={}
 for label,sample in [('original',None),('bite026',records['bite'][26]),('sweep003',records['jaw_sweep'][3])]:
  if sample:
   targets={b.name:R.inverted()@C@Matrix(sample['skeleton_world'])@Matrix(sample['bones'][b.name]) for b in rig.data.bones}
   for b in rig.data.bones:rig.pose.bones[b.name].matrix=targets[b.name];bpy.context.view_layer.update()
  else:
   for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
   bpy.context.view_layer.update()
  coords=[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
  if version=='baseline':positions[label]=coords
  error=max((Vector(a)-Vector(b)).length for a,b in zip(coords,positions[label]));protected_error=max((Vector(a)-Vector(b)).length for i,(a,b) in enumerate(zip(coords,positions[label])) if i not in changedids);assert protected_error==0
  me.clear_geometry();me.from_pydata(coords,[],faces);me.update()
  for view,di,center,scale in [('side',(-1,0,0),(0,.8,1.9),5.6),('threequarter',(-1,1,-.1),(0,.8,1.9),5.6)]:
   di=Vector(di).normalized();cd.type='ORTHO';cd.ortho_scale=scale;cam.location=Vector(center)+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();out=p/'dynamic-captures'/version;out.mkdir(parents=True,exist_ok=True);dest=out/f'{label}_{view}.png';assert not dest.exists();sc.render.filepath=str(dest);bpy.ops.render.render(write_still=True,scene=sc.name)
  frames[label]={'max_delta_vs_baseline':error,'protected_coordinates_max_delta':protected_error}
 for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update();assert before==hashlib.sha256(src.read_bytes()).hexdigest();result[version]={'source_sha256_unchanged':before,'pose_restored':True,'frames':frames}
(p/'pose_verification.json').write_text(json.dumps({'results':result,'pose_source':'recorded M7 Godot samples replayed on same locked rig; tests bite026 and jaw_sweep003 only, not new game input or full neck animation'},indent=2))
