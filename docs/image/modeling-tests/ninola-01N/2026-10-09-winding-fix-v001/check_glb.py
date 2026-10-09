from pathlib import Path
import json,struct,collections,math,hashlib
p=Path(__file__).resolve().parent
formats={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)};width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def read(path):
 b=path.read_bytes();magic,version,total=struct.unpack_from('<III',b);assert magic==0x46546c67 and version==2 and total==len(b);offset=12;doc=None;binary=None
 while offset<len(b):
  n,t=struct.unpack_from('<II',b,offset);offset+=8;chunk=b[offset:offset+n];offset+=n
  if t==0x4e4f534a:doc=json.loads(chunk)
  elif t==0x004e4942:binary=chunk
 def accessor(i):
  a=doc['accessors'][i];assert 'sparse' not in a;v=doc['bufferViews'][a['bufferView']];fmt,size=formats[a['componentType']];dim=width[a['type']];stride=v.get('byteStride',size*dim);start=v.get('byteOffset',0)+a.get('byteOffset',0);out=[struct.unpack_from('<'+fmt*dim,binary,start+k*stride) for k in range(a['count'])]
  if a.get('normalized') and a['componentType']!=5126:
   factor={5121:255,5123:65535,5120:127,5122:32767}[a['componentType']];out=[tuple(max(-1,x/factor) for x in row) for row in out]
  return out
 skin=doc['skins'][0];bones=[doc['nodes'][i]['name'] for i in skin['joints']];triangles=collections.Counter();weighted=set();count=0;weight_error=0;normal_dot_min=1.
 for mesh in doc['meshes']:
  for prim in mesh['primitives']:
   assert prim.get('mode',4)==4;at=prim['attributes'];pos=accessor(at['POSITION']);norm=accessor(at['NORMAL']);idx=[x[0] for x in accessor(prim['indices'])];sets=[(accessor(at[f'JOINTS_{i}']),accessor(at[f'WEIGHTS_{i}'])) for i in range(8) if f'JOINTS_{i}' in at];assert sets
   for k,pt in enumerate(pos):
    assert all(math.isfinite(x) for x in pt+norm[k]);w=collections.defaultdict(float)
    for joints,values in sets:
     for j,value in zip(joints[k],values[k]):
      if value>1e-7:assert j<len(bones);w[bones[j]]+=value
    weight_error=max(weight_error,abs(sum(w.values())-1));weighted.add((tuple(round(x,5) for x in pt),tuple(sorted((name,round(v,5)) for name,v in w.items()))))
   material=doc['materials'][prim['material']]['name']
   for start in range(0,len(idx),3):
    ids=idx[start:start+3];assert len(ids)==3;tri=tuple(sorted(tuple(round(x,5) for x in pos[i]) for i in ids));triangles[(material,tri)]+=1;count+=1
 return {'bones':bones,'parents':[(n.get('name'),n.get('children',[]),n.get('matrix'),n.get('translation'),n.get('rotation'),n.get('scale')) for n in doc['nodes']],'inverse_bind':accessor(skin['inverseBindMatrices']),'triangles':triangles,'weighted':weighted,'triangle_count':count,'max_weight_sum_error':weight_error,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
a=read(p/'test-project/models/N1v003_eight_weights.glb');b=read(p/'test-project/models/N1v004_eight_weights.glb');assert a['bones']==b['bones'] and len(b['bones'])==45;assert a['parents']==b['parents'];assert a['inverse_bind']==b['inverse_bind'];assert a['triangles']==b['triangles'];assert a['weighted']==b['weighted'];assert b['max_weight_sum_error']<1e-6
report={'glb_binary_readable':True,'exported_triangles':b['triangle_count'],'bone_count':len(b['bones']),'names_hierarchy_transforms_inverse_bind_exact':True,'unordered_triangle_positions_and_material_names_match_5_decimals':True,'position_influence_signatures_match_5_decimals':True,'geometry_weight_signature_comparison_decimals':5,'material_signature_scope':'names only','all_positions_normals_finite':True,'weight_sum_max_error':b['max_weight_sum_error'],'v003_glb_sha256':a['sha256'],'v004_glb_sha256':b['sha256'],'production_integration':False};(p/'glb_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
