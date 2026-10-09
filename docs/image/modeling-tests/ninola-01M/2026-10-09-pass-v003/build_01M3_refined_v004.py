import bpy,json,hashlib,ast,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.geometry import tessellate_polygon
r=Path.cwd();out=Path(__file__).resolve().parent/'refined-v004';out.mkdir(exist_ok=True);src=r/'blender/ninola/working/01M1/2026-10-08-v002/ninola_01M1_jaw_mass_blockout.blend';dest=r/'blender/ninola/working/01M3/2026-10-09-v004/ninola_01M3_concept_head_reconstruction.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M1_Lower_Jaw_Mass_Blockout'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];key=lambda i:tuple(round(v,5) for v in c[i]);world=[v.copy() for v in c]
# Remove one complete cranial skin patch; keep exact neck and oral boundary, teeth, inner mouth, jaw and body.
remove={fi for fi,f in enumerate(faces) if mats[fi] in [0,1,2,5] and all(wt[i].get('head',0)>.3 and c[i].y>2.33 for i in f)};edges=collections.Counter();rep={}
for fi in remove:
 f=faces[fi]
 for i in f:rep[key(i)]=i
 for aa,bb in zip(f,f[1:]+f[:1]):edges[tuple(sorted([key(aa),key(bb)]))]+=1
adj=collections.defaultdict(set)
for (aa,bb),n in edges.items():
 if n==1:adj[aa].add(bb);adj[bb].add(aa)
assert adj and all(len(v)==2 for v in adj.values());start=min(adj);loop=[start];prev=None;cur=start
while True:
 nxt=next(k for k in sorted(adj[cur]) if k!=prev)
 if nxt==start:break
 loop.append(nxt);prev,cur=cur,nxt
assert len(loop)==len(adj)
boundary=[rep[k] for k in loop]
uv=[Vector((c[i].y,math.atan2(max(.001,c[i].z-1.85),c[i].x),0)) for i in boundary]
# Triangulate the preserved boundary in a cylindrical chart, then insert an independent grid of control points.
tris=tessellate_polygon([uv]);uvlookup={tuple(v):i for i,v in enumerate(uv)};tf=[[v if isinstance(v,int) else uvlookup[tuple(v)] for v in tri] for tri in tris];assert len(tf)==len(uv)-2
localworld=[c[i].copy() for i in boundary];localwt=[dict(wt[i]) for i in boundary];uvpoints=[v.copy() for v in uv]
stations=[(2.33,.52,2.64,1.95),(2.55,.53,2.68,1.95),(2.85,.49,2.66,1.96),(3.15,.40,2.58,1.98),(3.45,.31,2.48,2.00),(3.70,.23,2.36,2.02)]
def params(y):
 if y<=stations[0][0]:return stations[0][1:]
 for aa,bb in zip(stations,stations[1:]):
  if y<=bb[0]:
   t=(y-aa[0])/(bb[0]-aa[0]);return tuple(aa[j]*(1-t)+bb[j]*t for j in range(1,4))
 return stations[-1][1:]
source_uv={i:Vector((c[i].y,math.atan2(max(.001,c[i].z-1.85),c[i].x),0)) for fi in remove for i in faces[fi]}
source_patch=list(remove)
def target(y,theta):
 w,top,bottom=params(y);co=math.cos(theta);si=max(0,math.sin(theta));x=w*(1 if co>=0 else -1)*abs(co)**.85;z=bottom+(top-bottom)*si**.65
 # Eye socket placeholder is built into skin, below the cranial roof, without central roof elevation.
 eye=min(abs(theta-.78),abs(theta-(math.pi-.78)));depression=.045*math.exp(-((y-2.98)/.115)**2-(eye/.10)**2);x-=(1 if x>0 else -1)*depression
 result=Vector((x,y,z));q=Vector((y,theta,0))
 # Match the fixed oral/neck border through a continuous transition, rather than a sharp accordion edge.
 nearest=1e9
 for k in range(len(uv)):
  aa=uv[k];bb=uv[(k+1)%len(uv)];v=bb-aa;t=max(0,min(1,(q-aa).dot(v)/max(1e-10,v.length_squared)));nearest=min(nearest,(q-aa-v*t).length)
 fade=max(0,min(1,nearest/.23));fade=fade*fade*(3-2*fade)
 for fi in source_patch:
  tri=faces[fi];aa,bb,cc=[source_uv[i] for i in tri];den=(bb.y-cc.y)*(aa.x-cc.x)+(cc.x-bb.x)*(aa.y-cc.y)
  if abs(den)<1e-10:continue
  u=((bb.y-cc.y)*(q.x-cc.x)+(cc.x-bb.x)*(q.y-cc.y))/den;v=((cc.y-aa.y)*(q.x-cc.x)+(aa.x-cc.x)*(q.y-cc.y))/den;bw=(u,v,1-u-v)
  if min(bw)>=-1e-6:
   original=sum((c[i]*bw[j] for j,i in enumerate(tri)),Vector());result=original.lerp(result,fade);break
 return result
