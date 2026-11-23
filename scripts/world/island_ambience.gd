class_name IslandAmbience
extends Node
## The island's background sound. Looping layers (surf, lake, wind, birds, crickets,
## frogs, rain) fade in and out with where the player is, the time of day and the
## weather; a few one-off sounds (wind chimes in the village, gulls on the coast, an owl
## in the forest at night) play now and then. Placed speakers add the village's story
## sounds: market music and chatter once the market reopens (Chapter 3), and a soft hum
## from the well while it glows; in the finale, the Moonwell's shimmer under the lake
## (fuller with every Glowstone shard) and the lit lighthouse's hum, which swells as
## the beam sweeps past, with ships' horns far out at sea. Each season reshapes the mix (see SEASONS), and
## falling snow softens everything.
##
## Weather: rain patters everywhere, plinks on the lake and the sea, drips heavily from
## the forest canopy and drums on the roof when you're indoors; summer and autumn rain
## brings far-off, gentle thunder; when the rain stops the island drips for a while.
## Cloudy and blustery days (and high ground) bring gusts of wind; falling snow brings a
## soft whistle of air and now and then snow sliding off a branch or a roof.
##
## Everything plays on the "Ambience" bus (from default_bus_layout.tres; created here if
## missing), which sends to Master, so the Ambience and Master volume settings cover it. Indoors, a low-pass on that bus muffles the
## outside. During the opening scene the ambience stays silent, then fades in.
## Sound only: it never touches the ActivityClock.
## The sounds are synthesised by tools/generate_ambient_audio.py and
## tools/generate_village_audio.py.

