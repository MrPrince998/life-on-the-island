class_name ShopCounter
extends Interactable
## Press E at the counter to open the store.

@export var shop_title: String = "Willowbrook General Store"


func _on_interact(_interactor: Node) -> void:
	var panel := get_tree().get_first_node_in_group(&"shop_panel") as ShopPanel
	if panel:
		panel.open(shop_title)
