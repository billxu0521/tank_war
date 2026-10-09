import bpy,json,hashlib,math,ast
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01R2/2026-10-09-v005/ninola_01R2_gold_slit_eye.blend';sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));rig=bpy.data.objects['TrexRig'];o=bpy.data.objects['01R2_Gold_Slit_Eye'];saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};rest={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones};R=rig.matrix_world.copy();C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));data=json.loads((p/'bite_samples.json').read_text());faces=[list(f.vertices) for f in o.data.polygons];w=[{o.vertex_groups[t.group].name:t.weight for t in v.groups} for v in o.data.vertices];mn=[o.data.materials[f.material_index].name for f in o.data.polygons];soft=['d_olive','d_moss','d_tan','d_belly','d_mouth'];sets={'jaw_soft':[i for i,f in enumerate(faces) if mn[i] in soft and all(w[j].get('jaw',0)>.99 for j in f)],'head_soft':[i for i,f in enumerate(faces) if mn[i] in soft and all(w[j].get('head',0)>.5 for j in f)],'jaw_teeth':[i for i,f in enumerate(faces) if mn[i]=='d_bone' and all(w[j].get('jaw',0)>.9 for j in f)],'head_teeth':[i for i,f in enumerate(faces) if mn[i]=='d_bone' and all(w[j].get('head',0)>.5 for j in f)]}
tree=ast.parse((p.parent/'2026-10-09-occlusion-v001/diagnose.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['bary','crossings']],type_ignores=[]),'contact_functions','exec'))
resterror=max(max(abs((C@Matrix(data['rest'][b.name]['matrix']))[i][j]-(R@b.matrix_local)[i][j]) for i in range(4) for j in range(4)) for b in rig.data.bones);assert resterror<5e-6
sc=bpy.data.scenes.new('ReadonlyBiteTrial');sc.world=bpy.data.worlds.new('BiteBG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1000;sc.render.resolution_y=750;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sc.display.shading.color_type='MATERIAL';sc.display.shading.show_cavity=False;sc.display.shading.show_shadows=False;me=bpy.data.meshes.new('BiteDisplay');ob=bpy.data.objects.new('BiteDisplay',me);sc.collection.objects.link(ob);cd=bpy.data.cameras.new('BiteCamera');cam=bpy.data.objects.new('BiteCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO';rows=[];posemax=0
samples=[('sweep',s) for s in data['sweeps']]+[(key,s) for key,seq in data['cycles'].items() for s in seq]
for seq,s in samples:
 W=Matrix(s['skeleton_world']);targets={b.name:R.inverted()@C@W@Matrix(s['bones'][b.name]) for b in rig.data.bones}
 for b in rig.data.bones:rig.pose.bones[b.name].matrix=targets[b.name];bpy.context.view_layer.update()
 err=max(max(abs(rig.pose.bones[n].matrix[i][j]-m[i][j]) for i in range(4) for j in range(4)) for n,m in targets.items());posemax=max(posemax,err);assert err<3e-5
 c=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];row={'sequence':seq,'frame':s['frame'],'neutral_degrees':s['degrees'],'soft':0,'teeth':0,'soft_pairs':[]}
 for key,A,B in [('soft','jaw_soft','head_soft'),('teeth','jaw_teeth','head_teeth')]:
  pairs=BVHTree.FromPolygons(c,[faces[i] for i in sets[A]]).overlap(BVHTree.FromPolygons(c,[faces[i] for i in sets[B]]))
  for ia,ib in pairs:
   fa,fb=sets[A][ia],sets[B][ib]
   if crossings(c,faces[fa],faces[fb]):
    row[key]+=1
    if key=='soft':row['soft_pairs'].append({'face_ids':[fa,fb],'materials':[mn[fa],mn[fb]]})
 rows.append(row)
 if seq=='sweep' and s['degrees'] in [1.0,1.5,2.0,2.29] or seq=='1.5' and s['frame'] in [0,12,29,30,31,32,34,45,60,90,119]:
  me.clear_geometry();me.from_pydata(c,[],faces);me.update();me.materials.clear()
  for m in o.data.materials:me.materials.append(m)
  for f,old in zip(me.polygons,o.data.polygons):f.material_index=old.material_index;f.use_smooth=old.use_smooth
  center=Vector((0,2.7,2.15));D=Vector((-1,1,.20)).normalized();cd.ortho_scale=3.4;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/f'bite_{seq}_{s["frame"]:03d}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
for n,m in saved.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert rest=={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones};assert sha==hashlib.sha256(src.read_bytes()).hexdigest();summary={key:{'frames':len(seq),'soft_max':max(z['soft'] for z in rows if z['sequence']==key),'teeth_max':max(z['teeth'] for z in rows if z['sequence']==key),'soft_nonzero_frames':sum(z['soft']>0 for z in rows if z['sequence']==key)} for key,seq in data['cycles'].items()};(p/'bite_metrics.json').write_text(json.dumps({'source':str(src.relative_to(r)),'sha256':sha,'source_unchanged':True,'rest_and_pose_restored':True,'rest_mapping_error':resterror,'pose_replay_error':posemax,'candidate':1.5,'original_driver_neutral_degrees':math.degrees(.12),'note':'candidate changes eval-only neutral jaw base, preserving action terms; not merely an inactive cap on existing 6.88 degree idle','sweep_rows':[z for z in rows if z['sequence']=='sweep'],'cycle_summary':summary,'rows':rows,'not_complete_collision_or_game_acceptance':True},indent=2));print('BITE_TEST_COMPLETE',json.dumps(summary))
