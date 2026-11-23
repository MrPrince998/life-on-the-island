class_name FishingController
extends Node
## Fishing for the player: equip rod -> charge and cast -> wait -> bite -> reel -> catch.
##
## Controls: R = rod in/out, hold Left Click = charge cast, release = cast,
## Left Click on a bite = hook, hold Left Click = reel, Right Click = reel in / give up.
##
## Time rules (explicit, activity-based):
##   catch a fish          -> catch_minutes
##   fish escapes / snaps  -> lost_minutes
##   miss a bite           -> missed_bite_minutes
##   waiting, casting, walking with the rod, cancelling before a bite -> no time.

signal state_changed(new_state: int)
signal hint_changed(text: String)
signal cast_power_changed(power: float)
signal fish_hooked(fish: FishData)
signal reel_updated(tension: float, progress: float, struggling: bool)
signal catch_finished(fish: FishData, size_cm: float, info: Dictionary)
signal fish_lost(reason: String)

enum State { STOWED, READY, CHARGING, CASTING, WAITING, BITE, REELING, LANDING }

## Angle of the rod above horizontal while just holding it (degrees).
const HOLD_PITCH := 40.0
## Cast clip (fish_cast, from Mixamo "Fishing Cast"): the wind-up peaks here (the pose
## is held while the player charges the cast) and the line is released here.
## Story: the player starts without a rod. Oliver the fisherman gives it to them
## (his conversation calls grant_rod()) and explains how to fish.
const ROD_FLAG := &"has_fishing_rod"
const CAST_WINDUP := 1.45
const CAST_RELEASE := 2.0

@export var catalog: FishCatalog

@export_group("Time costs (minutes)")
@export var catch_minutes: int = 20
@export var lost_minutes: int = 10
@export var missed_bite_minutes: int = 5

@export_group("Timing")
@export var bite_wait_min: float = 3.0
@export var bite_wait_max: float = 9.0
@export var bite_window: float = 1.4
@export var charge_cycle: float = 1.3
@export var landing_pause: float = 2.4

@export_group("Cast")
@export var min_cast_distance: float = 3.5
@export var max_cast_distance: float = 13.0
@export var min_water_depth: float = 0.4

## Tests can force these: wait time before a bite (<0 = random) and reeling input (-1 = player input).
var bite_wait_override: float = -1.0
var reel_override: int = -1
## Set by the ukulele's Lake Lullaby: the next cast gets a bite almost at once.
var quick_bite_next: bool = false
const QUICK_BITE_SECONDS := 1.0

var state: State = State.STOWED

var _player: PlayerController
var _animator: CharacterAnimator
var _tackle: FishingTackle
var _minigame := ReelMinigame.new()
var _rng := RandomNumberGenerator.new()
var _power: float = 0.0
var _charge_time: float = 0.0
var _timer: float = 0.0
var _water: WaterBody
var _cast_target: Vector3
var _cast_dir: Vector3 = Vector3.FORWARD
var _fish: FishData


func _ready() -> void:
	add_to_group(&"fishing_controller")
	_rng.randomize()
	_player = get_parent() as PlayerController
	_animator = _player.get_node("Visual/Character") as CharacterAnimator
	_tackle = $Tackle as FishingTackle
	_tackle.setup(_player, _player.get_node("Visual") as Node3D, _animator)


func is_busy() -> bool:
	return state != State.STOWED and state != State.READY


func get_hooked_fish() -> FishData:
	return _fish


func get_minigame() -> ReelMinigame:
	return _minigame


# ---- Player actions -------------------------------------------------------

func toggle_rod() -> void:
	if state == State.STOWED:
		equip()
	elif state == State.READY:
		stow()


## The holding and casting clips are two-handed: the rod follows the direction stored in
## the clip (not while reeling, which uses its own reel animation, or while celebrating).
func _update_rod_follow() -> void:
	_tackle.follow_hands = state in [State.READY, State.CHARGING, State.CASTING, State.WAITING, State.BITE]


## True once Oliver has given the player the fishing rod.
func has_rod() -> bool:
	return GameManager.has_flag(ROD_FLAG)


## Gives the player the fishing rod (called at the end of Oliver's first conversation).
func grant_rod() -> void:
	if has_rod():
		return
	GameManager.set_flag(ROD_FLAG)
	GameManager.notify("You got Oliver's spare fishing rod! Press R to take it out.")
	SaveManager.save_game("got fishing rod")


func equip() -> void:
	if state != State.STOWED:
		return
	if not has_rod():
		GameManager.notify("You don't have a fishing rod yet. Maybe someone down at the dock can help.")
		return
	_tackle.set_equipped(true)
	_tackle.rod_pitch = HOLD_PITCH
	_animator.set_idle_clip(&"fish_hold")
	_set_state(State.READY)


func stow() -> void:
	if state != State.READY:
		return
	_tackle.set_equipped(false)
	_animator.set_idle_clip(&"idle")
	_set_state(State.STOWED)


