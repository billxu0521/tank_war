import bpy,json,hashlib,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;prev=p.parent/'2026-10-09-pass-v003'
rec=json.loads((prev/'build_record_v010.json').read_text());src=r/rec['output_path'];dst=r/'blender/ninola/working/01R1/2026-10-09-v011/ninola_01R1_posterior_junction.blend';assert not dst.exists()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);assert before==rec['sha256']
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects[rec['object']];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];coords=[list(v.co) for v in a.data.vertices];W=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];smooth=[f.use_smooth for f in a.data.polygons]
donor_faces=set(range(len(faces)-rec['donor_faces_added'],len(faces)));edges=collections.Counter();refs={}
key=lambda i:tuple(round(q,5) for q in world[i])
for j in donor_faces:
 f=faces[j]
 for aa,bb in zip(f,f[1:]+f[:1]):
  k=tuple(sorted((key(aa),key(bb))));edges[k]+=1;refs[k]=(aa,bb)
outer=[k for k,c in edges.items() if c==1 and .25<abs((Vector(k[0])+Vector(k[1])).x*.5) and 2.35<(k[0][1]+k[1][1])*.5<2.7 and 1.9<(k[0][2]+k[1][2])*.5<2.6]
bmats={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bmats))
 for n,v in w.items():
  if n in bmats:m+=bmats[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
targets=[Vector((side*x,2.49,z)) for side in [-1,1] for x,z in [(.51533,2.36631),(.48184,2.20949),(.44834,2.05267)]]
moves={};endpoints={};split=collections.defaultdict(list);plan=[]
for q in targets:
 ids=[i for i,v in enumerate(world) if (q-v).length<.0001];assert len(ids)==1,ids;i=ids[0];best=None
 for k in outer:
  A=Vector(k[0]);B=Vector(k[1])
  if A.x*q.x<=0:continue
  v=B-A;t=max(0,min(1,(world[i]-A).dot(v)/v.length_squared));pos=A+v*t;d=(pos-world[i]).length
  if best is None or d<best[0]:best=(d,k,t,pos)
 distance,k,t,pos=best;assert distance<.15,(i,distance,t)
 coords[i]=list(bind(pos,W[i]));moves[i]=pos
 if .001<t<.999:split[k].append((t,i))
 else:endpoints[k[0] if t<.5 else k[1]]=i
 plan.append({'vertex':i,'before_world':list(world[i]),'after_world':list(pos),'delta':distance,'donor_edge':k,'edge_fraction':t,'weights_unchanged':True})
F=[];M=[];S=[];mapping=[];changed_faces=[]
for j,source_face in enumerate(faces):
 f=[endpoints.get(key(i),i) for i in source_face] if j in donor_faces else source_face
 expanded=None
 if j in donor_faces:
  for aa,bb in zip(f,f[1:]+f[:1]):
   k=tuple(sorted((key(source_face[f.index(aa)]),key(source_face[f.index(bb)]))))
   if k not in split:continue
   chain=[i for t,i in sorted(split[k],reverse=key(source_face[f.index(aa)])!=k[0])]
   assert len(f)==3
   third=next(i for i in f if i not in [aa,bb]);poly=[aa]+chain+[bb]
   expanded=[[poly[z],poly[z+1],third] for z in range(len(poly)-1)];break
 out=expanded if expanded is not None else [f]
 if expanded:changed_faces.append(j)
 for ff in out:F.append(ff);M.append(mats[j]);S.append(smooth[j]);mapping.append(j)
ob=a.copy();me=bpy.data.meshes.new('01R1_Posterior_Junction');me.from_pydata(coords,[],F);me.update();ob.data=me;ob.name='01R1_Posterior_Junction';bpy.context.scene.collection.objects.link(ob)
for mat in a.data.materials:me.materials.append(mat)
for f,m,s in zip(me.polygons,M,S):f.material_index=m;f.use_smooth=s
for gn in sorted({gn for w in W for gn in w}):
 if gn not in ob.vertex_groups:ob.vertex_groups.new(name=gn)
for i,w in enumerate(W):
 for gn,value in w.items():ob.vertex_groups[gn].add([i],value,'REPLACE')
bpy.context.view_layer.update();newworld=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
assert all(list(v.co)==list(a.data.vertices[i].co) for i,v in enumerate(me.vertices) if i not in moves)
assert all((newworld[i]-pos).length<2e-6 for i,pos in moves.items())
assert sum(f.area<1e-10 for f in me.polygons)==0
# New triangles inherit winding; coplanar donor edge subdivisions retain the accepted head surface.
for j,f in enumerate(me.polygons):
 if mapping[j] in changed_faces:
  A,B,C=[newworld[i] for i in f.vertices[:3]];old=faces[mapping[j]];D,E,G=[world[i] for i in old[:3]]
  assert (B-A).cross(C-A).normalized().dot((E-D).cross(G-D).normalized())>.98
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None)
for x in bpy.context.scene.objects:
 if x.type=='MESH':x.hide_render=x!=ob;x.hide_set(x!=ob);x.select_set(x==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='Limited posterior junction repair; accepted nose/orbit/spines unchanged; pending review'
dst.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dst));assert sha(src)==before
record={'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dst.relative_to(r)),'sha256':sha(dst),'object':ob.name,'vertices':len(coords),'source_triangles':rec['triangles'],'triangles':sum(len(f)-2 for f in F),'changed_vertices':sorted(moves),'newly_shared_seam_vertices':len(moves),'endpoint_joins':len(endpoints),'subdivided_donor_faces':changed_faces,'max_vertex_delta':max(q['delta'] for q in plan),'all_other_vertex_coordinates_exact':True,'all_vertex_weights_exact':True,'material_palette_assignments_preserved':True,'original_shading_flags_preserved':True,'accepted_nose_eye_spine_vertex_positions_exact':True,'rig_edited':False,'pipeline_issues':issues,'production_ready':False}
(p/'build_record_v011.json').write_text(json.dumps(record,indent=2));(p/'junction_plan_v011.json').write_text(json.dumps({'moves':plan,'source_face_per_output_face':mapping,'source_sha256':before},indent=2));print(json.dumps(record))
