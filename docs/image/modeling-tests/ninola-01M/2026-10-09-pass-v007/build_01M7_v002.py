import bpy,json,hashlib,ast,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.geometry import tessellate_polygon
r=Path.cwd();out=Path(__file__).resolve().parent/'refined-v002';out.mkdir(exist_ok=True);src=r/'blender/ninola/working/01M3/2026-10-09-v006/ninola_01M3_concept_head_reconstruction.blend';dest=r/'blender/ninola/working/01M7/2026-10-09-v002/ninola_01M7_whole_cranial_blockout.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M3_Concept_Head_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];material_names=['d_olive','d_moss','d_tan','d_tailu','d_taild','d_belly','d_spike','d_spike_lit','d_ridge','d_bone','d_claw','d_mouth','d_eye','d_pupil'];material_bank=[bpy.data.materials[n] for n in material_names];mats=[material_names.index(a.data.materials[f.material_index].name) for f in a.data.polygons];key=lambda i:tuple(round(v,5) for v in c[i]);world=[v.copy() for v in c]
# Remove one complete cranial skin patch; keep exact neck and oral boundary, teeth, inner mouth, jaw and body.
remove=set(range(5999,len(faces)));boundary=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v003/refined-v006/edit_mask.json').read_text())['preserved_boundary']
# A true longitudinal section mesh, not an inserted triangle chart.
stations=[(2.35,.52,2.72,2.055),(2.65,.51,2.72,2.05),(2.92,.45,2.66,2.03),(3.20,.39,2.55,2.01),(3.46,.32,2.46,1.99),(3.65,.25,2.36,1.97),(3.75,.20,2.29,1.95)]
def params(y):
 if y<=stations[0][0]:return stations[0][1:]
 for aa,bb in zip(stations,stations[1:]):
  if y<=bb[0]:
   t=(y-aa[0])/(bb[0]-aa[0]);return tuple(aa[j]*(1-t)+bb[j]*t for j in range(1,4))
 return stations[-1][1:]
def target(y,t):
 w,top,b=params(y);h=top-b
 # Coarse structural cross-sections: brow canopy, orbital recess and cheek support.
 controls=[(2.49,0),(2.65,.6),(2.80,1),(3.04,1),(3.20,0)]
 strength=0
 for A,B in zip(controls,controls[1:]):
  if A[0]<=y<=B[0]:f=(y-A[0])/(B[0]-A[0]);strength=A[1]*(1-f)+B[1]*f;break
 profile=[(0,.87*w,b),(.15,w*(1-.04*strength),b+.47*h),(.205,w*(.936-.050*strength),b+.615*h),(.28,w*(.85+.09*strength),top-.20*h),(.39,.47*w,top-.06*h),(.5,0,top)]
 tt=min(t,1-t)
 for A,B in zip(profile,profile[1:]):
  if A[0]<=tt<=B[0]:
   f=(tt-A[0])/(B[0]-A[0]);x=A[1]*(1-f)+B[1]*f;z=A[2]*(1-f)+B[2]*f;break
 return Vector((x*(1 if t<=.5 else -1),y+.035*math.sin(math.pi*t)*max(0,min(1,(y-3.60)/.15)),z))
ys=[2.49,2.65,2.80,2.88,2.96,3.04,3.12,3.20,3.35,3.50,3.65,3.75]
ts=[0,.075,.15,.205,.26,.33,.40,.50,.60,.67,.74,.795,.85,.925,1]
added=[];grid=[];newfaces=[];newmats=[]
for ri,y in enumerate(ys):
 row=[]
 for t in ts:
  q=target(y,t);idx=len(world);world.append(q);added.append(idx);row.append(idx)
  if ri==0:
   near=min(boundary,key=lambda i:(c[i]-q).length);w={n:v*.35 for n,v in wt[near].items()};w['head']=w.get('head',0)+.65
  else:w={'head':1.0}
  wt.append(w)
 grid.append(row)
def shell_emit(f,m=0):
 aa,bb,cc=[world[i] for i in f];mid=(aa+bb+cc)/3
 if (bb-aa).cross(cc-aa).dot(Vector((mid.x,0,mid.z-2.04)))<0:f.reverse()
 newfaces.append(f);newmats.append(m)
