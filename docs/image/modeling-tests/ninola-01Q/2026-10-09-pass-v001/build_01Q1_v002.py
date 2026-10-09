import bpy,json,hashlib,math,ast,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;p.mkdir(exist_ok=True);src=r/'blender/ninola/working/01P1/2026-10-09-v002/ninola_01P1_palm_digit_continuity.blend';dest=r/'blender/ninola/working/01Q1/2026-10-09-v002/ninola_01Q1_tail_taper.blend';assert not dest.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01P1_Palm_Digit_Continuity'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];names=[m.name for m in a.data.materials];groups={f'tail{i}' for i in range(1,9)};skinm={'d_olive','d_moss','d_tan','d_belly','d_taild','d_tailu'};key=lambda i:tuple(round(x,5) for x in world[i]);classes={}
for i in {i for f in faces for i in f}:classes.setdefault(key(i),[]).append(i)
selected={fi for fi,f in enumerate(faces) if names[mats[fi]] in skinm and all(-4.85<world[i].y<-1.4 and sum(weights[i].get(g,0) for g in groups)>.65 for i in f)}
protected={key(i) for fi,f in enumerate(faces) if fi not in selected for i in f};candidate={key(i) for fi in selected for i in faces[fi]};free=candidate-protected
# Preserve every non-target face and all coordinate-coincident borders including spike attachments.
prot=[Vector(k) for k in protected if -5.0<k[1]<-1.0];stations=json.loads((r/'docs/image/modeling-tests/ninola-01Q/2026-10-09-schematic-v001/schematic_geometry.json').read_text())['stations']
# Correct baseline measurement: dedicated tail upper/lower skin colours are
# skin, whereas d_ridge belongs to protected spikes.
for st in stations:
 pts=[];y=st['y']
 for fi,f in enumerate(faces):
  if names[mats[fi]] not in skinm:continue
  for ii,jj in zip(f,f[1:]+f[:1]):
   A=world[ii];B=world[jj]
   if (A.y-y)*(B.y-y)<0:
    t=(y-A.y)/(B.y-A.y);pts.append(A.lerp(B,t))
 st['source_skin_bottom']=min(a.z for a in pts);st['source_skin_top']=max(a.z for a in pts);st['source_skin_halfwidth']=max(abs(a.x) for a in pts)
root_bottom=stations[1]['source_skin_bottom'];distal_bottom=stations[-2]['source_skin_bottom']
for i,st in enumerate(stations):
 if i in [0,1,12,13]:st['target_bottom']=st['source_skin_bottom']
 else:
  u=(-st['y']-1.5)/(4.8-1.5);target=root_bottom*(1-u)+distal_bottom*u;st['target_bottom']=st['source_skin_bottom']+max(-.08,min(.16,target-st['source_skin_bottom']))

def station_at(y):
 for aa,bb in zip(stations,stations[1:]):
  if aa['y']>=y>=bb['y']:
   t=(y-aa['y'])/(bb['y']-aa['y']);return {k:aa[k]*(1-t)+bb[k]*t for k in ['source_skin_halfwidth','source_skin_bottom','source_skin_top','target_halfwidth','target_bottom']}
 return stations[-1]
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
locked=lock();ob=a.copy();ob.data=a.data.copy();ob.name='01Q1_Tail_Taper';bpy.context.scene.collection.objects.link(ob);changes=[]
for k in sorted(free):
 q=Vector(k);
 if any(sum(weights[i].get(g,0) for g in groups)<.65 for i in classes[k]):continue
 distance=min((q-v).length for v in prot);edge=smooth((distance-.005)/.10);fade=smooth((-q.y-1.5)/.4)*smooth((4.75+q.y)/.4);st=station_at(q.y);height=st['source_skin_top']-st['source_skin_bottom'];ventral=smooth((st['source_skin_top']-q.z)/max(.01,.72*height));alpha=edge*fade*.80
 width_delta=q.x*(st['target_halfwidth']/st['source_skin_halfwidth']-1)*alpha*ventral
 z_delta=(st['target_bottom']-st['source_skin_bottom'])*alpha*ventral**2
 delta=Vector((width_delta,0,z_delta))
 if delta.length<.002:continue
 for i in classes[k]:ob.data.vertices[i].co=bind(world[i]+delta,weights[i])
 changes.append({'key':k,'vertex_ids':classes[k],'delta_world':list(delta),'distance_to_protected':distance,'alpha':alpha,'station':st})
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
bpy.context.view_layer.objects.active=ob;ob['status']='01Q1 v002 corrected tail skin classification trial pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
record={'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dest.relative_to(r)),'sha256':sha(dest),'object':ob.name,'selected_faces':len(selected),'candidate_coordinates':len(candidate),'fixed_coincident_coordinates':len(candidate&protected),'free_coordinates':len(free),'changed_coordinates':len(changes),'changed_vertex_ids':len(changedids),'max_world_displacement':max(Vector(ch['delta_world']).length for ch in changes),'vertices':len(world),'triangles':sum(len(f)-2 for f in faces),'topology_material_weights_exact':True,'all_non_target_face_coordinates_exact':True,'Rig_Trex_keys_pose_exact':True,'inverse_bind_error':max(errors),'new_degenerate_faces':newdeg,'normal_reversal_faces':flip,'pipeline_issues':issues,'new_geometry':False,'design_stations':stations,'scope':'tail mid skin only, root and tip protected','source_unchanged':True,'spike_attachment_coordinates_exact':True,'limitation':'limited taper trial; spines and fixed coincident skin untouched; no whole-tail remodel or production integration','production_ready':False}
(p/'build_record_v002.json').write_text(json.dumps(record,indent=2));(p/'edit_mask_v002.json').write_text(json.dumps({'selected_face_ids':sorted(selected),'fixed_keys':[list(k) for k in sorted(candidate&protected)],'changes':changes},indent=2));(p/'inspection_geometry_v002.json').write_text(json.dumps({'vertices':[list(v) for v in actual],'faces':faces,'material_indices':mats,'material_colors':[list(m.diffuse_color) for m in ob.data.materials]}));print(json.dumps(record))
