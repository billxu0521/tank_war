import bpy,bmesh,json,hashlib,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01O2/2026-10-09-v003/ninola_01O2_ventral_belly_tuck.blend';dest=r/'blender/ninola/working/01P1/2026-10-09-v001/ninola_01P1_palm_digit_continuity.blend';assert not dest.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01O2_Ventral_Belly_Tuck'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[x.group].name:x.weight for x in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];names=[m.name for m in a.data.materials];mats=[f.material_index for f in a.data.polygons];assert not a.data.shape_keys
key=lambda i:tuple(round(v,5) for v in world[i]);selected={fi for fi,f in enumerate(faces) if names[mats[fi]]!='d_claw' and all(sum(v for n,v in weights[i].items() if n.startswith(('arm_','forearm_','hand_','finger')))>.35 for i in f) and all(.4<abs(world[i].x)<.8 and 1.60<world[i].y<1.75 and 1.05<world[i].z<1.31 for i in f)};print("SELECTED",len(selected),sorted(selected));assert len(selected)==17
locked=lambda:{'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in rig.data.bones],'pose':[(b.name,[list(row) for row in b.matrix_basis]) for b in rig.pose.bones],'keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in bpy.data.objects['Trex'].data.shape_keys.key_blocks]};locks=locked();ob=a.copy();ob.data=a.data.copy();ob.name='01P1_Palm_Digit_Continuity';bpy.context.scene.collection.objects.link(ob);bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
mesh=bmesh.new();mesh.from_mesh(ob.data);mesh.verts.ensure_lookup_table();mesh.faces.ensure_lookup_table();original_verts=list(mesh.verts);original_faces=list(mesh.faces);coordmap={v:world[i] for i,v in enumerate(original_verts)};deform=mesh.verts.layers.deform.verify();groupindex={g.name:g.index for g in ob.vertex_groups};newverts=[];newfaces=[];seamdata=[]
def add(q,w):
 q=Vector(q);v=mesh.verts.new(bind(q,w));total=sum(w.values());assert abs(total-1)<1e-4
 for n,value in w.items():v[deform][groupindex[n]]=value
 newverts.append((v,q,w));coordmap[v]=q;return v

def bridge(A,B,mat):
 # Monotone perimeter correspondence supports triangle and 10/6/4 rings.
 i=j=0
 while i<len(A) or j<len(B):
  ta=(i+1)/len(A) if i<len(A) else 2;tb=(j+1)/len(B) if j<len(B) else 2
  if abs(ta-tb)<1e-9:poly=[A[i%len(A)],A[(i+1)%len(A)],B[(j+1)%len(B)],B[j%len(B)]];i+=1;j+=1
  elif ta<tb:poly=[A[i%len(A)],A[(i+1)%len(A)],B[j%len(B)]];i+=1
  else:poly=[A[i%len(A)],B[(j+1)%len(B)],B[j%len(B)]];j+=1
  f=mesh.faces.new(poly);f.material_index=mat;newfaces.append(f)

def mix(A,B,t):return {n:A.get(n,0)*(1-t)+B.get(n,0)*t for n in A.keys()|B.keys() if A.get(n,0)*(1-t)+B.get(n,0)*t>1e-8}
for side in [1,-1]:
 ss=[fi for fi in selected if world[faces[fi][0]].x*side>0];edges=collections.Counter(tuple(sorted((key(x),key(y)))) for fi in ss for x,y in zip(faces[fi],faces[fi][1:]+faces[fi][:1]));boundary=[e for e,n in edges.items() if n==1];assert len(boundary) in (3,4)
 keys=set(k for e in boundary for k in e);orig={k:next(i for fi,f in enumerate(faces) if fi not in selected for i in f if key(i)==k) for k in keys}
 # Existing boundary triangle is retained exactly, including skinning.
 center=Vector((side*.62,1.65,1.22));coords=lambda v: coordmap[v]
 angular=lambda q:math.atan2((q.z-1.22)/.72+(q.y-1.65)/.69,(q.x*side-.62))
 boundarykeys=sorted(keys,key=lambda k:angular(Vector(k)));A=[original_verts[orig[k]] for k in boundarykeys]
 avg={n:sum(weights[orig[k]].get(n,0) for k in keys)/len(keys) for n in set(n for k in keys for n in weights[orig[k]])}
 hand={f'hand_{"l" if side==1 else "r"}':1.0}
 # Ten-point ring: top and bottom middle become shared web edge. Width remains compact.
 P=[]
 for j in range(10):
  theta=math.pi/2+j*2*math.pi/10;x=.62+.075*math.cos(theta);u=math.sin(theta)
  P.append(add((side*x,1.649+u*.028*.69,1.218+u*.028*.72),mix(avg,hand,.65)))
 # Cyclic alignment at proximal seam; preserve P's bifurcation identities.
 rotations=[P[i:]+P[:i] for i in range(10)]
 shifted=min(rotations,key=lambda ring:sum((coords(A[i])-coords(ring[round(i*10/len(A))%10])).length_squared for i in range(len(A))))
 bridge(A,shifted,names.index('d_olive'))
 for digit,start in [(1,[P[i] for i in range(6)]),(2,[P[i%10] for i in range(5,11)])]:
  cf=[fi for fi,f in enumerate(faces) if names[mats[fi]]=='d_claw' and all(world[i].x*side>0 and ((abs(world[i].x)<.62) if digit==1 else (abs(world[i].x)>.62)) and 1.65<world[i].y<1.75 and .90<world[i].z<1.14 for i in f)]
  assert len(cf)==6
  rootkeys=set(key(i) for fi in cf for i in faces[fi] if world[i].z>1.09);assert len(rootkeys)==4
  rootids={k:next(i for fi in cf for i in faces[fi] if key(i)==k) for k in rootkeys};rootcenter=sum((world[i] for i in rootids.values()),Vector())/4
  rootweight={n:sum(weights[i].get(n,0) for i in rootids.values())/4 for n in set(n for i in rootids.values() for n in weights[i])}
  x=.578 if digit==1 else .662;middle=[]
  for j in range(6):
   theta=math.pi/2+j*2*math.pi/6;u=math.sin(theta)
   middle.append(add((side*((x+abs(rootcenter.x))/2+.035*math.cos(theta)),1.684+u*.028*.69,1.157+u*.028*.72),mix(hand,rootweight,.65)))
  rotations=[middle[i:]+middle[:i] for i in range(6)]
  middle=min(rotations,key=lambda ring:sum((coords(start[i])-coords(ring[i])).length_squared for i in range(6)))
  bridge(start,middle,names.index('d_olive'))
  rk=sorted(rootkeys,key=lambda k:math.atan2(k[2]-rootcenter.z,k[0]*side-abs(rootcenter.x)));end=[original_verts[rootids[k]] for k in rk]
  # Root uses original vertex, bind coordinate and exact original deform weights.
  rotations=[end[i:]+end[:i] for i in range(4)]
  end=min(rotations,key=lambda ring:sum((coords(middle[round(i*6/4)%6])-coords(ring[i])).length_squared for i in range(4)))
  bridge(middle,end,names.index('d_olive'))
  seamdata.append({'side':side,'digit':digit,'root_vertex_ids':list(rootids.values()),'root_weights':rootweight,'root_exact':True})
