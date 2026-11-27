extends Node
## Little pieces of music for the story's big moments (autoload "StorySounds"):
## a glassy shimmer for each Glowstone shard (a step higher with every shard), a music
## box for each page of Grandpa's journal, a "ta-da" of its own for each restored
## building (the market's awnings snap open with a squeeze-box, the windmill groans and
## its sails whoosh round, the bridge's planks thud down over the creek, the greenhouse's
## glass clinks into place, the lighthouse lens rings with its five Glowstones, the inn's
## fire whooshes alight, the boathouse ropes creak to a little shanty), a leafy sparkle when a path is cleared or trees are planted, birdsong and a
## rising chord when the great oak grows back, the market's handbell on Market Day, a
## magical hum when something awakens, a warm fanfare for an important gift (Oliver's
## rod), and a big swell when the lighthouse is lit. (The finale and credits music is
## MusicDirector's.)
##
## It listens for the story flags being set during play (loading a save doesn't set them
## one by one, so loading is silent). While a sting plays, the island's ambience and
## market music dip, and the interface holds back its smaller chimes so they don't
## clash. Stings play on the Music bus. It never changes the game.

signal played(sound: StringName)

const DIR := "res://assets/audio/story/"
const SOUNDS: Array[StringName] = [
	&"shard_found", &"memory_found", &"restored", &"world_change", &"bloom",
	&"market_bell", &"glow", &"lighthouse_lit", &"gift",
	&"restored_market", &"restored_windmill", &"restored_bridge", &"restored_greenhouse",
	&"restored_lighthouse", &"restored_inn", &"restored_boathouse",
]
## When several story moments happen at once (Market Day also reopens the inn and two
## houses), only the most important one plays.
const PRIORITY := {
	&"lighthouse_lit": 100, &"market_bell": 80, &"bloom": 60, &"shard_found": 55, &"gift": 55,
	&"memory_found": 50, &"glow": 40, &"world_change": 30, &"restored": 10,
}
## A building's own restoration sound outranks the moments around it.
const BUILDING_PRIORITY := 70
const FLAG_SOUNDS := {
	&"has_fishing_rod": &"gift",
	&"ch1_hedge_cleared": &"world_change", &"ch1_orchard_planted": &"world_change",
	&"ch2_saplings_planted": &"world_change", &"ch4_rockfall_cleared": &"world_change",
	&"ch2_tree_restored": &"bloom", &"ch3_market_day": &"market_bell",
	&"ch3_well_glow": &"glow", &"finale_lens": &"glow", &"lighthouse_lit": &"lighthouse_lit",
}
const DB := {
	&"shard_found": -7.0, &"memory_found": -8.0, &"restored": -6.0, &"world_change": -8.0,
	&"bloom": -6.0, &"market_bell": -7.0, &"glow": -8.0, &"lighthouse_lit": -4.0, &"gift": -8.0,
}
## Each shard sounds a step higher: D, E, F#, G, A.
const SHARD_STEPS := [0, 2, 4, 5, 7]

var _sting: AudioStreamPlayer
var _streams: Dictionary = {}
## Story moments waiting to be played at the end of this frame: [sound, pitch].
var _pending: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sting = AudioStreamPlayer.new()
	_sting.name = "Sting"
	_sting.bus = &"Music"
	_sting.max_polyphony = 2
	add_child(_sting)
	GameManager.flag_changed.connect(_on_flag_changed)


## The sound a story flag plays when it is set (&"" for none).
static func sound_for_flag(flag: StringName) -> StringName:
	if FLAG_SOUNDS.has(flag):
		return FLAG_SOUNDS[flag]
	var name := String(flag)
	if name.begins_with("shard_"):
		return &"shard_found"
	if name.begins_with("journal_page_"):
		return &"memory_found"
	if name.begins_with("restored_"):
		# Each building has its own; anything else (the village houses) the general one.
		return flag if ResourceLoader.exists(DIR + name + ".wav") else &"restored"
	return &""


func play(sound: StringName, pitch: float = 1.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	_sting.stream = stream
	_sting.volume_db = float(DB.get(sound, -7.0))
	_sting.pitch_scale = pitch
	_sting.play()
	_hush_ui(sound, pitch)
	played.emit(sound)


## Holds back the interface's chimes and blips for the length of the sting.
func _hush_ui(sound: StringName, pitch: float) -> void:
	var stream := _stream(sound)
	var ui := get_node_or_null(^"/root/UISounds")
	if stream and ui and ui.has_method(&"hush"):
		ui.call(&"hush", minf(stream.get_length() / pitch, 3.0))


## True while a story sting is playing (the ambience and the music dip).
func is_playing() -> bool:
	return _sting.playing


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if not value:
		return
	var sound := sound_for_flag(flag)
	if sound == &"":
		return
	var pitch := 1.0
	if sound == &"shard_found":
		var number := String(flag).trim_prefix("shard_").to_int()
		pitch = pow(2.0, float(SHARD_STEPS[clampi(number - 1, 0, SHARD_STEPS.size() - 1)]) / 12.0)
	_pending.append([sound, pitch])
	# Hush the interface's chimes now (it plays its own pending ones before we play ours).
	_hush_ui(sound, pitch)


static func priority_of(sound: StringName) -> int:
	if PRIORITY.has(sound):
		return PRIORITY[sound]
	return BUILDING_PRIORITY if String(sound).begins_with("restored_") else 0


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		var best: Array = _pending[0]
		for entry: Array in _pending:
			if priority_of(entry[0]) > priority_of(best[0]):
				best = entry
		_pending.clear()
		play(best[0], best[1])


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		_streams[sound] = load(DIR + String(sound) + ".wav") as AudioStream
	return _streams[sound]
