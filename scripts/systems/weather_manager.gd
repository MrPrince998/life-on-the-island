extends Node
## WeatherManager (autoload): today's weather. It changes only when a new in-game day
## starts (ActivityClock.day_started), never on a real-time timer.
##
## Weather so far: SUNNY, CLOUDY, RAIN. Rain waters every dug garden bed (FarmField).
## Fog and storms come later (see CLAUDE.md, Phase 7).
##
## Saved through SaveManager's "persistent" group (save key "weather").

signal weather_changed(weather: int)

enum Weather { SUNNY, CLOUDY, RAIN, SNOW }

const NAMES: Array[String] = ["Sunny", "Cloudy", "Rain", "Snow"]
## Chances for a new day, by season: [rain (snow in winter), cloudy]; the rest is sunny.
## Day 1 is always sunny.
const SEASON_CHANCES := {
	&"spring": [0.30, 0.25],
	&"summer": [0.12, 0.18],
	&"autumn": [0.25, 0.35],
	&"winter": [0.35, 0.30],
}
const RAIN_CHANCE := 0.22
const CLOUDY_CHANCE := 0.25
const SAVE_VERSION := 1

var current: Weather = Weather.SUNNY
## Makes each game's weather different but repeatable (saved).
var weather_seed: int = 0
## Tests turn this off so the weather stays put while they skip through days.
var auto_change: bool = true


func _ready() -> void:
	add_to_group(&"persistent")
	weather_seed = randi()
	ActivityClock.day_started.connect(_on_day_started)


func is_raining() -> bool:
	return current == Weather.RAIN


func is_snowing() -> bool:
	return current == Weather.SNOW


## Rain or snow: either way the garden gets watered.
func is_wet() -> bool:
	return current == Weather.RAIN or current == Weather.SNOW


func get_weather_name() -> String:
	return NAMES[current]


## A short line for the morning (shown after sleeping). On a season's first day it
## starts by announcing the new season and what can be planted.
func get_morning_line() -> String:
	var line := _weather_line()
	if ActivityClock.get_day_of_season() == 1 and ActivityClock.get_day() > 1:
		var crops: Array[String] = []
		for crop in CropCatalog.shared().crops:
			if crop.grows_in(ActivityClock.get_season_id()):
				crops.append(crop.display_name)
		line = "%s has arrived! In season now: %s.  %s" % [ActivityClock.get_season_name(), ", ".join(crops), line]
	return line


func _weather_line() -> String:
	match current:
		Weather.RAIN:
			return "It's raining today, so the garden gets a good drink."
		Weather.CLOUDY:
			return "Soft grey clouds today."
		Weather.SNOW:
			return "Snow is falling. The whole island has gone quiet and white."
	return "A sunny day."


func set_weather(weather: Weather) -> void:
	if weather == current:
		return
	current = weather
	weather_changed.emit(current)


## The weather a given day gets (same seed + day = same weather). Each season has its
## own mood: rainy springs, sunny summers, cloudy autumns and snowy winters.
func roll_for_day(day: int) -> Weather:
	if day <= 1:
		return Weather.SUNNY
	var season := ActivityClock.SEASON_IDS[floori((day - 1) / float(ActivityClock.DAYS_PER_SEASON)) % ActivityClock.SEASON_IDS.size()]
	var chances: Array = SEASON_CHANCES.get(season, [RAIN_CHANCE, CLOUDY_CHANCE])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([weather_seed, day])
	var roll := rng.randf()
	if roll < float(chances[0]):
		return Weather.SNOW if season == &"winter" else Weather.RAIN
	if roll < float(chances[0]) + float(chances[1]):
		return Weather.CLOUDY
	return Weather.SUNNY


func _on_day_started(day: int) -> void:
	if auto_change:
		set_weather(roll_for_day(day))


## New game: sunny, with fresh weather ahead.
func reset() -> void:
	weather_seed = randi()
	set_weather(Weather.SUNNY)


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "weather"


func save_state() -> Dictionary:
	return {"version": SAVE_VERSION, "weather": int(current), "seed": weather_seed}


func load_state(data: Dictionary) -> void:
	weather_seed = int(data.get("seed", weather_seed))
	set_weather(clampi(int(data.get("weather", 0)), 0, Weather.size() - 1) as Weather)
