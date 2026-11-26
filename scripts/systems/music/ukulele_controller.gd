class_name UkuleleController
extends Node
## Grandpa's ukulele, on the player as "Ukulele". U takes it out and puts it away;
## keys 1-8 play a C major scale. Free playing is just for fun and uses no time.
##
## Playing one of Grandpa's melodies (MelodyData, learned from the ukulele case and his
## journal pages) does something gentle. Time rules (explicit, activity-based):
##   Sunset Song      daytime: play until 6 PM            (clock moves to 6 PM)
##   Starlight Song   at night: sleep under the stars     (clock moves to 6 AM)
##   Rain Song        a soft rain, once a day              -> melody_minutes
##   Serenade         a villager nearby, once a day each   -> melody_minutes
##   Lake Lullaby     by the water: next cast bites fast   -> melody_minutes
## A melody that can't work right now (wrong time, nobody near) costs nothing.

signal note_played(note: int)
signal melody_played(melody: MelodyData, worked: bool)
signal playing_changed(playing: bool)

const UKULELE := &"ukulele"
const CLIP := &"uke_play"
## C major from middle C: note 1..8 -> semitones above C4.
const SCALE := [0, 2, 4, 5, 7, 9, 11, 12]
const NOTE_NAMES := ["C", "D", "E", "F", "G", "A", "B", "C"]
const C4 := 261.63
const SERENADE_DISTANCE := 5.0
const LULLABY_WATER_REACH := 6.0
## Short pause after the last note before a melody's effect (let it ring).
const EFFECT_DELAY := 0.6

@export var melody_minutes: int = 15

var _player: PlayerController
var _animator: CharacterAnimator
var _fishing: FishingController
var _skeleton: Skeleton3D
var _left_hand: int = -1
var _right_hand: int = -1
var _synth: UkuleleSynth
var _instrument: MeshInstance3D
var _hud: CanvasLayer
var _keys: Array[PanelContainer] = []
var _recent_label: Label
var _book: VBoxContainer
var _playing: bool = false
var _recent: Array[int] = []
var _rain_day: int = 0


func _ready() -> void:
	add_to_group(&"ukulele_controller")
	add_to_group(&"persistent")
	_player = get_parent() as PlayerController
	_animator = _player.get_node("Visual/Character") as CharacterAnimator
	_fishing = _player.get_node_or_null("Fishing") as FishingController
	_skeleton = _animator.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_left_hand = _skeleton.find_bone("mixamorig_LeftHand")
		_right_hand = _skeleton.find_bone("mixamorig_RightHand")
	_synth = UkuleleSynth.new()
	_synth.name = "Synth"
	add_child(_synth)
	_instrument = MeshInstance3D.new()
	_instrument.name = "Instrument"
	_instrument.mesh = UkuleleVisuals.mesh()
	_instrument.top_level = true
	_instrument.visible = false
	_player.add_child.call_deferred(_instrument)
	_build_hud()


func is_playing() -> bool:
	return _playing


func has_ukulele() -> bool:
	return InventoryManager.has_item(UKULELE)


func get_synth() -> UkuleleSynth:
	return _synth


## Melodies you know right now.
func get_known_melodies() -> Array[MelodyData]:
	var result: Array[MelodyData] = []
	for melody in MelodyCatalog.shared().melodies:
		if is_known(melody):
			result.append(melody)
	return result


func is_known(melody: MelodyData) -> bool:
	return has_ukulele() and (melody.learn_flag == &"" or GameManager.has_flag(melody.learn_flag))


# ---- Taking it out ------------------------------------------------------------------

func toggle() -> void:
	if _playing:
		stop()
	else:
		start()


func start() -> bool:
	if _playing:
		return true
	if not has_ukulele():
		GameManager.notify("You don't have an instrument yet. Grandpa used to keep his ukulele in the cottage.")
		return false
	if _player.is_sitting() or _player.is_input_locked() or not _player.is_on_floor():
		return false
	if _fishing:
		if _fishing.is_busy():
			return false
		_fishing.stow()
	_playing = true
	_recent.clear()
	_player.set_input_locked(true)
	_animator.play_action(CLIP)
	_instrument.visible = true
	_refresh_book()
	_refresh_recent()
	_hud.visible = true
	playing_changed.emit(true)
	return true


