class_name RequestBoardPanel
extends CanvasLayer
## The notice board screen: today's villager requests (RequestBoard), each with its
## reward and a "Take request" button, plus the requests you're helping with.
## Reading and taking requests costs no time. Esc, E or the Close button closes it.

const ICON_SIZE := Vector2(56, 56)

var _root: Control
var _subtitle: Label
var _note: Label
var _cards: VBoxContainer
var _active_title: Label
var _active_list: VBoxContainer
var _opened_at := 0


func _ready() -> void:
	add_to_group(&"request_board_panel")
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	RequestBoard.board_changed.connect(func() -> void:
		if is_open():
			_refresh())


func is_open() -> bool:
	return _root.visible


func open(_interactor: Node = null) -> void:
	if is_open():
		return
	var player := _player()
	if player and player.is_input_locked():
		return
	_opened_at = Engine.get_process_frames()
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	RequestBoard.mark_read()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	var player := _player()
	if player:
		player.set_input_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Takes a request (the button does this). Returns RequestBoard.accept()'s result.
func take(request_id: StringName) -> Dictionary:
	var result := RequestBoard.accept(request_id)
	if result.get("ok", false):
		var quest: QuestData = result["quest"]
		_note.text = "You promised to help %s. Bring the things to them whenever you're ready." % quest.giver
	else:
		_note.text = String(result.get("reason", ""))
	_refresh(false)
	return result


## Request ids on the cards right now (for tests).
func get_card_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in _cards.get_children():
		if card.has_meta(&"request_id"):
			ids.append(card.get_meta(&"request_id"))
	return ids


func get_note() -> String:
	return _note.text


func _input(event: InputEvent) -> void:
	if not is_open() or Engine.get_process_frames() - _opened_at < 2:
		return
	if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		close()


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Content --------------------------------------------------------------------

func _refresh(reset_note: bool = true) -> void:
	var done := RequestBoard.completed
	_subtitle.text = "Requests finished: %d" % done if done > 0 else "Little jobs for kind neighbours"
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var requests := RequestBoard.get_requests()
	var active := RequestBoard.get_active()
	var full := active.size() >= RequestBoard.MAX_ACTIVE
	for request in requests:
		_cards.add_child(_card(request, full))
	if reset_note:
		var empty := RequestBoard.get_empty_reason()
		if not empty.is_empty():
			_note.text = empty
		elif full:
			_note.text = "You're helping with %d requests already. Finish one, then come back!" % RequestBoard.MAX_ACTIVE
		else:
			_note.text = "Pick anything you'd like to help with. There's no rush: requests never run out of time once you take them."
	_cards.visible = not requests.is_empty()
	for child in _active_list.get_children():
		_active_list.remove_child(child)
		child.queue_free()
	_active_title.text = "Helping with (%d of %d)" % [active.size(), RequestBoard.MAX_ACTIVE]
	_active_title.visible = not active.is_empty()
	_active_list.visible = not active.is_empty()
	for quest in active:
		var line := Label.new()
		var progress := QuestLog.get_step_progress(quest.id)
		var ready := progress.x >= progress.y
		line.text = "•  %s   %s" % [quest.title, "(ready: talk to %s)" % quest.giver if ready else "(%d of %d)" % [progress.x, progress.y]]
		line.add_theme_font_size_override("font_size", 16)
		if ready:
			line.add_theme_color_override("font_color", UIPalette.LEAF.darkened(0.25))
		_active_list.add_child(line)


func _card(request: Dictionary, full: bool) -> Control:
	var item_id := StringName(str(request.get("item")))
	var amount := int(request.get("amount", 1))
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.set_meta(&"request_id", StringName(str(request.get("id"))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _icon_for(item_id)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var text := Label.new()
	text.text = str(request.get("text", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 18)
	texts.add_child(text)
	var have := InventoryManager.get_count(item_id)
	var reward := Label.new()
	reward.theme_type_variation = &"SubtleLabel"
	reward.add_theme_font_size_override("font_size", 15)
	reward.text = "Reward: %d coins and friendship   ·   You have %d of %d" % [int(request.get("coins", 0)), mini(have, amount), amount]
	texts.add_child(reward)
	row.add_child(texts)
	var button := Button.new()
	button.text = "Take request"
	button.disabled = full
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var request_id := StringName(str(request.get("id")))
	button.pressed.connect(func() -> void: take(request_id))
	row.add_child(button)
	return card


func _icon_for(item_id: StringName) -> Texture2D:
	var item := ItemDB.get_item(item_id)
	if item and item.icon:
		return item.icon
	if item == null:
		return UIPalette.icon("bag")
	match item.category:
		ItemData.Category.FISH:
			return UIPalette.icon("fish")
		ItemData.Category.FOOD:
			return UIPalette.icon("bread")
		ItemData.Category.MATERIAL:
			return UIPalette.icon("plank")
	return UIPalette.icon("leaf")


# ---- Layout ---------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.04, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(760, 0)
	center.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	window.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var board_icon := TextureRect.new()
	board_icon.texture = UIPalette.icon("book")
	board_icon.custom_minimum_size = Vector2(36, 36)
	board_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(board_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.text = "Village Notice Board"
	names.add_child(title)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"SubtleLabel"
	_subtitle.add_theme_font_size_override("font_size", 15)
	names.add_child(_subtitle)
	header.add_child(names)
	box.add_child(header)
	box.add_child(HSeparator.new())

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 16)
	box.add_child(_note)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	box.add_child(_cards)
	_active_title = Label.new()
	_active_title.theme_type_variation = &"HeaderLabel"
	_active_title.add_theme_font_size_override("font_size", 19)
	box.add_child(_active_title)
	_active_list = VBoxContainer.new()
	_active_list.add_theme_constant_override("separation", 2)
	box.add_child(_active_list)

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 44)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	box.add_child(footer)
