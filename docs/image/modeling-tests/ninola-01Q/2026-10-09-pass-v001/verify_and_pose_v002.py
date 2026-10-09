import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'build_record_v002.json').read_text());src=r/rec['output_path'];source=r/rec['source_path'];mask=json.loads((p/'edit_mask_v002.json').read_text());changed={i for ch in mask['changes'] for i in ch['vertex_ids']};camrec=json.loads((p.parent/'2026-10-09-review-v001/capture_settings.json').read_text())['tail_oblique'];checks=[];out=p/'pose-captures';out.mkdir(exist_ok=True)
# Readback protects exact bind data and original production keys/rest/pose channels.
def state(path,name):
 bpy.ops.wm.open_mainfile(filepath=str(path));o=bpy.data.objects[name];rig=bpy.data.objects['TrexRig'];return {'coords':[list(v.co) for v in o.data.vertices],'weights':[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices],'faces':[(list(f.vertices),f.material_index) for f in o.data.polygons],'bones':[(b.name,b.parent.name if b.parent else None,[list(row) for row in b.matrix_local]) for b in rig.data.bones],'pose':[(b.name,list(b.location),list(b.rotation_quaternion),list(b.rotation_euler),list(b.scale),b.rotation_mode) for b in rig.pose.bones],'keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in bpy.data.objects['Trex'].data.shape_keys.key_blocks]}
A=state(source,'01P1_Palm_Digit_Continuity');B=state(src,rec['object']);assert all(A[k]==B[k] for k in ['weights','faces','bones','pose','keys']);assert all(A['coords'][i]==B['coords'][i] for i in range(len(A['coords'])) if i not in changed)
for test,bone,axis,angle in [('tail3_yaw_plus12','tail3','Z',12),('tail3_yaw_minus12','tail3','Z',-12),('tail4_pitch_plus8','tail4','X',8)]:
 bpy.ops.wm.open_mainfile(filepath=str(src));ob=bpy.data.objects[rec['object']];a=bpy.data.objects['01P1_Palm_Digit_Continuity'];rig=bpy.data.objects['TrexRig'];b=rig.pose.bones[bone];b.matrix_basis=b.matrix_basis@Matrix.Rotation(math.radians(angle),4,axis);bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();aa=[a.matrix_world@v.co for v in a.evaluated_get(dep).data.vertices];bb=[ob.matrix_world@v.co for v in ob.evaluated_get(dep).data.vertices];delta=max((aa[i]-bb[i]).length for i in range(len(aa)) if i not in changed);assert delta<1e-6
 newdeg=[];reversals=[]
 for fi,f in enumerate(ob.data.polygons):
  inds=list(f.vertices)
  if not any(i in changed for i in inds):continue
  x,y,z=inds[:3];na=(aa[y]-aa[x]).cross(aa[z]-aa[x]);nb=(bb[y]-bb[x]).cross(bb[z]-bb[x])
  if nb.length<1e-10 and na.length>=1e-10:newdeg.append(fi)
  if na.dot(nb)<0:reversals.append(fi)
 assert not newdeg and not reversals
 checks.append({'test':test,'bone':bone,'axis':'local '+axis,'angle_degrees':angle,'protected_vertices_max_delta':delta,'new_degenerate_faces':newdeg,'normal_reversals_against_same_pose_source':reversals})
 sc=bpy.context.scene;sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='SINGLE';sh.single_color=(.6,.64,.68);sh.show_cavity=True
 cd=bpy.data.cameras.new('IsolatedTailPoseCamera');cam=bpy.data.objects.new('IsolatedTailPoseCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cam.matrix_world=Matrix(camrec['matrix']);cd.type='ORTHO';cd.ortho_scale=6.6
 for label,model in [('source',a),('Q1',ob)]:
  for obj in sc.objects:
   if obj.type=='MESH':obj.hide_render=obj!=model
  sc.render.filepath=str(out/f'{test}_{label}.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(src.read_bytes()).hexdigest()==rec['sha256'];assert hashlib.sha256(source.read_bytes()).hexdigest()==rec['source_sha256'];(p/'readback_and_pose_verification_v002.json').write_text(json.dumps({'readback_coordinates_outside_edit_exact':True,'readback_topology_material_weights_Rig_keys_pose_exact':True,'source_hash_unchanged':True,'trial_hash_unchanged':True,'checks':checks,'real_game_tested':False,'full_tail_motion_collision_self_intersection_verified':False},indent=2));print('Q1 readback and three isolated poses passed limited checks')
