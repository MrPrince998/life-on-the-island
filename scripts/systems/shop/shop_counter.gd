class_name ShopCounter
extends Interactable
## Press E at the counter to open the store, or F for the shop view: the camera frames
## the shop and its shopkeeper and the store window opens at the side (ShopFocus).

@export var shop_title: String = "Willowbrook General Store"
## The shopkeeper (NPCData id) the shop view looks for.
@export var keeper_id: StringName = &"emma"
## The shop's root node (the building); empty = this counter's parent.
@export var shop_path: NodePath


func get_prompt() -> String:
	return "%s   ·   F: shop view" % prompt_text


func _on_interact(_interactor: Node) -> void:
	var panel := _panel()
	if panel:
		panel.open(shop_title)


func focus_shop(player: Node) -> void:
	var panel := _panel()
	if panel == null or panel.is_open():
		return
	var shop := get_node_or_null(shop_path) as Node3D if not shop_path.is_empty() else get_parent() as Node3D
	ShopFocus.start(player, shop if shop else self, self, keeper_id)
	panel.open(shop_title, true)
	ShopFocus.release_when_closed(player, panel)


func _panel() -> ShopPanel:
	return get_tree().get_first_node_in_group(&"shop_panel") as ShopPanel
