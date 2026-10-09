import bpy,json,hashlib
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'approved_spine_palette.json').read_text())
def snapshot(o):
 return {'vertices':[list(v.co) for v in o.data.vertices],'faces':[list(f.vertices) for f in o.data.polygons],'weights':[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices],'bones':[(b.name,b.parent.name if b.parent else None,[list(x) for x in b.matrix_local]) for b in bpy.data.objects['TrexRig'].data.bones],'keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in bpy.data.objects['Trex'].data.shape_keys.key_blocks]}
bpy.ops.wm.open_mainfile(filepath=str(r/rec['source_path']));a=bpy.data.objects['01Q1_Tail_Taper'];s=snapshot(a);old=[f.material_index for f in a.data.polygons];names=[m.name for m in a.data.materials]
bpy.ops.wm.open_mainfile(filepath=str(r/rec['output_path']));o=bpy.data.objects[rec['object']];assert s==snapshot(o)
expected={v['source_face']:names.index(v['new']) for v in rec['material_assignments']};assert all(f.material_index==expected.get(f.index,old[f.index]) for f in o.data.polygons)
assert hashlib.sha256((r/rec['output_path']).read_bytes()).hexdigest()==rec['sha256'];assert hashlib.sha256((r/rec['source_path']).read_bytes()).hexdigest()==rec['source_sha256']
(p/'approved_spine_readback.json').write_text(json.dumps({'geometry_topology_weights_Rig_Trex_keys_exact':True,'only_recorded_spine_face_material_assignments_changed':True,'changed_material_faces':len(expected),'model_hashes_verified':True,'production_acceptance':False},indent=2));print('Approved spine-only checkpoint readback passed')
