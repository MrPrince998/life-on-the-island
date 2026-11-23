class_name TalkSpot
extends Interactable
## The "E  Talk to ___" area around a villager. Talking never uses time.

@export var villager_path: NodePath = ^".."


func get_prompt() -> String:
	var villager := get_node_or_null(villager_path) as Villager
	return villager.get_talk_prompt() if villager else prompt_text


func _on_interact(interactor: Node) -> void:
	var villager := get_node_or_null(villager_path) as Villager
	if villager:
		villager.talk(interactor)


## G near the villager: give them a gift.
func give_gift(interactor: Node) -> void:
	var villager := get_node_or_null(villager_path) as Villager
	if villager:
		villager.request_gift(interactor)