for ra,rb in zip(grid,grid[1:]):
 for j in range(len(ts)-1):
  A,B,C,D=ra[j],rb[j],rb[j+1],ra[j+1]
  if (world[A]-world[C]).length<(world[B]-world[D]).length:shell_emit([A,B,C]);shell_emit([A,C,D])
  else:shell_emit([A,B,D]);shell_emit([B,C,D])
# Continuous exterior perimeter, joined once to the immutable legacy oral/neck border.
perimeter=grid[0]+[row[-1] for row in grid[1:]]+list(reversed(grid[-1][:-1]))+[row[0] for row in reversed(grid[1:-1])]
def angle(i):
 v=world[i];theta=math.atan2(max(.001,v.z-1.85),v.x)
 return math.atan2((theta-math.pi/2)/math.pi,(v.y-3.10)/1.30)%(2*math.pi)
outer_rim=[]
for i in boundary:
 q=c[i].copy();w,top,b=params(q.y);fade=max(0,min(1,(q.y-2.50)/.22));fade=fade*fade*(3-2*fade)
 if q.z<2.25 and fade>0:
  x=(1 if q.x>0 else -1)*.87*w
  if q.y>3.60 and abs(q.x)<.13:x=q.x*.87
  goal=Vector((x,q.y,b));q=q.lerp(goal,fade)
 if (q-c[i]).length>1e-7:
  idx=len(world);world.append(q);wt.append(dict(wt[i]));added.append(idx)
 else:idx=i
 outer_rim.append(idx)
for k in range(len(boundary)):
 j=(k+1)%len(boundary)
 for f in [[boundary[k],boundary[j],outer_rim[j]],[boundary[k],outer_rim[j],outer_rim[k]]]:
  if len(set(f))<3:continue
  aa,bb,cc=[world[v] for v in f]
  if (bb-aa).cross(cc-aa).length_squared<1e-12:continue
  newfaces.append(f);newmats.append(2)
