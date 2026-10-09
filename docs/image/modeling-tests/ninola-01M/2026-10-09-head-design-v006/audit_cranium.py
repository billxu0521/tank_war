import bpy,json,hashlib,csv,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np
r=Path.cwd();p=Path(__file__).resolve().parent;index=json.loads((r/'docs/image/modeling-tests/ninola-workflow/asset-index.json').read_text());reports={};rows=[]
regions=[('L1','Nasal_Vault',(0,3.35,2.47),(.20,.25,.20)),('L2','Preorbital',(.30,3.12,2.45),(.17,.16,.18)),('L3','Postorbital',(.43,2.70,2.43),(.18,.18,.25)),('L4','Supraorbital',(.30,2.98,2.55),(.18,.24,.16)),('L5','Eyeball_Region',(.35,2.98,2.435),(.14,.13,.12)),('L6','Infraorbital_Jugal',(.38,2.90,2.22),(.18,.25,.17)),('L7','Maxillary_Mass',(.29,3.30,2.22),(.16,.28,.15)),('L8','Muzzle_Premaxillary',(0,3.64,2.22),(.24,.15,.20)),('L9','Naris_Region',(.18,3.51,2.37),(.10,.15,.12))]
for tag in ['01M3','01M5B']:
 item=index['assets'][tag];src=r/item['local_path'];before=hashlib.sha256(src.read_bytes()).hexdigest();assert before==item['sha256'];bpy.ops.wm.open_mainfile(filepath=str(src));ob=bpy.data.objects[item['object']];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();me=ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data;c=[ob.matrix_world@v.co for v in me.vertices];names=[m.name for m in me.materials];skinface=[f for f in me.polygons if names[f.material_index] in ['d_olive','d_moss','d_tan','d_ridge']];skinids={i for f in skinface for i in f.vertices};bvh=BVHTree.FromPolygons(c,[list(f.vertices) for f in me.polygons if 'Iris' not in names[f.material_index] and names[f.material_index] not in ['d_pupil','Ninola_Eye_Dark_Bronze']],all_triangles=False)
 landmarks=[]
 for lid,name,center,half in regions:
  sides=[0] if lid in ['L1','L8'] else [-1,1]
  for side in sides:
   cc=Vector((center[0]*side,center[1],center[2]));ids=[i for i in skinids if i>=10444 and all(abs(c[i][j]-cc[j])<=half[j] for j in range(3))];point=list(sum((c[i] for i in ids),Vector())/len(ids)) if ids else None
   rec={'id':lid,'side':side,'region':name,'candidate_skin_region_centroid':point,'vertex_samples':len(ids),'evidence_class':'I/D','confidence':'LOW' if lid=='L9' or not ids else 'MEDIUM','meaning':'actual skin samples in explicitly chosen design region; not measured fossil bone landmark','anatomical_identity':'UNCERTAIN' if lid=='L9' else 'region correspondence only'};landmarks.append(rec);rows.append([tag,lid,side,name,'I/D',rec['confidence'],ob.name,*(point or ['','','']),len(ids),rec['meaning']])
 eyes=[]
 for sign in [-1,1]:
  eye_fs=[f for f in me.polygons if (names[f.material_index] in ['d_pupil','Ninola_Eye_Dark_Bronze'] or 'Iris' in names[f.material_index]) and all(c[i].x*sign>.15 for i in f.vertices) and all(2.65<c[i].y<3.25 and 2.25<c[i].z<2.65 for i in f.vertices)]
  if tag=='01M5B':eye_fs=[f for f in eye_fs if min(f.vertices)>=10561]
  ids={i for f in eye_fs for i in f.vertices};sphere=None;axis=None;residual=None
  if tag=='01M5B' and ids:
   xyz=np.array([list(c[i]) for i in ids]);A=np.column_stack((2*xyz,np.ones(len(xyz))));sol=np.linalg.lstsq(A,(xyz*xyz).sum(axis=1),rcond=None)[0];sphere=Vector(sol[:3]);rad=math.sqrt(sol[3]+sum(sol[:3]**2));residual=max(abs((c[i]-sphere).length-rad) for i in ids)
   cap=[f for f in eye_fs if names[f.material_index]=='d_pupil'];cent=sum((sum((c[i] for i in f.vertices),Vector())/len(f.vertices) for f in cap),Vector())/len(cap);axis=(cent-sphere).normalized()
  else:
   rad=None
  iris=[f for f in eye_fs if 'Iris' in names[f.material_index]];testfaces=iris or eye_fs
  samples=[sum((c[i] for i in f.vertices),Vector())/len(f.vertices) for f in testfaces]
  center=sphere or (sum((c[i] for i in ids),Vector())/len(ids) if ids else None)
  tests={}
  if center:
   head_length=1.35
   targets={'near':Vector((0,3.76+head_length,2.435)),'far':Vector((0,3.76+4*head_length,2.435))}
   camera_positions={'front':Vector((0,22,2.435)),'left_threequarter':Vector((-14,16,6)),'right_threequarter':Vector((14,16,6))}
   for label,target in {**targets,**camera_positions}.items():
    visible=0;distances=[]
    for q in samples:
     direction=(target-q).normalized();distance=(target-q).length;hit=bvh.ray_cast(q+direction*.00001,direction,distance)
     if hit[0] is None:visible+=1
     else:distances.append(hit[3])
    tests[label]={'point_visibility':visible,'tested_face_centroids':len(samples),'visible_fraction':visible/len(samples) if samples else None,'axis_target_angle_degrees':math.degrees(axis.angle((target-center).normalized())) if axis else None,'target_world':list(target),'occlusion_distance_min':min(distances) if distances else None}
  eyes.append({'side':sign,'sphere_center_measured':list(sphere) if sphere else None,'sphere_radius_fitted':rad,'sphere_fit_max_residual':residual,'visible_patch_centroid_only':list(center) if center and sphere is None else None,'pupil_cap_axis_measured':list(axis) if axis else None,'tests':tests,'note':'neutral pose samples; point rays exclude eye surfaces but include external shell; not area integration or full biological visual field'})
 reports[tag]={'source':item['local_path'],'sha256':before,'object':ob.name,'bones':len(rig.data.bones),'prototype_shape_keys':ob.data.shape_keys is not None,'landmarks':landmarks,'eyes':eyes,'coords':[list(v) for v in c],'faces':[list(f.vertices) for f in me.polygons],'material_names':names,'material_indices':[f.material_index for f in me.polygons],'source_saved':False};assert hashlib.sha256(src.read_bytes()).hexdigest()==before
(p/'audit_geometry.json').write_text(json.dumps(reports));small={k:{q:v for q,v in d.items() if q not in ['coords','faces','material_indices']} for k,d in reports.items()};(p/'audit_results.json').write_text(json.dumps(small,indent=2))
with (p/'landmarks.csv').open('w') as stream:
 wr=csv.writer(stream);wr.writerow(['asset','id','side','region','evidence','confidence','object','world_x','world_y','world_z','samples','meaning']);wr.writerows(rows)
print(json.dumps({k:{'bones':v['bones'],'eyes':v['eyes']} for k,v in reports.items()},indent=2))
