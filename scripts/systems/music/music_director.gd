extends Node
## MusicDirector (autoload): the background music, on the Music bus (Settings' music slider).
##
## Picks a track for the moment and crossfades when it changes:
##   title screen -> title_theme        the finale and credits -> finale
##   in the world -> the region's track (village, fields, plains, lake & forest...)
##   ...unless a time / weather / season track fits better and exists: night, evening,
##   rain, winter (missing tracks just fall back to the region's).
## The opening scene has its own music, so the director stays silent then.
##
## In the world a track plays once, then there's a quiet rest (only the island's ambience)
## before the next, so the music never wears thin over a long session. The music dips
## while you chat with a villager and fades out while you play Grandpa's ukulele.
## Purely presentation: never changes game state or time.

## Track files (Suno, made by the user). Missing ones are simply skipped.
const MUSIC_DIR := "res://source_assets/music/"
## Per-track loudness trim (dB) so the Suno masters sit at the same level.
const TRACK_GAIN := {
	&"title_theme": -0.6, &"village_day": 0.4, &"fields_day": -0.1, &"amber_plains": -0.4,
	&"lake_forest": 1.2, &"finale": -0.9,
}
## Region id -> track.
const REGION_TRACK := {
	&"willowbrook_village": &"village_day",
	&"sunflower_fields": &"fields_day",
	&"amber_plains": &"amber_plains",
	&"moonlit_lake": &"lake_forest",
	&"fernwood_forest": &"lake_forest",
	&"whispering_coast": &"lake_forest",
	&"northern_hills": &"amber_plains",
}
const DEFAULT_TRACK := &"village_day"

## Overall levels (dB) before the Music bus slider: quiet under the world's sounds,
## fuller on the title screen and in the finale.
const WORLD_DB := -11.0
const TITLE_DB := -6.0
const FINALE_DB := -5.0
## Dips during a conversation; out while playing the ukulele.
const TALK_DUCK_DB := -7.0
## Dips under StorySounds' short jingles so they're heard.
const STING_DUCK_DB := -8.0
const SILENT_DB := -60.0
const CROSSFADE := 3.0
## How fast the playing track's volume follows its target (dB per second): a fade-in
## from silence takes about 3 seconds.
const FADE_SPEED := 16.0
const FADE_OUT := 2.0
## Quiet gap between world tracks (seconds, random within).
const REST_SECONDS := Vector2(25.0, 55.0)
## How often the director looks round (seconds).
const CHECK_EVERY := 0.25

enum Mode { SILENT, TITLE, WORLD, FINALE }

var mode: int = Mode.SILENT
var _players: Array[AudioStreamPlayer] = []
var _fade_outs: Array[Tween] = [null, null]
var _active := 0
var _current: StringName = &""
var _resting := false
var _rest_left := 0.0
var _check_left := 0.0
var _duck_db := 0.0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)


# ---- Queries (tests, debugging) -------------------------------------------------

func get_current_track() -> StringName:
	return _current


func is_resting() -> bool:
	return _resting


func has_track(track: StringName) -> bool:
	return _stream(track) != null


## The track that fits right now (&"" for silence).
func pick_track() -> StringName:
	match mode:
		Mode.TITLE:
			return _first([&"title_theme"])
		Mode.FINALE:
			return _first([&"finale", &"title_theme"])
		Mode.WORLD:
			var region: StringName = REGION_TRACK.get(GameManager.current_region_id, DEFAULT_TRACK)
			var hour := ActivityClock.get_hour()
			var options: Array[StringName] = []
			if hour >= 22 or hour < 5:
				options.append_array([&"night", &"lake_forest"])
			if WeatherManager.is_raining():
				options.append(&"rain")
			if hour >= 18 and hour < 22:
				options.append(&"evening")
			if ActivityClock.get_season_id() == &"winter":
				options.append(&"winter")
			options.append(region)
			options.append(DEFAULT_TRACK)
			return _first(options)
	return &""


## The volume (dB, before the slider) the music should be at now.
func target_db() -> float:
	var base := WORLD_DB
	match mode:
		Mode.TITLE:
			base = TITLE_DB
		Mode.FINALE:
			base = FINALE_DB
		Mode.SILENT:
			return SILENT_DB
	return base + float(TRACK_GAIN.get(_current, 0.0)) + _duck_db


