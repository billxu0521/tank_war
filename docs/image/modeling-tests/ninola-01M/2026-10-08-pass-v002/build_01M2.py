import bpy,json,math,hashlib,ast,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();out=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01M1/2026-10-08-v002/ninola_01M1_jaw_mass_blockout.blend';dest=r/'blender/ninola/working/01M2/2026-10-08-v001/ninola_01M2_head_identity_blockout.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M1_Lower_Jaw_Mass_Blockout'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];world=[v.copy() for v in c];changed=set()
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def gauss(v,center,width):return math.exp(-((v-center)/width)**2)
# Teeth, tongue/inner-mouth and non-head regions remain exact. Exterior duplicates share a deformation field.
skin={i for f,m in zip(faces,mats) if m in [0,1,2,5,6,7,8] for i in f if wt[i].get('head',0)>.40 or wt[i].get('jaw',0)>.99};protect={i for f,m in zip(faces,mats) if m in [9,10,11] for i in f};skin-=protect
for i in sorted(skin):
 p=c[i];q=p.copy();h=wt[i].get('head',0);j=wt[i].get('jaw',0)
 if h>.40 and p.y>2.30:
  fade=smooth((p.y-2.30)/.42)*smooth((p.z-1.98)/.29)*smooth((h-.4)/.4)
  rear=gauss(p.y,2.76,.42);brow=gauss(p.y,3.01,.25);front=gauss(p.y,3.47,.35)
  q.x*=1+fade*(.18*rear+.08*front)
  q.z+=fade*(.12*rear+.12*brow+.075*front)
  # Raised brows on existing cranial skin, with a trough immediately behind them.
  q.x+=(1 if p.x>0 else -1)*.045*brow*gauss(p.z,2.60,.18)*smooth((abs(p.x)-.15)/.18)*fade
  q.z-=.035*gauss(p.y,3.55,.20)*gauss(p.z,2.42,.14)*fade
 if j>.99 and p.z<1.80:
  depth=smooth((1.80-p.z)/.32);rear=gauss(p.y,2.28,.35)
  q.x*=1+depth*(.08+.05*rear)
  q.z-=depth*(.035+.040*rear)
 if (q-p).length>1e-7:world[i]=q;changed.add(i)
# Replace original convex eyes and insert actual recessed socket patches into containing skull triangles.
removed_eye={fi for fi,m in enumerate(mats) if m in [12,13]};removed=set(removed_eye);newfaces=[];newmats=[];added=[];socket_records=[]
def add(p,w):idx=len(world);world.append(Vector(p));wt.append(dict(w));added.append(idx);return idx
def emit(f,m,sign):
 pts=[world[i] for i in f];normal=(pts[1]-pts[0]).cross(pts[2]-pts[0]);
 if normal.x*sign<0:f=list(reversed(f))
 newfaces.append(f);newmats.append(m)
def bary(y,z,fi,coords=None):
 coords=world if coords is None else coords
 aa,bb,cc=[coords[i] for i in faces[fi]];den=(bb.z-cc.z)*(aa.y-cc.y)+(cc.y-bb.y)*(aa.z-cc.z)
 if abs(den)<1e-9:return None
 u=((bb.z-cc.z)*(y-cc.y)+(cc.y-bb.y)*(z-cc.z))/den;v=((cc.z-aa.z)*(y-cc.y)+(aa.y-cc.y)*(z-cc.z))/den;return (u,v,1-u-v)
