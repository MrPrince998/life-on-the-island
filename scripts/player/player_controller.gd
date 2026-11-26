class_name PlayerController
extends CharacterBody3D
## Relaxed third-person movement: camera-relative walking, gentle acceleration,
## sprint, forgiving jump (coyote time + jump buffer), and a safety net that
## returns the player to shore if they wander into deep water.
##
## Movement NEVER advances in-game time. Only activities call ActivityClock.

signal respawned
signal sat_down
signal stood_up

## Sitting: the sit clips put the hips this far above the feet (metres, at the model's
## size), with thighs level. A seat's surface sits a little under the hips.
const SIT_HIP_ABOVE_ORIGIN := 0.40
## In the sit_down / stand_up clips, when the body lowers onto / rises off the seat (s).
const SIT_LOWER_START := 0.3
const SIT_LOWER_END := 1.5
const STAND_RISE_START := 0.4
const STAND_RISE_END := 1.6
const STAND_UP_LENGTH := 2.0

@export_group("Movement")
## Relaxed pace. The walk animation is matched to these speeds (see CharacterAnimator).
@export var walk_speed: float = 1.7
@export var sprint_speed: float = 3.2
@export var ground_acceleration: float = 10.0
@export var ground_deceleration: float = 14.0
@export var air_acceleration: float = 3.0
@export var turn_sharpness: float = 11.0

@export_group("Jumping")
@export var jump_velocity: float = 5.4
@export var fall_gravity_multiplier: float = 1.7
@export var jump_cut_multiplier: float = 0.55
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

@export_group("Safety")
@export var max_water_depth: float = 1.25
## Willow Creek is a gate, so it turns you back sooner than still water does.
@export var max_creek_depth: float = 0.5
@export var void_height: float = -30.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _sprinting: bool = false
## Carrying a crate or pushing the cart (PlayerCarry): slower, no running or jumping.
var _hands_busy: bool = false
var _hands_speed: float = 1.0
var _last_safe_position: Vector3
var _safe_record_timer: float = 0.0
## While true (e.g. fishing), movement and jump input are ignored. Camera still works.
var _input_locked: bool = false
var _sitting: bool = false
var _standing_up: bool = false
var _stand_point: Vector3
var _sit_tween: Tween

@onready var _visual: Node3D = $Visual
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _animator: CharacterAnimator = $Visual/Character


func _ready() -> void:
	add_to_group("player")
	_last_safe_position = global_position
	add_child(Footsteps.new())
	add_child(ActionSounds.new())
	add_child(PlayerCarry.new())


func _physics_process(delta: float) -> void:
	if _sitting or _standing_up:
		velocity = Vector3.ZERO
		# Moving or jumping while seated stands you up. Sitting never uses time.
		if _sitting and not _standing_up:
			var wants_up := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back").length() > 0.3
			if wants_up or Input.is_action_just_pressed(&"jump"):
				stand_up()
		return
	var input := Vector2.ZERO if _input_locked else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var move_dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _camera_rig.get_yaw())
	_sprinting = Input.is_action_pressed(&"sprint") and input.length() > 0.1 and not _hands_busy
	var target_velocity := move_dir * (sprint_speed if _sprinting else walk_speed * _hands_speed)

	var rate := air_acceleration
	if is_on_floor():
		rate = ground_acceleration if input.length() > 0.01 else ground_deceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(target_velocity, 1.0 - exp(-rate * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
		var gravity_scale := fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * gravity_scale * delta

	if Input.is_action_just_pressed(&"jump") and not _input_locked and not _hands_busy:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	if Input.is_action_just_released(&"jump") and velocity.y > 0.0:
		velocity.y *= jump_cut_multiplier

	move_and_slide()

	_animator.update_locomotion(get_horizontal_speed(), is_on_floor(), _sprinting)

	if move_dir.length() > 0.05:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_sharpness * delta))

	_update_safety(delta)


func set_input_locked(locked: bool) -> void:
	_input_locked = locked


