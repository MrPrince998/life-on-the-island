class_name CookingSpot
extends Interactable
## Grandpa's stove: press E to open the cooking window. Also tells you when a villager
## has taught you a new recipe (its flag turns on).


func _ready() -> void:
	if prompt_text == "Interact":
		prompt_text = "Cook at Grandpa's stove"
	GameManager.flag_changed.connect(_on_flag_changed)


func _on_interact(_interactor: Node) -> void:
	CookingPanel.get_instance(get_tree()).open()


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if not value:
		return
	for recipe in CookingService.get_recipes():
		if recipe.requires_flag == flag:
			GameManager.notify("New recipe: %s! Cook it at Grandpa's stove." % ItemDB.get_display_name(recipe.result_item))
