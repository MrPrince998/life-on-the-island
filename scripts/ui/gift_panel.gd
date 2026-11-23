class_name GiftPanel
extends CanvasLayer
## The gift screen (G next to a villager): pick something from your bag to give.
## One gift per villager per day; their reaction shows in their speech bubble.
## Giving gifts costs no time. Esc, G or Tab closes it.

const COLUMNS := 6
const SLOT_SIZE := Vector2(72, 72)

var _root: Control
var _window: PanelContainer
var _title: Label
var _role: Label
var _hearts: HBoxContainer
var _grid: GridContainer
var _detail: Label
var _give_button: Button
var _note: Label
var _villager: Villager
var _items: Array = []
var _selected: StringName = &""


func _ready() -> void:
	add_to_group(&"gift_panel")
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func get_villager() -> Villager:
	return _villager


## Item ids offered right now (for tests).
func get_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for pair in _items:
		ids.append(pair[0])
	return ids


func open_for(villager: Villager, _interactor: Node = null) -> void:
	if villager == null or villager.data == null or is_open():
		return
	var player := _player()
	if player and player.is_input_locked():
		return
	_villager = villager
	_selected = &""
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	var player := _player()
	if player:
		player.set_input_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Gives one of this item to the villager and closes the screen. Returns the result.
func give(item_id: StringName) -> Dictionary:
	if _villager == null:
		return {"ok": false, "reason": "nobody"}
	var villager := _villager
	var result := Friendship.give_gift(villager.data, item_id)
	if result.get("ok", false):
		close()
		villager.react_to_gift(result)
	elif result.has("line"):
		_note.text = String(result["line"])
	return result


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"give_gift") or event.is_action_pressed(&"toggle_bag"):
		get_viewport().set_input_as_handled()
		close()


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Content --------------------------------------------------------------------

func _refresh() -> void:
	var npc := _villager.data
	_title.text = "A gift for %s" % npc.display_name
	_role.text = npc.role
	var full := Friendship.get_hearts(npc.id)
	for i in _hearts.get_child_count():
		(_hearts.get_child(i) as TextureRect).texture = UIPalette.icon("heart" if i < full else "heart_empty")
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_items = Friendship.get_giftable_items()
	var gifted := Friendship.gifted_today(npc.id)
	if gifted:
		_note.text = "%s already has a gift from you today. Come back tomorrow!" % npc.display_name
	elif _items.is_empty():
		_note.text = "Nothing to give yet. Fish, crops and goods from the store all make nice gifts."
	else:
		_note.text = "Everyone has favourites. See what makes %s smile." % npc.display_name
	for pair in _items:
		_grid.add_child(_slot(pair[0], int(pair[1]), gifted))
	_grid.visible = not _items.is_empty()
	_select(&"")


func _slot(item_id: StringName, count: int, locked: bool) -> Button:
	var slot := Button.new()
	slot.theme_type_variation = &"SlotButton"
	slot.custom_minimum_size = SLOT_SIZE
	slot.disabled = locked
	slot.tooltip_text = ItemDB.get_display_name(item_id)
	slot.pressed.connect(func() -> void: _select(item_id))
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 8
	icon.offset_right = -12
	icon.offset_bottom = -16
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _icon_for(item_id)
	slot.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"KeyLabel"
	label.text = str(count)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", UIPalette.CREAM)
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.offset_left = -40
	label.offset_top = -24
	label.offset_right = -6
	label.offset_bottom = -2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	return slot


func _select(item_id: StringName) -> void:
	_selected = item_id
	if item_id == &"":
		_detail.text = "Choose something to give."
		_give_button.disabled = true
		return
	_detail.text = ItemDB.get_display_name(item_id)
	_give_button.disabled = Friendship.gifted_today(_villager.data.id)


func _icon_for(item_id: StringName) -> Texture2D:
	var item := ItemDB.get_item(item_id)
	if item and item.icon:
		return item.icon
	if item == null:
		return UIPalette.icon("bag")
	match item.category:
		ItemData.Category.FISH:
			return UIPalette.icon("fish")
		ItemData.Category.SEED:
			return UIPalette.icon("leaf")
		ItemData.Category.FOOD:
			return UIPalette.icon("bread")
		ItemData.Category.MATERIAL:
			return UIPalette.icon("plank")
	return UIPalette.icon("bag")


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
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(COLUMNS * (SLOT_SIZE.x + 8) + 24, 0)
	center.add_child(_window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_window.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var gift_icon := TextureRect.new()
	gift_icon.texture = UIPalette.icon("heart")
	gift_icon.custom_minimum_size = Vector2(36, 36)
	gift_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gift_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(gift_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override("font_size", 28)
	names.add_child(_title)
	_role = Label.new()
	_role.theme_type_variation = &"SubtleLabel"
	_role.add_theme_font_size_override("font_size", 15)
	names.add_child(_role)
	header.add_child(names)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 2)
	_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Friendship.MAX_HEARTS:
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(26, 26)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts.add_child(heart)
	header.add_child(_hearts)
	box.add_child(header)
	box.add_child(HSeparator.new())

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 16)
	box.add_child(_note)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_grid)

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_detail = Label.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("font_size", 17)
	footer.add_child(_detail)
	_give_button = Button.new()
	_give_button.text = "Give"
	_give_button.custom_minimum_size = Vector2(110, 40)
	_give_button.pressed.connect(func() -> void:
		if _selected != &"":
			give(_selected))
	footer.add_child(_give_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	box.add_child(footer)
