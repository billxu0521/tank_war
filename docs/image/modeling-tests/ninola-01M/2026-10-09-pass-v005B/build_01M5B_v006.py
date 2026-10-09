import bpy,json,hashlib,math,ast,collections,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();out=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01M3/2026-10-09-v006/ninola_01M3_concept_head_reconstruction.blend';dest=r/'blender/ninola/working/01M5B/2026-10-09-v006/ninola_01M5B_face_mass_gaze.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M3_Concept_Head_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];world=[v.copy() for v in c];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];names=[m.name for m in a.data.materials];olive=names.index('d_olive');pupil=names.index('d_pupil');skin={i for f,m in zip(faces,mats) if m in [olive,pupil] and max(f)>=10444 for i in f if i>=10444};moved=set()
def gauss(v,center,width):return math.exp(-((v-center)/width)**2)
for i in skin:
 p=c[i];q=p.copy()
 # B: distribute nasal vault, lateral planes and rounded muzzle instead of scaling the whole head.
 front=gauss(p.y,3.68,.19);upper=max(0,min(1,(p.z-2.07)/.22))
 q.x*=1-.15*front*upper
 q.y+=.10*front*upper*max(0,1-(abs(p.x)/.29)**2)
 nose=gauss(p.y,3.37,.32)*gauss(p.x,0,.17)*gauss(p.z,2.46,.20);q.z+=.034*nose-.045*front*upper*gauss(p.x,0,.21)
 brow=gauss(p.y,3.02,.23)*gauss(abs(p.x),.31,.16)*gauss(p.z,2.50,.15)
 q.x+=(1 if p.x>0 else -1)*.052*brow;q.z+=.047*brow
 # Preorbital support transitions into cheek; not an isolated eyebrow strip.
 support=gauss(p.y,3.16,.16)*gauss(abs(p.x),.29,.16)*gauss(p.z,2.37,.15)
 q.x+=(1 if p.x>0 else -1)*.024*support
 if (q-p).length>1e-7:world[i]=q;moved.add(i)
# Clear coarse black placement triangles. Actual integrated eye patches replace them.
material_changed=[]
for fi,f in enumerate(faces):
 if mats[fi]==pupil and max(f)>=10444:mats[fi]=olive;material_changed.append(fi)
# M3's new connector is external skin at the anterior lip, not a change to original oral surfaces.
for fi,f in enumerate(faces):
 if fi>=6230 and names[mats[fi]]=='d_mouth':mats[fi]=names.index('d_tan');material_changed.append(fi)