func begin_charge() -> void:
	if state != State.READY or not _player.is_on_floor():
		return
	var yaw := (_player.get_node("CameraRig") as CameraRig).get_yaw()
	_cast_dir = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	_player.set_input_locked(true)
	_player.face_yaw(yaw)
	# Wind up while charging; the pose is held at the top (see _physics_process).
	_animator.play_action(&"fish_cast")
	_power = 0.0
	_charge_time = 0.0
	_set_state(State.CHARGING)


## Releases the cast. `power` < 0 uses the charged power.
func release_cast(power: float = -1.0) -> void:
	if state != State.CHARGING:
		return
	if power >= 0.0:
		_power = clampf(power, 0.0, 1.0)
	var distance := lerpf(min_cast_distance, max_cast_distance, _power)
	var origin := _player.global_position
	var target := origin + _cast_dir * distance
	_water = find_water_at(target)
	if _water:
		target.y = _water.get_surface_height()
	else:
		target.y = IslandShape.shared().get_height(target.x, target.z) + 0.05
	_cast_target = target
	_set_state(State.CASTING)
	var tween := create_tween()
	# Carry on from the wind-up; the line goes when the rod whips forward.
	_animator.set_action_speed(1.0)
	tween.tween_interval(maxf(CAST_RELEASE - _animator.get_action_position(), 0.05))
	tween.tween_callback(func() -> void: _tackle.launch_bobber(_cast_target, 0.55, _on_bobber_landed))


func hook() -> void:
	if state != State.BITE:
		return
	var line_distance := Vector2(_cast_target.x - _player.global_position.x, _cast_target.z - _player.global_position.z).length()
	# A better rod (UpgradeService) takes some of the fight out of the fish.
	_minigame.setup(_fish.difficulty * (1.0 - UpgradeService.rod_ease()), line_distance, _rng.randi() | 1)
	_animator.play_action(&"fish_reel")
	_tackle.set_bite(false)
	fish_hooked.emit(_fish)
	_set_state(State.REELING)


## Right click: reel in. Before a bite this is free; during a fight the fish gets away.
func cancel() -> void:
	match state:
		State.CHARGING, State.WAITING, State.BITE:
			_finish(false)
		State.REELING:
			_lose_fish("You let the fish go.")
		_:
			pass


# ---- Water ------------------------------------------------------------------

## The water body at this spot if it is deep enough to fish, else null.
func find_water_at(point: Vector3) -> WaterBody:
	var ground := IslandShape.shared().get_height(point.x, point.z)
	var best: WaterBody = null
	for node in get_tree().get_nodes_in_group(&"water_body"):
		var water := node as WaterBody
		if water == null or not water.contains_xz(point):
			continue
		if water.get_surface_height() - ground < min_water_depth:
			continue
		if best == null or water.get_surface_height() > best.get_surface_height():
			best = water
	return best


# ---- Update -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_rod"):
		toggle_rod()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"cancel_tool") and is_busy():
		cancel()
		get_viewport().set_input_as_handled()
		return
	var mouse_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless"
	if event.is_action_pressed(&"use_tool") and not mouse_free:
		if state == State.READY:
			begin_charge()
			get_viewport().set_input_as_handled()
		elif state == State.BITE:
			hook()
			get_viewport().set_input_as_handled()
	elif event.is_action_released(&"use_tool") and state == State.CHARGING:
		release_cast()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	match state:
		State.CHARGING:
			_charge_time += delta
			_power = 1.0 - absf(fposmod(_charge_time / charge_cycle, 2.0) - 1.0)
			if _animator.get_action_position() >= CAST_WINDUP:
				_animator.set_action_speed(0.0)
			cast_power_changed.emit(_power)
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_start_bite()
		State.BITE:
			_timer -= delta
			if _timer <= 0.0:
				_tackle.set_bite(false)
				ActivityClock.advance_minutes(missed_bite_minutes, &"fishing")
				GameManager.notify("It nibbled and swam off. Try clicking as soon as the bobber dips!")
				_finish(false)
		State.REELING:
			var reeling := Input.is_action_pressed(&"use_tool") if reel_override < 0 else reel_override == 1
			var result := _minigame.update(delta, reeling)
			_tackle.line_tension = _minigame.tension
			# Rod bends with tension (shakes when the fish fights); the reel winds in while
			# reeling and clicks backwards when the fish pulls line out.
			var shake := sin(Time.get_ticks_msec() * 0.03) * 0.08 if _minigame.struggling else 0.0
			_tackle.rod_bend = clampf(0.12 + _minigame.tension * 0.75 + shake, 0.0, 1.0)
			if reeling:
				_tackle.reel_speed = 1.5 + _minigame.tension * 1.5
			elif _minigame.struggling:
				_tackle.reel_speed = -1.2
			else:
				_tackle.reel_speed = 0.0
			_tackle.rod_pitch = 28.0 + _minigame.tension * 30.0 + (sin(Time.get_ticks_msec() * 0.02) * 3.0 if _minigame.struggling else 0.0)
			var to_target := Vector3(_cast_target.x - _player.global_position.x, 0, _cast_target.z - _player.global_position.z)
			if to_target.length() > 0.01:
				var point := _player.global_position + to_target.normalized() * maxf(_minigame.distance, 0.6)
				point.y = _cast_target.y
				_tackle.set_bobber_rest(point)
			reel_updated.emit(_minigame.tension, _minigame.get_progress(), _minigame.struggling)
			match result:
				ReelMinigame.Result.CAUGHT:
					_land_fish()
				ReelMinigame.Result.SNAPPED:
					_lose_fish("Snap! The line was too tight. Let go when it turns red.")
				ReelMinigame.Result.ESCAPED:
					_lose_fish("The fish slipped away. Keep the line in the green.")
		State.LANDING:
			_timer -= delta
			if _timer <= 0.0:
				_finish(false)


