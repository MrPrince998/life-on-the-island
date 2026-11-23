class_name TitleScreen
extends Node3D
## The first thing the player sees: the real island, slowly circled by a camera,
## with the game's name. Any key opens the main menu (New game / Settings / Quit).
## The game scene loads in the background while the menu is up.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const ISLAND_SCENE := preload("res://scenes/world/island.tscn")

## Camera orbit around the village and Moonlit Lake (purely visual, real time).
const ORBIT_CENTRE := Vector3(5, 4, 65)
const ORBIT_RADIUS := 150.0
const ORBIT_HEIGHT := 55.0
const ORBIT_SPEED := 0.025  # radians per second

enum State { TITLE, MENU, SETTINGS, LOADING }

var _state: int = State.TITLE
var _orbit_angle := atan2(85.0, -65.0)
var _camera: Camera3D
var _press_row: Control
var _menu: VBoxContainer
var _continue_button: Button
var _new_game_button: Button
var _settings: SettingsPanel
var _settings_screen: Control
var _column: Control
var _loading: Control
var _press_tween: Tween
## Line under Continue: when the save is from, or "No saved game yet".
var _save_info: Label
## New game asks once more when it would replace a saved island.
var _confirm_new_game: bool = false


## Puts every global system back to a brand-new game. (Continue then loads a save on top.)
static func reset_game_state() -> void:
	SaveManager.clear_pending_world()
	GameManager.reset_flags()
	ActivityClock.reset()
	InventoryManager.reset()
	Journal.clear()
	WeatherManager.reset()
	Friendship.reset()
	QuestLog.reset()


func _ready() -> void:
	GameSettings.ensure_loaded()
	get_tree().paused = false
	reset_game_state()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH, "PackedScene", true)

	var island := ISLAND_SCENE.instantiate()
	island.name = "Island"
	add_child(island)
	_camera = Camera3D.new()
	_camera.name = "OrbitCamera"
	_camera.fov = 55.0
	_camera.far = 3000.0
	add_child(_camera)
	_camera.make_current()
	_place_camera()
	_build_ui()
	_set_state(State.TITLE)


func get_state() -> int:
	return _state


## Leaves the title card and shows the main menu buttons.
func show_menu() -> void:
	_set_state(State.MENU)


func open_settings() -> void:
	_set_state(State.SETTINGS)


func _exit_tree() -> void:
	# Collect the background-loaded game scene if nobody used it (avoids a leak).
	if ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(MAIN_SCENE_PATH)


func start_new_game() -> void:
	if _state == State.LOADING:
		return
	# Starting over replaces the saved island, so ask once.
	if SaveManager.has_save() and not _confirm_new_game:
		_confirm_new_game = true
		_new_game_button.text = "Replace saved island?"
		return
	_set_state(State.LOADING)
	reset_game_state()
	OpeningScene.request()
	await _go_to_island()


## Loads the saved game (falls back to the backup if the save is damaged).
func continue_game() -> void:
	if _state == State.LOADING:
		return
	var data := SaveManager.read_latest()
	if data.is_empty():
		_refresh_save_info()
		return
	_set_state(State.LOADING)
	reset_game_state()
	SaveManager.load_into_game(data)
	await _go_to_island()


func _refresh_save_info() -> void:
	var summary := SaveManager.get_save_summary()
	_continue_button.disabled = summary.is_empty()
	_continue_button.tooltip_text = "" if summary.is_empty() else "Carry on from where you left off."
	_save_info.text = "No saved game yet" if summary.is_empty() else summary
	_confirm_new_game = false
	_new_game_button.text = "New game"


func _go_to_island() -> void:
	# Let the "Heading to the island…" card draw before the scene switch.
	await get_tree().process_frame
	await get_tree().process_frame
	var packed: PackedScene = null
	while ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		packed = load(MAIN_SCENE_PATH) as PackedScene
	get_tree().change_scene_to_packed(packed)


func _process(delta: float) -> void:
	_orbit_angle += ORBIT_SPEED * delta
	_place_camera()


func _place_camera() -> void:
	var offset := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * ORBIT_RADIUS
	_camera.look_at_from_position(ORBIT_CENTRE + offset + Vector3.UP * ORBIT_HEIGHT, ORBIT_CENTRE + Vector3.DOWN * 6.0)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	match _state:
		State.TITLE:
			if pressed:
				show_menu()
				get_viewport().set_input_as_handled()
		State.SETTINGS:
			if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"ui_cancel"):
				_set_state(State.MENU)
				get_viewport().set_input_as_handled()


