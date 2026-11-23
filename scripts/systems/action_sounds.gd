class_name ActionSounds
extends Node
## Sounds for the player's fishing and farming, played in time with what you see:
##
## Fishing: the rod coming out and going away, the swish of the cast, the reel's clicks
## (they follow the crank, so they speed up and slow down with it, and buzz backwards
## when a fish pulls line), the bobber's plop, the plunk of a bite, a fish thrashing,
## the line straining when it's too tight, a snap, a fish slipping away, and a big
## splash with a happy jingle for a catch.
## Farming: the spade biting into the soil, seeds dropped and patted in, water
## sprinkling (exactly while the can pours), fertilizer scattering, a crop pulled up
## with a little chime, and the rattle of a seed packet when you switch seeds.
##
## Other work (gathering wood or stone, clearing brambles, building and repairing) gets
## a sound each time the work swing lands: snapping branches, a chisel on stone, a
## brush of leaves, a hammer.
##
## Lives on the player as "ActionSounds", listening to the Fishing and Farming nodes.
## It only listens and plays: it never changes the clock or the game.

signal played(sound: StringName)

const DIR := "res://assets/audio/actions/"
const DB := {
	&"rod_out": -14.0, &"rod_away": -15.0, &"cast_swish": -9.0, &"reel_click": -19.0,
	&"drag_click": -15.0, &"bobber_plop": -7.0, &"bite_plunk": -4.0, &"fish_splash": -7.0,
	&"catch_splash": -4.0, &"catch_jingle": -10.0, &"line_snap": -6.0, &"fish_escape": -8.0,
	&"dig": -6.0, &"plant": -9.0, &"fertilize": -10.0, &"harvest": -7.0,
	&"harvest_jingle": -12.0, &"seed_rattle": -12.0,
	&"work_hammer": -8.0, &"work_wood": -8.0, &"work_stone": -9.0, &"work_brush": -9.0,
}
## The work sounds live with the story sounds.
const WORK_DIR := "res://assets/audio/story/"
## The work swing (farm_swing, 1.4 s) lands at this point of the clip.
const SWING_IMPACT := 0.8
## Sounds heard from the water where the bobber is, not from the player.
const AT_BOBBER: Array[StringName] = [&"bobber_plop", &"bite_plunk", &"fish_splash", &"fish_escape"]
## The cast's swish leads the moment the line is let go by this much (s).
const SWISH_LEAD := 0.18
## Reel clicks per turn of the crank.
const CLICKS_PER_TURN := 6.0
## Tension above which the line audibly strains (0..1).
const STRAIN_FROM := 0.72
const POUR_DB := -11.0
const STRAIN_DB := -13.0

## How many reel clicks have played (for checks).
var click_count: int = 0

var _player: PlayerController
var _fishing: FishingController
var _farming: FarmingController
var _tackle: FishingTackle
var _animator: CharacterAnimator
var _near: AudioStreamPlayer
var _far: AudioStreamPlayer3D
var _clicks: AudioStreamPlayer
var _pour: AudioStreamPlayer
var _strain: AudioStreamPlayer
var _streams: Dictionary = {}
var _last_state: int = -1
var _last_reel_angle: float = 0.0
var _click_phase: float = 0.0
var _splash_timer: float = 0.0
var _swish_timer: float = -1.0
var _pour_level: float = 0.0
var _strain_level: float = 0.0
var _interaction: PlayerInteraction
var _last_target: Interactable
var _swing_pos: float = -1.0


func _ready() -> void:
	name = "ActionSounds"
	_player = get_parent() as PlayerController
	_near = _make_player(&"Near", 4)
	_clicks = _make_player(&"Clicks", 4)
	_pour = _make_player(&"Pour", 1)
	_pour.stream = _loop(&"water_pour")
	_strain = _make_player(&"Strain", 1)
	_strain.stream = _loop(&"line_strain")
	_far = AudioStreamPlayer3D.new()
	_far.name = "AtBobber"
	_far.bus = &"Effects"
	_far.unit_size = 6.0
	_far.max_distance = 45.0
	_far.max_polyphony = 3
	add_child(_far)
	if _player == null:
		return
	_animator = _player.get_node_or_null("Visual/Character") as CharacterAnimator
	_fishing = _player.get_node_or_null("Fishing") as FishingController
	_farming = _player.get_node_or_null("Farming") as FarmingController
	if _fishing:
		_tackle = _fishing.get_node_or_null("Tackle") as FishingTackle
		_last_state = _fishing.state
		_fishing.state_changed.connect(_on_fishing_state)
		_fishing.fish_hooked.connect(func(_f: FishData) -> void: play(&"fish_splash"))
		_fishing.catch_finished.connect(func(_f: FishData, _s: float, _i: Dictionary) -> void:
			play(&"catch_splash")
			play(&"catch_jingle"))
		_fishing.fish_lost.connect(func(reason: String) -> void:
			play(&"line_snap" if reason.begins_with("Snap") else &"fish_escape"))
	if _farming:
		_farming.action_finished.connect(_on_farm_action)
		_farming.selected_seed_changed.connect(func(_s: StringName) -> void: play(&"seed_rattle"))
	for child in _player.get_children():
		if child is PlayerInteraction:
			_interaction = child


## Plays one of the action sounds (see DB for the names).
func play(sound: StringName) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p: Node = _near
	if sound in AT_BOBBER and _tackle:
		var line := _tackle.get_line_points()
		if line.size() >= 2:
			_far.global_position = line[line.size() - 2]
			p = _far
	p.set(&"stream", stream)
	p.set(&"volume_db", float(DB.get(sound, -10.0)) + randf_range(-1.0, 1.0))
	p.set(&"pitch_scale", randf_range(0.95, 1.05))
	p.call(&"play")
	played.emit(sound)