const DIR := "res://assets/audio/ambience/"
const OPENING_DIR := "res://assets/audio/opening/"
const BUS := &"Ambience"
## The outdoor sounds go through this bus (created here, it sends to Ambience) so that
## indoors they can be muffled while the rain on the roof stays crisp.
const OUTDOOR_BUS := &"AmbienceOutdoors"
## Looping layers and their loudness (dB) at full level.
const LAYERS := {
	&"coast_waves": -3.0,
	&"lake_lap": -7.0,
	&"wind": -13.0,
	&"birds_day": -8.0,
	&"crickets": -15.0,
	&"frogs": -12.0,
	&"rain": -4.0,
	&"cicadas": -17.0,
	&"leaves": -13.0,
	&"rain_roof": -8.0,
	&"rain_water": -9.0,
	&"rain_leaves": -7.0,
	&"drips": -12.0,
	&"snow_wind": -14.0,
}
## Heard indoors, on the unmuffled Ambience bus.
const INDOOR_LAYERS: Array[StringName] = [&"rain_roof"]
## After the rain stops the island keeps dripping for this long (real seconds).
const AFTER_RAIN_TIME := 90.0
## Seasons whose rain brings far-off thunder (spring showers are gentle).
const THUNDER_SEASONS: Array[StringName] = [&"summer", &"autumn"]
## How each season reshapes the layers: multipliers, plus extra wind.
## Spring: lively birds and frogs. Summer: crickets at night, cicadas by day.
## Autumn: fewer birds, rustling dry leaves, more wind. Winter: no insects or frogs,
## a few hardy birds, colder wind, a quieter lake. Snow hushes everything.
const SEASONS := {
	&"spring": {&"birds": 1.15, &"crickets": 0.5, &"frogs": 1.2, &"cicadas": 0.0, &"leaves": 0.0, &"wind": 0.0, &"lake": 1.0},
	&"summer": {&"birds": 1.0, &"crickets": 1.0, &"frogs": 1.0, &"cicadas": 1.0, &"leaves": 0.0, &"wind": 0.0, &"lake": 1.0},
	&"autumn": {&"birds": 0.55, &"crickets": 0.45, &"frogs": 0.35, &"cicadas": 0.0, &"leaves": 1.0, &"wind": 0.2, &"lake": 1.0},
	&"winter": {&"birds": 0.25, &"crickets": 0.0, &"frogs": 0.0, &"cicadas": 0.0, &"leaves": 0.0, &"wind": 0.3, &"lake": 0.6},
}
const SNOW_CUTOFF := 3200.0     # falling snow softens every outdoor sound
## One-off sounds: [file, loudness dB, shortest gap s, longest gap s].
const ONE_SHOTS := {
	&"chimes": [OPENING_DIR + "chimes.wav", -17.0, 12.0, 26.0],
	&"gulls": [OPENING_DIR + "gulls.wav", -13.0, 14.0, 30.0],
	&"owl": [DIR + "owl.wav", -9.0, 18.0, 40.0],
	# Once the lighthouse shines, ships come back: a far-off horn at night on the coast.
	&"ship_horn": [OPENING_DIR + "horn.wav", -21.0, 60.0, 130.0],
	# Weather.
	&"thunder": [DIR + "thunder.wav", -13.0, 35.0, 90.0],
	&"wind_gust": [DIR + "wind_gust.wav", -13.0, 18.0, 45.0],
	&"snow_whump": [DIR + "snow_whump.wav", -11.0, 15.0, 40.0],
}
## Sounds that come from a place in the world (they get louder as you walk closer).
## name -> [file, bus, loudness dB, position, unit size m, max distance m]
## The market (story flag ch3_market_day) plays by day; the well hums while it glows
## (ch3_well_glow, until shard_3 is taken).
const SPOTS := {
	&"market_music": ["market_tune.wav", &"Music", -6.0, Vector3(3.0, 5.0, 117.0), 9.0, 75.0],
	&"chatter_square": ["market_chatter.wav", &"Ambience", -8.0, Vector3(-4.0, 5.0, 111.0), 7.0, 50.0],
	&"chatter_inn": ["market_chatter.wav", &"Ambience", -11.0, Vector3(-29.0, 5.0, 120.0), 5.0, 40.0],
	&"well_hum": ["well_hum.wav", &"Ambience", -7.0, Vector3(0.0, 4.6, 115.0), 3.0, 28.0],
	# The finale's lights (positions are moved onto the real nodes when they exist).
	&"moonwell": ["moonwell.wav", &"Ambience", -6.0, Vector3(-1.5, 3.4, -3.5), 14.0, 90.0],
	&"lighthouse": ["lighthouse_hum.wav", &"Ambience", -4.0, Vector3(172.0, 30.3, -92.0), 18.0, 160.0],
	# Restored buildings come back to life (each placed on its building, see BUILDINGS).
	&"windmill_turn": ["windmill_turn.wav", &"Ambience", -7.0, Vector3(140.0, 11.0, 48.0), 8.0, 70.0],
	&"greenhouse_mist": ["greenhouse_mist.wav", &"Ambience", -9.0, Vector3(119.0, 7.0, 87.0), 3.0, 22.0],
	&"inn_fire": ["inn_fire.wav", &"Ambience", -8.0, Vector3(-32.0, 5.5, 122.0), 3.0, 25.0],
	&"boathouse_ropes": ["boathouse_ropes.wav", &"Ambience", -8.0, Vector3(-14.8, 4.0, 44.6), 4.0, 35.0],
	&"workshop": ["workshop.wav", &"Ambience", -8.0, Vector3(-98.0, 5.0, 36.0), 5.0, 40.0],
}
## Restored buildings' sounds of life: spot -> [story flag, building node (under main),
## height above it]. Silent until the building is restored.
const BUILDINGS := {
	&"windmill_turn": [&"restored_windmill", ^"Island/StoryPlaces/Farm/Windmill", 6.0],
	&"greenhouse_mist": [&"restored_greenhouse", ^"Island/Buildings/FarmField/Greenhouse", 1.5],
	&"inn_fire": [&"restored_inn", ^"Island/StoryPlaces/Village/Inn", 1.5],
	&"boathouse_ropes": [&"restored_boathouse", ^"Island/StoryPlaces/Lake/Boathouse", 0.5],
	# Theo's workshop opens once the bridge is rebuilt.
	&"workshop": [&"restored_bridge", ^"Island/StoryPlaces/Forest/Workshop", 1.5],
}
## Without a LighthouseBeam node, the hum sits this far above the lighthouse building.
const LIGHTHOUSE_LAMP_HEIGHT := 26.0
## The lighthouse hum swells each time the turning beam points towards you.
const BEAM_SWELL_SHARPNESS := 10.0
const MARKET_FLAG := &"ch3_market_day"
const WELL_GLOW_FLAG := &"ch3_well_glow"
const WELL_SHARD_FLAG := &"shard_3"
const VILLAGE_SQUARE := Vector2(0.0, 115.0)
const UPDATE_EVERY := 0.25
const FOLLOW_SPEED := 1.1      # how quickly layers follow their targets (per second)
const FADE_IN_TIME := 4.0      # after the opening, or when the island loads
const INDOOR_LEVEL := 0.4
const INDOOR_CUTOFF := 650.0
const OUTDOOR_CUTOFF := 20000.0
const UKULELE_DUCK := 0.55
## The ambience dips to this while a story moment's music plays (StorySounds).
const STORY_DUCK := 0.45
const DUCK_SPEED := 2.5

