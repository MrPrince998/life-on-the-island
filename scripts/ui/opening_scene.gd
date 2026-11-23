class_name OpeningScene
extends Node
## "A Letter from Grandpa": the opening shown once, right after New game
## (docs/features/opening-scene/design.md).
##
## The mail boat brings the player in at dawn while the camera drifts over the island
## and Grandpa Elias's letter appears line by line. It ends at the beach jetty, where the
## camera swings behind the player and they take control. Holding any key or mouse
## button for a second skips it.
##
## Presentation only: no in-game time passes (the ActivityClock is never touched), and
## everything runs from one timeline (_t), so skipping just moves the timeline on.
##
## The main scene starts it with begin(main). It uses these nodes when they exist and
## falls back to sensible stand-ins when they don't:
##   BeachJetty/MailBoat       (the boat, -Z = bow; a rowboat otherwise)
##   BeachJetty/ArrivalPoint   (where the player stands, -Z up the path)
##   BeachJetty/CaptainMarlow
## (BeachJetty is found anywhere under the Island, e.g. StoryPlaces/Coast/BeachJetty.)
##   Villagers/Oliver, Island/Buildings/GeneralStore

signal finished(skipped: bool)

const FLAG := &"opening_seen"
const CHARACTER := preload("res://scenes/player/character.tscn")
const FALLBACK_BOAT := preload("res://scenes/props/rowboat.tscn")
const SUITCASE := "res://source_assets/tripo/suitcase.glb"
const HAND_FONT := preload("res://assets/ui/fonts/Caveat.ttf")
## Used when the jetty hasn't been built yet: the south-west beach.
const FALLBACK_JETTY := Vector3(-95.0, 0.0, 186.0)
const FALLBACK_ARRIVAL := Vector2(-95.0, 172.0)
const VILLAGE_SQUARE := Vector3(0.0, 4.0, 115.0)
const LAKE_GLOW_POINT := Vector3(-2.0, 0.0, 11.0)

## Timeline (seconds). Shots cut on a short dip to black.
const CUTS := [9.0, 19.0, 31.0, 41.0, 45.5, 50.0, 55.5]
const ARRIVE_AT := 55.0       # the boat is moored
const HANDOFF_AT := 62.0      # camera swings behind the player, bars slide away
const HANDOFF_TIME := 2.5
const UNLOCK_AT := 64.5       # player can move, HUD back, flag set
const TITLE_IN := 62.6
const TITLE_HOLD := 3.0
const HUD_AT := 66.4         # after the title, so it doesn't clash with the region banner
const END_AT := 67.0
const SKIP_HOLD := 1.0
const SKIP_HINT_AT := 3.0
const BAR_HEIGHT := 0.1       # of the screen height, top and bottom
const LINE_FADE := 0.6
## [text, from, to]
const LETTER := [
	["To my dear grandchild,", 1.2, 5.2],
	["If you're reading this, the island has finally called you home.", 5.4, 10.6],
	["I've left you my cottage. It's small and a little dusty, but it was always full of light.", 10.8, 19.2],
	["The village isn't what it was. After the storm, when the lighthouse went dark, most families moved away.", 19.4, 31.0],
	["But some things here are still worth finding. You'll know them when you see them.", 31.4, 41.0],
	["Emma at the store has your key. Oliver will show you the lake. Be kind to them; they were kind to me.", 41.4, 50.2],
	["Take your time. The island isn't going anywhere.", 50.6, 57.0],
	["With love,\nGrandpa Elias", 57.2, 61.8],
]
const MARLOW_LINE := "Willowbrook! Mind the gap, and give Emma my best."
## Sounds (synthesised by tools/generate_opening_audio.py). The music starts at
## MUSIC_AT; the sea loops under everything; cues are [time, sound, volume_db].
const AUDIO := "res://assets/audio/opening/"
const MUSIC_AT := 0.5
const MUSIC_DB := -3.0
const SEA_DB := -6.0
const CUES := [
	[2.4, "gulls", -10.0], [12.5, "gulls", -13.0], [19.1, "whoosh", -5.0],
	[21.5, "chimes", -15.0], [34.0, "lake_bell", -3.0], [41.6, "horn", -15.0],
	[46.2, "chimes", -17.0], [52.3, "horn", -4.0], [53.8, "gulls", -7.0], [58.6, "gulls", -12.0],
]

