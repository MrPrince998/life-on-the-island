extends Node
## Interface sounds, everywhere at once (autoload "UISounds"): soft wooden marimba
## clicks for buttons, a tick when the pointer or the keyboard/controller moves onto one,
## a muted "bonk" for a button you can't use yet, ticks for sliders, gentle chimes when a
## panel opens and closes (the journal opens and shuts like a book and turns its pages),
## coins when money comes in or goes out, chimes for a new quest, a finished step and a
## finished quest, a sweet chime for a new friendship heart, a soft blip for messages and
## a hummed "mm" for each line a villager says.
##
## It finds buttons, sliders, tabs, panels and villagers by itself as they are added to
## the scene tree, so menus don't need any sound code. It only listens and plays: it
## never changes the clock or the game. All sounds play on the Effects bus.

signal played(sound: StringName)

const DIR := "res://assets/audio/ui/"
const SOUNDS: Array[StringName] = [
	&"hover", &"click", &"back", &"deny", &"slider", &"open", &"close", &"book_open",
	&"book_close", &"page", &"coin_gain", &"coin_spend", &"quest_new", &"quest_step",
	&"quest_done", &"heart", &"notify", &"talk",
]
const DB := {
	&"hover": -20.0, &"click": -12.0, &"back": -12.0, &"deny": -12.0, &"slider": -18.0,
	&"open": -12.0, &"close": -13.0, &"book_open": -9.0, &"book_close": -10.0, &"page": -10.0,
	&"coin_gain": -10.0, &"coin_spend": -11.0, &"quest_new": -8.0, &"quest_step": -9.0,
	&"quest_done": -6.0, &"heart": -8.0, &"notify": -19.0, &"talk": -15.0,
}
## The same sound never repeats faster than this (seconds).
const MIN_GAP := {
	&"hover": 0.05, &"slider": 0.05, &"talk": 0.08, &"notify": 0.4, &"page": 0.08,
	&"click": 0.03, &"coin_gain": 0.12, &"coin_spend": 0.12,
}
## Buttons whose words mean "go back" get the lower click.
const BACK_WORDS: Array[String] = ["back", "close", "resume", "cancel", "leave", "quit", "not now"]
## No coin or message sounds for this long after the island loads (loading a save
## sets the money and posts messages).
const LOAD_QUIET_MS := 1500

## Off: everything stays silent (nothing else changes).
var enabled: bool = true

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
var _last_ms: Dictionary = {}
var _last_any_ms: int = -100000
var _quiet_until_ms: int = 0
var _money: int = 0
var _panels: Array = []           # [panel, was_open (or null before its first look)]
var _panel_changed_ms: int = -100000
var _last_click_voice: AudioStreamPlayer
var _last_click_ms: int = -100000
var _nav_input_ms: int = -100000
var _pending_focus: bool = false
var _pending_step: bool = false
var _pending_done: bool = false
var _loading: bool = false
var _pending_new: bool = false
var _hush_until_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		p.bus = &"Effects"
		add_child(p)
		_voices.append(p)
	_money = InventoryManager.get_money()
	get_tree().node_added.connect(_on_node_added)
	_watch_all(get_tree().root)
	InventoryManager.money_changed.connect(_on_money_changed)
	QuestLog.quest_announced.connect(func(_q: QuestData) -> void: _pending_new = true)
	QuestLog.step_completed.connect(func(_q: QuestData, _i: int) -> void: _pending_step = true)
	QuestLog.quest_completed.connect(func(_q: QuestData) -> void: _pending_done = true)
	Friendship.heart_gained.connect(func(_id: StringName, _h: int) -> void: play(&"heart"))
	GameManager.notification_posted.connect(_on_notification)


## Plays one interface sound (see SOUNDS). `pitch` 1 = as recorded.
func play(sound: StringName, pitch: float = 1.0) -> AudioStreamPlayer:
	if not enabled:
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sound, -100000)) < int(float(MIN_GAP.get(sound, 0.0)) * 1000.0):
		return null
	var stream := _stream(sound)
	if stream == null:
		return null
	_last_ms[sound] = now
	_last_any_ms = now
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.volume_db = float(DB.get(sound, -12.0))
	p.pitch_scale = pitch * randf_range(0.98, 1.02)
	p.play()
	played.emit(sound)
	return p


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _loading:
		# The first frame after the island loaded: stay quiet a little longer.
		_loading = false
		_quiet_until_ms = now + LOAD_QUIET_MS
		_money = InventoryManager.get_money()
	# Quests: a finished quest's fanfare replaces the chime for its last step.
	# (A story moment's music, playing now, says it all: then they stay quiet.)
	if not _hushed():
		if _pending_done:
			play(&"quest_done")
		elif _pending_step:
			play(&"quest_step")
		elif _pending_new:
			play(&"quest_new")
	_pending_done = false
	_pending_step = false
	_pending_new = false
	# Panels opening and closing.
	var keep: Array = []
	for entry: Array in _panels:
		if not is_instance_valid(entry[0]):
			continue
		var panel: Node = entry[0]
		if not panel.is_inside_tree():
			continue
		keep.append(entry)
		if not panel.is_node_ready():
			continue
		var open := bool(panel.call(&"is_open"))
		if entry[1] != null and open != bool(entry[1]):
			_panel_changed_ms = now
			# The panel's own sound replaces the click of the button that opened/closed it.
			if _last_click_voice and now - _last_click_ms < 150:
				_last_click_voice.stop()
			if panel is JournalPanel:
				play(&"book_open" if open else &"book_close")
			else:
				play(&"open" if open else &"close")
		entry[1] = open
	_panels = keep
	# Keyboard / controller focus moving onto a button (not focus grabbed by a panel opening).
	if _pending_focus:
		_pending_focus = false
		if now - _panel_changed_ms > 300 and now - _last_click_ms > 100:
			play(&"hover")


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_nav_input_ms = Time.get_ticks_msec()


