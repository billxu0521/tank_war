import bpy,json,hashlib,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
r=Path.cwd();p=Path(__file__).resolve().parent
src=r/'blender/ninola/working/01R-spine/2026-10-09-v001/ninola_Q1_approved_spine_palette.blend'
donor=r/'blender/ninola/working/01M1/2026-10-08-v002/ninola_01M1_jaw_mass_blockout.blend'
dst=r/'blender/ninola/working/01R1/2026-10-09-v009/ninola_01R1_old_panel_head_transfer.blend'
assert not dst.exists()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
before=sha(src);donorhash=sha(donor)
DG=json.loads((p.parent/'2026-10-09-pass-v001/historical_head_geometry.json').read_text())
assert donorhash==json.loads((p.parent/'2026-10-09-pass-v001/historical_head_inspection.json').read_text())['sha256']
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01Q1_Approved_Spine_Palette'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
faces=[list(f.vertices) for f in a.data.polygons];names=[m.name for m in a.data.materials];mats=[f.material_index for f in a.data.polygons]
skin={'d_olive','d_moss','d_tan','d_belly'}
selected={j for j,f in enumerate(faces) if names[mats[j]] in skin and all(world[i].y>1.85 and weights[i].get('head',0)>.65 for i in f)}
def eye(q):return ((q.y-2.98)/.235)**2+((q.z-2.435)/.185)**2 if abs(q.x)>.27 else 100
def orbital_ring(q):return ((q.y-2.98)/.125)**2+((q.z-2.435)/.095)**2 if abs(q.x)>.29 else 100
collar={j for j in selected if all(orbital_ring(world[i])<1.4 for i in faces[j])}
replace=selected-collar
# Fit old, irregular panel layout to the current head envelope, retaining the eye collar.
target_tris=[];target_face=[]
for j in selected:
 f=faces[j]
 for k in range(1,len(f)-1):target_tris.append([f[0],f[k],f[k+1]]);target_face.append(j)