def bary2(q,tri):
 aa,bb,cc=[uvpoints[i] for i in tri];den=(bb.y-cc.y)*(aa.x-cc.x)+(cc.x-bb.x)*(aa.y-cc.y)
 if abs(den)<1e-10:return None
 u=((bb.y-cc.y)*(q.x-cc.x)+(cc.x-bb.x)*(q.y-cc.y))/den;v=((cc.y-aa.y)*(q.x-cc.x)+(aa.x-cc.x)*(q.y-cc.y))/den;return (u,v,1-u-v)
def insert(y,theta):
 q=Vector((y,theta,0));choices=[]
 for fi,tri in enumerate(tf):
  b=bary2(q,tri)
  if b and min(b)>.003:choices.append((min(b),fi,b))
 if not choices:return False
 _,fi,b=max(choices);tri=tf.pop(fi);idx=len(uvpoints);uvpoints.append(q);localworld.append(target(y,theta));localwt.append({'head':1.0});tf.extend([[tri[0],tri[1],idx],[tri[1],tri[2],idx],[tri[2],tri[0],idx]]);return True
for y in [2.47,2.60,2.75,2.90,3.05,3.20,3.35,3.50,3.63,3.72]:
 for theta in [.16,.38,.60,.82,1.04,1.28,1.57,1.86,2.10,2.32,2.54,2.76,2.98]:insert(y,theta)
for y in [2.91,2.98,3.05]:
 for theta in [.72,.78,.84,math.pi-.84,math.pi-.78,math.pi-.72]:insert(y,theta)
# Improve the independent chart triangulation by flipping interior edges; boundary constraints stay exact.
def orient(aa,bb,cc):return (bb.x-aa.x)*(cc.y-aa.y)-(bb.y-aa.y)*(cc.x-aa.x)
def angle(aa,bb,cc):
 v=aa-cc;w=bb-cc;return math.acos(max(-1,min(1,v.dot(w)/max(1e-12,v.length*w.length))))
scaled=[Vector((v.x/1.37,v.y/math.pi,0)) for v in uvpoints]
flipped=0
for iteration in range(3000):
 edgefaces=collections.defaultdict(list)
 for fi,tri in enumerate(tf):
  for aa,bb in zip(tri,tri[1:]+tri[:1]):edgefaces[tuple(sorted((aa,bb)))].append(fi)
 found=False
 for (aa,bb),fis in edgefaces.items():
  if len(fis)!=2:continue
  i,j=fis;cc=next(v for v in tf[i] if v not in [aa,bb]);dd=next(v for v in tf[j] if v not in [aa,bb]);A,B,C,D=[scaled[v] for v in [aa,bb,cc,dd]]
  if orient(A,B,C)*orient(A,B,D)>=-1e-12 or orient(C,D,A)*orient(C,D,B)>=-1e-12:continue
  if angle(A,B,C)+angle(A,B,D)>math.pi+1e-6:
   tf[i]=[cc,dd,aa];tf[j]=[dd,cc,bb];flipped+=1;found=True;break
 if not found:break