outer=sorted(outer_rim,key=angle);inner=sorted(perimeter,key=angle);no,ni=len(outer),len(inner);oi=ii=0;co=outer[-1];ci=inner[-1]
for k in range(no+ni):
 ao=angle(outer[oi%no])+2*math.pi*(oi//no);ai=angle(inner[ii%ni])+2*math.pi*(ii//ni)
 if ao<ai:f=[co,outer[oi%no],ci];co=outer[oi%no];oi+=1
 else:f=[co,inner[ii%ni],ci];ci=inner[ii%ni];ii+=1
 aa,bb,cc=[world[i] for i in f];mid=(aa+bb+cc)/3;normal=(bb-aa).cross(cc-aa)
 # The forward nose transition faces forward; side/neck transition uses lateral/roof orientation.
 direction=Vector((mid.x,max(0,(mid.y-3.55)*4),mid.z-2.04))
 if normal.dot(direction)<0:f.reverse()
 newfaces.append(f);newmats.append(2 if mid.z<2.10 else 0)
removed_extras={fi for fi,f in enumerate(faces) if fi>=5999 and mats[fi] in [12,13] or (mats[fi] in [6,7,8] and sum(c[i].y for i in f)/len(f)>2.33 and max(wt[i].get('head',0) for i in f)>.3)};remove|=removed_extras
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
 selected={fi for fi in pool if all(world[i].x*sign>.12 for i in faces[fi]) and abs(sum(world[i].y for i in faces[fi])/3-cy)<.105 and abs(sum(world[i].z for i in faces[fi])/3-cz)<.075}
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
 spherecenter=Vector((surface(cy,cz,sign)-sign*.042,cy,cz))
 radius=.054;opening=spherecenter+N*.043
 sy,sz=.066,.043
 rings=[]
 for scale,depth in [(1.28,.012),(1.0,0)]:
  ring=[]
  for k in range(12):
   t=k*2*math.pi/12
   hood=.010*max(0,math.sin(t)) if scale>1 else .005*max(0,math.sin(t))
   yy=cy+sy*scale*math.cos(t);zz=cz+sz*scale*math.sin(t);xx=surface(yy,zz,sign);pt=Vector((xx+sign*(.006*max(0,math.sin(t)) if scale>1 else -.009),yy,zz))
   ring.append(add(pt))
  rings.append(ring)
 removed.update(cluster)
 # Angular zipper annulus. Original patch boundary points stay exact.
 outer=sorted(loop,key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi));angles=[math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi) for i in outer];no=len(outer);co=outer[-1];ci=rings[0][0];oi=0;ii=1
 # Ring index angle is not YZ polar after tilt: order it geometrically for zipper.
 inner=sorted(rings[0],key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi));ia=[math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi) for i in inner];ci=inner[-1];ii=0
 for k in range(no+12):
  ao=angles[oi%no]+2*math.pi*(oi//no);ai=ia[ii%12]+2*math.pi*(ii//12)
  if ao<ai:emit([co,outer[oi%no],ci],olive,sign);co=outer[oi%no];oi+=1
  else:emit([co,inner[ii%12],ci],olive,sign);ci=inner[ii%12];ii+=1
 for aa,bb in zip(rings,rings[1:]):
  for k in range(12):j=(k+1)%12;emit([aa[k],aa[j],bb[j]],olive,sign);emit([aa[k],bb[j],bb[k]],olive,sign)
 # Low-poly sphere with circular iris/pupil caps along a shared far-front gaze axis.
 target=Vector((0,10.55,cz));F=(target-spherecenter).normalized();EU=Vector((1,0,0));EU=(EU-F*EU.dot(F)).normalized();EV=F.cross(EU).normalized()
 tip=add(spherecenter+F*radius);lat=[];thetas=[.16,.43,.85,1.4,2.15,2.7]
 for theta in thetas:
  ring=[]
  for k in range(12):
   phi=k*2*math.pi/12;ring.append(add(spherecenter+radius*(F*math.cos(theta)+(EU*math.cos(phi)+EV*math.sin(phi))*math.sin(theta))))
  lat.append(ring)
 def spherical_emit(f,mat):
  aa,bb,cc=[world[i] for i in f];normal=(bb-aa).cross(cc-aa);mid=(aa+bb+cc)/3
  if normal.dot(mid-spherecenter)<0:f.reverse()
  emit(f,mat)
 for k in range(12):spherical_emit([tip,lat[0][k],lat[0][(k+1)%12]],pupil)
 for row,(aa,bb) in enumerate(zip(lat,lat[1:])):
  mat=goldidx if row==0 else pupil
  for k in range(12):j=(k+1)%12;spherical_emit([aa[k],aa[j],bb[j]],mat);spherical_emit([aa[k],bb[j],bb[k]],mat)
 back=add(spherecenter-F*radius)
 for k in range(12):spherical_emit([lat[-1][k],lat[-1][(k+1)%12],back],pupil)
 eye_records.append({'side':sign,'source_patch_faces':sorted(cluster),'sphere_center':list(spherecenter),'sphere_radius':radius,'gaze_target':list(target),'gaze_axis':list(F),'opening_normal':list(N),'opening_radii':[sy,sz],'bone':'head'})
retained=[i for i in range(len(faces)) if i not in removed];ff=[faces[i] for i in retained]+newfaces;mm=[mats[i] for i in retained]+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) else bind(q,wt[i]) for i,q in enumerate(world)];me=bpy.data.meshes.new('01M7_Whole_Cranial_Blockout');me.from_pydata(rest,[],ff);me.update()
used=sorted(set(mm));remap={old:new for new,old in enumerate(used)}
for mi in used:me.materials.append(allmats[mi])
for f,mi in zip(me.polygons,mm):f.material_index=remap[mi]
ob=a.copy();ob.data=me;ob.name='01M7_Whole_Cranial_Blockout';bpy.context.scene.collection.objects.link(ob)
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
bpy.context.view_layer.objects.active=ob;ob['status']='01M7 whole cranial trial; pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
rec={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in ff),'moved_source_vertices':0,'added_vertices':len(added),'new_faces':len(newfaces),'removed_eye_patch_faces':len(removed),'spines':[],'eyes':eye_records,'Rig_Trex_keys_pose_exact':True,'outside_mask_rest_coords_exact':True,'source_weights_exact':True,'construction':'coarse nasal wedge, orbital canopy/recess, cheek and posterior skull sections; no fine detailing','discussion_anchor':'01M6 v004','scope':'structural direction, not weekend production integration','new_faces_near_degenerate':near,'inverse_bind_error':err,'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review'};(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'moved_source_vertices':[],'added_vertices':added,'removed_local_shell_faces':sorted(removed),'removed_original_faces':sorted(remove),'preserved_boundary':boundary,'retained_source_face_mapping':retained,'source_material_changed_faces':[]},indent=2));print(json.dumps({k:v for k,v in rec.items() if k not in ['spines','eyes']}))
