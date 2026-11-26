extends Node3D
## 完整時兩面工單隨實木面板顯示；該面脫落時收掉紙張，重置時回復。
var timber
var mounts: Dictionary
var last_version: int = -1

func _ready() -> void:
	var game_script := "res://toy_build.gd"
	if get_parent().has_meta("editable_geometry") or not ResourceLoader.exists(game_script):
		set_process(false)
		return
	var bricks: Array=[]
	var strength: int=load("res://hit_rules.gd").level(&"wood")
	for part: MeshInstance3D in $Timber.get_children():
		mounts[part.name]=bricks.size()
		bricks.append([part.transform,part.mesh.size,strength,part.mesh.material.albedo_color,true,&"wood"])
	timber=load(game_script).make(bricks)
	timber.name="RollTimber"
	$Timber.free()
	$Static.free()
	add_child(timber)
	_process(0)

func _process(_delta: float) -> void:
	if timber==null or timber.geo_ver==last_version:
		return
	last_version=timber.geo_ver
	for sheet in $Notices.get_children():
		sheet.visible=timber.is_standing(mounts[StringName(sheet.get_meta("mount"))])

