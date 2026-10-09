import bpy,json,hashlib,ast,collections,importlib.util
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01N1/2026-10-09-v003/ninola_01N1_jaw_volume_reconstruction.blend';dest=r/'blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend';assert not dest.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];bpy.context.view_layer.update()
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();tree=ast.parse((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-pass-v003/build_01L3_refined.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='locked_signature'],type_ignores=[]),'sig','exec'));lock=locked_signature()
coords=[list(v.co) for v in o.data.vertices];weights=[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices];faces=[list(f.vertices) for f in o.data.polygons];mats=[f.material_index for f in o.data.polygons];material_names=[m.name for m in o.data.materials];matrix=[list(row) for row in o.matrix_world];world=[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];analysis=json.loads((r/'docs/image/modeling-tests/ninola-01N/2026-10-09-interface-audit-v001/interface_analysis.json').read_text());changed=sorted(6709+i for i in analysis['diagnostic_orientation_only']['new_local_faces_to_reverse']);new=[list(reversed(f)) if i in changed else f for i,f in enumerate(faces)]
# Copy mesh data to preserve weights, attributes and shape of the accepted asset.
me=o.data.copy();me.name='01N1_Jaw_Winding_Fixed';old=o.data;o.data=me
for fi in changed:me.polygons[fi].flip()
me.update();bpy.context.view_layer.update();actual=[list(f.vertices) for f in me.polygons]
# flip can use cyclic reversal, not necessarily reverse list starting index.
def cyclic(v):return min(tuple(v[i:]+v[:i]) for i in range(len(v)))
assert all(cyclic(f)==cyclic(new[i]) for i,f in enumerate(actual));assert coords==[list(v.co) for v in me.vertices];assert weights==[[(g.group,g.weight) for g in v.groups] for v in me.vertices];assert mats==[f.material_index for f in me.polygons];assert material_names==[m.name for m in me.materials];assert matrix==[list(row) for row in o.matrix_world];assert world==[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];assert lock==locked_signature()
edge=collections.defaultdict(list)
for fi,f in enumerate(actual[6709:]):
 for a,b in zip(f,f[1:]+f[:1]):edge[tuple(sorted([a,b]))].append((fi,a,b))
bad=[e for e,records in edge.items() if len(records)==2 and records[0][1:]==records[1][1:]];assert not bad
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([o],budget=None);assert not issues,issues
o['status']='01N1 accepted v003 shape, v004 technical winding repair';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
rec={'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dest.relative_to(r)),'output_sha256':sha(dest),'object':o.name,'changed_face_indices':changed,'changed_face_count':len(changed),'vertices':len(coords),'triangles':sum(len(f)-2 for f in faces),'coords_weights_materials_matrix_exact':True,'evaluated_world_coords_exact':True,'Rig_Trex_keys_pose_exact':True,'new_patch_inconsistent_winding_edges_before':21,'new_patch_inconsistent_winding_edges_after':0,'pipeline_check':'CHECK OK budget=None','scope':'12 face winding only, no geometry/style changes','production_integration':False};(p/'fix_record.json').write_text(json.dumps(rec,indent=2));print(json.dumps(rec))
# Save pre-change exact data for independent read-back checks; no model output beyond v004.
(p/'expected_source_data.json').write_text(json.dumps({'coords':coords,'weights':weights,'faces':faces,'materials':mats,'material_names':material_names,'matrix':matrix,'world':world,'lock':lock}))
