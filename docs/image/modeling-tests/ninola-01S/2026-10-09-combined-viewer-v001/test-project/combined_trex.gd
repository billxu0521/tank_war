extends Trex
var eval_changes_enabled := true
const NECK_LIFT := 12.0
const HEAD_COMPENSATION := -4.0
const JAW_NEUTRAL := 1.5
func _process(delta: float) -> void:
	super._process(delta)
	if not eval_changes_enabled: return
	var jaw_pitch: float = pose_rot("jaw").get_euler().x
	_pose("jaw",Vector3.RIGHT,jaw_pitch+0.12-deg_to_rad(JAW_NEUTRAL))
	# Compose on the current global bone pose in skeleton/model coordinates.
	# Do not edit rest transforms or add world-space angles to parent-space Euler constants.
	_apply_model_pitch("neck",NECK_LIFT)
	_apply_model_pitch("head",HEAD_COMPENSATION)
func _apply_model_pitch(name: String, degrees: float) -> void:
	var id: int = _idx[name]
	var pose: Transform3D = skel.get_bone_global_pose(id)
	pose.basis = Basis(Vector3.RIGHT,deg_to_rad(degrees)) * pose.basis
	skel.set_bone_global_pose(id,pose)
