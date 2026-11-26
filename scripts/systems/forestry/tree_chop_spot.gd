class_name TreeChopSpot
extends Interactable
## The "Fell the tree" prompt. The ForestService keeps this one spot on the standing
## tree nearest the player (when they carry an axe), so the thousands of scattered trees
## don't each need their own interaction area.

var service: ForestService
## The tree it's on: {layer_id, index, transform} ({} = none).
var tree: Dictionary = {}


func _init() -> void:
	super()
	interaction_id = &"fell_tree"


func can_interact_now(player: Node) -> bool:
	return not tree.is_empty() and player is PlayerController and not (player as PlayerController).is_hands_busy()


func get_prompt() -> String:
	if tree.is_empty() or service == null:
		return ""
	var layer := service.get_layer(tree.layer_id)
	var swings := WoodcuttingController.swings_for(layer.chop_hits if layer else 5)
	return "Fell the tree  (%s · %d swings · %d min)" % [ItemDB.get_display_name(WoodcuttingController.best_axe()), swings, service.fell_minutes()]


func _on_interact(interactor: Node) -> void:
	if service and not tree.is_empty():
		service.fell(tree, interactor)
