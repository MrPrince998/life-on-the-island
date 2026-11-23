class_name JournalPanel
extends CanvasLayer
## The collection journal (J): everything you've found and everyone you know.
##   Fish       every species: caught ones with count and best size; others as a
##              mystery with a hint about where and when they bite
##   Crops      how many of each you've harvested
##   Villagers  hearts, and the gift tastes you've discovered
##   Pages      Grandpa's journal pages you've found (read them again)
##   Songs      Grandpa's ukulele melodies, known and still to find
## Only reads the game's records; opening it costs no time.

enum Tab { FISH, CROPS, VILLAGERS, PAGES, SONGS }

const TAB_NAMES := ["Fish", "Crops", "Villagers", "Grandpa's Pages", "Songs"]
const WATER_NAMES := {"moonlit_lake": "Moonlit Lake", "sea": "the sea"}
const RARITY_NAMES := ["Common", "Uncommon", "Rare"]

var _root: Control
var _window: PanelContainer
var _tab_buttons: Array[Button] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _summary: Label
var _tab: int = Tab.FISH


func _ready() -> void:
	add_to_group(&"journal_panel")
	layer = 4
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func get_tab() -> int:
	return _tab


func open(tab: int = -1) -> bool:
	if is_open():
		if tab >= 0:
			show_tab(tab)
		return true
	var player := _player()
	if player and player.is_input_locked():
		return false
	_root.show()
	if player:
		player.set_input_locked(true)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_tab(tab if tab >= 0 else _tab)
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


func show_tab(tab: int) -> void:
	_tab = clampi(tab, 0, Tab.size() - 1)
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == _tab
	_rebuild()


## Entries on the current tab (for tests): [[title, detail], ...].
func get_entries() -> Array:
	var result := []
	for card in _list.get_children():
		if card.has_meta(&"title"):
			result.append([card.get_meta(&"title"), card.get_meta(&"detail")])
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_journal") and not is_open():
		if open():
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"toggle_journal") or event.is_action_pressed(&"toggle_mouse") or event.is_action_pressed(&"toggle_bag"):
		get_viewport().set_input_as_handled()
		close()


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController


# ---- Pages of the journal ---------------------------------------------------------------

func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.FISH:
			_fish_tab()
		Tab.CROPS:
			_crops_tab()
		Tab.VILLAGERS:
			_villagers_tab()
		Tab.PAGES:
			_pages_tab()
		Tab.SONGS:
			_songs_tab()
	_scroll.scroll_vertical = 0


func _fish_tab() -> void:
	var catalog := load("res://data/fish/fish_catalog.tres") as FishCatalog
	var caught := 0
	for fish in catalog.fish:
		var entry := Journal.get_fish_entry(fish.id)
		if entry.is_empty():
			_card(UIPalette.icon("fish"), "? ? ?", "%s fish. Try %s, %s." % [RARITY_NAMES[fish.rarity], _water_text(fish), _hours_text(fish)], false, fish.ui_color.darkened(0.6))
		else:
			caught += 1
			_card(UIPalette.icon("fish"), fish.display_name, "Caught %d  ·  biggest %.1f cm  ·  %s\n%s" % [int(entry.count), float(entry.best_cm), RARITY_NAMES[fish.rarity], fish.description], true, fish.ui_color)
	_summary.text = "Fish caught: %d of %d" % [caught, catalog.fish.size()]


func _crops_tab() -> void:
	var grown := 0
	for crop in CropCatalog.shared().crops:
		var count := Journal.get_harvest_count(crop.id)
		var item := ItemDB.get_item(crop.harvest_item_id)
		var icon := item.icon if item and item.icon else UIPalette.icon("leaf")
		if count > 0:
			grown += 1
			_card(icon, crop.display_name, "Harvested %d  ·  plant in %s  ·  about %d hours to grow" % [count, crop.get_seasons_text(), roundi(crop.grow_hours)], true)
		else:
			_card(icon, crop.display_name, "Not grown yet. Plant in %s; the General Store sells %s in season." % [crop.get_seasons_text(), ItemDB.get_display_name(crop.seed_item_id)], false)
	_summary.text = "Crops grown: %d of %d" % [grown, CropCatalog.shared().crops.size()]


func _villagers_tab() -> void:
	var met := 0
	var villagers := get_tree().get_nodes_in_group(&"villagers")
	# Friends you've met first (alphabetically), then the ones still to meet.
	villagers.sort_custom(func(a: Node, b: Node) -> bool:
		var va := a as Villager
		var vb := b as Villager
		if va.has_met() != vb.has_met():
			return va.has_met()
		return String(va.data.display_name) < String(vb.data.display_name))
	for node in villagers:
		var villager := node as Villager
		if villager == null or villager.data == null:
			continue
		var npc := villager.data
		if not villager.has_met():
			_card(UIPalette.icon("heart_empty"), "? ? ?", "Someone you haven't met yet.", false)
			continue
		met += 1
		var hearts := Friendship.get_hearts(npc.id)
		var heart_text := "♥".repeat(hearts) + "♡".repeat(Friendship.MAX_HEARTS - hearts)
		var tastes := Friendship.get_known_tastes(npc.id)
		var loves: Array[String] = []
		var likes: Array[String] = []
		for item_id in tastes:
			if tastes[item_id] == Friendship.Taste.LOVED:
				loves.append(ItemDB.get_display_name(item_id))
			elif tastes[item_id] == Friendship.Taste.LIKED:
				likes.append(ItemDB.get_display_name(item_id))
		var detail := "%s  ·  %s" % [npc.role, heart_text]
		detail += "\nLoves: " + (", ".join(loves) if not loves.is_empty() else "give gifts to find out")
		if not likes.is_empty():
			detail += "\nLikes: " + ", ".join(likes)
		_card(UIPalette.icon("heart" if hearts > 0 else "heart_empty"), npc.display_name, detail, true)
	_summary.text = "Villagers met: %d of %d" % [met, villagers.size()]


