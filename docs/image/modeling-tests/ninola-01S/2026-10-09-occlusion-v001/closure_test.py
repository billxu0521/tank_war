import bpy,json,hashlib,math,collections
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
r=Path.cwd();p=Path(__file__).resolve().parent;audit=p.parent/'2026-10-09-review-v001';ex=json.loads((audit/'export_records.json').read_text())[0];g=json.loads((p/'closure_samples.json').read_text())['assets']['S'];src=r/ex['source'];sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));rig=bpy.data.objects['TrexRig'];saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};R=rig.matrix_world.copy();C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));rows=[]
def bary(P,A,B,C):
 v0=B-A;v1=C-A;v2=P-A;d00=v0.dot(v0);d01=v0.dot(v1);d11=v1.dot(v1);d20=v2.dot(v0);d21=v2.dot(v1);den=d00*d11-d01*d01
 if abs(den)<1e-16:return [-1,-1,-1]
 v=(d11*d20-d01*d21)/den;w=(d00*d21-d01*d20)/den;return [1-v-w,v,w]
def crossings(c,f1,f2):
 hits=[]
 for aa,bb in [(f1,f2),(f2,f1)]:
  T=[c[i] for i in bb]
  for u,v in zip(aa,aa[1:]+aa[:1]):
   D=c[v]-c[u];L=D.length
   if L<1e-8:continue
   hit=intersect_ray_tri(*T,D.normalized(),c[u],True)
   if hit is not None and 1e-6<(hit-c[u]).dot(D.normalized())<L-1e-6 and min(bary(hit,*T))>1e-5:hits.append(list(hit))
 return hits
for kind,idx in [('jaw_sweep',i) for i in range(7)]:
 s=g[kind][idx];W=Matrix(s['skeleton_world'])
 for b in rig.data.bones:rig.pose.bones[b.name].matrix=R.inverted()@C@W@Matrix(s['bones'][b.name]);bpy.context.view_layer.update()
 for tag,name in [('R2','01R2_Gold_Slit_Eye'),('original_Trex','Trex')]:
  o=bpy.data.objects[name];c=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];faces=[list(f.vertices) for f in o.data.polygons];mn=[o.data.materials[f.material_index].name for f in o.data.polygons];w=[{o.vertex_groups[t.group].name:t.weight for t in v.groups} for v in o.data.vertices];soft=['d_olive','d_moss','d_tan','d_belly','d_mouth'];sets={'jaw_soft':[i for i,f in enumerate(faces) if mn[i] in soft and all(w[j].get('jaw',0)>.99 for j in f)],'head_soft':[i for i,f in enumerate(faces) if mn[i] in soft and all(w[j].get('head',0)>.5 for j in f)],'jaw_teeth':[i for i,f in enumerate(faces) if mn[i]=='d_bone' and all(w[j].get('jaw',0)>.9 for j in f)],'head_teeth':[i for i,f in enumerate(faces) if mn[i]=='d_bone' and all(w[j].get('head',0)>.5 for j in f)]};details={};confirmed=set();rawset=set()
  for key,A,B in [('soft','jaw_soft','head_soft'),('teeth','jaw_teeth','head_teeth')]:
   pairs=BVHTree.FromPolygons(c,[faces[i] for i in sets[A]]).overlap(BVHTree.FromPolygons(c,[faces[i] for i in sets[B]]));details[key]=[]
   for ia,ib in pairs:
    fa,fb=sets[A][ia],sets[B][ib];shared=sorted(set(faces[fa])&set(faces[fb]));hits=crossings(c,faces[fa],faces[fb]);rawset.update([fa,fb])
    if hits:confirmed.update([fa,fb])
    details[key].append({'faces':[fa,fb],'materials':[mn[fa],mn[fb]],'shared_vertices':shared,'strict_edge_face_crossings':hits,'centroids':[list(sum((c[j] for j in faces[fi]),Vector())/len(faces[fi])) for fi in [fa,fb]],'classification':'strict_surface_crossing' if hits else 'touch_or_coplanar_or_BVH_only_flag'})
  row={'asset':tag,'sequence':kind,'frame':idx,'angle_degrees':math.degrees(s['angle_radians']),'soft_raw_pairs':len(details['soft']),'teeth_raw_pairs':len(details['teeth']),'soft_strict_crossing_pairs':sum(bool(x['strict_edge_face_crossings']) for x in details['soft']),'teeth_strict_crossing_pairs':sum(bool(x['strict_edge_face_crossings']) for x in details['teeth']),'details':details};rows.append(row)
  if tag!='R2' or (kind,idx) not in [('jaw_sweep',2),('jaw_sweep',4),('jaw_sweep',6)]:continue
  sc=bpy.data.scenes.new('ReadonlyOcclusion');sc.world=bpy.data.worlds.new('OcclusionBG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1000;sc.render.resolution_y=750;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='MATERIAL';sh.show_shadows=False;sh.show_cavity=True
  mats=[]
  for label,col in [('Gray',(.4,.44,.48,1)),('RawFlag',(.9,.6,.05,1)),('StrictCrossing',(1,.04,.12,1))]:
   m=bpy.data.materials.new(label);m.diffuse_color=col;mats.append(m)
  cd=bpy.data.cameras.new('OcclusionCamera');cam=bpy.data.objects.new('OcclusionCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO'
  for mode in ['head_context','teeth_only','mouth_only']:
   inds=list(range(len(faces))) if mode=='head_context' else sets['jaw_teeth']+sets['head_teeth'] if mode=='teeth_only' else sets['jaw_soft']+sets['head_soft'];me=bpy.data.meshes.new('EvaluatedContact');me.from_pydata(c,[],[faces[i] for i in inds]);me.update();ob=bpy.data.objects.new('EvaluatedContact',me);sc.collection.objects.link(ob)
   for m in mats:me.materials.append(m)
   for f,fi in zip(me.polygons,inds):f.material_index=2 if fi in confirmed else 1 if fi in rawset else 0
   D=Vector((-1,1,.15)).normalized();center=Vector((0,2.9,2.05));cd.ortho_scale=3.0;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/f'closure_{idx:03d}_{mode}.png');bpy.ops.render.render(write_still=True,scene=sc.name);bpy.data.objects.remove(ob,do_unlink=True)
for n,m in saved.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert sha==hashlib.sha256(src.read_bytes()).hexdigest();(p/'closure_details.json').write_text(json.dumps({'source':ex['source'],'sha256':sha,'source_unchanged':True,'method':'BVH flags plus strict segment/triangle interior crossing; touching/coplanar not excluded proof of volumetric clearance','rows':rows},indent=2));print(json.dumps([{k:v for k,v in x.items() if k!='details'} for x in rows]))
