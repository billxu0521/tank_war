import bpy, json, collections
from pathlib import Path
r=Path(__file__).resolve().parents[5]
p=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/working/01K8/2026-10-08-v004/ninola_01K8_hock_mass_continuity.blend'))
a=bpy.data.objects['01K8_Hock_Mass_Continuity']; d=a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data
c=[a.matrix_world@v.co for v in d.vertices]; edges=collections.defaultdict(list)
for face in d.polygons:
 k=[tuple(round(t,5) for t in c[i]) for i in face.vertices]
 for x,y in zip(k,k[1:]+k[:1]): edges[tuple(sorted((x,y)))].append((face.index,x,y))
cut=len(d.polygons)-744
seams=[v for v in edges.values() if any(t[0]>=cut for t in v) and any(t[0]<cut for t in v)]
result={'shared_geometric_seam_edges':len(seams),'seam_winding_conflicts':sum(len(v)==2 and v[0][1:]==v[1][1:] for v in seams),'seam_non_two_face_edges':sum(len(v)!=2 for v in seams),'scope':'quantized geometric seam only, not full manifold or self-intersection certification; read-only Blender inspection'}
(p/'seam_verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
