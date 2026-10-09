import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
r=Path.cwd();p=Path(__file__).resolve().parent;out=p/'captures';out.mkdir(exist_ok=True);src=r/'blender/ninola/working/01O2/2026-10-09-v003/ninola_01O2_ventral_belly_tuck.blend';sha=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects['01O2_Ventral_Belly_Tuck'];bpy.context.view_layer.update();c=[list(o.matrix_world@v.co) for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];f=[list(x.vertices) for x in o.data.polygons];w=[{o.vertex_groups[g.group].name:g.weight for g in v.groups} for v in o.data.vertices];limb=lambda i:sum(v for n,v in w[i].items() if n.startswith(('arm_','forearm_','hand_','finger')))
# Mask only for visibility: majority arm skin and claws, with attachment cuts explicitly recorded.
ids={side:[fi for fi,face in enumerate(f) if all(limb(i)>.35 and c[i][0]*side>.10 for i in face)] for side in [-1,1]}
sc=bpy.data.scenes.new('Temporary_01P_Readonly');sc.world=bpy.data.worlds.new('Temporary_01P_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True;sh.color_type='MATERIAL';sh.single_color=(.6,.64,.68);me=bpy.data.meshes.new('Temporary_01P_Display');ob=bpy.data.objects.new('Temporary_01P_Display',me);sc.collection.objects.link(ob)
for mat in o.data.materials:me.materials.append(mat)
cd=bpy.data.cameras.new('Temporary_01P_Camera');cam=bpy.data.objects.new('Temporary_01P_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam
views={'left_outer':((1,0,0),(.63,1.46,1.38),1.4,1),'right_outer':((-1,0,0),(-.63,1.46,1.38),1.4,-1),'left_front':((0,1,0),(.63,1.46,1.38),1.4,1),'left_palm':((-1,1,-.5),(.63,1.46,1.38),1.4,1),'left_top':((0,0,1),(.63,1.46,1.38),1.4,1),'right_palm':((1,1,-.5),(-.63,1.46,1.38),1.4,-1),'left_oblique':((1,1,.15),(.63,1.46,1.38),1.4,1),'right_oblique':((-1,1,.15),(-.63,1.46,1.38),1.4,-1),'arm_context':((1,1,-.2),(0,1.4,1.3),3.2,0),'arm_context_side':((1,0,0),(0,1.4,1.35),2.5,0)}
views={'left_hand_unmasked':((1,1,-.65),(.62,1.66,1.16),.85,0),'right_hand_unmasked':((-1,1,-.65),(-.62,1.66,1.16),.85,0),'left_hand_front_unmasked':((0,1,-.15),(.62,1.66,1.16),.7,0)}
record=json.loads((p/'capture_settings.json').read_text())
for view,(di,center,scale,side) in views.items():
 keep=ids[side] if side else list(range(len(f)));me.clear_geometry();me.from_pydata(c,[],[f[i] for i in keep]);me.update()
 for poly,fi in zip(me.polygons,keep):poly.material_index=o.data.polygons[fi].material_index
 sh.color_type='SINGLE' if view=='left_palm' else 'MATERIAL';di=Vector(di).normalized();cd.type='ORTHO';cd.ortho_scale=scale;cam.location=Vector(center)+di*20;cam.rotation_euler=(-di).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();dest=out/f'{view}.png';sc.render.filepath=str(dest)
 if not dest.exists():bpy.ops.render.render(write_still=True,scene=sc.name)
 record[view]={'matrix':[list(row) for row in cam.matrix_world],'scale':scale,'resolution':[1100,1100],'display_mask':'arm/hand only, majority influence>.35; upper attachment cut is a viewing artifact' if side else 'complete isolated prototype','display_face_ids':keep,'side':side}
# Retain full-body read-only captures using exact camera settings from approved source review.
settings=json.loads((r/'docs/image/modeling-tests/ninola-01O/2026-10-09-belly-v001/captures-v003/capture_settings_01O2.json').read_text())
# Exact camera record for the accepted O2 object.
for view in []:
 rec=settings[view];me.clear_geometry();me.from_pydata(c,[],f);me.update()
 for poly,orig in zip(me.polygons,o.data.polygons):poly.material_index=orig.material_index
 from mathutils import Matrix
 cam.matrix_world=Matrix(rec['matrix']);cd.type=rec['camera_type'];cd.ortho_scale=rec['scale'];sh.color_type='SINGLE' if view=='full_body_side' else 'MATERIAL';sc.view_layers[0].update();sc.render.filepath=str(out/f'{view}.png');bpy.ops.render.render(write_still=True,scene=sc.name);record[view]=rec
rig=bpy.data.objects['TrexRig'];armbones={b.name:{'head_world':list(rig.matrix_world@b.head),'tail_world':list(rig.matrix_world@b.tail),'parent':b.parent.name if b.parent else None} for b in rig.pose.bones if b.name.startswith(('arm_','forearm_','hand_','finger'))}
assert hashlib.sha256(src.read_bytes()).hexdigest()==sha
(p/'capture_settings.json').write_text(json.dumps(record,indent=2));(p/'inspection.json').write_text(json.dumps({'source':str(src.relative_to(r)),'sha256':sha,'source_unchanged':True,'prototype_object':o.name,'bone_count':len(rig.data.bones),'arm_bones':armbones,'masked_face_counts':{str(k):len(v) for k,v in ids.items()},'arm_vertices':{str(side):{str(i):c[i] for fi in ids[side] for i in f[fi]} for side in [-1,1]},'masked_topology_is_display_only':True,'source_pose_edited':False,'external_libraries':[l.filepath for l in bpy.data.libraries]},indent=2));print('01P readonly captures complete')
