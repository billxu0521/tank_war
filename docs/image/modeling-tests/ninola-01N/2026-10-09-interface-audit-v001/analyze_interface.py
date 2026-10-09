from pathlib import Path
import json,collections,math
from statistics import median
r=Path.cwd();p=Path(__file__).resolve().parent;old=json.loads((p.parent/'2026-10-09-schematic-v001/source_geometry.json').read_text());new=json.loads((p.parent/'2026-10-09-pass-v001/refined-v003/inspection_geometry.json').read_text());mask=json.loads((p.parent/'2026-10-09-pass-v001/refined-v003/edit_mask.json').read_text());ov=old['vertices'];nv=new['vertices'];key=lambda v:tuple(round(x,5) for x in v);sub=lambda a,b:[x-y for x,y in zip(a,b)];dot=lambda a,b:sum(x*y for x,y in zip(a,b));cross=lambda a,b:[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];length=lambda a:math.sqrt(dot(a,a));normal=lambda f:cross(sub(nv[f[1]],nv[f[0]]),sub(nv[f[2]],nv[f[0]]))
removed=set(mask['removed_faces']);sourceedge=collections.Counter()
for fi in removed:
 f=old['faces'][fi]
 for a,b in zip(f,f[1:]+f[:1]):sourceedge[tuple(sorted([key(ov[a]),key(ov[b])]))]+=1
adj=collections.defaultdict(set)
for (a,b),n in sourceedge.items():
 if n==1:adj[a].add(b);adj[b].add(a)
start=min(adj);loop=[start];prev=None;cur=start
while True:
 nxt=next(x for x in sorted(adj[cur]) if x!=prev)
 if nxt==start:break
 loop.append(nxt);prev,cur=cur,nxt
back=min(range(len(loop)),key=lambda i:abs(loop[i][0])+.3*(loop[i][1]-2));loop=loop[back:]+loop[:back]
incident=collections.defaultdict(list)
for fi,f in enumerate(old['faces']):
 if fi in removed:continue
 for i in f:incident[key(ov[i])].append((fi,old['face_materials'][fi]))
points=[]
for j,k in enumerate(loop):
 neighbours=sorted(set(incident[k]));a=loop[(j-1)%27];b=loop[(j+1)%27];ab=sub(b,a);t=max(0,min(1,dot(sub(k,a),ab)/dot(ab,ab)));project=[a[i]+t*ab[i] for i in range(3)];notch=length(sub(k,project));points.append({'order':j,'world':k,'fixed_source_neighbour_materials':sorted(set(m for _,m in neighbours)),'protected_source_faces':[f for f,_ in neighbours],'deviation_from_neighbour_chord':notch,'collar_point':nv[mask['added_vertices'][j]],'shoulder_point':nv[mask['added_vertices'][27+j]],'lower_point':nv[mask['added_vertices'][54+j]]})
# Confirm no missing shared seam coordinate. Edge winding within new exterior is a separate check.
newfaces=new['faces'][len(mask['retained_faces']):];edgefaces=collections.defaultdict(list)
for local,f in enumerate(newfaces):
 for a,b in zip(f,f[1:]+f[:1]):edgefaces[tuple(sorted([a,b]))].append((local,a,b))
inconsistent=[];creases=[]
for edge,records in edgefaces.items():
 if len(records)!=2:continue
 aa,bb=records
 if aa[1:]==bb[1:]:inconsistent.append({'local_faces':[aa[0],bb[0]],'vertices':edge})
 n0=normal(newfaces[aa[0]]);n1=normal(newfaces[bb[0]]);cos=max(-1,min(1,dot(n0,n1)/max(1e-20,length(n0)*length(n1))));angle=math.degrees(math.acos(cos))
 if angle>80:creases.append({'local_faces':[aa[0],bb[0]],'vertices':edge,'normal_angle_degrees':angle})
