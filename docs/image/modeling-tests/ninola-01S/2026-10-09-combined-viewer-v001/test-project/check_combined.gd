extends SceneTree
var observations := []
var records := {}
func _initialize() -> void:
	call_deferred("run")
func transform_array(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func capture(t: Trex, label: String, index: int, time_s: float) -> Dictionary:
	var bones := {}
	for i in t.skel.get_bone_count():
		bones[t.skel.get_bone_name(i)] = transform_array(t.skel.get_bone_global_pose(i))
	return {"label":label,"frame":index,"time":time_s,"bones":bones,"jaw_rotation_parent_world":[t.pose_rot("jaw").x,t.pose_rot("jaw").y,t.pose_rot("jaw").z,t.pose_rot("jaw").w],"skeleton_world":transform_array(t.skel.global_transform),"swing":[t._swing[0],t._swing[1]],"ground_plane_y":0.0}
func make_candidate(tag: String) -> Trex:
	var t = load("res://combined_trex.gd").new()
	root.add_child(t)
	t.set_process(false)
	return t
func run() -> void:
	for enabled in [false,true]:
		var tag := "combined" if enabled else "baseline"
		var t := make_candidate(tag)
		t.eval_changes_enabled = enabled
		var rest := {}
		for i in t.skel.get_bone_count():
			rest[t.skel.get_bone_name(i)]={"matrix":transform_array(t.skel.get_bone_global_rest(i))}
		t.free()
		var sequences := {}
		for mode in ["idle","bite","roar","walk","run","turn"]:
			t = make_candidate(tag)
			t.eval_changes_enabled = enabled
			var seq := []
			for f in 120:
				if mode=="bite":
					if f==12:t.act=1
					if f==30:
						t.act=2
						t.bite()
					if f==35:t.act=7
					if f==60:t.act=0
				if mode=="roar":
					if f==12:t.act=3
					if f==60:t.act=0
				if mode in ["walk","run","turn"]:
					if mode=="turn":t.rotation.y+=0.4/24.0
					t.global_position+=-t.global_basis.z*(8.0 if mode=="run" else 4.0)/24.0
				t._process(1.0/24.0)
				seq.append(capture(t,mode,f,float(f)/24.0))
			t.free()
			sequences[mode]=seq
		records[tag]={"rest":rest,"sequences":sequences}
	var dest := ProjectSettings.globalize_path("res://../combined_samples.json")
	var file := FileAccess.open(dest,FileAccess.WRITE)
	file.store_string(JSON.stringify({"assets":records,"dt":1.0/24.0,"scope":"isolated actual runtime subclass, not real input"},"\t"))
	print("COMBINED_SAMPLES_OK")
	quit(0)
