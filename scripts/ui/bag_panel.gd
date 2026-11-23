extends CanvasLayer
## The bag, as a pop-up window (Tab or I): a grid of slots on the left, details of the
## selected item on the right, coins and slots used at the top, the fish journal at the
## bottom. The world is dimmed behind it, the player stands still and the mouse is free.
## Closes with Tab, I or Esc. Styled by the cozy theme.
##
## Each slot is one stack: an item bigger than its stack limit fills several slots.

@export var catalog: FishCatalog

const COLUMNS := 6
const SLOT_SIZE := Vector2(86, 86)
const CATEGORY_NAMES := ["Fish", "Seeds", "Tool", "Material", "Food", "Misc"]

var _root: Control
var _window: PanelContainer
var _grid: GridContainer
var _slots: Array[Button] = []
## What each slot holds: {"id": StringName, "count": int} or {} when empty.
var _slot_items: Array[Dictionary] = []
var _group := ButtonGroup.new()
var _selected: int = -1
var _coins_label: Label
var _slots_label: Label
var _journal_label: Label
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_kind: Label
var _detail_desc: Label
var _detail_count: Label
var _detail_price: Label
var _detail_price_row: HBoxContainer
var _open_tween: Tween


func _ready() -> void:
	layer = 3
	_build()
	_root.hide()
	InventoryManager.inventory_changed.connect(func(_id: StringName, _n: int) -> void: _refresh())
	InventoryManager.money_changed.connect(func(_total: int) -> void: _refresh())
	Journal.fish_recorded.connect(func(_a: StringName, _b: float, _c: bool, _d: bool) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() and event.is_action_pressed(&"toggle_bag"):
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"toggle_bag") or event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


## Opens the bag, unless something else already has the player busy (the store,
## fishing, a conversation). Returns true if the bag is open.
func open() -> bool:
	if is_open():
		return true
	var player := _player()
	if player and player.is_input_locked():
		return false
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_select(_first_filled_slot())
	if _selected >= 0:
		_slots[_selected].grab_focus()
	# Little pop-in.
	_window.pivot_offset = _window.size * 0.5
	_window.scale = Vector2(0.94, 0.94)
	_root.modulate.a = 0.0
	if _open_tween:
		_open_tween.kill()
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_root, "modulate:a", 1.0, 0.16)
	_open_tween.tween_property(_window, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func close() -> void:
	if not is_open():
		return
	_root.hide()
	var player := _player()
	if player:
		player.set_input_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## For tests and other screens: the item in a slot ({} when empty), and the selection.
func get_slot_item(index: int) -> Dictionary:
	return _slot_items[index] if index >= 0 and index < _slot_items.size() else {}


func get_selected_slot() -> int:
	return _selected


func get_detail_name() -> String:
	return _detail_name.text


func select_slot(index: int) -> void:
	_select(index)


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Layout -----------------------------------------------------------------

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
	center.add_child(_window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_window.add_child(box)

	# Header: [bag] Bag ............ [coin] 85   12 / 24 slots
	var header := HBoxContainer.new()
	header.add_child(_icon("bag", 40))
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.text = "Bag"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_icon("coin", 30))
	_coins_label = Label.new()
	_coins_label.theme_type_variation = &"HeaderLabel"
	_coins_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_coins_label)
	var slots_chip := PanelContainer.new()
	slots_chip.theme_type_variation = &"InsetPanel"
	slots_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slots_label = Label.new()
	_slots_label.add_theme_font_size_override("font_size", 16)
	slots_chip.add_child(_slots_label)
	header.add_child(slots_chip)
	box.add_child(header)
	box.add_child(HSeparator.new())

	# Body: slot grid | details.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	box.add_child(body)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)
	# Room for the biggest bag; slots past the current size stay hidden (bag upgrades).
	for i in InventoryManager.MAX_BAG_SLOTS:
		_grid.add_child(_make_slot(i))
	body.add_child(_build_details())

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_child(_icon("book", 26))
	_journal_label = Label.new()
	_journal_label.add_theme_font_size_override("font_size", 16)
	_journal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_journal_label)
	for key in ["Tab", "I", "Esc"]:
		footer.add_child(_key_cap(key))
	var close_label := Label.new()
	close_label.theme_type_variation = &"SubtleLabel"
	close_label.text = "close"
	footer.add_child(close_label)
	box.add_child(footer)


