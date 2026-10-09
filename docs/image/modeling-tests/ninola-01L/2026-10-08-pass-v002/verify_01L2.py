import bpy,json,hashlib
from pathlib import Path
p=Path(__file__).resolve().parent;root=p.parents[4];out=p/'refined-v002';rec=json.loads((out/'build_record.json').read_text());sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend'));a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];bpy.context.view_layer.update();c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
def extent(cc):
 f=[v for v in cc if abs(v.x)>.35 and v.z<.7]
 return {'x':[min(v.x for v in f),max(v.x for v in f)],'y':[min(v.y for v in f),max(v.y for v in f)]}
base_ext=extent(c);bpy.ops.wm.open_mainfile(filepath=str(root/rec['output_path']));a=bpy.data.objects[rec['object']];bpy.context.view_layer.update();after=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];mask=json.loads((out/'edit_mask.json').read_text());locked=mask['protected_source_refs']+mask['locked_new_boundary_refs'];ww=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices[:len(c)]];assert ww==wt
result={'retained_original_weights_exact_after_reopen':True,'source_foot_xy_extent':base_ext,'output_foot_xy_extent':extent(after),'original_ref_xy_max_error':max(abs(v.x-q.x)+abs(v.y-q.y) for v,q in zip(c,after)),'protected_original_max_displacement':max((after[i]-c[i]).length for i in mask['protected_source_refs']),'output_hash_match':sha(root/rec['output_path'])==rec['output_sha256'],'geometry_scope':'dorsal surface relief only, no foot length/width change; interpolated new weights provisional; nonconforming subdivision at retained boundaries is not production topology'}
assert result['output_hash_match'];assert result['original_ref_xy_max_error']<2e-6;assert result['protected_original_max_displacement']<1e-6
(out/'reopen_verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