var _duck: float = 1.0
var _players := {}             # layer -> AudioStreamPlayer
var _spots := {}               # spot -> AudioStreamPlayer3D
var _beam: Node3D              # the lighthouse's LighthouseBeam, if the island has one
var _moonwell: Node3D          # the MoonwellGlow under the lake, if any
var _player: Node3D
var _targets := {}             # layer -> 0..1
var _levels := {}              # layer -> 0..1 (smoothed)
var _shot_timers := {}
var _master: float = 0.0
var _indoors: bool = false
var _snowing: bool = false
var _after_rain: float = 0.0   # 1 while raining, then fades out: the island drips
var _timer: float = 0.0
var _lowpass: AudioEffectLowPassFilter
var _cutoff: float = OUTDOOR_CUTOFF
var _rng := RandomNumberGenerator.new()
## The last one-off sound played (for checks).
var last_one_shot: StringName = &""


func _ready() -> void:
	name = "Ambience"
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps breathing softly under the pause menu
	_rng.randomize()
	_ensure_bus()
	for layer: StringName in LAYERS:
		var path := DIR + str(layer) + ".wav"
		if not ResourceLoader.exists(path):
			continue
		var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.name = str(layer)
		player.stream = stream
		player.bus = BUS if layer in INDOOR_LAYERS else OUTDOOR_BUS
		player.volume_db = -80.0
		add_child(player)
		# Start each loop somewhere different so they never line up.
		player.play(_rng.randf() * stream.get_length())
		_players[layer] = player
		_targets[layer] = 0.0
		_levels[layer] = 0.0
	for spot: StringName in SPOTS:
		var def: Array = SPOTS[spot]
		var path: String = DIR + def[0]
		if not ResourceLoader.exists(path):
			continue
		var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var speaker := AudioStreamPlayer3D.new()
		speaker.name = str(spot)
		speaker.stream = stream
		var spot_bus: StringName = OUTDOOR_BUS if def[1] == BUS else def[1]
		speaker.bus = spot_bus if AudioServer.get_bus_index(spot_bus) >= 0 else OUTDOOR_BUS
		speaker.unit_size = def[4]
		speaker.max_distance = def[5]
		speaker.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		speaker.panning_strength = 0.6
		speaker.volume_db = -80.0
		add_child(speaker)
		speaker.global_position = def[3]
		speaker.play(_rng.randf() * stream.get_length())
		speaker.stream_paused = true  # wakes up when its story moment arrives
		_spots[spot] = speaker
		_targets[spot] = 0.0
		_levels[spot] = 0.0
	for shot: StringName in ONE_SHOTS:
		_shot_timers[shot] = _rng.randf_range(4.0, float(ONE_SHOTS[shot][3]))
	_find_story_lights()
	update_targets()