# ---- Steps --------------------------------------------------------------------

func _on_bobber_landed() -> void:
	if state != State.CASTING:
		return
	if _water == null:
		GameManager.notify("That's not deep enough water. Face the lake or the sea and cast again.")
		_finish(false)
		return
	_animator.play_action(&"fish_hold")
	_tackle.line_tension = 0.0
	_tackle.rod_bend = 0.04
	_timer = bite_wait_override if bite_wait_override >= 0.0 else _rng.randf_range(bite_wait_min, bite_wait_max)
	if quick_bite_next:
		# The Lake Lullaby (ukulele) hummed the fish up: this cast gets a bite at once.
		quick_bite_next = false
		_timer = minf(_timer, QUICK_BITE_SECONDS)
	_set_state(State.WAITING)


func _start_bite() -> void:
	_fish = catalog.pick(_water.water_id, ActivityClock.get_hour(), _rng, UpgradeService.rare_bonus()) if catalog else null
	if _fish == null:
		GameManager.notify("Nothing seems to be biting here right now.")
		_finish(false)
		return
	_tackle.set_bite(true)
	_timer = bite_window
	_set_state(State.BITE)


func _land_fish() -> void:
	var size_cm := snappedf(lerpf(_fish.min_size_cm, _fish.max_size_cm, pow(_rng.randf(), 1.6)), 0.1)
	var kept := InventoryManager.add_item(_fish.id) > 0
	if not kept:
		GameManager.notify("Your bag is full, so you let the %s swim free. Sell something at the General Store." % _fish.display_name)
	var info := Journal.record_fish(_fish.id, size_cm)
	QuestLog.record_event(&"catch_fish")
	ActivityClock.advance_minutes(catch_minutes, &"fishing")
	info["minutes"] = catch_minutes
	info["kept"] = kept
	_tackle.rod_bend = 0.0
	_tackle.reel_speed = 0.0
	_tackle.reel_in_bobber()
	_tackle.show_catch(_fish, size_cm)
	_animator.play_action(&"wave")
	catch_finished.emit(_fish, size_cm, info)
	_timer = landing_pause
	_set_state(State.LANDING)


func _lose_fish(message: String) -> void:
	ActivityClock.advance_minutes(lost_minutes, &"fishing")
	GameManager.notify(message)
	fish_lost.emit(message)
	_finish(false)


## Back to standing with the rod ready.
func _finish(_caught: bool) -> void:
	_tackle.reel_in_bobber()
	_tackle.set_bite(false)
	_tackle.line_tension = 0.0
	_tackle.rod_bend = 0.0
	_tackle.reel_speed = 0.0
	_tackle.rod_pitch = HOLD_PITCH
	_animator.stop_action()
	_player.set_input_locked(false)
	_fish = null
	_set_state(State.READY)


func _set_state(new_state: State) -> void:
	state = new_state
	_update_rod_follow()
	# Left hand: on the reel crank while fighting a fish, free while celebrating a
	# catch, otherwise resting on the rod butt.
	match new_state:
		State.REELING:
			_tackle.left_hand = FishingTackle.LeftHand.CRANK
		State.STOWED, State.LANDING:
			_tackle.left_hand = FishingTackle.LeftHand.FREE
		_:
			_tackle.left_hand = FishingTackle.LeftHand.HANDLE
	state_changed.emit(new_state)
	hint_changed.emit(_hint_for(new_state))


func _hint_for(s: State) -> String:
	match s:
		State.STOWED:
			return ""
		State.READY:
			return "Hold Left Click to cast  ·  R to put the rod away"
		State.CHARGING:
			return "Release to cast"
		State.CASTING:
			return ""
		State.WAITING:
			return "Waiting for a bite…  (Right Click to reel in)"
		State.BITE:
			return "BITE!  Click now!"
		State.REELING:
			return "Hold Left Click to reel  ·  let go when the line turns red"
		State.LANDING:
			return ""
	return ""
