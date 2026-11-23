class_name SettingsPanel
extends PanelContainer
## The Settings window, shared by the main menu and the pause menu: options on the
## left (mouse sensitivity, master/music/ambience/effects volume, full screen), every
## control on the right.
## Changes apply and save immediately. "Back" (or Esc in the menus) returns to the
## menu that opened it.

signal back_pressed

## Key bindings shown in Settings → Controls (this is the game's controls list).
const CONTROLS := [
	["WASD", "Walk"], ["Mouse", "Look around"], ["Wheel", "Camera distance"],
	["Shift", "Sprint"], ["Space", "Jump"], ["E", "Interact / talk / farm"],
	["R", "Fishing rod in / out"], ["L-Click", "Cast, hook, reel"], ["R-Click", "Reel in"],
	["Q", "Choose seeds to plant"], ["G", "Give a villager a gift"], ["U", "Ukulele in / out"], ["J", "Journal"], ["1 – 8", "Play ukulele notes"], ["Tab / I", "Bag"], ["Esc", "Pause menu"],
]

var _sensitivity: HSlider
var _sensitivity_value: Label
var _volume: HSlider
var _volume_value: Label
## Music, Ambience and Effects: bus name -> [slider, value label]
var _bus_volumes := {}
var _fullscreen: CheckButton
var _back: Button


func _init() -> void:
	name = "SettingsPanel"
	custom_minimum_size = Vector2(900, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var header := Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.add_theme_font_size_override("font_size", 36)
	header.text = "Settings"
	box.add_child(header)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	box.add_child(columns)

	# ---- Options ----
	var options := VBoxContainer.new()
	options.name = "Options"
	options.add_theme_constant_override("separation", 16)
	options.custom_minimum_size = Vector2(420, 0)
	columns.add_child(options)
	options.add_child(_section("Options"))
	_sensitivity = _slider(GameSettings.MIN_SENSITIVITY, GameSettings.MAX_SENSITIVITY, 0.05)
	_sensitivity_value = Label.new()
	options.add_child(_row("Mouse sensitivity", _sensitivity, _sensitivity_value))
	_volume = _slider(0.0, 1.0, 0.05)
	_volume_value = Label.new()
	options.add_child(_row("Master volume", _volume, _volume_value))
	for bus: StringName in [&"Music", &"Ambience", &"Effects"]:
		var slider := _slider(0.0, 1.0, 0.05)
		slider.name = str(bus) + "Slider"
		var value := Label.new()
		options.add_child(_row(str(bus), slider, value))
		_bus_volumes[bus] = [slider, value]
		slider.value_changed.connect(func(v: float) -> void:
			GameSettings.set_volume(bus, v)
			_changed())
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Full screen"
	_fullscreen.custom_minimum_size = Vector2(0, 44)
	options.add_child(_fullscreen)
	var hint := Label.new()
	hint.theme_type_variation = &"SubtleLabel"
	hint.text = "Changes are saved straight away."
	options.add_child(hint)

	# ---- Controls ----
	var controls := VBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", 12)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(controls)
	controls.add_child(_section("Controls"))
	var grid := GridContainer.new()
	grid.name = "ControlsGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	controls.add_child(grid)
	for row in CONTROLS:
		var cap := PanelContainer.new()
		cap.theme_type_variation = &"KeyCap"
		cap.size_flags_horizontal = Control.SIZE_SHRINK_END
		var key := Label.new()
		key.theme_type_variation = &"KeyLabel"
		key.add_theme_font_size_override("font_size", 15)
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_child(key)
		grid.add_child(cap)
		var what := Label.new()
		what.text = row[1]
		what.add_theme_font_size_override("font_size", 16)
		grid.add_child(what)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(back_row)
	_back = Button.new()
	_back.name = "BackButton"
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(220, 56)
	_back.add_theme_font_size_override("font_size", 24)
	back_row.add_child(_back)

	refresh()
	_sensitivity.value_changed.connect(_on_sensitivity)
	_volume.value_changed.connect(_on_volume)
	_fullscreen.toggled.connect(_on_fullscreen)
	_back.pressed.connect(func() -> void: back_pressed.emit())


## Shows the current values (call when the panel is opened).
func refresh() -> void:
	_sensitivity.set_value_no_signal(GameSettings.mouse_sensitivity)
	_volume.set_value_no_signal(GameSettings.master_volume)
	for bus: StringName in _bus_volumes:
		(_bus_volumes[bus][0] as HSlider).set_value_no_signal(GameSettings.get_volume(bus))
	_fullscreen.set_pressed_no_signal(GameSettings.fullscreen)
	_update_labels()


func focus_first() -> void:
	_sensitivity.grab_focus()


func _section(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.add_theme_font_size_override("font_size", 22)
	label.text = text
	return label


func _row(text: String, slider: HSlider, value_label: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(160, 32)
	row.add_child(slider)
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


func _slider(min_value: float, max_value: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	return s


func _update_labels() -> void:
	_sensitivity_value.text = "%.2f×" % GameSettings.mouse_sensitivity
	_volume_value.text = "%d%%" % roundi(GameSettings.master_volume * 100.0)
	for bus: StringName in _bus_volumes:
		(_bus_volumes[bus][1] as Label).text = "%d%%" % roundi(GameSettings.get_volume(bus) * 100.0)


func _on_sensitivity(value: float) -> void:
	GameSettings.mouse_sensitivity = value
	_changed()


func _on_volume(value: float) -> void:
	GameSettings.master_volume = value
	_changed()


func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	_changed()


func _changed() -> void:
	GameSettings.apply()
	GameSettings.save_to()
	_update_labels()
