class_name DayNightController
extends Node
## Presents the ActivityClock's time of day: sun angle, light colour, sky colours.
##
## This node never changes the time. When the clock jumps forward (e.g. after
## resting), it smoothly animates the sky from the old time to the new one.
## It also shows WeatherManager's weather: grey skies and softer light on cloudy and
## rainy days, plus falling rain (RainEffect).

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var day_sun_energy: float = 1.25
@export var night_light_energy: float = 0.22

var _display_minutes: float = 0.0
var _tween: Tween
## 0 = clear sky, 1 = heavy rain clouds.
var _overcast: float = 0.0
var _weather_tween: Tween
var _base_fog_density: float = -1.0
var _rain: RainEffect


func _ready() -> void:
	_display_minutes = float(ActivityClock.total_minutes)
	_overcast = overcast_for(WeatherManager.current)
	_apply(_display_minutes)
	ActivityClock.time_changed.connect(_on_time_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	_rain = RainEffect.new()
	_rain.name = "Rain"
	add_child(_rain)
	_season = ActivityClock.get_season_id()
	_season_clock = ActivityClock.total_minutes
	_set_season_instantly(_season)


# ---- Seasons ---------------------------------------------------------------------------
# The terrain and foliage shaders read three global values (season_summer,
# season_autumn, season_winter; spring = all zero). They ease over a few seconds when a
# new season starts, and snap when a game loads into a different season.

const SEASON_GLOBALS := [&"season_summer", &"season_autumn", &"season_winter"]
const SEASON_FADE := 4.0
var _season: StringName = &"spring"
var _season_clock: int = 0
var _season_values := [0.0, 0.0, 0.0]
var _season_tween: Tween


static func season_targets(season_id: StringName) -> Array:
	match season_id:
		&"summer":
			return [1.0, 0.0, 0.0]
		&"autumn":
			return [0.0, 1.0, 0.0]
		&"winter":
			return [0.0, 0.0, 1.0]
	return [0.0, 0.0, 0.0]


func get_season_values() -> Array:
	return _season_values.duplicate()


func _set_season_instantly(season_id: StringName) -> void:
	if _season_tween:
		_season_tween.kill()
	_set_season_mix(season_targets(season_id), 1.0, season_targets(season_id))


func _fade_to_season(season_id: StringName) -> void:
	var from := _season_values.duplicate()
	var to := season_targets(season_id)
	if _season_tween:
		_season_tween.kill()
	_season_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_season_tween.tween_method(func(t: float) -> void: _set_season_mix(from, t, to), 0.0, 1.0, SEASON_FADE)


func _set_season_mix(from: Array, t: float, to: Array) -> void:
	for i in 3:
		_season_values[i] = lerpf(float(from[i]), float(to[i]), t)
		RenderingServer.global_shader_parameter_set(SEASON_GLOBALS[i], _season_values[i])


func _check_season() -> void:
	var now := ActivityClock.get_season_id()
	var went_forward := ActivityClock.total_minutes >= _season_clock
	_season_clock = ActivityClock.total_minutes
	if now == _season:
		return
	# Fade when time moved on into the next season; snap for loads and new games.
	var forward := went_forward and ActivityClock.get_season_index() == (ActivityClock.SEASON_IDS.find(_season) + 1) % ActivityClock.SEASON_IDS.size()
	_season = now
	if forward:
		_fade_to_season(now)
	else:
		_set_season_instantly(now)


## How cloudy the sky is for a weather (0..1).
static func overcast_for(weather: int) -> float:
	match weather:
		WeatherManager.Weather.RAIN:
			return 1.0
		WeatherManager.Weather.CLOUDY:
			return 0.55
		WeatherManager.Weather.SNOW:
			return 0.7
	return 0.0


func get_overcast() -> float:
	return _overcast


func _on_weather_changed(weather: int) -> void:
	if _weather_tween:
		_weather_tween.kill()
	_weather_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_weather_tween.tween_method(_set_overcast, _overcast, overcast_for(weather), 2.0)


func _set_overcast(value: float) -> void:
	_overcast = value
	_apply(_display_minutes)


func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	_check_season()
	var target := float(ActivityClock.total_minutes)
	if _tween:
		_tween.kill()
	if target < _display_minutes:
		# Loaded an earlier save: snap.
		_apply(target)
		return
	var duration := clampf((target - _display_minutes) / 60.0 * 0.45, 0.35, 3.0)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply, _display_minutes, target, duration)