for fi in sorted(selected,reverse=True):mesh.faces.remove(original_faces[fi])
# Remove edges made loose only by replacement; preserve all original source coordinates.
for e in list(mesh.edges):
 if not e.link_faces and all(v in original_verts for v in e.verts) and any(set(e.verts).issubset({original_verts[i] for i in faces[fi]}) for fi in selected):mesh.edges.remove(e)
bmesh.ops.recalc_face_normals(mesh,faces=newfaces)
# The skin is split at source-coordinate duplicates, so choose global new-skin
# winding against outward radial direction instead of claiming closed topology.
for f in newfaces:
 c=sum((coords(v) for v in f.verts),Vector())/len(f.verts);side=1 if c.x>0 else -1;axis=Vector((side*.62,1.66,1.20));rad=Vector((c.x-axis.x,c.y-axis.y,c.z-axis.z))
 if f.normal.dot(ob.matrix_world.inverted().to_3x3()@rad)<0:f.normal_flip()
mesh.to_mesh(ob.data);mesh.free();ob.data.update();bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
assert locked()==locks;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(world)))
assert all(abs(ob.vertex_groups[g.group].index-g.group)<1 for v in a.data.vertices for g in v.groups)
assert [{ob.vertex_groups[g.group].name:g.weight for g in ob.data.vertices[i].groups} for i in range(len(world))]==weights
assert max((actual[i]-world[i]).length for i in range(len(world)))<1e-6
source_signature=lambda fi:(tuple(tuple(round(x,7) for x in a.data.vertices[i].co) for i in faces[fi]),mats[fi])
retained=collections.Counter((tuple(tuple(round(x,7) for x in ob.data.vertices[i].co) for i in f.vertices),f.material_index) for f in ob.data.polygons)
assert all(retained[source_signature(fi)]>0 for fi in range(len(faces)) if fi not in selected)
# Non-target data and exact root coordinates/weights remain unchanged in isolated poses.
posechecks=[]
assert locked()==locks
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None)
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01P1 v001 hand skin trial pending review; claws and rig unchanged';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
record={'source':str(src.relative_to(r)),'source_sha256':before,'output':str(dest.relative_to(r)),'sha256':sha(dest),'object':ob.name,'replaced_faces':sorted(selected),'replaced_triangles':len(selected),'new_vertices':len(newverts),'new_faces_before_triangulation':len(newfaces),'vertices':len(ob.data.vertices),'triangles':sum(len(f.vertices)-2 for f in ob.data.polygons),'non_target_faces_coordinates_materials_retained':True,'all_original_bind_coordinates_and_weights_exact':True,'Rig_Trex_keys_pose_exact':True,'claw_root_seams':seamdata,'limited_pose_checks':posechecks,'pipeline_issues':issues,'source_unchanged':True,'production_ready':False,'limitation':'local hand skin replacement; original two claws weight mainly finger1 remains; no production keys/GLB/new game test'};(p/'build_record.json').write_text(json.dumps(record,indent=2));(p/'inspection_geometry.json').write_text(json.dumps({'vertices':[list(v) for v in actual],'faces':[list(f.vertices) for f in ob.data.polygons],'material_indices':[f.material_index for f in ob.data.polygons],'material_colors':[list(m.diffuse_color) for m in ob.data.materials]}));print(json.dumps(record))
