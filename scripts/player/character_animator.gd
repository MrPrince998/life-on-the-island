class_name CharacterAnimator
extends Node3D
## Drives the player's animations.
##
## Locomotion (idle / walk / run / jump) is chosen automatically from the player's
## speed and whether they're on the ground. Actions (fish_cast, fish_reel, farm_swing,
## wave) are started by gameplay code with play_action().
##
## Clips come from resources/animations/character_library.tres, built by
## tools/build_character_animations.gd. This node never changes time.

const LIBRARY := preload("res://resources/animations/character_library.tres")
## How far the walk clip moves the body (metres) in one full cycle, at the model's
## 1.8x scale: 1.347 units x 1.8 = 2.43 m over 2.33 s. Feet only stay planted when the
## clip plays at (ground speed / this speed), so the legs are matched to movement.
const WALK_METRES_PER_SECOND_AT_SCALE_ONE := 2.43 / 2.3333
const MIN_PLAYBACK := 0.25
## In the walk clip, the two legs are closest together at this time (seconds).
## Walks start here so the first step doesn't begin with one leg forward and one back.
const WALK_START_TIME := 2.24
const MAX_PLAYBACK := 3.0
## The run clip is the Mixamo run (source_assets/mixamo/Running.fbx) retargeted onto our
## rig by tools/build_character_animations.gd. One 0.7 s cycle moves the body 2.686 m at
## our character's size, so it is played at (ground speed / this) to keep feet planted.
const RUN_METRES_PER_SECOND_AT_SCALE_ONE := 2.686 / 0.7
const RUN_MIN_PLAYBACK := 0.6
const RUN_MAX_PLAYBACK := 1.6
## Actions that play once and then return to locomotion.
const ONE_SHOT_ACTIONS: Array[StringName] = [&"fish_cast", &"farm_swing", &"wave", &"stand_up", &"carry_lift", &"carry_reach"]

@export var blend_time: float = 0.2
## Longer blend when going from walking back to standing, so the legs settle smoothly.
@export var stop_blend_time: float = 0.35
## Sprinting switches the legs to the run clip once the player is moving faster
## than a walk. Two thresholds stop it flickering between walk and run.
@export var run_enter_speed: float = 2.1
@export var run_exit_speed: float = 1.9

var _player: AnimationPlayer
var _current: StringName = &""
var _action_active: bool = false
var _jumping: bool = false
## Clip used when standing still. Holding the rod switches this to "fish_hold".
var _idle_clip: StringName = &"idle"
## The walking clip (carrying a crate or pushing the cart swaps it).
var _walk_clip: StringName = &"walk"
## Seated: sit_down plays, then sit_idle loops until stand() is called.
var _seated: bool = false


func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_warning("CharacterAnimator: no AnimationPlayer in the character model.")
		return
	_player.remove_animation_library("")
	_player.add_animation_library("", LIBRARY)
	_player.animation_finished.connect(_on_animation_finished)
	_play(&"idle")


func set_idle_clip(clip: StringName) -> void:
	if LIBRARY.has_animation(clip):
		_idle_clip = clip


func set_walk_clip(clip: StringName) -> void:
	_walk_clip = clip if LIBRARY.has_animation(clip) else &"walk"


func get_current_animation() -> StringName:
	return _current


## Called every physics frame by the player.
func update_locomotion(speed: float, on_floor: bool, sprinting: bool) -> void:
	if _player == null:
		return
	if not on_floor:
		if not _jumping:
			_jumping = true
			_action_active = false
			_play(&"jump")
		return
	if _jumping:
		_jumping = false
		_current = &""
	if _action_active:
		return
	var running := _current == &"run"
	if speed < 0.2:
		_play(_idle_clip)
	elif (running and speed > run_exit_speed) or (sprinting and speed > run_enter_speed):
		_play(&"run", clampf(speed / RUN_METRES_PER_SECOND_AT_SCALE_ONE, RUN_MIN_PLAYBACK, RUN_MAX_PLAYBACK))
	else:
		_play(_walk_clip, clampf(speed / WALK_METRES_PER_SECOND_AT_SCALE_ONE, MIN_PLAYBACK, MAX_PLAYBACK))


## Starts a named action. Returns false if the name is unknown.
func play_action(action: StringName) -> bool:
	if _player == null or not LIBRARY.has_animation(action):
		return false
	_action_active = true
	# The same one-shot again (a second work swing) starts over, not carries on.
	var again := action == _current and action in ONE_SHOT_ACTIONS and _player.is_playing()
	_play(action)
	if again:
		_player.seek(0.0, true)
	return true


## Sits down (sit_down, then sit_idle on a loop) until stand() is called.
func sit() -> void:
	_seated = true
	play_action(&"sit_down")


## Plays the stand-up clip; stand_finished() hands back to walking and idling.
func stand() -> void:
	_seated = false
	play_action(&"stand_up")


func stand_finished() -> void:
	_seated = false
	_action_active = false
	_current = &""


func is_seated() -> bool:
	return _seated


## True if the library contains this clip.
func has_clip(clip: StringName) -> bool:
	return LIBRARY.has_animation(clip)


## Playback position (seconds) of the clip that is playing now.
func get_action_position() -> float:
	return _player.current_animation_position if _player and _player.is_playing() else 0.0


## Which way the held fishing rod points in the clip playing now (skeleton space), from
## the clip's "rod_directions" metadata (see tools/build_character_animations.gd).
## Vector3.ZERO when the clip has no rod (walking, running...).
func get_rod_direction() -> Vector3:
	if _player == null or not _player.is_playing():
		return Vector3.ZERO
	var anim := _player.get_animation(_player.current_animation)
	if anim == null or not anim.has_meta(&"rod_directions"):
		return Vector3.ZERO
	var dirs: PackedVector3Array = anim.get_meta(&"rod_directions")
	if dirs.is_empty():
		return Vector3.ZERO
	var frame := _player.current_animation_position * float(anim.get_meta(&"rod_fps", 30.0))
	var i := clampi(int(frame), 0, dirs.size() - 1)
	var j := mini(i + 1, dirs.size() - 1)
	return dirs[i].slerp(dirs[j], clampf(frame - i, 0.0, 1.0)).normalized()


## Changes the playback speed of the running action (0 = hold the current pose).
func set_action_speed(speed: float) -> void:
	if _player:
		_player.speed_scale = speed


## Ends a looping action (such as fish_reel) and returns to locomotion.
func stop_action() -> void:
	_action_active = false
	_current = &""


func _play(anim: StringName, speed: float = 1.0) -> void:
	if _player == null:
		return
	if anim != _current:
		var was_walking := _current == &"walk"
		var was_moving := was_walking or _current == &"run"
		var blend := stop_blend_time if (anim == _idle_clip and was_moving) else blend_time
		_current = anim
		_player.play(anim, blend)
		if anim == &"walk" and not was_walking:
			_player.seek(WALK_START_TIME, true)
	_player.speed_scale = speed


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"sit_down" and _seated and anim_name == _current:
		_play(&"sit_idle")
		return
	if anim_name in ONE_SHOT_ACTIONS and anim_name == _current:
		_action_active = false
		_current = &""
