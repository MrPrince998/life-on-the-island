extends CanvasLayer
## Fishing UI: hints, cast power, the reeling tension bar and the catch card.
## Built in code; listens to the player's FishingController.
## Styled by the cozy theme (assets/ui/cozy_theme.tres); colours from UIPalette.

var _controller: FishingController
var _hint_panel: PanelContainer
var _hint: Label
var _power_panel: PanelContainer
var _power_bar: ProgressBar
var _reel_panel: PanelContainer
var _tension_bar: TensionBar
var _progress_bar: ProgressBar
var _reel_status: Label
var _card: PanelContainer
var _card_title: Label
var _card_name: Label
var _card_details: Label
var _card_desc: Label
var _card_tween: Tween


func _ready() -> void:
	layer = 2
	_build()
	await get_tree().process_frame
	_controller = get_tree().get_first_node_in_group(&"fishing_controller") as FishingController
	if _controller == null:
		push_warning("FishingHUD: no FishingController found.")
		return
	_controller.hint_changed.connect(_on_hint)
	_controller.state_changed.connect(_on_state)
	_controller.cast_power_changed.connect(func(p: float) -> void: _power_bar.value = p * 100.0)
	_controller.reel_updated.connect(_on_reel)
	_controller.fish_hooked.connect(_on_hooked)
	_controller.catch_finished.connect(_on_catch)
	_on_state(_controller.state)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hint_panel = _panel()
	_hint = _label("", "", 19)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_place_top_center(_hint_panel, root, 600, 150, 0)

	_power_panel = _panel()
	var power_box := VBoxContainer.new()
	power_box.add_child(_label("Cast power", "HeaderLabel", 18))
	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size = Vector2(300, 22)
	_power_bar.show_percentage = false
	power_box.add_child(_power_bar)
	_power_panel.add_child(power_box)
	_place_top_center(_power_panel, root, 340, 220, 0)

	_reel_panel = _panel()
	var reel_box := VBoxContainer.new()
	reel_box.add_theme_constant_override("separation", 6)
	_reel_status = _label("Reel it in!", "HeaderLabel", 24)
	_reel_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reel_box.add_child(_reel_status)
	reel_box.add_child(_label("Line tension", "SubtleLabel", 14))
	_tension_bar = TensionBar.new()
	_tension_bar.custom_minimum_size = Vector2(440, 28)
	reel_box.add_child(_tension_bar)
	var distance_row := HBoxContainer.new()
	var fish_icon := _icon("fish", 22)
	distance_row.add_child(fish_icon)
	distance_row.add_child(_label("Fish distance", "SubtleLabel", 14))
	reel_box.add_child(distance_row)
	_progress_bar = ProgressBar.new()
	_progress_bar.theme_type_variation = &"SkyBar"
	_progress_bar.custom_minimum_size = Vector2(440, 16)
	_progress_bar.show_percentage = false
	reel_box.add_child(_progress_bar)
	_reel_panel.add_child(reel_box)
	_place_top_center(_reel_panel, root, 490, 220, 0)

	# Catch card: fish icon, "You caught a fish!", name in its rarity colour, details, description.
	_card = _panel()
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 4)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_child(_icon("fish", 30))
	_card_title = _label("You caught a fish!", "HeaderLabel", 22)
	title_row.add_child(_card_title)
	card_box.add_child(title_row)
	_card_name = _label("", "BigLabel", 38)
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_card_name)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"InsetPanel"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_details = _label("", "", 17)
	_card_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(_card_details)
	card_box.add_child(chip)
	_card_desc = _label("", "SubtleLabel", 16)
	_card_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_desc.custom_minimum_size = Vector2(440, 0)
	card_box.add_child(_card_desc)
	_card.add_child(card_box)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -260
	_card.offset_right = 260
	_card.offset_top = 140
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_card)
	_card.modulate.a = 0.0
	_card.hide()


func _on_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = not text.is_empty()


func _on_state(s: int) -> void:
	_power_panel.visible = s == FishingController.State.CHARGING
	_reel_panel.visible = s == FishingController.State.REELING
	if s == FishingController.State.BITE:
		_hint.add_theme_color_override("font_color", UIPalette.BERRY)
	else:
		_hint.remove_theme_color_override("font_color")
	if s == FishingController.State.STOWED:
		_hint_panel.hide()


func _on_hooked(_fish: FishData) -> void:
	_reel_status.text = "Something's on the line!"
	_progress_bar.value = 0


func _on_reel(tension: float, progress: float, struggling: bool) -> void:
	_tension_bar.tension = tension
	_tension_bar.queue_redraw()
	_progress_bar.value = progress * 100.0
	if tension >= 0.95:
		_reel_status.text = "Too tight! Let go!"
	elif struggling:
		_reel_status.text = "It's pulling hard!"
	elif tension < 0.12:
		_reel_status.text = "The line is slack, reel in!"
	else:
		_reel_status.text = "Reel it in!"


func _on_catch(fish: FishData, size_cm: float, info: Dictionary) -> void:
	_card_title.text = "New species!" if info.get("is_new", false) else ("New size record!" if info.get("is_record", false) else "You caught a fish!")
	_card_name.text = fish.display_name
	_card_name.add_theme_color_override("font_color", UIPalette.RARITY[clampi(fish.rarity, 0, UIPalette.RARITY.size() - 1)])
	_card_details.text = "%.1f cm  ·  %s  ·  +%d min" % [size_cm, fish.get_rarity_name(), int(info.get("minutes", 0))]
	_card_desc.text = fish.description
	_hint_panel.hide()
	_card.show()
	_card.pivot_offset = Vector2(_card.size.x * 0.5, 0)
	_card.scale = Vector2(0.92, 0.92)
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.3)
	_card_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(3.6)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	_card_tween.tween_callback(_card.hide)


# ---- helpers ----

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.hide()
	return p


func _label(text: String, variation: StringName, size: int) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon(icon_name: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UIPalette.icon(icon_name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _place_top_center(control: Control, root: Control, width: float, top: float, height: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_TOP)
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = top
	control.offset_bottom = top + height
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(control)


## Horizontal bar: berry slack zone, leaf sweet zone, berry snap zone, and a marker.
class TensionBar extends Control:
	var tension: float = 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = Color(UIPalette.WOOD_DARK, 0.22)
		track.border_color = Color(UIPalette.WOOD, 0.55)
		track.set_border_width_all(2)
		track.set_corner_radius_all(8)
		draw_style_box(track, Rect2(0, 0, w, h))
		var inner := Rect2(3, 3, w - 6, h - 6)
		draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x * ReelMinigame.SLACK_LIMIT, inner.size.y), Color(UIPalette.BERRY, 0.45))
		draw_rect(Rect2(inner.position.x + inner.size.x * ReelMinigame.SWEET_MIN, inner.position.y, inner.size.x * (ReelMinigame.SWEET_MAX - ReelMinigame.SWEET_MIN), inner.size.y), Color(UIPalette.LEAF, 0.85))
		draw_rect(Rect2(inner.position.x + inner.size.x * 0.9, inner.position.y, inner.size.x * 0.1, inner.size.y), Color(UIPalette.BERRY, 0.8))
		var x := inner.position.x + clampf(tension, 0.0, 1.0) * inner.size.x
		var marker := UIPalette.CREAM if tension < 0.9 else UIPalette.BERRY
		var bob := StyleBoxFlat.new()
		bob.bg_color = marker
		bob.border_color = UIPalette.WOOD_DARK
		bob.set_border_width_all(2)
		bob.set_corner_radius_all(4)
		draw_style_box(bob, Rect2(x - 5, -5, 10, h + 10))
