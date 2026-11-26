class_name PackingPanel
extends CanvasLayer
## The shipping orders screen at the packing table: each open order with its buyer, what
## it needs (and how much of it is in your bag), the pay, and a "Pack crate" button.
## Packing takes ShippingYard.PACK_MINUTES. Esc, E or the X closes it.

const THEME_PATH := "res://assets/ui/cozy_theme.tres"
const INK := Color("4a3222")
const INK_SOFT := Color("7d6450")
const HONEY := Color("b9822a")
const BERRY := Color("c0503d")
const LEAF := Color("4f8a3c")

var _yard: ShippingYard
var _list: VBoxContainer
var _status: Label
var _root: Control


func _ready() -> void:
	layer = 4
	add_to_group(&"packing_panel")
	_build()
	visible = false
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void: _refresh())


func is_open() -> bool:
	return visible


func open(yard: ShippingYard) -> void:
	_yard = yard
	if _yard and not _yard.orders_changed.is_connected(_refresh):
		_yard.orders_changed.connect(_refresh)
	visible = true
	_status.text = "Pack an order, then take the crate to the jetty. Captain Marlow sails at 6 PM."
	_status.add_theme_color_override("font_color", INK_SOFT)
	_set_player_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_set_player_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Used by the buttons (and tests).
func pack(order_id: int) -> ShippingCrate:
	if _yard == null:
		return null
	var crate := _yard.pack(order_id)
	if crate:
		_say("Packed! The crate for %s is on the table. Lift it with E." % crate.buyer, LEAF)
	else:
		_say("You can't pack that one yet.", BERRY)
	_refresh()
	return crate


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()


func _set_player_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player:
		player.set_input_locked(locked)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		_root.theme = load(THEME_PATH) as Theme
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.04, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 470)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -235
	panel.offset_bottom = 235
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _label("Shipping Orders", 28, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "  ✕  "
	close_button.pressed.connect(close)
	header.add_child(close_button)
	box.add_child(_label("Captain Marlow's boat calls at the farm jetty every day and sails at 6 PM.", 15, INK_SOFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_status = _label("", 16, INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	box.add_child(_label("Esc or E to close  ·  Packing a crate takes %d minutes" % ShippingYard.PACK_MINUTES, 14, INK_SOFT))


func _refresh() -> void:
	if _list == null or not visible or _yard == null:
		return
	for child in _list.get_children():
		child.queue_free()
	if _yard.orders.is_empty():
		_list.add_child(_label("No orders right now. New ones come in every morning.", 17, INK_SOFT))
		return
	for order in _yard.orders:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(str(order.buyer), 20, INK))
		var parts: Array[String] = []
		for item_id in order.items:
			var need := int(order.items[item_id])
			var have := InventoryManager.get_count(item_id)
			parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id), mini(have, need), need])
		var needs := _label("  ·  ".join(parts), 15, INK_SOFT)
		needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(needs)
		row.add_child(text)
		row.add_child(_label("%d coins" % int(order.reward), 17, HONEY))
		var order_id := int(order.id)
		if _yard.is_packed(order_id):
			row.add_child(_label("Packed ✓", 16, LEAF))
		else:
			var button := Button.new()
			button.text = "Pack crate"
			button.custom_minimum_size = Vector2(130, 38)
			button.disabled = not _yard.can_pack(order_id)
			button.pressed.connect(func() -> void: pack(order_id))
			row.add_child(button)
		_list.add_child(row)
		_list.add_child(HSeparator.new())


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