# ---- Running -------------------------------------------------------------------

func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_EVERY
		_look_round()
	if _resting:
		_rest_left -= delta
		if _rest_left <= 0.0:
			_resting = false
			_start(pick_track(), CROSSFADE)
	# Ease the playing track toward where it should be (ducking, mode changes).
	var player := _players[_active]
	if player.playing and _current != &"":
		var want := target_db()
		player.volume_db = move_toward(player.volume_db, want, FADE_SPEED * delta)


## Works out the mode and the ducking, and changes track when the fitting one changes.
func _look_round() -> void:
	var new_mode := _detect_mode()
	var duck := 0.0
	if new_mode == Mode.WORLD:
		duck = _detect_duck()
	_duck_db = duck
	var wanted := pick_track() if new_mode == mode else &""
	if new_mode != mode:
		mode = new_mode
		wanted = pick_track()
		_resting = false
		_start(wanted, CROSSFADE)
		return
	if _resting:
		return
	if wanted != _current:
		# A new place (or evening falling): move to its music. In the world, after a
		# short rest if nothing is playing.
		_start(wanted, CROSSFADE)


func _detect_mode() -> int:
	var tree := get_tree()
	var credits := tree.root.get_node_or_null(^"FinaleCredits")
	if credits and credits.has_method(&"is_running") and credits.call(&"is_running"):
		return Mode.FINALE
	var scene := tree.current_scene
	if scene == null:
		return Mode.SILENT
	if scene is TitleScreen:
		return Mode.TITLE
	for child in scene.get_children():
		if child is OpeningScene:
			return Mode.SILENT
	if tree.get_first_node_in_group(&"player") != null:
		return Mode.WORLD
	return Mode.SILENT


func _detect_duck() -> float:
	var ukulele := get_tree().get_first_node_in_group(&"ukulele_controller")
	if ukulele and ukulele.has_method(&"is_playing") and ukulele.call(&"is_playing"):
		return SILENT_DB
	# Story jingles (a building restored, a shard found) play on the Music bus too.
	if StorySounds.has_method(&"is_playing") and StorySounds.call(&"is_playing"):
		return STING_DUCK_DB
	for node in get_tree().get_nodes_in_group(&"villagers"):
		if node.has_method(&"get_mode") and int(node.call(&"get_mode")) == 2:  # Villager.Mode.TALKING
			return TALK_DUCK_DB
	return 0.0


## Crossfades to `track` (&"" fades out to silence).
func _start(track: StringName, fade: float) -> void:
	var old := _players[_active]
	if track == _current and old.playing:
		return
	_cancel_fade(_active)
	if old.playing:
		var out := create_tween()
		_fade_outs[_active] = out
		out.tween_property(old, ^"volume_db", SILENT_DB, fade if track != &"" else FADE_OUT)
		out.tween_callback(old.stop)
	_current = track
	if track == &"":
		return
	_active = 1 - _active
	# This speaker may still have a fade-out scheduled for its previous track.
	_cancel_fade(_active)
	var player := _players[_active]
	player.stop()
	player.stream = _stream(track)
	player.volume_db = SILENT_DB
	player.play()
	# It fades in from silence in _process (and follows ducking the same way).


func _cancel_fade(index: int) -> void:
	var fade := _fade_outs[index]
	if fade != null and fade.is_valid():
		fade.kill()
	_fade_outs[index] = null


func _on_finished(index: int) -> void:
	if index != _active:
		return
	if mode == Mode.WORLD:
		# A quiet rest, then the next track for wherever you are by then.
		_resting = true
		_rest_left = _rng.randf_range(REST_SECONDS.x, REST_SECONDS.y)
		_current = &""
	elif mode != Mode.SILENT:
		_players[_active].play()  # title screen and credits just play on


func _first(options: Array) -> StringName:
	for track: StringName in options:
		if _stream(track) != null:
			return track
	return &""


func _stream(track: StringName) -> AudioStream:
	if track == &"":
		return null
	if not _streams.has(track):
		var path := MUSIC_DIR + String(track) + ".mp3"
		_streams[track] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[track]


## For tests: rest right away (as if the track had ended).
func skip_to_rest() -> void:
	_on_finished(_active)
