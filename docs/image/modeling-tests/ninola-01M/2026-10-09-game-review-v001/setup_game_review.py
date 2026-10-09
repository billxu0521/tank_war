from pathlib import Path
import shutil,json,hashlib
r=Path.cwd();p=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-game-review-v001';d=p/'test-project';d.mkdir(parents=True,exist_ok=False)
allowed={'.gd','.uid','.tscn','.tres','.glb','.png','.jpg','.jpeg','.svg','.ogg','.wav','.mp3','.csv','.godot','.gdshader','.ttf','.otf'};dirs={'assets','models','levels','cowboy','interact'};files=[]
for q in r.iterdir():
 if q.is_file() and q.suffix in allowed:files.append(q)
 elif q.is_dir() and q.name in dirs:files.extend(x for x in q.rglob('*') if x.is_file() and x.suffix in allowed)
manifest=[]
for q in files:
 t=d/q.relative_to(r);t.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(q,t);manifest.append({'source':str(q.relative_to(r)),'sha256':hashlib.sha256(q.read_bytes()).hexdigest()})
source=r/'docs/image/modeling-tests/ninola-01M/2026-10-09-pass-v007/dynamic/test-project/models/M7_eight_weights.glb';shutil.copyfile(source,d/'models/ninola_M7_evaluation.glb')
f=d/'trex.gd';s=f.read_text();assert s.count('preload("res://models/trex_hd.glb")')==1;s=s.replace('preload("res://models/trex_hd.glb")','preload("res://models/ninola_M7_evaluation.glb")');f.write_text(s)
shutil.copyfile(p/'test-support/review_probe.gd',d/'review_probe.gd')
f=d/'main.gd';s=f.read_text();start=s.index('func _start_practice(');end=s.index('\n## 靶場',start);part=s[start:end];assert part.count('_add_player(COWBOY, 1)')==1;part=part.replace('_add_player(COWBOY, 1)','_add_player(DINO, 1)');part=part.replace('_on_ground(start)', '_on_ground(start + Vector3(0,4.1,0))');part=part.replace('\tme.viewmodel.set_infinite()', '\tif me.is_in_group(&\"cowboy\"):\n\t\tme.viewmodel.set_infinite()');s=s[:start]+part+s[end:];s+='\n';s=s.replace('func _ready() -> void:\n','func _ready() -> void:\n\tvar review_probe = load("res://review_probe.gd").new()\n\tadd_child(review_probe)\n',1);f.write_text(s)
# Isolate settings/save data from the real game and give the test window a clear label.
f=d/'project.godot';s=f.read_text();s=s.replace('config/name=','config/use_custom_user_dir=true\nconfig/custom_user_dir_name="Ninola_M7_Isolated_Review"\nconfig/name=',1);f.write_text(s)
(p/'source_manifest.json').write_text(json.dumps({'copied_allowlist':manifest,'evaluation_asset_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'isolated_changes':['trex MODEL resource path','sandbox player1 DINO for true input','read-only telemetry/observer camera','isolated user settings directory'],'original_checkout_modified':False},ensure_ascii=False,indent=2))
