import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view
p=Path(__file__).resolve().parent;r=p.parents[4]
bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend'))
rig=bpy.data.objects['TrexRig'];a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];bpy.context.view_layer.update();s=bpy.context.scene;s.render.resolution_x=s.render.resolution_y=1100;s.render.resolution_percentage=100
settings=json.loads((r/'docs/image/modeling-tests/ninola-01L/2026-10-08-review-v001/captures/capture_settings_01K6.json').read_text())['foot_top'];cd=bpy.data.cameras.new('DiagramProjection');cam=bpy.data.objects.new('DiagramProjection',cd);s.collection.objects.link(cam);cd.type='ORTHO';cd.ortho_scale=settings['scale'];cam.matrix_world=Matrix(settings['matrix']);s.camera=cam;s.view_layers[0].update()
def project(v):
 q=world_to_camera_view(s,cam,Vector(v));return [q.x*1100,(1-q.y)*1100]
bones={b.name:{'head_world':list(rig.matrix_world@b.head),'tail_world':list(rig.matrix_world@b.tail),'head_px':project(rig.matrix_world@b.head),'tail_px':project(rig.matrix_world@b.tail)} for b in rig.pose.bones if b.name.startswith('toe') and b.name.endswith('_l')}
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];claw=[]
for n in [1,2,3]:
 ids={i for f in a.data.polygons if a.data.materials[f.material_index].name=='d_claw' for i in f.vertices if c[i].x>0 and any(a.vertex_groups[g.group].name.startswith('toe'+str(n)+'_') and g.weight>.5 for g in a.data.vertices[i].groups)}
 tip=max(ids,key=lambda i:c[i].y);claw.append({'toe':n,'tip_id':tip,'world':list(c[tip]),'px':project(c[tip])})
landmarks={};paths={}
# Designer intent paths are a schematic, not geometry or new anchor positions.
for n,coords in {'inner':[(.61,.25,.2),(.575,.40,.2),(.54,.55,.2),(.50,.70,.2)],'middle':[(.715,.25,.2),(.725,.43,.2),(.75,.68,.2),(.78,.93,.2)],'outer':[(.82,.25,.2),(.885,.40,.2),(.98,.55,.2),(1.02,.70,.2)]}.items():paths[n]=[project(q) for q in coords]
for n,q in {'root_center':(.72,.23,.2),'web_inner':(.65,.43,.2),'web_outer':(.82,.43,.2),'shaft':(.68,.07,.3)}.items():landmarks[n]=project(q)
d={'model':'01K6 v003','object':a.name,'projection_view':'foot_top','camera':settings,'actual_bones':bones,'actual_claw_tips':claw,'schematic_paths_px':paths,'schematic_landmarks_px':landmarks,'actual_ground_anchor_samples':[{'id':i,'world':list(c[i]),'px':project(c[i])} for i in json.loads((r/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/source-records/zone_vertices.json').read_text())['L_anchor_retained']], 'note':'planned paths and corridors are illustrative; only actual bones/claw tips are projected verified positions; no Blender save'}
(p/'landmarks.json').write_text(json.dumps(d,indent=2));print(json.dumps({'bones':bones,'tips':claw,'paths':paths}))
