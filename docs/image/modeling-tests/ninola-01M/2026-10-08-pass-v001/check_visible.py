import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01M/2026-10-08-pass-v001';bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/working/01M1/2026-10-08-v001/ninola_01M1_jaw_mass_blockout.blend'));o=bpy.data.objects['01M1_Lower_Jaw_Mass_Blockout'];bpy.context.view_layer.update();e=o.evaluated_get(bpy.context.evaluated_depsgraph_get());c=[o.matrix_world@v.co for v in e.data.vertices];f=[list(x.vertices) for x in e.data.polygons];tree=BVHTree.FromPolygons(c,f,all_triangles=False);s=json.loads((p/'captures/capture_settings_01M1.json').read_text())['head_threequarter'];m=Matrix(s['matrix']);result=[]
for x,y in [(577,840),(583,856),(594,851),(572,827),(586,818)]:
 local=Vector(((x/1100-.5)*36/70,(.5-y/1100)*36/70,-1)).normalized();di=m.to_3x3()@local;hit=tree.ray_cast(m.translation,di)
 if hit[2] is not None:
  fi=hit[2];ids=f[fi];groups={o.vertex_groups[g.group].name for i in ids for g in o.data.vertices[i].groups};result.append({'pixel':[x,y],'face':fi,'material':o.data.materials[o.data.polygons[fi].material_index].name,'coords':[list(c[i]) for i in ids],'groups':list(groups)})
print(json.dumps(result));(p/'visible_feature_check.json').write_text(json.dumps(result,indent=2))
