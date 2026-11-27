class_name CameraRig
extends Node3D
## Over-the-shoulder third-person camera.
##
## Structure:  CameraRig (yaw) -> PitchPivot (pitch) -> SpringArm3D -> Camera3D
## The SpringArm3D pulls the camera in when walls or terrain are behind the
## player, so the camera never clips through them.

@export var height_offset: float = 1.55
@export var follow_sharpness: float = 14.0
@export var mouse_sensitivity: float = 0.0024
@export var gamepad_sensitivity: float = 2.6
@export var min_pitch_degrees: float = -65.0
@export var max_pitch_degrees: float = 38.0
@export var default_distance: float = 3.8
@export var min_distance: float = 2.0
@export var max_distance: float = 7.0
@export var zoom_step: float = 0.45
@export var sprint_fov_boost: float = 6.0

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-14.0)
var _target_distance: float
var _base_fov: float
var _target: Node3D
## Mouse motion is ignored briefly after capturing, so the cursor warp
## doesn't spin the camera.
var _ignore_mouse_until_msec: int = 0
## A second camera for set shots (the shop view, ShopFocus): it glides from the
## follow camera to the shot and back, then hands over again.
var _focus_cam: Camera3D
var _focus_tween: Tween
var _focused := false
## Driving: the camera sits further back and higher, and swings round behind the vehicle
## when you leave the mouse alone for a moment.
var _vehicle: Node3D = null
var _last_look_msec: int = 0
var _walk_distance: float = 0.0
const VEHICLE_DISTANCE := 7.5
const VEHICLE_HEIGHT := 2.4
## Seconds without mouse/stick look before the camera eases round behind the vehicle.
const VEHICLE_FOLLOW_DELAY := 1.2

@onready var _pitch_pivot: Node3D = $PitchPivot
@onready var _spring_arm: SpringArm3D = $PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	# Moved every rendered frame, so it must not be physics-interpolated itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_target = get_parent() as Node3D
	var body := _target as CollisionObject3D
	if body:
		_spring_arm.add_excluded_object(body.get_rid())
	_target_distance = default_distance
	_spring_arm.spring_length = default_distance
	_base_fov = _camera.fov
	_capture_mouse(true)
	snap_to_target()


func get_yaw() -> float:
	return _yaw


func set_yaw(value: float) -> void:
	_yaw = value
	rotation = Vector3(0.0, _yaw, 0.0)


func get_camera() -> Camera3D:
	return _camera


## Switches to (vehicle) or from (null) the driving view.
func set_vehicle_view(vehicle: Node3D) -> void:
	# The spring arm mustn't bump into the vehicle itself.
	if _vehicle is CollisionObject3D:
		_spring_arm.remove_excluded_object((_vehicle as CollisionObject3D).get_rid())
	if vehicle is CollisionObject3D:
		_spring_arm.add_excluded_object((vehicle as CollisionObject3D).get_rid())
	if vehicle and _vehicle == null:
		_walk_distance = _target_distance
		_target_distance = VEHICLE_DISTANCE
	elif vehicle == null and _vehicle:
		_target_distance = _walk_distance if _walk_distance > 0.0 else default_distance
	_vehicle = vehicle
	_last_look_msec = Time.get_ticks_msec()


func is_vehicle_view() -> bool:
	return _vehicle != null


## The camera on screen now (the shot camera while focused).
func get_active_camera() -> Camera3D:
	return _focus_cam if _focus_cam and _focus_cam.current else _camera


func is_focused() -> bool:
	return _focused


## Glides the view to a set shot (world transform). `h_offset` slides the picture
## sideways (positive = what you look at sits left of centre).
func focus_on(shot: Transform3D, h_offset: float = 0.0, seconds: float = 0.9) -> void:
	if _focus_cam == null:
		_focus_cam = Camera3D.new()
		_focus_cam.name = "FocusCamera"
		_focus_cam.top_level = true
		_focus_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_focus_cam)
	if not _focused:
		_focus_cam.global_transform = _camera.global_transform
		_focus_cam.fov = _camera.fov
		_focus_cam.h_offset = 0.0
	_focused = true
	_set_player_shown(false)
	_focus_cam.make_current()
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(_focus_cam, ^"global_transform", shot, seconds)
	_focus_tween.tween_property(_focus_cam, ^"h_offset", h_offset, seconds)
	_focus_tween.tween_property(_focus_cam, ^"fov", _base_fov, seconds)


