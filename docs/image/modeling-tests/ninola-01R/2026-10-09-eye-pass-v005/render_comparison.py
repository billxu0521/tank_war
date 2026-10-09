import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'build_record.json').read_text());settings={}
for label,path,name in [('before','blender/ninola/working/01R2/2026-10-09-v004/ninola_01R2_gold_slit_eye.blend','01R2_Gold_Slit_Eye'),('trial',rec['output_path'],rec['object'])]:
 src=r/path;originalhash=hashlib.sha256(src.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[name];bpy.context.view_layer.update();co=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
 sc=bpy.data.scenes.new('ReadonlyEyeTrial');sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=800;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='MATERIAL';sh.show_cavity=False;sh.show_shadows=False;sh.background_type='WORLD';sc.world=bpy.data.worlds.new('ReviewBG');sc.world.color=(.065,.075,.09)
 cd=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO'
 def showmesh(ids,faces,materials,smooth=False):
  me=bpy.data.meshes.new('ReadonlyEvaluated');mapping={i:j for j,i in enumerate(ids)};me.from_pydata([co[i] for i in ids],[],[[mapping[i] for i in f.vertices] for f in faces]);me.update();obj=bpy.data.objects.new('ReadonlyEvaluated',me);sc.collection.objects.link(obj)
  for m in o.data.materials:me.materials.append(m)
  for f,srcf in zip(me.polygons,faces):f.material_index=srcf.material_index;f.use_smooth=smooth or srcf.use_smooth
  return obj
 globe=[f for f in o.data.polygons if any(k in o.data.materials[f.material_index].name.lower() for k in ['eye','iris','pupil']) and all(co[i].x>0 for i in f.vertices)]
 ids=sorted({i for f in globe for i in f.vertices});eye=showmesh(ids,globe,None)
 C=Vector(rec['eyes'][1]['sphere_center']);F=Vector((1,0,0));U=Vector((0,1,0))
 views=[('eye_forward',F,C,.135),('eye_oblique',(F+U*.65).normalized(),C,.135)]
 for view,D,center,scale in views:
  cd.ortho_scale=scale;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/f'{label}_{view}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
 eye.hide_render=True;whole=showmesh(list(range(len(co))),list(o.data.polygons),None)
 for view,D,center,scale in [('installed_side',Vector((1,0,0)),Vector((.35,2.98,2.435)),.38),('installed_other_side',Vector((-1,0,0)),Vector((-.35,2.98,2.435)),.38),('installed_front',Vector((.25,1,.05)).normalized(),Vector((.35,2.98,2.435)),.38),('installed_close',Vector((1,1,.12)).normalized(),Vector((.35,2.98,2.435)),.38),('head_threequarter',Vector((1,1,.25)).normalized(),Vector((0,2.65,2.17)),2.7),('head_side',Vector((1,0,0)),Vector((0,2.65,2.17)),2.7),('head_front',Vector((0,1,0)),Vector((0,2.65,2.17)),2.7)]:
  cd.ortho_scale=scale;cam.location=center+D*20;cam.rotation_euler=(-D).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/f'{label}_{view}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
 assert hashlib.sha256(src.read_bytes()).hexdigest()==originalhash
print('18 actual evaluated model comparison renders; input files unchanged')
