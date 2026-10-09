import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Matrix,Vector
r=Path.cwd();p=Path(__file__).resolve().parent;s=p.parent/'2026-10-09-review-v001';g=json.loads((s/'source_geometry.json').read_text());ins=json.loads((s/'inspection.json').read_text());cams=json.loads((s/'capture_settings.json').read_text());source=r/ins['source'];before=hashlib.sha256(source.read_bytes()).hexdigest();assert before==ins['sha256'];bpy.ops.wm.open_mainfile(filepath=str(source));o=bpy.data.objects['01Q1_Tail_Taper'];skin={'d_olive','d_tan','d_moss','d_belly'};groups={};labels={};colors={'nasal':(.36,.27,.13,1),'muzzle_side':(.43,.34,.17,1),'rear_cranium':(.30,.25,.12,1),'lower_cheek':(.28,.23,.13,1),'jaw_side':(.45,.34,.19,1),'jaw_lower':(.32,.25,.14,1)}
for fi,f in enumerate(g['faces']):
 w={n:sum(g['weights'][i].get(n,0) for i in f)/len(f) for n in ['head','jaw']};c=sum((Vector(g['vertices'][i]) for i in f),Vector())/len(f)
 if g['materials'][fi] not in skin or c.y<1.85:continue
 if w['jaw']>.55:name='jaw_lower' if c.z<1.75 else 'jaw_side'
 elif w['head']>.55:
  name='rear_cranium' if c.y<2.3 else 'nasal' if c.z>2.23 and abs(c.x)<.38 else 'lower_cheek' if c.y<2.7 and c.z<2.18 else 'muzzle_side'
 else:continue
 labels[str(fi)]=name;groups.setdefault(name,[]).append(fi)
sc=bpy.data.scenes.new('Temporary_R1_Grouping');sc.world=bpy.data.worlds.new('Temporary_R1_BG');sc.world.color=(.075,.085,.1);sc.render.engine='BLENDER_WORKBENCH';sc.render.resolution_x=sc.render.resolution_y=1100;sc.render.resolution_percentage=100;sc.view_settings.view_transform='Standard';sh=sc.display.shading;sh.light='STUDIO';sh.show_shadows=False;sh.show_cavity=True;sh.color_type='MATERIAL';me=bpy.data.meshes.new('Temporary_R1_Display');me.from_pydata(g['vertices'],[],g['faces']);me.update();ob=bpy.data.objects.new('Temporary_R1_Display',me);sc.collection.objects.link(ob)
for m in o.data.materials:me.materials.append(m)
for f,orig in zip(me.polygons,o.data.polygons):f.material_index=orig.material_index
indices={}
for n,col in colors.items():
 m=bpy.data.materials.new('Temporary_R1_'+n);m.diffuse_color=col;indices[n]=len(me.materials);me.materials.append(m)
cd=bpy.data.cameras.new('Temporary_R1_Camera');cam=bpy.data.objects.new('Temporary_R1_Camera',cd);sc.collection.objects.link(cam);sc.camera=cam;out=p/'captures';out.mkdir(exist_ok=True)
for view in ['head_side','head_front','head_threequarter','head_top','head_body_context','full_left_oblique']:
 rec=cams[view];cam.matrix_world=Matrix(rec['matrix']);cd.type='ORTHO';cd.ortho_scale=rec['scale'];sc.view_layers[0].update()
 for mode in ['source','grouping']:
  for fi,f in enumerate(me.polygons):f.material_index=indices[labels[str(fi)]] if mode=='grouping' and str(fi) in labels else o.data.polygons[fi].material_index
  sc.render.filepath=str(out/f'{view}_{mode}.png');bpy.ops.render.render(write_still=True,scene=sc.name)
assert hashlib.sha256(source.read_bytes()).hexdigest()==before;(p/'grouping_spec.json').write_text(json.dumps({'role':'same_geometry_material_grouping_schematic_not_model_edit','source':ins['source'],'source_sha256':before,'face_groups':groups,'palette_linear_rgba':colors,'geometry_modified':False,'normals_modified':False,'source_materials_modified':False,'triangles_saved':0,'boundary_groups_are_proposals':True,'eyes_teeth_mouth_spines_preserved':True},indent=2));print('R1 six same-camera material grouping comparisons; model unchanged')
