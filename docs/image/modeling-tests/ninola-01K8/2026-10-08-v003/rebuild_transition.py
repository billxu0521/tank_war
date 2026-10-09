import bpy,json,math,hashlib,collections,bisect
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(__file__).resolve().parents[5];rec=Path(__file__).resolve().parent.parent/'2026-10-08-v001/source-records';out=rec.parent.parent/'2026-10-08-v004';out.mkdir(exist_ok=True)
source=root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend';dest=root/'blender/ninola/working/01K8/2026-10-08-v004/ninola_01K8_hock_mass_continuity.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();srcsha=sha(source);bpy.ops.wm.open_mainfile(filepath=str(source));a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];rest=[v.co.copy() for v in a.data.vertices];fs=[list(p.vertices) for p in a.data.polygons];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
def locksig():
 rig=bpy.data.objects['TrexRig'];tr=bpy.data.objects['Trex'];d={'bones':[(b.name,b.parent.name if b.parent else None,[list(r) for r in b.matrix_local]) for b in rig.data.bones],'pose':[(p.name,[list(r) for r in p.matrix_basis]) for p in rig.pose.bones],'rigprops':str(dict(rig.items())),'Trex_coords':[list(v.co) for v in tr.data.vertices],'Trex_faces':[list(p.vertices) for p in tr.data.polygons],'Trex_weights':[[(g.group,g.weight) for g in v.groups] for v in tr.data.vertices],'keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]};return hashlib.sha256(json.dumps(d,sort_keys=True).encode()).hexdigest()
locked=locksig();boundary=json.loads((rec/'transition_loops.json').read_text());remove=set(boundary['faces']);retained=[f for i,f in enumerate(fs) if i not in remove];polys=retained.copy();materials=[p.material_index for i,p in enumerate(a.data.polygons) if i not in remove];mat=collections.Counter(a.data.polygons[i].material_index for i in remove).most_common(1)[0][0]
newworld=c.copy();newwt=wt.copy();loops=boundary['loops'];generated=[]
def area(ids):return sum(c[i].x*c[j].y-c[j].x*c[i].y for i,j in zip(ids,ids[1:]+ids[:1]))
def params(ids):
 lengths=[(c[j]-c[i]).length for i,j in zip(ids,ids[1:]+ids[:1])];s=sum(lengths);v=[0]
 for l in lengths:v.append(v[-1]+l/s)
 return v
for side in [1,-1]:
 ll=[l for l in loops if c[l[0]].x*side>0];top=max(ll,key=len);bottom=min(ll,key=len)
 if area(top)*area(bottom)<0:bottom=list(reversed(bottom))
 offset=min(range(len(bottom)),key=lambda i:(c[bottom[i]]-c[top[0]]).length);bottom=bottom[offset:]+bottom[:offset];tt=params(top);bt=params(bottom)
 def interp(t):
  j=min(len(bottom)-1,bisect.bisect_right(bt,t)-1);f=(t-bt[j])/(bt[j+1]-bt[j]);i,k=bottom[j],bottom[(j+1)%len(bottom)];weights={n:wt[i].get(n,0)*(1-f)+wt[k].get(n,0)*f for n in set(wt[i])|set(wt[k])};return c[i].lerp(c[k],f),weights
 previous=top
 for alpha in [.33,.66]:
  ring=[]
  for i,t in zip(top,tt):
   b,bw=interp(t);p=c[i].lerp(b,alpha)
   # Slight posterior tendon support and anterior taper; no circular band.
   front=max(-1,min(1,(p.y+.075)/.20));p.y-=.014*math.sin(math.pi*alpha)*max(0,-front)
   weights={n:wt[i].get(n,0)*(1-alpha)+bw.get(n,0)*alpha for n in set(wt[i])|set(bw)}
   ring.append(len(newworld));newworld.append(p);newwt.append(weights)
  for j in range(len(top)):
   k=(j+1)%len(top);generated.extend([[previous[j],previous[k],ring[k]],[previous[j],ring[k],ring[j]]])
  previous=ring
 # Zipper unequal source boundary loops, retaining every perimeter edge.
 i=j=0
 while i<len(top) or j<len(bottom):
  if j==len(bottom) or (i<len(top) and tt[i+1]<bt[j+1]):
   generated.append([previous[i%len(top)],previous[(i+1)%len(top)],bottom[j%len(bottom)]]);i+=1
  else:
   generated.append([previous[i%len(top)],bottom[(j+1)%len(bottom)],bottom[j%len(bottom)]]);j+=1
# Orient entire connected side consistently to retained source boundary winding.
source_edges={}
for f in retained:
 ks=[tuple(round(v,5) for v in c[i]) for i in f]
 for x,y in zip(ks,ks[1:]+ks[:1]):source_edges[tuple(sorted((x,y)))]=(x,y)
for side in [1,-1]:
 group=[f for f in generated if newworld[f[0]].x*side>0];flip=None
 for f in group:
  ks=[tuple(round(v,5) for v in newworld[i]) for i in f]
  for x,y in zip(ks,ks[1:]+ks[:1]):
   old=source_edges.get(tuple(sorted((x,y))))
   if old is not None:flip=old==(x,y);break
  if flip is not None:break
 assert flip is not None
 if flip:
  for f in group:f.reverse()
polys.extend(generated);materials.extend([mat]*len(generated))
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform};restout=rest.copy()
for p,w in zip(newworld[len(c):],newwt[len(c):]):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 eff=rig.matrix_world@m@rig.matrix_world.inverted();restout.append(a.matrix_world.inverted()@(eff.inverted()@p))
ob=a.copy();ob.name='01K8_Hock_Mass_Continuity';me=bpy.data.meshes.new('01K8_Local_Hock_Transition');me.from_pydata(restout,[],polys);me.update();ob.data=me;bpy.context.scene.collection.objects.link(ob)
for m in a.data.materials:me.materials.append(m)
for name in sorted({n for w in newwt for n in w}):
 if name not in ob.vertex_groups:ob.vertex_groups.new(name=name)