func stop() -> void:
	if not _playing:
		return
	_playing = false
	_animator.stop_action()
	_instrument.visible = false
	_hud.visible = false
	_player.set_input_locked(false)
	playing_changed.emit(false)


# ---- Playing ----------------------------------------------------------------------

## Plays scale note 1..8. Checks whether a melody was just completed.
func play_note(note: int) -> void:
	if not _playing or note < 1 or note > 8:
		return
	_synth.pluck(C4 * pow(2.0, SCALE[note - 1] / 12.0), 0.85 + randf() * 0.15)
	_recent.append(note)
	if _recent.size() > 8:
		_recent.pop_front()
	_flash_key(note)
	_refresh_recent()
	note_played.emit(note)
	var melody := _completed_melody()
	if melody:
		_recent.clear()
		if is_inside_tree() and DisplayServer.get_name() != "headless":
			get_tree().create_timer(EFFECT_DELAY).timeout.connect(func() -> void: perform(melody))
		else:
			perform(melody)


func _completed_melody() -> MelodyData:
	for melody in get_known_melodies():
		var n := melody.notes.size()
		if n == 0 or _recent.size() < n:
			continue
		var tail := _recent.slice(_recent.size() - n)
		var matches := true
		for i in n:
			matches = matches and tail[i] == melody.notes[i]
		if matches:
			return melody
	return null


## Does a melody's effect. Returns true if it worked (and time was spent).
func perform(melody: MelodyData) -> bool:
	var worked := false
	match melody.effect:
		&"sunset":
			worked = _sunset()
		&"starlight":
			worked = _starlight()
		&"rain":
			worked = _rain()
		&"serenade":
			worked = _serenade()
		&"lullaby":
			worked = _lullaby()
	if worked:
		QuestLog.record_event(&"play_melody")
		_cheer_villagers()
	melody_played.emit(melody, worked)
	return worked


func _sunset() -> bool:
	var hour := ActivityClock.get_hour()
	if hour < 5 or hour >= 18:
		GameManager.notify("The sun has already set. The Starlight Song suits the night.")
		return false
	var minutes := ActivityClock.minutes_until(18)
	ActivityClock.advance_minutes(minutes, &"music")
	GameManager.notify("You play the Sunset Song until the sky turns gold. It's %s." % ActivityClock.get_time_string())
	return true


func _starlight() -> bool:
	var hour := ActivityClock.get_hour()
	if hour >= 5 and hour < 20:
		GameManager.notify("The stars aren't out yet. Play the Starlight Song after 8 PM.")
		return false
	stop()
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	GameManager.notify("You drift off under the stars, ukulele in your lap. Good morning!  %s  %s" % [ActivityClock.get_time_string(), WeatherManager.get_morning_line()])
	return true


func _rain() -> bool:
	if WeatherManager.is_raining():
		GameManager.notify("It's already raining.")
		return false
	if _rain_day == ActivityClock.get_day():
		GameManager.notify("The clouds need a rest. Try the Rain Song again tomorrow.")
		return false
	_rain_day = ActivityClock.get_day()
	WeatherManager.set_weather(WeatherManager.Weather.RAIN)
	ActivityClock.advance_minutes(melody_minutes, &"music")
	GameManager.notify("Clouds gather as you play, and a soft rain begins. The garden will love it.")
	return true


func _serenade() -> bool:
	var villager := _nearest_villager()
	if villager == null:
		GameManager.notify("Play the Serenade near a villager.")
		return false
	if Friendship.serenaded_today(villager.data.id):
		villager.react_to_gift({"ok": true, "taste": Friendship.Taste.LIKED, "line": "Twice in one day? You'll spoil me!"})
		return false
	Friendship.record_serenade(villager.data.id)
	ActivityClock.advance_minutes(melody_minutes, &"music")
	villager.react_to_gift({"ok": true, "taste": Friendship.Taste.LOVED, "line": "What a lovely tune… your grandpa used to play that one."})
	return true


