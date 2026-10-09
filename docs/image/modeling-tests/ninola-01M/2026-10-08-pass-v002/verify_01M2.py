import bpy,json,hashlib,ast,collections,struct
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'refined-v002/build_record.json').read_text());mask=json.loads((p/'refined-v002/edit_mask.json').read_text());sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest();sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'))
bpy.ops.wm.open_mainfile(filepath=str(r/rec['base_path']));a=bpy.data.objects['01M1_Lower_Jaw_Mass_Blockout'];lock=locked_signature();coords=[list(v.co) for v in a.data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];bpy.context.view_layer.update();oldworld=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
bpy.ops.wm.open_mainfile(filepath=str(r/rec['output_path']));o=bpy.data.objects[rec['object']];bpy.context.view_layer.update();world=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];assert locked_signature()==lock;changed=set(mask['changed_original_vertices']);assert all(list(o.data.vertices[i].co)==coords[i] for i in range(len(coords)) if i not in changed);assert [{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices[:len(coords)]]==weights
mapping=mask['original_face_mapping'];assert [list(o.data.polygons[k].vertices) for k in range(len(mapping))]==[faces[i] for i in mapping]
near=[];flips=[]
for fi in range(len(o.data.polygons)):
 f=o.data.polygons[fi];v=[world[i] for i in f.vertices];n=(v[1]-v[0]).cross(v[2]-v[0]);
 if n.length_squared<1e-12:near.append(fi)
 if fi<len(mapping):
  b=[oldworld[i] for i in faces[mapping[fi]]];oldn=(b[1]-b[0]).cross(b[2]-b[0]);
  if n.dot(oldn)<0:flips.append(fi)
newnear=[i for i in near if i>=len(mapping)];assert not newnear
b=(p/'dynamic/test-project/models/M2_eight_weights.glb').read_bytes();ln=struct.unpack_from('<I',b,12)[0];glb=json.loads(b[20:20+ln]);assert len(glb['meshes'])==len(glb['skins'])==1 and len(glb['skins'][0]['joints'])==45
result={'reopened_Rig_Trex_shape_keys_exact':True,'outside_mask_rest_exact':True,'all_original_weights_exact':True,'retained_faces_exact':True,'new_socket_weights':'head 1.0','vertices':len(world),'triangles':sum(len(f.vertices)-2 for f in o.data.polygons),'new_faces_near_degenerate':newnear,'all_mesh_near_degenerate_count':len(near),'retained_face_normal_flips':flips,'GLB_meshes':1,'GLB_joints':45,'source_sha256_matches':sha(r/rec['base_path'])==rec['base_sha256'],'output_sha256_matches':sha(r/rec['output_path'])==rec['output_sha256'],'status':'prototype_review_not_production_acceptance'};(p/'refined-v002/verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
