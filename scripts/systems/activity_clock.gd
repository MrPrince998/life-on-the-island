extends Node
## ActivityClock (autoload) — the ONLY place in-game time lives.
##
## Time in Life on the Island does not tick on its own. Walking, running,
## looking around and talking are free. Time moves forward only when a
## gameplay system finishes an activity and calls:
##
##     ActivityClock.advance_minutes(60, &"rest")
##
## Never call advance_minutes from _process / _physics_process.

## Emitted once per advance, before time_changed. Useful for logs and NPC schedules.
signal time_advanced(minutes: int, activity_id: StringName)
## Emitted once for every new day reached during an advance (sleeping past midnight, etc.).
signal day_started(day: int)
## Emitted when a new season begins during an advance (on its first day), after day_started.
signal season_started(season_id: StringName)
## Emitted after every change to the clock (advance or load). UI listens to this.
signal time_changed(day: int, minute_of_day: int)

const MINUTES_PER_DAY := 1440
const DAYS_PER_SEASON := 28
const SEASON_IDS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const START_MINUTE_OF_DAY := 6 * 60
const SAVE_VERSION := 1

## Minutes elapsed since Day 1, 00:00.
var total_minutes: int = START_MINUTE_OF_DAY


func advance_minutes(amount: int, activity_id: StringName) -> void:
	if amount <= 0:
		push_warning("ActivityClock.advance_minutes ignored a non-positive amount (%d) from '%s'." % [amount, activity_id])
		return
	if activity_id == &"":
		push_warning("ActivityClock.advance_minutes called without an activity_id.")
	var previous_day := get_day()
	total_minutes += amount
	time_advanced.emit(amount, activity_id)
	for day in range(previous_day + 1, get_day() + 1):
		day_started.emit(day)
		if (day - 1) % DAYS_PER_SEASON == 0:
			season_started.emit(SEASON_IDS[floori((day - 1) / float(DAYS_PER_SEASON)) % SEASON_IDS.size()])
	time_changed.emit(get_day(), get_minute_of_day())


## Minutes from now until the next occurrence of hour:minute. Always in 1..1440.
func minutes_until(hour: int, minute: int = 0) -> int:
	var target := (hour * 60 + minute) % MINUTES_PER_DAY
	var delta := posmod(target - get_minute_of_day(), MINUTES_PER_DAY)
	return MINUTES_PER_DAY if delta == 0 else delta


func get_day() -> int:
	return floori(total_minutes / float(MINUTES_PER_DAY)) + 1


func get_minute_of_day() -> int:
	return posmod(total_minutes, MINUTES_PER_DAY)


func get_hour() -> int:
	return floori(get_minute_of_day() / 60.0)


func get_minute() -> int:
	return get_minute_of_day() % 60


func get_season_index() -> int:
	return floori((get_day() - 1) / float(DAYS_PER_SEASON)) % SEASON_IDS.size()


func get_season_id() -> StringName:
	return SEASON_IDS[get_season_index()]


func get_season_name() -> String:
	return SEASON_NAMES[get_season_index()]


func get_day_of_season() -> int:
	return (get_day() - 1) % DAYS_PER_SEASON + 1


func is_night() -> bool:
	var hour := get_hour()
	return hour < 5 or hour >= 21


func get_time_string() -> String:
	var hour := get_hour()
	var suffix := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:%02d %s" % [display_hour, get_minute(), suffix]


func get_date_string() -> String:
	return "Day %d  ·  %s %d" % [get_day(), SEASON_NAMES[get_season_index()], get_day_of_season()]


## Save support (used by the future SaveManager).
func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "total_minutes": total_minutes}


func from_dict(data: Dictionary) -> void:
	total_minutes = maxi(int(data.get("total_minutes", START_MINUTE_OF_DAY)), 0)
	time_changed.emit(get_day(), get_minute_of_day())


func reset() -> void:
	total_minutes = START_MINUTE_OF_DAY
	time_changed.emit(get_day(), get_minute_of_day())
