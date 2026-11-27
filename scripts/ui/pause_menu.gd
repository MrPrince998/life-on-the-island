class_name PauseMenu
extends CanvasLayer
## Pause menu: Esc during play freezes the game and shows Resume / Settings /
## Main menu / Quit (Settings also lists the controls). Esc again (or Resume) carries on.
##
## The bag and the store read Esc in _input and close themselves first, so the
## pause menu only opens when nothing else is on screen. Pausing never touches
## the ActivityClock: no in-game time passes while paused.

signal opened
signal closed

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

enum Page { MAIN, SETTINGS, CONFIRM }
enum Leave { MAIN_MENU, QUIT }

var _root: Control
var _pages: Dictionary = {}  # Page -> Control
var _page: int = Page.MAIN
var _leave: int = Leave.MAIN_MENU
var _resume_button: Button
var _settings: SettingsPanel
var _confirm_title: Label
var _confirm_body: Label
var _confirm_yes: Button
var _confirm_no: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func get_page() -> int:
	return _page


func open() -> void:
	if is_open():
		return
	_show_page(Page.MAIN)
	_root.show()
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.12)
	opened.emit()


func resume() -> void:
	if not is_open():
		return
	_root.hide()
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Asks before leaving (the island is saved first, so nothing is lost).
func ask_leave(to_main_menu: bool) -> void:
	_leave = Leave.MAIN_MENU if to_main_menu else Leave.QUIT
	_confirm_title.text = "Back to the main menu?" if to_main_menu else "Quit the game?"
	_confirm_yes.text = "Go to main menu" if to_main_menu else "Quit"
	_show_page(Page.CONFIRM)


func confirm_leave() -> void:
	SaveManager.save_game("leave")
	get_tree().paused = false
	if _leave == Leave.QUIT:
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_mouse"):
		if not is_open():
			open()
		elif _page != Page.MAIN:
			_show_page(Page.MAIN)
		else:
			resume()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed(&"ui_cancel"):
		if _page != Page.MAIN:
			_show_page(Page.MAIN)
		else:
			resume()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Alt-tabbing away pauses the game, so nothing is missed.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and DisplayServer.get_name() != "headless":
		if is_inside_tree() and get_tree().current_scene and get_tree().current_scene.get_node_or_null("Player"):
			open()


func _show_page(page: int) -> void:
	_page = page
	for key in _pages:
		(_pages[key] as Control).visible = key == page
	match page:
		Page.MAIN:
			_resume_button.grab_focus.call_deferred()
		Page.SETTINGS:
			_settings.refresh()
			_settings.focus_first.call_deferred()
		Page.CONFIRM:
			_confirm_no.grab_focus.call_deferred()


# ---------------------------------------------------------------- building

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(UIPalette.INK, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)

	_pages[Page.MAIN] = _build_main()
	_settings = SettingsPanel.new()
	_settings.back_pressed.connect(func() -> void: _show_page(Page.MAIN))
	_pages[Page.SETTINGS] = _settings
	_pages[Page.CONFIRM] = _build_confirm()
	for key in _pages:
		stack.add_child(_pages[key])


func _build_main() -> Control:
	var page := VBoxContainer.new()
	page.name = "MainPage"
	page.add_theme_constant_override("separation", -6)
	page.custom_minimum_size = Vector2(380, 0)

	var plaque_row := CenterContainer.new()
	page.add_child(plaque_row)
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"WoodPanel"
	plaque.z_index = 1
	plaque_row.add_child(plaque)
	var title := Label.new()
	title.theme_type_variation = &"WoodLabel"
	title.add_theme_font_size_override("font_size", 34)
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(200, 0)
	plaque.add_child(title)

	var card := PanelContainer.new()
	page.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	_resume_button = _button(box, "Resume", resume)
	_button(box, "Review cheats · F8", func() -> void: get_parent().get_node("ReviewPanel").open())
	_button(box, "Settings", func() -> void: _show_page(Page.SETTINGS))
	_button(box, "Main menu", func() -> void: ask_leave(true))
	_button(box, "Quit game", func() -> void: ask_leave(false))

	var note := Label.new()
	note.theme_type_variation = &"SubtleLabel"
	note.text = "The island waits for you. Time only moves when you do an activity."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(320, 0)
	box.add_child(note)
	return page


func _build_confirm() -> Control:
	var card := PanelContainer.new()
	card.name = "ConfirmPage"
	card.custom_minimum_size = Vector2(480, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	_confirm_title = Label.new()
	_confirm_title.theme_type_variation = &"HeaderLabel"
	box.add_child(_confirm_title)
	_confirm_body = Label.new()
	_confirm_body.text = "Your island is saved before you go. Choose Continue on the title screen to carry on right where you left off."
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.custom_minimum_size = Vector2(440, 0)
	box.add_child(_confirm_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_confirm_no = Button.new()
	_confirm_no.text = "Stay"
	_confirm_no.custom_minimum_size = Vector2(0, 52)
	_confirm_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_no.pressed.connect(func() -> void: _show_page(Page.MAIN))
	row.add_child(_confirm_no)
	_confirm_yes = Button.new()
	_confirm_yes.custom_minimum_size = Vector2(0, 52)
	_confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_yes.pressed.connect(confirm_leave)
	row.add_child(_confirm_yes)
	return card


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
