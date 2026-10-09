import bpy,json,hashlib,ast,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.geometry import tessellate_polygon
r=Path.cwd();out=Path(__file__).resolve().parent;out.mkdir(exist_ok=True);src=r/'blender/ninola/working/01M3/2026-10-09-v006/ninola_01M3_concept_head_reconstruction.blend';dest=r/'blender/ninola/working/01M6/2026-10-09-v001/ninola_01M6_whole_cranial_blockout.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M3_Concept_Head_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];material_names=['d_olive','d_moss','d_tan','d_tailu','d_taild','d_belly','d_spike','d_spike_lit','d_ridge','d_bone','d_claw','d_mouth','d_eye','d_pupil'];material_bank=[bpy.data.materials[n] for n in material_names];mats=[material_names.index(a.data.materials[f.material_index].name) for f in a.data.polygons];key=lambda i:tuple(round(v,5) for v in c[i]);world=[v.copy() for v in c]
# Remove one complete cranial skin patch; keep exact neck and oral boundary, teeth, inner mouth, jaw and body.
remove=set(range(5999,len(faces)));boundary=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v003/refined-v006/edit_mask.json').read_text())['preserved_boundary']
uv=[Vector((c[i].y,math.atan2(max(.001,c[i].z-1.85),c[i].x),0)) for i in boundary]
# Triangulate the preserved boundary in a cylindrical chart, then insert an independent grid of control points.
tris=tessellate_polygon([uv]);uvlookup={tuple(v):i for i,v in enumerate(uv)};tf=[[v if isinstance(v,int) else uvlookup[tuple(v)] for v in tri] for tri in tris];assert len(tf)==len(uv)-2
localworld=[c[i].copy() for i in boundary];localwt=[dict(wt[i]) for i in boundary];uvpoints=[v.copy() for v in uv]
stations=[(2.35,.52,2.68,2.06),(2.65,.51,2.66,2.055),(2.92,.45,2.61,2.045),(3.20,.38,2.53,2.035),(3.46,.31,2.44,2.045),(3.65,.24,2.34,2.055),(3.75,.17,2.25,2.095)]
def params(y):
 if y<=stations[0][0]:return stations[0][1:]
 for aa,bb in zip(stations,stations[1:]):
  if y<=bb[0]:
   t=(y-aa[0])/(bb[0]-aa[0]);return tuple(aa[j]*(1-t)+bb[j]*t for j in range(1,4))
 return stations[-1][1:]
source_uv={i:Vector((c[i].y,math.atan2(max(.001,c[i].z-1.85),c[i].x),0)) for fi in remove for i in faces[fi]}
source_patch=list(remove)
# Reconstruct an exterior lip rim; retain the exact source mouth boundary as an inner connector.
outer_boundary=[]
for k,i in enumerate(boundary):
 old=c[i];y=old.y;q=old.copy();fade=max(0,min(1,(y-2.50)/.22));fade=fade*fade*(3-2*fade)
 w,top,bottom=params(y)
 if old.z<2.25 and fade>0:
  q.x=(1 if old.x>0 else -1)*w*.86;q.z=bottom
  q=old.lerp(q,fade)
 outer_boundary.append(q)
localworld[:len(boundary)]=outer_boundary

def target(y,theta):
 # Normalize each section to its actual fixed oral-border endpoints before reconstructing its arch.
 hits=[]
 for k in range(len(uv)):
  aa=uv[k];bb=uv[(k+1)%len(uv)]
  if min(aa.x,bb.x)<=y<=max(aa.x,bb.x) and abs(bb.x-aa.x)>1e-8:
   t=(y-aa.x)/(bb.x-aa.x);ang=aa.y+(bb.y-aa.y)*t;pos=outer_boundary[k].lerp(outer_boundary[(k+1)%len(boundary)],t);hits.append((ang,pos))
 if len(hits)<2:return None
 hits.sort(key=lambda q:q[0]);lo,R=hits[0];hi,L=hits[-1]
 if theta<=lo+.015 or theta>=hi-.015:return None
 t=max(0,min(1,(theta-lo)/(hi-lo)));angle=t*math.pi;si=max(0,math.sin(angle));co=math.cos(angle);width,top,bottom=params(y)
 # Piecewise broad structural planes: oral rim, cheek, brow, roof and nasal strip.
 h=top-bottom;profile=[(0,.87*width,bottom),(.15,width,bottom+.47*h),(.28,.85*width,top-.23*h),(.39,.47*width,top-.06*h),(.5,0,top)]
 tt=min(t,1-t)
 for A,B in zip(profile,profile[1:]):
  if A[0]<=tt<=B[0]:
   f=(tt-A[0])/(B[0]-A[0]);x=A[1]*(1-f)+B[1]*f;z=A[2]*(1-f)+B[2]*f;break
 x*=1 if t<=.5 else -1
 # The true oral interface is immutable; only its new external transition changes.
 endpoint=R.lerp(L,t);fade=min(1,tt/.10);fade=fade*fade*(3-2*fade)
 x=endpoint.x*(1-fade)+x*fade;z=endpoint.z*(1-fade)+z*fade
 yy=y+.025*si*max(0,min(1,(y-3.40)/.25))
 return Vector((x,yy,z))