## Glides back behind the player and hands the view back to the follow camera.
func release_focus(seconds: float = 0.7) -> void:
	if not _focused or _focus_cam == null:
		return
	_focused = false
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(_focus_cam, ^"global_transform", _camera.global_transform, seconds)
	_focus_tween.tween_property(_focus_cam, ^"h_offset", 0.0, seconds)
	_focus_tween.chain().tween_callback(func() -> void:
		if not _focused:
			_camera.make_current()
			_set_player_shown(true))


## The player steps out of the picture during a set shot (they'd stand in front of the
## shop), and the HUD (map, quest list) gets out of the way; both are back when the view
## returns.
func _set_player_shown(shown: bool) -> void:
	var visual := _target.get_node_or_null(^"Visual") as Node3D if _target else null
	if visual:
		visual.visible = shown
	var hud := get_tree().get_first_node_in_group(&"hud") as CanvasLayer
	if hud:
		hud.visible = shown


func snap_to_target() -> void:
	if _target:
		global_position = _target.global_position + Vector3.UP * height_offset
	rotation = Vector3(0.0, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		if Time.get_ticks_msec() < _ignore_mouse_until_msec:
			return
		var motion := event as InputEventMouseMotion
		_last_look_msec = Time.get_ticks_msec()
		var sensitivity := mouse_sensitivity * GameSettings.mouse_sensitivity
		_yaw -= motion.relative.x * sensitivity
		_pitch -= motion.relative.y * sensitivity
		_clamp_pitch()
	elif event.is_action_pressed(&"toggle_mouse"):
		_capture_mouse(not captured)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		var button := event as InputEventMouseButton
		if not captured and button.button_index == MOUSE_BUTTON_LEFT:
			_capture_mouse(true)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance - zoom_step, min_distance, max_distance)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance + zoom_step, min_distance, max_distance)


func _process(delta: float) -> void:
	if not _target:
		return
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.0:
		_last_look_msec = Time.get_ticks_msec()
		_yaw -= look.x * gamepad_sensitivity * delta
		_pitch -= look.y * gamepad_sensitivity * 0.7 * delta
		_clamp_pitch()

	if _vehicle and is_instance_valid(_vehicle) and Time.get_ticks_msec() - _last_look_msec > VEHICLE_FOLLOW_DELAY * 1000.0:
		# Ease round behind the vehicle (its forward is -Z, like the camera's).
		var moving := _vehicle.has_method(&"get_speed") and absf(float(_vehicle.call(&"get_speed"))) > 0.5
		if moving:
			_yaw = lerp_angle(_yaw, _vehicle.global_rotation.y, 1.0 - exp(-1.8 * delta))
	var lift := VEHICLE_HEIGHT if _vehicle else height_offset
	var target_position := _target.get_global_transform_interpolated().origin + Vector3.UP * lift
	global_position = global_position.lerp(target_position, 1.0 - exp(-follow_sharpness * delta))
	rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_pivot.rotation = Vector3(_pitch, 0.0, 0.0)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _target_distance, 1.0 - exp(-10.0 * delta))

	var sprinting: bool = _target.has_method(&"is_sprinting") and _target.call(&"is_sprinting")
	var wanted_fov := _base_fov + (sprint_fov_boost if sprinting else 0.0)
	_camera.fov = lerpf(_camera.fov, wanted_fov, 1.0 - exp(-4.0 * delta))


func _clamp_pitch() -> void:
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))


func _capture_mouse(capture: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if capture:
		_ignore_mouse_until_msec = Time.get_ticks_msec() + 200
