class_name StoragePanel
extends CanvasLayer
## The storage window for a StorageChest: the chest's slots on the left, your bag on
## the right. Click a stack to move it to the other side, right-click to move just
## one, or "Store all" to tuck everything but your tools away. Closes with E, Tab or
## Esc. The player stands still and the mouse is free while it's open. Storing costs
## no time. One shared instance is created on first use.

const COLUMNS := 6
const SLOT_SIZE := Vector2(74, 74)

var _chest: StorageChest
var _root: Control
var _window: PanelContainer
var _title: Label
var _chest_grid: GridContainer
var _bag_grid: GridContainer
var _chest_slots: Array[Button] = []
var _bag_slots: Array[Button] = []
## What each slot shows: {"id": StringName, "count": int} or {}.
var _chest_items: Array[Dictionary] = []
var _bag_items: Array[Dictionary] = []
var _chest_label: Label
var _bag_label: Label
var _info: Label
var _store_all: Button
var _open_tween: Tween


static func get_instance(tree: SceneTree) -> StoragePanel:
	var existing := tree.root.get_node_or_null(^"StoragePanel") as StoragePanel
	if existing:
		return existing
	var panel := StoragePanel.new()
	panel.name = "StoragePanel"
	tree.root.add_child(panel)
	return panel


func _ready() -> void:
	layer = 4
	_build()
	_root.hide()
	InventoryManager.inventory_changed.connect(func(_id: StringName, _n: int) -> void: _refresh())


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"toggle_bag") or event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


func get_chest() -> StorageChest:
	return _chest if is_instance_valid(_chest) else null


## Opens the window for a chest. Returns false if the player is busy with something else.
func open_for(chest: StorageChest) -> bool:
	var player := _player()
	if is_open() or chest == null:
		return is_open()
	if player and player.is_input_locked():
		return false
	if is_instance_valid(_chest) and _chest.contents_changed.is_connected(_refresh):
		_chest.contents_changed.disconnect(_refresh)
	_chest = chest
	_chest.contents_changed.connect(_refresh)
	_build_chest_slots(chest.slots)
	_title.text = chest.display_name
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_info.text = "Click a stack to move it across. Right-click moves just one."
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
	if is_instance_valid(_chest) and _chest.contents_changed.is_connected(_refresh):
		_chest.contents_changed.disconnect(_refresh)
	var player := _player()
	if player:
		player.set_input_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Moves the stack in a slot to the other side (for clicks, keys and tests).
## `one` moves a single item. Returns how many moved.
func move_from_chest(index: int, one: bool = false) -> int:
	var chest := get_chest()
	if chest == null or index < 0 or index >= _chest_items.size() or _chest_items[index].is_empty():
		return 0
	var item: Dictionary = _chest_items[index]
	var moved := chest.take(item.id, 1 if one else int(item.count))
	_info.text = ("Took %d × %s." % [moved, ItemDB.get_display_name(item.id)]) if moved > 0 else "Your bag is full."
	return moved


func move_from_bag(index: int, one: bool = false) -> int:
	var chest := get_chest()
	if chest == null or index < 0 or index >= _bag_items.size() or _bag_items[index].is_empty():
		return 0
	var item: Dictionary = _bag_items[index]
	var moved := chest.store(item.id, 1 if one else int(item.count))
	_info.text = ("Stored %d × %s." % [moved, ItemDB.get_display_name(item.id)]) if moved > 0 else "The chest is full."
	return moved


func store_all() -> int:
	var chest := get_chest()
	if chest == null:
		return 0
	var moved := chest.store_all()
	_info.text = ("Stored %d things. Your tools stay in your bag." % moved) if moved > 0 else "Nothing to store (tools stay in your bag)."
	return moved


func get_chest_slot_item(index: int) -> Dictionary:
	return _chest_items[index] if index >= 0 and index < _chest_items.size() else {}


func get_bag_slot_item(index: int) -> Dictionary:
	return _bag_items[index] if index >= 0 and index < _bag_items.size() else {}


