class_name ForgePanel
extends CanvasLayer
## Bram's forge window: each tool with two ways to get it, "Forge it" (bring the
## materials, pay a small fee, wait while he works) or "Buy" (full price, no wait).
## Opened with E at the forge (centred) or F (the shop view: docked at the right while the
## camera frames the forge and Bram). Esc, E, F or the Close button closes it.

const ICON_SIZE := Vector2(60, 60)

var _root: Control
var _dim: ColorRect
var _window: PanelContainer
var _coins: Label
var _note: Label
var _cards: VBoxContainer
var _opened_at := 0


func _ready() -> void:
	add_to_group(&"forge_panel")
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	InventoryManager.money_changed.connect(func(_m: int) -> void:
		if is_open():
			_refresh())
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void:
		if is_open():
			_refresh())


func is_open() -> bool:
	return visible


func open(docked: bool = false) -> void:
	if is_open():
		return
	var player := _player()
	if player and player.is_input_locked():
		return
	_opened_at = Engine.get_process_frames()
	_dim.visible = not docked
	if docked:
		_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_window.offset_left = -740
		_window.offset_right = -24
	else:
		_window.set_anchors_preset(Control.PRESET_CENTER)
		_window.offset_left = -360
		_window.offset_right = 360
	_window.offset_top = -260
	_window.offset_bottom = 260
	_note.text = "\"Need a tool? Bring me the makings and I'll forge it while you wait, or take one I made earlier.\""
	visible = true
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	QuestLog.record_event(&"open_forge")


func close() -> void:
	if not is_open():
		return
	# (The shop view watches this to glide the camera back.)
	visible = false
	var player := _player()
	if player:
		player.set_input_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Forges a tool from your materials (the "Forge it" button). Returns BlacksmithService.forge().
func forge(item_id: StringName) -> Dictionary:
	var result := BlacksmithService.forge(item_id)
	var name_text := ItemDB.get_display_name(item_id)
	if result.result == BlacksmithService.Result.OK:
		var hours := int(result.minutes) / 60.0
		_note.text = "Bram hammers away at the anvil... %s later, your %s is ready. \"Mind the edge!\"" % ["an hour" if hours == 1.0 else "%s hours" % str(hours).trim_suffix(".0"), name_text]
		GameManager.notify("Bram forged you a %s!" % name_text)
	else:
		_note.text = BlacksmithService.message_for(result.result)
	_refresh()
	return result


## Buys a ready-made tool (the "Buy" button). Returns BlacksmithService.buy().
func buy(item_id: StringName) -> Dictionary:
	var result := BlacksmithService.buy(item_id)
	var name_text := ItemDB.get_display_name(item_id)
	if result.result == BlacksmithService.Result.OK:
		_note.text = "\"Here you are, one %s, fresh off the rack. Look after it.\"" % name_text
		GameManager.notify("Bought a %s for %d coins." % [name_text, int(result.coins)])
	else:
		_note.text = BlacksmithService.message_for(result.result)
	_refresh()
	return result


func get_note() -> String:
	return _note.text


## Tool ids on show (for tests).
func get_card_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for card in _cards.get_children():
		if card.has_meta(&"item_id"):
			ids.append(card.get_meta(&"item_id"))
	return ids


func is_docked() -> bool:
	return not _dim.visible


func _input(event: InputEvent) -> void:
	if not is_open() or Engine.get_process_frames() - _opened_at < 2:
		return
	if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"focus_shop"):
		get_viewport().set_input_as_handled()
		close()


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Content --------------------------------------------------------------------

func _refresh() -> void:
	_coins.text = "%d coins" % InventoryManager.get_money()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for recipe in BlacksmithService.get_recipes():
		_cards.add_child(_card(recipe))


func _card(recipe: ToolRecipe) -> Control:
	var item := ItemDB.get_item(recipe.item_id)
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.set_meta(&"item_id", recipe.item_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = item.icon if item and item.icon else UIPalette.icon("bag")
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 20)
	title.text = item.display_name if item else String(recipe.item_id)
	texts.add_child(title)
	var pitch := Label.new()
	pitch.text = recipe.pitch
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.add_theme_font_size_override("font_size", 15)
	texts.add_child(pitch)
	var owned := InventoryManager.has_item(recipe.item_id)
	var details := Label.new()
	details.theme_type_variation = &"SubtleLabel"
	details.add_theme_font_size_override("font_size", 14)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if owned:
		details.text = "You have this one."
	else:
		var have: Array[String] = []
		for material: StringName in recipe.materials:
			have.append("%d of %d %s" % [mini(InventoryManager.get_count(material), int(recipe.materials[material])), int(recipe.materials[material]), BlacksmithService.item_name(material, int(recipe.materials[material]))])
		details.text = "Forge it: %s + %d coins (takes %s)   ·   You have %s" % [BlacksmithService.materials_text(recipe), recipe.forge_fee, _duration(recipe.forge_minutes), ", ".join(have)]
	texts.add_child(details)
	row.add_child(texts)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override("separation", 6)
	var forge_button := Button.new()
	forge_button.text = "Forge it (%d)" % recipe.forge_fee
	forge_button.custom_minimum_size = Vector2(150, 40)
	forge_button.disabled = BlacksmithService.can_forge(recipe.item_id) != BlacksmithService.Result.OK
	forge_button.tooltip_text = "Bring %s and pay %d coins. You wait while Bram works." % [BlacksmithService.materials_text(recipe), recipe.forge_fee]
	forge_button.pressed.connect(func() -> void: forge(recipe.item_id))
	buttons.add_child(forge_button)
	if recipe.buy_price > 0:
		var buy_button := Button.new()
		buy_button.text = "Buy (%d)" % recipe.buy_price
		buy_button.custom_minimum_size = Vector2(150, 40)
		buy_button.disabled = BlacksmithService.can_buy(recipe.item_id) != BlacksmithService.Result.OK
		buy_button.tooltip_text = "Take a ready-made one for %d coins. No waiting." % recipe.buy_price
		buy_button.pressed.connect(func() -> void: buy(recipe.item_id))
		buttons.add_child(buy_button)
	row.add_child(buttons)
	return card


static func _duration(minutes: int) -> String:
	if minutes % 60 == 0:
		return "1 hour" if minutes == 60 else "%d hours" % (minutes / 60)
	return "%d min" % minutes


# ---- Layout ---------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.1, 0.07, 0.04, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_window = PanelContainer.new()
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.custom_minimum_size = Vector2(720, 0)
	_root.add_child(_window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_window.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.text = "Bram's Forge"
	names.add_child(title)
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"SubtleLabel"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.text = "Blacksmith · tools made to last"
	names.add_child(subtitle)
	header.add_child(names)
	var coin := TextureRect.new()
	coin.texture = UIPalette.icon("coin")
	coin.custom_minimum_size = Vector2(28, 28)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(coin)
	_coins = Label.new()
	_coins.add_theme_font_size_override("font_size", 20)
	header.add_child(_coins)
	box.add_child(header)
	box.add_child(HSeparator.new())

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 16)
	box.add_child(_note)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	box.add_child(_cards)

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 44)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	box.add_child(footer)
