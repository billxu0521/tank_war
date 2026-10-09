import bpy,json,ast,hashlib
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent
sha=lambda x:hashlib.sha256(x.read_bytes()).hexdigest();sha_bytes=lambda b:hashlib.sha256(b).hexdigest()
t=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in t.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'))
b=json.loads((p/'build_record.json').read_text());m=json.loads((p/'edit_mask.json').read_text());d=json.loads((p/'source_geometry.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(r/b['base_path']));lock=locked_signature()
bpy.ops.wm.open_mainfile(filepath=str(r/b['output_path']));o=bpy.data.objects[b['object']];bpy.context.view_layer.update();coords=[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];moved=set(m['moved_source_vertices']);changed=set(m['source_material_changed_faces']);names=[x.name for x in o.data.materials]
assert locked_signature()==lock
assert all(coords[i]==v for i,v in enumerate(d['coords']) if i not in moved)
assert all(coords[i]==d['coords'][i] for i in range(10444))
assert weights[:len(d['weights'])]==d['weights']
assert min(m['removed_source_faces'])>=5999
for ni,si in enumerate(m['retained_source_face_mapping']):
 f=o.data.polygons[ni];assert list(f.vertices)==d['faces'][si]
 if si not in changed:assert names[f.material_index]==d['material_names'][d['mats'][si]]
assert all(si>=5999 for si in changed)
assert sha(r/b['base_path'])==b['base_sha256'];assert sha(r/b['output_path'])==b['output_sha256']
near=[f.index for f in o.data.polygons[len(m['retained_source_face_mapping']):] if f.area<1e-10];assert not near
report={'reopened_saved_asset':True,'Rig_Trex_shape_keys_pose_exact':True,'legacy_M1_10444_coordinates_exact':True,'all_source_weights_exact':True,'outside_edit_mask_exact':True,'retained_face_vertices_exact':True,'original_mouth_teeth_body_foot_materials_exact':True,'source_and_output_hashes_match':True,'new_faces_near_degenerate':near,'triangles':sum(len(f.vertices)-2 for f in o.data.polygons),'vertices':len(o.data.vertices),'production_ready':False,'limitations':['Prototype has no Production Shape Keys','Spine bases embedded, not welded engineering cleanup','No true input/full gameplay validation']}
(p/'verification.json').write_text(json.dumps(report,indent=2));print(report)
