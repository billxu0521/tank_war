import bpy,json,hashlib,math,collections
from pathlib import Path
from mathutils import Vector,Matrix
root=Path(__file__).resolve().parents[5]; out=Path(__file__).resolve().parent
src=root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend'
dest=root/'blender/ninola/working/01K8/2026-10-08-v001/ninola_01K8_hock_mass_continuity.blend'
assert not dest.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base_sha=sha(src);bpy.ops.wm.open_mainfile(filepath=str(src));rig=bpy.data.objects['TrexRig'];a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];bpy.context.view_layer.update()
def signature():
 tr=bpy.data.objects['Trex'];return {'bones':[(b.name,b.parent.name if b.parent else None,list(b.head_local),list(b.tail_local),[list(r) for r in b.matrix_local]) for b in rig.data.bones],'pose':[(p.name,[list(r) for r in p.matrix_basis]) for p in rig.pose.bones],'rig_matrix':[list(r) for r in rig.matrix_world],'rollback':rig.get('01A_original_pose_basis_json'),'Trex_vertices':[list(v.co) for v in tr.data.vertices],'Trex_faces':[list(p.vertices) for p in tr.data.polygons],'Trex_weights':[[(g.group,g.weight) for g in v.groups] for v in tr.data.vertices],'Trex_keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]}
locked=signature();c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];faces=[list(p.vertices) for p in a.data.polygons];weights=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
k5=json.loads((out/'source-records/k5_build.json').read_text());zones=json.loads((out/'source-records/prototype_face_zones.json').read_text());protected=set(json.loads((out/'source-records/k6_build.json').read_text())['protected_indices'])
# Actual provenance mask; all upper body references remain fixed outside local height/window.
eligible=set()
for fi,f in enumerate(faces):
 z=zones[k5['face_source_A_indices'][fi]]
 if z.endswith(('_upper_retained','_distal_transition','_hock_transition','_ankle_collar','_pedal_shaft')):eligible.update(f)
bundles=collections.defaultdict(list)
for i,p in enumerate(c):bundles[tuple(round(x,6) for x in p)].append(i)
result=[p.copy() for p in c]
def smooth(x):x=min(1,max(0,x));return x*x*(3-2*x)
for ids in bundles.values():
 if any(i in protected for i in ids) or not any(i in eligible for i in ids):continue
 p=c[ids[0]];sgn=1 if p.x>0 else -1;x=abs(p.x);y=p.y;z=p.z
 if not (.43<z<.82 and .43<x<.90 and -.34<y<.34):continue
 # Low-poly tissue envelope: broaden lower calf support, taper into joint;
 # remove circumferential straight seam by varying height with front/back and side.
 fade=smooth((z-.43)/.05)*smooth((.82-z)/.12)
 calf=math.exp(-((z-.61)/.13)**2);joint=math.exp(-((z-.505)/.065)**2)
 dx=x-.655;rx=max(-1,min(1,dx/.17));front=max(-1,min(1,(y+.075)/.20))
 q=p.copy();q.x=sgn*(x + fade*.040*calf*rx*(.75+.25*max(0,-front)))
 q.y+=fade*(-.026*calf*max(0,-front) -.034*joint*max(0,front))
 q.z+=fade*joint*(-.057*front + .016*(abs(rx)-.5))
 # No broad/symmetric ring inflation; preserved pedal central/distal samples.
 for i in ids:result[i]=c[i]+(q-p)
ob=a.copy();ob.data=a.data.copy();ob.name='01K8_Hock_Mass_Continuity';bpy.context.scene.collection.objects.link(ob)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform}
changed=[]
for i,(v,p,q,wt) in enumerate(zip(ob.data.vertices,c,result,weights)):
 if (q-p).length<1e-10:continue
 total=sum(w for n,w in wt.items() if n in bm);m=Matrix.Identity(4)*(1-total)
 for n,w in wt.items():
  if n in bm:m+=bm[n]*w
 eff=rig.matrix_world@m@rig.matrix_world.inverted();v.co=ob.matrix_world.inverted()@(eff.inverted()@q);changed.append(i)
ob.data.update();bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices]
error=max((actual[i]-result[i]).length for i in changed);assert error<2e-6
assert signature()==locked
assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in protected)
# Display isolation only in new working file.
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and obj!=ob:obj.hide_render=True;obj.hide_set(True)
ob.hide_render=False;ob.hide_set(False);bpy.context.view_layer.objects.active=ob;ob.select_set(True)
ob['status']='working_prototype_pending_user_review';ob['base_sha256']=base_sha
# Signed normal reversal and degenerate diagnostics, retained topology.
def normals(coords):
 return [(coords[f[1]]-coords[f[0]]).cross(coords[f[2]]-coords[f[0]]) for f in faces]
bn=normals(c);an=normals(actual);flips=[i for i,(n,m) in enumerate(zip(bn,an)) if n.length>1e-10 and m.length>1e-10 and n.dot(m)<0]
record={'base_path':str(src.relative_to(root)),'base_sha256':base_sha,'output_path':str(dest.relative_to(root)),'object':ob.name,'vertices':len(c),'triangles':len(faces),'changed_references':changed,'changed_reference_count':len(changed),'max_displacement':max((p-q).length for p,q in zip(c,actual)),'inverse_binding_max_error':error,'protected_rest_displacement':0,'protected_evaluated_max_displacement':max((c[i]-actual[i]).length for i in protected),'rig_Trex_keys_weights_geometry_exact':True,'topology_changed':False,'prototype_weights_changed':False,'faces_normal_rotation_over_90_degrees':flips,'near_degenerate_before':sum(n.length_squared<1e-12 for n in bn),'near_degenerate_after':sum(n.length_squared<1e-12 for n in an),'untouched_scope':'digit/claw/rear-digit core/anchors; pedal middle/distal; upper body; original Trex/Rig','status':'pending_user_review'}
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==base_sha
bpy.ops.wm.open_mainfile(filepath=str(dest));assert signature()==locked
record['reopen_locked_data_exact']=True;record['output_sha256']=sha(dest)
(out/'build_record.json').write_text(json.dumps(record,indent=2));(out/'after_geometry.json').write_text(json.dumps([list(p) for p in actual]));print(json.dumps({k:v for k,v in record.items() if k not in ['changed_references','faces_normal_rotation_over_90_degrees']}))
