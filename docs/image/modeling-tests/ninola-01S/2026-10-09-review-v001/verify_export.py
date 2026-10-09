import bpy,json,hashlib
from pathlib import Path
from mathutils.kdtree import KDTree
r=Path.cwd();p=Path(__file__).resolve().parent;x=json.loads((p/'export_records.json').read_text())[0];src=r/x['source'];sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[x['object']];rest=[o.matrix_world@v.co for v in o.data.vertices];evaluated=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];trees=[]
for points in [rest,evaluated]:
 tree=KDTree(len(points))
 for i,q in enumerate(points):tree.insert(q,i)
 tree.balance();trees.append(tree)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(r/x['export_path']));all_meshes=[ob for ob in bpy.context.scene.objects if ob.type=='MESH'];meshes=[ob for ob in all_meshes if ob.name==x['object']];assert len(meshes)==1;points=[ob.matrix_world@v.co for ob in meshes for v in ob.data.vertices];errors=[max(tree.find(q)[2] for q in points) for tree in trees];tri=sum(len(f.vertices)-2 for ob in meshes for f in ob.data.polygons);assert tri==x['triangles'];assert errors[0]<2e-5,errors;assert hashlib.sha256(src.read_bytes()).hexdigest()==sha
(p/'export_readback.json').write_text(json.dumps({'GLB_blender_import_meshes':[ob.name for ob in meshes],'excluded_import_display_shapes':[ob.name for ob in all_meshes if ob not in meshes],'triangles':tri,'import_vertex_count':len(points),'max_nearest_source_bind_world_error':errors[0],'max_nearest_source_evaluated_world_error':errors[1],'bind_world_geometry_matches':errors[0]<2e-5,'triangle_count_matches':tri==x['triangles'],'scope':'Blender exporter/importer bind geometry check; not full Godot skin/PBR acceptance','source_hash_unchanged':True},indent=2));print('GLB bind readback',errors,tri)