func _pages_tab() -> void:
	var texts := {}
	for node in get_tree().root.find_children("*", "JournalPage", true, false):
		var page := node as JournalPage
		texts[page.page] = page.text
	for flag in GameManager.flags_to_dict().get("flags", []):
		var name := String(flag)
		if name.begins_with("journal_page_") and name.trim_prefix("journal_page_").is_valid_int():
			var n := name.trim_prefix("journal_page_").to_int()
			if not texts.has(n):
				texts[n] = ""
	var numbers := texts.keys()
	numbers.sort()
	var found := 0
	for n in numbers:
		if GameManager.has_flag(StringName("journal_page_%d" % n)):
			found += 1
			var text: String = texts[n]
			_card(UIPalette.icon("book"), "Page %d" % n, "\"%s\"" % text if not text.is_empty() else "(You read this page.)", true)
		else:
			_card(UIPalette.icon("book"), "Page %d" % n, "Not found yet.", false)
	_summary.text = "Pages found: %d of %d" % [found, numbers.size()]


func _songs_tab() -> void:
	var uke := get_tree().get_first_node_in_group(&"ukulele_controller") as UkuleleController
	var known_count := 0
	for melody in MelodyCatalog.shared().melodies:
		var known := uke != null and uke.is_known(melody)
		if known:
			known_count += 1
			_card(UIPalette.icon("ukulele"), melody.title, "Notes: %s\n%s" % [melody.notes_text(), melody.description], true)
		else:
			_card(UIPalette.icon("ukulele"), "? ? ?", melody.hint if not melody.hint.is_empty() else "A tune still to find.", false)
	_summary.text = "Songs known: %d of %d" % [known_count, MelodyCatalog.shared().melodies.size()]


func _water_text(fish: FishData) -> String:
	var places: Array[String] = []
	for water in fish.water_ids:
		places.append(WATER_NAMES.get(water, water))
	return " or ".join(places) if not places.is_empty() else "the water"


func _hours_text(fish: FishData) -> String:
	var text := "any time" if fish.start_hour == 0 and fish.end_hour == 24 else "%s to %s" % [_clock(fish.start_hour), _clock(fish.end_hour)]
	if not fish.seasons.is_empty():
		var names: Array[String] = []
		for season in fish.seasons:
			names.append(String(season).capitalize())
		text += " (%s)" % ", ".join(names)
	return text


static func _clock(hour: int) -> String:
	var h := hour % 24
	var suffix := "AM" if h < 12 else "PM"
	var shown := h % 12
	return "%d %s" % [12 if shown == 0 else shown, suffix]


# ---- Layout ----------------------------------------------------------------------------

func _card(icon: Texture2D, title: String, detail: String, found: bool, tint: Color = Color.WHITE) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InsetPanel"
	card.set_meta(&"title", title)
	card.set_meta(&"detail", detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.custom_minimum_size = Vector2(44, 44)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.modulate = (tint if tint != Color.WHITE else Color.WHITE) if found else Color(0.35, 0.3, 0.27, 0.55)
	row.add_child(pic)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", UIPalette.WOOD if found else UIPalette.INK_SOFT)
	text_box.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", UIPalette.INK if found else UIPalette.INK_SOFT)
	text_box.add_child(detail_label)
	_list.add_child(card)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.04, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(780, 560)
	center.add_child(_window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_window.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	var book := TextureRect.new()
	book.texture = UIPalette.icon("book")
	book.custom_minimum_size = Vector2(38, 38)
	book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	book.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(book)
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "Journal"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_summary = Label.new()
	_summary.theme_type_variation = &"SubtleLabel"
	_summary.add_theme_font_size_override("font_size", 17)
	header.add_child(_summary)
	box.add_child(header)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var tab_button := Button.new()
		tab_button.text = TAB_NAMES[i]
		tab_button.toggle_mode = true
		tab_button.button_group = group
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.pressed.connect(func() -> void: show_tab(i))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)
	box.add_child(tabs)
	box.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 400)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

	var footer := HBoxContainer.new()
	var hint := Label.new()
	hint.theme_type_variation = &"SubtleLabel"
	hint.text = "J, Tab or Esc to close"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 14)
	footer.add_child(hint)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 38)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	box.add_child(footer)
