import bpy,json,hashlib,math,ast,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();out=Path(__file__).resolve().parent
src=r/'blender/ninola/working/01M7/2026-10-09-v003/ninola_01M7_whole_cranial_blockout.blend'
dest=r/'blender/ninola/working/01M8/2026-10-09-v001/ninola_01M8_cranial_identity.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();basehash=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M7_Whole_Cranial_Blockout'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];world=[v.copy() for v in c];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];allmats=list(a.data.materials);names=[m.name for m in allmats]
# Current reconstructed outer head only, excludes preserved mouth, teeth, body and original neck spines.
pool=[i for i,f in enumerate(faces) if i>=5999 and names[mats[i]]=='d_olive']
added=[];newfaces=[];newmats=[]
def add(p,w=None):
 i=len(world);world.append(Vector(p));wt.append(w or {'head':1.0});added.append(i);return i
def emit(f,m):newfaces.append(f);newmats.append(m)
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

ff=faces+newfaces;mm=mats+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) else bind(q,wt[i]) for i,q in enumerate(world)]
me=bpy.data.meshes.new('01M8_Cranial_Identity');me.from_pydata(rest,[],ff);me.update()
for mat in allmats:me.materials.append(mat)
for f,mi in zip(me.polygons,mm):f.material_index=mi
ob=a.copy();ob.data=me;ob.name='01M8_Cranial_Identity';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
if 'head' not in ob.vertex_groups:ob.vertex_groups.new(name='head')
for i,w in enumerate(wt):
 for n,v in w.items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((aa-bb).length for aa,bb in zip(actual,world));assert err<3e-5
assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)))
assert [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices[:len(c)]]==[[(g.group,g.weight) for g in v.groups] for v in a.data.vertices]
near=[]
for fi in range(len(faces),len(ff)):
 aa,bb,cc=[actual[i] for i in ff[fi]]
 if (bb-aa).cross(cc-aa).length_squared<1e-12:near.append(fi)
assert not near,near
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01M8 head identity restoration candidate, pending user review'
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==basehash
rec={'base_path':str(src.relative_to(r)),'base_sha256':basehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in ff),'added_vertices':len(added),'added_triangles':sum(len(f)-2 for f in newfaces),'spines':spines,'all_M7_coords_weights_faces_materials_exact':True,'Rig_Trex_keys_pose_exact':True,'new_vertices_head_weight':1.0,'new_degenerate_faces':near,'inverse_bind_error':err,'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review','production_integration':False}
(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'added_vertices':added,'changed_M7_vertices':[],'changed_M7_faces':[]},indent=2));print(json.dumps(rec))