## Tests can run the scene faster.
var speed: float = 1.0

var _t: float = 0.0
var _running: bool = false
var _skipped: bool = false
var _unlocked: bool = false
var _focus_paused: bool = false
var _fired: Dictionary = {}
var _held: Dictionary = {}
var _hold: float = 0.0

var _main: Node3D
var _island: Node3D
var _player: PlayerController
var _player_camera: Camera3D
var _hud: CanvasLayer
var _oliver: Node3D
var _marlow: Node3D
var _store: Node3D
var _jetty_root: Node
var _boat: Node3D
var _boat_moored := Transform3D.IDENTITY
var _boat_start := Vector3.ZERO
var _boat_p1 := Vector3.ZERO
var _boat_p2 := Vector3.ZERO
var _fallback_boat: bool = false
var _bow_local := Vector3.ZERO
var _standin: Node3D
var _arrival := Transform3D.IDENTITY
var _jetty := Vector3.ZERO
var _side := Vector3.RIGHT
var _handoff_from := Transform3D.IDENTITY

var _camera: Camera3D
var _glow: MeshInstance3D
var _glow_material: ShaderMaterial
var _glow_light: OmniLight3D
var _store_light: OmniLight3D
var _marlow_bubble: Label3D

var _music: AudioStreamPlayer
var _sea: AudioStreamPlayer
var _cues: Array = []          # [player, volume_db]
var _audio_level: float = 1.0  # falls to 0 after a skip

var _ui: CanvasLayer
var _fader: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _letter_card: PanelContainer
var _letter_label: Label
var _title: Label
var _skip_hint: Control
var _skip_bar: ProgressBar


## Requested by the title screen on New game, read once by the main scene.
static var _requested: bool = false


static func request() -> void:
	_requested = true


