extends SceneTree
## Dev tool: builds the player's animation library from bone poses.
## Run: Godot --headless --path . --script res://tools/build_character_animations.gd
##
## The character's walk clip comes from the Tripo/Mixamo file. The other clips are
## built here from bone rotations, so they work on any model with the same bone names.
## Output: res://resources/animations/character_library.tres

const CHARACTER := "res://source_assets/tripo/tripo_convert_5283d58f-c5ab-416f-b627-ea86d64e6fa6.glb"
const OUT := "res://resources/animations/character_library.tres"
## The character model is shown at this scale (scenes/player/character.tscn).
const CHARACTER_SCALE := 1.8
const SKEL := "Armature/Skeleton3D:"

# Pose poses: bone -> Vector3 euler degrees (XYZ), applied on top of the rest pose.
# Each clip is a list of [time, {bone: euler}] keyframes. Missing bones stay at rest.
var clips := {}
## Neutral standing pose: local rotation per bone. Arms hang down; legs keep the model's pose.
var _stand: Dictionary = {}
var _skel: Skeleton3D


func _init() -> void:
	var character := (load(CHARACTER) as PackedScene).instantiate()
	var player := character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := character.find_child("Skeleton3D", true, false) as Skeleton3D
	var library := AnimationLibrary.new()
	_stand = _compute_stand_pose(skeleton)
	_skel = skeleton

	# Keep the original walk clip, but make it loop.
	var walk := player.get_animation("walk").duplicate() as Animation
	walk.loop_mode = Animation.LOOP_LINEAR
	_strip_root_drift(walk)
	_fill_missing_bones(skeleton, walk)
	library.add_animation(&"walk", walk)

	_define_clips()
	for clip_name in clips:
		var anim := _make_clip(skeleton, clips[clip_name])
		if clip_name == "run":
			_add_run_bounce(skeleton, anim)
		_fill_missing_bones(skeleton, anim)
		library.add_animation(clip_name, anim)
		print("built ", clip_name, " length=", anim.length, " loop=", anim.loop_mode)

	# Replace the hand-made run with the Mixamo run, retargeted onto our rig, when present.
	if ResourceLoader.exists(RUN_SOURCE):
		var run := _retarget_clip(RUN_SOURCE)
		_fill_missing_bones(skeleton, run)
		if library.has_animation(&"run"):
			library.remove_animation(&"run")
		library.add_animation(&"run", run)
		print("built run from ", RUN_SOURCE, " length=", run.length, " (retargeted)")

	# Fishing: the two-handed Mixamo clips, retargeted. Each also carries the rod's
	# direction per frame (metadata "rod_directions"), taken from the source rig where the
	# hands line up along the rod; on our chunkier character they don't.
	var fishing := {&"fish_hold": [FISH_IDLE_SOURCE, true, -1.0], &"fish_cast": [FISH_CAST_SOURCE, false, FISH_CAST_END]}
	for clip_name in fishing:
		var def: Array = fishing[clip_name]
		if not ResourceLoader.exists(def[0]):
			push_error("Missing fishing animation: " + def[0])
			continue
		var clip := _retarget_clip(def[0], def[1], def[2], true)
		_fill_missing_bones(skeleton, clip)
		library.add_animation(clip_name, clip)
		print("built ", clip_name, " from ", def[0], " length=", clip.length)

	# Sitting (benches, porch steps, the dock): Mixamo sit-down, sit-idle and stand-up,
	# retargeted. Hips keep their (scaled) height, so the body lowers onto the seat.
	var sitting := {&"sit_down": [SIT_DOWN_SOURCE, false], &"sit_idle": [SIT_IDLE_SOURCE, true], &"stand_up": [STAND_UP_SOURCE, false]}
	for clip_name in sitting:
		var sdef: Array = sitting[clip_name]
		if not ResourceLoader.exists(sdef[0]):
			push_error("Missing sitting animation: " + sdef[0])
			continue
		var sit_clip := _retarget_clip(sdef[0], sdef[1])
		_fill_missing_bones(skeleton, sit_clip)
		library.add_animation(clip_name, sit_clip)
		print("built ", clip_name, " from ", sdef[0], " length=", sit_clip.length)

	var err := ResourceSaver.save(library, OUT)
	print("saved ", OUT, " ", error_string(err))
	character.free()
	quit(0 if err == OK else 1)


