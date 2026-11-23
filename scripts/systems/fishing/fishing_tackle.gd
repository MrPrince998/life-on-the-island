class_name FishingTackle
extends Node3D
## Visuals for fishing: rod in the right hand, line, bobber and water ripples.
## The left hand rests on the rod butt, or turns the reel crank while reeling
## (see left_hand), using two-bone IK in a second HandGrip.
##
## Uses Tripo models when they exist:
##   source_assets/tripo/fishing rod.glb      (upright, handle at the bottom, reel on the +Z side)
##   source_assets/tripo/fishing_bobber.glb
## Otherwise it builds a simple stand-in rod and bobber.
## The rod is aimed in world space from the hand, so it works with any hand bone setup.
## While fishing the rod bends with line tension and the reel crank spins.

const ROD_MODEL_PATHS := ["res://source_assets/tripo/fishing rod.glb", "res://source_assets/tripo/fishing_rod.glb"]
const ROD_SHADER := preload("res://shaders/fishing_rod.gdshader")
## Measurements of the Tripo rod, in its own model units (see tests notes in the handoff):
const ROD_MODEL_HEIGHT := 0.976
## Thickness of the model's cork handle (model units).
const ROD_MODEL_HANDLE_WIDTH := 0.075
## Where the right hand holds it: the top of the cork handle just below the reel, on the rod's axis.
const ROD_MODEL_GRIP := Vector3(0.004, 0.13, -0.036)
## Where the left hand holds the butt end of the handle.
const ROD_MODEL_BUTT_GRIP := Vector3(0.004, 0.045, -0.036)
## Model sections (see shaders/fishing_rod.gdshader): handle below this height...
const ROD_MODEL_HANDLE_END := 0.17
## ...reel and reel seat up to this height, thin rod above it.
const ROD_MODEL_REEL_END := 0.36
## The handle is lengthened a little so two hands fit on it.
const HANDLE_STRETCH := 1.6
## Centre of the reel face, where the spinning crank is mounted.
const ROD_MODEL_REEL_FACE := Vector3(-0.005, 0.3025, 0.064)
## How far the tip curves at full bend (metres).
const BEND_METRES := 0.32
const BOBBER_MODEL_PATH := "res://source_assets/tripo/fishing_bobber.glb"
## The Tripo rod is short and chunky: it is scaled so the handle fits the character's
## fist, and the thin rod above the reel is stretched so the whole rod is this long.
const ROD_LENGTH := 1.75
const ROD_HANDLE_THICKNESS := 0.06
const GRIP_BEHIND_HAND := 0.25
const LINE_SEGMENTS := 16
## Crank knob position on the crank (crank's own space).
const CRANK_KNOB_POSITION := Vector3(0, 0.026, 0.014)
## Where the line leaves the reel spool, and the eyes of the three line guides, in the
## rod model's own units (measured from the mesh). The line runs reel -> guides -> tip.
const ROD_MODEL_SPOOL := Vector3(-0.005, 0.315, 0.035)
const ROD_MODEL_GUIDES := [Vector3(0.002, 0.535, -0.008), Vector3(0.002, 0.742, -0.008), Vector3(0.005, 0.94, -0.01)]
const ROD_MODEL_TIP := Vector3(0.003, 0.976, -0.043)
## Bend shape used by shaders/fishing_rod.gdshader (keep in sync).
const SHADER_BEND_START := 0.3
## How far the hook hangs below the bobber: in the water, and while dangling from the rod.
const HOOK_DEPTH_IN_WATER := 0.6
const HOOK_DROP_DANGLING := 0.22

## Angle of the rod above horizontal, in degrees (over 90 tips it back over the shoulder).
var rod_pitch: float = 65.0
## 0 = slack line (sags), 1 = tight line.
var line_tension: float = 0.0

var _player: Node3D
var _facing: Node3D
var _skeleton: Skeleton3D
## Reports which way the rod points in the clip playing now (CharacterAnimator).
var _animator: Node
var _hand_bone: int = -1
var _grip: HandGrip
var _rod: Node3D
var _tip: Marker3D
var _bobber: Node3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _line_material := StandardMaterial3D.new()
var _bobber_out: bool = false
var _bobber_flying: bool = false
var _bobber_rest: Vector3
var _dip: float = 0.0
var _time: float = 0.0
var _equipped: bool = false
var _catch_display: Node3D
var _rod_material: ShaderMaterial
var _hook: Node3D
## Current rod bend (0..1), kept so the line can follow the bent rod through its guides.
var _current_bend: float = 0.0
## Points the line passed through last frame: reel, guides, tip, bobber, hook (world).
var _line_points := PackedVector3Array()
var _crank: Node3D
var _crank_mount: Node3D
## Rod model scale (model units -> metres) and how much the thin rod is stretched.
var _rod_scale: float = 1.0
var _blank_stretch: float = 1.0
var _model_xf := Transform3D()

