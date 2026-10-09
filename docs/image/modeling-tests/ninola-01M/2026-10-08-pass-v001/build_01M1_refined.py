import bpy,json,hashlib,ast,math,collections
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();out=r/'docs/image/modeling-tests/ninola-01M/2026-10-08-pass-v001/refined-v002';out.mkdir(exist_ok=True);src=r/'blender/ninola/working/01L3/2026-10-08-v002/ninola_01L3_toe_volume_rebuild.blend';dest=r/'blender/ninola/working/01M1/2026-10-08-v002/ninola_01M1_jaw_mass_blockout.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01L3_Three_Toe_Volume_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));locked=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];key=lambda p:tuple(round(v,5) for v in p)
skin={i for f,m in zip(faces,mats) if m in [2,5] for i in f if weights[i].get('jaw',0)>.999};protected={i for f,m in zip(faces,mats) if m not in [2,5] or any(weights[j].get('jaw',0)<.999 for j in f) for i in f};pk={key(c[i]) for i in protected};active={i for i in skin if key(c[i]) not in pk};groups=collections.defaultdict(list)
for i,p in enumerate(c):groups[key(p)].append(i)
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
knots=[(1.94,1.44),(2.10,1.40),(2.30,1.41),(2.50,1.45),(2.70,1.51),(2.90,1.58),(3.10,1.66),(3.30,1.78),(3.42,1.85)]
basefloor=[(1.94,1.222),(2.10,1.225),(2.30,1.262),(2.50,1.373),(2.70,1.388),(2.90,1.478),(3.10,1.528),(3.30,1.737),(3.42,1.85)]
def interp(y,pts):
 if y<=pts[0][0]:return pts[0][1]
 for (y0,z0),(y1,z1) in zip(pts,pts[1:]):
  if y<=y1:return z0+(z1-z0)*smooth((y-y0)/(y1-y0))
 return pts[-1][1]
world=[p.copy() for p in c];moved=set()
for i in sorted(active):
 p=c[i];floor=interp(p.y,basefloor);lift=interp(p.y,knots)-floor;depth=smooth((1.79-p.z)/max(.05,1.79-floor));q=p.copy();q.z+=max(0,lift)*depth
 q.y+=.07*depth*smooth((2.40-p.y)/.46)
 q.x*=1-.07*depth
 q.z+=.015*depth*min(1,(abs(p.x)/.52)**2)
 if (q-p).length>1e-7:
  for j in groups[key(p)]:
   assert j not in protected;world[j]=q.copy();moved.add(j)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform};ob=a.copy();ob.data=a.data.copy();ob.name='01M1_Lower_Jaw_Mass_Blockout';bpy.context.scene.collection.objects.link(ob)
for i in moved:
 ww=weights[i];m=Matrix.Identity(4)*(1-sum(v for n,v in ww.items() if n in bm))
 for n,v in ww.items():
  if n in bm:m+=bm[n]*v
 eff=rig.matrix_world@m@rig.matrix_world.inverted();ob.data.vertices[i].co=ob.matrix_world.inverted()@(eff.inverted()@world[i])
ob.data.update();bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((x-y).length for x,y in zip(actual,world));assert err<3e-5
assert locked_signature()==locked;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)) if i not in moved)
changedfaces=[i for i,f in enumerate(faces) if any(j in moved for j in f)];near=[];turned=[]
for fi in changedfaces:
 f=faces[fi];n=(actual[f[1]]-actual[f[0]]).cross(actual[f[2]]-actual[f[0]]);old=(c[f[1]]-c[f[0]]).cross(c[f[2]]-c[f[0]])
 if n.length_squared<1e-12:near.append(fi)
 if n.dot(old)<0:turned.append(fi)
record={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'object':ob.name,'changed_vertices':len(moved),'changed_faces':len(changedfaces),'topology_unchanged':True,'weights_unchanged':True,'protected_vertices_unchanged':True,'outside_mask_rest_coords_exact':True,'Rig_Trex_keys_pose_exact':True,'changed_skin_near_degenerates':len(near),'changed_face_normal_dot_negative':len(turned),'inverse_bind_error':err,'max_world_displacement':max((actual[i]-c[i]).length for i in moved),'status':'pending_visual_review','attack_deformation_not_tested':True}
print('LOCAL_FACE_CHECK',len(near),len(turned),turned);assert not near;assert not turned
(out/'edit_mask.json').write_text(json.dumps({'moved_vertices':sorted(moved),'changed_faces':changedfaces,'protected_vertices':sorted(protected),'world_displacements':{str(i):list(actual[i]-c[i]) for i in moved}},indent=2))
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='prototype_pending_visual_review';ob['base_sha256']=basehash
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash;bpy.ops.wm.open_mainfile(filepath=str(dest));assert locked_signature()==locked;o=bpy.data.objects[ob.name] if False else bpy.data.objects['01M1_Lower_Jaw_Mass_Blockout'];bpy.context.view_layer.update();assert [list(f.vertices) for f in o.data.polygons]==faces;assert [{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices]==weights;record['reopen_Rig_Trex_topology_weights_exact']=True;record['output_sha256']=sha(dest);(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps(record))
