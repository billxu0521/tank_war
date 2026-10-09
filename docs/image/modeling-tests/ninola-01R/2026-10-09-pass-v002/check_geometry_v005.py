import bpy,json,hashlib
from pathlib import Path
p=Path(__file__).resolve().parent;r=Path.cwd();rec=json.loads((p/'build_record_v005.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(r/rec['output_path']));o=bpy.data.objects[rec['object']];o.data.update()
g=json.loads((p/'vertex_provenance_v005.json').read_text());changed=set(g['changed_old_vertex_ids']);ids=g['retained_old_vertex_ids'];target=[f for f in o.data.polygons if any(ids[i] in changed for i in f.vertices)]
result={'changed_surface_adjacent_faces':len(target),'changed_surface_degenerate_faces':sum(f.area<1e-10 for f in target),'all_mesh_degenerate_faces':sum(f.area<1e-10 for f in o.data.polygons),'all_faces_explicit_triangles':all(len(f.vertices)==3 for f in o.data.polygons),'rig_bones':len(bpy.data.objects['TrexRig'].data.bones),'original_Trex_shape_keys':len(bpy.data.objects['Trex'].data.shape_keys.key_blocks),'prototype_shape_keys':o.data.shape_keys is not None,'scope':'degeneracy/readback only; no claim of full manifold, intersection or production readiness'}
assert result['changed_surface_degenerate_faces']==0
assert hashlib.sha256((r/rec['output_path']).read_bytes()).hexdigest()==rec['sha256']
(p/'geometry_check_v005.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