enum LeftHand { FREE, HANDLE, CRANK }
## What the left hand does while the rod is out. Set by the fishing controller.
var left_hand: LeftHand = LeftHand.FREE
## Above this speed (m/s) the left hand lets go and swings with the walk/run.
const LEFT_HAND_RELEASE_SPEED := 0.4
const LEFT_HAND_BLEND_SPEED := 5.0
var _left_grip: HandGrip
## While reeling, the right fist is drawn in toward the belly (0 = where the animation
## holds it, 1 = tucked in) so the left hand can reach the crank.
var _right_tuck: float = 0.0
## Where the right fist goes when tucked in, relative to the player's feet
## (x = right, y = up, z = forward), in metres.
const RIGHT_TUCK_OFFSET := Vector3(0.0, 0.92, 0.23)
## ...and the chest turns a little to the right, bringing the left shoulder forward.
const REEL_TORSO_TWIST := 25.0
## Distance from the left fist to its target in the last finished pose (-1 = not holding).
var _left_reach_error: float = -1.0
## When true (two-handed Mixamo clips), the rod lies along the line from the animated
## left hand to the animated right hand instead of using rod_pitch, so it moves exactly
## as the animation intends (wind-up, cast, settle). Set by the fishing controller.
var follow_hands: bool = false
var _follow_weight: float = 0.0
## Left wrist -> right wrist in the animated pose this frame (world), or zero.
var _hands_aim := Vector3.ZERO
## The rod tip is kept at least this high above the player's feet.
const TIP_MIN_HEIGHT := 0.15
var _tip_base := Vector3.ZERO

## Rod bend 0..1 (0 = straight). Set by the fishing controller.
var rod_bend: float = 0.0
## Reel crank speed in turns per second (+ = winding in, - = line running out).
var reel_speed: float = 0.0
var _reel_boost_time: float = 0.0
var _reel_boost_speed: float = 0.0
var _reel_angle: float = 0.0


func setup(player: Node3D, facing: Node3D, character: Node) -> void:
	_player = player
	_facing = facing
	_animator = character
	_skeleton = character.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_hand_bone = _skeleton.find_bone("mixamorig_RightHand")
		_grip = HandGrip.new()
		_grip.name = "HandGrip"
		_skeleton.add_child(_grip)
		_grip.rod_radius = ROD_HANDLE_THICKNESS * 0.5 / _skeleton.global_basis.get_scale().x
		_grip.reach_provider = _right_hand_target
		# Added after the right hand, so it runs after it and can reach for the rod
		# where the right hand has just put it.
		_left_grip = HandGrip.new()
		_left_grip.name = "LeftHandGrip"
		_left_grip.side = "Left"
		_left_grip.influence = 0.0
		_left_grip.reach_provider = _left_hand_target
		_skeleton.add_child(_left_grip)
		# Place the rod after the hand's final pose is known (animation + fist), so the
		# rod never lags a frame behind the hand while walking or running.
		_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_build()
	set_equipped(false)


func _build() -> void:
	_rod = Node3D.new()
	_rod.name = "Rod"
	_rod.top_level = true
	add_child(_rod)
	_tip = Marker3D.new()
	_tip.name = "Tip"
	var model_path := ""
	for path in ROD_MODEL_PATHS:
		if ResourceLoader.exists(path):
			model_path = path
			break
	if model_path != "":
		_build_model_rod(load(model_path) as PackedScene)
	else:
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		pivot.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)  # +Y -> rod -Z (forward)
		pivot.position = Vector3(0, 0, GRIP_BEHIND_HAND)
		_rod.add_child(pivot)
		_build_placeholder_rod(pivot)
		_tip_base = Vector3(0, 0, GRIP_BEHIND_HAND - ROD_LENGTH)
	_tip.position = _tip_base
	_rod.add_child(_tip)

	_bobber = Node3D.new()
	_bobber.name = "Bobber"
	_bobber.top_level = true
	add_child(_bobber)
	if ResourceLoader.exists(BOBBER_MODEL_PATH):
		var bobber_model := (load(BOBBER_MODEL_PATH) as PackedScene).instantiate() as Node3D
		bobber_model.scale = Vector3.ONE * 0.16
		bobber_model.position = Vector3(0, -0.06, 0)
		_bobber.add_child(bobber_model)
	else:
		_build_placeholder_bobber(_bobber)

	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(0.95, 0.95, 0.9, 0.85)
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.top_level = true
	_line.mesh = _line_mesh
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_hook = _build_hook()
	add_child(_hook)


