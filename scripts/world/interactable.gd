class_name Interactable
extends Area3D
## Base component for anything the player can press E on.
## Give it a CollisionShape3D child. Subclasses override _on_interact().

signal interacted(interactor: Node)

## Stable ID for saves and quests (do not rely on node names).
@export var interaction_id: StringName = &""
@export var prompt_text: String = "Interact"
@export var enabled: bool = true


func _init() -> void:
	collision_layer = 4  # "interactables"
	collision_mask = 0
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt_text


func interact(interactor: Node) -> void:
	if not enabled:
		return
	_on_interact(interactor)
	interacted.emit(interactor)


func _on_interact(_interactor: Node) -> void:
	pass