for i,w in enumerate(newwt):
 for n,v in w.items():
  if v>0:ob.vertex_groups[n].add([i],v,'REPLACE')
for p,m in zip(me.polygons,materials):p.material_index=m
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((p-q).length for p,q in zip(actual,newworld));assert err<2e-6;assert locksig()==locked
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and obj!=ob:obj.hide_render=True;obj.hide_set(True)
ob.hide_set(False);ob.hide_render=False;bpy.context.view_layer.objects.active=ob;ob.select_set(True);ob['status']='prototype_pending_user_review'
protected=json.loads((rec/'k6_build.json').read_text())['protected_indices'];assert max((actual[i]-c[i]).length for i in protected)<1e-6
# Quantized geometric seam and winding check, not full model manifold certification.
edge=collections.defaultdict(list)
for f in generated:
 keys=[tuple(round(v,5) for v in actual[i]) for i in f]
 for x,y in zip(keys,keys[1:]+keys[:1]):edge[tuple(sorted((x,y)))].append((x,y))
conflicts=sum(len(v)==2 and v[0]==v[1] for v in edge.values())
near=sum((actual[f[1]]-actual[f[0]]).cross(actual[f[2]]-actual[f[0]]).length_squared<1e-12 for f in generated)
record={'base_sha256':srcsha,'output_path':str(dest.relative_to(root)),'object':ob.name,'vertices':len(actual),'triangles':len(polys),'removed_faces':len(remove),'new_faces':len(generated),'new_vertices':len(actual)-len(c),'original_vertex_positions_max_displacement':max((actual[i]-c[i]).length for i in range(len(c))),'protected_max_displacement':max((actual[i]-c[i]).length for i in protected),'rig_Trex_keys_weights_geometry_exact':True,'topology_changed':True,'weight_method':'provisional source boundary weight interpolation on new shell only; retained weights exact','inverse_binding_error':err,'new_shell_near_degenerate':near,'new_shell_edge_winding_conflicts':conflicts,'status':'pending_user_review','unused_old_transition_vertices_retained_for_provenance':True}
assert conflicts==0,conflicts
assert near==0,near
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(source)==srcsha;bpy.ops.wm.open_mainfile(filepath=str(dest));assert locksig()==locked;record['reopen_locked_data_exact']=True;record['output_sha256']=sha(dest);(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