# ---- Retargeting a Mixamo clip ------------------------------------------------

const RUN_SOURCE := "res://source_assets/mixamo/Running.fbx"
const FISH_IDLE_SOURCE := "res://source_assets/mixamo/Fishing Idle.fbx"
const FISH_CAST_SOURCE := "res://source_assets/mixamo/Fishing Cast.fbx"
const SIT_DOWN_SOURCE := "res://source_assets/mixamo/npc_sit_down.fbx"
const SIT_IDLE_SOURCE := "res://source_assets/mixamo/npc_sit_idle.fbx"
const STAND_UP_SOURCE := "res://source_assets/mixamo/npc_stand_up.fbx"
## The Mixamo cast is 8.8 s: wind-up (peak ~1.45 s), release (~2.0 s), then a long
## follow-through and return to idle. Only the part up to the rod settling is kept;
## the game blends into the waiting pose from there.
const FISH_CAST_END := 2.9
const RETARGET_FPS := 30.0
## Torso and head: copy the source's change of rotation (both rigs stand upright at rest).
const DELTA_BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
## Limbs: point each segment the same way as the source. This copes with the source
## being in a T-pose and ours in an A-pose, and with differently oriented bone axes.
const AIM_BONES := [
	["LeftUpLeg", "LeftLeg"], ["LeftLeg", "LeftFoot"], ["LeftFoot", "LeftToeBase"],
	["RightUpLeg", "RightLeg"], ["RightLeg", "RightFoot"], ["RightFoot", "RightToeBase"],
	["LeftShoulder", "LeftArm"], ["LeftArm", "LeftForeArm"], ["LeftForeArm", "LeftHand"],
	["RightShoulder", "RightArm"], ["RightArm", "RightForeArm"], ["RightForeArm", "RightHand"],
]


## Retargets the first animation of a Mixamo file (skeleton with mixamorig_ bone names)
## onto our character. Root forward/sideways motion is removed; the hip height is kept,
## scaled. `end_time` > 0 keeps only the start of the clip.
## `with_rod` stores the left-hand -> right-hand direction of the source (skeleton space,
## sampled at RETARGET_FPS) as metadata "rod_directions" for CharacterAnimator.
func _retarget_clip(path: String, loop: bool = true, end_time: float = -1.0, with_rod: bool = false) -> Animation:
	var src_root := (load(path) as PackedScene).instantiate()
	var src_skel := src_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var src_player := src_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var src_anim := src_player.get_animation(src_player.get_animation_list()[0])
	var rot_tracks := {}
	var pos_tracks := {}
	for i in src_anim.get_track_count():
		var bone := str(src_anim.track_get_path(i)).get_slice(":", 1)
		if src_anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot_tracks[bone] = i
		elif src_anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			pos_tracks[bone] = i

	var length := minf(src_anim.length, end_time) if end_time > 0.0 else src_anim.length
	var out := Animation.new()
	out.length = length
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var out_tracks := {}
	for name in DELTA_BONES:
		out_tracks[name] = _add_rot_track(out, name)
	for aim in AIM_BONES:
		out_tracks[aim[0]] = _add_rot_track(out, aim[0])
	var hips_pos_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_pos_track, NodePath(SKEL + "mixamorig_Hips"))

	var src_hips := src_skel.find_bone("mixamorig_Hips")
	var tgt_hips := _skel.find_bone("mixamorig_Hips")
	var src_hips_rest_y := src_skel.get_bone_global_rest(src_hips).origin.y
	var tgt_hips_rest := _skel.get_bone_rest(tgt_hips).origin
	var frames := int(round(length * RETARGET_FPS))
	var rod_dirs := PackedVector3Array()
	var src_lhand := src_skel.find_bone("mixamorig_LeftHand")
	var src_rhand := src_skel.find_bone("mixamorig_RightHand")
	for f in frames + 1:
		var t := minf(f / RETARGET_FPS, length)
		var src_global := _source_globals(src_skel, src_anim, rot_tracks, pos_tracks, t)
		if with_rod:
			var rod := (src_global[src_rhand] as Transform3D).origin - (src_global[src_lhand] as Transform3D).origin
			rod_dirs.append(rod.normalized())
		var pose := {}
		for name in DELTA_BONES:
			var si := src_skel.find_bone("mixamorig_" + name)
			var ti := _skel.find_bone("mixamorig_" + name)
			var src_now := (src_global[si] as Transform3D).basis.get_rotation_quaternion()
			var src_rest := src_skel.get_bone_global_rest(si).basis.get_rotation_quaternion()
			var tgt_rest := _skel.get_bone_global_rest(ti).basis.get_rotation_quaternion()
			var world_now := (src_now * src_rest.inverse()) * tgt_rest
			var parent_q := _global_basis(_skel, pose, _skel.get_bone_parent(ti)).get_rotation_quaternion()
			pose[name] = (parent_q.inverse() * world_now).normalized()
		for aim in AIM_BONES:
			var sb := src_skel.find_bone("mixamorig_" + aim[0])
			var sc := src_skel.find_bone("mixamorig_" + aim[1])
			var direction: Vector3 = (src_global[sc] as Transform3D).origin - (src_global[sb] as Transform3D).origin
			_aim_into(pose, aim[0], aim[1], direction)
		for name in out_tracks:
			out.rotation_track_insert_key(out_tracks[name], t, pose[name])
		var src_hips_y := (src_global[src_hips] as Transform3D).origin.y
		out.position_track_insert_key(hips_pos_track, t, Vector3(tgt_hips_rest.x, tgt_hips_rest.y * src_hips_y / src_hips_rest_y, tgt_hips_rest.z))

	# How far the source body travels per cycle, converted to our character's size (metres).
	if loop and path == RUN_SOURCE and pos_tracks.has("mixamorig_Hips"):
		var track: int = pos_tracks["mixamorig_Hips"]
		var travel := (src_anim.track_get_key_value(track, src_anim.track_get_key_count(track) - 1) as Vector3) - (src_anim.track_get_key_value(track, 0) as Vector3)
		var size_ratio := tgt_hips_rest.y * CHARACTER_SCALE / src_hips_rest_y
		print("RUN cycle: %.3f s, body travel %.3f m at our size -> %.2f m/s at playback 1.0" % [src_anim.length, travel.length() * size_ratio, travel.length() * size_ratio / src_anim.length])
	if with_rod:
		out.set_meta(&"rod_directions", rod_dirs)
		out.set_meta(&"rod_fps", RETARGET_FPS)
	src_root.free()
	return out


