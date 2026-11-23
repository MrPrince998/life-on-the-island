extends SceneTree
## Dev tool: builds the cozy UI theme used by every screen in the game.
## Run: Godot --headless --path . --script res://tools/build_ui_theme.gd
## Output: res://assets/ui/cozy_theme.tres (set as the project's custom theme).
##
## Look: warm parchment panels with a wooden border and a soft shadow, dark-brown
## rounded text (Fredoka for headings, Nunito for body), wooden buttons, honey/leaf/sky
## bars. Colours live in scripts/ui/ui_palette.gd.
##
## Type variations (set a Control's theme_type_variation to use them):
##   PanelContainer: WoodPanel (wooden plaque), KeyCap (keyboard key), InsetPanel (row/slot)
##   Button: SlotButton (bag/shop item slot; toggle it to show "selected")
##   Label: HeaderLabel, TitleLabel (big outlined region title), SubtleLabel, WoodLabel,
##          KeyLabel, BigLabel
##   ProgressBar: LeafBar, SkyBar (default fill is honey)

const P := preload("res://scripts/ui/ui_palette.gd")


func _init() -> void:
	var fredoka := load("res://assets/ui/fonts/Fredoka.ttf") as FontFile
	var nunito := load("res://assets/ui/fonts/Nunito.ttf") as FontFile
	var body := _font(nunito, 650)
	var bold := _font(nunito, 800)
	var heading := _font(fredoka, 600)

	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 18

	# ---- Text ----
	t.set_color("font_color", "Label", P.INK)
	t.set_color("font_outline_color", "Label", P.CREAM)
	t.set_constant("outline_size", "Label", 0)
	t.set_constant("line_spacing", "Label", 2)

	_label_variation(t, "HeaderLabel", heading, 26, P.WOOD_DARK)
	_label_variation(t, "BigLabel", heading, 34, P.INK)
	_label_variation(t, "SubtleLabel", body, 15, P.INK_SOFT)
	_label_variation(t, "WoodLabel", heading, 18, P.CREAM)
	_label_variation(t, "KeyLabel", heading, 18, P.WOOD_DARK)
	_label_variation(t, "TitleLabel", heading, 50, P.CREAM)
	t.set_color("font_outline_color", "TitleLabel", P.WOOD_DARK)
	t.set_constant("outline_size", "TitleLabel", 14)
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_y", "TitleLabel", 4)
	t.set_constant("shadow_outline_size", "TitleLabel", 14)

	# ---- Panels ----
	var parchment := _box(P.PARCHMENT, P.WOOD, 3, 16)
	parchment.shadow_color = P.SHADOW
	parchment.shadow_size = 8
	parchment.shadow_offset = Vector2(0, 4)
	_margins(parchment, 20, 14)
	t.set_stylebox("panel", "PanelContainer", parchment)
	t.set_stylebox("panel", "Panel", parchment)

	t.set_type_variation("WoodPanel", "PanelContainer")
	var wood := _box(P.WOOD, P.WOOD_DARK, 3, 16)
	wood.border_width_bottom = 6
	wood.shadow_color = P.SHADOW
	wood.shadow_size = 8
	wood.shadow_offset = Vector2(0, 4)
	_margins(wood, 18, 10)
	t.set_stylebox("panel", "WoodPanel", wood)

	t.set_type_variation("InsetPanel", "PanelContainer")
	var inset := _box(P.PARCHMENT_DARK, Color(P.WOOD, 0.35), 2, 10)
	_margins(inset, 12, 6)
	t.set_stylebox("panel", "InsetPanel", inset)

	t.set_type_variation("KeyCap", "PanelContainer")
	var key := _box(P.CREAM, P.WOOD, 2, 8)
	key.border_width_bottom = 4
	_margins(key, 10, 1)
	t.set_stylebox("panel", "KeyCap", key)

	# ---- Buttons ----
	t.set_font("font", "Button", heading)
	t.set_font_size("font_size", "Button", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", P.CREAM)
	t.set_color("font_disabled_color", "Button", Color(P.CREAM, 0.6))
	# Cream on light wood is only ~3.7:1 contrast, so button text gets a dark wood outline.
	t.set_color("font_outline_color", "Button", P.WOOD_DARK)
	t.set_constant("outline_size", "Button", 5)
	var btn := _box(P.WOOD_LIGHT, P.WOOD_DARK, 3, 12)
	btn.border_width_bottom = 6
	_margins(btn, 18, 8)
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = P.WOOD_LIGHT.lightened(0.15)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = P.WOOD
	pressed.border_width_bottom = 3
	pressed.content_margin_top += 3
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(P.WOOD_LIGHT, 0.5)
	var focus := _box(Color(0, 0, 0, 0), P.HONEY, 3, 14)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)

	# ---- Bag / item slots (Button variation "SlotButton") ----
	t.set_type_variation("SlotButton", "Button")
	var slot := _box(P.PARCHMENT_DARK, Color(P.WOOD, 0.45), 2, 12)
	_margins(slot, 4, 4)
	var slot_hover := _box(P.PARCHMENT_DARK.lightened(0.06), P.HONEY, 2, 12)
	_margins(slot_hover, 4, 4)
	var slot_selected := _box(Color("f3dca6"), P.HONEY, 4, 12)
	_margins(slot_selected, 4, 4)
	var slot_empty := _box(Color(P.PARCHMENT_DARK, 0.55), Color(P.WOOD, 0.22), 2, 12)
	_margins(slot_empty, 4, 4)
	t.set_stylebox("normal", "SlotButton", slot)
	t.set_stylebox("hover", "SlotButton", slot_hover)
	t.set_stylebox("pressed", "SlotButton", slot_selected)
	t.set_stylebox("hover_pressed", "SlotButton", slot_selected)
	t.set_stylebox("disabled", "SlotButton", slot_empty)
	t.set_stylebox("focus", "SlotButton", focus)

	# Dimmed backdrop behind pop-up windows.
	t.set_color("dim_color", "PopupDim", Color(0.1, 0.07, 0.04, 0.45))

	# ---- Bars ----
	var track := _box(Color(P.WOOD_DARK, 0.22), Color(P.WOOD, 0.55), 2, 8)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", _box(P.HONEY, P.WOOD_DARK, 2, 8))
	t.set_font("font", "ProgressBar", bold)
	t.set_color("font_color", "ProgressBar", P.INK)
	for bar in [["LeafBar", P.LEAF], ["SkyBar", P.SKY]]:
		t.set_type_variation(bar[0], "ProgressBar")
		t.set_stylebox("fill", bar[0], _box(bar[1], P.WOOD_DARK, 2, 8))

	# ---- Bits and pieces ----
	var line := StyleBoxLine.new()
	line.color = Color(P.WOOD, 0.45)
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 10)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 10)
	var tip := _box(P.PARCHMENT, P.WOOD, 2, 10)
	_margins(tip, 12, 6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", P.INK)

	var err := ResourceSaver.save(t, P.THEME_PATH)
	print("saved ", P.THEME_PATH, " ", error_string(err))
	quit(0 if err == OK else 1)


func _font(base: FontFile, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	# Variable fonts: the weight axis must be keyed by its OpenType tag number.
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _label_variation(t: Theme, type_name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(type_name, "Label")
	t.set_font("font", type_name, font)
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)


func _box(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


func _margins(s: StyleBox, horizontal: float, vertical: float) -> void:
	s.content_margin_left = horizontal
	s.content_margin_right = horizontal
	s.content_margin_top = vertical
	s.content_margin_bottom = vertical
