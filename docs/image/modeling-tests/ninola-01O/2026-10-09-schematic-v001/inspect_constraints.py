import bpy,json,hashlib
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent
src=r/'blender/ninola/working/01N1/2026-10-09-v004/ninola_01N1_jaw_volume_reconstruction.blend'; sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];bpy.context.view_layer.update();e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());c=[list(o.matrix_world@v.co) for v in e.data.vertices];weights=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];names=[m.name for m in o.data.materials];faces=[list(f.vertices) for f in o.data.polygons];mats=[names[f.material_index] for f in o.data.polygons];used={i for f in faces for i in f}
groups={'neck','neck2','spine2','spine1'};skinm={'d_olive','d_moss','d_tan','d_belly'}
skin={i for f,m in zip(faces,mats) if m in skinm for i in f if sum(weights[i].get(g,0) for g in groups)>.5 and .3<c[i][1]<2.35}
protected={i for f,m in zip(faces,mats) if m not in skinm or any(sum(weights[j].get(g,0) for g in groups)<=.5 for j in f) for i in f};key=lambda i:tuple(round(v,5) for v in c[i]);keys={key(i) for i in protected};shared={i for i in skin if key(i) in keys}
def quant(a,t):return sorted(a)[round((len(a)-1)*t)]
bins=[]
for y in [2.24,2.08,1.88,1.66,1.44,1.2,.96,.72,.48]:
 pts=[c[i] for i in skin if abs(c[i][1]-y)<.12]
 if pts:bins.append({'y':y,'n':len(pts),'halfwidth_max':max(abs(v[0]) for v in pts),'z_min':min(v[2] for v in pts),'z_max':max(v[2] for v in pts),'z_q10':quant([v[2] for v in pts],.1),'z_q90':quant([v[2] for v in pts],.9)})
rig=bpy.data.objects['TrexRig'];bone={b.name:{'head_world':list(rig.matrix_world@b.head),'tail_world':list(rig.matrix_world@b.tail)} for b in rig.pose.bones}
(p/'source_geometry.json').write_text(json.dumps({'vertices':c,'faces':faces,'materials':mats,'weights':weights,'active_candidate':sorted(skin),'protected_coincident_candidates':sorted(shared),'protected_vertex_ids':sorted(protected),'used_vertices':len(used)}))
(p/'constraint_inspection.json').write_text(json.dumps({'source':str(src.relative_to(r)),'sha256':sha,'source_unchanged':hashlib.sha256(src.read_bytes()).hexdigest()==sha,'bones':bone,'bone_count':len(rig.data.bones),'source_keys':{k.name:k.value for k in bpy.data.objects['Trex'].data.shape_keys.key_blocks},'candidate_points':len(skin),'shared_candidate_points':len(shared),'bins':bins,'mask_status':'weight/material aided location candidate only; not an authorized edit mask; no seam solve or deformation validation'},indent=2));print(json.dumps({'materials':names,'candidate_points':len(skin),'shared':len(shared),'bins':bins}))
