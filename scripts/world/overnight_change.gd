class_name OvernightChange
extends Node
## Something that happens later on its own: once `after_flag` is on, the next new
## morning (or, with `at_hour` set, the next time the clock reaches that hour of the
## evening/night) sets `sets_flag` and shows `message`. The ancient oak bursts into leaf
## the morning after you plant saplings; the village well glows the first evening after
## Market Day. Flags are saved, so nothing is lost on load.

@export var after_flag: StringName = &""
@export var sets_flag: StringName = &""
@export_multiline var message: String = ""
## -1 = the next new morning. Otherwise the hour from which it happens (until 5 AM).
@export var at_hour: int = -1
## "The next morning" = the first time the clock reaches this hour after `after_flag`
## came on (waking up in bed is at 6 AM). Not midnight: planting at 1 AM and sleeping
## till 6 AM must still count as "the next morning".
const MORNING_HOUR := 6

## Clock time (ActivityClock.total_minutes) of the morning that brings the change.
var _due_at: int = -1


func _ready() -> void:
	if GameManager.has_flag(after_flag):
		_arm()
	GameManager.flag_changed.connect(func(flag: StringName, value: bool) -> void:
		if flag == after_flag and value:
			_arm())
	ActivityClock.time_changed.connect(func(_day: int, _minute: int) -> void:
		if at_hour >= 0:
			var hour := ActivityClock.get_hour()
			if hour >= at_hour or hour < 5:
				_trigger()
		elif _due_at >= 0 and ActivityClock.total_minutes >= _due_at:
			_trigger())


## Works out when the next morning is, counting from now.
func _arm() -> void:
	var now := ActivityClock.total_minutes
	var day_start := now - now % 1440
	_due_at = day_start + MORNING_HOUR * 60
	if now % 1440 >= MORNING_HOUR * 60:
		_due_at += 1440


func _trigger() -> void:
	if GameManager.has_flag(after_flag) and not GameManager.has_flag(sets_flag):
		GameManager.set_flag(sets_flag)
		if not message.is_empty():
			GameManager.notify(message)
