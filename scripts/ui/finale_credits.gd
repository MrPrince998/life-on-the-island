class_name FinaleCredits
extends CanvasLayer
## The gentle end of the main story: after you read Grandpa's last letter, a few lines
## fade in and out over the island at night. Press Esc or E to skip. The game carries on
## afterwards (free play).

signal finished

const LINES := [
	"Life on the Island",
	"The lighthouse shines again.",
	"The fields are golden, the forest sings, the market is full.",
	"Grandpa would be so proud.",
	"Thank you for playing.",
	"The island is yours. Take your time.",
]
const HOLD := 2.6
const FADE := 0.9

var _label: Label
var _dim: ColorRect
var _running: bool = false


static func play(tree: SceneTree) -> FinaleCredits:
	var credits := FinaleCredits.new()
	credits.name = "FinaleCredits"
	tree.root.add_child(credits)
	credits._run()
	return credits


func _init() -> void:
	layer = 20
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.04, 0.09, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_label = Label.new()
	_label.theme_type_variation = &"TitleLabel"
	_label.add_theme_font_size_override("font_size", 46)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.modulate.a = 0.0
	add_child(_label)


func is_running() -> bool:
	return _running


func _input(event: InputEvent) -> void:
	if _running and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact")):
		get_viewport().set_input_as_handled()
		_end()


func _run() -> void:
	_running = true
	_label.theme = load(UIPalette.THEME_PATH) as Theme
	var t := create_tween()
	t.tween_property(_dim, "color:a", 0.55, 1.2)
	for line in LINES:
		t.tween_callback(func() -> void: _label.text = line)
		t.tween_property(_label, "modulate:a", 1.0, FADE)
		t.tween_interval(HOLD)
		t.tween_property(_label, "modulate:a", 0.0, FADE)
	t.tween_property(_dim, "color:a", 0.0, 1.2)
	t.tween_callback(_end)


func _end() -> void:
	if not _running:
		return
	_running = false
	finished.emit()
	queue_free()