def bary2(q,tri):
 aa,bb,cc=[uvpoints[i] for i in tri];den=(bb.y-cc.y)*(aa.x-cc.x)+(cc.x-bb.x)*(aa.y-cc.y)
 if abs(den)<1e-10:return None
 u=((bb.y-cc.y)*(q.x-cc.x)+(cc.x-bb.x)*(q.y-cc.y))/den;v=((cc.y-aa.y)*(q.x-cc.x)+(aa.x-cc.x)*(q.y-cc.y))/den;return (u,v,1-u-v)
def insert(y,theta):
 q=Vector((y,theta,0));authored=target(y,theta)
 if authored is None:return False
 choices=[]
 for fi,tri in enumerate(tf):
  b=bary2(q,tri)
  if b and min(b)>.003:choices.append((min(b),fi,b))
 if not choices:return False
 _,fi,b=max(choices);tri=tf.pop(fi);idx=len(uvpoints);uvpoints.append(q);localworld.append(authored);localwt.append({'head':1.0});tf.extend([[tri[0],tri[1],idx],[tri[1],tri[2],idx],[tri[2],tri[0],idx]]);return True
for y in [2.47,2.60,2.75,2.83,2.89,2.95,3.01,3.07,3.13,3.20,3.35,3.50,3.63,3.72]:
 for theta in [.16,.36,.52,.64,.73,.82,.91,1.00,1.12,1.30,1.57,1.84,2.02,2.14,2.23,2.32,2.41,2.50,2.62,2.78,2.98]:insert(y,theta)
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
# Preserve source boundary coordinates; authored points are inverse-bound to unchanged source pose.
newids=[];added=[]
for k,i in enumerate(boundary):
 if (localworld[k]-c[i]).length<1e-7:newids.append(i)
 else:newids.append(len(world));added.append(len(world));world.append(localworld[k]);wt.append(dict(wt[i]))
for j in range(len(boundary),len(localworld)):
 newids.append(len(world));added.append(len(world));world.append(localworld[j]);wt.append(localwt[j])
newfaces=[];newmats=[]
for tri in tf:
 f=[newids[j] for j in tri];p0,p1,p2=[world[i] for i in f];n=(p1-p0).cross(p2-p0);mid=(p0+p1+p2)/3;y=mid.y;_,top,bottom=params(y);outward=Vector((mid.x,0,max(.04,mid.z-bottom)))
 if orient(uvpoints[tri[0]],uvpoints[tri[1]],uvpoints[tri[2]])<0:f.reverse()
 newfaces.append(f);t=sum(uvpoints[j].y for j in tri)/3;eye=min(abs(t-.78),abs(t-(math.pi-.78)));newmats.append(0)
area=sum(uv[k].x*uv[(k+1)%len(uv)].y-uv[(k+1)%len(uv)].x*uv[k].y for k in range(len(uv)))
for k in range(len(boundary)):
 j=(k+1)%len(boundary)
 for f in [[boundary[k],boundary[j],newids[j]],[boundary[k],newids[j],newids[k]]]:
  if len(set(f))<3:continue
  if area<0:f.reverse()
  newfaces.append(f);newmats.append(2)
removed_extras={fi for fi,f in enumerate(faces) if mats[fi] in [12,13] or (mats[fi] in [6,7,8] and sum(c[i].y for i in f)/len(f)>2.33 and max(wt[i].get('head',0) for i in f)>.3)};remove|=removed_extras
retained=[fi for fi in range(len(faces)) if fi not in remove];finalfaces=[faces[i] for i in retained]+newfaces;finalmats=[mats[i] for i in retained]+newmats

