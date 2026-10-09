import bpy,json,math,hashlib,collections
from pathlib import Path
from mathutils import Vector,Matrix
out=Path(__file__).resolve().parent;root=out.parents[4]
rec=root/'docs/image/modeling-tests/ninola-01K8/2026-10-08-v001/source-records'
src=root/'blender/ninola/candidates/01K6/ninola_01K6_pedal_mass_reconstruction.blend';dest=root/'blender/ninola/working/01L1/2026-10-08-v001/ninola_01L1_forward_toe_volume.blend'
assert not dest.exists();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();base_sha=sha(src)
bpy.ops.wm.open_mainfile(filepath=str(src));a=bpy.data.objects['01K6_Pedal_Segment_Mass_Reconstruction'];rig=bpy.data.objects['TrexRig'];bpy.context.view_layer.update()
def locked_signature():
 rig=bpy.data.objects['TrexRig'];tr=bpy.data.objects['Trex'];d={'bones':[(b.name,b.parent.name if b.parent else None,list(b.head_local),list(b.tail_local),[list(row) for row in b.matrix_local]) for b in rig.data.bones],'rig_matrix':[list(row) for row in rig.matrix_world],'pose':[(b.name,[list(row) for row in b.matrix_basis]) for b in rig.pose.bones],'rig_props':str(dict(rig.items())),'Trex_coords':[list(v.co) for v in tr.data.vertices],'Trex_faces':[list(f.vertices) for f in tr.data.polygons],'Trex_weights':[[(g.group,g.weight) for g in v.groups] for v in tr.data.vertices],'Trex_keys':[(k.name,k.value,[list(v.co) for v in k.data]) for k in tr.data.shape_keys.key_blocks]};return sha_bytes(json.dumps(d,sort_keys=True).encode())
sha_bytes=lambda b:hashlib.sha256(b).hexdigest();locked=locked_signature()
c=[a.matrix_world@v.co for v in a.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];faces=[list(f.vertices) for f in a.data.polygons];wt=[{a.vertex_groups[g.group].name:g.weight for g in v.groups} for v in a.data.vertices]
zones=json.loads((rec/'prototype_face_zones.json').read_text());mapping=json.loads((rec/'k5_build.json').read_text())['face_source_A_indices'];zone_ids=collections.defaultdict(set)
for fi,f in enumerate(faces):zone_ids[zones[mapping[fi]]].update(f)
eligible=set();protected=set();reasons={}
for z,ids in zone_ids.items():
 if z.endswith(('_forward_retained','_main_toe_attachment')):eligible.update(ids)
 if z.endswith(('_pedal_shaft','_rear_retained','_rear_digit_attachment','_anchor_retained','_forward_pad_attachment')):protected.update(ids);reasons[z]=sorted(ids)
claw=set(i for f in a.data.polygons if a.data.materials[f.material_index].name=='d_claw' for i in f.vertices);protected.update(claw);reasons['all_claw_vertices']=sorted(claw)
# Static sole and contact sample band; preserve all three claw tips and existing footprint.
sole={i for i,p in enumerate(c) if abs(p.x)>.35 and p.z<=.035};protected.update(sole);reasons['sole_z_le_0035']=sorted(sole)
# Geometric bundle agreement prevents moving only one duplicate seam reference.
bundles=collections.defaultdict(list)
for i,p in enumerate(c):bundles[tuple(round(t,6) for t in p)].append(i)
result=[p.copy() for p in c];assignment={}
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
# Terminal skin center paths measured from this model, not exact reconstructed anatomy.
paths=[(.680,.100,.500,.710),(.680,.100,.774,.945),(.680,.100,1.020,.710)]
for ids in bundles.values():
 if any(i in protected for i in ids) or not any(i in eligible for i in ids):continue
 p=c[ids[0]];x=abs(p.x);y=p.y;z=p.z
 if y<=.205 or z>=.32 or x<.35:continue
 candidates=[]
 for n,(rx,ry,tx,ty) in enumerate(paths):
  dx=tx-rx;dy=ty-ry;t=((x-rx)*dx+(y-ry)*dy)/(dx*dx+dy*dy);tt=max(0,min(1,t));ax=rx+tt*dx;ay=ry+tt*dy;candidates.append(((x-ax)**2+(y-ay)**2,n,t,ax,ay))
 _,n,t,ax,ay=min(candidates)
 if not 0<t<1:continue
 rootfade=smooth((y-.205)/.12);endfade=smooth((.90-t)/.20);arch=math.sin(math.pi*t)**1.2;dorsal=smooth((z-.035)/.105)
 fade=rootfade*endfade;dz=.082*arch*dorsal*fade
 # Modest lateral contraction of skin-only mid-body toward the chosen toe path.
 # No toe spread, longitudinal shift, claw, ground or core-pedal modification.
 dx=-(x-ax)*.10*arch*fade
 q=p.copy();q.z+=dz;q.x=(1 if p.x>0 else -1)*(x+dx)
 for i in ids:result[i]=c[i]+(q-p);assignment[i]=n+1