func _add_rot_track(anim: Animation, bone_name: String) -> int:
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath(SKEL + "mixamorig_" + bone_name))
	return track


## Source skeleton-space transforms of every bone at time t.
func _source_globals(skel: Skeleton3D, anim: Animation, rot_tracks: Dictionary, pos_tracks: Dictionary, t: float) -> Dictionary:
	var result := {}
	for i in skel.get_bone_count():
		var bone_name := skel.get_bone_name(i)
		var rest := skel.get_bone_rest(i)
		var q := rest.basis.get_rotation_quaternion()
		var origin := rest.origin
		if rot_tracks.has(bone_name):
			q = anim.rotation_track_interpolate(rot_tracks[bone_name], t)
		if pos_tracks.has(bone_name):
			origin = anim.position_track_interpolate(pos_tracks[bone_name], t)
		var local := Transform3D(Basis(q), origin)
		var parent := skel.get_bone_parent(i)
		result[i] = (result[parent] as Transform3D) * local if parent >= 0 else local
	return result


## Like _aim(), but adds one bone to an existing pose (rest pose where the pose has no entry).
func _aim_into(pose: Dictionary, bone: String, child: String, direction: Vector3) -> void:
	if direction.length_squared() < 1e-8:
		return
	var bone_idx := _skel.find_bone("mixamorig_" + bone)
	var child_idx := _skel.find_bone("mixamorig_" + child)
	var base: Quaternion = pose.get(bone, _skel.get_bone_rest(bone_idx).basis.get_rotation_quaternion())
	var parent_basis := _global_basis(_skel, pose, _skel.get_bone_parent(bone_idx))
	var current: Vector3 = (base * _skel.get_bone_rest(child_idx).origin.normalized()).normalized()
	var wanted: Vector3 = (parent_basis.inverse() * direction.normalized()).normalized()
	pose[bone] = (Quaternion(current, wanted) * base).normalized()


# ---- Helpers --------------------------------------------------------------

## Every clip must set every body bone. If a clip leaves a bone out, the bone keeps
## whatever pose the previous clip left it in (this froze the legs when stopping
## and after landing). Missing bones are given a rest-pose key.
const BODY_BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
	"LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]


