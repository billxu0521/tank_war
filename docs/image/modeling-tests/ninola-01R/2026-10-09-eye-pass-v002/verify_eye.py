import bpy,json,hashlib,collections,ast
from pathlib import Path
from mathutils import Vector
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'build_record.json').read_text());sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest();sha_bytes=lambda b:hashlib.sha256(b).hexdigest()
tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'))
bpy.ops.wm.open_mainfile(filepath=str(r/rec['base_path']));a=bpy.data.objects['01R1_Posterior_Junction'];lock=locked_signature();src=[]
for f in a.data.polygons:
 if any(k in a.data.materials[f.material_index].name.lower() for k in ['eye','iris','pupil']):continue
 src.append(([list(a.data.vertices[i].co) for i in f.vertices],a.data.materials[f.material_index].name,f.use_smooth,[{a.vertex_groups[g.group].name:g.weight for g in a.data.vertices[i].groups} for i in f.vertices]))
bpy.ops.wm.open_mainfile(filepath=str(r/rec['output_path']));a=bpy.data.objects[rec['object']];bpy.context.view_layer.update();target=[]
for f in list(a.data.polygons)[:len(src)]:target.append(([list(a.data.vertices[i].co) for i in f.vertices],a.data.materials[f.material_index].name,f.use_smooth,[{a.vertex_groups[g.group].name:g.weight for g in a.data.vertices[i].groups} for i in f.vertices]))
assert src==target;assert lock==locked_signature();co=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];result=[]
for ids,faces,eye in zip(rec['eye_ids'],rec['eye_faces'],rec['eyes']):
 center=Vector(eye['sphere_center']);radius=eye['sphere_radius'];error=max(abs((co[i]-center).length-radius) for i in ids);assert error<2e-6,error;edges=collections.Counter();minarea=1.;minwind=1.
 for fi in faces:
  f=list(a.data.polygons[fi].vertices);A,B,C=[co[i] for i in f];normal=(B-A).cross(C-A);minarea=min(minarea,normal.length/2);minwind=min(minwind,normal.dot((A+B+C)/3-center))
  for i,j in zip(f,f[1:]+f[:1]):edges[tuple(sorted((i,j)))]+=1
 assert all(n==2 for n in edges.values());assert minarea>1e-10 and minwind>0;assert all({a.vertex_groups[g.group].name:g.weight for g in a.data.vertices[i].groups}=={'head':1.0} for i in ids)
 result.append({'side':eye['side'],'radius_error':error,'closed_edges_two_faces':True,'minimum_triangle_area':minarea,'all_outward':True,'head_weight_1':True})
assert sha(r/rec['base_path'])==rec['base_sha256'];assert sha(r/rec['output_path'])==rec['output_sha256']
(p/'verification.json').write_text(json.dumps({'saved_file_readback':True,'source_hash_unchanged':True,'non_eye_geometry_material_weights_smoothing_exact':True,'Rig_Trex_keys_pose_exact':True,'bones':len(bpy.data.objects['TrexRig'].data.bones),'eyes':result,'no_external_image_texture_added':True,'desktop_MCP':'unavailable: Broken pipe / Not connected','game_PBR_validation':False},indent=2));print('Saved file readback: all eye-only locks and closed outward eye geometry PASS')
