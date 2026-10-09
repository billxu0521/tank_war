import bpy,json,math,hashlib,collections
from pathlib import Path
from mathutils import Vector,Matrix
out=Path(__file__).resolve().parent;root=out.parents[4]
rec=root/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/source-records'
src=root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend';dest=root/'blender/ninola/working/01L3/2026-10-08-v001/ninola_01L3_toe_volume_rebuild.blend'
assert not dest.exists();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();base_sha=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
def locked_signature():
 rig=bpy.data.objects['TrexRig'];tr=bpy.data.objects['Trex'];d={'bones':[(b.name,b.parent.name if b.parent else None,list(b.head_local),list(b.tail_local),[list(row) for row in b.matrix_local]) for b in rig.data.bones],'rig_matrix':[list(row) for row in rig.matrix_world],'pose':[(b.name,[list(row) for row in b.matrix_basis]) for b in rig.pose.bones],'rig_props':str(dict(rig.items())),'Trex_coords':[list(v.co) for v in tr.data.vertices],'Trex_faces':[list(f.vertices) for f in tr.data.polygons],'Trex_weights':[[(g.group,g.weight) for g in v.groups] for v in tr.data.vertices],'Trex_keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]};return sha_bytes(json.dumps(d,sort_keys=True).encode())
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();locked=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];faces=[list(f.vertices) for f in a.data.polygons];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
zones=json.loads((rec/'prototype_face_zones.json').read_text());mapping=json.loads((rec/'k5_build.json').read_text())['face_source_A_indices'];zone_ids=collections.defaultdict(set)
for fi,f in enumerate(faces):zone_ids[zones[mapping[fi]]].update(f)
import bmesh
interfaces=json.loads((out/'source_interfaces.json').read_text());remove=set(interfaces['removed_source_faces']);retained=[f for i,f in enumerate(faces) if i not in remove];materials=[f.material_index for f in a.data.polygons if f.index not in remove]
skinmat=collections.Counter(a.data.polygons[i].material_index for i in remove).most_common(1)[0][0]
base_materials=list(a.data.materials);capback=bpy.data.materials.new('Temporary_Source_Interface_Cap');capclaw=bpy.data.materials.new('Temporary_Claw_Interface_Cap');allmat=base_materials+[capback,capclaw];backidx=len(base_materials);clawidx=backidx+1
key=lambda p:tuple(round(t,5) for t in p)
def tempmesh(name,verts,ff,mm):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],ff);me.update()
 for m in allmat:me.materials.append(m)
 for f,m in zip(me.polygons,mm):f.material_index=m
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);return ob
N=12;localworld=[];localfaces=[];localmats=[];summary=[]
for side in interfaces['feet']:
 sign=side['side_sign'];ring=side['root_ring'];rv=[c[i].copy() for i in ring];rf=[];rm=[]
 def bridge(r1,r2,ff,mm):
  assert len(r1)==len(r2)
  for j in range(len(r1)):
   k=(j+1)%len(r1);ff.extend([[r1[j],r1[k],r2[k]],[r1[j],r2[k],r2[j]]]);mm.extend([skinmat]*2)
 previous=list(range(N))
 # Keep the exact inverse-bound source root boundary; only the distal common root is rebuilt.
 for y,rx,top,bottom in [(.255,.195,.251,.025),(.340,.180,.226,.015)]:
  new=[]
  for i in ring:
   angle=math.atan2(c[i].z-.14266,abs(c[i].x)-.678);new.append(len(rv));rv.append(Vector((sign*(.70+rx*math.cos(angle)),y,(top+bottom)/2+(top-bottom)/2*math.sin(angle))))
  bridge(previous,new,rf,rm);previous=new
 # Temporary cap is removed after union, preserving all original root coordinates.
 backcenter=len(rv);rv.append(sum(rv[:N],Vector())/N)
 frontcenter=len(rv);rv.append(sum((rv[i] for i in previous),Vector())/N)
 for j in range(N):
  k=(j+1)%N;rf.append([backcenter,j,k]);rm.append(backidx);rf.append([frontcenter,previous[j],previous[k]]);rm.append(skinmat)
 rootob=tempmesh('Temporary_L3_Common_Root',rv,rf,rm)
 for toe in side['toes']:
  n=toe['number'];terminal=toe['claw_ring'];end=Vector(toe['claw_ring_center']);endx=abs(end.x);endy=end.y;starty=.280
  # Thick proximal bodies taper by digit, not three identical straight cylinders.
  ys=[starty,.360,.450,.540]+([.630,.730,.825] if n==2 else [.620]);ys=[y for y in ys if y<endy-.045]
  tv=[];tf=[];tm=[];rings=[]
  for y in ys:
   t=(y-.10)/(endy-.10);cx=.680+(endx-.680)*t
   rootwidth={1:.095,2:.102,3:.101}[n];endwidth={1:.094,2:.091,3:.090}[n]
   u=(y-starty)/(endy-starty);rx=rootwidth*(1-u)+endwidth*u
   # Modest joint rhythm, broad pads and controlled taper rather than uniform inflation.
   rx*=1+.055*math.sin(math.pi*u*2)
   top=.245*(1-u)+.145*u+(.012 if n==2 else .006)*math.sin(math.pi*u)
   bottom=.014+.004*math.sin(math.pi*u);cz=(top+bottom)/2;rz=(top-bottom)/2
   slope=(endx-.680)/(endy-.10);rr=[]
   for j in range(N):
    theta=2*math.pi*j/N;rr.append(len(tv));tv.append(Vector((sign*(cx+rx*math.cos(theta)),y-rx*math.cos(theta)*slope,cz+rz*math.sin(theta))))
   if rings:bridge(rings[-1],rr,tf,tm)
   rings.append(rr)
  startcenter=len(tv);tv.append(sum((tv[i] for i in rings[0]),Vector())/N)
  for j in range(N):tf.append([startcenter,rings[0][j],rings[0][(j+1)%N]]);tm.append(skinmat)
  # Exact four-point claw base retained; no claw curvature/tip transformation.
  four=[]
  for i in terminal:four.append(len(tv));tv.append(c[i].copy())
  # Match ring cyclic ordering in X/Z, with nearest phase and consistent orientation.
  four.sort(key=lambda i:math.atan2(tv[i].z-end.z,(tv[i].x-end.x)*sign))
  last=rings[-1];start=min(range(4),key=lambda j:(tv[four[j]]-tv[last[0]]).length);four=four[start:]+four[:start]
  i=j=0
  while i<N or j<4:
   if j==4 or (i<N and (i+1)/N<(j+1)/4):tf.append([last[i%N],last[(i+1)%N],four[j%4]]);tm.append(skinmat);i+=1
   else:tf.append([last[i%N],four[(j+1)%4],four[j%4]]);tm.append(skinmat);j+=1
  tf.extend([[four[0],four[1],four[2]],[four[0],four[2],four[3]]]);tm.extend([clawidx]*2)
  toeob=tempmesh('Temporary_L3_Digit_'+str(n),tv,tf,tm)
  mod=rootob.modifiers.new('Local_Digit_Union','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=toeob
  bpy.context.view_layer.update();bpy.context.view_layer.objects.active=rootob
  for ob in bpy.context.selected_objects:ob.select_set(False)
  rootob.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(toeob,do_unlink=True)
 # Boolean only applied to temporary skin volumes, never source model or Armature.
 bm=bmesh.new();bm.from_mesh(rootob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(rootob.data);bm.free();rootob.data.update()
 offset=len(localworld);localworld.extend(v.co.copy() for v in rootob.data.vertices);kept=0;caps=0
 for f in rootob.data.polygons:
  if f.material_index in [backidx,clawidx]:caps+=1;continue
  localfaces.append([offset+i for i in f.vertices]);localmats.append(f.material_index);kept+=1
 summary.append({'side_sign':sign,'skin_faces':kept,'temporary_caps_removed':caps});bpy.data.objects.remove(rootob,do_unlink=True)
# Source references retained for provenance; removed plate vertices become unused, not visible faces.
world=c.copy();weights=wt.copy();lookup={key(p):i for i,p in enumerate(c)};newmap={};skin_source=[i for i,p in enumerate(c) if abs(p.x)>.35 and p.z<.38 and p.y>.02]
for i,p in enumerate(localworld):
 if key(p) in lookup and (c[lookup[key(p)]]-p).length<2e-5:newmap[i]=lookup[key(p)];continue
 newmap[i]=len(world);world.append(p)
 nearest=sorted((j for j in skin_source if c[j].x*p.x>0),key=lambda j:(c[j]-p).length_squared)[:4];coeff=[1/max(1e-5,(c[j]-p).length_squared) for j in nearest];den=sum(coeff);ww=collections.defaultdict(float)
 for j,factor in zip(nearest,coeff):
  for n,v in wt[j].items():ww[n]+=v*factor/den
 weights.append(dict(ww))
newfaces=[[newmap[i] for i in f] for f in localfaces];newmats=localmats.copy()
# Preserve the pre-existing small anchor-loop interface instead of moving contact samples.
for side in interfaces['feet']:
 f=side['anchor_triangle'];newfaces.append(f.copy());newmats.append(skinmat)
# Orient each connected side to the retained source root winding.
retedges={}
for f in retained:
 for i,j in zip(f,f[1:]+f[:1]):retedges[tuple(sorted((key(c[i]),key(c[j]))))]=(key(c[i]),key(c[j]))
root_seam_keys={tuple(sorted((key(c[i]),key(c[j])))) for side in interfaces['feet'] for i,j in side['root_source_boundary_edges'] if c[i].y<.1995 and c[j].y<.1995}
for sign in [1,-1]:
 group=[f for f in newfaces if world[f[0]].x*sign>0];flip=None
 for f in group:
  for i,j in zip(f,f[1:]+f[:1]):
   prev=retedges.get(tuple(sorted((key(world[i]),key(world[j])))))
   if prev and tuple(sorted((key(world[i]),key(world[j])))) in root_seam_keys:flip=prev==(key(world[i]),key(world[j]));break
  if flip is not None:break
 assert flip is not None
 if flip:
  for f in group:f.reverse()
for f in newfaces[-2:]:
 for i,j in zip(f,f[1:]+f[:1]):
  prev=retedges.get(tuple(sorted((key(world[i]),key(world[j])))))
  if prev:
   if prev==(key(world[i]),key(world[j])):f.reverse()
   break
polys=retained+newfaces;mats=materials+newmats
ob=a.copy();ob.name='01L3_Three_Toe_Volume_Reconstruction';me=bpy.data.meshes.new('01L3_Rebuilt_Toe_Skin');ob.data=me;bpy.context.scene.collection.objects.link(ob)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform};rest=[v.co.copy() for v in a.data.vertices]
for p,ww in zip(world[len(c):],weights[len(c):]):
 m=Matrix.Identity(4)*(1-sum(v for n,v in ww.items() if n in bm))
 for n,v in ww.items():
  if n in bm:m+=bm[n]*v
 eff=rig.matrix_world@m@rig.matrix_world.inverted();rest.append(ob.matrix_world.inverted()@(eff.inverted()@p))
me.from_pydata(rest,[],polys);me.update()
for m in base_materials:me.materials.append(m)
for n in sorted({n for ww in weights for n in ww}):
 if n not in ob.vertex_groups:ob.vertex_groups.new(name=n)
for i,ww in enumerate(weights):
 for n,v in ww.items():
  if v>0:ob.vertex_groups[n].add([i],v,'REPLACE')
for f,m in zip(me.polygons,mats):f.material_index=m
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((p-q).length for p,q in zip(world,actual));assert err<3e-5;assert locked_signature()==locked
near=sum((actual[f[1]]-actual[f[0]]).cross(actual[f[2]]-actual[f[0]]).length_squared<1e-12 for f in newfaces)
# Geometry-aware seam checks include non-welded source references.
edges=collections.defaultdict(list)
for f in newfaces:
 for i,j in zip(f,f[1:]+f[:1]):edges[tuple(sorted((key(actual[i]),key(actual[j]))))].append((key(actual[i]),key(actual[j])))
internal_conflicts=sum(len(v)==2 and v[0]==v[1] for v in edges.values());all_seam_keys=set(edges)&set(retedges);seam_keys={tuple(sorted((key(c[i]),key(c[j])))) for side in interfaces['feet'] for i,j in side['root_source_boundary_edges']} & set(edges);seam_conflicts=sum(any(e==retedges[k] for e in edges[k]) for k in seam_keys)
record={'base_sha256':base_sha,'base':'01K6 v003, no L1/L2 geometry layering','output_path':str(dest.relative_to(root)),'object':ob.name,'removed_source_faces':len(remove),'new_skin_faces':len(newfaces),'new_vertices':len(world)-len(c),'vertices':len(world),'faces':len(polys),'original_ref_coords_max_displacement':max((actual[i]-c[i]).length for i in range(len(c))),'retained_original_weights_exact':True,'rig_Trex_exact':True,'topology_changed':True,'new_weights':'provisional inverse-distance interpolation from source foot skin; no deformation approval','inverse_bind_error':err,'new_skin_near_degenerates':near,'new_internal_winding_conflicts':internal_conflicts,'source_seam_edges':len(seam_keys),'claw_base_cap_note':'original closed claw base caps retained unchanged; geometric skin/claw interface may be nonmanifold and needs separately authorized production cleanup','source_seam_winding_conflicts':seam_conflicts,'boolean_summary':summary,'unused_old_skin_points_retained_for_provenance':True,'status':'pending_visual_review'}
(out/'edit_mask.json').write_text(json.dumps({'removed_source_faces':sorted(remove),'new_faces_start':len(retained),'source_interfaces':interfaces},indent=2))
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='prototype_pending_visual_review';ob['base_sha256']=base_sha
assert internal_conflicts==0,internal_conflicts;assert seam_conflicts==0,seam_conflicts
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==base_sha;bpy.ops.wm.open_mainfile(filepath=str(dest));assert locked_signature()==locked;record['reopen_locked_data_exact']=True;record['output_sha256']=sha(dest);(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
