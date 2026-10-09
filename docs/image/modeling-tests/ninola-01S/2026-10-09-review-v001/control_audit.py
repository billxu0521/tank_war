import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
r=Path.cwd();p=Path(__file__).resolve().parent;g=json.loads((p/'godot_pose_samples.json').read_text())['assets']['S'];record=json.loads((p/'export_records.json').read_text())[0];src=r/record['source'];sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[record['object']];rig=bpy.data.objects['TrexRig'];R=rig.matrix_world.copy();bones=list(rig.data.bones);saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));faces=[list(f.vertices) for f in o.data.polygons];w=[{o.vertex_groups[x.group].name:x.weight for x in v.groups} for v in o.data.vertices];mn=[o.data.materials[f.material_index].name for f in o.data.polygons];coords0=[list(v.co) for v in o.data.vertices]
resterror=max(max(abs((C@Matrix(g['rest'][b.name]['matrix']))[i][j]-(R@b.matrix_local)[i][j]) for i in range(4) for j in range(4)) for b in bones);assert resterror<5e-6,resterror
feet={side:[i for i,weights in enumerate(w) if sum(v for n,v in weights.items() if n.endswith(side) and n.startswith(('foot','toe')))> .8] for side in ['_l','_r']}
soft=['d_olive','d_moss','d_tan','d_belly','d_mouth'];jaw=[fi for fi,f in enumerate(faces) if mn[fi] in soft and all(w[i].get('jaw',0)>.99 for i in f)];head=[fi for fi,f in enumerate(faces) if mn[fi] in soft and all(w[i].get('head',0)>.5 for i in f)];jt=[fi for fi,f in enumerate(faces) if mn[fi]=='d_bone' and all(w[i].get('jaw',0)>.9 for i in f)];ht=[fi for fi,f in enumerate(faces) if mn[fi]=='d_bone' and all(w[i].get('head',0)>.5 for i in f)]
sc=bpy.data.scenes.new('Readonly_S_Audit');sc.world=bpy.data.worlds.new('S_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1000;sc.render.resolution_y=700;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='MATERIAL';sh.show_shadows=False;sh.show_cavity=False;me=bpy.data.meshes.new('S_Evaluated');obj=bpy.data.objects.new('S_Evaluated',me);sc.collection.objects.link(obj)
cd=bpy.data.cameras.new('S_Camera');cam=bpy.data.objects.new('S_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO';out=p/'motion';out.mkdir(exist_ok=True)
control=bpy.data.objects['Trex'];cw=[{control.vertex_groups[x.group].name:x.weight for x in v.groups} for v in control.data.vertices];cf={side:[i for i,ww in enumerate(cw) if sum(v for n,v in ww.items() if n.endswith(side) and n.startswith(('foot','toe')))> .8] for side in ['_l','_r']};control_rows=[];metrics=[];posemax=0.;selected={'walk':list(range(48,144,8)),'run':list(range(48,144,8)),'turn':list(range(48,144,12)),'bite':[0,20,24,26,28,40,70],'roar':[0,20,28,46],'jaw_sweep':[0,1,2,3]}
for kind in ['walk','run','turn','bite','roar','jaw_sweep']:
 for idx,s in enumerate(g[kind]):
  if kind in ['walk','run','turn'] and idx%2:continue
  if kind in ['bite','roar'] and idx not in selected[kind]:continue
  W=Matrix(s['skeleton_world']);targets={b.name:R.inverted()@C@W@Matrix(s['bones'][b.name]) for b in bones}
  for b in bones:rig.pose.bones[b.name].matrix=targets[b.name];bpy.context.view_layer.update()
  error=max(max(abs(rig.pose.bones[n].matrix[i][j]-m[i][j]) for i in range(4) for j in range(4)) for n,m in targets.items());posemax=max(posemax,error);assert error<3e-5,error
  co=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
  row={'sequence':kind,'frame':idx,'time':s['time'],'swing':s.get('swing'),'foot_min_height':{side:min(co[i].z for i in ids) for side,ids in feet.items()}}
  if kind in ['bite','roar','jaw_sweep']:
   row['jaw_head_soft_triangle_pairs']=len(BVHTree.FromPolygons(co,[faces[i] for i in jaw]).overlap(BVHTree.FromPolygons(co,[faces[i] for i in head])))
   row['tooth_triangle_pairs']=len(BVHTree.FromPolygons(co,[faces[i] for i in jt]).overlap(BVHTree.FromPolygons(co,[faces[i] for i in ht])))
  metrics.append(row)
  cc=[control.matrix_world@v.co for v in control.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];control_rows.append({'sequence':kind,'frame':idx,'foot_min_height':{side:min(cc[i].z for i in ids) for side,ids in cf.items()}})
  if True:continue # control-only rerun; existing images retained
  offset=(C@W).translation;display=[v-offset for v in co];me.clear_geometry();me.from_pydata(display,[],faces);me.update();me.materials.clear()
  for material in o.data.materials:me.materials.append(material)
  for f,old in zip(me.polygons,o.data.polygons):f.material_index=old.material_index;f.use_smooth=old.use_smooth
  views=[('body',Vector((-1,0,0)),Vector((0,-.85,1.8)),11.2)]
  if kind in ['bite','roar','jaw_sweep']:views.append(('head',Vector((-1,1,.3)).normalized(),Vector((0,2.2,2.1)),4.5))
  if kind in ['walk','run','turn'] and idx in selected[kind][::3]:views.append(('feet',Vector((-1,1,.15)).normalized(),Vector((0,.4,.45)),3.2))
  for name,D,center,scale in views:
   cd.ortho_scale=scale;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(out/f'{kind}_{idx:03d}_{name}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
for n,m in saved.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert coords0==[list(v.co) for v in o.data.vertices];assert sha==hashlib.sha256(src.read_bytes()).hexdigest()
summary={}
for kind in selected:
 rows=[x for x in metrics if x['sequence']==kind];summ={side:{'all_frames_min_height':min(x['foot_min_height'][side] for x in rows),'support_samples_min_height':min((x['foot_min_height'][side] for x in rows if not x['swing'][0 if side=='_l' else 1]),default=None),'support_samples_max_min_height':max((x['foot_min_height'][side] for x in rows if not x['swing'][0 if side=='_l' else 1]),default=None)} for side in feet};summary[kind]=summ
(p/'audit_metrics.json').write_text(json.dumps({'source_sha256':sha,'source_unchanged':True,'rest_mapping_error':resterror,'pose_replay_error':posemax,'bones':len(bones),'pose_restored':True,'ground_plane_z':0,'foot_minimum_scope':'all foot/toe weighted mesh points incl claws; pair flags are triangle intersections, not volume certification','sequence_summary':summary,'samples':metrics,'original_Trex_control_foot_samples':control_rows,'driver':'isolated Godot unaltered trex.gd direct procedural calls; not game/player input','selected_frames':selected},indent=2));print('AUDIT_REPLAY_PASS',json.dumps(summary))