func _fill_missing_bones(skeleton: Skeleton3D, anim: Animation) -> void:
	var tracked := {}
	for i in anim.get_track_count():
		tracked[str(anim.track_get_path(i))] = true
	for bone_name in BODY_BONES:
		var path: String = SKEL + "mixamorig_" + bone_name
		if tracked.has(path):
			continue
		var bone_idx := skeleton.find_bone("mixamorig_" + bone_name)
		if bone_idx < 0:
			push_warning("missing bone " + bone_name)
			continue
		var rest_q := _base_rotation(skeleton, bone_idx)
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(path))
		anim.rotation_track_insert_key(track, 0.0, rest_q)
		anim.rotation_track_insert_key(track, anim.length, rest_q)


## The source walk moves the hips about 1.3 m forward over one cycle, then snaps back
## when it loops. The game moves the character itself, so keep only the up-and-down
## bounce of the hips and hold forward/side position at the first frame.
func _strip_root_drift(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var base: Vector3 = anim.track_get_key_value(i, 0)
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(base.x, v.y, base.z))

func _make_clip(skeleton: Skeleton3D, def: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = def.length
	anim.loop_mode = Animation.LOOP_LINEAR if def.get("loop", false) else Animation.LOOP_NONE
	var keys_by_bone: Dictionary = def.keys
	for bone_name in keys_by_bone:
		var bone_idx := skeleton.find_bone("mixamorig_" + bone_name)
		if bone_idx < 0:
			push_warning("missing bone " + bone_name)
			continue
		var rest_q := _base_rotation(skeleton, bone_idx)
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(SKEL + "mixamorig_" + bone_name))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for key in keys_by_bone[bone_name]:
			var q: Quaternion
			if key[1] is Quaternion:
				q = key[1]
			else:
				q = rest_q * Quaternion.from_euler((key[1] as Vector3) * PI / 180.0)
			anim.rotation_track_insert_key(track, key[0], q)
	return anim


## The rotation every clip is measured from: the neutral standing pose if we have one.
func _base_rotation(skeleton: Skeleton3D, bone_idx: int) -> Quaternion:
	var name := skeleton.get_bone_name(bone_idx).trim_prefix("mixamorig_")
	if _stand.has(name):
		return _stand[name]
	return skeleton.get_bone_rest(bone_idx).basis.get_rotation_quaternion()


## Turns the model's arms to hang down at the sides (the model starts with its arms
## held out). Legs and body keep the model's own pose. Each limb bone is rotated so the bone below it points down,
## taking the parent's rotation into account.
func _compute_stand_pose(skeleton: Skeleton3D) -> Dictionary:
	var stand := {}
	var limbs := [
		["LeftArm", "LeftForeArm", Vector3(0.14, -0.99, 0)],
		["LeftForeArm", "LeftHand", Vector3(0.14, -0.99, 0)],
		["RightArm", "RightForeArm", Vector3(-0.14, -0.99, 0)],
		["RightForeArm", "RightHand", Vector3(-0.14, -0.99, 0)],
	]
	for limb in limbs:
		var bone_idx := skeleton.find_bone("mixamorig_" + limb[0])
		var child_idx := skeleton.find_bone("mixamorig_" + limb[1])
		if bone_idx < 0 or child_idx < 0:
			push_warning("stand pose: missing bone")
			continue
		var parent_basis := _global_basis(skeleton, stand, skeleton.get_bone_parent(bone_idx))
		var current: Vector3 = skeleton.get_bone_rest(child_idx).origin.normalized()
		var wanted: Vector3 = (parent_basis.inverse() * (limb[2] as Vector3)).normalized()
		stand[limb[0]] = Quaternion(current, wanted)
	return stand


## Global rotation of a bone, using stand-pose rotations where they exist.
func _global_basis(skeleton: Skeleton3D, stand: Dictionary, bone_idx: int) -> Basis:
	if bone_idx < 0:
		return Basis()
	var name := skeleton.get_bone_name(bone_idx).trim_prefix("mixamorig_")
	var local: Basis
	if stand.has(name):
		local = Basis(stand[name])
	else:
		local = skeleton.get_bone_rest(bone_idx).basis
	return _global_basis(skeleton, stand, skeleton.get_bone_parent(bone_idx)) * local


