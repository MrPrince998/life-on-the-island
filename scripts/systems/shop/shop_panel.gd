class_name ShopPanel
extends CanvasLayer
## The store screen: Buy, Sell and Upgrades tabs, coin total, bag space.
## Upgrades (UpgradeService) are bought once: better tools, furniture for the cottage,
## more garden beds and projects for the village.
## Opening it frees the mouse and stops the player walking; Esc, E or the X closes it.

const THEME_PATH := "res://assets/ui/cozy_theme.tres"
const COIN_ICON_PATH := "res://assets/ui/icons/coin.svg"
const INK := Color("4a3222")
const INK_SOFT := Color("7d6450")
const HONEY := Color("b9822a")
const BERRY := Color("c0503d")
const LEAF := Color("4f8a3c")

var _title: Label
var _coins: Label
var _bag: Label
var _status: Label
var _list: VBoxContainer
var _buy_tab: Button
var _sell_tab: Button
var _upgrades_tab: Button
var _dim: ColorRect
var _window: PanelContainer
var _selling: bool = false
var _upgrades: bool = false
var _status_tween: Tween


func _ready() -> void:
	layer = 4
	add_to_group(&"shop_panel")
	_build()
	visible = false
	InventoryManager.money_changed.connect(func(_m: int) -> void: _refresh())
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void: _refresh())


func is_open() -> bool:
	return visible


## `docked`: the shop view (ShopFocus) - the window sits at the right and the scene
## stays visible (no dimming).
func open(title: String = "Willowbrook General Store", docked: bool = false) -> void:
	_title.text = title
	_dim.visible = not docked
	if docked:
		_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_window.offset_left = -780
		_window.offset_right = -24
	else:
		_window.set_anchors_preset(Control.PRESET_CENTER)
		_window.offset_left = -380
		_window.offset_right = 380
	_window.offset_top = -280
	_window.offset_bottom = 280
	_selling = false
	_upgrades = false
	_status.text = "Welcome! Have a look around."
	visible = true
	_set_player_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	QuestLog.record_event(&"open_shop")


func close() -> void:
	if not visible:
		return
	visible = false
	_set_player_locked(false)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_interaction_prompt("")


func show_tab(selling: bool) -> void:
	_selling = selling
	_upgrades = false
	_refresh()


func show_upgrades() -> void:
	_selling = false
	_upgrades = true
	_refresh()


## Used by the Upgrades buttons (and tests). Returns the UpgradeService result.
func buy_upgrade(id: StringName) -> Dictionary:
	var result := UpgradeService.buy(id)
	var upgrade := UpgradeService.get_upgrade(id)
	if result.result == UpgradeService.Result.OK:
		_say(upgrade.bought_message if upgrade.bought_message != "" else "Bought the %s." % upgrade.display_name, LEAF)
		GameManager.notify(upgrade.bought_message if upgrade.bought_message != "" else "Bought the %s!" % upgrade.display_name)
	else:
		_say(UpgradeService.message_for(result.result), BERRY)
	_refresh()
	return result


## Used by the buttons (and tests). Returns the ShopService result dictionary.
func buy(item_id: StringName, quantity: int) -> Dictionary:
	var result := ShopService.buy(item_id, quantity)
	if result.result == ShopService.Result.OK:
		_say("Bought %d × %s for %d coins." % [quantity, ItemDB.get_display_name(item_id), result.coins], LEAF)
	else:
		_say(ShopService.message_for(result.result), BERRY)
	return result


func sell(item_id: StringName, quantity: int) -> Dictionary:
	var result := ShopService.sell(item_id, quantity)
	if result.result == ShopService.Result.OK:
		_say("Sold %d × %s for %d coins." % [quantity, ItemDB.get_display_name(item_id), result.coins], LEAF)
	else:
		_say(ShopService.message_for(result.result), BERRY)
	return result


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"toggle_bag") or event.is_action_pressed(&"focus_shop"):
		close()
		get_viewport().set_input_as_handled()


func _set_player_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player:
		player.set_input_locked(locked)


