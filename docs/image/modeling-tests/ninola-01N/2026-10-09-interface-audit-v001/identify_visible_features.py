import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01N1/2026-10-09-v003/ninola_01N1_jaw_volume_reconstruction.blend';before=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01N1_Jaw_Volume_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();faces=[list(f.vertices) for f in o.data.polygons];mi=[f.material_index for f in o.data.polygons];analysis=json.loads((p/'interface_analysis.json').read_text());first=6709;fixed=[f.copy() for f in faces]
for local in analysis['diagnostic_orientation_only']['new_local_faces_to_reverse']:fixed[first+local].reverse()
records=json.loads((r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/godot_pose_samples.json').read_text())['assets']['M7'];C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));R=rig.matrix_world.copy();pose0={b.name:b.matrix_basis.copy() for b in rig.pose.bones};rest0=[list(v.co) for v in o.data.vertices]

from mathutils.bvhtree import BVHTree
sample=records['jaw_sweep'][3]
for b in rig.data.bones:
 rig.pose.bones[b.name].matrix=R.inverted()@C@Matrix(sample['skeleton_world'])@Matrix(sample['bones'][b.name]);bpy.context.view_layer.update()
coords=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];tree=BVHTree.FromPolygons(coords,faces);di=Vector((-1,0,0));rotation=(-di).to_track_quat('-Z','Y').to_matrix();camera=Vector((0,2.5,1.9))+di*20;result=[]
for px,py in [(390,537),(440,505),(502,449),(552,406),(599,355),(531,470),(567,423)]:
 hits=[]
 for dx in range(-3,4):
  for dy in range(-3,4):
   origin=camera+rotation@Vector((((px+dx)/1100-.5)*3.8,(.5-(py+dy)/850)*3.8*850/1100,0));h,n,fi,d=tree.ray_cast(origin,-di)
   if fi is not None:hits.append(fi)
 fi=max(set(hits),key=hits.count) if hits else None
 if fi is not None:
  f=faces[fi];groups=sorted({o.vertex_groups[g.group].name for i in f for g in o.data.vertices[i].groups});result.append({'pixel':[px,py],'face':fi,'material':o.data.materials[mi[fi]].name,'face_is_new_external':fi>=6709,'groups':groups,'majority_hits':hits.count(fi),'classified_samples':len(hits)})
for n,m in pose0.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert before==hashlib.sha256(src.read_bytes()).hexdigest()
(p/'spike_pixel_identification.json').write_text(json.dumps({'image':'sweep003_current.png','samples':result,'source_unchanged':True,'limitation':'Only these sampled image locations, not every possible sharp feature.'},indent=2));print(json.dumps(result))