## Mirror a pose so the same numbers drive left and right arms/legs.
## Aim pose: rotates each listed bone (in order, parents first) so that its child bone
## points in a direction given in CHARACTER space: +Z = the way the character faces,
## +Y = up, -X = the character's right side. Rotation starts from the standing pose and
## turns by the smallest angle, so the limb keeps its natural twist.
## aims: Array of [bone, child_bone, direction]. Returns {bone_name: local Quaternion}.
func _aim(aims: Array) -> Dictionary:
	var pose := _stand.duplicate()
	for aim in aims:
		var bone_idx := _skel.find_bone("mixamorig_" + aim[0])
		var child_idx := _skel.find_bone("mixamorig_" + aim[1])
		var base: Quaternion = pose.get(aim[0], _skel.get_bone_rest(bone_idx).basis.get_rotation_quaternion())
		var parent_basis := _global_basis(_skel, pose, _skel.get_bone_parent(bone_idx))
		var child_offset: Vector3 = _skel.get_bone_rest(child_idx).origin.normalized()
		var current: Vector3 = (base * child_offset).normalized()
		var wanted: Vector3 = (parent_basis.inverse() * (aim[2] as Vector3).normalized()).normalized()
		pose[aim[0]] = Quaternion(current, wanted) * base
	return pose


## Turns a list of [time, aims] frames into clip keys for every aimed bone.
func _aim_keys(frames: Array) -> Dictionary:
	var names := {}
	for frame in frames:
		for aim in frame[1]:
			names[aim[0]] = true
	var keys := {}
	for frame in frames:
		var pose := _aim(frame[1])
		for bone_name in names:
			var bone_idx := _skel.find_bone("mixamorig_" + bone_name)
			var q: Quaternion = pose.get(bone_name, _base_rotation(_skel, bone_idx))
			if not keys.has(bone_name):
				keys[bone_name] = []
			keys[bone_name].append([frame[0], q])
	return keys


## Mirror a direction for the left side (character space: left = +X).
func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


