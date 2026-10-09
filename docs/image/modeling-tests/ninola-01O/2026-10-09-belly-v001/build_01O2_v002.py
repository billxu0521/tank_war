import bpy,json,hashlib,math,ast,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent/'refined-v002';p.mkdir(exist_ok=True);src=r/'blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend';dest=r/'blender/ninola/working/01O2/2026-10-09-v002/ninola_01O2_ventral_belly_tuck.blend';assert not dest.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];names=[m.name for m in a.data.materials];groups={'neck','neck2','spine1','spine2','root'};skinm={'d_olive','d_moss','d_tan','d_belly'};key=lambda i:tuple(round(x,5) for x in world[i]);classes={}
for i in {i for f in faces for i in f}:classes.setdefault(key(i),[]).append(i)
selected={fi for fi,f in enumerate(faces) if names[mats[fi]] in skinm and all(.25<world[i].y<2.05 and world[i].z<2.20 and abs(world[i].x)<1.25 and sum(weights[i].get(g,0) for g in groups)>.5 for i in f)}
protected={key(i) for fi,f in enumerate(faces) if fi not in selected for i in f};candidate={key(i) for fi in selected for i in faces[fi]};free=candidate-protected
# Preserve every non-target face and all coordinate-coincident borders including spike attachments.
prot=[Vector(k) for k in protected if .1<k[1]<2.2 and k[2]<2.2];target_line=[(.50,1.063),(.85,1.155),(1.20,1.247),(1.41,1.465),(1.59,1.50)]
def target_z(y):
 for aa,bb in zip(target_line,target_line[1:]):
  if y<=bb[0]:t=max(0,min(1,(y-aa[0])/(bb[0]-aa[0])));return aa[1]*(1-t)+bb[1]*t
 return target_line[-1][1]
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
# Digest actual locked scene state, independent from new object.
def lock():
 tr=bpy.data.objects['Trex'];return {'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in rig.data.bones],'pose':[(b.name,[list(row) for row in b.matrix_basis]) for b in rig.pose.bones],'keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]}
locked=lock();ob=a.copy();ob.data=a.data.copy();ob.name='01O2_Ventral_Belly_Tuck';bpy.context.scene.collection.objects.link(ob);changes=[]
for k in sorted(free):
 q=Vector(k);distance=min((q-v).length for v in prot);edge=smooth((distance-.006)/.12);fade=smooth((q.y-.48)/.18)*smooth((1.67-q.y)/.20);alpha=edge*fade
 target=target_z(q.y);rise=max(0,target-q.z)*alpha
 delta=Vector((0,0,min(.25,rise)))
 if delta.length<.002:continue
 for i in classes[k]:ob.data.vertices[i].co=bind(world[i]+delta,weights[i])
 changes.append({'key':k,'vertex_ids':classes[k],'delta_world':list(delta),'distance_to_protected':distance,'alpha':alpha,'target_z':target})
ob.data.update();bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];changedids={i for ch in changes for i in ch['vertex_ids']};assert changes
assert lock()==locked
assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(world)) if i not in changedids)
assert all(all(ob.data.vertices[i].co==a.data.vertices[i].co for i in f) for fi,f in enumerate(faces) if fi not in selected)
assert [list(f.vertices) for f in ob.data.polygons]==faces and [f.material_index for f in ob.data.polygons]==mats
assert [{ob.vertex_groups[g.group].name:g.weight for g in v.groups} for v in ob.data.vertices]==weights
errors=[(actual[i]-(world[i]+Vector(ch['delta_world']))).length for ch in changes for i in ch['vertex_ids']];assert max(errors)<3e-5
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None)
# normals and near-degeneracy against baseline, with identical topology
newdeg=[];flip=[]
for fi,(old,new) in enumerate(zip(a.data.polygons,ob.data.polygons)):
 if new.area<1e-9 and old.area>=1e-9:newdeg.append(fi)
 if old.normal.dot(new.normal)<0:flip.append(fi)
assert not newdeg and not flip
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01O2 v001 ventral belly tuck trial, pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
record={'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dest.relative_to(r)),'sha256':sha(dest),'object':ob.name,'selected_faces':len(selected),'candidate_coordinates':len(candidate),'fixed_coincident_coordinates':len(candidate&protected),'free_coordinates':len(free),'changed_coordinates':len(changes),'changed_vertex_ids':len(changedids),'max_world_displacement':max(Vector(ch['delta_world']).length for ch in changes),'vertices':len(world),'triangles':sum(len(f)-2 for f in faces),'topology_material_weights_exact':True,'all_non_target_face_coordinates_exact':True,'Rig_Trex_keys_pose_exact':True,'inverse_bind_error':max(errors),'new_degenerate_faces':newdeg,'normal_reversal_faces':flip,'pipeline_issues':issues,'new_geometry':False,'target_line_y_z':target_line,'neck_main_torso_policy':'preserve N1, reject O1 neck changes','source_unchanged':True,'spike_attachment_coordinates_exact':True,'limitation':'user yellow-line ventral tuck only; neck and main torso upper/side mass unchanged; endpoint and limb borders fixed','production_ready':False}
(p/'build_record.json').write_text(json.dumps(record,indent=2));(p/'edit_mask.json').write_text(json.dumps({'selected_face_ids':sorted(selected),'fixed_keys':[list(k) for k in sorted(candidate&protected)],'changes':changes},indent=2));(p/'inspection_geometry.json').write_text(json.dumps({'vertices':[list(v) for v in actual],'faces':faces,'material_indices':mats,'material_colors':[list(m.diffuse_color) for m in ob.data.materials]}));print(json.dumps(record))