func is_pouring() -> bool:
	return _pour.playing and _pour_level > 0.01


func is_straining() -> bool:
	return _strain.playing and _strain_level > 0.01


func _on_fishing_state(new_state: int) -> void:
	var old := _last_state
	_last_state = new_state
	match new_state:
		FishingController.State.READY:
			if old == FishingController.State.STOWED:
				play(&"rod_out")
		FishingController.State.STOWED:
			play(&"rod_away")
		FishingController.State.CASTING:
			var pos := _animator.get_action_position() if _animator else 0.0
			_swish_timer = maxf(FishingController.CAST_RELEASE - pos - SWISH_LEAD, 0.0)
		FishingController.State.WAITING:
			play(&"bobber_plop")
		FishingController.State.BITE:
			play(&"bite_plunk")
		FishingController.State.REELING:
			_splash_timer = randf_range(0.6, 1.2)


func _on_farm_action(_plot: FarmPlot, action: int) -> void:
	match action:
		FarmingController.Action.DIG:
			play(&"dig")
		FarmingController.Action.PLANT:
			play(&"plant")
		FarmingController.Action.FERTILIZE:
			play(&"fertilize")
		FarmingController.Action.HARVEST:
			play(&"harvest")
			play(&"harvest_jingle")


func _process(delta: float) -> void:
	if _swish_timer >= 0.0:
		_swish_timer -= delta
		if _swish_timer < 0.0:
			play(&"cast_swish")
	_update_reel()
	_update_fight(delta)
	_update_pour(delta)
	_update_work()


## One click each time the crank turns a sixth of the way round, whichever way it goes.
func _update_reel() -> void:
	if _tackle == null:
		return
	var angle := _tackle.get_reel_angle()
	var turned := wrapf(angle - _last_reel_angle, -PI, PI)
	_last_reel_angle = angle
	if absf(turned) < 0.0001:
		return
	_click_phase += turned / TAU * CLICKS_PER_TURN
	if _click_phase >= 1.0 or _click_phase <= -1.0:
		var backwards := _click_phase < 0.0
		_click_phase = fmod(_click_phase, 1.0)
		_clicks.stream = _stream(&"drag_click" if backwards else &"reel_click")
		_clicks.volume_db = float(DB[&"drag_click" if backwards else &"reel_click"])
		_clicks.pitch_scale = randf_range(0.96, 1.04)
		_clicks.play()
		click_count += 1


## While fighting a fish: it thrashes now and then, and the line strains when too tight.
func _update_fight(delta: float) -> void:
	var reeling := _fishing != null and _fishing.state == FishingController.State.REELING
	var target := 0.0
	if reeling:
		var game := _fishing.get_minigame()
		target = smoothstep(STRAIN_FROM, 1.0, game.tension)
		if game.struggling:
			_splash_timer -= delta
			if _splash_timer <= 0.0:
				_splash_timer = randf_range(0.7, 1.4)
				play(&"fish_splash")
	_strain_level = move_toward(_strain_level, target, delta * 4.0)
	_fade_loop(_strain, _strain_level, STRAIN_DB)


## The watering can's sprinkle plays exactly while its water is pouring.
func _update_pour(delta: float) -> void:
	var pouring := false
	if _player:
		var water := _player.get_node_or_null("WateringCan/Water") as CPUParticles3D
		pouring = water != null and water.emitting and water.is_visible_in_tree()
	_pour_level = move_toward(_pour_level, 1.0 if pouring else 0.0, delta * (8.0 if pouring else 3.0))
	_fade_loop(_pour, _pour_level, POUR_DB)


## Gathering, clearing and repairing: one sound each time the work swing lands.
func _update_work() -> void:
	if _interaction and _interaction.get_current():
		_last_target = _interaction.get_current()
	var swinging := _animator != null and _animator.get_current_animation() == &"farm_swing"
	if not swinging or (_farming and _farming.is_busy()):
		_swing_pos = -1.0
		return
	var pos := _animator.get_action_position()
	if _swing_pos >= 0.0 and _swing_pos < SWING_IMPACT and pos >= SWING_IMPACT:
		play(work_sound_for(_last_target if is_instance_valid(_last_target) else null))
	_swing_pos = pos


## Which sound a work swing makes at this place.
static func work_sound_for(target: Interactable) -> StringName:
	if target is GatherNode:
		match (target as GatherNode).item_id:
			&"wood":
				return &"work_wood"
			&"stone":
				return &"work_stone"
		return &"work_brush"
	if target is RestorationSite or target is CraftingSpot:
		return &"work_hammer"
	if target is StoryActivity and String((target as StoryActivity).sets_flag).contains("plant"):
		return &"dig"
	return &"work_brush"


func _fade_loop(p: AudioStreamPlayer, level: float, full_db: float) -> void:
	if level > 0.001:
		p.volume_db = full_db + linear_to_db(level)
		if not p.playing:
			p.play()
	elif p.playing:
		p.stop()


func _make_player(node_name: StringName, polyphony: int) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = &"Effects"
	p.max_polyphony = polyphony
	add_child(p)
	return p


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		var dir := WORK_DIR if String(sound).begins_with("work_") else DIR
		_streams[sound] = load(dir + String(sound) + ".wav") as AudioStream
	return _streams[sound]


func _loop(sound: StringName) -> AudioStream:
	var s := (load(DIR + String(sound) + ".wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	if s:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s
