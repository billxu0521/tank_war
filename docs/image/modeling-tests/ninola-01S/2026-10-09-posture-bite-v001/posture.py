import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01R2/2026-10-09-v005/ninola_01R2_gold_slit_eye.blend';sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01R2_Gold_Slit_Eye'];rig=bpy.data.objects['TrexRig'];saved={b.name:b.matrix_basis.copy() for b in rig.pose.bones};rest={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones};weights=[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices];bind=[list(v.co) for v in o.data.vertices];records=[];faces=[list(f.vertices) for f in o.data.polygons]
sc=bpy.data.scenes.new('ReadonlyPosture');sc.world=bpy.data.worlds.new('PostureBG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=1200;sc.render.resolution_y=800;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sc.display.shading.color_type='MATERIAL';sc.display.shading.show_cavity=False;sc.display.shading.show_shadows=False;me=bpy.data.meshes.new('PoseDisplay');ob=bpy.data.objects.new('PoseDisplay',me);sc.collection.objects.link(ob);cd=bpy.data.cameras.new('PostureCamera');cam=bpy.data.objects.new('PostureCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO'
for label,neck,head in [('baseline',0,0),('A',6,-2),('B',12,-4)]:
 for n,m in saved.items():rig.pose.bones[n].matrix_basis=m
 bpy.context.view_layer.update()
 for name,angle in [('neck',neck),('head',head)]:
  b=rig.pose.bones[name];P=b.matrix.copy();h=P.translation.copy();b.matrix=Matrix.Translation(h)@Matrix.Rotation(math.radians(angle),4,'X')@Matrix.Translation(-h)@P;bpy.context.view_layer.update()
 c=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];me.clear_geometry();me.from_pydata(c,[],faces);me.update();me.materials.clear()
 for m in o.data.materials:me.materials.append(m)
 for f,old in zip(me.polygons,o.data.polygons):f.material_index=old.material_index;f.use_smooth=old.use_smooth
 records.append({'label':label,'neck_world_pitch_delta_degrees':neck,'head_world_pitch_delta_degrees':head,'spine_delta':0,'head_origin_world':list(rig.matrix_world@rig.pose.bones['head'].head),'pose_scope':'temporary evaluation only, source saved rest/current pose unchanged'})
 for view,D in [('side',Vector((-1,0,0))),('oblique',Vector((-1,1,.25)).normalized())]:
  center=Vector((0,-.75,1.9));cd.ortho_scale=11.1;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/f'posture_{label}_{view}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
for n,m in saved.items():rig.pose.bones[n].matrix_basis=m
bpy.context.view_layer.update();assert rest=={b.name:[list(v) for v in b.matrix_local] for b in rig.data.bones};assert bind==[list(v.co) for v in o.data.vertices];assert weights==[[(g.group,g.weight) for g in v.groups] for v in o.data.vertices];assert sha==hashlib.sha256(src.read_bytes()).hexdigest();(p/'posture_record.json').write_text(json.dumps({'source':str(src.relative_to(r)),'source_sha256':sha,'rest_mesh_weights_source_exact':True,'pose_restored':True,'candidates':records,'not_game_motion_validation':True},indent=2));print('POSTURE_READONLY_PASS')
