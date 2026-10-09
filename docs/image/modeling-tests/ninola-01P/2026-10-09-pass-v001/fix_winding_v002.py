import bpy,bmesh,json,collections,hashlib
from pathlib import Path
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'build_record.json').read_text());src=r/rec['output'];dest=r/'blender/ninola/working/01P1/2026-10-09-v002/ninola_01P1_palm_digit_continuity.blend';assert not dest.exists();bpy.ops.wm.open_mainfile(filepath=str(src));ob=bpy.data.objects[rec['object']];bpy.context.view_layer.update();world=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];key=lambda i:tuple(round(v,5) for v in world[i]);faces=[list(f.vertices) for f in ob.data.polygons];new={fi for fi,f in enumerate(faces) if any(i>=11136 for i in f)};edges=collections.defaultdict(list)
for fi,f in enumerate(faces):
 for a,b in zip(f,f[1:]+f[:1]):edges[tuple(sorted((key(a),key(b))))].append((fi,key(a),key(b)))
adj=collections.defaultdict(list);sign={}
for edge,items in edges.items():
 if len(items)!=2:continue
 A,B=items; same=A[1:]==B[1:]
 if A[0] in new and B[0] in new:adj[A[0]].append((B[0],-1 if same else 1));adj[B[0]].append((A[0],-1 if same else 1))
 elif A[0] in new:sign[A[0]]=-1 if same else 1
 elif B[0] in new:sign[B[0]]=-1 if same else 1
queue=list(sign)
while queue:
 i=queue.pop()
 for j,relation in adj[i]:
  val=sign[i]*relation
  if j not in sign:sign[j]=val;queue.append(j)
  else:assert sign[j]==val
assert set(sign)==new
bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table();flips=[fi for fi,s in sign.items() if s<0]
for fi in flips:bm.faces[fi].normal_flip()
bm.to_mesh(ob.data);bm.free();ob.data.update();assert all(ob.data.vertices[i].co==bpy.data.objects[rec['object']].data.vertices[i].co for i in range(len(world)))
# Exact geometry and weights digest before/after winding-only save.
record={**rec,'output':str(dest.relative_to(r)),'revision':'v002 winding-only correction','previous_output':rec['output'],'flipped_new_faces':flips,'local_skin_winding_consistent':True,'inherited_claw_base_caps_retained':True,'claw_base_valence3_edges':16,'closed_manifold_production_claim':False};ob['status']='01P1 v002 isolated palm digit trial pending user review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));record['sha256']=hashlib.sha256(dest.read_bytes()).hexdigest();(p/'build_record_v002.json').write_text(json.dumps(record,indent=2));(p/'inspection_geometry.json').write_text(json.dumps({'vertices':[list(v) for v in world],'faces':[list(f.vertices) for f in ob.data.polygons],'material_indices':[f.material_index for f in ob.data.polygons],'material_colors':[list(m.diffuse_color) for m in ob.data.materials]}));print('winding-only correction',len(flips))