## Rod node space: -Z = toward the tip, +Y = up, origin = the hand.
## Model space: +Y = butt to tip, +Z = reel side. The reel should hang underneath,
## so model +Y -> rod -Z, model +Z -> rod -Y, model +X -> rod -X.
func _build_model_rod(scene: PackedScene) -> void:
	_rod_scale = ROD_HANDLE_THICKNESS / ROD_MODEL_HANDLE_WIDTH
	var fixed := ROD_MODEL_HANDLE_END * HANDLE_STRETCH + (ROD_MODEL_REEL_END - ROD_MODEL_HANDLE_END)
	_blank_stretch = (ROD_LENGTH / _rod_scale - fixed) / (ROD_MODEL_HEIGHT - ROD_MODEL_REEL_END)
	var turn := Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0))
	var basis := turn.scaled_local(Vector3.ONE * _rod_scale)
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.transform = Transform3D(basis, -(basis * remap_model_point(ROD_MODEL_GRIP)))
	_model_xf = model.transform
	_rod.add_child(model)
	var mesh_instance := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	# The shader lengthens the rod, so widen the culling box to match.
	var length := remap_model_y(ROD_MODEL_HEIGHT)
	mesh_instance.custom_aabb = AABB(Vector3(-0.15, -0.05, -0.4), Vector3(0.3, length + 0.1, 0.8))
	var source := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
	_rod_material = ShaderMaterial.new()
	_rod_material.shader = ROD_SHADER
	_rod_material.set_shader_parameter(&"rod_height", ROD_MODEL_HEIGHT)
	_rod_material.set_shader_parameter(&"bend_start", SHADER_BEND_START)
	_rod_material.set_shader_parameter(&"bend_amount", BEND_METRES / _rod_scale)
	_rod_material.set_shader_parameter(&"handle_end", ROD_MODEL_HANDLE_END)
	_rod_material.set_shader_parameter(&"reel_end", ROD_MODEL_REEL_END)
	_rod_material.set_shader_parameter(&"handle_stretch", HANDLE_STRETCH)
	_rod_material.set_shader_parameter(&"blank_stretch", _blank_stretch)
	if source:
		_rod_material.set_shader_parameter(&"albedo_tex", source.albedo_texture)
		_rod_material.set_shader_parameter(&"normal_tex", source.normal_texture)
		_rod_material.set_shader_parameter(&"use_normal_map", source.normal_enabled and source.normal_texture != null)
	mesh_instance.material_override = _rod_material
	_tip_base = model.transform * remap_model_point(Vector3(0.003, ROD_MODEL_HEIGHT, -0.043))
	# The crank sits on its own mount on the rod node so it spins cleanly.
	_crank_mount = Node3D.new()
	_crank_mount.name = "ReelMount"
	_crank_mount.transform = Transform3D(basis, model.transform * remap_model_point(ROD_MODEL_REEL_FACE))
	_rod.add_child(_crank_mount)
	_crank = _build_crank()
	_crank_mount.add_child(_crank)


## Height along the rod model after the shader's lengthening (model units, before scale).
## Must match remap_y() in shaders/fishing_rod.gdshader.
func remap_model_y(y: float) -> float:
	var handle := minf(y, ROD_MODEL_HANDLE_END) * HANDLE_STRETCH
	var reel := clampf(y - ROD_MODEL_HANDLE_END, 0.0, ROD_MODEL_REEL_END - ROD_MODEL_HANDLE_END)
	var blank := maxf(y - ROD_MODEL_REEL_END, 0.0) * _blank_stretch
	return handle + reel + blank


func remap_model_point(p: Vector3) -> Vector3:
	return Vector3(p.x, remap_model_y(p.y), p.z)