const SUNRISE_HOUR := 5.0
const SUNSET_HOUR := 21.0


## Returns -1..1: positive while the sun is up (5:00-21:00), negative at night.
static func sun_height_for(minute_of_day: float) -> float:
	var hours := minute_of_day / 60.0
	var day_length := SUNSET_HOUR - SUNRISE_HOUR
	if hours >= SUNRISE_HOUR and hours <= SUNSET_HOUR:
		return sin((hours - SUNRISE_HOUR) / day_length * PI)
	var night := fposmod(hours - SUNSET_HOUR, 24.0) / (24.0 - day_length)
	return -sin(night * PI)


func _apply(total_minutes: float) -> void:
	_display_minutes = total_minutes
	var minute_of_day := fposmod(total_minutes, 1440.0)
	var height := sun_height_for(minute_of_day)
	var daylight := smoothstep(-0.08, 0.3, height)
	var twilight := 1.0 - smoothstep(0.0, 0.35, absf(height))

	if sun:
		if height > -0.05:
			var day_t := clampf((minute_of_day / 60.0 - SUNRISE_HOUR) / (SUNSET_HOUR - SUNRISE_HOUR), 0.0, 1.0)
			var elevation := deg_to_rad(lerpf(4.0, 62.0, maxf(height, 0.0)))
			var azimuth := deg_to_rad(lerpf(95.0, -95.0, day_t))
			sun.rotation = Vector3(-elevation, azimuth, 0.0)
		else:
			# Moonlight from a fixed, gentle angle.
			sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-25.0), 0.0)
		var day_color := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.68, 0.42), twilight)
		var moon_color := Color(0.55, 0.65, 1.0)
		sun.light_color = moon_color.lerp(day_color, daylight)
		sun.light_energy = lerpf(night_light_energy, day_sun_energy, daylight) * lerpf(1.0, 0.32, _overcast)

	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_energy = lerpf(0.35, 1.0, daylight) * lerpf(1.0, 0.85, _overcast)
		if _base_fog_density < 0.0:
			_base_fog_density = env.fog_density
		env.fog_density = _base_fog_density * lerpf(1.0, 2.4, _overcast)
		var sky_material := env.sky.sky_material as ShaderMaterial if env.sky else null
		if sky_material:
			var top_day := Color(0.36, 0.6, 0.86)
			var horizon_day := Color(0.74, 0.86, 0.93)
			var top_night := Color(0.04, 0.06, 0.16)
			var horizon_night := Color(0.11, 0.14, 0.27)
			var horizon_dusk := Color(0.98, 0.66, 0.48)
			# Rain clouds: soft blue-grey instead of blue.
			top_day = top_day.lerp(Color(0.5, 0.56, 0.63), _overcast)
			horizon_day = horizon_day.lerp(Color(0.68, 0.72, 0.76), _overcast)
			var top := top_night.lerp(top_day, daylight)
			var horizon := horizon_night.lerp(horizon_day, daylight).lerp(horizon_dusk, twilight * 0.75 * (1.0 - _overcast * 0.7))
			sky_material.set_shader_parameter("sky_top_color", top)
			sky_material.set_shader_parameter("sky_horizon_color", horizon)
			sky_material.set_shader_parameter("ground_bottom_color", top_night.lerp(Color(0.2, 0.3, 0.38), daylight))
			sky_material.set_shader_parameter("sky_energy", lerpf(0.55, 1.0, daylight))
			sky_material.set_shader_parameter("overcast", _overcast)
			var cream := Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.72, 0.52), twilight * 0.7)
			var shade := Color(0.65, 0.75, 0.85).lerp(Color(0.68, 0.53, 0.65), twilight * 0.65)
			cream = cream.lerp(Color(0.68, 0.72, 0.77), _overcast)
			shade = shade.lerp(Color(0.4, 0.46, 0.55), _overcast)
			sky_material.set_shader_parameter("cloud_light", Color(0.19, 0.24, 0.38).lerp(cream, maxf(daylight, twilight * 0.65)))
			sky_material.set_shader_parameter("cloud_shadow", Color(0.07, 0.1, 0.2).lerp(shade, daylight))
		env.fog_light_color = Color(0.12, 0.15, 0.26).lerp(Color(0.72, 0.82, 0.9).lerp(Color(0.62, 0.66, 0.7), _overcast), daylight).lerp(Color(0.95, 0.7, 0.55), twilight * 0.5 * (1.0 - _overcast))
