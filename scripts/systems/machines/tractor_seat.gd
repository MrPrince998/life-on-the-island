class_name TractorSeat
extends Interactable
## "Drive the tractor" (E by the tractor). Only once the tractor has been restored.

var tractor: Tractor


func can_interact_now(player: Node) -> bool:
	if tractor == null or not tractor.is_restored() or tractor.has_driver():
		return false
	return not (player is PlayerController and (player as PlayerController).is_hands_busy())


func get_prompt() -> String:
	return "Drive Grandpa's tractor"


func _on_interact(interactor: Node) -> void:
	if tractor:
		tractor.mount(interactor as PlayerController)