for sign in [-1,1]:
 cy,cz=2.98,2.43
 choices=[]
 for fi,f in enumerate(faces):
  if len(f)!=3 or mats[fi] not in [0,1,2,5] or not all(world[i].x*sign>.15 and wt[i].get('head',0)>.5 for i in f):continue
  b=bary(cy,cz,fi,c)
  if b and min(b)>0:choices.append((min(b),fi,b))
 assert choices;_,fi,b=max(choices);f=faces[fi];removed.add(fi)
 cy=sum(world[i].y*b[j] for j,i in enumerate(f));cz=sum(world[i].z*b[j] for j,i in enumerate(f))
 boundary=list(f)
 if min(b)<.12:
  opposite=min(range(3),key=lambda k:b[k]);edge=[f[k] for k in range(3) if k!=opposite];key=lambda idx:tuple(round(v,5) for v in c[idx]);edgekeys={key(i) for i in edge}
  neighbors=[(fj,ff) for fj,ff in enumerate(faces) if fj!=fi and mats[fj] in [0,1,2,5] and edgekeys.issubset({key(i) for i in ff})]
  assert neighbors
  fj,ff=neighbors[0];removed.add(fj);boundary.extend(i for i in ff if key(i) not in {key(k) for k in boundary})
 boundary.sort(key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi))
 def inside(y,z):
  count=False
  for k in range(len(boundary)):
   aa=world[boundary[k]];bb=world[boundary[(k+1)%len(boundary)]]
   if ((aa.z>z)!=(bb.z>z)) and y<(bb.y-aa.y)*(z-aa.z)/(bb.z-aa.z)+aa.y:count=not count
  return count
 def surface(y,z):
  bw=bary(y,z,fi);return sum(world[i].x*bw[j] for j,i in enumerate(f))
 # Largest ellipse fully inside original triangular face; exact original boundary retained.
 sy,sz=.108,.070
 for attempt in range(20):
  if all(inside(cy+sy*math.cos(t*2*math.pi/12),cz+sz*math.sin(t*2*math.pi/12)) for t in range(12)):break
  sy*=.9;sz*=.9
 assert sy>.045,(sign,sy,sz)
 rings=[]
 for radius,offset in [(1.0,.015),(.72,.025),(.53,-.040)]:
  ring=[]
  for k in range(12):
   angle=2*math.pi*k/12;y=cy+sy*radius*math.cos(angle);z=cz+sz*radius*math.sin(angle)
   # The upper lid has greater projection, creating true overhang above recessed opening.
   extra=.016*max(0,math.sin(angle)) if radius==.72 else 0
   ring.append(add((surface(y,z)+sign*(offset+extra),y,z),{'head':1.0}))
  rings.append(ring)
 # Zipper triangulation between original triangle and outer socket loop, no boundary subdivisions/T-junctions.
 outer=sorted(boundary,key=lambda i:math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi));inner=rings[0];angles_o=[math.atan2(world[i].z-cz,world[i].y-cy)%(2*math.pi) for i in outer];oi=0;ii=0
 # Pick latest outer angle preceding inner angle zero, then advance in polar order.
 no=len(outer);oi=no-1;ai=angles_o[oi]-2*math.pi;cur_o=outer[oi];cur_i=inner[0];next_o=0;next_i=1
 for _ in range(no+12):
  ao=angles_o[next_o%no]+2*math.pi*(next_o//no);an=(next_i/12)*2*math.pi
  if ao<an:emit([cur_o,outer[next_o%no],cur_i],mats[fi],sign);cur_o=outer[next_o%no];next_o+=1
  else:emit([cur_o,inner[next_i%12],cur_i],mats[fi],sign);cur_i=inner[next_i%12];next_i+=1
 for ring0,ring1 in zip(rings,rings[1:]):
  for k in range(12):emit([ring0[k],ring0[(k+1)%12],ring1[(k+1)%12]],0,sign);emit([ring0[k],ring1[(k+1)%12],ring1[k]],0,sign)
 # Dark socket floor, small gold iris and vertical pupil follow existing head bone; no additional bone.
 center=add((surface(cy,cz)-sign*.050,cy,cz),{'head':1.0})
 for k in range(12):emit([rings[-1][k],rings[-1][(k+1)%12],center],13,sign)
 iris=[]
 for k in range(12):
  t=k*2*math.pi/12;yy=cy+sy*.46*math.cos(t);zz=cz+sz*.36*math.sin(t);iris.append(add((surface(yy,zz)-sign*.025,yy,zz),{'head':1.0}))
 ic=add((surface(cy,cz)-sign*.010,cy,cz),{'head':1.0})
 for k in range(12):emit([iris[k],iris[(k+1)%12],ic],12,sign)
 pup=[add((surface(cy+dy,cz+dz)-sign*.006,cy+dy,cz+dz),{'head':1.0}) for dy,dz in [(-.007,-sz*.29),(.007,-sz*.29),(.008,sz*.29),(-.008,sz*.29)]];emit([pup[0],pup[1],pup[2]],13,sign);emit([pup[0],pup[2],pup[3]],13,sign)
 socket_records.append({'side':sign,'replaced_source_face':fi,'center_yz':[cy,cz],'radius_yz':[sy,sz],'weight':'head 1.0','actual_recess_depth':.050})
finalfaces=[f for fi,f in enumerate(faces) if fi not in removed]+newfaces;finalmats=[m for fi,m in enumerate(mats) if fi not in removed]+newmats
# Convert authored evaluated-world geometry back to rest coordinates under unchanged source pose.
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 eff=rig.matrix_world@m@rig.matrix_world.inverted();return a.matrix_world.inverted()@eff.inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) and i not in changed else bind(q,wt[i]) for i,q in enumerate(world)]
me=bpy.data.meshes.new('01M2_Head_Identity_Blockout');me.from_pydata(rest,[],finalfaces);me.update()
for mat in a.data.materials:me.materials.append(mat)
for fi,m in enumerate(finalmats):me.polygons[fi].material_index=m
ob=a.copy();ob.data=me;ob.name='01M2_Head_Identity_Blockout';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
for i in range(len(c),len(world)):
 for n,v in wt[i].items():ob.vertex_groups[n].add([i],v,'REPLACE')
# copy original vertex weights: object.copy groups exist but mesh replacement requires membership assignment.
for i in range(len(c)):
 for n,v in wt[i].items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((q-v).length for q,v in zip(actual,world));assert err<3e-5,err
assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)) if i not in changed)
assert all(actual[i]==c[i] for i in protect if i not in changed) or max((actual[i]-c[i]).length for i in protect)<1e-6
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
ob['status']='01M2 prototype pending user visual review';ob['source_sha256']=basehash
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
record={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'original_vertices':len(c),'vertices':len(world),'triangles':sum(len(f)-2 for f in finalfaces),'changed_original_vertices':len(changed),'added_vertices':len(added),'removed_eye_faces':len(removed_eye),'socket_records':socket_records,'inverse_bind_error':err,'Rig_Trex_keys_pose_exact':True,'outside_mask_rest_coords_exact':True,'teeth_tongue_inner_mouth_exact':True,'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review'}
(out/'edit_mask.json').write_text(json.dumps({'changed_original_vertices':sorted(changed),'added_vertices':added,'removed_source_faces':sorted(removed),'added_faces_start':len(finalfaces)-len(newfaces),'original_face_mapping':[i for i in range(len(faces)) if i not in removed]},indent=2));(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
