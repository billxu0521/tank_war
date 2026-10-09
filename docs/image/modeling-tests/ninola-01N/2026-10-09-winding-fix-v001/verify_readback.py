import bpy,json,hashlib,ast
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'))
def get(path,name):
 q=r/path;before=hashlib.sha256(q.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(q));o=bpy.data.objects[name];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
 return {'sha256':before,'lock':locked_signature(),'coords':[list(v.co) for v in o.data.vertices],'weights':[{o.vertex_groups[x.group].name:x.weight for x in v.groups} for v in o.data.vertices],'faces':[list(f.vertices) for f in o.data.polygons],'materials':[o.data.materials[f.material_index].name for f in o.data.polygons],'keys':o.data.shape_keys is not None,'bones':len(rig.data.bones),'deform_bones':[b.name for b in rig.data.bones if b.use_deform]}
a=get('blender/ninola/working/01N1/2026-10-09-v003/ninola_01N1_jaw_volume_reconstruction.blend','01N1_Jaw_Volume_Reconstruction');b=get('blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend','01N1_Jaw_Volume_Reconstruction');rec=json.loads((p/'fix_record.json').read_text());changed=rec['changed_face_indices']
def cyclic(v):return min(tuple(v[i:]+v[:i]) for i in range(len(v)))
assert a['coords']==b['coords'] and a['weights']==b['weights'] and a['materials']==b['materials'] and a['lock']==b['lock'];assert len(a['faces'])==len(b['faces'])
assert all(cyclic(f)==cyclic(list(reversed(a['faces'][i])) if i in changed else a['faces'][i]) for i,f in enumerate(b['faces']))
report={'saved_file_readback_pass':True,'coordinates_weights_materials_Rig_Trex_keys_pose_exact':True,'only_face_order_changed':changed,'bones':b['bones'],'prototype_shape_keys':b['keys'],'v003_sha256':a['sha256'],'v004_sha256':b['sha256'],'production_integration':False};(p/'readback_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
