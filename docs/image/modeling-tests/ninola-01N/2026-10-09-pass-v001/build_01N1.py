import bpy,json,hashlib,ast,math,importlib.util,collections
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();out=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01M8/2026-10-09-v001/ninola_01M8_cranial_identity.blend';dest=r/'blender/ninola/working/01N1/2026-10-09-v001/ninola_01N1_jaw_volume_reconstruction.blend';assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01M8_Cranial_Identity'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];names=[m.name for m in a.data.materials];mats=[f.material_index for f in a.data.polygons];key=lambda i:tuple(round(x,5) for x in c[i]);world=[v.copy() for v in c]
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
remove={i for i,f in enumerate(faces) if names[mats[i]] in {'d_tan','d_belly'} and all(weights[j].get('jaw',0)>.999 for j in f)};skin={i for fi in remove for i in faces[fi]};protected={i for fi,f in enumerate(faces) if fi not in remove for i in f};pk={key(i) for i in protected};fixedkeys={key(i) for i in skin if key(i) in pk}
# Reconstruct complete exterior patch using welded geometric vertices; all oral boundary points remain exact.
source_sections=[(2.07,.505,1.79,1.432),(2.28,.500,1.752,1.388),(2.50,.490,1.838,1.397),(2.75,.420,1.792,1.496),(3.00,.390,1.854,1.596),(3.25,.365,1.884,1.631),(3.38,.280,1.884,1.670)]
target_sections=[(2.07,.490,1.79,1.48),(2.30,.490,1.78,1.44),(2.55,.470,1.83,1.45),(2.80,.420,1.83,1.49),(3.02,.380,1.86,1.54),(3.22,.340,1.88,1.58),(3.37,.280,1.88,1.64)]
def section(y,rows):
 if y<=rows[0][0]:return rows[0][1:]
 for aa,bb in zip(rows,rows[1:]):
  if y<=bb[0]:t=(y-aa[0])/(bb[0]-aa[0]);return tuple(aa[j]*(1-t)+bb[j]*t for j in range(1,4))
 return rows[-1][1:]
fixedpoints=[Vector(v) for v in fixedkeys];newids={};changed=[];added=[];targetworld={}
for i in sorted(skin):
 k=key(i)
 if k in newids:continue
 if k in fixedkeys:newids[k]=i;targetworld[k]=c[i];continue
 q=c[i].copy();sw,st,sb=section(q.y,source_sections);tw,tt,tb=section(q.y,target_sections);s=max(0,min(1,(st-q.z)/max(.10,st-sb)));candidate=q.copy();candidate.x=q.x*tw/sw;candidate.z=tt-s*(tt-tb)
 # Preserve thick side plane, soften lower corners into a shallow chamfer, not a pointed chin.
 width_fraction=min(1,abs(q.x)/sw);candidate.z+=.018*max(0,width_fraction-.60)*max(0,s-.45)
 distance=min((q-v).length for v in fixedpoints);blend=min(1,distance/.11);blend=blend*blend*(3-2*blend);candidate=q.lerp(candidate,blend)
 idx=len(world);world.append(candidate);weights.append({'jaw':1.0});newids[k]=idx;added.append(idx);targetworld[k]=candidate;changed.append({'source_key':k,'new_vertex':idx,'world_displacement':list(candidate-q)})
newfaces=[[newids[key(i)] for i in faces[fi]] for fi in sorted(remove)];newmats=[mats[fi] for fi in sorted(remove)];retained=[i for i in range(len(faces)) if i not in remove];ff=[faces[i] for i in retained]+newfaces;mm=[mats[i] for i in retained]+newmats
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
def bind(q,w):
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,v in w.items():
  if n in bm:m+=bm[n]*v
 return a.matrix_world.inverted()@(rig.matrix_world@m@rig.matrix_world.inverted()).inverted()@q
rest=[a.data.vertices[i].co.copy() if i<len(c) else bind(q,weights[i]) for i,q in enumerate(world)];me=bpy.data.meshes.new('01N1_Jaw_Volume_Reconstruction');me.from_pydata(rest,[],ff);me.update()
for mat in a.data.materials:me.materials.append(mat)
for f,mi in zip(me.polygons,mm):f.material_index=mi
ob=a.copy();ob.data=me;ob.name='01N1_Jaw_Volume_Reconstruction';bpy.context.scene.collection.objects.link(ob)
for group in a.vertex_groups:
 if group.name not in ob.vertex_groups:ob.vertex_groups.new(name=group.name)
for i,w in enumerate(weights):
 for n,v in w.items():ob.vertex_groups[n].add([i],v,'REPLACE')
bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((x-y).length for x,y in zip(actual,world));assert err<3e-5;assert locked_signature()==lock;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in range(len(c)))
near=[];flips=[]
for n,fi in enumerate(sorted(remove)):
 f=newfaces[n];aa,bb,cc=[actual[i] for i in f];a0,b0,c0=[c[i] for i in faces[fi]];nn=(bb-aa).cross(cc-aa);old=(b0-a0).cross(c0-a0)
 if nn.length_squared<1e-12:near.append(fi)
 if nn.dot(old)<0:flips.append(fi)
assert not near and not flips,(near,flips)
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None);assert not issues,issues
for item in bpy.context.scene.objects:
 if item.type=='MESH':item.hide_render=item!=ob;item.hide_set(item!=ob);item.select_set(item==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='01N1 reconstructed jaw exterior, pending user review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
rec={'base_path':str(src.relative_to(r)),'base_sha256':before,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':ob.name,'vertices':len(world),'triangles':sum(len(f)-2 for f in ff),'reconstructed_external_faces':len(remove),'welded_patch_coordinates':len(newids),'fixed_boundary_keys':len(fixedkeys),'added_active_vertices':len(added),'new_faces_degenerate':near,'new_faces_flipped':flips,'inverse_bind_error':err,'all_M8_original_rest_coords_and_weights_preserved':True,'retained_faces_materials_exact':True,'Rig_Trex_keys_pose_exact':True,'max_exterior_world_displacement':max(Vector(v['world_displacement']).length for v in changed),'pipeline_check':'CHECK OK budget=None','status':'pending_visual_review','production_integration':False,'style_faceting_deferred':True}
(out/'build_record.json').write_text(json.dumps(rec,indent=2));(out/'edit_mask.json').write_text(json.dumps({'removed_faces':sorted(remove),'retained_faces':retained,'fixed_boundary_keys':[list(k) for k in sorted(fixedkeys)],'added_vertices':added,'changes':changed},indent=2));print(json.dumps(rec))