func get_info_text() -> String:
	return _info.text


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Layout -----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = load(UIPalette.THEME_PATH) as Theme
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_icon("house", 38))
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override("font_size", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_store_all = Button.new()
	_store_all.text = "Store all"
	_store_all.tooltip_text = "Put everything except your tools in the chest"
	_store_all.pressed.connect(func() -> void: store_all())
	header.add_child(_store_all)
	box.add_child(header)
	box.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	box.add_child(body)
	var chest_col := VBoxContainer.new()
	_chest_label = _column_label(chest_col, "house")
	_chest_grid = _make_grid()
	chest_col.add_child(_chest_grid)
	body.add_child(chest_col)
	body.add_child(VSeparator.new())
	var bag_col := VBoxContainer.new()
	_bag_label = _column_label(bag_col, "bag")
	_bag_grid = _make_grid()
	bag_col.add_child(_bag_grid)
	body.add_child(bag_col)
	# Room for the biggest bag; slots past the current size stay hidden (bag upgrades).
	for i in InventoryManager.MAX_BAG_SLOTS:
		var slot := _make_slot(false, i)
		_bag_grid.add_child(slot)
		_bag_slots.append(slot)
		_bag_items.append({})

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_info)
	for key in ["E", "Esc"]:
		footer.add_child(_key_cap(key))
	var close_label := Label.new()
	close_label.theme_type_variation = &"SubtleLabel"
	close_label.text = "close"
	footer.add_child(close_label)
	box.add_child(footer)


func _build_chest_slots(count: int) -> void:
	if _chest_slots.size() == count:
		return
	for slot in _chest_slots:
		slot.queue_free()
	_chest_slots.clear()
	_chest_items.clear()
	for i in count:
		var slot := _make_slot(true, i)
		_chest_grid.add_child(slot)
		_chest_slots.append(slot)
		_chest_items.append({})


func _column_label(parent: Control, icon_name: String) -> Label:
	var row := HBoxContainer.new()
	row.add_child(_icon(icon_name, 26))
	var label := Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	parent.add_child(row)
	return label


func _make_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


func _make_slot(in_chest: bool, index: int) -> Button:
	var slot := Button.new()
	slot.theme_type_variation = &"SlotButton"
	slot.custom_minimum_size = SLOT_SIZE
	slot.focus_mode = Control.FOCUS_ALL
	slot.pressed.connect(func() -> void:
		if in_chest:
			move_from_chest(index)
		else:
			move_from_bag(index))
	slot.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			if in_chest:
				move_from_chest(index, true)
			else:
				move_from_bag(index, true)
			slot.accept_event())
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 8
	icon.offset_right = -12
	icon.offset_bottom = -16
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.theme_type_variation = &"KeyLabel"
	count.add_theme_font_size_override("font_size", 15)
	count.add_theme_color_override("font_outline_color", UIPalette.CREAM)
	count.add_theme_constant_override("outline_size", 6)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -40
	count.offset_top = -24
	count.offset_right = -6
	count.offset_bottom = -3
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count)
	return slot


# ---- Contents ---------------------------------------------------------------

func _refresh() -> void:
	if _bag_grid == null:
		return
	_fill(_bag_slots, _bag_items, InventoryManager.get_all())
	var capacity := InventoryManager.get_bag_slots()
	for i in _bag_slots.size():
		_bag_slots[i].visible = i < capacity
	_bag_label.text = "Bag  %d / %d" % [InventoryManager.get_slots_used(), capacity]
	var chest := get_chest()
	if chest:
		_fill(_chest_slots, _chest_items, chest.get_all())
		_chest_label.text = "Chest  %d / %d" % [chest.get_slots_used(), chest.slots]
	_store_all.disabled = chest == null


## Lays items out as stacks, one stack per slot.
func _fill(slots: Array[Button], shown: Array[Dictionary], items: Dictionary) -> void:
	var stacks: Array[Dictionary] = []
	for item_id in items:
		var remaining := int(items[item_id])
		var stack := ItemDB.get_max_stack(item_id)
		while remaining > 0:
			stacks.append({"id": item_id, "count": mini(remaining, stack)})
			remaining -= stack
	for i in slots.size():
		var item: Dictionary = stacks[i] if i < stacks.size() else {}
		shown[i] = item
		var slot := slots[i]
		var icon := slot.get_node("Icon") as TextureRect
		var count := slot.get_node("Count") as Label
		slot.disabled = item.is_empty()
		icon.texture = null if item.is_empty() else UIPalette.item_icon(item.id)
		count.text = "" if item.is_empty() or item.count <= 1 else str(item.count)
		slot.tooltip_text = "" if item.is_empty() else "%s × %d" % [ItemDB.get_display_name(item.id), item.count]


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
