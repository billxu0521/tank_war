import bpy,json,hashlib,collections,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
r=Path.cwd();out=r/'docs/image/modeling-tests/ninola-01N/2026-10-09-pass-v001/refined-v003/dynamic';out.mkdir(parents=True,exist_ok=True);g=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json').read_text());g['assets']['M8']=g['assets']['M7'];g['assets']['N1']=g['assets']['M7'];exports=[{'asset':'M8','source':'blender/ninola/working/01M8/2026-10-09-v001/ninola_01M8_cranial_identity.blend','object':'01M8_Cranial_Identity'},{'asset':'N1','source':'blender/ninola/working/01N1/2026-10-09-v003/ninola_01N1_jaw_volume_reconstruction.blend','object':'01N1_Jaw_Volume_Reconstruction'}];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
results={}
for item in exports:
 tag=item['asset'];src=r/item['source'];before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[item['object']];rig=bpy.data.objects['TrexRig'];bones=list(rig.data.bones);R=rig.matrix_world.copy();pose0={b.name:b.matrix_basis.copy() for b in rig.pose.bones};orig_rest={b.name:[list(row) for row in b.matrix_local] for b in bones};weights=[{o.vertex_groups[x.group].name:x.weight for x in v.groups} for v in o.data.vertices];rest_coords=[list(v.co) for v in o.data.vertices];faces=[list(f.vertices) for f in o.data.polygons];source_names=['d_olive','d_moss','d_tan','d_tailu','d_taild','d_belly','d_spike','d_spike_lit','d_ridge','d_bone','d_claw','d_mouth','d_eye','d_pupil'];mats=[(source_names.index(o.data.materials[f.material_index].name) if o.data.materials[f.material_index].name in source_names else 12) for f in o.data.polygons]
 rest_error=max(max(abs((C@Matrix(g['assets'][tag]['rest'][b.name]['matrix']))[i][j]-(R@b.matrix_local)[i][j]) for i in range(4) for j in range(4)) for b in bones);assert rest_error<5e-6,rest_error
 # New temporary evaluated display scene only; source scene and files are never saved.
 sc=bpy.data.scenes.new('Temporary_Dynamic_Evaluation');sc.world=bpy.data.worlds.new('Temporary_Sim_Background');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=900;sc.render.resolution_y=700;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='SINGLE';sh.single_color=(.60,.64,.68);sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True
 me=bpy.data.meshes.new('Temporary_Evaluated_Dynamic_Mesh');display=bpy.data.objects.new('Temporary_Evaluated_Dynamic_Mesh',me);sc.collection.objects.link(display);cd=bpy.data.cameras.new('Temporary_Sim_Camera');cam=bpy.data.objects.new('Temporary_Sim_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam
 views={'side':((-1,0,0),(0,2.15,2.1),4.9),'threequarter':((-1,1,.30),(0,2.2,2.1),4.5),'front':((0,1,0),(0,2.15,2.1),4.3),'body':((-1,0,0),(0,-.85,1.8),11.2),'bottom_threequarter':((-1,1,-.35),(0,2.2,2.1),4.5)}
 saved={};metrics=[];max_pose_err=0
 def pose(sample):
  global max_pose_err
  skeleton=Matrix(sample['skeleton_world']);targets={b.name:R.inverted()@C@skeleton@Matrix(sample['bones'][b.name]) for b in bones}
  for b in bones:
   rig.pose.bones[b.name].matrix=targets[b.name];bpy.context.view_layer.update()
  error=max(max(abs(rig.pose.bones[n].matrix[i][j]-m[i][j]) for i in range(4) for j in range(4)) for n,m in targets.items());max_pose_err=max(max_pose_err,error);assert error<2e-5,error
  ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());coords=[o.matrix_world@v.co for v in ev.data.vertices];me.clear_geometry();me.from_pydata(coords,[],faces);me.update();return coords
 def shot(sample,kind,idx,view):
  coords=pose(sample);di,center,scale=views[view];di=Vector(di).normalized();cd.type='ORTHO';cd.ortho_scale=scale;cam.location=Vector(center)+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();folder=out/'captures'/tag/kind;folder.mkdir(parents=True,exist_ok=True);dest=folder/f'{idx:03d}_{view}.png';assert not dest.exists();sc.render.filepath=str(dest);bpy.ops.render.render(write_still=True,scene=sc.name)
  saved[str(dest.relative_to(out))]={'sequence':kind,'frame':idx,'sample_label':sample['label'],'time':sample['time'],'view':view,'matrix':[list(row) for row in cam.matrix_world],'scale':scale,'resolution':[900,700],'display_mask':'full model; evaluated skin from actual 45-bone rig','source':'recorded M7 Godot procedural poses replayed on M8/N1 same verified rig; not new Godot input validation'}
  return coords
 jawfaces=[i for i,f in enumerate(faces) if all(weights[j].get('jaw',0)>.99 for j in f) and mats[i] in [2,5,11]];upperfaces=[i for i,f in enumerate(faces) if all(weights[j].get('head',0)>.5 for j in f) and mats[i] in [0,1,2,5,11]]
 for idx,sample in enumerate(g['assets'][tag]['jaw_sweep']):
  coords=shot(sample,'sweep',idx,'side')
  for view in ['threequarter','front','bottom_threequarter']:shot(sample,'sweep',idx,view)
  overlaps=BVHTree.FromPolygons(coords,[faces[i] for i in jawfaces]).overlap(BVHTree.FromPolygons(coords,[faces[i] for i in upperfaces]));metrics.append({'sequence':'sweep','frame':idx,'jaw_parent_world_quat':sample['jaw_rotation_parent_world'],'jaw_head_soft_surface_triangle_overlaps':len(overlaps),'note':'surface intersection flag, not tooth clearance nor closed-volume penetration certification'})
 for kind,frames in [('bite',[0,12,20,24,26,28,40,56,70]),('roar',[0,8,14,20,28,38,46])]:
  for idx in frames:
   coords=shot(g['assets'][tag][kind][idx],kind,idx,'side')
   if idx in ([0,20,24,26,28,40,70] if kind=='bite' else [0,20,28,46]):
    shot(g['assets'][tag][kind][idx],kind,idx,'threequarter')
   if idx in ([0,24,26,40,70] if kind=='bite' else [0,28,46]):shot(g['assets'][tag][kind][idx],kind,idx,'body')
   overlap=BVHTree.FromPolygons(coords,[faces[i] for i in jawfaces]).overlap(BVHTree.FromPolygons(coords,[faces[i] for i in upperfaces]));metrics.append({'sequence':kind,'frame':idx,'jaw_head_soft_surface_triangle_overlaps':len(overlap)})
 for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update();assert orig_rest=={b.name:[list(row) for row in b.matrix_local] for b in bones};assert rest_coords==[list(v.co) for v in o.data.vertices];assert before==hashlib.sha256(src.read_bytes()).hexdigest()
 results[tag]={'rest_mapping_max_error':rest_error,'pose_replay_max_error':max_pose_err,'bones':len(bones),'rest_and_mesh_restored_exact':True,'source_sha256_unchanged':before,'captures':saved,'metrics':metrics,'jaw_skin_face_count':len(jawfaces),'head_skin_face_count':len(upperfaces)}
 (out/f'capture_record_{tag}.json').write_text(json.dumps(results[tag],indent=2));print('CAPTURE_OK',tag,rest_error,max_pose_err)
(out/'simulation_verification.json').write_text(json.dumps({k:{x:v for x,v in d.items() if x!='captures'} for k,d in results.items()},indent=2))