static func consume_request() -> bool:
	var was := _requested
	_requested = false
	return was


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Starts the opening on the main scene (the island, the player and the HUD are its
## children). The player is placed at the jetty straight away, so a skip, or the end of
## the scene, leaves them there.
func begin(main: Node3D) -> void:
	_main = main
	_island = main.get_node("Island") as Node3D
	_player = main.get_node("Player") as PlayerController
	_player_camera = _player.get_node("CameraRig").call(&"get_camera") as Camera3D
	_hud = main.get_node_or_null("HUD") as CanvasLayer
	_oliver = main.get_node_or_null("Villagers/Oliver") as Node3D
	_store = _island.get_node_or_null("Buildings/GeneralStore") as Node3D
	_jetty_root = _island.find_child("BeachJetty", true, false)
	_marlow = _jetty_node("CaptainMarlow")
	_find_arrival()
	_find_boat()
	_build_world_bits()
	_build_ui()
	_build_audio()
	_player.set_input_locked(true)
	_player.teleport_to(_arrival.origin, _yaw_of(_arrival.basis))
	_player.visible = false
	if _hud:
		_hud.visible = false
	if _marlow:
		_marlow.visible = false
	_camera.make_current()
	_running = true
	_apply(0.0)


func is_running() -> bool:
	return _running


func get_time() -> float:
	return _t


func get_arrival() -> Transform3D:
	return _arrival


func get_boat() -> Node3D:
	return _boat


func get_letter_text() -> String:
	return _letter_label.text if _letter_card.modulate.a > 0.01 else ""


## Jumps to the end: the boat is moored, the player stands on the jetty and can move.
func skip() -> void:
	if not _running or _unlocked:
		return
	_skipped = true
	_t = UNLOCK_AT
	for key in [&"oliver_wave", &"swap", &"handoff", &"marlow_wave", &"unlock"]:
		_fired[key] = true
	_finish_state()
	_fader.color.a = 1.0
	_apply(_t)


# ---------------------------------------------------------------- timeline

func _process(delta: float) -> void:
	if not _running:
		return
	if not _focus_paused:
		_t += delta * speed
	if _skipped:
		_audio_level = maxf(0.0, _audio_level - delta * 1.25)
	_update_skip(delta)
	_apply(_t)
	if _t >= END_AT:
		_end()


func _apply(t: float) -> void:
	if not _unlocked:
		_boat.global_transform = _boat_transform(t)
		if t < HANDOFF_AT:
			var shot := _shot_camera(t)
			_camera.look_at_from_position(shot[0], shot[1], Vector3.UP)
		else:
			if not _fired.has(&"handoff"):
				_fired[&"handoff"] = true
				_handoff_from = _camera.global_transform
			var k := _ease(clampf((t - HANDOFF_AT) / HANDOFF_TIME, 0.0, 1.0))
			_camera.global_transform = _handoff_from.interpolate_with(_player_camera.global_transform, k)
	_once(&"oliver_wave", t >= 42.0, func() -> void:
		if _oliver and _oliver.has_method(&"wave_towards"):
			_oliver.call(&"wave_towards", _boat.global_position))
	_once(&"swap", t >= CUTS[6], _swap_to_player)
	_once(&"marlow_wave", t >= 63.0, func() -> void:
		if _marlow and _marlow.has_method(&"wave_towards"):
			_marlow.call(&"wave_towards", _player.global_position))
	_once(&"unlock", t >= UNLOCK_AT, _finish_state)
	_once(&"hud", t >= HUD_AT, func() -> void:
		if _hud:
			_hud.visible = true)
	_apply_effects(t)
	_apply_ui(t)
	_apply_audio(t)


func _once(key: StringName, condition: bool, action: Callable) -> void:
	if condition and not _fired.has(key):
		_fired[key] = true
		action.call()


## Shots 1 to 6: [camera position, look-at point] at time t.
func _shot_camera(t: float) -> Array:
	var j := _jetty
	if t < CUTS[0]:
		# 1. Sea at dawn: low over the water, the boat crosses towards the island.
		var k := t / CUTS[0]
		var heading := _boat_p1 - _boat_start
		heading.y = 0.0
		heading = heading.normalized()
		var right := heading.cross(Vector3.UP)
		var cam := _boat_start - heading * 26.0 + right * 7.0 + Vector3.UP * 3.6
		return [_lerp_e(cam, cam + heading * 18.0 + Vector3.UP * 0.6, k), _boat_start + heading * 90.0 + Vector3.UP * 9.0]
	if t < CUTS[1]:
		# 2. On deck: behind the player at the bow, drifting round to their side.
		var k := (t - CUTS[0]) / (CUTS[1] - CUTS[0])
		var b := _boat.global_transform
		var bow := b * _bow_local
		var fwd := -b.basis.z.normalized()
		var right := b.basis.x.normalized()
		var pos := _lerp_e(bow - fwd * 3.6 + right * 1.3 + Vector3.UP * 2.7, bow + right * 3.4 + fwd * 1.4 + Vector3.UP * 1.7, k)
		var look := _lerp_e(bow + fwd * 7.0 + Vector3.UP * 0.4, bow + Vector3.UP * 1.3, k)
		return [pos, look]
	if t < CUTS[2]:
		# 3. Over Willowbrook: up from the beach, gliding north over the rooftops.
		var k := (t - CUTS[1]) / (CUTS[2] - CUTS[1])
		return [_lerp_e(Vector3(-62, 38, 192), Vector3(2, 24, 136), k), _lerp_e(Vector3(-22, 6, 146), Vector3(0, 4, 110), k)]
	if t < CUTS[3]:
		# 4. Over Moonlit Lake: low across the water from the dock towards the lake isle.
		var k := (t - CUTS[2]) / (CUTS[3] - CUTS[2])
		var lake := IslandShape.LAKE_LEVEL
		return [_lerp_e(Vector3(12, lake + 5.5, 46), Vector3(4, lake + 4.2, 26), k), _lerp_e(Vector3(-3, lake, 8), Vector3(-5, lake + 0.4, 6), k)]
	if t < CUTS[4]:
		# 5a. Oliver at the dock hears the horn and waves.
		var k := (t - CUTS[3]) / (CUTS[4] - CUTS[3])
		var o := _oliver.global_position if _oliver else Vector3(11, 4, 61.5)
		return [_lerp_e(o + Vector3(-2.8, 1.9, 3.8), o + Vector3(-2.1, 1.7, 2.9), k), o + Vector3(0, 1.35, 0)]
	if t < CUTS[5]:
		# 5b. The General Store: the window light comes on.
		var k := (t - CUTS[4]) / (CUTS[5] - CUTS[4])
		var s := _store.global_transform if _store else Transform3D(Basis(), Vector3(26, 4, 119))
		return [_lerp_e(s * Vector3(3.0, 3.2, 14.0), s * Vector3(2.0, 2.8, 11.5), k), s * Vector3(0, 2.4, 0)]
	if t < CUTS[6]:
		# 6a. The boat glides in to the jetty (side view).
		var k := (t - CUTS[5]) / (CUTS[6] - CUTS[5])
		var cam := j + _side * 24.0 + Vector3.UP * 6.0 - _boat_moored.basis.z.normalized() * 6.0
		return [_lerp_e(cam, cam - _side * 4.0, k), _boat.global_position + Vector3.UP * 1.5]
	# 6b. On the jetty: the player looks up the path, the boat behind them.
	var k := (t - CUTS[6]) / (HANDOFF_AT - CUTS[6])
	var a := _arrival
	return [_lerp_e(a * Vector3(2.3, 1.7, -3.6), a * Vector3(1.6, 1.55, -2.7), k), a.origin + Vector3.UP * 1.3]


## The mail boat's path: in from the open sea, slowing as it reaches the jetty.
func _boat_transform(t: float) -> Transform3D:
	var x := clampf(t / ARRIVE_AT, 0.0, 1.0)
	var u := 0.45 * x + 0.55 * (1.0 - pow(1.0 - x, 2.0))
	var pos := _bezier(_boat_start, _boat_p1, _boat_p2, _boat_moored.origin, u)
	var ahead := _bezier(_boat_start, _boat_p1, _boat_p2, _boat_moored.origin, minf(u + 0.01, 1.0))
	var basis := _boat_moored.basis
	var dir := ahead - pos
	dir.y = 0.0
	if u < 0.999 and dir.length() > 0.01:
		var moored := _boat_moored.basis.orthonormalized()
		var turn := Basis.looking_at(dir.normalized(), Vector3.UP).slerp(moored, smoothstep(0.8, 1.0, u))
		basis = turn.orthonormalized() * Basis.from_scale(_boat_moored.basis.get_scale())
	pos.y = _boat_moored.origin.y
	return Transform3D(basis, pos)


func _swap_to_player() -> void:
	if _standin:
		_standin.visible = false
	_player.visible = true
	_player.teleport_to(_arrival.origin, _yaw_of(_arrival.basis))
	if _marlow:
		_marlow.visible = true


## Everything the scene leaves behind once it's over (also the result of a skip).
func _finish_state() -> void:
	_unlocked = true
	_boat.global_transform = _boat_moored
	_swap_to_player()
	_player_camera.make_current()
	_player.set_input_locked(false)
	# After a skip the HUD comes straight back; otherwise once the title has faded.
	if _hud and _skipped:
		_hud.visible = true
	_held.clear()
	if not GameManager.has_flag(FLAG):
		GameManager.set_flag(FLAG)


func _end() -> void:
	if not _unlocked:
		_finish_state()
	if _hud:
		_hud.visible = true
	_running = false
	if is_instance_valid(_standin):
		_standin.queue_free()
	finished.emit(_skipped)
	queue_free()


# ---------------------------------------------------------------- effects

func _apply_effects(t: float) -> void:
	# The light in the lake: one soft pulse in shot 4.
	var pulse := 0.0
	if t > 34.0 and t < 37.0:
		pulse = sin((t - 34.0) / 3.0 * PI)
	_glow.visible = pulse > 0.001
	_glow_material.set_shader_parameter(&"strength", pulse)
	_glow_light.light_energy = 3.0 * pulse
	# The store's window light comes on in shot 5b and stays warm until the hand-off.
	_store_light.light_energy = 2.2 * smoothstep(46.6, 47.6, t) * (1.0 - smoothstep(64.0, 66.0, t))
	# Captain Marlow's only line.
	if _marlow_bubble:
		_marlow_bubble.visible = t > 56.2 and t < 61.6 and not _skipped


func _apply_ui(t: float) -> void:
	# Fade in from black at the start, and a short dip to black at each cut.
	var black := 1.0 - smoothstep(0.3, 2.2, t)
	for cut in CUTS:
		black = maxf(black, 1.0 - clampf(absf(t - cut) / 0.4, 0.0, 1.0))
	if _skipped:
		black = maxf(0.0, _fader.color.a - get_process_delta_time() * 2.0)
	_fader.color.a = black
	# Letterbox bars slide away at the hand-off.
	var bars := 1.0 - smoothstep(HANDOFF_AT, HANDOFF_AT + 0.8, t)
	_top_bar.anchor_bottom = BAR_HEIGHT * bars
	_bottom_bar.anchor_top = 1.0 - BAR_HEIGHT * bars
	# The letter: one line at a time.
	var alpha := 0.0
	for line in LETTER:
		if t >= line[1] and t < line[2]:
			if _letter_label.text != line[0]:
				_letter_label.text = line[0]
			alpha = minf(clampf((t - line[1]) / LINE_FADE, 0.0, 1.0), clampf((line[2] - t) / 0.35, 0.0, 1.0))
	_letter_card.modulate.a = alpha
	# The title, then the skip hint.
	_title.modulate.a = 0.0 if _skipped else smoothstep(TITLE_IN, TITLE_IN + 0.8, t) * (1.0 - smoothstep(TITLE_IN + TITLE_HOLD, TITLE_IN + TITLE_HOLD + 0.9, t))
	_skip_hint.modulate.a = 0.0 if _unlocked or t >= HANDOFF_AT else maxf(smoothstep(SKIP_HINT_AT, SKIP_HINT_AT + 0.8, t) * 0.85, 1.0 if _hold > 0.0 else 0.0)
	_skip_bar.value = _hold / SKIP_HOLD


# ---------------------------------------------------------------- sound

func _apply_audio(t: float) -> void:
	if _music == null:
		return
	_once(&"music", t >= MUSIC_AT and t < MUSIC_AT + 2.0, _music.play)
	_once(&"sea", true, _sea.play)
	var fade_out := 1.0 - smoothstep(END_AT - 2.0, END_AT, t)
	_music.volume_db = MUSIC_DB + _db(fade_out * _audio_level)
	# The sea is loud at sea and at the jetty, distant over the village and the lake.
	var near := 1.0 - smoothstep(18.6, 19.6, t) * (1.0 - smoothstep(49.6, 51.0, t))
	var sea := lerpf(0.22, 1.0, near) * (1.0 - smoothstep(63.5, END_AT, t))
	_sea.volume_db = SEA_DB + _db(sea * _audio_level)
	for i in CUES.size():
		var cue: Array = CUES[i]
		var at: float = cue[0]
		# Only fire a cue near its moment, so a skip doesn't set off every sound at once.
		_once(StringName("cue%d" % i), t >= at and t < at + 1.0, func() -> void:
			var player := AudioStreamPlayer.new()
			player.stream = load(AUDIO + str(cue[1]) + ".wav") as AudioStream
			player.bus = &"Effects"
			player.volume_db = float(cue[2]) + _db(_audio_level)
			add_child(player)
			player.play()
			player.finished.connect(player.queue_free)
			_cues.append([player, float(cue[2])]))
	# Finished cues free themselves; keep the rest in step with a skip's fade.
	_cues = _cues.filter(func(entry: Array) -> bool: return is_instance_valid(entry[0]))
	for entry in _cues:
		(entry[0] as AudioStreamPlayer).volume_db = float(entry[1]) + _db(_audio_level)


func _build_audio() -> void:
	if not ResourceLoader.exists(AUDIO + "music.wav"):
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.stream = load(AUDIO + "music.wav") as AudioStream
	_music.bus = &"Music"
	add_child(_music)
	_sea = AudioStreamPlayer.new()
	_sea.name = "Sea"
	var sea := (load(AUDIO + "sea_loop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	sea.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sea.loop_begin = 0
	sea.loop_end = int(sea.get_length() * sea.mix_rate)
	_sea.stream = sea
	_sea.bus = &"Ambience"
	add_child(_sea)


func _pause_audio(paused: bool) -> void:
	for node in find_children("*", "AudioStreamPlayer", false, false):
		(node as AudioStreamPlayer).stream_paused = paused


static func _db(level: float) -> float:
	return linear_to_db(maxf(level, 0.0001))


# ---------------------------------------------------------------- input

## While the scene plays it takes all input (nothing reaches the player, the bag or
## the pause menu). Holding any key or button skips.
func _input(event: InputEvent) -> void:
	if not _running or _unlocked:
		return
	if event is InputEventKey and not event.is_echo():
		_track(&"k%d" % (event as InputEventKey).physical_keycode, event.is_pressed())
	elif event is InputEventMouseButton:
		_track(&"m%d" % (event as InputEventMouseButton).button_index, event.is_pressed())
	elif event is InputEventJoypadButton:
		_track(&"j%d" % (event as InputEventJoypadButton).button_index, event.is_pressed())
	get_viewport().set_input_as_handled()


func _track(key: StringName, pressed: bool) -> void:
	if pressed:
		_held[key] = true
	else:
		_held.erase(key)


func _update_skip(delta: float) -> void:
	if _unlocked:
		_hold = 0.0
		return
	if _held.is_empty():
		_hold = maxf(0.0, _hold - delta * 3.0)
	else:
		_hold += delta
		if _hold >= SKIP_HOLD:
			_hold = 0.0
			skip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_paused = true
		_held.clear()
		_pause_audio(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_paused = false
		_pause_audio(false)


# ---------------------------------------------------------------- setup

func _find_arrival() -> void:
	var marker := _jetty_node("ArrivalPoint")
	if marker:
		var pos := marker.global_position
		_arrival = Transform3D(Basis(Vector3.UP, _yaw_of(marker.global_basis)), _surface_below(pos + Vector3.UP * 2.0, pos.y))
	else:
		var x := FALLBACK_ARRIVAL.x
		var z := FALLBACK_ARRIVAL.y
		var ground := IslandShape.shared().get_height(x, z)
		var to_village := VILLAGE_SQUARE - Vector3(x, 0, z)
		_arrival = Transform3D(Basis(Vector3.UP, atan2(-to_village.x, -to_village.z)), Vector3(x, ground + 0.2, z))


func _find_boat() -> void:
	_boat = _jetty_node("MailBoat")
	if _boat == null:
		# Not built yet: a larger rowboat stands in, moored beside the beach.
		_fallback_boat = true
		_boat = FALLBACK_BOAT.instantiate() as Node3D
		_boat.name = "OpeningBoat"
		_island.add_child(_boat)
		_boat.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 1.6), FALLBACK_JETTY)
	_boat_moored = _boat.global_transform
	_jetty = _boat_moored.origin
	var back := _boat_moored.basis.z
	back.y = 0.0
	back = back.normalized()
	var shape := IslandShape.shared()
	# Come in from the open sea behind the boat; if land is behind it, from the south.
	var behind := _jetty + back * 45.0
	if shape.get_height(behind.x, behind.z) > -1.5:
		back = Vector3(0, 0, 1)
		behind = _jetty + back * 45.0
	_boat_start = _jetty + Vector3(-70, 0, 140)
	_boat_p1 = _boat_start.lerp(behind, 0.45)
	_boat_p2 = behind
	# The side camera in shot 6 goes on whichever side of the boat is lower (open water).
	var side := _boat_moored.basis.x
	side.y = 0.0
	side = side.normalized()
	var a := _jetty + side * 24.0
	var b := _jetty - side * 24.0
	_side = side if shape.get_height(a.x, a.z) < shape.get_height(b.x, b.z) else -side
	_bow_local = _find_bow()


## A spot on the deck near the bow, in the boat's own space.
func _find_bow() -> Vector3:
	var inverse := _boat.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for node in _boat.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		var local := (inverse * vi.global_transform) * vi.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if first:
		return Vector3(0, 1, -1)
	var bow := Vector3(box.get_center().x, box.position.y + box.size.y * 0.32, box.position.z + box.size.z * 0.24)
	return bow


func _build_world_bits() -> void:
	_camera = Camera3D.new()
	_camera.name = "OpeningCamera"
	_camera.fov = 58.0
	_camera.near = 0.08
	_camera.far = 900.0
	add_child(_camera)
	# The player, standing at the bow with the letter.
	_standin = CHARACTER.instantiate() as Node3D
	_standin.name = "PlayerOnDeck"
	_boat.add_child(_standin)
	var b := _boat.global_transform
	var bow_world := b * _bow_local
	_standin.global_transform = Transform3D(Basis(Vector3.UP, _yaw_of(b.basis)), _deck_height(bow_world))
	if ResourceLoader.exists(SUITCASE):
		var suitcase := (load(SUITCASE) as PackedScene).instantiate() as Node3D
		_standin.add_child(suitcase)
		suitcase.position = Vector3(0.45, 0.0, 0.35)
		suitcase.scale = Vector3.ONE * 0.5
	# The light in the lake: a soft glow just under the surface.
	_glow = MeshInstance3D.new()
	_glow.name = "LakeGlow"
	var quad := QuadMesh.new()
	quad.size = Vector2(22, 22)
	quad.orientation = PlaneMesh.FACE_Y
	_glow.mesh = quad
	_glow_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
	ALBEDO = vec3(0.35, 0.78, 1.0) * glow * strength * 3.2;
}"""
	_glow_material.shader = shader
	_glow.material_override = _glow_material
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_glow.global_position = Vector3(LAKE_GLOW_POINT.x, IslandShape.LAKE_LEVEL + 0.06, LAKE_GLOW_POINT.z)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(0.45, 0.8, 1.0)
	_glow_light.omni_range = 12.0
	_glow_light.light_energy = 0.0
	_glow.add_child(_glow_light)
	_glow_light.position = Vector3(0, 1.2, 0)
	# The store's window light.
	_store_light = OmniLight3D.new()
	_store_light.name = "StoreWindowLight"
	_store_light.light_color = Color(1.0, 0.78, 0.48)
	_store_light.omni_range = 7.0
	_store_light.light_energy = 0.0
	add_child(_store_light)
	var s := _store.global_transform if _store else Transform3D(Basis(), Vector3(26, 4, 119))
	_store_light.global_position = s * Vector3(0, 2.2, 3.2)
	# Captain Marlow's line, styled like the villagers' speech bubbles.
	if _marlow:
		_marlow_bubble = Label3D.new()
		_marlow_bubble.name = "MarlowLine"
		_marlow_bubble.text = MARLOW_LINE
		_marlow_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marlow_bubble.pixel_size = 0.0045
		_marlow_bubble.font_size = 44
		_marlow_bubble.outline_size = 16
		_marlow_bubble.modulate = UIPalette.CREAM
		_marlow_bubble.outline_modulate = UIPalette.INK
		_marlow_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_marlow_bubble.width = 620
		_marlow_bubble.no_depth_test = true
		_marlow_bubble.visible = false
		add_child(_marlow_bubble)
		_marlow_bubble.global_position = _marlow.global_position + Vector3.UP * 2.6


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "OpeningUI"
	_ui.layer = 20
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(UIPalette.THEME_PATH):
		root.theme = load(UIPalette.THEME_PATH) as Theme
	_ui.add_child(root)

	_top_bar = _bar(root)
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = BAR_HEIGHT
	_bottom_bar = _bar(root)
	_bottom_bar.anchor_top = 1.0 - BAR_HEIGHT
	_bottom_bar.anchor_bottom = 1.0

	# The letter card: parchment, handwriting, bottom centre over the lower bar.
	_letter_card = PanelContainer.new()
	_letter_card.name = "LetterCard"
	_letter_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = UIPalette.PARCHMENT
	paper.border_color = UIPalette.WOOD_LIGHT
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(14)
	paper.shadow_color = UIPalette.SHADOW
	paper.shadow_size = 10
	paper.content_margin_left = 34
	paper.content_margin_right = 34
	paper.content_margin_top = 14
	paper.content_margin_bottom = 16
	_letter_card.add_theme_stylebox_override(&"panel", paper)
	_letter_card.anchor_left = 0.2
	_letter_card.anchor_right = 0.8
	_letter_card.anchor_top = 1.0
	_letter_card.anchor_bottom = 1.0
	_letter_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_letter_card.offset_bottom = -36
	_letter_card.modulate.a = 0.0
	root.add_child(_letter_card)
	_letter_label = Label.new()
	_letter_label.name = "LetterLine"
	_letter_label.add_theme_font_override(&"font", HAND_FONT)
	_letter_label.add_theme_font_size_override(&"font_size", 40)
	_letter_label.add_theme_color_override(&"font_color", UIPalette.INK)
	_letter_label.add_theme_constant_override(&"outline_size", 0)
	_letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_label.custom_minimum_size = Vector2(200, 0)
	_letter_card.add_child(_letter_label)

	# The game's title, over the sky at the hand-off.
	_title = Label.new()
	_title.name = "TitleCard"
	_title.text = "Life on the Island"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.anchor_top = 0.16
	_title.anchor_bottom = 0.16
	_title.modulate.a = 0.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)

	# "Hold to skip", bottom-right, with a bar that fills while held.
	var hint := PanelContainer.new()
	hint.name = "SkipHint"
	hint.theme_type_variation = &"InsetPanel"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -24
	hint.offset_bottom = -20
	hint.modulate.a = 0.0
	root.add_child(hint)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	hint.add_child(column)
	var label := Label.new()
	label.text = "Hold any key to skip"
	label.theme_type_variation = &"SubtleLabel"
	column.add_child(label)
	_skip_bar = ProgressBar.new()
	_skip_bar.theme_type_variation = &"LeafBar"
	_skip_bar.show_percentage = false
	_skip_bar.max_value = 1.0
	_skip_bar.custom_minimum_size = Vector2(160, 8)
	column.add_child(_skip_bar)
	_skip_hint = hint

	_fader = ColorRect.new()
	_fader.name = "Fader"
	_fader.color = Color(0, 0, 0, 1)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fader)


func _bar(parent: Control) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0.02, 0.02, 0.03, 1)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


# ---------------------------------------------------------------- helpers

func _jetty_node(node_name: String) -> Node3D:
	return _jetty_root.get_node_or_null(node_name) as Node3D if _jetty_root else null


## The top of whatever solid thing is under a point (the jetty boards, the deck), or
## the terrain.
func _surface_below(from: Vector3, fallback_y: float) -> Vector3:
	var space := _main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0)
	query.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(query)
	var y := fallback_y
	if not hit.is_empty():
		y = (hit.position as Vector3).y
	y = maxf(y, IslandShape.shared().get_height(from.x, from.z))
	return Vector3(from.x, y + 0.05, from.z)


func _deck_height(point: Vector3) -> Vector3:
	var space := _main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 4.0, point + Vector3.DOWN * 3.0)
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Node and _boat.is_ancestor_of(hit.collider as Node):
		return hit.position as Vector3
	return point


static func _yaw_of(basis: Basis) -> float:
	var fwd := -basis.z
	return atan2(-fwd.x, -fwd.z)


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _lerp_e(a: Vector3, b: Vector3, k: float) -> Vector3:
	return a.lerp(b, _ease(k))


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u