## How loud a layer wants to be right now (0..1, before indoor and fade adjustments).
func get_target(layer: StringName) -> float:
	return _targets.get(layer, 0.0)


func get_level(layer: StringName) -> float:
	return _levels.get(layer, 0.0)


func is_indoors() -> bool:
	return _indoors


func get_master() -> float:
	return _master


func get_cutoff() -> float:
	return _cutoff


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_EVERY
		update_targets()
	# Fade the whole ambience in (silent while the opening plays).
	var want := 0.0 if _opening_running() else 1.0
	_master = move_toward(_master, want, delta / FADE_IN_TIME)
	# Dip for the ukulele and for the story's musical moments (StorySounds), smoothly.
	var duck_target := minf(UKULELE_DUCK if _ukulele_playing() else 1.0, STORY_DUCK if _story_playing() else 1.0)
	_duck = move_toward(_duck, duck_target, delta * DUCK_SPEED)
	var duck := _duck
	if WeatherManager.is_raining():
		_after_rain = 1.0
	else:
		_after_rain = move_toward(_after_rain, 0.0, delta / AFTER_RAIN_TIME)
	var follow := 1.0 - exp(-FOLLOW_SPEED * delta)
	for layer: StringName in _players:
		var target: float = _targets[layer]
		if _indoors and not layer in INDOOR_LAYERS:
			target *= 0.75 if layer == &"rain" else INDOOR_LEVEL
		_levels[layer] = lerpf(_levels[layer], target, follow)
		var player := _players[layer] as AudioStreamPlayer
		player.volume_db = float(LAYERS[layer]) + _db(_levels[layer] * _master * duck)
	for spot: StringName in _spots:
		_levels[spot] = lerpf(_levels[spot], _targets[spot], follow)
		var speaker := _spots[spot] as AudioStreamPlayer3D
		var level: float = _levels[spot] * _master * (duck if SPOTS[spot][1] == &"Music" else 1.0)
		if spot == &"lighthouse":
			level *= beam_swell()
		speaker.volume_db = float(SPOTS[spot][2]) + _db(level)
		# Silent speakers rest (saves mixing work); they pick up where they paused.
		speaker.stream_paused = level < 0.002
	# Indoors the outside sounds muffled.
	var cutoff_target := INDOOR_CUTOFF if _indoors else (SNOW_CUTOFF if _snowing else OUTDOOR_CUTOFF)
	_cutoff = lerpf(_cutoff, cutoff_target, follow * 2.0)
	if _lowpass:
		_lowpass.cutoff_hz = _cutoff
	_update_one_shots(delta, duck)