## A small crank handle on the reel face that turns while reeling.
func _build_crank() -> Node3D:
	var crank := Node3D.new()
	crank.name = "ReelCrank"
	var brass := _material(Color(0.86, 0.62, 0.3))
	brass.metallic = 0.5
	var wood := _material(Color(0.42, 0.24, 0.14))
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.009, 0.03, 0.004)
	arm_mesh.material = brass
	arm.mesh = arm_mesh
	arm.position = Vector3(0, 0.013, 0.003)
	crank.add_child(arm)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.007
	hub_mesh.bottom_radius = 0.007
	hub_mesh.height = 0.006
	hub_mesh.material = brass
	hub.mesh = hub_mesh
	hub.rotation = Vector3(PI * 0.5, 0, 0)
	hub.position = Vector3(0, 0, 0.003)
	crank.add_child(hub)
	var knob := MeshInstance3D.new()
	var knob_mesh := CylinderMesh.new()
	knob_mesh.top_radius = 0.0065
	knob_mesh.bottom_radius = 0.0055
	knob_mesh.height = 0.02
	knob_mesh.material = wood
	knob.mesh = knob_mesh
	knob.rotation = Vector3(PI * 0.5, 0, 0)
	knob.position = CRANK_KNOB_POSITION
	crank.add_child(knob)
	return crank


## Spin the reel at `speed` turns/second for `seconds` (e.g. winding the line back in).
func spin_reel_for(speed: float, seconds: float) -> void:
	_reel_boost_speed = speed
	_reel_boost_time = seconds


func _build_placeholder_rod(pivot: Node3D) -> void:
	var cork := _material(Color(0.78, 0.6, 0.4))
	var blank := _material(Color(0.36, 0.24, 0.16))
	var metal := _material(Color(0.65, 0.66, 0.68))
	metal.metallic = 0.6
	# Pivot space: +Y runs from the butt (0) to the tip (ROD_LENGTH).
	_add_cylinder(pivot, 0.024, 0.028, 0.45, 0.225, cork)
	_add_cylinder(pivot, 0.006, 0.016, ROD_LENGTH - 0.45, 0.45 + (ROD_LENGTH - 0.45) * 0.5, blank)
	var reel := _add_cylinder(pivot, 0.045, 0.045, 0.05, 0.0, metal)
	reel.position = Vector3(0, 0.32, 0.06)
	reel.rotation = Vector3(0, 0, deg_to_rad(90.0))


func _build_placeholder_bobber(parent: Node3D) -> void:
	var top := MeshInstance3D.new()
	var top_mesh := SphereMesh.new()
	top_mesh.radius = 0.055
	top_mesh.height = 0.055
	top_mesh.is_hemisphere = true
	top_mesh.material = _material(Color(0.9, 0.2, 0.18))
	top.mesh = top_mesh
	parent.add_child(top)
	var bottom := MeshInstance3D.new()
	var bottom_mesh := SphereMesh.new()
	bottom_mesh.radius = 0.055
	bottom_mesh.height = 0.055
	bottom_mesh.is_hemisphere = true
	bottom_mesh.material = _material(Color(0.97, 0.96, 0.92))
	bottom.mesh = bottom_mesh
	bottom.rotation = Vector3(PI, 0, 0)
	parent.add_child(bottom)


func _add_cylinder(parent: Node3D, top_r: float, bottom_r: float, height: float, center_y: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = mat
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(0, center_y, 0)
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


func set_equipped(on: bool) -> void:
	_equipped = on
	if _grip:
		_grip.holding = on
		if not on:
			_grip.grip_direction = Vector3.ZERO
	if _left_grip and not on:
		left_hand = LeftHand.FREE
		_left_grip.holding = false
		_left_grip.influence = 0.0
		_right_tuck = 0.0
		_follow_weight = 0.0
	_rod.visible = on
	_line.visible = on
	_bobber.visible = on
	if _hook:
		_hook.visible = on
	if not on:
		_bobber_out = false


func get_tip_position() -> Vector3:
	return _tip.global_position


func get_hand_position() -> Vector3:
	if _skeleton and _hand_bone >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone).origin
	return _player.global_position + Vector3(0, 1.1, 0)


## Centre of the handle inside the closed fist (worked out by HandGrip from the hand bones).
func get_grip_position() -> Vector3:
	if _skeleton == null or _hand_bone < 0 or _grip == null:
		return get_hand_position()
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone)
	return hand * _grip.get_grip_point_local()


