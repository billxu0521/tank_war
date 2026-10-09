import bpy,json,hashlib,collections
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01R1/2026-10-09-v011/ninola_01R1_posterior_junction.blend';sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01R1_Posterior_Junction'];bpy.context.view_layer.update()
mats={}
for m in o.data.materials:
 if any(k in m.name.lower() for k in ['eye','iris','pupil']):
  nodes=[]
  if m.use_nodes:
   for n in m.node_tree.nodes:
    if n.type=='BSDF_PRINCIPLED':nodes.append({k:list(n.inputs[k].default_value) if k=='Base Color' else n.inputs[k].default_value for k in ['Base Color','Roughness','Metallic']})
  ff=[f for f in o.data.polygons if o.data.materials[f.material_index]==m]
  mats[m.name]={'diffuse_color':list(m.diffuse_color),'nodes':nodes,'faces':len(ff),'triangles':sum(len(f.vertices)-2 for f in ff),'image_textures':[n.image.filepath for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if m.use_nodes else []}
world=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
sel=[f for f in o.data.polygons if any(k in o.data.materials[f.material_index].name.lower() for k in ['eye','iris','pupil'])]
ids={i for f in sel for i in f.vertices}
weights=collections.Counter()
for i in ids:
 for g in o.data.vertices[i].groups:weights[o.vertex_groups[g.group].name]+=g.weight
rec={'path':str(src.relative_to(r)),'sha256':sha,'object':o.name,'eye_materials':mats,'eye_vertex_count':len(ids),'bone_weight_sum':dict(weights),'independent_eye_objects_visible_in_target':False,'no_model_edit':True}
(p/'inspection.json').write_text(json.dumps(rec,indent=2));assert hashlib.sha256(src.read_bytes()).hexdigest()==sha;print(json.dumps(rec))
