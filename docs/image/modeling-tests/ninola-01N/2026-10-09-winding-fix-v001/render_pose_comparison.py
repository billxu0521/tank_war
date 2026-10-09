import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;records=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json').read_text())['assets']['M7'];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));positions={};result={}
for version in ['v003','v004']:
 src=r/f'blender/ninola/working/01N1/2026-10-09-{version}/ninola_01N1_jaw_volume_reconstruction.blend';before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];rig=bpy.data.objects['TrexRig'];R=rig.matrix_world.copy();pose0={b.name:b.matrix_basis.copy() for b in rig.pose.bones};faces=[list(f.vertices) for f in o.data.polygons]
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
  if version=='v003':positions[label]=coords
  error=max((Vector(a)-Vector(b)).length for a,b in zip(coords,positions[label]));assert error==0
  me.clear_geometry();me.from_pydata(coords,[],faces);me.update()
  for view,di,center,scale in [('side',(-1,0,0),(0,2.5,1.9),3.8),('threequarter',(-1,1,-.1),(0,2.4,1.9),3.8)]:
   di=Vector(di).normalized();cd.type='ORTHO';cd.ortho_scale=scale;cam.location=Vector(center)+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();out=p/'captures'/version;out.mkdir(parents=True,exist_ok=True);dest=out/f'{label}_{view}.png';assert not dest.exists();sc.render.filepath=str(dest);bpy.ops.render.render(write_still=True,scene=sc.name)
  frames[label]={'all_evaluated_coordinates_max_delta_vs_v003':error}
 for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update();assert before==hashlib.sha256(src.read_bytes()).hexdigest();result[version]={'source_sha256_unchanged':before,'pose_restored':True,'frames':frames}
(p/'pose_verification.json').write_text(json.dumps({'results':result,'pose_source':'recorded M7 Godot samples replayed on unchanged rig, not a new game-input test'},indent=2))