func is_input_locked() -> bool:
	return _input_locked


func is_sitting() -> bool:
	return _sitting


## Sits down on a seat. `seat` marks the seat surface where the hips go; its +Z is the
## way the sitter faces. `stand_point` is where to stand up to (on the floor).
## Sitting is free: it never advances the clock.
func sit_on(seat: Node3D, stand_point: Vector3) -> void:
	if _sitting or _standing_up or _input_locked:
		return
	_sitting = true
	_stand_point = stand_point
	set_input_locked(true)
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred(&"disabled", true)
	var facing := seat.global_basis.z
	facing.y = 0.0
	if facing.length() > 0.01:
		_visual.rotation.y = atan2(-facing.x, -facing.z)
	var target := seat.global_position - Vector3.UP * SIT_HIP_ABOVE_ORIGIN
	_animator.sit()
	if _sit_tween:
		_sit_tween.kill()
	_sit_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_sit_tween.tween_interval(SIT_LOWER_START)
	_sit_tween.tween_property(self, ^"global_position", target, SIT_LOWER_END - SIT_LOWER_START).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sat_down.emit()


## Gets up from a seat and walks free again.
func stand_up() -> void:
	if not _sitting or _standing_up:
		return
	_standing_up = true
	_animator.stand()
	if _sit_tween:
		_sit_tween.kill()
	_sit_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_sit_tween.tween_interval(STAND_RISE_START)
	_sit_tween.tween_property(self, ^"global_position", _stand_point, STAND_RISE_END - STAND_RISE_START).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sit_tween.tween_interval(maxf(STAND_UP_LENGTH - STAND_RISE_END, 0.0))
	_sit_tween.tween_callback(_finish_standing)


func _finish_standing() -> void:
	_sitting = false
	_standing_up = false
	$CollisionShape3D.set_deferred(&"disabled", false)
	_animator.stand_finished()
	set_input_locked(false)
	_last_safe_position = global_position
	stood_up.emit()


## Turns the character to face a camera-style yaw (0 = north).
func face_yaw(yaw: float) -> void:
	_visual.rotation.y = yaw


## Hands full (PlayerCarry): walk at `speed_factor` of the usual speed, no running or jumping.
func set_hands_busy(busy: bool, speed_factor: float = 1.0) -> void:
	_hands_busy = busy
	_hands_speed = speed_factor if busy else 1.0


func is_hands_busy() -> bool:
	return _hands_busy


func is_sprinting() -> bool:
	return _sprinting


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Places the player (used at spawn and after leaving deep water).
func teleport_to(position_: Vector3, facing_yaw: float = NAN) -> void:
	global_position = position_
	velocity = Vector3.ZERO
	if not is_nan(facing_yaw):
		_visual.rotation.y = facing_yaw
		_camera_rig.set_yaw(facing_yaw)
	_last_safe_position = position_
	reset_physics_interpolation()
	_camera_rig.snap_to_target()


func _update_safety(delta: float) -> void:
	if global_position.y < void_height:
		_return_to_safety("You found your way back to solid ground.")
		return
	var depth := WaterBody.deepest_at(get_tree(), global_position)
	if depth > max_water_depth:
		_return_to_safety("The water is too deep here — you paddle back to shore.")
		return
	# Willow Creek is quick and cold: past the shallow edge you climb back out (a gate:
	# the bridge is the way across, and the deep middle is wider than a running jump).
	if IslandShape.shared().get_creek_depth(global_position) > max_creek_depth:
		_return_to_safety("Willow Creek runs too deep and quick to wade. The old stone bridge is the way across.")
		return
	if is_on_floor() and depth < 0.05:
		_safe_record_timer -= delta
		if _safe_record_timer <= 0.0:
			_safe_record_timer = 0.5
			_last_safe_position = global_position


func _return_to_safety(message: String) -> void:
	teleport_to(_last_safe_position + Vector3.UP * 0.3)
	GameManager.notify(message)
	respawned.emit()