func _define_clips() -> void:
	var spine := "Spine1"

	# Idle: gentle breathing and a slight sway (small offsets from the standing pose).
	clips["idle"] = {"length": 3.2, "loop": true, "keys": {
		spine: [[0.0, Vector3(0, 0, 0)], [1.6, Vector3(-2.0, 0, 0)], [3.2, Vector3(0, 0, 0)]],
		"Head": [[0.0, Vector3(0, 0, 0)], [1.6, Vector3(-1.5, 3, 0)], [3.2, Vector3(0, 0, 0)]],
	}}

	# Holding and casting the rod come from the Mixamo fishing clips (see _init).

	# Reeling: rod hand lifts and lowers while the other hand winds the reel.
	var reel_a := [["RightArm", "RightForeArm", Vector3(-0.25, -0.8, 0.3)], ["RightForeArm", "RightHand", Vector3(-0.05, 0.5, 0.9)],
		["LeftArm", "LeftForeArm", Vector3(0.1, -0.85, 0.35)], ["LeftForeArm", "LeftHand", Vector3(-0.55, 0.25, 0.8)]]
	var reel_b := [["RightArm", "RightForeArm", Vector3(-0.25, -0.75, 0.45)], ["RightForeArm", "RightHand", Vector3(-0.05, 0.2, 1.0)],
		["LeftArm", "LeftForeArm", Vector3(0.15, -0.8, 0.45)], ["LeftForeArm", "LeftHand", Vector3(-0.45, -0.15, 0.9)]]
	clips["fish_reel"] = {"length": 1.0, "loop": true, "keys": _aim_keys([[0.0, reel_a], [0.5, reel_b], [1.0, reel_a]])}
	clips["fish_reel"].keys[spine] = [[0.0, Vector3(-4, 0, 0)], [0.5, Vector3(2, 0, 0)], [1.0, Vector3(-4, 0, 0)]]

	# Jump: arms lift out for balance, knees tuck a little. Holds while in the air.
	var jump_pose := [
		["RightArm", "RightForeArm", Vector3(-0.8, 0.05, 0.2)], ["RightForeArm", "RightHand", Vector3(-0.65, 0.4, 0.35)],
		["LeftArm", "LeftForeArm", _mirror(Vector3(-0.8, 0.05, 0.2))], ["LeftForeArm", "LeftHand", _mirror(Vector3(-0.65, 0.4, 0.35))],
		["RightUpLeg", "RightLeg", Vector3(-0.05, -0.82, 0.55)], ["RightLeg", "RightFoot", Vector3(0.0, -0.9, -0.3)],
		["LeftUpLeg", "LeftLeg", Vector3(0.05, -0.9, 0.3)], ["LeftLeg", "LeftFoot", Vector3(0.0, -0.85, -0.45)],
	]
	var jump_start := [
		["RightArm", "RightForeArm", Vector3(-0.14, -0.99, 0.0)], ["RightForeArm", "RightHand", Vector3(-0.14, -0.99, 0.0)],
		["LeftArm", "LeftForeArm", Vector3(0.14, -0.99, 0.0)], ["LeftForeArm", "LeftHand", Vector3(0.14, -0.99, 0.0)],
	]
	clips["jump"] = {"length": 0.6, "loop": false, "keys": _aim_keys([[0.0, jump_start], [0.25, jump_pose], [0.6, jump_pose]])}

	# Watering / digging: bend forward and reach both arms down in front.
	var reach := [["RightArm", "RightForeArm", Vector3(-0.15, -0.55, 0.8)], ["RightForeArm", "RightHand", Vector3(-0.05, -0.7, 0.7)],
		["LeftArm", "LeftForeArm", Vector3(0.15, -0.55, 0.8)], ["LeftForeArm", "LeftHand", Vector3(0.05, -0.7, 0.7)]]
	clips["farm_swing"] = {"length": 1.4, "loop": false, "keys": _aim_keys([[0.0, jump_start], [0.5, reach], [0.9, reach], [1.4, jump_start]])}
	clips["farm_swing"].keys[spine] = [[0.0, Vector3(0, 0, 0)], [0.5, Vector3(30, 0, 0)], [0.9, Vector3(35, 0, 0)], [1.4, Vector3(0, 0, 0)]]

	# Ukulele: held across the body, left hand up the neck, right hand strumming over
	# the sound hole with a gentle sway.
	var uke_a := [["RightArm", "RightForeArm", Vector3(-0.3, -0.8, 0.35)], ["RightForeArm", "RightHand", Vector3(0.6, -0.2, 0.6)],
		["LeftArm", "LeftForeArm", Vector3(0.6, -0.55, 0.45)], ["LeftForeArm", "LeftHand", Vector3(0.45, 0.3, 0.75)]]
	var uke_b := [["RightArm", "RightForeArm", Vector3(-0.3, -0.78, 0.38)], ["RightForeArm", "RightHand", Vector3(0.6, -0.45, 0.5)],
		["LeftArm", "LeftForeArm", Vector3(0.6, -0.55, 0.45)], ["LeftForeArm", "LeftHand", Vector3(0.45, 0.32, 0.75)]]
	clips["uke_play"] = {"length": 1.2, "loop": true, "keys": _aim_keys([[0.0, uke_a], [0.3, uke_b], [0.6, uke_a], [0.9, uke_b], [1.2, uke_a]])}
	clips["uke_play"].keys[spine] = [[0.0, Vector3(4, 0, -2)], [0.6, Vector3(4, 0, 2)], [1.2, Vector3(4, 0, -2)]]
	clips["uke_play"].keys["Head"] = [[0.0, Vector3(6, 0, 3)], [0.6, Vector3(6, 0, -3)], [1.2, Vector3(6, 0, 3)]]

	# Wave (also used to celebrate a catch): right hand up, waving from the elbow.
	var up_a := [["RightArm", "RightForeArm", Vector3(-0.55, 0.8, 0.1)], ["RightForeArm", "RightHand", Vector3(-0.45, 0.9, 0.2)]]
	var up_b := [["RightArm", "RightForeArm", Vector3(-0.55, 0.8, 0.1)], ["RightForeArm", "RightHand", Vector3(0.15, 0.95, 0.2)]]
	var down := [["RightArm", "RightForeArm", Vector3(-0.14, -0.99, 0.0)], ["RightForeArm", "RightHand", Vector3(-0.14, -0.99, 0.0)]]
	clips["wave"] = {"length": 1.6, "loop": false, "keys": _aim_keys([[0.0, down], [0.3, up_a], [0.55, up_b], [0.8, up_a], [1.05, up_b], [1.3, up_a], [1.6, down]])}

	_define_run(spine)