# ---- Layout -----------------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH) as Theme
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.04, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	_dim = dim

	var panel := PanelContainer.new()
	_window = panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 560)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -280
	panel.offset_bottom = 280
	if not ResourceLoader.exists(THEME_PATH):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f6ead2")
		style.set_corner_radius_all(14)
		style.set_content_margin_all(18)
		style.border_width_bottom = 4
		style.border_color = Color("7a4e2d")
		panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_title = _label("Willowbrook General Store", 28, INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	if ResourceLoader.exists(COIN_ICON_PATH):
		var icon := TextureRect.new()
		icon.texture = load(COIN_ICON_PATH)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)
	_coins = _label("0", 24, HONEY)
	header.add_child(_coins)
	var close_button := Button.new()
	close_button.text = "  ✕  "
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	_buy_tab = Button.new()
	_buy_tab.text = "Buy"
	_buy_tab.toggle_mode = true
	_buy_tab.custom_minimum_size = Vector2(120, 40)
	_buy_tab.pressed.connect(func() -> void: show_tab(false))
	tabs.add_child(_buy_tab)
	_sell_tab = Button.new()
	_sell_tab.text = "Sell"
	_sell_tab.toggle_mode = true
	_sell_tab.custom_minimum_size = Vector2(120, 40)
	_sell_tab.pressed.connect(func() -> void: show_tab(true))
	tabs.add_child(_sell_tab)
	_upgrades_tab = Button.new()
	_upgrades_tab.text = "Upgrades"
	_upgrades_tab.toggle_mode = true
	_upgrades_tab.custom_minimum_size = Vector2(140, 40)
	_upgrades_tab.pressed.connect(show_upgrades)
	tabs.add_child(_upgrades_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_bag = _label("", 17, INK_SOFT)
	tabs.add_child(_bag)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_status = _label("", 17, INK_SOFT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	box.add_child(_label("Esc or E to leave  ·  Shopping doesn't use any time", 14, INK_SOFT))


func _refresh() -> void:
	if _list == null or not visible:
		return
	_coins.text = " %d coins " % InventoryManager.get_money()
	_bag.text = "Bag %d / %d" % [InventoryManager.get_slots_used(), InventoryManager.get_bag_slots()]
	_buy_tab.button_pressed = not _selling and not _upgrades
	_sell_tab.button_pressed = _selling
	_upgrades_tab.button_pressed = _upgrades
	for child in _list.get_children():
		child.queue_free()
	if _upgrades:
		_fill_upgrades()
	elif _selling:
		var sellable := ShopService.get_sellable()
		if sellable.is_empty():
			_list.add_child(_label("You have nothing the store wants to buy. Try catching some fish!", 17, INK_SOFT))
		for entry in sellable:
			var item: ItemData = entry[0]
			var count: int = entry[1]
			var row := _row(item, "%d each  ·  you have %d" % [item.sell_price, count])
			row.add_child(_button("Sell 1", func() -> void: sell(item.id, 1)))
			row.add_child(_button("Sell all (%d)" % (item.sell_price * count), func() -> void: sell(item.id, InventoryManager.get_count(item.id))))
	else:
		for item in ShopService.get_stock():
			var owned := InventoryManager.get_count(item.id)
			var note := "%d coins" % item.buy_price + ("  ·  you have %d" % owned if owned > 0 else "")
			var row := _row(item, note)
			var one := _button("Buy 1", func() -> void: buy(item.id, 1))
			one.disabled = ShopService.can_buy(item.id, 1) != ShopService.Result.OK
			row.add_child(one)
			if not item.unique:
				var five := _button("Buy 5", func() -> void: buy(item.id, 5))
				five.disabled = ShopService.can_buy(item.id, 5) != ShopService.Result.OK
				row.add_child(five)


func _fill_upgrades() -> void:
	var category := -1
	for upgrade in UpgradeService.get_all():
		if upgrade.category != category:
			category = upgrade.category
			var heading := _label(_category_heading(category), 22, HONEY)
			_list.add_child(heading)
		var owned := UpgradeService.is_bought(upgrade.id)
		var locked := not owned and not UpgradeService.is_unlocked(upgrade)
		var note := "Owned ✓" if owned else "%d coins" % upgrade.price
		var row := _upgrade_row(upgrade, note, owned or locked)
		if locked:
			var why := _label(UpgradeService.lock_reason(upgrade), 14, INK_SOFT)
			why.custom_minimum_size = Vector2(150, 0)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(why)
		elif not owned:
			var buy_button := _button("Buy", func() -> void: buy_upgrade(upgrade.id))
			buy_button.disabled = UpgradeService.can_buy(upgrade.id) != UpgradeService.Result.OK
			row.add_child(buy_button)


static func _category_heading(category: int) -> String:
	return ["Tools  ·  from Oliver and Emma", "For Grandpa's cottage", "For the farm  ·  with Mia", "For the village"][category]


func _upgrade_row(upgrade: UpgradeData, note: String, dim: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if dim:
		row.modulate = Color(1, 1, 1, 0.62)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label(upgrade.display_name, 20, INK))
	var desc := _label(upgrade.description, 14, INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	row.add_child(text)
	var price := _label(note, 16, LEAF if note.begins_with("Owned") else HONEY)
	price.custom_minimum_size = Vector2(110, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	_list.add_child(row)
	_list.add_child(HSeparator.new())
	return row


func _row(item: ItemData, note: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label("%s   ·   %s" % [item.display_name, item.get_category_name()], 20, INK))
	var desc := _label(item.description, 14, INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(desc)
	row.add_child(text)
	var price := _label(note, 16, HONEY)
	price.custom_minimum_size = Vector2(170, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	_list.add_child(row)
	_list.add_child(HSeparator.new())
	return row


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(92, 36)
	b.pressed.connect(action)
	return b


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
