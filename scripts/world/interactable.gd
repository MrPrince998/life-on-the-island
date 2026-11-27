class_name Interactable
extends Area3D
## Base component for anything the player can press E on.
## Give it a CollisionShape3D child. Subclasses override _on_interact().

signal interacted(interactor: Node)

## Stable ID for saves and quests (do not rely on node names).
@export var interaction_id: StringName = &""
@export var prompt_text: String = "Interact"
@export var enabled: bool = true
## Position of the selected-object diamond relative to this interaction area.
@export var focus_offset: Vector3 = Vector3(0, 2.0, 0)


func _init() -> void:
	collision_layer = 4  # "interactables"
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt_text


func get_focus_position() -> Vector3:
	return to_global(focus_offset)


func interact(interactor: Node) -> void:
	if not enabled:
		return
	_on_interact(interactor)
	interacted.emit(interactor)


func _on_interact(_interactor: Node) -> void:
	pass
