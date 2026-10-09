import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
r=Path.cwd();p=Path(__file__).resolve().parent;rec=json.loads((p/'inspection.json').read_text());src=r/rec['path'];bpy.ops.wm.open_mainfile(filepath=str(src));o=bpy.data.objects[rec['object']];bpy.context.view_layer.update();c=[o.matrix_world@v.co for v in o.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];ff=[f for f in o.data.polygons if any(k in o.data.materials[f.material_index].name.lower() for k in ['eye','iris','pupil']) and all(c[i].x>0 for i in f.vertices)];ids=sorted({i for f in ff for i in f.vertices});mapping={v:i for i,v in enumerate(ids)};pts=[c[i] for i in ids];center=sum(pts,Vector())/len(pts);F=(Vector((0,10.55,center.z))-center).normalized();U=Vector((1,0,0));U=(U-F*U.dot(F)).normalized()
sc=bpy.data.scenes.new('ReadonlyEyeInspection');sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=600;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.color_type='MATERIAL';sh.show_cavity=False;sh.show_shadows=False;sh.background_type='WORLD';sc.world=bpy.data.worlds.new('EyeInspectionBG');sc.world.color=(.08,.09,.11)
me=bpy.data.meshes.new('EvaluatedEyeOnly');me.from_pydata(pts,[],[[mapping[i] for i in f.vertices] for f in ff]);me.update();ob=bpy.data.objects.new('EvaluatedEyeOnly',me);sc.collection.objects.link(ob)
for m in o.data.materials:me.materials.append(m)
for f,srcf in zip(me.polygons,ff):f.material_index=srcf.material_index
cd=bpy.data.cameras.new('EyeCamera');cam=bpy.data.objects.new('EyeCamera',cd);sc.collection.objects.link(cam);sc.camera=cam;cd.type='ORTHO';cd.ortho_scale=.14
for name,dir in [('current_eye_forward',F),('current_eye_oblique',(F+U*.65).normalized())]:
 cam.location=center+dir*2;cam.rotation_euler=(-dir).to_track_quat('-Z','Y').to_euler();sc.view_layers[0].update();sc.render.filepath=str(p/(name+'.png'));bpy.ops.render.render(write_still=True,scene=sc.name)
assert hashlib.sha256(src.read_bytes()).hexdigest()==rec['sha256'];(p/'capture.json').write_text(json.dumps({'mesh':'one actual evaluated eyeball isolated, original unchanged','vertices':len(ids),'triangles':sum(len(f.vertices)-2 for f in ff),'center':list(center),'gaze_axis':list(F),'render':'Workbench Standard studio, not game/PBR verification'},indent=2))
