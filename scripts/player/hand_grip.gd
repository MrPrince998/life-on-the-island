class_name HandGrip
extends SkeletonModifier3D
## Makes one hand hold a rod-like object (the fishing rod, or the reel's crank knob).
## Runs after the animation each frame, so it works with any clip:
##   1. turns the wrist so the object runs through the fist, crossing the palm slightly
##      diagonally (as a real fishing rod grip does) with the palm facing grip_palm_facing;
##   2. optionally (reach_provider set) bends the arm with two-bone IK so the fist lands
##      exactly on a target point, e.g. the left hand on the rod butt or the reel crank;
##   3. curls the fingers around the object and lays the thumb over it.
##
## All directions are worked out from the rig's own finger bones, so this does not
## depend on how a particular model's bone axes happen to point, and it works for
## either hand. Use `influence` (from SkeletonModifier3D) to fade the grip in and out.

## "Right" or "Left". Set before the node enters the tree.
@export var side: String = "Right"
## Extra bend at each finger joint (knuckle, middle, tip), in degrees, toward the palm.
@export var finger_curl: Vector3 = Vector3(25.0, 50.0, 40.0)
## Extra bend of the thumb's two outer joints (negative = presses down over the handle).
@export var thumb_curl: float = -15.0
## How diagonally the handle crosses the palm (0 = straight across, like holding a hammer).
@export var diagonal_degrees: float = 35.0
@export var holding: bool = false

## World-space direction the held object points (rod: toward its tip). Zero = leave the wrist alone.
var grip_direction: Vector3 = Vector3.ZERO
## World-space direction the palm should face (from the palm toward the handle).
var grip_palm_facing: Vector3 = Vector3.ZERO
## Radius of the held handle, in the hand bone's units.
var rod_radius: float = 0.017
## Optional. Called during the modification; returns {} (no reach) or a Dictionary with
## world-space "position" (where the centre of the fist must be), "direction",
## "palm" and "pole" (which way the elbow should point).
var reach_provider: Callable
## Turns the chest toward the hand's side by this many degrees before reaching (e.g. so
## the other shoulder comes forward while reeling). Applied first, so both hands follow.
var torso_twist: float = 0.0
@export var torso_bone: String = "mixamorig_Spine2"

var calls: int = 0

var _hand: int = -1
var _forearm: int = -1
var _upper_arm: int = -1
## Hand-bone space: little finger -> index finger, wrist -> knuckles, and out of the palm.
var _fist_axis := Vector3.RIGHT
var _finger_dir := Vector3.UP
var _palm_dir := Vector3.BACK
var _knuckle := Vector3(0, 0.07, 0)
## [bone index, extra rotation in that bone's own space]
var _curls: Array = []


func _ready() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var prefix := "mixamorig_" + side
	_hand = skeleton.find_bone(prefix + "Hand")
	_forearm = skeleton.find_bone(prefix + "ForeArm")
	_upper_arm = skeleton.find_bone(prefix + "Arm")
	var index := skeleton.find_bone(prefix + "HandIndex1")
	var pinky := skeleton.find_bone(prefix + "HandPinky1")
	var middle := skeleton.find_bone(prefix + "HandMiddle1")
	if _hand < 0 or index < 0 or pinky < 0 or middle < 0:
		push_warning("HandGrip: %s hand bones not found." % side)
		_hand = -1
		return
	_knuckle = skeleton.get_bone_rest(middle).origin
	_finger_dir = _knuckle.normalized()
	var across := skeleton.get_bone_rest(index).origin - skeleton.get_bone_rest(pinky).origin
	_fist_axis = (across - _finger_dir * across.dot(_finger_dir)).normalized()
	# The palm is the side the fingers naturally bend toward (from the finger chain).
	_palm_dir = _fist_axis.cross(_finger_dir).normalized()
	var tip := _finger_tip_local(skeleton, middle)
	if (tip - _knuckle).dot(_palm_dir) < 0.0:
		_palm_dir = -_palm_dir
	# Turning around this axis bends a finger from pointing straight toward the palm.
	var curl_axis := _finger_dir.cross(_palm_dir).normalized()

	var hand_rest := skeleton.get_bone_global_rest(_hand).basis.orthonormalized()
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in [1, 2, 3]:
			_add_curl(skeleton, hand_rest, curl_axis, "%s%s%d" % [prefix + "Hand", finger, joint], finger_curl[joint - 1])
	for joint in [2, 3]:
		_add_curl(skeleton, hand_rest, curl_axis, "%sThumb%d" % [prefix + "Hand", joint], thumb_curl)


## Middle finger's last joint, in hand-bone space (rest pose).
func _finger_tip_local(skeleton: Skeleton3D, first: int) -> Vector3:
	var xf := Transform3D()
	var bone := first
	for i in 3:
		xf = xf * skeleton.get_bone_rest(bone)
		var children := skeleton.get_bone_children(bone)
		if children.is_empty():
			break
		bone = children[0]
	return xf.origin


func _add_curl(skeleton: Skeleton3D, hand_rest: Basis, axis_in_hand: Vector3, bone_name: String, degrees: float) -> void:
	var idx := skeleton.find_bone(bone_name)
	if idx < 0:
		return
	var bone_rest := skeleton.get_bone_global_rest(idx).basis.orthonormalized()
	var axis := (bone_rest.inverse() * (hand_rest * axis_in_hand)).normalized()
	_curls.append([idx, Quaternion(axis, deg_to_rad(degrees))])