func _set_state(state: int) -> void:
	_state = state
	_press_row.visible = state == State.TITLE
	_menu.visible = state == State.MENU
	_settings_screen.visible = state == State.SETTINGS
	_column.visible = state != State.SETTINGS
	_loading.visible = state == State.LOADING
	if _press_tween:
		_press_tween.kill()
		_press_tween = null
	match state:
		State.TITLE:
			_press_row.modulate.a = 1.0
			_press_tween = create_tween().set_loops()
			_press_tween.tween_property(_press_row, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
			_press_tween.tween_property(_press_row, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		State.MENU:
			_menu.modulate.a = 0.0
			create_tween().tween_property(_menu, "modulate:a", 1.0, 0.2)
			var first := _new_game_button if _continue_button.disabled else _continue_button
			first.grab_focus.call_deferred()
		State.SETTINGS:
			_settings.refresh()
			_settings.focus_first.call_deferred()


# ---------------------------------------------------------------- building

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Soft shade on the left so the name and buttons read over the bright island.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UIPalette.INK, 0.6))
	gradient.set_color(1, Color(UIPalette.INK, 0.0))
	gradient.set_offset(1, 0.62)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 4
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var column := VBoxContainer.new()
	_column = column
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	column.add_child(_title_label("Life on the", 40, 10))
	var island_label := _title_label("Island", 128, 22)
	island_label.name = "GameTitle"
	column.add_child(island_label)
	column.add_child(_title_label("A cozy island, at your own pace.", 24, 8))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 44)
	column.add_child(gap)

	# Title card: "Press any key".
	_press_row = HBoxContainer.new()
	_press_row.name = "PressAnyKey"
	_press_row.add_theme_constant_override("separation", 14)
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"KeyCap"
	var cap_label := Label.new()
	cap_label.theme_type_variation = &"KeyLabel"
	cap_label.text = "Any key"
	cap.add_child(cap_label)
	_press_row.add_child(cap)
	_press_row.add_child(_title_label("Press any key to begin", 28, 8))
	column.add_child(_press_row)

	# Main menu.
	_menu = VBoxContainer.new()
	_menu.name = "MainMenu"
	_menu.add_theme_constant_override("separation", 14)
	_menu.custom_minimum_size = Vector2(340, 0)
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_menu)
	_continue_button = _menu_button("Continue", continue_game)
	_continue_button.name = "ContinueButton"
	_save_info = _title_label("No saved game yet", 17, 6)
	_menu.add_child(_save_info)
	_new_game_button = _menu_button("New game", start_new_game)
	_new_game_button.name = "NewGameButton"
	_refresh_save_info()
	_menu_button("Settings", func() -> void: _set_state(State.SETTINGS))
	_menu_button("Quit", func() -> void: get_tree().quit())

	# Settings: its own window over a dimmed island; Back returns to the menu.
	_settings_screen = Control.new()
	_settings_screen.name = "SettingsScreen"
	_settings_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_settings_screen)
	var dim := ColorRect.new()
	dim.color = Color(UIPalette.INK, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_screen.add_child(dim)
	var settings_center := CenterContainer.new()
	settings_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_screen.add_child(settings_center)
	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(func() -> void: _set_state(State.MENU))
	settings_center.add_child(_settings)

	# "Heading to the island…" card while the game scene opens.
	_loading = CenterContainer.new()
	_loading.name = "Loading"
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_loading)
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"WoodPanel"
	_loading.add_child(plaque)
	var loading_label := Label.new()
	loading_label.theme_type_variation = &"WoodLabel"
	loading_label.add_theme_font_size_override("font_size", 30)
	loading_label.text = "Heading to the island…"
	plaque.add_child(loading_label)

	var build := _title_label("Prototype build", 16, 6)
	build.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	build.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build.offset_right = -28
	build.offset_bottom = -24
	root.add_child(build)


func _title_label(text: String, font_size: int, outline: int) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"TitleLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_constant_override("shadow_outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 60)
	b.add_theme_font_size_override("font_size", 26)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	_menu.add_child(b)
	return b
