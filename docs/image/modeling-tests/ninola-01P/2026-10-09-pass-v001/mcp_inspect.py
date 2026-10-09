import bpy,json
from pathlib import Path
from mathutils import Vector
p=Path('/Users/ChenPo-Yun/Documents/GameDev/worktrees/ninola/docs/image/modeling-tests/ninola-01P/2026-10-09-pass-v001')
ns=bpy.app.driver_namespace;assert '_p1_review' not in ns
state={'scene':bpy.context.window.scene,'active':bpy.context.view_layer.objects.active,'selected':list(bpy.context.selected_objects),'dirty':bpy.data.is_dirty,'file':bpy.data.filepath,'views':[]}
for area in bpy.context.screen.areas:
 if area.type=='VIEW_3D':
  sp=area.spaces.active;rv=sp.region_3d;state['views'].append((sp,rv,rv.view_location.copy(),rv.view_rotation.copy(),rv.view_distance,rv.view_perspective,sp.shading.color_type))
data=json.loads((p/'inspection_geometry.json').read_text());sc=bpy.data.scenes.new('Temporary_P1_v002_Inspection');me=bpy.data.meshes.new('Temporary_P1_v002_Display');me.from_pydata(data['vertices'],[],data['faces']);me.update();ob=bpy.data.objects.new('Temporary_P1_v002_Display',me);sc.collection.objects.link(ob);materials=[]
for i,color in enumerate(data['material_colors']):
 mat=bpy.data.materials.new('Temporary_P1_v002_Color_'+str(i));mat.diffuse_color=color;me.materials.append(mat);materials.append(mat)
for f,i in zip(me.polygons,data['material_indices']):f.material_index=i
state.update({'temp':sc,'object':ob,'mesh':me,'materials':materials});ns['_p1_review']=state;bpy.context.window.scene=sc
for sp,rv,*_ in state['views']:
 rv.view_location=Vector((.62,1.66,1.16));rv.view_distance=.75;rv.view_rotation=Vector((1,1,-.5)).to_track_quat('Z','Y');rv.view_perspective='PERSP';sp.shading.color_type='MATERIAL'
print('Temporary P1 v002 evaluated display only, no source saved.')
