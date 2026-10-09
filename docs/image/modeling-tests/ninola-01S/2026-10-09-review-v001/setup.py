from pathlib import Path
import json,shutil,hashlib
r=Path.cwd();p=Path(__file__).resolve().parent;d=p/'test-project';d.mkdir(exist_ok=False);(d/'models').mkdir();old=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic-v002/test-project';manifest=[]
for name in ['trex.gd','candidate.gd','viewmodel_mark.gd','fx.gd','project.godot']:
 source=r/name if name=='trex.gd' else old/name
 shutil.copyfile(source,d/name);manifest.append({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
shutil.copyfile(r/'models/trex_hd.glb',d/'models/trex_hd.glb')
original=Path('/Users/ChenPo-Yun/Documents/Codex/2026-10-06/https-github-com-billxu0521-tank-war/tank_war')
checks=[]
for name in ['trex.gd','models/trex_hd.glb']:
 q=original/name;checks.append({'path':str(q),'exists':q.exists(),'sha256':hashlib.sha256(q.read_bytes()).hexdigest() if q.exists() else None,'worktree_sha256':hashlib.sha256((r/name).read_bytes()).hexdigest()})
(p/'resource_provenance.json').write_text(json.dumps({'copied_allowlist':manifest,'original_checkout_readonly_checks':checks,'driver':'worktree trex.gd copied unchanged; isolated direct procedural calls, not player input'},indent=2))