pool=[fi for fi,f in enumerate(faces) if mats[fi]==olive and max(f)>=10444];removed=set();added=[];newfaces=[];newmats=[];eye_records=[]
allmats=list(a.data.materials);gold=bpy.data.materials.new('Ninola_Iris_Gold_M4');gold.diffuse_color=(.72,.39,.055,1);gold.use_nodes=True;bs=next(n for n in gold.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=gold.diffuse_color;bs.inputs['Roughness'].default_value=.78;allmats.append(gold);goldidx=len(allmats)-1
eye_dark=bpy.data.materials.new('Ninola_Eye_Dark_Bronze');eye_dark.diffuse_color=(.07,.055,.025,1);eye_dark.use_nodes=True;bs=next(n for n in eye_dark.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=eye_dark.diffuse_color;bs.inputs['Roughness'].default_value=.65;allmats.append(eye_dark);eyedarkidx=len(allmats)-1

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
 cy,cz=2.84,2.47
 selected={fi for fi in pool if all(world[i].x*sign>.12 for i in faces[fi]) and abs(sum(world[i].y for i in faces[fi])/3-cy)<.245 and abs(sum(world[i].z for i in faces[fi])/3-cz)<.16}
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
 N=Vector((sign*.65,.76,0)).normalized();U=Vector((.76,-sign*.65,0)).normalized();Z=Vector((0,0,1))
 spherecenter=Vector((surface(cy,cz,sign)-sign*.032,cy-.010,cz))
 radius=.049;opening=Vector((surface(cy,cz,sign),cy,cz))
 sy,sz=.070,.041
 removed.update(cluster)
 outer=sorted(loop,key=lambda i:math.atan2(world[i].z-opening.z,world[i].y-opening.y)%(2*math.pi))
 middle=[];inner=[]
 for oi in outer:
  source=world[oi];theta=math.atan2(source.z-opening.z,source.y-opening.y)
  y=opening.y+sy*math.cos(theta);z=opening.z+sz*math.sin(theta)
  x=surface(y,z,sign)+sign*(.020*max(0,math.sin(theta))-.006*max(0,-math.sin(theta)))
  end=Vector((x,y,z))
  # Two transitions indexed one-to-one with source boundary; no zipper fan/star topology.
  mid=source.lerp(end,.52);middle.append(add(mid));inner.append(add(end))
 for aa,bb in [(outer,middle),(middle,inner)]:
  for k in range(len(outer)):
   j=(k+1)%len(outer);emit([aa[k],aa[j],bb[j]],olive,sign);emit([aa[k],bb[j],bb[k]],olive,sign)
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
  mat=goldidx if row==0 else eyedarkidx
  for k in range(16):j=(k+1)%16;spherical_emit([aa[k],aa[j],bb[j]],mat);spherical_emit([aa[k],bb[j],bb[k]],mat)
 back=add(spherecenter-F*radius)
 for k in range(16):spherical_emit([lat[-1][k],lat[-1][(k+1)%16],back],eyedarkidx)
 eye_records.append({'side':sign,'source_patch_faces':sorted(cluster),'sphere_center':list(spherecenter),'sphere_radius':radius,'gaze_target':list(target),'gaze_axis':list(F),'opening_normal':list(N),'opening_radii':[sy,sz],'bone':'head'})
# Reintroduce low, rear-swept cranial spines, rooted in the current skull surface.
def roof(x,y):
 choices=[]
 for fi in pool:
  aa,bb,cc=[world[i] for i in faces[fi]];den=(bb.y-cc.y)*(aa.x-cc.x)+(cc.x-bb.x)*(aa.y-cc.y)
  if abs(den)<1e-10:continue
  u=((bb.y-cc.y)*(x-cc.x)+(cc.x-bb.x)*(y-cc.y))/den;v=((cc.y-aa.y)*(x-cc.x)+(aa.x-cc.x)*(y-cc.y))/den;bw=(u,v,1-u-v)
  if min(bw)>=-1e-5:choices.append(aa.z*u+bb.z*v+cc.z*(1-u-v))
 assert choices,(x,y)
 return max(choices)
spines=[]
for y,h,rx,ry in [(3.48,.065,.030,.055),(3.28,.085,.034,.060),(3.06,.105,.040,.065),(2.84,.125,.043,.075),(2.61,.145,.048,.078)]:
 for sign in [-1,1]:
  x=sign*(.065 if y>3.2 else .11);z=roof(x,y);ring=[]
  for k in range(5):
   t=k*2*math.pi/5;xx=x+rx*math.cos(t);yy=y+ry*math.sin(t);ring.append(add((xx,yy,roof(xx,yy)-.010)))
  apex=add((x+sign*.012,y-.065,z+h))
  for k in range(5):emit([ring[k],ring[(k+1)%5],apex],names.index('d_spike_lit') if k%2 else names.index('d_spike'))
  for k in range(1,4):emit([ring[0],ring[k+1],ring[k]],names.index('d_spike'))
  spines.append({'root':[x,y,z],'tip':list(world[apex]),'height':h,'bone':'head'})
for y,xabs,h in [(3.12,.24,.070),(2.88,.29,.100),(2.64,.32,.125)]:
 for sign in [-1,1]:
  x=sign*xabs;z=roof(x,y);ring=[]
  for k in range(5):
   t=k*2*math.pi/5;xx=x+.026*math.cos(t);yy=y+.050*math.sin(t);ring.append(add((xx,yy,roof(xx,yy)-.010)))
  apex=add((x+sign*.035,y-.055,z+h))
  for k in range(5):emit([ring[k],ring[(k+1)%5],apex],names.index('d_spike'))
  for k in range(1,4):emit([ring[0],ring[k+1],ring[k]],names.index('d_spike'))
  spines.append({'root':[x,y,z],'tip':list(world[apex]),'height':h,'bone':'head'})
retained=[i for i in range(len(faces)) if i not in removed];ff=[faces[i] for i in retained]+newfaces;mm=[mats[i] for i in retained]+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) and i not in moved else bind(q,wt[i]) for i,q in enumerate(world)];me=bpy.data.meshes.new('01M5B_Face_Mass_Gaze');me.from_pydata(rest,[],ff);me.update()
for mat in allmats:me.materials.append(mat)
for f,mi in zip(me.polygons,mm):f.material_index=mi
ob=a.copy();ob.data=me;ob.name='01M5B_Face_Mass_Gaze';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
for i,w in enumerate(wt):
 for n,v in w.items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((aa-bb).length for aa,bb in zip(actual,world));assert err<3e-5;assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)) if i not in moved)
near=[]
for fi in range(len(retained),len(ff)):
 aa,bb,cc=[actual[i] for i in ff[fi]]
 if (bb-aa).cross(cc-aa).length_squared<1e-12:near.append(fi)
assert not near,near
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01M5B identity candidate pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
rec={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in ff),'moved_source_vertices':len(moved),'added_vertices':len(added),'new_faces':len(newfaces),'removed_eye_patch_faces':len(removed),'spines':spines,'eyes':eye_records,'Rig_Trex_keys_pose_exact':True,'outside_mask_rest_coords_exact':True,'source_weights_exact':True,'new_faces_near_degenerate':near,'inverse_bind_error':err,'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review'};(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'moved_source_vertices':sorted(moved),'added_vertices':added,'removed_source_faces':sorted(removed),'retained_source_face_mapping':retained,'source_material_changed_faces':sorted(set(material_changed))},indent=2));print(json.dumps({k:v for k,v in rec.items() if k not in ['spines','eyes']}))
