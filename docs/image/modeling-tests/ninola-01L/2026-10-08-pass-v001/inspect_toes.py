import bpy,json
from pathlib import Path
p=Path(__file__).resolve().parent;r=p.parents[4]
bpy.ops.wm.open_mainfile(filepath=str(r/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend'))
a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();c=[list(a.matrix_world@v.co) for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
d={'vertices':[{'id':i,'co':x,'weights':{a.vertex_groups[g.group].name:g.weight for g in a.data.vertices[i].groups}} for i,x in enumerate(c) if abs(x[0])>.35 and x[2]<.4],'faces':[{'id':f.index,'ids':list(f.vertices),'material':f.material_index} for f in a.data.polygons], 'materials':[m.name for m in a.data.materials], 'bones':{b.name:{'head':list(rig.matrix_world@b.head),'tail':list(rig.matrix_world@b.tail)} for b in rig.pose.bones if any(t in b.name.lower() for t in ['toe','claw','foot','dew'])}}
(p/'toe_inspection.json').write_text(json.dumps(d));print(json.dumps({'materials':d['materials'],'bones':d['bones']},indent=2))
