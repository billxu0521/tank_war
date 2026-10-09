import bpy,json
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/working/01Q1/2026-10-09-v002/ninola_01Q1_tail_taper.blend'));o=bpy.data.objects['01Q1_Tail_Taper'];d={m.name:{'diffuse':list(m.diffuse_color),'node_base_color':[list(n.inputs['Base Color'].default_value) for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'] if m.use_nodes else []} for m in o.data.materials};(p/'source_material_inspection.json').write_text(json.dumps(d,indent=2));print({k:v for k,v in d.items() if 'spike' in k or 'ridge' in k})