func _make_slot(index: int) -> Button:
	var slot := Button.new()
	slot.theme_type_variation = &"SlotButton"
	slot.custom_minimum_size = SLOT_SIZE
	slot.toggle_mode = true
	slot.button_group = _group
	slot.focus_mode = Control.FOCUS_ALL
	slot.pressed.connect(func() -> void: _select(index))
	slot.focus_entered.connect(func() -> void:
		if not slot.disabled:
			_select(index))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 14
	icon.offset_top = 10
	icon.offset_right = -14
	icon.offset_bottom = -18
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = &"KeyLabel"
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_outline_color", UIPalette.CREAM)
	count.add_theme_constant_override("outline_size", 6)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -44
	count.offset_top = -26
	count.offset_right = -8
	count.offset_bottom = -4
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)
	_slots.append(slot)
	_slot_items.append({})
	return slot


func _build_details() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"InsetPanel"
	panel.custom_minimum_size = Vector2(270, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_detail_icon = _icon("bag", 84)
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.theme_type_variation = &"HeaderLabel"
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_name)
	_detail_kind = Label.new()
	_detail_kind.add_theme_font_size_override("font_size", 15)
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail_kind)
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 16)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size = Vector2(240, 0)
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_detail_desc)
	_detail_count = Label.new()
	_detail_count.add_theme_font_size_override("font_size", 16)
	box.add_child(_detail_count)
	_detail_price_row = HBoxContainer.new()
	_detail_price_row.add_child(_icon("coin", 24))
	_detail_price = Label.new()
	_detail_price.add_theme_font_size_override("font_size", 16)
	_detail_price_row.add_child(_detail_price)
	box.add_child(_detail_price_row)
	return panel


# ---- Contents ---------------------------------------------------------------

func _refresh() -> void:
	if _grid == null:
		return
	# Lay the items out as stacks, one per slot.
	var stacks: Array[Dictionary] = []
	var items := InventoryManager.get_all()
	for item_id in items:
		var remaining: int = items[item_id]
		var stack := maxi(ItemDB.get_max_stack(item_id) if ItemDB.has_item(item_id) else 99, 1)
		while remaining > 0:
			stacks.append({"id": item_id, "count": mini(remaining, stack)})
			remaining -= stack
	var capacity := InventoryManager.get_bag_slots()
	# A bigger bag gets slightly smaller slots so the window still fits the screen.
	var slot_size := SLOT_SIZE if capacity <= 24 else (SLOT_SIZE * 0.9 if capacity <= 30 else SLOT_SIZE * 0.78)
	for i in _slots.size():
		var slot := _slots[i]
		slot.visible = i < capacity
		slot.custom_minimum_size = slot_size
		var item: Dictionary = stacks[i] if i < stacks.size() and i < capacity else {}
		_slot_items[i] = item
		var icon := slot.get_node("Icon") as TextureRect
		var count := slot.get_node("Count") as Label
		slot.disabled = item.is_empty()
		slot.focus_mode = Control.FOCUS_NONE if item.is_empty() else Control.FOCUS_ALL
		icon.texture = null if item.is_empty() else _item_icon(item.id)
		count.text = "" if item.is_empty() or item.count <= 1 else str(item.count)
		slot.tooltip_text = "" if item.is_empty() else _item_name(item.id)
	_coins_label.text = str(InventoryManager.get_money())
	_slots_label.text = "%d / %d slots" % [InventoryManager.get_slots_used(), capacity]
	var total := catalog.fish.size() if catalog else 0
	_journal_label.text = "Fish journal: %d / %d species" % [Journal.species_caught(), total]
	if _selected < 0 or _slot_items[_selected].is_empty():
		_select(_first_filled_slot())
	else:
		_show_details(_selected)