bvh=BVHTree.FromPolygons(world,target_tris,all_triangles=True)
bmats={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bmats))
 for n,v in w.items():
  if n in bmats:m+=bmats[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
def bary(q,vs):
 A,B,C=vs;v0=B-A;v1=C-A;v2=q-A;d00=v0.dot(v0);d01=v0.dot(v1);d11=v1.dot(v1);d20=v2.dot(v0);d21=v2.dot(v1);den=d00*d11-d01*d01
 if abs(den)<1e-12:return [1,0,0]
 b=(d11*d20-d01*d21)/den;c=(d00*d21-d01*d20)/den
 vals=[max(0,1-b-c),max(0,b),max(0,c)];s=sum(vals);return [x/s for x in vals]
Dv=[Vector(q) for q in DG['vertices']]
ds={j for j,f in enumerate(DG['faces']) if DG['materials'][j] in skin and all(Dv[i].y>1.85 and DG['weights'][i].get('head',0)>.65 for i in f)}
oldids=sorted({i for j in ds for i in DG['faces'][j]})
coords=[];W=[];origins=[];F=[];M=[];currentmap={}
for j,f in enumerate(faces):
 if j in replace:continue
 out=[]
 for i in f:
  if i not in currentmap:
   currentmap[i]=len(coords);coords.append(list(a.data.vertices[i].co));W.append(weights[i]);origins.append(i)
  out.append(currentmap[i])
 F.append(out);M.append(mats[j])
donormap={};transfer=[];boundary_keys=set()
edgecount=collections.Counter()
for j in ds:
 f=DG['faces'][j]
 for aa,bb in zip(f,f[1:]+f[:1]):edgecount[tuple(sorted((tuple(round(x,5) for x in Dv[aa]),tuple(round(x,5) for x in Dv[bb]))))]+=1
for e,c in edgecount.items():
 if c==1:boundary_keys.update(e)
targetkeys=collections.defaultdict(list)
valid_source_ids={i for j,f in enumerate(faces) for i in f}
for i in sorted(valid_source_ids):targetkeys[tuple(round(x,5) for x in world[i])].append(i)
for i in oldids:
 old=Dv[i];k=tuple(round(x,5) for x in old)
 hit,n,ti,dist=bvh.find_nearest(old);assert hit is not None
 # Old and new neck/upper-mouth seam coordinates which still agree are exact.
 exact=targetkeys.get(k) if k in boundary_keys else None
 if exact:
  oi=exact[0];new=world[oi];w=weights[oi];co=a.data.vertices[oi].co
 else:
  new=hit.copy();ts=target_tris[ti];bc=bary(hit,[world[x] for x in ts]);w={}
  for vid,t in zip(ts,bc):
   for gn,value in weights[vid].items():w[gn]=w.get(gn,0)+t*value
  total=sum(w.values());w={gn:v/total for gn,v in w.items() if v>1e-8}
  # Recess under the retained orbit collar rather than pushing a new plane into the eye.
  fade=max(0,1-eye(new)/2.0)
  new.x-=math.copysign(.025*fade,new.x)
  co=bind(new,w)
 donormap[i]=len(coords);coords.append(list(co));W.append(w);origins.append(None)
 transfer.append({'donor_vertex':i,'source_world':list(old),'fitted_world':list(new),'nearest_current_distance':dist,'source_seam_exact':bool(exact),'target_face':target_face[ti]})
for j in sorted(ds):
 F.append([donormap[i] for i in DG['faces'][j]])
 # Preserve original palette; use the nearest current region's material.
 c=sum((Vector(transfer[oldids.index(i)]['fitted_world']) for i in DG['faces'][j]),Vector())/len(DG['faces'][j])
 hit,n,ti,dist=bvh.find_nearest(c);M.append(mats[target_face[ti]])
ob=a.copy();mesh=bpy.data.meshes.new('01R1_Transferred_Panels');mesh.from_pydata(coords,[],F);mesh.update();ob.data=mesh;ob.name='01R1_Old_Panel_Head_Transfer';bpy.context.scene.collection.objects.link(ob)
for m in a.data.materials:mesh.materials.append(m)
for f,m in zip(mesh.polygons,M):f.material_index=m;f.use_smooth=False
for gn in sorted({gn for w in W for gn in w}):
 if gn not in ob.vertex_groups:ob.vertex_groups.new(name=gn)
for i,w in enumerate(W):
 for gn,value in w.items():ob.vertex_groups[gn].add([i],value,'REPLACE')
bpy.context.view_layer.update()
assert all(list(v.co)==list(a.data.vertices[origins[i]].co) for i,v in enumerate(mesh.vertices) if origins[i] is not None)
degen=sum(f.area<1e-10 for f in mesh.polygons);assert degen==0,degen
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe)
issues=pipe.check([ob],budget=None)
for x in bpy.context.scene.objects:
 if x.type=='MESH':x.hide_render=x!=ob;x.hide_set(x!=ob);x.select_set(x==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='Independent donor-panel head shell trial; retained orbit collar; layered prototype interface not Production-ready'
dst.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dst))
assert sha(src)==before and sha(donor)==donorhash
rec={'source_path':str(src.relative_to(r)),'source_sha256':before,'donor_path':str(donor.relative_to(r)),'donor_sha256':donorhash,'output_path':str(dst.relative_to(r)),'sha256':sha(dst),'object':ob.name,'source_head_skin_faces':len(selected),'retained_eye_collar_faces':len(collar),'removed_skin_faces':len(replace),'donor_faces_added':len(ds),'source_triangles':sum(len(f)-2 for f in faces),'triangles':sum(len(f)-2 for f in F),'vertices':len(coords),'donor_vertices':len(oldids),'exact_shared_seam_vertices':sum(x['source_seam_exact'] for x in transfer),'max_donor_fit_distance':max(x['nearest_current_distance'] for x in transfer),'all_retained_original_coordinates_weights_exact':True,'skin_palette_preserved':True,'spine_geometry_materials_preserved':True,'rig_edited':False,'degenerated_faces':degen,'pipeline_issues':issues,'source_donor_hashes_unchanged':True,'production_ready':False,'limitations':['retained orbit collar overlays coarse shell; interface overlap/attachment needs visual and deformation inspection','new shell weights interpolated from current target skin; full animation/export unverified']}
(p/'build_record_v009.json').write_text(json.dumps(rec,indent=2))
(p/'transfer_provenance_v009.json').write_text(json.dumps({'retained_original_vertex_ids':origins,'transferred_vertices':transfer,'source_removed_faces':sorted(replace),'source_retained_orbit_faces':sorted(collar),'donor_faces':sorted(ds)},indent=2))
print(json.dumps(rec))
