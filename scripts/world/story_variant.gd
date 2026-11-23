@tool
class_name StoryVariant
extends Node3D
## A place that looks different once a story flag is set: a ruined windmill that is
## later repaired, a bramble tangle that is later cleared.
##
## Children whose names start with "Before" show until `flag` is set; children whose
## names start with "After" show from then on. Hidden children are also switched off,
## so their collision goes away too. Story flags are saved by GameManager, so a loaded
## game shows the right look. Flags for buildings follow RestorationSite's
## "restored_<id>" naming.

@export var flag: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		_show(false)
		return
	GameManager.flag_changed.connect(_on_flag_changed)
	_show(is_after())


func is_after() -> bool:
	return not Engine.is_editor_hint() and GameManager.has_flag(flag)


func _on_flag_changed(changed: StringName, _value: bool) -> void:
	if changed == flag:
		_show(is_after())


func _show(after: bool) -> void:
	for child in get_children():
		var node := child as Node3D
		if node == null:
			continue
		var name_text := String(node.name)
		var on := true
		if name_text.begins_with("Before"):
			on = not after
		elif name_text.begins_with("After"):
			on = after
		node.visible = on
		node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