func _first_filled_slot() -> int:
	for i in _slot_items.size():
		if not _slot_items[i].is_empty():
			return i
	return -1


func _select(index: int) -> void:
	_selected = index
	for i in _slots.size():
		_slots[i].set_pressed_no_signal(i == index)
	_show_details(index)


func _show_details(index: int) -> void:
	var item: Dictionary = _slot_items[index] if index >= 0 else {}
	if item.is_empty():
		var empty_bag := _first_filled_slot() < 0
		_detail_icon.texture = UIPalette.icon("bag")
		_detail_name.text = "Your bag is empty" if empty_bag else "Empty slot"
		_detail_kind.text = ""
		_detail_desc.text = "Catch fish at the dock, or buy seeds at the General Store." if empty_bag else ""
		_detail_count.text = ""
		_detail_price_row.hide()
		return
	var item_id: StringName = item.id
	_detail_icon.texture = _item_icon(item_id)
	_detail_name.text = _item_name(item_id)
	var data := ItemDB.get_item(item_id) if ItemDB.has_item(item_id) else null
	var fish := catalog.get_fish(item_id) if catalog else null
	if data:
		_detail_kind.text = CATEGORY_NAMES[clampi(data.category, 0, CATEGORY_NAMES.size() - 1)]
	elif fish:
		_detail_kind.text = "Fish"
	else:
		_detail_kind.text = ""
	if fish:
		_detail_kind.text += "  ·  " + fish.get_rarity_name()
		_detail_kind.add_theme_color_override("font_color", UIPalette.RARITY[clampi(fish.rarity, 0, UIPalette.RARITY.size() - 1)])
	else:
		_detail_kind.add_theme_color_override("font_color", UIPalette.INK_SOFT)
	var desc := ""
	if data and not data.description.is_empty():
		desc = data.description
	elif fish:
		desc = fish.description
	_detail_desc.text = desc
	_detail_count.text = "You have %d" % InventoryManager.get_count(item_id)
	var price := data.sell_price if data else (fish.sell_price if fish else 0)
	_detail_price_row.visible = price > 0
	_detail_price.text = "Sells for %d coins each" % price


func _item_name(item_id: StringName) -> String:
	if ItemDB.has_item(item_id):
		return ItemDB.get_display_name(item_id)
	var fish := catalog.get_fish(item_id) if catalog else null
	return fish.display_name if fish else String(item_id).capitalize()


## The item's own icon if it has one, otherwise one for its kind.
func _item_icon(item_id: StringName) -> Texture2D:
	var data := ItemDB.get_item(item_id) if ItemDB.has_item(item_id) else null
	if data and data.icon:
		return data.icon
	if data == null:
		return UIPalette.icon("fish" if catalog and catalog.get_fish(item_id) else "bag")
	match data.category:
		ItemData.Category.FISH:
			return UIPalette.icon("fish")
		ItemData.Category.SEED:
			return UIPalette.icon("leaf")
		ItemData.Category.TOOL:
			return UIPalette.icon("can")
		ItemData.Category.FOOD:
			return UIPalette.icon("bread")
		ItemData.Category.MATERIAL:
			return UIPalette.icon("plank")
		_:
			return UIPalette.icon("bag")


# ---- Little helpers ---------------------------------------------------------

func _icon(icon_name: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UIPalette.icon(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _key_cap(key: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"KeyCap"
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.theme_type_variation = &"KeyLabel"
	l.add_theme_font_size_override("font_size", 15)
	l.text = key
	cap.add_child(l)
	return cap
