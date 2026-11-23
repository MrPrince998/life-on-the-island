class_name GameSettings
extends RefCounted
## Player options shared by the main menu and the pause menu: mouse sensitivity,
## volumes and full screen. Kept in user://settings.cfg (separate from save games).
##
## Volumes: Master covers everything; Music, Ambience and Effects are the audio buses
## of the same names (default_bus_layout.tres), which all send to Master.

const PATH := "user://settings.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 2.5

## Multiplier on the camera's base mouse sensitivity (1.0 = default).
static var mouse_sensitivity: float = 1.0
## 0.0 (silent) to 1.0 (full).
static var master_volume: float = 0.8
static var music_volume: float = 0.8
static var ambience_volume: float = 0.8
static var effects_volume: float = 0.9
static var fullscreen: bool = false

static var _loaded := false


## Loads the settings once per run and applies them. Safe to call from any scene.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	load_from(PATH)
	apply()


static func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", 1.0)), MIN_SENSITIVITY, MAX_SENSITIVITY)
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.8)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience_volume", 0.8)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value("audio", "effects_volume", 0.9)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))


static func save_to(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.set_value("audio", "effects_volume", effects_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	return cfg.save(path)


static func reset_to_defaults() -> void:
	mouse_sensitivity = 1.0
	master_volume = 0.8
	music_volume = 0.8
	ambience_volume = 0.8
	effects_volume = 0.9
	fullscreen = false


## Pushes the current values to the engine (volume, window mode). The camera reads
## mouse_sensitivity directly every time the mouse moves.
static func apply() -> void:
	_set_bus(&"Master", master_volume)
	_set_bus(&"Music", music_volume)
	_set_bus(&"Ambience", ambience_volume)
	_set_bus(&"Effects", effects_volume)
	if DisplayServer.get_name() == "headless":
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted:
		DisplayServer.window_set_mode(wanted)


## Volume (0..1) for a bus by name: &"Master", &"Music", &"Ambience" or &"Effects".
static func get_volume(bus_name: StringName) -> float:
	match bus_name:
		&"Music":
			return music_volume
		&"Ambience":
			return ambience_volume
		&"Effects":
			return effects_volume
	return master_volume


static func set_volume(bus_name: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus_name:
		&"Music":
			music_volume = value
		&"Ambience":
			ambience_volume = value
		&"Effects":
			effects_volume = value
		_:
			master_volume = value


static func _set_bus(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
