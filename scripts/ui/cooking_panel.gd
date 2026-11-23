class_name CookingPanel
extends CanvasLayer
## The cooking window at Grandpa's stove: recipes on the left (ones you can cook now
## are marked), the chosen recipe on the right with its ingredients (have / need),
## cooking time and price, and "Cook 1" / "Cook all" buttons. Recipes villagers
## haven't taught you yet show a hint. Closes with E, Tab or Esc; the player stands
## still meanwhile. One shared instance is created on first use.

var _root: Control
var _window: PanelContainer
var _list: VBoxContainer
var _buttons: Array[Button] = []
var _recipes: Array[RecipeData] = []
var _selected: int = 0
var _icon: TextureRect
var _name: Label
var _desc: Label
var _rows: VBoxContainer
var _info: Label
var _cook_one: Button
var _cook_all: Button
var _status: Label
var _group := ButtonGroup.new()


static func get_instance(tree: SceneTree) -> CookingPanel:
	var existing := tree.root.get_node_or_null(^"CookingPanel") as CookingPanel
	if existing:
		return existing
	var panel := CookingPanel.new()
	panel.name = "CookingPanel"
	tree.root.add_child(panel)
	return panel


func _ready() -> void:
	layer = 4
	_build()
	_root.hide()
	InventoryManager.inventory_changed.connect(func(_id: StringName, _n: int) -> void:
		if is_open():
			_refresh())


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"toggle_bag") or event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> bool:
	var player := _player()
	if is_open():
		return true
	if player and player.is_input_locked():
		return false
	_recipes = CookingService.get_recipes()
	_build_list()
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = ""
	select(_first_cookable())
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


func select(index: int) -> void:
	_selected = clampi(index, 0, maxi(_recipes.size() - 1, 0))
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(i == _selected)
	_refresh()


func get_selected() -> RecipeData:
	return _recipes[_selected] if _selected < _recipes.size() else null


## Cooks the selected recipe (1, or as many as possible). Returns how many.
func cook(all: bool = false) -> int:
	var recipe := get_selected()
	if recipe == null:
		return 0
	var made := CookingService.cook(recipe, 99 if all else 1)
	var dish := ItemDB.get_display_name(recipe.result_item)
	_status.text = ("You cooked %d × %s." % [made, dish]) if made > 0 else "Not enough ingredients."
	_refresh()
	return made


func get_status_text() -> String:
	return _status.text


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


func _first_cookable() -> int:
	for i in _recipes.size():
		if CookingService.max_cookable(_recipes[i]) > 0:
			return i
	return 0


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
	header.add_child(_make_icon(UIPalette.icon("bread"), 38))
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.text = "Grandpa's Stove"
	header.add_child(title)
	box.add_child(header)
	box.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	box.add_child(body)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(300, 0)
	_list.add_theme_constant_override("separation", 6)
	body.add_child(_list)

	var detail := PanelContainer.new()
	detail.theme_type_variation = &"InsetPanel"
	detail.custom_minimum_size = Vector2(380, 380)
	body.add_child(detail)
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 8)
	detail.add_child(dbox)
	_icon = _make_icon(null, 84)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dbox.add_child(_icon)
	_name = Label.new()
	_name.theme_type_variation = &"HeaderLabel"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dbox.add_child(_name)
	_desc = Label.new()
	_desc.add_theme_font_size_override("font_size", 16)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(340, 0)
	dbox.add_child(_desc)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	dbox.add_child(_rows)
	_info = Label.new()
	_info.theme_type_variation = &"SubtleLabel"
	_info.add_theme_font_size_override("font_size", 15)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(340, 0)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dbox.add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_cook_one = Button.new()
	_cook_one.text = "Cook 1"
	_cook_one.pressed.connect(func() -> void: cook(false))
	buttons.add_child(_cook_one)
	_cook_all = Button.new()
	_cook_all.pressed.connect(func() -> void: cook(true))
	buttons.add_child(_cook_all)
	dbox.add_child(buttons)

	box.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 16)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	for key in ["E", "Esc"]:
		footer.add_child(_key_cap(key))
	var close_label := Label.new()
	close_label.theme_type_variation = &"SubtleLabel"
	close_label.text = "close"
	footer.add_child(close_label)
	box.add_child(footer)


func _build_list() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for i in _recipes.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(300, 52)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 36)
		var index := i
		b.pressed.connect(func() -> void: select(index))
		_list.add_child(b)
		_buttons.append(b)


# ---- Contents ---------------------------------------------------------------

func _refresh() -> void:
	for i in _buttons.size():
		var r := _recipes[i]
		var known := CookingService.is_known(r)
		var can := CookingService.max_cookable(r)
		var b := _buttons[i]
		b.icon = UIPalette.item_icon(r.result_item) if known else UIPalette.icon("book")
		b.text = ("%s%s" % [ItemDB.get_display_name(r.result_item), "   ✓" if can > 0 else ""]) if known else "Unknown recipe"
		b.modulate = Color.WHITE if known else Color(1, 1, 1, 0.6)
	var recipe := get_selected()
	for child in _rows.get_children():
		child.queue_free()
	if recipe == null:
		return
	var known := CookingService.is_known(recipe)
	var item := ItemDB.get_item(recipe.result_item)
	_icon.texture = UIPalette.item_icon(recipe.result_item) if known else UIPalette.icon("book")
	_name.text = ItemDB.get_display_name(recipe.result_item) if known else "Unknown recipe"
	_desc.text = (item.description if item else "") if known else recipe.unlock_hint
	if known:
		for ingredient in recipe.ingredients:
			var key := StringName(str(ingredient))
			var need := int(recipe.ingredients[ingredient])
			var has := CookingService.have(key)
			var row := HBoxContainer.new()
			if key != CookingService.ANY_FISH:
				row.add_child(_make_icon(UIPalette.item_icon(key), 26))
			else:
				row.add_child(_make_icon(UIPalette.icon("fish"), 26))
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 17)
			l.text = "%s  %d / %d" % [CookingService.ingredient_name(key), mini(has, need), need]
			l.add_theme_color_override("font_color", UIPalette.LEAF.darkened(0.35) if has >= need else UIPalette.BERRY)
			row.add_child(l)
			_rows.add_child(row)
		_info.text = "Takes %d min · sells for %d coins%s" % [recipe.minutes, item.sell_price if item else 0,
				"\nAny fish uses your cheapest fish first." if recipe.ingredients.has("any_fish") or recipe.ingredients.has(CookingService.ANY_FISH) else ""]
	else:
		_info.text = ""
	var can := CookingService.max_cookable(recipe)
	_cook_one.disabled = can <= 0
	_cook_all.disabled = can <= 1
	_cook_all.text = "Cook all (%d)" % can if can > 1 else "Cook all"


# ---- Little helpers ---------------------------------------------------------

func _make_icon(texture: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
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