bn=[(c[f[1]]-c[f[0]]).cross(c[f[2]]-c[f[0]]) for f in faces]
# One safety projection limits the same blockout, not a second morphology pass.
for attempt in range(12):
 bad=[]
 for fi,f in enumerate(faces):
  nn=(result[f[1]]-result[f[0]]).cross(result[f[2]]-result[f[0]])
  if bn[fi].length_squared>1e-12 and (nn.dot(bn[fi])<=0 or nn.length_squared<1e-12):bad.extend(f)
 if not bad:break
 keys={tuple(round(t,6) for t in c[i]) for i in bad}
 for key in keys:
  for i in bundles[key]:result[i]=c[i]+(result[i]-c[i])*.5
ob=a.copy();ob.data=a.data.copy();ob.name='01L1_Forward_Toe_Volume_Blockout';bpy.context.scene.collection.objects.link(ob)
bm={b.name:rig.pose.bones[b.name].matrix@b.matrix_local.inverted() for b in rig.data.bones if b.use_deform};changed=[]
for i,(v,p,q,w) in enumerate(zip(ob.data.vertices,c,result,wt)):
 if (p-q).length<1e-9:continue
 m=Matrix.Identity(4)*(1-sum(v for n,v in w.items() if n in bm))
 for n,vv in w.items():
  if n in bm:m+=bm[n]*vv
 eff=rig.matrix_world@m@rig.matrix_world.inverted();v.co=ob.matrix_world.inverted()@(eff.inverted()@q);changed.append(i)
ob.data.update();bpy.context.view_layer.update();actual=[ob.matrix_world@v.co for v in ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).data.vertices];err=max((p-q).length for p,q in zip(actual,result));assert err<2e-6
an=[(actual[f[1]]-actual[f[0]]).cross(actual[f[2]]-actual[f[0]]) for f in faces];flips=[i for i,(x,y) in enumerate(zip(bn,an)) if x.length_squared>1e-12 and y.dot(x)<=0];assert not flips
assert locked_signature()==locked;assert all(ob.data.vertices[i].co==a.data.vertices[i].co for i in protected)
assert [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices]==[[(g.group,g.weight) for g in v.groups] for v in a.data.vertices]
for obj in bpy.context.scene.objects:
 if obj.type=='MESH':obj.hide_render=obj!=ob;obj.hide_set(obj!=ob);obj.select_set(obj==ob)
bpy.context.view_layer.objects.active=ob;ob['status']='prototype_pending_user_review';ob['base_sha256']=base_sha
record={'base_sha256':base_sha,'output_path':str(dest.relative_to(root)),'object':ob.name,'changed_reference_count':len(changed),'changed_refs':changed,'toe_assignment_counts':dict(collections.Counter(assignment[i] for i in changed)),'max_displacement':max((p-q).length for p,q in zip(c,actual)),'max_dorsal_lift':max(q.z-p.z for p,q in zip(c,actual)),'topology_changed':False,'prototype_weights_changed':False,'rig_Trex_exact':True,'protected_max_displacement':max((c[i]-actual[i]).length for i in protected),'claws_sole_rear_pedal_protected':True,'new_face_reversals':flips,'near_degenerate_before':sum(x.length_squared<1e-12 for x in bn),'near_degenerate_after':sum(x.length_squared<1e-12 for x in an),'inverse_bind_max_error':err,'vertices':len(c),'faces':len(faces),'status':'pending_user_review'}
(out/'edit_mask.json').write_text(json.dumps({'eligible':sorted(eligible),'protected':sorted(protected),'protection_reasons':reasons,'changed':changed},indent=2))
dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest));assert sha(src)==base_sha;bpy.ops.wm.open_mainfile(filepath=str(dest));assert locked_signature()==locked;record['reopen_locks_exact']=True;record['output_sha256']=sha(dest)
(out/'build_record.json').write_text(json.dumps(record,indent=2));print(json.dumps({k:v for k,v in record.items() if k!='changed_refs'}))
