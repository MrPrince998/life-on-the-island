class_name PaddyPump
extends Interactable
## The hand pump and sluice at the corner of the paddy: E pumps water in (floods it) or
## opens the sluice (drains it). The rice needs standing water to grow, and dry ground
## to be cut.

@export var field_path: NodePath = ^".."


func _field() -> CropField:
	return get_node_or_null(field_path) as CropField


func can_interact_now(player: Node) -> bool:
	var field := _field()
	if field == null or field.is_busy():
		return false
	return not (player is PlayerController and (player as PlayerController).is_hands_busy())


func get_prompt() -> String:
	var field := _field()
	return field.pump_prompt() if field else ""


func _on_interact(interactor: Node) -> void:
	var field := _field()
	if field:
		await field.use_pump(interactor as PlayerController)