## Works out every layer's target from the player's surroundings, the time and weather.
func update_targets() -> void:
	_update_spot_targets()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_player = player
	if player == null:
		return
	var p := player.global_position
	var shape := IslandShape.shared()
	_indoors = InteriorRoom.is_indoors(get_tree(), p)
	_targets[&"rain_roof"] = 1.0 if _indoors and WeatherManager.is_raining() else 0.0
	if _indoors:
		# Indoors, the layers keep whatever the outside sounds like at the house.
		return
	var minute := float(ActivityClock.get_minute_of_day()) / 60.0
	var day := smoothstep(4.5, 5.75, minute) * (1.0 - smoothstep(19.5, 20.5, minute))
	var night := 1.0 - day
	var rain := 1.0 if WeatherManager.is_raining() else 0.0
	_snowing = WeatherManager.has_method(&"is_snowing") and WeatherManager.call(&"is_snowing")
	var snow := 1.0 if _snowing else 0.0
	var season: Dictionary = SEASONS.get(ActivityClock.get_season_id(), SEASONS[&"summer"])
	var sea := sea_nearby(p)
	var lake := 1.0 - smoothstep(5.0, 45.0, Vector2(p.x, p.z).distance_to(IslandShape.LAKE_CENTER) - IslandShape.LAKE_RADIUS * 0.85)
	var forest := 1.0 if GameManager.current_region_id == &"fernwood_forest" else 0.0
	var ground := shape.get_height(p.x, p.z)
	var high := clampf((ground - 8.0) / 25.0, 0.0, 1.0)
	_targets[&"coast_waves"] = sea * (1.0 - 0.25 * snow)
	_targets[&"lake_lap"] = lake * 0.9 * float(season[&"lake"]) * (1.0 - 0.5 * snow)
	var cloudy := 1.0 if WeatherManager.current == WeatherManager.Weather.CLOUDY else 0.0
	_targets[&"wind"] = clampf(0.3 + 0.4 * high + 0.25 * sea + 0.35 * rain + 0.15 * cloudy + float(season[&"wind"]) + 0.15 * snow, 0.0, 1.0)
	_targets[&"birds_day"] = day * (0.45 + 0.55 * forest) * (1.0 - 0.75 * rain) * (1.0 - 0.7 * snow) * float(season[&"birds"])
	_targets[&"crickets"] = night * (1.0 - 0.6 * sea) * (1.0 - 0.6 * rain) * float(season[&"crickets"])
	_targets[&"frogs"] = night * lake * (1.0 - 0.4 * rain) * float(season[&"frogs"])
	_targets[&"rain"] = rain
	_targets[&"cicadas"] = day * (1.0 - 0.7 * sea) * (1.0 - rain) * (0.6 + 0.4 * forest) * float(season[&"cicadas"])
	_targets[&"leaves"] = (0.45 + 0.55 * forest) * (1.0 - 0.5 * rain) * float(season[&"leaves"])
	_targets[&"village"] = (1.0 - smoothstep(25.0, 60.0, Vector2(p.x, p.z).distance_to(VILLAGE_SQUARE))) * day
	_targets[&"forest_night"] = forest * night
	_targets[&"coast_day"] = (1.0 if sea > 0.4 else 0.0) * day * (1.0 - rain)
	# Weather.
	_targets[&"rain_water"] = rain * maxf(lake, sea) * (1.0 - 0.5 * forest)
	_targets[&"rain_leaves"] = rain * forest
	_targets[&"drips"] = (1.0 - rain) * _after_rain * (0.5 + 0.5 * forest)
	_targets[&"snow_wind"] = snow * (0.6 + 0.4 * high)
	_targets[&"thunder_day"] = rain if ActivityClock.get_season_id() in THUNDER_SEASONS else 0.0
	_targets[&"gusty"] = 1.0 if _targets[&"wind"] > 0.6 or cloudy > 0.0 else 0.0
	# Snow slides off branches in the forest and off roofs in the village.
	var near_village := 1.0 - smoothstep(25.0, 60.0, Vector2(p.x, p.z).distance_to(VILLAGE_SQUARE))
	_targets[&"snow_places"] = snow if forest > 0.0 or near_village > 0.3 else 0.0


