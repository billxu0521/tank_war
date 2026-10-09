import bpy,json,math,hashlib,collections
from pathlib import Path
from mathutils import Vector,Matrix
out=Path(__file__).resolve().parent;root=out.parents[4]
rec=root/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/source-records'
src=root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend';dest=root/'blender/ninola/working/01L2/2026-10-08-v001/ninola_01L2_toe_separation.blend'
assert not dest.exists();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();base_sha=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
def locked_signature():
 rig=bpy.data.objects['TrexRig'];tr=bpy.data.objects['Trex'];d={'bones':[(b.name,b.parent.name if b.parent else None,list(b.head_local),list(b.tail_local),[list(row) for row in b.matrix_local]) for b in rig.data.bones],'rig_matrix':[list(row) for row in rig.matrix_world],'pose':[(b.name,[list(row) for row in b.matrix_basis]) for b in rig.pose.bones],'rig_props':str(dict(rig.items())),'Trex_coords':[list(v.co) for v in tr.data.vertices],'Trex_faces':[list(f.vertices) for f in tr.data.polygons],'Trex_weights':[[(g.group,g.weight) for g in v.groups] for v in tr.data.vertices],'Trex_keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]};return sha_bytes(json.dumps(d,sort_keys=True).encode())
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();locked=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];faces=[list(f.vertices) for f in a.data.polygons];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
zones=json.loads((rec/'prototype_face_zones.json').read_text());mapping=json.loads((rec/'k5_build.json').read_text())['face_source_A_indices'];zone_ids=collections.defaultdict(set)
for fi,f in enumerate(faces):zone_ids[zones[mapping[fi]]].update(f)
protected=set()
for z,ids in zone_ids.items():
 if z.endswith(('_pedal_shaft','_rear_retained','_rear_digit_attachment','_anchor_retained','_forward_pad_attachment')):protected.update(ids)
claw=set(i for f in a.data.polygons if a.data.materials[f.material_index].name=='d_claw' for i in f.vertices);protected.update(claw)
protected.update(i for i,p in enumerate(c) if abs(p.x)>.35 and p.z<=.035)
# Select dorsal toe-skin faces by provenance, material, and actual posed coordinates.
selected=set()
for fi,f in enumerate(faces):
 zone=zones[mapping[fi]];mid=sum((c[i] for i in f),Vector())/len(f)
 if zone.endswith(('_forward_retained','_main_toe_attachment')) and a.data.materials[a.data.polygons[fi].material_index].name!='d_claw' and abs(mid.x)>.35 and .24<mid.y<.88 and all(c[i].z>.035 for i in f):selected.add(fi)
assert selected
polys=[f for fi,f in enumerate(faces) if fi not in selected];mats=[f.material_index for f in a.data.polygons if f.index not in selected]
# Refinement is confined to dorsal skin; geometrically shared boundary edges stay put.
key=lambda p:tuple(round(t,6) for t in p)
base_edges=collections.defaultdict(list)
for fi,f in enumerate(faces):
 for x,y in zip(f,f[1:]+f[:1]):base_edges[tuple(sorted((key(c[x]),key(c[y]))))].append(fi)
boundary={e for e,v in base_edges.items() if any(i in selected for i in v) and not all(i in selected for i in v)}
world=c.copy();weights=wt.copy();newprotect=set(protected);local=[];edge_cache={}
def midindex(i,j):
 e=tuple(sorted((key(world[i]),key(world[j]))))
 if e in edge_cache:return edge_cache[e]
 k=len(world);world.append((world[i]+world[j])*.5);weights.append({n:(weights[i].get(n,0)+weights[j].get(n,0))*.5 for n in set(weights[i])|set(weights[j])});edge_cache[e]=k
 if (i in newprotect and j in newprotect) or e in boundary:newprotect.add(k)
 return k
# Two subdivisions make room for two valleys, rather than changing a broad flat triangle.
# Boundary descendants are locked each level, including non-welded flat-shading copies.
subfaces=[(faces[fi],a.data.polygons[fi].material_index) for fi in sorted(selected)]
locked_edges=boundary.copy()
for level in range(2):
 boundary=locked_edges;edge_cache={};nextfaces=[];nextlocked=set()
 for f,mat in subfaces:
  i,j,k=f;ij=midindex(i,j);jk=midindex(j,k);ki=midindex(k,i)
  nextfaces.extend([([i,ij,ki],mat),([ij,j,jk],mat),([ki,jk,k],mat),([ij,jk,ki],mat)])
  for u,v,m in [(i,j,ij),(j,k,jk),(k,i,ki)]:
   if tuple(sorted((key(world[u]),key(world[v])))) in boundary:
    nextlocked.update([tuple(sorted((key(world[u]),key(world[m])))),tuple(sorted((key(world[m]),key(world[v]))))]);newprotect.add(m)
 subfaces=nextfaces;locked_edges=nextlocked
