class_name ReelMinigame
extends RefCounted
## The reeling minigame, as pure logic (no visuals), so it can be tested.
##
## Hold to reel: tension rises. Let go: tension falls. The fish takes turns
## resting and struggling; while it struggles it pulls tension up and swims away.
## - Tension in the green zone while reeling brings the fish closer.
## - Tension at the top for too long snaps the line.
## - A slack line for too long lets the fish slip away.

enum Result { NONE, CAUGHT, SNAPPED, ESCAPED }

const SWEET_MIN := 0.35
const SWEET_MAX := 0.75
const SNAP_TIME := 0.4
const SLACK_LIMIT := 0.08
const SLACK_TIME := 3.0
const CATCH_DISTANCE := 0.6
const ESCAPE_EXTRA_DISTANCE := 5.0

var tension: float = 0.3
var distance: float = 10.0
var start_distance: float = 10.0
var difficulty: float = 0.3
var struggling: bool = false
var result: Result = Result.NONE

var _phase_timer: float = 1.5
var _over_timer: float = 0.0
var _slack_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(fish_difficulty: float, line_distance: float, seed_value: int = 0) -> void:
	difficulty = clampf(fish_difficulty, 0.0, 1.0)
	distance = maxf(line_distance, CATCH_DISTANCE + 1.0)
	start_distance = distance
	tension = 0.3
	struggling = false
	result = Result.NONE
	_over_timer = 0.0
	_slack_timer = 0.0
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_phase_timer = _rng.randf_range(0.8, 1.6)


## Progress toward landing the fish: 0 at the cast distance, 1 when caught.
func get_progress() -> float:
	return clampf(1.0 - (distance - CATCH_DISTANCE) / maxf(start_distance - CATCH_DISTANCE, 0.01), 0.0, 1.0)


func is_in_sweet_zone() -> bool:
	return tension >= SWEET_MIN and tension <= SWEET_MAX


func update(delta: float, reeling: bool) -> Result:
	if result != Result.NONE:
		return result

	_phase_timer -= delta
	if _phase_timer <= 0.0:
		struggling = not struggling
		if struggling:
			_phase_timer = _rng.randf_range(0.6, 1.3) * (0.7 + difficulty * 0.8)
		else:
			_phase_timer = _rng.randf_range(1.0, 2.2) * (1.3 - difficulty * 0.5)

	var pull := (0.15 + 0.45 * difficulty) if struggling else 0.04
	tension += ((0.5 if reeling else -0.9) + pull) * delta
	tension = clampf(tension, 0.0, 1.15)

	var reel_speed := 2.3 - 0.9 * difficulty
	if reeling:
		if is_in_sweet_zone():
			distance -= reel_speed * delta
		elif tension > SWEET_MAX:
			distance -= reel_speed * 0.35 * delta
		else:
			distance -= reel_speed * 0.5 * delta
	if struggling:
		distance += (0.35 + 0.6 * difficulty) * (0.45 if reeling else 1.0) * delta

	_over_timer = _over_timer + delta if tension >= 1.0 else 0.0
	_slack_timer = _slack_timer + delta if tension < SLACK_LIMIT else maxf(_slack_timer - delta, 0.0)

	if _over_timer >= SNAP_TIME:
		result = Result.SNAPPED
	elif _slack_timer >= SLACK_TIME or distance >= start_distance + ESCAPE_EXTRA_DISTANCE:
		result = Result.ESCAPED
	elif distance <= CATCH_DISTANCE:
		result = Result.CAUGHT
	return result
