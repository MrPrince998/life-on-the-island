class_name ScreenFade
extends CanvasLayer
## A full-screen colour fade (going through doors). One shared instance is created
## on first use under the scene tree's root.

var _rect: ColorRect


static func get_instance(tree: SceneTree) -> ScreenFade:
	var existing := tree.root.get_node_or_null(^"ScreenFade") as ScreenFade
	if existing:
		return existing
	var fade := ScreenFade.new()
	fade.name = "ScreenFade"
	fade.layer = 90
	tree.root.add_child(fade)
	return fade


func _init() -> void:
	_rect = ColorRect.new()
	_rect.color = Color(0.05, 0.035, 0.03, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Fades to `alpha` (1 = covered) over `seconds`; await it.
func fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, seconds)
	await tween.finished


func get_alpha() -> float:
	return _rect.color.a
