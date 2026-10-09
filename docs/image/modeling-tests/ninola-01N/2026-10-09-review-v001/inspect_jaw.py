import bpy,json,hashlib
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent
src=r/'blender/ninola/working/01M8/2026-10-09-v001/ninola_01M8_cranial_identity.blend';before=hashlib.sha256(src.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01M8_Cranial_Identity'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());world=[o.matrix_world@v.co for v in e.data.vertices]
weights=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];skin=set();faceids=[]
for f in o.data.polygons:
 if o.data.materials[f.material_index].name in {'d_tan','d_belly'} and all(weights[i].get('jaw',0)>.999 for i in f.vertices):skin.update(f.vertices);faceids.append(f.index)
pts=[world[i] for i in skin];bounds=lambda ps:[[min(v[k] for v in ps),max(v[k] for v in ps)] for k in range(3)]
rec={'source':str(src.relative_to(r)),'sha256':before,'object':o.name,'bones':len(rig.data.bones),'prototype_has_shape_keys':bool(o.data.shape_keys),'jaw_bone':{'head_world':list(rig.matrix_world@rig.pose.bones['jaw'].head),'tail_world':list(rig.matrix_world@rig.pose.bones['jaw'].tail),'pose_basis':[list(row) for row in rig.pose.bones['jaw'].matrix_basis]},'candidate_skin_materials':['d_tan','d_belly'],'candidate_jaw1_skin_vertex_count':len(skin),'candidate_skin_face_count':len(faceids),'candidate_skin_bounds_xyz':bounds(pts),'mask_is_not_authorized_edit_mask':True,'source_unchanged':hashlib.sha256(src.read_bytes()).hexdigest()==before,'bones_mesh_pose_modified':False}
(p/'model_inspection.json').write_text(json.dumps(rec,indent=2));print(json.dumps(rec))
