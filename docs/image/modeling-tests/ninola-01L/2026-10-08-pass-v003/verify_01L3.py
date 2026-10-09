import bpy,json,hashlib,ast
from pathlib import Path
root=Path.cwd(); out=root/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/refined-v002'
sha_bytes=lambda b:hashlib.sha256(b).hexdigest()
tree=ast.parse((out.parent/'build_01L3_refined.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'signature','exec'))
idx=json.loads((root/'docs/image/modeling-tests/ninola-workflow/asset-index.json').read_text())
base=root/idx['assets']['01K6']['local_path']; dest=root/'blender/ninola/working/01L3/2026-10-08-v002/ninola_01L3_toe_volume_rebuild.blend'
def snapshot(path,name):
 bpy.ops.wm.open_mainfile(filepath=str(path));o=bpy.data.objects[name];bpy.context.view_layer.update()
 coords=[list(v.co) for v in o.data.vertices];weights=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];faces=[(list(f.vertices),f.material_index) for f in o.data.polygons]
 ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());c=[o.matrix_world@v.co for v in ev.data.vertices];active={i for f in faces for i in f[0]};foot=[c[i] for i in active if c[i].x>.35 and c[i].z<.4]
 bounds={axis:[min(v[j] for v in foot),max(v[j] for v in foot)] for j,axis in enumerate('xyz')}
 return coords,weights,faces,bounds,locked_signature()
a=snapshot(base,'01K6_Pedal_Segment_Mass_Reconstruction');b=snapshot(dest,'01L3_Three_Toe_Volume_Reconstruction');removed=set(json.loads((out/'edit_mask.json').read_text())['removed_source_faces']);retained=[f for i,f in enumerate(a[2]) if i not in removed]
r={'original_rest_coords_exact':a[0]==b[0][:len(a[0])],'original_vertex_weights_exact_by_name':a[1]==b[1][:len(a[1])],'retained_faces_and_materials_exact':retained==b[2][:len(retained)],'rig_Trex_keys_pose_exact':a[4]==b[4],'source_claw_faces_removed':sum(a[2][i][1]==10 for i in removed),'base_active_foot_bounds':a[3],'result_active_foot_bounds':b[3],'hashes':{k:hashlib.sha256((root/v['local_path']).read_bytes()).hexdigest()==v['sha256'] for k,v in idx['assets'].items() if v.get('local_path')},'output_sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
assert all(r[k] for k in ['original_rest_coords_exact','original_vertex_weights_exact_by_name','retained_faces_and_materials_exact','rig_Trex_keys_pose_exact']);assert r['source_claw_faces_removed']==0;assert all(r['hashes'].values())
(out/'verification.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