fixedkeys=set(loop);seamcoords={key(nv[i]) for f in newfaces[:54] for i in f};missing=sorted(fixedkeys-seamcoords)
report={'source':'01N1 v003 user accepted','fixed_point_count':27,'shared_boundary_missing_coordinates':missing,'new_exterior_faces':len(newfaces),'collar_faces':54,'shoulder_faces':54,'lower_transition_faces':54,'floor_faces':len(newfaces)-162,'boundary_points':points,'top_boundary_z_range':[min(k[2] for k in loop),max(k[2] for k in loop)],'collar_z_offset_range':[min(points[j]['collar_point'][2]-k[2] for j,k in enumerate(loop)),max(points[j]['collar_point'][2]-k[2] for j,k in enumerate(loop))],'new_patch_internal_boundary_edges':sum(len(v)==1 for v in edgefaces.values()),'new_patch_nonmanifold_edges':sum(len(v)>2 for v in edgefaces.values()),'new_patch_inconsistent_winding_edges':inconsistent,'new_patch_large_normal_angle_edges':creases,'interpretation_limits':'Sharp angle and notch metrics locate candidates, not visual approval or proof of holes; winding is a concrete local mesh consistency check, source and rig not modified.'}
(p/'interface_analysis.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k not in ['boundary_points','new_patch_large_normal_angle_edges','new_patch_inconsistent_winding_edges']}));print('winding inconsistency',len(inconsistent),'large crease',len(creases),'max_notches',sorted([(x['order'],x['deviation_from_neighbour_chord'],x['fixed_source_neighbour_materials']) for x in points],key=lambda x:-x[1])[:6])
# Diagnostic-only orientation normalization: no model is written.
neighbours=collections.defaultdict(list)
for edge,records in edgefaces.items():
 if len(records)==2:
  a,b=records;neighbours[a[0]].append((b[0],a[1:]==b[1:]));neighbours[b[0]].append((a[0],a[1:]==b[1:]))
flip={0:False};todo=[0];contradictions=[]
while todo:
 a=todo.pop()
 for b,same in neighbours[a]:
  need=flip[a]^same
  if b not in flip:flip[b]=need;todo.append(b)
  elif flip[b]!=need:contradictions.append([a,b])
assert len(flip)==len(newfaces) and not contradictions
# Choose global orientation using unchanged d_mouth boundary edges.
protected_edge_dirs=collections.defaultdict(list)
for fi in mask['retained_faces']:
 f=old['faces'][fi]
 for a,b in zip(f,f[1:]+f[:1]):
  ka,kb=key(ov[a]),key(ov[b]);protected_edge_dirs[tuple(sorted([ka,kb]))].append((ka,kb))
votes=collections.Counter()
for edge,records in edgefaces.items():
 if len(records)!=1:continue
 local,a,b=records[0];ka,kb=key(nv[a]),key(nv[b]);dirs=protected_edge_dirs[tuple(sorted([ka,kb]))]
 for u,v in dirs:
  aa,bb=(kb,ka) if flip[local] else (ka,kb);votes[aa==u and bb==v]+=1
if votes[True]>votes[False]:flip={k:not v for k,v in flip.items()}
fixedfaces=[list(reversed(f)) if flip[i] else f for i,f in enumerate(newfaces)];check=collections.defaultdict(list)
for i,f in enumerate(fixedfaces):
 for a,b in zip(f,f[1:]+f[:1]):check[tuple(sorted([a,b]))].append((a,b))
assert not any(len(v)==2 and v[0]==v[1] for v in check.values())
report['diagnostic_orientation_only']={'new_local_faces_to_reverse':[i for i,v in flip.items() if v],'source_model_changed':False,'coordinates_changed':False,'remaining_inconsistent_new_patch_edges':0,'boundary_orientation_votes_before_global_choice':dict(votes),'note':'A hypothesis on an evaluation display, not a saved corrected model; geometric notches still remain.'}
(p/'interface_analysis.json').write_text(json.dumps(report,indent=2));print('diagnostic reversals',sum(flip.values()))
