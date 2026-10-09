import json,math
from pathlib import Path
import numpy as np
p=Path('docs/image/modeling-tests/ninola-01S/2026-10-09-combined-viewer-v001');d=json.loads((p/'combined_samples.json').read_text() if (p/'combined_samples.json').exists() else __import__('gzip').decompress((p/'combined_samples.json.gz').read_bytes()).decode())['assets'];errs=[];unchanged=0
for mode in d['baseline']['sequences']:
 for a,b in zip(d['baseline']['sequences'][mode],d['combined']['sequences'][mode]):
  N=np.array(a['bones']['neck']);H=np.array(a['bones']['head']);N2=N.copy();t=math.radians(12);R=np.array([[1,0,0],[0,math.cos(t),-math.sin(t)],[0,math.sin(t),math.cos(t)]]);N2[:3,:3]=R@N[:3,:3];H2=N2@np.linalg.inv(N)@H;t=math.radians(-4);R=np.array([[1,0,0],[0,math.cos(t),-math.sin(t)],[0,math.sin(t),math.cos(t)]]);H2[:3,:3]=R@H2[:3,:3];errs.extend([float(np.max(abs(N2-np.array(b['bones']['neck'])))),float(np.max(abs(H2-np.array(b['bones']['head']))))]);unchanged=max(unchanged,float(np.max(abs(np.array(a['bones']['spine2'])-np.array(b['bones']['spine2'])))))
rest=d['baseline']['rest']==d['combined']['rest'];o={'samples':720,'neck_head_composition_max_error':max(errs),'spine_pose_difference':unchanged,'rest_equal':rest};print(o);assert max(errs)<3e-5 and unchanged==0 and rest;(p/'composition_verification.json').write_text(json.dumps(o,indent=2));print(o)