## The village's story sounds: the market once it has reopened, the glowing well's hum.
func _update_spot_targets() -> void:
	var hour := float(ActivityClock.get_minute_of_day()) / 60.0
	var market := 1.0 if GameManager.has_flag(MARKET_FLAG) else 0.0
	var rain := 1.0 if WeatherManager.is_raining() else 0.0
	var music_hours := smoothstep(7.0, 7.5, hour) * (1.0 - smoothstep(21.0, 21.5, hour))
	var chatter_hours := smoothstep(8.0, 8.5, hour) * (1.0 - smoothstep(20.0, 20.5, hour))
	_targets[&"market_music"] = market * music_hours * (1.0 - 0.4 * rain)
	_targets[&"chatter_square"] = market * chatter_hours * (1.0 - 0.7 * rain)
	# The inn stays lively into the evening.
	_targets[&"chatter_inn"] = market * smoothstep(8.0, 8.5, hour) * (1.0 - smoothstep(22.5, 23.0, hour))
	var glowing := GameManager.has_flag(WELL_GLOW_FLAG) and not GameManager.has_flag(WELL_SHARD_FLAG)
	_targets[&"well_hum"] = 1.0 if glowing else 0.0
	# The Moonwell sings as it glows (at night): faint at first, fuller with every shard.
	var moon := 0.0
	if is_instance_valid(_moonwell) and _moonwell.visible and _moonwell.has_method(&"get_target_energy"):
		moon = clampf(float(_moonwell.call(&"get_target_energy")) / float(_moonwell.get(&"lit_energy")), 0.12, 1.0)
	_targets[&"moonwell"] = moon
	var shining := is_instance_valid(_beam) and _beam.has_method(&"is_shining") and bool(_beam.call(&"is_shining"))
	_targets[&"lighthouse"] = 1.0 if shining else 0.0
	# Restored buildings: the windmill turns and the boathouse ropes creak all the time;
	# the greenhouse mists by day; the inn's fire burns mornings, evenings and rainy days;
	# Theo saws and hammers in his workshop during the working day.
	var day := smoothstep(6.0, 6.5, hour) * (1.0 - smoothstep(20.0, 20.5, hour))
	var fire := maxf(maxf(1.0 - smoothstep(9.0, 9.5, hour), smoothstep(17.0, 17.5, hour)), rain)
	var work := smoothstep(8.5, 9.0, hour) * (1.0 - smoothstep(17.5, 18.0, hour))
	var when := {&"windmill_turn": 1.0, &"boathouse_ropes": 1.0, &"greenhouse_mist": day, &"inn_fire": fire, &"workshop": work}
	for spot: StringName in BUILDINGS:
		_targets[spot] = float(when[spot]) if GameManager.has_flag(BUILDINGS[spot][0]) else 0.0


## 0.5..1: louder while the lighthouse beam points towards the player.
func beam_swell() -> float:
	if not is_instance_valid(_beam) or not is_instance_valid(_player):
		return 1.0
	var arm := _beam.get_node_or_null(^"Arm") as Node3D
	if arm == null:
		return 1.0
	var facing := -arm.global_basis.z
	var to_player := _player.global_position - _beam.global_position
	facing.y = 0.0
	to_player.y = 0.0
	if facing.length_squared() < 0.0001 or to_player.length_squared() < 0.0001:
		return 1.0
	# Two cones back to back, so either end sweeping past counts.
	var align := absf(facing.normalized().dot(to_player.normalized()))
	return 0.5 + 0.5 * pow(align, BEAM_SWELL_SHARPNESS)


## Finds the lighthouse beam and the Moonwell on the island and puts their speakers there.
func _find_story_lights() -> void:
	var root := get_parent() if get_parent() else get_tree().root
	for node in root.find_children("*", "Node3D", true, false):
		if node is LighthouseBeam and _beam == null:
			_beam = node as Node3D
		elif node is MoonwellGlow and _moonwell == null:
			_moonwell = node as Node3D
	if _spots.has(&"lighthouse"):
		# On the lamp (the beam); without one, at the top of the lighthouse building.
		var tower := root.get_node_or_null(^"Island/Buildings/Lighthouse") as Node3D
		if _beam:
			(_spots[&"lighthouse"] as Node3D).global_position = _beam.global_position
		elif tower:
			(_spots[&"lighthouse"] as Node3D).global_position = tower.global_position + Vector3.UP * LIGHTHOUSE_LAMP_HEIGHT
	for spot: StringName in BUILDINGS:
		var building := root.get_node_or_null(BUILDINGS[spot][1]) as Node3D
		if building and _spots.has(spot):
			(_spots[spot] as Node3D).global_position = building.global_position + Vector3.UP * float(BUILDINGS[spot][2])
	if _moonwell and _spots.has(&"moonwell"):
		var p := _moonwell.global_position
		(_spots[&"moonwell"] as Node3D).global_position = Vector3(p.x, IslandShape.LAKE_LEVEL + 0.3, p.z)