retained=[fi for fi in range(len(faces)) if fi not in remove]
faces=[faces[i] for i in retained]+newfaces;mats=[mats[i] for i in retained]+newmats
names=material_names;olive=0;pupil=13
pool=list(range(len(retained),len(faces)));removed=set();added_shell=list(added);newfaces=[];newmats=[];eye_records=[]
allmats=list(material_bank);gold=bpy.data.materials.new('Ninola_Iris_Gold_M6');gold.diffuse_color=(.72,.39,.055,1);gold.use_nodes=True;bs=next(n for n in gold.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=gold.diffuse_color;bs.inputs['Roughness'].default_value=.78;allmats.append(gold);goldidx=len(allmats)-1

def add(p,w=None):i=len(world);world.append(Vector(p));wt.append(w or {'head':1.0});added.append(i);return i
def emit(f,m,sign=None):
 if sign is not None:
  aa,bb,cc=[world[i] for i in f]
  if (bb-aa).cross(cc-aa).x*sign<0:f.reverse()
 newfaces.append(f);newmats.append(m)
def bary_yz(y,z,f):
 aa,bb,cc=[world[i] for i in f];den=(bb.z-cc.z)*(aa.y-cc.y)+(cc.y-bb.y)*(aa.z-cc.z)
 if abs(den)<1e-10:return None
 u=((bb.z-cc.z)*(y-cc.y)+(cc.y-bb.y)*(z-cc.z))/den;v=((cc.z-aa.z)*(y-cc.y)+(aa.y-cc.y)*(z-cc.z))/den;return (u,v,1-u-v)
def surface(y,z,sign):
 choices=[]
 for fi in pool:
  f=faces[fi]
  if not all(world[i].x*sign>.12 for i in f):continue
  b=bary_yz(y,z,f)
  if b and min(b)>=-1e-5:choices.append(sum(world[i].x*b[j] for j,i in enumerate(f)))
 assert choices,(y,z,sign)
 return max(choices,key=lambda x:x*sign)
for sign in [-1,1]:
 cy,cz=2.98,2.435
 selected={fi for fi in pool if all(world[i].x*sign>.12 for i in faces[fi]) and abs(sum(world[i].y for i in faces[fi])/3-cy)<.105 and abs(sum(world[i].z for i in faces[fi])/3-cz)<.090}
 # Find connected patch around the eye center, expand boundary if necessary.
 chosen=[]
 for fi in selected:
  b=bary_yz(cy,cz,faces[fi])
  if b and min(b)>-1e-5:chosen.append(fi)
 assert chosen;seed=chosen[0];edgefaces=collections.defaultdict(set)
 for fi in selected:
  f=faces[fi]
  for aa,bb in zip(f,f[1:]+f[:1]):edgefaces[tuple(sorted((aa,bb)))].add(fi)
 cluster={seed};stack=[seed]
 while stack:
  fi=stack.pop();f=faces[fi]
  for aa,bb in zip(f,f[1:]+f[:1]):
   for fj in edgefaces[tuple(sorted((aa,bb)))]:
    if fj not in cluster:cluster.add(fj);stack.append(fj)
 edges=collections.Counter()
 for fi in cluster:
  f=faces[fi]
  for aa,bb in zip(f,f[1:]+f[:1]):edges[tuple(sorted((aa,bb)))]+=1
 adj=collections.defaultdict(set)
 for (aa,bb),n in edges.items():
  if n==1:adj[aa].add(bb);adj[bb].add(aa)
 assert all(len(v)==2 for v in adj.values());start=min(adj);loop=[start];prev=None;cur=start
 while True:
  nxt=next(i for i in sorted(adj[cur]) if i!=prev)
  if nxt==start:break
  loop.append(nxt);prev,cur=cur,nxt
 assert len(loop)==len(adj)
 def inside(y,z):
  hit=False
  for k in range(len(loop)):
   aa=world[loop[k]];bb=world[loop[(k+1)%len(loop)]]
   if (aa.z>z)!=(bb.z>z) and y<(bb.y-aa.y)*(z-aa.z)/(bb.z-aa.z)+aa.y:hit=not hit
  return hit
 N=Vector((sign*.56,.8285,0)).normalized();U=Vector((.8285,-sign*.56,0)).normalized();Z=Vector((0,0,1))
 spherecenter=Vector((surface(cy,cz,sign)-sign*.032,cy-.025,cz))
 radius=.055;opening=spherecenter+N*.043
 sy,sz=.066,.043
 rings=[]
 for scale,depth in [(1.28,.012),(1.0,0)]:
  ring=[]
  for k in range(16):
   t=k*2*math.pi/16
   hood=.010*max(0,math.sin(t)) if scale>1 else .005*max(0,math.sin(t))
   pt=opening+U*(sy*scale*math.cos(t))+Z*(sz*scale*math.sin(t))+N*(depth+hood)
   ring.append(add(pt))
  rings.append(ring)
 removed.update(cluster)
 # Angular zipper annulus. Original patch boundary points stay exact.
 outer=sorted(loop,key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi));angles=[math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi) for i in outer];no=len(outer);co=outer[-1];ci=rings[0][0];oi=0;ii=1
 # Ring index angle is not YZ polar after tilt: order it geometrically for zipper.
 inner=sorted(rings[0],key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi));ia=[math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi) for i in inner];ci=inner[-1];ii=0
 for k in range(no+16):
  ao=angles[oi%no]+2*math.pi*(oi//no);ai=ia[ii%16]+2*math.pi*(ii//16)
  if ao<ai:emit([co,outer[oi%no],ci],olive,sign);co=outer[oi%no];oi+=1
  else:emit([co,inner[ii%16],ci],olive,sign);ci=inner[ii%16];ii+=1
 for aa,bb in zip(rings,rings[1:]):
  for k in range(16):j=(k+1)%16;emit([aa[k],aa[j],bb[j]],olive,sign);emit([aa[k],bb[j],bb[k]],olive,sign)
 # Low-poly sphere with circular iris/pupil caps along a shared far-front gaze axis.
 target=Vector((0,10.55,cz));F=(target-spherecenter).normalized();EU=Vector((1,0,0));EU=(EU-F*EU.dot(F)).normalized();EV=F.cross(EU).normalized()
 tip=add(spherecenter+F*radius);lat=[];thetas=[.16,.43,.72,1.05,1.4,1.8,2.25,2.7]
 for theta in thetas:
  ring=[]
  for k in range(16):
   phi=k*2*math.pi/16;ring.append(add(spherecenter+radius*(F*math.cos(theta)+(EU*math.cos(phi)+EV*math.sin(phi))*math.sin(theta))))
  lat.append(ring)
 def spherical_emit(f,mat):
  aa,bb,cc=[world[i] for i in f];normal=(bb-aa).cross(cc-aa);mid=(aa+bb+cc)/3
  if normal.dot(mid-spherecenter)<0:f.reverse()
  emit(f,mat)
 for k in range(16):spherical_emit([tip,lat[0][k],lat[0][(k+1)%16]],pupil)
 for row,(aa,bb) in enumerate(zip(lat,lat[1:])):
  mat=goldidx if row==0 else pupil
  for k in range(16):j=(k+1)%16;spherical_emit([aa[k],aa[j],bb[j]],mat);spherical_emit([aa[k],bb[j],bb[k]],mat)
 back=add(spherecenter-F*radius)
 for k in range(16):spherical_emit([lat[-1][k],lat[-1][(k+1)%16],back],pupil)
 eye_records.append({'side':sign,'source_patch_faces':sorted(cluster),'sphere_center':list(spherecenter),'sphere_radius':radius,'gaze_target':list(target),'gaze_axis':list(F),'opening_normal':list(N),'opening_radii':[sy,sz],'bone':'head'})
retained=[i for i in range(len(faces)) if i not in removed];ff=[faces[i] for i in retained]+newfaces;mm=[mats[i] for i in retained]+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) else bind(q,wt[i]) for i,q in enumerate(world)];me=bpy.data.meshes.new('01M6_Whole_Cranial_Blockout');me.from_pydata(rest,[],ff);me.update()
used=sorted(set(mm));remap={old:new for new,old in enumerate(used)}
for mi in used:me.materials.append(allmats[mi])
for f,mi in zip(me.polygons,mm):f.material_index=remap[mi]
ob=a.copy();ob.data=me;ob.name='01M6_Whole_Cranial_Blockout';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
for i,w in enumerate(wt):
 for n,v in w.items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((aa-bb).length for aa,bb in zip(actual,world));assert err<3e-5;assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)) )
near=[]
for fi in range(len(retained),len(ff)):
 aa,bb,cc=[actual[i] for i in ff[fi]]
 if (bb-aa).cross(cc-aa).length_squared<1e-12:near.append(fi)
assert not near,near
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01M6 whole cranial trial; pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
rec={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in ff),'moved_source_vertices':0,'added_vertices':len(added),'new_faces':len(newfaces),'removed_eye_patch_faces':len(removed),'spines':[],'eyes':eye_records,'Rig_Trex_keys_pose_exact':True,'outside_mask_rest_coords_exact':True,'source_weights_exact':True,'new_faces_near_degenerate':near,'inverse_bind_error':err,'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review'};(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'moved_source_vertices':[],'added_vertices':added,'removed_local_shell_faces':sorted(removed),'removed_original_faces':sorted(remove),'preserved_boundary':boundary,'retained_source_face_mapping':retained,'source_material_changed_faces':[]},indent=2));print(json.dumps({k:v for k,v in rec.items() if k not in ['spines','eyes']}))
