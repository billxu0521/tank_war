import bpy,json
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend'));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];bpy.context.view_layer.update();e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());(p/'inspection_geometry.json').write_text(json.dumps({'vertices':[list(o.matrix_world@v.co) for v in e.data.vertices],'faces':[list(f.vertices) for f in e.data.polygons],'material_indices':[f.material_index for f in e.data.polygons],'material_colors':[list(m.diffuse_color) for m in o.data.materials]}))