## 0..1: how much open sea there is around a point (samples rings of the terrain).
func sea_nearby(p: Vector3) -> float:
	var shape := IslandShape.shared()
	var total := 0.0
	var weight := 0.0
	for ring: Vector2 in [Vector2(14.0, 1.0), Vector2(32.0, 0.6), Vector2(65.0, 0.3)]:
		for i in 12:
			var a := TAU * i / 12.0
			var x := p.x + cos(a) * ring.x
			var z := p.z + sin(a) * ring.x
			if shape.get_height(x, z) < IslandShape.SEA_LEVEL - 0.2:
				total += ring.y
			weight += ring.y
	return clampf(total / weight * 2.2, 0.0, 1.0)


func _update_one_shots(delta: float, duck: float) -> void:
	if _master < 0.5:
		return
	var wants := {&"chimes": _targets.get(&"village", 0.0) > 0.5, &"gulls": _targets.get(&"coast_day", 0.0) > 0.5,
		&"owl": _targets.get(&"forest_night", 0.0) > 0.5,
		&"ship_horn": _targets.get(&"lighthouse", 0.0) > 0.5 and _targets.get(&"coast_waves", 0.0) > 0.3,
		&"thunder": _targets.get(&"thunder_day", 0.0) > 0.5, &"wind_gust": _targets.get(&"gusty", 0.0) > 0.5,
		&"snow_whump": _targets.get(&"snow_places", 0.0) > 0.5}
	for shot: StringName in ONE_SHOTS:
		_shot_timers[shot] -= delta
		if _shot_timers[shot] > 0.0:
			continue
		var def: Array = ONE_SHOTS[shot]
		_shot_timers[shot] = _rng.randf_range(def[2], def[3])
		# Indoors only the thunder carries in (muffled by the walls).
		if not wants[shot] or (_indoors and shot != &"thunder") or not ResourceLoader.exists(def[0]):
			continue
		last_one_shot = shot
		var player := AudioStreamPlayer.new()
		player.stream = load(def[0]) as AudioStream
		player.bus = OUTDOOR_BUS
		player.volume_db = float(def[1]) + _db(_master * duck) + _rng.randf_range(-3.0, 1.0)
		player.pitch_scale = _rng.randf_range(0.94, 1.06)
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)


func _ensure_bus() -> void:
	var index := AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
	# The Ambience bus's own filter (from the bus layout) stays wide open; the muffling
	# happens on the outdoor bus below.
	for i in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, i) as AudioEffectLowPassFilter
		if effect:
			effect.cutoff_hz = OUTDOOR_CUTOFF
	var outdoor := AudioServer.get_bus_index(OUTDOOR_BUS)
	if outdoor < 0:
		AudioServer.add_bus()
		outdoor = AudioServer.bus_count - 1
		AudioServer.set_bus_name(outdoor, OUTDOOR_BUS)
	AudioServer.set_bus_send(outdoor, BUS)
	for i in AudioServer.get_bus_effect_count(outdoor):
		if AudioServer.get_bus_effect(outdoor, i) is AudioEffectLowPassFilter:
			_lowpass = AudioServer.get_bus_effect(outdoor, i) as AudioEffectLowPassFilter
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = OUTDOOR_CUTOFF
		AudioServer.add_bus_effect(outdoor, _lowpass)


func _opening_running() -> bool:
	var opening := get_parent().get_node_or_null(^"OpeningScene") if get_parent() else null
	return opening != null and opening.has_method(&"is_running") and opening.call(&"is_running")


func _story_playing() -> bool:
	var story := get_node_or_null(^"/root/StorySounds")
	return story != null and story.has_method(&"is_playing") and story.call(&"is_playing")


## How far the ambience is dipped right now (1 = not at all).
func get_duck() -> float:
	return _duck


func _ukulele_playing() -> bool:
	var uke := get_tree().get_first_node_in_group(&"ukulele_controller")
	return uke != null and uke.has_method(&"is_playing") and uke.call(&"is_playing")


static func _db(level: float) -> float:
	return linear_to_db(maxf(level, 0.0001))