## The line the handle follows through the fist, in hand-bone space.
func get_grip_axis() -> Vector3:
	var d := deg_to_rad(diagonal_degrees)
	return (_fist_axis * cos(d) + _finger_dir * sin(d)).normalized()


## Centre of the handle inside the closed fist, in hand-bone space: just past the
## knuckle line, one handle-radius (plus a finger's thickness) out from the palm.
func get_grip_point_local() -> Vector3:
	return _knuckle * 0.85 + _palm_dir * (rod_radius + _knuckle.length() * 0.08)


## Centre of the fist in world space (uses the current, possibly modified, pose).
func get_grip_point_world() -> Vector3:
	var skeleton := get_skeleton()
	if skeleton == null or _hand < 0:
		return Vector3.ZERO
	return skeleton.global_transform * skeleton.get_bone_global_pose(_hand) * get_grip_point_local()


func _process_modification_with_delta(_delta: float) -> void:
	calls += 1
	if not holding or _hand < 0:
		return
	var skeleton := get_skeleton()
	if absf(torso_twist) > 0.01:
		_twist_torso(skeleton)
	var reach: Dictionary = reach_provider.call() if reach_provider.is_valid() else {}
	if reach.has("direction"):
		grip_direction = reach.direction
	if reach.has("palm"):
		grip_palm_facing = reach.palm
	var hand_rot: Variant = _wanted_hand_rotation(skeleton)
	if reach.has("position") and hand_rot != null:
		_reach(skeleton, reach.position, reach.pole, hand_rot)
	if hand_rot != null:
		_set_global_rotation(skeleton, _hand, hand_rot)
	for curl in _curls:
		var idx: int = curl[0]
		skeleton.set_bone_pose_rotation(idx, skeleton.get_bone_pose_rotation(idx) * (curl[1] as Quaternion))


func _twist_torso(skeleton: Skeleton3D) -> void:
	var bone := skeleton.find_bone(torso_bone)
	if bone < 0:
		return
	# Character faces skeleton +Z; turning toward the right hand side is negative around +Y
	# for the right hand (left shoulder comes forward), positive for the left hand.
	var sign := -1.0 if side == "Right" else 1.0
	var rot := Quaternion(Vector3.UP, deg_to_rad(torso_twist) * sign) * skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	_set_global_rotation(skeleton, bone, rot)


## Hand rotation (skeleton space) that points the grip axis along grip_direction with
## the palm facing grip_palm_facing as closely as possible. Null = leave the wrist alone.
func _wanted_hand_rotation(skeleton: Skeleton3D) -> Variant:
	if grip_direction.length_squared() < 0.0001:
		return null
	var to_skeleton := skeleton.global_basis.inverse()
	var want_axis := (to_skeleton * grip_direction).normalized()
	var facing := grip_palm_facing if grip_palm_facing.length_squared() > 0.0001 else Vector3.UP
	var want_palm := to_skeleton * facing
	want_palm = want_palm - want_axis * want_palm.dot(want_axis)
	if want_palm.length_squared() < 0.0001:
		return null
	want_palm = want_palm.normalized()
	var axis := get_grip_axis()
	var hand_frame := Basis(axis, _palm_dir, axis.cross(_palm_dir))
	var target_frame := Basis(want_axis, want_palm, want_axis.cross(want_palm))
	return (target_frame * hand_frame.transposed()).get_rotation_quaternion()


## Two-bone IK: bends the upper arm and forearm so that, with the hand turned to
## hand_rot, the centre of the fist lands on target (world). The elbow bends toward pole.
func _reach(skeleton: Skeleton3D, target_world: Vector3, pole_world: Vector3, hand_rot: Quaternion) -> void:
	if _upper_arm < 0 or _forearm < 0:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var wrist := to_skeleton * target_world - hand_rot * get_grip_point_local()
	var pole := (skeleton.global_basis.inverse() * pole_world).normalized()
	var shoulder := skeleton.get_bone_global_pose(_upper_arm).origin
	var upper_len := skeleton.get_bone_rest(_forearm).origin.length()
	var lower_len := skeleton.get_bone_rest(_hand).origin.length()
	var to_target := wrist - shoulder
	var dist := clampf(to_target.length(), absf(upper_len - lower_len) + 0.001, (upper_len + lower_len) * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((upper_len * upper_len + dist * dist - lower_len * lower_len) / (2.0 * upper_len * dist), -1.0, 1.0)
	var bend_dir := pole - dir * pole.dot(dir)
	if bend_dir.length_squared() < 0.0001:
		bend_dir = Vector3.DOWN - dir * dir.y
	bend_dir = bend_dir.normalized()
	var elbow := shoulder + dir * (upper_len * cos_a) + bend_dir * (upper_len * sqrt(1.0 - cos_a * cos_a))
	var wrist_reached := shoulder + dir * dist
	_point_bone(skeleton, _upper_arm, _forearm, elbow)
	_point_bone(skeleton, _forearm, _hand, wrist_reached)


## Rotates `bone` (smallest turn) so that its child joint lies toward `target` (skeleton space).
func _point_bone(skeleton: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := (pose.basis * skeleton.get_bone_rest(child).origin).normalized()
	var wanted := (target - pose.origin).normalized()
	if current.dot(wanted) < -0.999:
		return
	var rot := Quaternion(current, wanted) * pose.basis.get_rotation_quaternion()
	_set_global_rotation(skeleton, bone, rot)


func _set_global_rotation(skeleton: Skeleton3D, bone: int, rot: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_rot := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, parent_rot.inverse() * rot)