## Throws the bobber in an arc to `target`. Calls on_landed when it arrives.
func launch_bobber(target: Vector3, duration: float, on_landed: Callable) -> void:
	_bobber_out = true
	_bobber_flying = true
	var start := get_tip_position()
	var arc := 1.2 + start.distance_to(target) * 0.15
	spin_reel_for(-7.0, duration)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_bobber.global_position = start.lerp(target, t) + Vector3.UP * sin(t * PI) * arc, 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		_bobber_flying = false
		_bobber_rest = target
		ripple(target)
		on_landed.call())


func set_bobber_rest(point: Vector3) -> void:
	_bobber_rest = point


func reel_in_bobber() -> void:
	if _bobber_out:
		spin_reel_for(5.0, 0.6)
	_bobber_out = false
	_bobber_flying = false
	_dip = 0.0


func set_bite(active: bool) -> void:
	_dip = 1.0 if active else 0.0
	if active:
		ripple(_bobber_rest)


func ripple(point: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.75)
	torus.material = mat
	ring.mesh = torus
	ring.top_level = true
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = point + Vector3(0, 0.03, 0)
	ring.scale = Vector3(0.15, 0.02, 0.15)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(1.1, 0.02, 1.1), 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.1)
	tween.chain().tween_callback(ring.queue_free)


