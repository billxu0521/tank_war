import bpy, math, json, hashlib, ast
from pathlib import Path
from mathutils import Vector, Matrix
r=Path.cwd();p=Path(__file__).resolve().parent
src=r/'blender/ninola/working/01R1/2026-10-09-v011/ninola_01R1_posterior_junction.blend'
dest=r/'blender/ninola/working/01R2/2026-10-09-v004/ninola_01R2_gold_slit_eye.blend'
assert not dest.exists();sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest();sourcehash=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01R1_Posterior_Junction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));locked=locked_signature()
weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
removed=[f.index for f in a.data.polygons if any(k in a.data.materials[f.material_index].name.lower() for k in ['eye','iris','pupil'])]
assert sum(len(a.data.polygons[i].vertices)-2 for i in removed)==288
keep=[f for f in a.data.polygons if f.index not in set(removed)];used=sorted({i for f in keep for i in f.vertices});mapping={i:j for j,i in enumerate(used)}
verts=[a.data.vertices[i].co.copy() for i in used];wt=[weights[i] for i in used];ff=[[mapping[i] for i in f.vertices] for f in keep];mm=[f.material_index for f in keep];materials=list(a.data.materials)
def mat(name,col,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1);bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=0;materials.append(m);return len(materials)-1
black=mat('Ninola_R2_Pupil_Black',(.003,.002,.001),.32)
golds=[mat('Ninola_R2_Iris_Gold_'+str(i),c,.5) for i,c in enumerate([(.64,.32,.035),(.72,.40,.055),(.60,.30,.028)])]
rim=mat('Ninola_R2_Iris_Amber_Rim',(.23,.105,.012),.55);body=mat('Ninola_R2_Eye_Dark',(.014,.009,.005),.4)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
inv=a.matrix_world.inverted()@(rig.matrix_world@bm['head']@rig.matrix_world.inverted()).inverted()
records=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/refined-v003/build_record.json').read_text())['eyes'];eyeids=[];eye_faces=[]
for rec in records:
 center=Vector(rec['sphere_center']);rec['previous_gaze_axis']=[rec['side']*math.cos(math.radians(10)),math.sin(math.radians(10)),0];rec['forward_rotation_degrees']=20;rec['additional_forward_rotation_degrees']=10;rec['gaze_axis']=[rec['side']*math.cos(math.radians(20)),math.sin(math.radians(20)),0];rec['gaze_target']=list(center+Vector(rec['gaze_axis'])*10);F=Vector(rec['gaze_axis']);U=Vector((0,1,0));U=(U-F*U.dot(F)).normalized();V=Vector((0,0,1));radius=rec['sphere_radius'];world=[];localff=[];localmm=[]
 def add(q):i=len(world);world.append(q);return i
 def emit(f,m):
  aa,bb,cc=[world[i] for i in f]
  if (bb-aa).cross(cc-aa).dot((aa+bb+cc)/3-center)<0:f=f[::-1]
  localff.append(f);localmm.append(m)
 tip=add(center+F*radius);rings=[];N=24
 for row,theta in enumerate([None,.88,1.15,1.6,2.15,2.7]):
  ring=[]
  for k in range(N):
   t=k*2*math.pi/N
   if theta is None:
    u=.0055*math.cos(t)*abs(math.cos(t))**.3;v=.028*math.sin(t);q=center+U*u+V*v+F*math.sqrt(radius**2-u*u-v*v)
   else:q=center+radius*(F*math.cos(theta)+(U*math.cos(t)+V*math.sin(t))*math.sin(theta))
   ring.append(add(q))
  rings.append(ring)
 for k in range(N):emit([tip,rings[0][k],rings[0][(k+1)%N]],black)
 for row,(aa,bb) in enumerate(zip(rings,rings[1:])):
  for k in range(N):
   j=(k+1)%N;m=golds[(k//4)%3] if row==0 else rim if row==1 else body
   emit([aa[k],aa[j],bb[j]],m);emit([aa[k],bb[j],bb[k]],m)
 back=add(center-F*radius)
 for k in range(N):emit([rings[-1][k],rings[-1][(k+1)%N],back],body)
 start=len(verts);startf=len(ff);verts.extend(inv@q for q in world);wt.extend([{'head':1.0} for q in world]);ff.extend([[i+start for i in f] for f in localff]);mm.extend(localmm);eyeids.append(list(range(start,len(verts))));eye_faces.append(list(range(startf,len(ff))))
me=bpy.data.meshes.new('01R2_Gold_Slit_Eyes');me.from_pydata(verts,[],ff);me.update()
for m in materials:me.materials.append(m)
for f,m in zip(me.polygons,mm):f.material_index=m;f.use_smooth=f.index>=len(keep)
ob=a.copy();ob.data=me;ob.name='01R2_Gold_Slit_Eye';bpy.context.scene.collection.objects.link(ob)
for n in {n for w in wt for n in w}:
 if n not in ob.vertex_groups:ob.vertex_groups.new(name=n)
for i,w in enumerate(wt):
 for n,v in w.items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
assert all(ob.data.vertices[mapping[i]].co==a.data.vertices[i].co for i in used)
assert all({ob.vertex_groups[g.group].name:g.weight for g in ob.data.vertices[mapping[i]].groups}==weights[i] for i in used)
assert locked_signature()==locked
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01R.2 independent gold slit-pupil trial; pending user review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==sourcehash
record={'base_path':str(src.relative_to(r)),'base_sha256':sourcehash,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(verts),'triangles':sum(len(f)-2 for f in ff),'eye_triangles':576,'old_eye_triangles':288,'segments':24,'pupil_width':.011,'pupil_height':.056,'eyes':records,'eye_ids':eyeids,'eye_faces':eye_faces,'outside_eye_rest_coords_weights_materials_exact':True,'Rig_Trex_keys_pose_exact':True,'source_unchanged':True,'status':'pending_user_review','render_limit':'Workbench material preview, no game/PBR validation'}
(p/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps({k:v for k,v in record.items() if k not in ['eye_ids','eye_faces','eyes']}))
