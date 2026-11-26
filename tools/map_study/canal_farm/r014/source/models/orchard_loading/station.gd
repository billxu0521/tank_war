extends Node3D
## 每個整數保留一垛原筐的槽位。房主改變筐列時才更新，後加入者讀同一份狀態。
@export_storage var crate_masks := PackedInt32Array():
	set(value):
		crate_masks = value.duplicate()
		if is_node_ready() and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
			_apply_received_masks()

func _ready() -> void:
	for stack in $WorkingCrates.get_children():
		stack.contents_changed.connect(_collect_masks)
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		_collect_masks()
	else:
		_apply_received_masks()

func _collect_masks(_changed_mask: int = 0) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	var counts := PackedInt32Array()
	for stack in $WorkingCrates.get_children():
		counts.append(stack.intact_mask)
	crate_masks = counts

func _apply_received_masks() -> void:
	var stacks := $WorkingCrates.get_children()
	if crate_masks.size() != stacks.size():
		return
	for i in stacks.size():
		stacks[i].apply_mask(crate_masks[i])
