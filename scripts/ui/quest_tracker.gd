class_name QuestTracker
extends PanelContainer
## The quest list under the minimap (newest quests first, up to MAX_SHOWN): each active
## quest's title and the step to do now,
## with progress ("Wooden Planks 3/8"). Finished steps flash a green tick before the
## next one appears. Reads QuestLog; never changes anything.

const MAX_SHOWN := 4
const WIDTH := 250.0
const FLASH_TIME := 1.6

var _list: VBoxContainer
var _flashes: VBoxContainer
var _rebuild_queued: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = UIPalette.icon("book")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var title := Label.new()
	title.name = "Title"
	title.text = "Quests"
	title.theme_type_variation = &"HeaderLabel"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)
	_flashes = VBoxContainer.new()
	_flashes.name = "Flashes"
	_flashes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_flashes)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	QuestLog.quest_started.connect(func(_q: QuestData) -> void: _queue_rebuild())
	QuestLog.quest_updated.connect(func(_q: QuestData) -> void: _queue_rebuild())
	QuestLog.quest_announced.connect(_on_quest_announced)
	QuestLog.step_completed.connect(_on_step_completed)
	QuestLog.quest_completed.connect(_on_quest_completed)
	# Counts ("3/8") follow the bag and coins.
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void: _queue_rebuild())
	InventoryManager.money_changed.connect(func(_m: int) -> void: _queue_rebuild())
	rebuild()


## Lines currently listed (for tests): [[quest title, step text], ...].
func get_lines() -> Array:
	var lines := []
	for entry in _list.get_children():
		if entry.has_meta(&"quest_id"):
			lines.append([entry.get_meta(&"title"), entry.get_meta(&"step")])
	return lines


func rebuild() -> void:
	_rebuild_queued = false
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	# Newest first, so a request you've just accepted is always on screen.
	var active := QuestLog.get_active_quests()
	active.reverse()
	for i in mini(active.size(), MAX_SHOWN):
		_list.add_child(_entry(active[i]))
	if active.size() > MAX_SHOWN:
		var more := Label.new()
		more.theme_type_variation = &"SubtleLabel"
		more.add_theme_font_size_override("font_size", 14)
		more.text = "+%d more" % (active.size() - MAX_SHOWN)
		_list.add_child(more)
	_update_visibility()


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		rebuild.call_deferred()


func _entry(quest: QuestData) -> Control:
	var entry := VBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_theme_constant_override("separation", 2)
	var step := QuestLog.get_current_step(quest.id)
	var step_text := step.text if step else ""
	if step and step.shows_count():
		var progress := QuestLog.get_step_progress(quest.id)
		step_text += "  %d/%d" % [progress.x, progress.y]
	entry.set_meta(&"quest_id", quest.id)
	entry.set_meta(&"title", quest.title)
	entry.set_meta(&"step", step_text)
	var title := Label.new()
	title.text = quest.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UIPalette.WOOD)
	entry.add_child(title)
	entry.add_child(_step_row(step_text, false))
	return entry


func _step_row(text: String, done: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var box := CheckMark.new()
	box.done = done
	row.add_child(box)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 52.0, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UIPalette.LEAF.darkened(0.25) if done else UIPalette.INK)
	row.add_child(label)
	return row


func _on_quest_announced(quest: QuestData) -> void:
	var row := _step_row("New quest: %s" % quest.title, false)
	(row.get_child(0) as Control).visible = false
	(row.get_child(1) as Label).add_theme_color_override("font_color", UIPalette.WOOD)
	_flash(row)
	_queue_rebuild()


func _on_step_completed(quest: QuestData, step_index: int) -> void:
	_flash(_step_row(quest.steps[step_index].text, true))
	_queue_rebuild()


func _on_quest_completed(quest: QuestData) -> void:
	_flash(_step_row("%s complete!" % quest.title, true))
	_queue_rebuild()


## A ticked line that fades away after a moment.
func _flash(row: Control) -> void:
	_flashes.add_child(row)
	_update_visibility()
	row.modulate.a = 0.0
	var tween := row.create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.2)
	tween.tween_interval(FLASH_TIME)
	tween.tween_property(row, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		row.queue_free()
		_update_visibility.call_deferred())


func _update_visibility() -> void:
	var flashing := 0
	for child in _flashes.get_children():
		if not child.is_queued_for_deletion():
			flashing += 1
	visible = flashing > 0 or not QuestLog.get_active_quests().is_empty()


## A small rounded checkbox, ticked when done.
class CheckMark:
	extends Control

	var done: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2(1, 3), Vector2(14, 14))
		draw_style_box(_box_style(), rect)
		if done:
			var points := PackedVector2Array([Vector2(4, 10), Vector2(7, 13.5), Vector2(13, 5.5)])
			draw_polyline(points, UIPalette.LEAF.darkened(0.3), 2.5, true)

	func _box_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = UIPalette.CREAM if not done else UIPalette.LEAF.lightened(0.55)
		style.border_color = UIPalette.WOOD_LIGHT
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		return style