func _lullaby() -> bool:
	if _fishing == null or not _fishing.has_rod():
		GameManager.notify("The lullaby calls the fish… but you'd need a fishing rod to meet them.")
		return false
	if not _near_water():
		GameManager.notify("Play the Lake Lullaby by the water.")
		return false
	_fishing.quick_bite_next = true
	ActivityClock.advance_minutes(melody_minutes, &"music")
	GameManager.notify("Ripples circle the water. Your next cast will get a quick bite.")
	return true


func _nearest_villager() -> Villager:
	var best: Villager = null
	var best_distance := SERENADE_DISTANCE
	for node in get_tree().get_nodes_in_group(&"villagers"):
		var villager := node as Villager
		if villager == null or villager.data == null or not villager.is_visible_in_tree():
			continue
		var d := villager.global_position.distance_to(_player.global_position)
		if d < best_distance:
			best_distance = d
			best = villager
	return best


func _near_water() -> bool:
	if _fishing == null:
		return false
	var visual := _player.get_node("Visual") as Node3D
	var forward := Vector3.FORWARD.rotated(Vector3.UP, visual.global_rotation.y)
	for i in 12:
		var dir := forward.rotated(Vector3.UP, TAU * i / 12.0)
		for reach in [2.0, 4.0, LULLABY_WATER_REACH]:
			if _fishing.find_water_at(_player.global_position + dir * reach):
				return true
	return false


func _cheer_villagers() -> void:
	for node in get_tree().get_nodes_in_group(&"villagers"):
		var villager := node as Villager
		if villager and villager.global_position.distance_to(_player.global_position) < 8.0 and villager.has_method(&"cheer"):
			villager.call(&"cheer")


# ---- Input --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_ukulele"):
		if not _playing and _player.has_method(&"is_hands_busy") and _player.is_hands_busy():
			return
		if _playing or not _player.is_input_locked():
			toggle()
			get_viewport().set_input_as_handled()
		return
	if not _playing:
		return
	for n in range(1, 9):
		if event.is_action_pressed(StringName("uke_note_%d" % n)):
			play_note(n)
			get_viewport().set_input_as_handled()
			return


func _input(event: InputEvent) -> void:
	# Esc puts the ukulele away (instead of opening the pause menu) while playing.
	if _playing and event.is_action_pressed(&"toggle_mouse"):
		stop()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _playing or _instrument == null:
		return
	_place_instrument()


## Puts the ukulele across the body: body under the strumming (right) hand, neck
## reaching to the left hand, soundboard facing forward.
func _place_instrument() -> void:
	var visual := _player.get_node("Visual") as Node3D
	var forward := Vector3.FORWARD.rotated(Vector3.UP, visual.global_rotation.y)
	var right_side := forward.cross(Vector3.UP).normalized()
	var strum := _player.global_position + Vector3.UP * 0.75 + forward * 0.25
	var fret := strum - right_side * 0.45 + Vector3.UP * 0.12
	if _skeleton and _left_hand >= 0 and _right_hand >= 0:
		strum = _skeleton.global_transform * _skeleton.get_bone_global_pose(_right_hand).origin
		fret = _skeleton.global_transform * _skeleton.get_bone_global_pose(_left_hand).origin
	var neck := (fret - strum).normalized()
	var face := (forward - neck * forward.dot(neck)).normalized()
	var up := face.cross(neck).normalized()
	# Sized so the neck reaches the fretting hand.
	var size := clampf((fret - strum).length() / 0.4, 0.95, 1.35)
	var basis := Basis(neck * size, up * size, face * size)
	var origin := strum - neck * 0.07 * size - face * 0.06
	_instrument.global_transform = Transform3D(basis, origin)


