import bpy,bmesh,json,hashlib,math,collections,importlib.util
from pathlib import Path
from mathutils import Vector
r=Path.cwd();p=Path(__file__).resolve().parent;src=r/'blender/ninola/working/01Q1/2026-10-09-v002/ninola_01Q1_tail_taper.blend';dest=r/'blender/ninola/working/01R1/2026-10-09-v002/ninola_01R1_geometric_head_jaw.blend';assert not dest.exists();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01Q1_Tail_Taper'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update();world=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices];faces=[list(f.vertices) for f in a.data.polygons];mats=[f.material_index for f in a.data.polygons];names=[m.name for m in a.data.materials];skin={'d_olive','d_moss','d_tan','d_belly'};key=lambda i:tuple(round(x,5) for x in world[i]);classes=collections.defaultdict(list)
for i in set(i for f in faces for i in f):classes[key(i)].append(i)
selected={fi for fi,f in enumerate(faces) if names[mats[fi]] in skin and all(world[i].y>1.85 and sum(weights[i].get(g,0) for g in ['head','jaw'])>.65 for i in f)};protected={key(i) for fi,f in enumerate(faces) if fi not in selected for i in f};candidate={key(i) for fi in selected for i in faces[fi]};free=candidate-protected
# Work in bind-space to preserve pose-dependent deformation. Local edge
# dissolves only remove sufficiently planar internal faces, never noise vertices.
ob=a.copy();ob.data=a.data.copy();ob.name='01R1_Geometric_Head_Jaw';bpy.context.scene.collection.objects.link(ob);mesh=bmesh.new();mesh.from_mesh(ob.data);mesh.verts.ensure_lookup_table();mesh.faces.ensure_lookup_table();orig=list(mesh.verts);oldfaces=list(mesh.faces);origin=mesh.verts.layers.int.new('R1_original_vertex');patch=mesh.faces.layers.int.new('R1_design_patch');mesh.verts.ensure_lookup_table();mesh.faces.ensure_lookup_table();orig=list(mesh.verts);oldfaces=list(mesh.faces)
for i,v in enumerate(orig):v[origin]=i
for fi,f in enumerate(oldfaces):
 if fi not in selected:f[patch]=-1;continue
 c=sum((world[i] for i in faces[fi]),Vector())/len(faces[fi]);normal=f.normal;side=1 if c.x>0 else -1;bone=1 if sum(weights[i].get('jaw',0) for i in faces[fi])/len(faces[fi])>.5 else 2
 # Broad irregular staggered tiles, not random triangular colour or displacement.
 yy=int(math.floor((c.y-1.85)/.60));zz=int(math.floor((c.z+.08*(yy%2))/.38));axis=max(range(3),key=lambda j:abs(normal[j]));f[patch]=bone*10000+(side+1)*1000+yy*100+zz*10+axis
# Weld only internal coincident vertices with identical deform weights. Border
# duplicates remain untouched, preserving source interfaces and protected faces.
for k in sorted(free):
 ids=classes[k]
 if len(ids)<2:continue
 if any(weights[i]!=weights[ids[0]] for i in ids):continue
 bmesh.ops.remove_doubles(mesh,verts=[orig[i] for i in ids if orig[i].is_valid],dist=1e-7)
mesh.normal_update();edges=[e for e in mesh.edges if len(e.link_faces)==2 and all(f[patch]>=0 for f in e.link_faces) and e.link_faces[0][patch]==e.link_faces[1][patch] and all(v[origin]>=0 and key(v[origin]) in free for v in e.verts)]
# Dissolve within a coarse patch only: keep corners, preserve material domains.
bmesh.ops.dissolve_limit(mesh,angle_limit=math.radians(35),use_dissolve_boundaries=False,verts=[],edges=edges,delimit={'MATERIAL'})
mesh.normal_update();spine_changed=[]
for f in mesh.faces:
 if f[patch]>=0:f.smooth=False
 # M8 head spines used alternating face-index bright/brown, unlike directional
 # dark-ridge body accents. Reassign head spine faces using shared palette.
 if names[f.material_index] in ['d_spike','d_spike_lit','d_ridge']:
  c=sum((a.matrix_world@v.co for v in f.verts),Vector())/len(f.verts)
  if c.y>1.85:
   n=(a.matrix_world.to_3x3()@f.normal).normalized();newmat=names.index('d_spike_lit') if n.z>.25 and n.y>.05 else names.index('d_ridge') if n.z<.15 else names.index('d_spike');
   if f.material_index!=newmat:spine_changed.append({'center':list(c),'old':names[f.material_index],'new':names[newmat]});f.material_index=newmat
# Original IDs allow exact checks after index compaction. No original coordinate
# or deform dictionary is intentionally moved; reduction removes redundant data.
remaining=[(v[origin],list(v.co),dict(v[mesh.verts.layers.deform.active])) for v in mesh.verts];assert all(v[1]==list(a.data.vertices[v[0]].co) for v in remaining);mesh.to_mesh(ob.data);mesh.free();ob.data.update();bpy.context.view_layer.update();oldtris=sum(len(f)-2 for f in faces);newtris=sum(len(f.vertices)-2 for f in ob.data.polygons)
# Every non-skin/non-head face retains bind coordinate polygon and material,
# except explicitly approved head-spine material assignment.
def signature(coords,mat):return (tuple(tuple(round(x,7) for x in q) for q in coords),mat)
retained=collections.Counter(signature([ob.data.vertices[i].co for i in f.vertices],names[f.material_index]) for f in ob.data.polygons)
for fi,f in enumerate(faces):
 if fi in selected:continue
 if names[mats[fi]] in ['d_spike','d_spike_lit','d_ridge'] and all(world[i].y>1.85 for i in f):continue
 assert retained[signature([a.data.vertices[i].co for i in f],names[mats[fi]])]>0
assert newtris<oldtris,(oldtris,newtris)
assert all(sum(x.weight for x in v.groups)>.999 for v in ob.data.vertices if v.groups)
spec=importlib.util.spec_from_file_location('pipeline',r/'blender/pipeline.py');pipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pipe);issues=pipe.check([ob],budget=None)
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_render=obj!=ob;obj.hide_set(obj!=ob);obj.select_set(obj==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='R1 v002 geometric coarsening and directional cranial spine palette trial, pending review';dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==before
rec={'source_path':str(src.relative_to(r)),'source_sha256':before,'output_path':str(dest.relative_to(r)),'sha256':sha(dest),'object':ob.name,'selected_skin_faces':len(selected),'fixed_coordinate_classes':len(candidate&protected),'free_classes':len(free),'eligible_internal_edges':len(edges),'source_triangles':oldtris,'triangles':newtris,'triangle_savings':oldtris-newtris,'source_vertices':len(world),'vertices':len(ob.data.vertices),'all_retained_bind_coordinates_exact':True,'source_skin_palette_preserved':True,'non_target_faces_exact_except_approved_head_spine_materials':True,'spine_material_changes':spine_changed,'spine_geometry_changed':False,'spines_added':0,'pipeline_issues':issues,'source_unchanged':True,'production_ready':False,'geometry_method':'local patch-limited edge dissolve and redundant interior vertex weld; no random noise or wholesale decimation'};(p/'build_record_v002.json').write_text(json.dumps(rec,indent=2));(p/'vertex_provenance_v002.json').write_text(json.dumps({'retained_old_vertex_ids':[i for i,co,w in remaining],'head_skin_target_faces':sorted(selected)},indent=2));print(json.dumps({k:v for k,v in rec.items() if k!='spine_material_changes'}))