for f,mat in subfaces:polys.append(f);mats.append(mat);local.extend(f)
active=set(local);result=[p.copy() for p in world]
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
# Existing measured toe directions. No X/Y shift, total spread/length/anchors unchanged.
paths=[(.680,.100,.500,.710),(.680,.100,.774,.945),(.680,.100,1.020,.710)]
bundles=collections.defaultdict(list)
for i,p in enumerate(world):bundles[key(p)].append(i)
changed=[]
for ids in bundles.values():
 if any(i in newprotect for i in ids) or not any(i in active for i in ids):continue
 p=world[ids[0]];x=abs(p.x);y=p.y;z=p.z
 if y<=.22 or z<=.04 or z>=.37:continue
 centers=[rx+(tx-rx)*max(0,min(1,(y-ry)/(ty-ry))) for rx,ry,tx,ty in paths]
 gaps=[(centers[n]+centers[n+1])*.5 for n in [0,1]]
 start=smooth((y-.22)/.12);end=smooth((.78-y)/.16);fade=start*end*smooth((z-.035)/.08)
 # Delineate with valleys that broaden as toes fan out; avoid carving a straight trench at the root.
 spacing=min(centers[1]-centers[0],centers[2]-centers[1]);width=max(.012,spacing*.20)
 groove=max(math.exp(-((x-g)/width)**2) for g in gaps)
 distance=min(abs(x-t) for t in centers);ridge=math.exp(-(distance/max(.025,spacing*.32))**2)
 dz=fade*(.045*ridge-.115*groove)
 # Preserve sole clearance and stop well below source top-foot height extent.
 q=p.copy();q.z=max(.045,min(.365,z+dz))
 for i in ids:result[i]=world[i]+(q-p)
# Conservative projection against face inversion, maintaining equal-coordinate copies.
for attempt in range(10):
 bad=set()
 for f in polys:
  i,j,k=f;old=(world[j]-world[i]).cross(world[k]-world[i]);new=(result[j]-result[i]).cross(result[k]-result[i])
  if old.length_squared>1e-12 and (old.dot(new)<=0 or new.length_squared<1e-12):bad.update(key(world[i]) for i in f)
 if not bad:break
 for e in bad:
  for i in bundles[e]:result[i]=world[i]+(result[i]-world[i])*.5
# Clone retained object, keeping source rest geometry and weights exact for original refs.
ob=a.copy();ob.name='01L2_Forward_Toe_Separation';me=bpy.data.meshes.new('01L2_Local_Dorsal_Toe_Surface');ob.data=me;bpy.context.scene.collection.objects.link(ob)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform};rest=[]
for i,(p,q,w) in enumerate(zip(world,result,weights)):
 if i<len(c) and (q-p).length<1e-9:rest.append(a.data.vertices[i].co.copy());continue
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 eff=rig.matrix_world@m@rig.matrix_world.inverted();rest.append(ob.matrix_world.inverted()@(eff.inverted()@q))
 if (q-p).length>1e-9:changed.append(i)
me.from_pydata(rest,[],polys);me.update()
for mat in a.data.materials:me.materials.append(mat)
for name in sorted({n for w in weights for n in w}):
 if name not in ob.vertex_groups:ob.vertex_groups.new(name=name)
for i,w in enumerate(weights):
 for n,v in w.items():
  if v>0:ob.vertex_groups[n].add([i],v,'REPLACE')
for f,mat in zip(me.polygons,mats):f.material_index=mat
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((p-q).length for p,q in zip(actual,result));assert err<2e-6
assert locked_signature()==locked
assert max((actual[i]-c[i]).length for i in protected)<1e-6
flips=[];near=0
for fi,f in enumerate(polys):
 i,j,k=f;old=(world[j]-world[i]).cross(world[k]-world[i]);new=(actual[j]-actual[i]).cross(actual[k]-actual[i])
 if old.length_squared>1e-12 and old.dot(new)<=0:flips.append(fi)
 if new.length_squared<1e-12:near+=1
assert not flips
assert max(abs(actual[i].x-world[i].x)+abs(actual[i].y-world[i].y) for i in range(len(actual)))<2e-6
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_render=obj!=ob;obj.hide_set(obj!=ob);obj.select_set(obj==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='prototype_pending_user_review';ob['base_sha256']=base_sha
record={'base_sha256':base_sha,'base':'01K6 v003, no 01L1 layering','output_path':str(dest.relative_to(root)),'object':ob.name,'selected_original_faces':len(selected),'new_vertices':len(world)-len(c),'vertices':len(world),'faces':len(polys),'modified_original_refs':sum(i<len(c) for i in changed),'modified_new_refs':sum(i>=len(c) for i in changed),'max_dorsal_delta':max(q.z-p.z for p,q in zip(world,actual)),'max_valley_lowering':max(p.z-q.z for p,q in zip(world,actual)),'topology_changed':True,'retained_original_weights_exact':True,'new_weights':'provisional midpoint interpolation, not deformation approved','protected_max_displacement':max((actual[i]-c[i]).length for i in protected),'xy_max_error':max(abs(actual[i].x-world[i].x)+abs(actual[i].y-world[i].y) for i in range(len(actual))),'rig_Trex_exact':True,'new_face_reversals':flips,'near_degenerate_after':near,'inverse_bind_error':err,'status':'pending_user_review','geometric_boundary_subdivision':'locked midpoint positions on shared nonselected edges; existing duplicate flat-shading seams retained; not production manifold certification'}
(out/'edit_mask.json').write_text(json.dumps({'selected_source_faces':sorted(selected),'protected_source_refs':sorted(protected),'modified_refs':changed,'locked_new_boundary_refs':sorted(newprotect-protected)},indent=2))
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==base_sha;bpy.ops.wm.open_mainfile(filepath=str(dest));assert locked_signature()==locked;record['reopen_locked_data_exact']=True;record['output_sha256']=sha(dest);(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
