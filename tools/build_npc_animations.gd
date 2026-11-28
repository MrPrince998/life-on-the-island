extends SceneTree
## Dev tool: builds each villager's animation library from the Mixamo clips in
## source_assets/mixamo/npc_*.fbx (downloaded "Without Skin").
## Run: Godot --headless --path . --script res://tools/build_npc_animations.gd [-- id id ...]
## Output: res://resources/animations/npc_<id>_library.tres (one per villager, because
## every model has its own bone proportions and rest pose).
##
## Retargeting works like the player's (tools/build_character_animations.gd): the torso
## and head copy the source's change of rotation, and each limb segment is pointed the
## same way as in the source, so T-pose/A-pose and bone-axis differences don't matter.
## The villager models' skeletons are also turned 90° inside their files, so every
## direction is first rotated from the Mixamo body frame into the villager's body frame.

const NPCS := {
	"bram": "res://source_assets/tripo/npc_bram.glb",
	"oliver": "res://source_assets/tripo/Oliver_character.glb",
	"mia": "res://source_assets/tripo/Mia_character.glb",
	"emma": "res://source_assets/tripo/npc_emma.glb",
	"theo": "res://source_assets/tripo/npc_theo.glb",
	"luna": "res://source_assets/tripo/npc_luna.glb",
	"nana_bea": "res://source_assets/tripo/npc_nana_bea.glb",
	"pip": "res://source_assets/tripo/npc_pip.glb",
	"ambrose": "res://source_assets/tripo/npc_mr-ambrose.glb",
	"marlow": "res://source_assets/tripo/npc_captain_marlow.glb",
}
const SRC := "res://source_assets/mixamo/"
## clip name -> [file, loops]
const CLIPS := {
	"idle": ["npc_breathing_idle.fbx", true],
	"look_around": ["npc_look_around.fbx", false],
	"happy": ["npc_happy.fbx", false],
	"nod": ["npc_nod.fbx", false],
	"wave": ["npc_wave.fbx", false],
	"talk_a": ["npc_talking.fbx", true],
	"talk_b": ["npc_talking_1.fbx", true],
	"talk_c": ["npc_talking_2.fbx", true],
	"think": ["npc_thinking.fbx", true],
	"walk": ["npc_walking.fbx", true],
	"sit_down": ["npc_sit_down.fbx", false],
	"sit_idle": ["npc_sit_idle.fbx", true],
	"stand_up": ["npc_stand_up.fbx", false],
	"plant": ["npc_planting.fbx", true],
	"water": ["npc_watering_plant.fbx", true],
}
const FPS := 30.0
const DELTA_BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]
const AIM_BONES := [
	["LeftUpLeg", "LeftLeg"], ["LeftLeg", "LeftFoot"], ["LeftFoot", "LeftToeBase"],
	["RightUpLeg", "RightLeg"], ["RightLeg", "RightFoot"], ["RightFoot", "RightToeBase"],
	["LeftShoulder", "LeftArm"], ["LeftArm", "LeftForeArm"], ["LeftForeArm", "LeftHand"],
	["RightShoulder", "RightArm"], ["RightArm", "RightForeArm"], ["RightForeArm", "RightHand"],
]

var _skel: Skeleton3D
var _skel_path := ""
var _to_target := Quaternion.IDENTITY  # Mixamo body frame -> villager body frame


func _init() -> void:
	# Optional: only rebuild some villagers, e.g. `-- emma theo`.
	var only := OS.get_cmdline_user_args()
	for id in NPCS:
		if not only.is_empty() and not only.has(id):
			continue
		var model := (load(NPCS[id]) as PackedScene).instantiate()
		_skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		_skel_path = str(model.get_path_to(_skel)) + ":"
		var library := AnimationLibrary.new()
		for clip_name in CLIPS:
			var def: Array = CLIPS[clip_name]
			var path: String = SRC + def[0]
			if not ResourceLoader.exists(path):
				push_warning("missing " + path)
				continue
			var anim := _retarget(path, def[1])
			library.add_animation(StringName(clip_name), anim)
		var out := "res://resources/animations/npc_%s_library.tres" % id
		var err := ResourceSaver.save(library, out)
		print("%s: %d clips -> %s (%s)" % [id, library.get_animation_list().size(), out, error_string(err)])
		model.free()
	quit()


