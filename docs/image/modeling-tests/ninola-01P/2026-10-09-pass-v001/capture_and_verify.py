import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
r=Path.cwd();p=Path(__file__).resolve().parent;record=json.loads((p/'build_record_v002.json').read_text());src=r/record['output'];sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[record['object']];a=bpy.data.objects['01O2_Ventral_Belly_Tuck'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();c=[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];f=[list(x.vertices) for x in o.data.polygons];w=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];limb=lambda i:sum(v for n,v in w[i].items() if n.startswith(('arm_','forearm_','hand_','finger')))
sc=bpy.data.scenes.new('Temporary_01P_Render');sc.world=bpy.data.worlds.new('Temporary_01P_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True;sh.single_color=(.6,.64,.68);me=bpy.data.meshes.new('Temporary_01P_Display');ob=bpy.data.objects.new('Temporary_01P_Display',me);sc.collection.objects.link(ob)
for mat in o.data.materials:me.materials.append(mat)
cd=bpy.data.cameras.new('Temporary_01P_Camera');cam=bpy.data.objects.new('Temporary_01P_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam
settings=json.loads((p.parent/'2026-10-09-review-v001/capture_settings.json').read_text());used=['left_hand_front_unmasked','left_hand_unmasked','right_hand_unmasked','left_palm','right_palm','left_outer','left_top','arm_context','full_body_side','full_body_front'];out=p/'captures';out.mkdir(exist_ok=True)
for view in used:
 rec=settings[view];side=rec.get('side',0);keep=[fi for fi,face in enumerate(f) if all(limb(i)>.35 and c[i][0]*side>.1 for i in face)] if side else list(range(len(f)));me.clear_geometry();me.from_pydata(c,[],[f[i] for i in keep]);me.update()
 for poly,fi in zip(me.polygons,keep):poly.material_index=o.data.polygons[fi].material_index
 sh.color_type='SINGLE' if view in ['left_palm','full_body_side'] else 'MATERIAL';cam.matrix_world=Matrix(rec['matrix']);cd.type=rec.get('camera_type','ORTHO');cd.ortho_scale=rec['scale'];cd.lens=rec.get('lens',50);sc.view_layers[0].update();sc.render.filepath=str(out/f'{view}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
# Evaluate exact source and retained claw roots in isolated test poses; never save.
checks=[]
for test,angle in [('hand_plus15',15),('hand_minus15',-15),('finger1_plus15',15)]:
 bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[record['object']];a=bpy.data.objects['01O2_Ventral_Belly_Tuck'];rig=bpy.data.objects['TrexRig']
 for side in ['l','r']:
  b=rig.pose.bones[f'{"finger1" if test.startswith("finger") else "hand"}_{side}'];b.matrix_basis=b.matrix_basis@Matrix.Rotation(math.radians(angle),4,'X')
 bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();av=[a.matrix_world@v.co for v in a.evaluated_get(dep).data.vertices];ov=[o.matrix_world@v.co for v in o.evaluated_get(dep).data.vertices];delta=max((av[i]-ov[i]).length for i in range(len(av)));assert delta<1e-6
 checks.append({'test':test,'original_vertex_max_delta':delta,'claw_root_coordinate_and_weights_exact':True,'scope':'artificial local pose, not game animation'})
 # Dedicated masked render camera in the current process, source file untouched.
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.display.shading.color_type='SINGLE';scene.display.shading.single_color=(.6,.64,.68)
 for obj in scene.objects:
  if obj.type=='MESH':obj.hide_render=obj!=o
 data=bpy.data.cameras.new('TestPoseCamera');camera=bpy.data.objects.new('TestPoseCamera',data);scene.collection.objects.link(camera);scene.camera=camera;camera.matrix_world=Matrix(settings['left_hand_unmasked']['matrix']);data.type='ORTHO';data.ortho_scale=.85;scene.render.filepath=str(out/f'{test}.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(src.read_bytes()).hexdigest()==sha
(p/'limited_pose_verification.json').write_text(json.dumps({'source_hash_unchanged':True,'readback_original_vertex_count':len(av),'original_coordinates_retained':True,'checks':checks,'real_game_tested':False,'full_grasp_animation_verified':False},indent=2));(p/'capture_settings.json').write_text(json.dumps({k:{a:b for a,b in settings[k].items() if a!='display_face_ids'} for k in used},indent=2));print('01P1 capture and limited pose verification complete')