else:raise RuntimeError('chart flip did not converge')
# Fair the new skin's oral transition while keeping all source boundary points exact.
nb=collections.defaultdict(set)
for tri in tf:
 for aa,bb in zip(tri,tri[1:]+tri[:1]):nb[aa].add(bb);nb[bb].add(aa)
anchors=[v.copy() for v in localworld]
for iteration in range(14):
 updated=[v.copy() for v in localworld]
 for i in range(len(boundary),len(localworld)):
  mean=sum((localworld[j] for j in nb[i]),Vector())/len(nb[i]);alpha=.42 if localworld[i].z<2.35 else .16
  delta=(mean-localworld[i])*alpha;candidate=localworld[i]+delta;deviation=candidate-anchors[i]
  if deviation.length>.09:candidate=anchors[i]+deviation.normalized()*.09
  updated[i]=candidate
 localworld=updated
# Preserve source boundary coordinates; authored points are inverse-bound to unchanged source pose.
newids=list(boundary);added=[]
for j in range(len(boundary),len(localworld)):
 newids.append(len(world));added.append(len(world));world.append(localworld[j]);wt.append(localwt[j])
newfaces=[];newmats=[]
for tri in tf:
 f=[newids[j] for j in tri];p0,p1,p2=[world[i] for i in f];n=(p1-p0).cross(p2-p0);mid=(p0+p1+p2)/3;y=mid.y;_,top,bottom=params(y);outward=Vector((mid.x,0,max(.04,mid.z-bottom)))
 if orient(uvpoints[tri[0]],uvpoints[tri[1]],uvpoints[tri[2]])<0:f.reverse()
 newfaces.append(f);t=sum(uvpoints[j].y for j in tri)/3;eye=min(abs(t-.78),abs(t-(math.pi-.78)));newmats.append(13 if abs(y-2.98)<.055 and eye<.065 else 0)
removed_extras={fi for fi,f in enumerate(faces) if mats[fi] in [12,13] or (mats[fi] in [6,7,8] and sum(c[i].y for i in f)/len(f)>2.33 and max(wt[i].get('head',0) for i in f)>.3)};remove|=removed_extras
retained=[fi for fi in range(len(faces)) if fi not in remove];finalfaces=[faces[i] for i in retained]+newfaces;finalmats=[mats[i] for i in retained]+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) else bind(q,wt[i]) for i,q in enumerate(world)];me=bpy.data.meshes.new('01M3_Reconstructed_Cranial_Skin');me.from_pydata(rest,[],finalfaces);me.update()
used_mats=sorted(set(finalmats));material_remap={old:new for new,old in enumerate(used_mats)}
for mi in used_mats:me.materials.append(a.data.materials[mi])
for f,m in zip(me.polygons,finalmats):f.material_index=material_remap[m]
ob=a.copy();ob.data=me;ob.name='01M3_Concept_Head_Reconstruction';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
for i,w in enumerate(wt):
 for name,value in w.items():ob.vertex_groups[name].add([i],value,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((x-y).length for x,y in zip(actual,world));assert err<3e-5;assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)))
near=[]
for fi in range(len(retained),len(finalfaces)):
 f=finalfaces[fi];aa,bb,cc=[actual[i] for i in f]
 if (bb-aa).cross(cc-aa).length_squared<1e-12:near.append(fi)
assert not near
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01M3 conceptual grey blockout pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
rec={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in finalfaces),'removed_original_faces':len(remove),'reconstructed_skin_faces':len(newfaces),'added_vertices':len(added),'fixed_boundary_vertices':len(boundary),'material_index_remap':material_remap,'all_original_coords_weights_exact':True,'Rig_Trex_keys_pose_exact':True,'teeth_tongue_jaw_body_retained_exact':True,'inverse_bind_error':err,'new_faces_near_degenerate':near,'pipeline_check':'CHECK OK budget=None','chart_internal_edge_flips':flipped,'status':'pending_visual_review','eye_geometry':'recessed placement only; no finished eyeball','source_forehead_spikes':'removed within reconstructed head only; not replaced at blockout stage'};(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'removed_original_faces':sorted(remove),'retained_original_face_mapping':retained,'preserved_boundary':boundary,'added_vertices':added},indent=2));print(json.dumps(rec))
