extends Node3D
## 舊建築工作分支／編輯器可讀取靜態板件；在含正式破壞系統的遊戲中以同一組板件建出 ToyBuild。
func _ready() -> void:
	var game_script := "res://toy_build.gd"
	if get_parent().has_meta("editable_geometry") or not ResourceLoader.exists(game_script):
		return
	var bricks: Array=[]
	var wood_level: int=load("res://hit_rules.gd").level(&"wood")
	var bearing_height: float=$Intact/Plank0.position.y-$Intact/Plank0.mesh.size.y*.5
	for plank: MeshInstance3D in $Intact.get_children():
		var mat: StandardMaterial3D=plank.mesh.material
		var relative:=plank.transform
		relative.origin.y-=bearing_height
		bricks.append([relative,plank.mesh.size,wood_level,mat.albedo_color,true,&"wood"])
	var insert=load(game_script).make(bricks)
	insert.name="Boards"
	insert.position.y=bearing_height
	$Intact.free()
	$StaticPreviewCollision.free()
	add_child(insert)