# ---- HUD ----------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "UkuleleHUD"
	_hud.layer = 3
	_hud.visible = false
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	# Bottom: the eight keys.
	var bottom := PanelContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -96
	root.add_child(bottom)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	bottom.add_child(box)
	_recent_label = Label.new()
	_recent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recent_label.add_theme_font_size_override("font_size", 18)
	_recent_label.add_theme_color_override("font_color", UIPalette.WOOD)
	box.add_child(_recent_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for i in 8:
		var cap := PanelContainer.new()
		cap.theme_type_variation = &"KeyCap"
		cap.custom_minimum_size = Vector2(52, 58)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.pivot_offset = Vector2(26, 29)
		var labels := VBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_theme_constant_override("separation", -2)
		var number := Label.new()
		number.theme_type_variation = &"KeyLabel"
		number.text = str(i + 1)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 20)
		labels.add_child(number)
		var note_name := Label.new()
		note_name.text = NOTE_NAMES[i]
		note_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_name.add_theme_font_size_override("font_size", 13)
		note_name.add_theme_color_override("font_color", UIPalette.INK_SOFT)
		labels.add_child(note_name)
		cap.add_child(labels)
		row.add_child(cap)
		_keys.append(cap)
	var help := Label.new()
	help.theme_type_variation = &"SubtleLabel"
	help.text = "Keys 1-8 play  ·  U or Esc: put the ukulele away"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	box.add_child(help)

	# Right: Grandpa's song book.
	var book_panel := PanelContainer.new()
	book_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	book_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	book_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	book_panel.offset_right = -20
	book_panel.custom_minimum_size = Vector2(270, 0)
	root.add_child(book_panel)
	var book_box := VBoxContainer.new()
	book_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_box.add_theme_constant_override("separation", 6)
	book_panel.add_child(book_box)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "Grandpa's Songs"
	title.add_theme_font_size_override("font_size", 20)
	book_box.add_child(title)
	_book = VBoxContainer.new()
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_theme_constant_override("separation", 6)
	book_box.add_child(_book)


func _refresh_book() -> void:
	for child in _book.get_children():
		_book.remove_child(child)
		child.queue_free()
	for melody in MelodyCatalog.shared().melodies:
		var known := is_known(melody)
		var entry := VBoxContainer.new()
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_constant_override("separation", 0)
		var name_row := HBoxContainer.new()
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := Label.new()
		name_label.text = melody.title if known else "? ? ?"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", UIPalette.WOOD if known else UIPalette.INK_SOFT)
		name_row.add_child(name_label)
		if known:
			var notes := Label.new()
			notes.text = melody.notes_text()
			notes.theme_type_variation = &"KeyLabel"
			notes.add_theme_font_size_override("font_size", 16)
			name_row.add_child(notes)
		entry.add_child(name_row)
		var info := Label.new()
		info.text = melody.description if known else melody.hint
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(250, 0)
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", UIPalette.INK_SOFT)
		entry.add_child(info)
		_book.add_child(entry)


func _refresh_recent() -> void:
	var names: Array[String] = []
	for n in _recent:
		names.append(str(n))
	_recent_label.text = "♪  " + ("  ".join(names) if not names.is_empty() else "play something…")


func _flash_key(note: int) -> void:
	var cap := _keys[note - 1]
	cap.scale = Vector2(1.12, 1.12)
	cap.modulate = Color(1.0, 0.9, 0.6)
	var tween := cap.create_tween().set_parallel(true)
	tween.tween_property(cap, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_property(cap, "modulate", Color.WHITE, 0.3)


## Song book contents (for tests): [[title or "? ? ?", known], ...].
func get_book_entries() -> Array:
	var entries := []
	for melody in MelodyCatalog.shared().melodies:
		entries.append([melody.title if is_known(melody) else "? ? ?", is_known(melody)])
	return entries


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "ukulele"


func save_state() -> Dictionary:
	return {"rain_day": _rain_day}


func load_state(data: Dictionary) -> void:
	_rain_day = int(data.get("rain_day", 0))