# ---------------------------------------------------------------- finding things to hear

func _watch_all(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_watch_all(child)


func _on_node_added(node: Node) -> void:
	# A node moved to a new parent is "added" again: hook it only once.
	if node.has_meta(&"ui_sounds_hooked"):
		return
	if node is BaseButton or node is Slider or node is TabBar or node is TabContainer or node is Villager or node is CanvasLayer:
		node.set_meta(&"ui_sounds_hooked", true)
	if node is BaseButton:
		_hook_button(node as BaseButton)
	elif node is Slider:
		var slider := node as Slider
		slider.value_changed.connect(func(value: float) -> void:
			# Only the player's own changes (refreshing a screen sets values silently).
			if slider.has_focus() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				var span := maxf(slider.max_value - slider.min_value, 0.0001)
				play(&"slider", 0.85 + 0.4 * (value - slider.min_value) / span))
	elif node is TabBar:
		(node as TabBar).tab_changed.connect(func(_t: int) -> void: play(&"page"))
	elif node is TabContainer:
		(node as TabContainer).tab_changed.connect(func(_t: int) -> void: play(&"page"))
	if node is Villager:
		var villager := node as Villager
		villager.line_shown.connect(func(npc_name: String, _text: String) -> void:
			# Each villager hums at their own pitch.
			play(&"talk", 0.85 + float(absi(npc_name.hash()) % 9) * 0.05))
	if node is PlayerController:
		# Quiet from now until a moment after the island has finished loading.
		_loading = true
		_quiet_until_ms = 1 << 62
	if node is CanvasLayer and node.has_method(&"is_open"):
		_panels.append([node, null])


func _hook_button(button: BaseButton) -> void:
	button.pressed.connect(func() -> void: _on_button_pressed(button))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.is_visible_in_tree():
			play(&"hover"))
	button.focus_entered.connect(func() -> void:
		if Time.get_ticks_msec() - _nav_input_ms < 250:
			_pending_focus = true)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if button.disabled and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			play(&"deny"))
	if button is OptionButton:
		(button as OptionButton).item_selected.connect(func(_i: int) -> void: play(&"click"))


func _on_button_pressed(button: BaseButton) -> void:
	var sound := &"click"
	if button.toggle_mode and _inside(button, "JournalPanel"):
		sound = &"page"
	elif is_back_button(button):
		sound = &"back"
	var voice := play(sound)
	if voice:
		_last_click_voice = voice
		_last_click_ms = Time.get_ticks_msec()


## True for Back / Close / Resume / Cancel... buttons (by their words or node name).
static func is_back_button(button: BaseButton) -> bool:
	var words := String(button.name).to_lower()
	if button is Button:
		words += " " + (button as Button).text.to_lower()
	for word in BACK_WORDS:
		if words.contains(word):
			return true
	return false


func _inside(node: Node, class_id: String) -> bool:
	var n := node.get_parent()
	while n:
		var s := n.get_script() as Script
		if s and s.get_global_name() == class_id:
			return true
		n = n.get_parent()
	return false


# ---------------------------------------------------------------- game events

func _on_money_changed(total: int) -> void:
	var change := total - _money
	_money = total
	if _loading or change == 0 or _quiet() or get_tree().get_first_node_in_group(&"player") == null:
		return
	play(&"coin_gain" if change > 0 else &"coin_spend")


## Holds back the quest chimes and message blips for a while (StorySounds calls this
## while one of its story moments plays).
func hush(seconds: float) -> void:
	_hush_until_ms = maxi(_hush_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))


func _hushed() -> bool:
	return Time.get_ticks_msec() < _hush_until_ms


func _on_notification(_text: String) -> void:
	# A soft blip, unless something else just made a sound for the same moment.
	if _quiet() or _hushed() or Time.get_ticks_msec() - _last_any_ms < 300:
		return
	play(&"notify")


func _quiet() -> bool:
	return Time.get_ticks_msec() < _quiet_until_ms


func _stream(sound: StringName) -> AudioStream:
	if not _streams.has(sound):
		_streams[sound] = load(DIR + String(sound) + ".wav") as AudioStream
	return _streams[sound]