## Shows the caught fish held up in front of the player for a moment.
func show_catch(fish: FishData, size_cm: float) -> void:
	var fish_model := fish.get_model()
	if fish_model == null:
		return
	if is_instance_valid(_catch_display):
		_catch_display.queue_free()
	var holder := Node3D.new()
	holder.top_level = true
	add_child(holder)
	var model := fish_model.instantiate() as Node3D
	holder.add_child(model)
	# Tripo models are about 1 unit across, so scale = real size in metres (a bit
	# larger for small fish so they read on screen).
	var length := clampf(size_cm / 100.0 * 1.3, 0.3, 1.7)
	model.scale = Vector3.ONE * length
	model.rotation = Vector3(0, deg_to_rad(fish.model_yaw_degrees), 0)
	# Centre the model on the holder.
	var bounds := _model_bounds(model)
	model.position = -bounds.get_center()
	var forward := -_facing.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	# Held up above the shoulder, head pointing to the player's right, so the camera
	# behind the player sees the fish side-on.
	holder.global_position = _player.global_position + Vector3.UP * (1.85 + length * 0.3) + right * 0.25 + forward * 0.3
	holder.global_rotation = Vector3(0, _facing.global_rotation.y, 0)
	_catch_display = holder
	holder.scale = Vector3.ONE * 0.01
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "rotation:z", 0.12, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(holder, "rotation:z", -0.12, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(holder, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(holder.queue_free)


func get_catch_display() -> Node3D:
	return _catch_display if is_instance_valid(_catch_display) else null


static func _model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var xf := Transform3D()
		var cur: Node = mesh_instance
		while cur != null and cur != model.get_parent():
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var box := xf * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _process(delta: float) -> void:
	_time += delta
	if not _equipped or _player == null:
		return
	_place_rod()
	_update_rod_motion(delta)
	_update_left_hand(delta)
	var tip := get_tip_position()
	if _bobber_out:
		if not _bobber_flying:
			var bob := sin(_time * 2.2) * 0.02
			var dip := _dip * (-0.1 + sin(_time * 18.0) * 0.03)
			_bobber.global_position = _bobber_rest + Vector3(0, bob + dip, 0)
	else:
		_bobber.global_position = tip + Vector3(0, -0.55, 0)
	_update_line()


## Line: reel spool -> each guide -> rod tip (taut along the rod), then a sagging span
## down to the bobber, then straight down to the hook.
func _update_line() -> void:
	if not _equipped or _rod == null:
		return
	var points := PackedVector3Array()
	if _rod_material:
		var rod_xf := _rod.global_transform * _model_xf
		points.append(rod_xf * _bent_model_point(ROD_MODEL_SPOOL))
		for guide in ROD_MODEL_GUIDES:
			points.append(rod_xf * _bent_model_point(guide))
	points.append(get_tip_position())
	var bobber_top := _bobber.global_position + Vector3(0, 0.05, 0)
	var hook_drop := HOOK_DEPTH_IN_WATER if (_bobber_out and not _bobber_flying) else HOOK_DROP_DANGLING
	var hook_eye := _bobber.global_position + Vector3(0, -hook_drop, 0)
	if _hook:
		_hook.global_position = hook_eye
		_hook.global_rotation = Vector3(0, _facing.global_rotation.y if _facing else 0.0, 0)
	_line_points = points.duplicate()
	_line_points.append(bobber_top)
	_line_points.append(hook_eye)
	_draw_line(points, bobber_top, hook_eye)


## A point on the rod model after the shader's lengthening and bend (model units).
func _bent_model_point(p: Vector3) -> Vector3:
	var h := clampf((p.y / ROD_MODEL_HEIGHT - SHADER_BEND_START) / (1.0 - SHADER_BEND_START), 0.0, 1.0)
	var curve := _current_bend * (BEND_METRES / _rod_scale) * h * h
	return Vector3(p.x, remap_model_y(p.y) - curve * 0.35 * h, p.z + curve)


## The points the line runs through (world): reel, guides, tip, bobber, hook.
func get_line_points() -> PackedVector3Array:
	return _line_points


func get_hook() -> Node3D:
	return _hook


## Rod: through the fist, aimed forward and tilted up by rod_pitch.
func _place_rod() -> void:
	if not _equipped or _player == null:
		return
	var aim := _rod_aim()
	if _grip:
		_grip.grip_direction = aim
		# Palm faces in toward the body, a little upward; the back of the hand faces out.
		_grip.grip_palm_facing = -_player_right() + Vector3.UP * 0.3
	_rod.global_transform = _rod_transform(aim)


func _player_forward() -> Vector3:
	var forward := -_facing.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD


func _player_right() -> Vector3:
	return _player_forward().cross(Vector3.UP).normalized()


func _rod_aim() -> Vector3:
	var pitch := deg_to_rad(rod_pitch)
	# Slightly out to the right so the rod clears the body.
	var aim := (_player_forward() * cos(pitch) + Vector3.UP * sin(pitch) + _player_right() * 0.15).normalized()
	if _follow_weight > 0.001 and _hands_aim != Vector3.ZERO:
		aim = aim.slerp(_hands_aim, _follow_weight).normalized()
		aim = _keep_tip_above_ground(aim)
	return aim


## Raises the rod just enough that its tip stays above the ground (the Mixamo wind-up
## swings the tip low behind the body, made for a shorter rod).
func _keep_tip_above_ground(aim: Vector3) -> Vector3:
	var reach := (remap_model_y(ROD_MODEL_HEIGHT) - remap_model_y(ROD_MODEL_GRIP.y)) * _rod_scale
	var lowest := _player.global_position.y + TIP_MIN_HEIGHT
	var grip_y := get_grip_position().y
	if reach <= 0.0 or grip_y + aim.y * reach >= lowest:
		return aim
	var y := clampf((lowest - grip_y) / reach, -1.0, 1.0)
	var flat := Vector3(aim.x, 0.0, aim.z)
	flat = flat.normalized() if flat.length() > 0.001 else -_player_forward()
	return (flat * sqrt(1.0 - y * y) + Vector3.UP * y).normalized()


## Left wrist -> right wrist direction of the animation this frame (world), for tests.
func get_hands_aim() -> Vector3:
	return _hands_aim


## Which way the rod should point this frame (world). Called before any hand
## modification, so it reflects the pure animation. Falls back to the animated
## left wrist -> right wrist line for clips without a recorded rod direction.
func _update_hands_aim() -> void:
	_hands_aim = Vector3.ZERO
	if _skeleton == null:
		return
	# Preferred: the rod direction recorded in the clip from the original Mixamo rig, where
	# the hands line up along the rod. (On our chunkier character the retargeted hands end
	# up side by side, so the wrist-to-wrist line would point the rod out sideways.)
	if _animator and _animator.has_method(&"get_rod_direction"):
		var clip_dir: Vector3 = _animator.call(&"get_rod_direction")
		if clip_dir != Vector3.ZERO:
			_hands_aim = (_skeleton.global_basis * clip_dir).normalized()
			return
	var left := _skeleton.find_bone("mixamorig_LeftHand")
	if left < 0 or _hand_bone < 0:
		return
	var l := _skeleton.global_transform * _skeleton.get_bone_global_pose(left).origin
	var r := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone).origin
	if l.distance_to(r) > 0.02:
		_hands_aim = (r - l).normalized()


func _rod_transform(aim: Vector3) -> Transform3D:
	var up_hint := Vector3.UP if absf(aim.dot(Vector3.UP)) < 0.95 else _player_forward()
	return Transform3D(Basis.looking_at(aim, up_hint), get_grip_position())


## The final pose (animation + both hands) is ready: place the rod in the right fist and
## note how close the left fist got to its target.
func _on_skeleton_updated() -> void:
	_place_rod()
	# Redraw the line now that the rod sits in the hands' final pose this frame.
	_update_line()
	_left_reach_error = -1.0
	if _equipped and _left_grip and _left_grip.influence > 0.99:
		var target := get_left_hand_target()
		if target != Vector3.ZERO:
			_left_reach_error = _left_grip.get_grip_point_world().distance_to(target)


## Distance (m) between the left fist and where it is reaching, measured on the last
## finished pose; -1 when the left hand is not holding anything.
func get_left_hand_reach_error() -> float:
	return _left_reach_error


## Right hand: follows the animation, except while reeling, when it is drawn in.
func _right_hand_target() -> Dictionary:
	if not _equipped or _player == null:
		return {}
	_update_hands_aim()
	var right := _player_right()
	var forward := _player_forward()
	if _right_tuck <= 0.001:
		# Follow the animation; just turn the wrist along this frame's rod direction.
		return {"direction": _rod_aim(), "palm": -right + Vector3.UP * 0.3}
	var tucked := _player.global_position + right * RIGHT_TUCK_OFFSET.x + Vector3.UP * RIGHT_TUCK_OFFSET.y + forward * RIGHT_TUCK_OFFSET.z
	var animated := _grip.get_grip_point_world()
	return {
		"position": animated.lerp(tucked, _right_tuck),
		"direction": _rod_aim(),
		"palm": -right + Vector3.UP * 0.3,
		"pole": Vector3.DOWN + right * 0.8 - forward * 0.3,
	}


## Fades the left hand onto the rod when standing still (it lets go while walking or
## running so the arm can swing), and keeps it on the crank while reeling.
func _update_left_hand(delta: float) -> void:
	if _left_grip == null:
		return
	var moving := _player.has_method(&"get_horizontal_speed") and float(_player.call(&"get_horizontal_speed")) > LEFT_HAND_RELEASE_SPEED
	var wanted := 0.0
	if left_hand == LeftHand.CRANK or (left_hand == LeftHand.HANDLE and not moving):
		wanted = 1.0
	_left_grip.influence = move_toward(_left_grip.influence, wanted, LEFT_HAND_BLEND_SPEED * delta)
	_left_grip.holding = _left_grip.influence > 0.001
	var follow := 1.0 if (follow_hands and not moving) else 0.0
	_follow_weight = move_toward(_follow_weight, follow, LEFT_HAND_BLEND_SPEED * delta)
	var tuck := 1.0 if left_hand == LeftHand.CRANK else 0.0
	_right_tuck = move_toward(_right_tuck, tuck, LEFT_HAND_BLEND_SPEED * delta)
	if _grip:
		_grip.torso_twist = REEL_TORSO_TWIST * _right_tuck


## Where the left hand should be this frame (called by the left HandGrip, after the right
## hand's final pose is known). World space.
func _left_hand_target() -> Dictionary:
	if not _equipped or _player == null or left_hand == LeftHand.FREE or _rod_material == null:
		return {}
	var aim := _rod_aim()
	var rod_xf := _rod_transform(aim)
	var right := _player_right()
	var forward := _player_forward()
	# Elbow points down and out to the left, a little back.
	var pole := Vector3.DOWN - right * 0.8 - forward * 0.3
	var unit := _skeleton.global_basis.get_scale().x
	if left_hand == LeftHand.CRANK and _crank:
		var knob_xf := rod_xf * _crank_mount.transform * _crank.transform
		_left_grip.rod_radius = 0.012 / unit
		return {
			"position": knob_xf * CRANK_KNOB_POSITION,
			"direction": (knob_xf.basis * Vector3.BACK).normalized(),
			"palm": right * 0.6 + forward * 0.2 + Vector3.UP * 0.4,
			"pole": pole,
		}
	_left_grip.rod_radius = ROD_HANDLE_THICKNESS * 0.5 / unit
	return {
		"position": rod_xf * (_model_xf * remap_model_point(ROD_MODEL_BUTT_GRIP)),
		"direction": aim,
		"palm": right * 0.5 + Vector3.UP * 0.8,
		"pole": pole,
	}


## Centre of the left fist (world), for tests and debugging.
func get_left_grip_position() -> Vector3:
	return _left_grip.get_grip_point_world() if _left_grip else Vector3.ZERO


func get_left_hand_influence() -> float:
	return _left_grip.influence if _left_grip else 0.0


## Where the left hand is aiming right now (world), or Vector3.ZERO when free.
func get_left_hand_target() -> Vector3:
	var target := _left_hand_target()
	return target.position if not target.is_empty() else Vector3.ZERO


func _update_rod_motion(delta: float) -> void:
	# Bend: what the controller asks for, plus a twitch while a fish is biting.
	var bend := rod_bend + _dip * (0.18 + sin(_time * 22.0) * 0.12)
	bend = clampf(bend, 0.0, 1.0)
	_current_bend = bend
	if _rod_material:
		_rod_material.set_shader_parameter(&"bend", bend)
		# Same curve as the shader (model units), converted to rod units.
		var curve := bend * BEND_METRES / _rod_scale
		_tip.position = _tip_base + Vector3(0, -curve * _rod_scale, curve * 0.35 * _rod_scale)
	# Reel crank.
	var speed := reel_speed
	if _reel_boost_time > 0.0:
		_reel_boost_time -= delta
		speed = _reel_boost_speed
	if _crank:
		_crank.rotate_object_local(Vector3.FORWARD, speed * TAU * delta)
		_reel_angle = fposmod(_reel_angle + speed * TAU * delta, TAU)


## How far the crank has turned (radians, 0..TAU). Tracked directly because the crank's
## mounting rotation makes its Euler angles unreliable for this.
func get_reel_angle() -> float:
	return _reel_angle if _crank else 0.0


func _draw_line(along_rod: PackedVector3Array, bobber_top: Vector3, hook_eye: Vector3) -> void:
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_material)
	for p in along_rod:
		_line_mesh.surface_add_vertex(p)
	var from := along_rod[along_rod.size() - 1]
	var sag := lerpf(0.12, 0.01, clampf(line_tension, 0.0, 1.0)) * from.distance_to(bobber_top)
	var mid := (from + bobber_top) * 0.5 + Vector3.DOWN * sag
	for i in range(1, LINE_SEGMENTS + 1):
		var t := float(i) / LINE_SEGMENTS
		_line_mesh.surface_add_vertex(from.lerp(mid, t).lerp(mid.lerp(bobber_top, t), t))
	_line_mesh.surface_add_vertex(hook_eye)
	_line_mesh.surface_end()