## A body frame from the rest pose: x = character's left, y = up, z = forward.
func _body_frame(skel: Skeleton3D) -> Basis:
	var hips := skel.get_bone_global_rest(skel.find_bone("mixamorig_Hips")).origin
	var head := skel.get_bone_global_rest(skel.find_bone("mixamorig_Head")).origin
	var left := skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftUpLeg")).origin
	var right := skel.get_bone_global_rest(skel.find_bone("mixamorig_RightUpLeg")).origin
	var up := (head - hips).normalized()
	var side := (left - right)
	side = (side - up * side.dot(up)).normalized()
	var forward := side.cross(up).normalized()
	return Basis(side, up, forward).orthonormalized()


func _retarget(path: String, loop: bool) -> Animation:
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
	_to_target = (_body_frame(_skel) * _body_frame(src_skel).inverse()).get_rotation_quaternion()
	var src_up := _body_frame(src_skel).y
	var tgt_up := _body_frame(_skel).y

	var out := Animation.new()
	out.length = src_anim.length
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for name in DELTA_BONES:
		tracks[name] = _rot_track(out, name)
	for aim in AIM_BONES:
		tracks[aim[0]] = _rot_track(out, aim[0])
	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath(_skel_path + "mixamorig_Hips"))

	var src_hips := src_skel.find_bone("mixamorig_Hips")
	var tgt_hips := _skel.find_bone("mixamorig_Hips")
	var src_hips_rest_h := src_skel.get_bone_global_rest(src_hips).origin.dot(src_up)
	var tgt_hips_rest := _skel.get_bone_rest(tgt_hips).origin
	var tgt_hips_rest_h := tgt_hips_rest.dot(tgt_up)
	var frames := int(round(out.length * FPS))
	for f in frames + 1:
		var t := minf(f / FPS, out.length)
		var g := _source_globals(src_skel, src_anim, rot_tracks, pos_tracks, t)
		var pose := {}
		for name in DELTA_BONES:
			var si := src_skel.find_bone("mixamorig_" + name)
			var ti := _skel.find_bone("mixamorig_" + name)
			var src_now := (g[si] as Transform3D).basis.get_rotation_quaternion()
			var src_rest := src_skel.get_bone_global_rest(si).basis.get_rotation_quaternion()
			var tgt_rest := _skel.get_bone_global_rest(ti).basis.get_rotation_quaternion()
			var change := _to_target * (src_now * src_rest.inverse()) * _to_target.inverse()
			var world_now := change * tgt_rest
			var parent_q := _global_basis(pose, _skel.get_bone_parent(ti)).get_rotation_quaternion()
			pose[name] = (parent_q.inverse() * world_now).normalized()
		for aim in AIM_BONES:
			var sb := src_skel.find_bone("mixamorig_" + aim[0])
			var sc := src_skel.find_bone("mixamorig_" + aim[1])
			var dir: Vector3 = (g[sc] as Transform3D).origin - (g[sb] as Transform3D).origin
			_aim_into(pose, aim[0], aim[1], _to_target * dir)
		for name in tracks:
			out.rotation_track_insert_key(tracks[name], t, pose[name])
		# Hip height follows the source (crouching, sitting, kneeling), scaled to our body.
		var src_h := (g[src_hips] as Transform3D).origin.dot(src_up)
		var new_h := tgt_hips_rest_h * src_h / src_hips_rest_h
		out.position_track_insert_key(hips_track, t, tgt_hips_rest + tgt_up * (new_h - tgt_hips_rest_h))
	src_root.free()
	return out


func _rot_track(anim: Animation, bone_name: String) -> int:
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(track, NodePath(_skel_path + "mixamorig_" + bone_name))
	return track


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


func _aim_into(pose: Dictionary, bone: String, child: String, direction: Vector3) -> void:
	if direction.length_squared() < 1e-8:
		return
	var bone_idx := _skel.find_bone("mixamorig_" + bone)
	var child_idx := _skel.find_bone("mixamorig_" + child)
	if bone_idx < 0 or child_idx < 0:
		return
	var base: Quaternion = pose.get(bone, _skel.get_bone_rest(bone_idx).basis.get_rotation_quaternion())
	var parent_basis := _global_basis(pose, _skel.get_bone_parent(bone_idx))
	var current: Vector3 = (base * _skel.get_bone_rest(child_idx).origin.normalized()).normalized()
	var wanted: Vector3 = (parent_basis.inverse() * direction.normalized()).normalized()
	pose[bone] = (Quaternion(current, wanted) * base).normalized()


func _global_basis(pose: Dictionary, bone_idx: int) -> Basis:
	if bone_idx < 0:
		return Basis()
	var name := _skel.get_bone_name(bone_idx).trim_prefix("mixamorig_")
	var local: Basis = Basis(pose[name]) if pose.has(name) else _skel.get_bone_rest(bone_idx).basis
	return _global_basis(pose, _skel.get_bone_parent(bone_idx)) * local
