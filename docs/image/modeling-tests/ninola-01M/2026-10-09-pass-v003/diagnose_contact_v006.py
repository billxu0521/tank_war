import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
r=Path.cwd();out=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v003/dynamic-v006';g=json.loads((out/'godot_pose_samples.json').read_text());exports=json.loads((out/'export_records.json').read_text());C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));results={}
for item in exports:
 tag=item['asset'];bpy.ops.wm.open_mainfile(filepath=str(r/item['source']));o=bpy.data.objects[item['object']];rig=bpy.data.objects['TrexRig'];R=rig.matrix_world.copy();faces=[list(f.vertices) for f in o.data.polygons];source_names=['d_olive','d_moss','d_tan','d_tailu','d_taild','d_belly','d_spike','d_spike_lit','d_ridge','d_bone','d_claw','d_mouth','d_eye','d_pupil'];mats=[source_names.index(o.data.materials[f.material_index].name) for f in o.data.polygons];w=[{o.vertex_groups[x.group].name:x.weight for x in v.groups} for v in o.data.vertices];rows=[]
 for kind,idx in [('jaw_sweep',0),('bite',0),('bite',26)]:
  s=g['assets'][tag][kind][idx];W=Matrix(s['skeleton_world'])
  for b in rig.data.bones:rig.pose.bones[b.name].matrix=R.inverted()@C@W@Matrix(s['bones'][b.name]);bpy.context.view_layer.update()
  ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());c=[o.matrix_world@v.co for v in ev.data.vertices]
  jf=[i for i,f in enumerate(faces) if all(w[j].get('jaw',0)>.99 for j in f) and mats[i] in [2,5,11]];hf=[i for i,f in enumerate(faces) if all(w[j].get('head',0)>.5 for j in f) and mats[i] in [0,1,2,5,11]];pairs=BVHTree.FromPolygons(c,[faces[i] for i in jf]).overlap(BVHTree.FromPolygons(c,[faces[i] for i in hf]));bad={jf[i] for i,j in pairs}|{hf[j] for i,j in pairs}
  jt=[i for i,f in enumerate(faces) if mats[i]==9 and all(w[j].get('jaw',0)>.9 for j in f)];ht=[i for i,f in enumerate(faces) if mats[i]==9 and all(w[j].get('head',0)>.5 for j in f)];upper=BVHTree.FromPolygons(c,[faces[i] for i in ht]);lower=BVHTree.FromPolygons(c,[faces[i] for i in jt]);tp=lower.overlap(upper);signed=[]
  for i in {j for fi in jt for j in faces[fi]}:
   h,n,fi,d=upper.find_nearest(c[i]);signed.append((c[i]-h).dot(n))
  rows.append({'sequence':kind,'frame':idx,'soft_surface_overlap_pairs':len(pairs),'original_face_pairs':[[jf[i],hf[j]] for i,j in pairs],'world_face_centroids':{str(fi):list(sum((c[j] for j in faces[fi]),Vector())/len(faces[fi])) for fi in bad},'tooth_surface_intersection_pairs':len(tp),'lower_tooth_vertex_to_nearest_upper_tooth_oriented_distance_min':min(signed) if signed else None,'oriented_distance_limit':'nearest triangle normal projection, not global signed-volume distance; not occlusal clearance certification'})
  if kind=='jaw_sweep':
   sc=bpy.data.scenes.new('Temporary_Contact_Diagnostic');sc.world=bpy.data.worlds.new('Contact_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=900;sc.render.resolution_y=700;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='MATERIAL';sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True
   me=bpy.data.meshes.new('Contact_Evaluated');me.from_pydata(c,[],faces);me.update();a=bpy.data.materials.new('Diagnostic_gray');a.diffuse_color=(.6,.64,.68,1);b=bpy.data.materials.new('Diagnostic_pink');b.diffuse_color=(1,.13,.4,1);me.materials.append(a);me.materials.append(b)
   for f in me.polygons:f.material_index=1 if f.index in bad else 0
   ob=bpy.data.objects.new('Contact_Evaluated',me);sc.collection.objects.link(ob);cd=bpy.data.cameras.new('Contact_Camera');cam=bpy.data.objects.new('Contact_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam;di=Vector((-1,1,.3)).normalized();cd.type='ORTHO';cd.ortho_scale=4.5;cam.location=Vector((0,2.2,2.1))+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();dest=out/f'contact_diagnostic_{tag}.png';assert not dest.exists();sc.render.filepath=str(dest);bpy.ops.render.render(write_still=True,scene=sc.name)
 results[tag]=rows
(out/'contact_diagnostics.json').write_text(json.dumps(results,indent=2));print('CONTACT_DIAGNOSTICS',json.dumps({tag:[{k:v for k,v in row.items() if k not in ['original_face_pairs','world_face_centroids']} for row in rows] for tag,rows in results.items()}))