## Run: a relaxed jog. Knees lift in front, heels kick up behind, elbows bent and
## pumping opposite to the legs, body leaning forward, hips bouncing once per step.
## One cycle (two steps) lasts RUN_LENGTH seconds and is designed for 3.2 m/s
## (see CharacterAnimator.RUN_METRES_PER_SECOND_AT_SCALE_ONE).
const RUN_LENGTH := 0.6

func _define_run(spine: String) -> void:
	# Right leg through 8 phases (thigh direction, shin direction), character space.
	# 0 foot lands in front (leg almost straight), 1 under the body, 2-3 the straight leg
	# drives back and pushes off, 4 heel kicks up, 5-6 knee swings through and lifts,
	# 7 leg reaches forward for the next landing. While the foot carries the body
	# (0-3) the knee stays nearly straight. Feet stay under the hips (no bowing out).
	var leg := [
		[Vector3(-0.03, -0.94, 0.34), Vector3(0.0, -0.97, 0.24)],
		[Vector3(-0.03, -1.0, 0.0), Vector3(0.0, -0.985, -0.17)],
		[Vector3(-0.03, -0.95, -0.31), Vector3(0.0, -0.92, -0.38)],
		[Vector3(-0.03, -0.87, -0.5), Vector3(0.0, -0.78, -0.62)],
		[Vector3(-0.03, -0.93, -0.35), Vector3(0.0, -0.25, -0.97)],
		[Vector3(-0.03, -0.92, 0.38), Vector3(0.0, -0.55, -0.83)],
		[Vector3(-0.03, -0.70, 0.71), Vector3(0.0, -0.95, -0.30)],
		[Vector3(-0.03, -0.80, 0.60), Vector3(0.0, -0.94, 0.33)],
	]
	# Right arm swung back (while the right leg is forward) and swung forward.
	var arm_back := [Vector3(-0.22, -0.82, -0.52), Vector3(-0.04, -0.30, 0.95)]
	var arm_fwd := [Vector3(-0.18, -0.80, 0.55), Vector3(0.10, 0.55, 0.82)]
	var frames := []
	for k in 9:
		var r := k % 8
		var l := (k + 4) % 8
		var t := RUN_LENGTH * k / 8.0
		var r_fwd := (1.0 - cos(TAU * r / 8.0)) * 0.5
		var l_fwd := (1.0 - cos(TAU * l / 8.0)) * 0.5
		var r_up: Vector3 = (arm_back[0] as Vector3).lerp(arm_fwd[0], r_fwd)
		var r_lo: Vector3 = (arm_back[1] as Vector3).lerp(arm_fwd[1], r_fwd)
		var l_up: Vector3 = (arm_back[0] as Vector3).lerp(arm_fwd[0], l_fwd)
		var l_lo: Vector3 = (arm_back[1] as Vector3).lerp(arm_fwd[1], l_fwd)
		frames.append([t, [
			["RightUpLeg", "RightLeg", leg[r][0]], ["RightLeg", "RightFoot", leg[r][1]],
			["LeftUpLeg", "LeftLeg", _mirror(leg[l][0])], ["LeftLeg", "LeftFoot", _mirror(leg[l][1])],
			["RightArm", "RightForeArm", r_up], ["RightForeArm", "RightHand", r_lo],
			["LeftArm", "LeftForeArm", _mirror(l_up)], ["LeftForeArm", "LeftHand", _mirror(l_lo)],
		]])
	var def := {"length": RUN_LENGTH, "loop": true, "keys": _aim_keys(frames)}
	# Lean forward into the run, dipping a little each time a foot lands.
	var lean := []
	var head := []
	for k in 5:
		var t := RUN_LENGTH * k / 4.0
		var dip := 2.0 if k % 2 == 1 else 0.0
		lean.append([t, Vector3(9.0 + dip, 0, 0)])
		head.append([t, Vector3(-6.0 - dip, 0, 0)])
	def.keys[spine] = lean
	def.keys["Head"] = head
	clips["run"] = def


## Hip bounce for the run: lowest as each foot takes the weight, highest in the air.
func _add_run_bounce(skeleton: Skeleton3D, anim: Animation) -> void:
	var hips := skeleton.find_bone("mixamorig_Hips")
	var rest := skeleton.get_bone_rest(hips).origin
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, NodePath(SKEL + "mixamorig_Hips"))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	var heights := [0.445, 0.450, 0.455, 0.462]
	for k in 9:
		anim.position_track_insert_key(track, RUN_LENGTH * k / 8.0, Vector3(rest.x, heights[k % 4], rest.z))
