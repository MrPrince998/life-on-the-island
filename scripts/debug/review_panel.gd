class_name ReviewPanel
extends CanvasLayer

var _root: Control
var _status: Label
var _banner: Label
var _first: Button
var _items: OptionButton
var _quests: OptionButton
var _item_ids: Array[StringName] = []
var _quest_ids: Array[StringName] = []
var _was_paused := false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	_banner.visible = ReviewCheats.is_active()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8:
		if _root.visible: close()
		else: open()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed(&"toggle_mouse"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if _root.visible: return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player and (player.is_input_locked() or player.is_driving()):
		GameManager.notify("Finish the current action, leave the tractor, or close the window before opening review cheats.")
		return
	var pause := get_parent().get_node_or_null("PauseMenu") as PauseMenu
	if pause and pause.is_open(): pause.resume()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.show()
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_quests()
	_first.grab_focus()

func close() -> void:
	_root.hide()
	get_tree().paused = _was_paused
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _was_paused else Input.MOUSE_MODE_CAPTURED

func _result(message: String) -> void:
	_status.text = message
	_banner.visible = ReviewCheats.is_active()
	_refresh_quests()

func _refresh_quests() -> void:
	_quests.clear()
	_quest_ids.clear()
	for quest in QuestLog.get_active_quests():
		_quests.add_item(quest.title)
		_quest_ids.append(quest.id)

func _travel(group: StringName) -> void:
	if not ReviewCheats.begin(): return
	var destination: Node3D
	match group:
		&"village": destination = get_parent().get_node("Island/SpawnPoint")
		&"farm": destination = get_tree().get_first_node_in_group(&"farm_field")
		&"tractor": destination = get_tree().get_first_node_in_group(&"tractor")
		_:
			for npc in get_tree().get_nodes_in_group(&"villagers"):
				if npc.data.id == group: destination = npc; break
	if destination == null:
		_result("Destination unavailable.")
		return
	var pos := destination.global_position + Vector3(0, 0, 4)
	pos.y = IslandShape.shared().get_height(pos.x, pos.z) + 0.3
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	player.teleport_to(pos, 0.0)
	_result("Travelled to " + String(group).capitalize() + ". Close this menu to explore.")

func _button(parent: Node, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _heading(parent: Node, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)

func _grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _build() -> void:
	_banner = Label.new()
	_banner.text = "REVIEW SAVE · F8 cheats · normal save protected"
	_banner.position = Vector2(380, 8)
	_banner.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	add_child(_banner)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_heading(box, "Review cheats · F8")
	var note := Label.new()
	note.text = "The first cheat saves your normal progress and creates a separate review save.\nMain menu / restart returns to your normal save. Chapter shortcuts only move forward."
	note.add_theme_font_size_override("font_size", 16)
	box.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 300.0, 180.0, 430.0)
	get_viewport().size_changed.connect(func() -> void: scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 300.0, 180.0, 430.0))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_heading(content, "Supplies")
	var supplies := _grid(content)
	_first = _button(supplies, "+10,000 coins", func() -> void: _result(ReviewCheats.money()))
	_button(supplies, "Tools + seeds", func() -> void: _result(ReviewCheats.tools()))
	_items = OptionButton.new()
	_items.custom_minimum_size.x = 230
	_items.fit_to_longest_item = false
	for item in ItemDB.all_items():
		_items.add_item(item.display_name)
		_item_ids.append(item.id)
	supplies.add_child(_items)
	_button(supplies, "Give selected item ×20", func() -> void: _result(ReviewCheats.give_item(_item_ids[_items.selected])))
	_button(supplies, "Repair tractor", func() -> void: _result(ReviewCheats.restore_tractor()))
	_heading(content, "Farming and time")
	var farm := _grid(content)
	_button(farm, "Plant empty beds / fields", func() -> void: _result(ReviewCheats.prepare_fields(get_tree())))
	_button(farm, "Ripen planted crops", func() -> void: _result(ReviewCheats.ready_crops(get_tree())))
	for hours in [1, 6, 24]:
		_button(farm, "+1 hour" if hours == 1 else "+%d hours" % hours, func() -> void: _result(ReviewCheats.advance(hours * 60)))
	for hour in [6, 12, 20, 23]:
		_button(farm, "Next %02d:00" % hour, func() -> void: _result(ReviewCheats.advance(ActivityClock.minutes_until(hour))))
	_heading(content, "Weather")
	var weather := _grid(content)
	for i in 4:
		_button(weather, ["Sunny", "Cloudy", "Rain", "Snow"][i], func() -> void: _result(ReviewCheats.weather(i)))
	_heading(content, "Story shortcuts (spoilers)")
	var story := _grid(content)
	for i in range(1, 6):
		_button(story, "Unlock chapter %d" % i if i < 5 else "Unlock finale", func() -> void: _result(ReviewCheats.chapter(i)))
	_quests = OptionButton.new()
	_quests.custom_minimum_size.x = 230
	_quests.fit_to_longest_item = false
	story.add_child(_quests)
	_button(story, "Complete selected quest", func() -> void:
		if _quests.selected >= 0: _result(ReviewCheats.finish_quest(_quest_ids[_quests.selected])))
	_heading(content, "Travel to places / villagers")
	var travel := _grid(content)
	for id in [&"village", &"farm", &"oliver", &"mia", &"theo", &"emma", &"luna", &"tractor"]:
		_button(travel, String(id).capitalize(), _travel.bind(id))
	_status = Label.new()
	_status.text = "Choose a shortcut to start reviewing."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 44
	box.add_child(_status)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	_button(footer, "Close · F8 / Esc", close)
	_button(footer, "Return to normal game (title)", func() -> void:
		SaveManager.save_game("leave_review")
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
