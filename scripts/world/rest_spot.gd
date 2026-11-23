class_name RestSpot
extends Interactable
## A seat or a bed.
##   SIT: the player sits down (with an animation) and stays until they press E or
##        move. Sitting is not an activity, so no time passes.
##   SLEEP_UNTIL_MORNING: sleeping is an activity; time skips to wake_hour.
##   FIXED_DURATION: resting that passes duration_minutes (kept for future use).
##
## SIT spots use two optional children: "Seat" (a Marker3D on the seat surface where the
## hips go, +Z = the way you face) and "StandPoint" (where you stand up to). Without them
## the spot itself is the seat and you stand up 0.7 m in front of it.

enum Mode { FIXED_DURATION, SLEEP_UNTIL_MORNING, SIT }

@export var mode: Mode = Mode.FIXED_DURATION
@export var duration_minutes: int = 60
@export var wake_hour: int = 6
@export var activity_id: StringName = &"rest"


func get_prompt() -> String:
	match mode:
		Mode.SLEEP_UNTIL_MORNING:
			return "%s  (sleep until %d:00 AM)" % [prompt_text, wake_hour]
		Mode.SIT:
			return prompt_text
	return "%s  (%s)" % [prompt_text, _format_duration(duration_minutes)]


func get_minutes_for_activity() -> int:
	match mode:
		Mode.SLEEP_UNTIL_MORNING:
			return ActivityClock.minutes_until(wake_hour)
		Mode.SIT:
			return 0
	return duration_minutes


func get_seat() -> Node3D:
	var seat := get_node_or_null(^"Seat") as Node3D
	return seat if seat else self


func get_stand_point() -> Vector3:
	var marker := get_node_or_null(^"StandPoint") as Node3D
	if marker:
		return marker.global_position
	var seat := get_seat()
	var forward := seat.global_basis.z
	forward.y = 0.0
	return seat.global_position + forward.normalized() * 0.7 - Vector3.UP * 0.4


func _on_interact(interactor: Node) -> void:
	if mode == Mode.SIT:
		_sit(interactor as PlayerController)
		return
	var minutes := get_minutes_for_activity()
	ActivityClock.advance_minutes(minutes, activity_id)
	if mode == Mode.SLEEP_UNTIL_MORNING:
		GameManager.notify("You slept soundly. Good morning!  %s  %s" % [ActivityClock.get_time_string(), WeatherManager.get_morning_line()])
	else:
		GameManager.notify("You rested for %s. It's now %s." % [_format_duration(minutes), ActivityClock.get_time_string()])


func _sit(player: PlayerController) -> void:
	if player == null or player.is_sitting():
		return
	var fishing := player.get_node_or_null(^"Fishing") as FishingController
	if fishing:
		if fishing.is_busy():
			return
		fishing.stow()
	player.sit_on(get_seat(), get_stand_point())


static func _format_duration(minutes: int) -> String:
	if minutes % 60 == 0:
		var hours := floori(minutes / 60.0)
		return "1 hour" if hours == 1 else "%d hours" % hours
	return "%d min" % minutes