## A small steel fishing hook: shank with an eye at the top and a curved bend with a barb.
func _build_hook() -> Node3D:
	var hook := Node3D.new()
	hook.name = "Hook"
	hook.top_level = true
	var steel := _material(Color(0.75, 0.77, 0.8))
	steel.metallic = 0.85
	steel.roughness = 0.3
	var eye := MeshInstance3D.new()
	var eye_mesh := TorusMesh.new()
	eye_mesh.inner_radius = 0.004
	eye_mesh.outer_radius = 0.007
	eye_mesh.rings = 12
	eye_mesh.ring_segments = 6
	eye_mesh.material = steel
	eye.mesh = eye_mesh
	eye.rotation = Vector3(0, 0, PI * 0.5)
	eye.position = Vector3(0, -0.006, 0)
	hook.add_child(eye)
	var shank := MeshInstance3D.new()
	var shank_mesh := CylinderMesh.new()
	shank_mesh.top_radius = 0.0018
	shank_mesh.bottom_radius = 0.0018
	shank_mesh.height = 0.034
	shank_mesh.radial_segments = 6
	shank_mesh.material = steel
	shank.mesh = shank_mesh
	shank.position = Vector3(0, -0.03, 0)
	hook.add_child(shank)
	var bend := MeshInstance3D.new()
	var bend_mesh := TorusMesh.new()
	bend_mesh.inner_radius = 0.0075
	bend_mesh.outer_radius = 0.0112
	bend_mesh.rings = 16
	bend_mesh.ring_segments = 6
	bend_mesh.material = steel
	bend.mesh = bend_mesh
	bend.rotation = Vector3(0, 0, PI * 0.5)
	bend.position = Vector3(0, -0.047, 0.009)
	hook.add_child(bend)
	var point := MeshInstance3D.new()
	var point_mesh := CylinderMesh.new()
	point_mesh.top_radius = 0.0
	point_mesh.bottom_radius = 0.0022
	point_mesh.height = 0.014
	point_mesh.radial_segments = 6
	point_mesh.material = steel
	point.mesh = point_mesh
	point.position = Vector3(0, -0.038, 0.019)
	hook.add_child(point)
	return hook
