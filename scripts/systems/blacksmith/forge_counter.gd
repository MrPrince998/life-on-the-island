class_name ForgeCounter
extends Interactable
## Bram's forge: E opens the forge window (ForgePanel); F gives the shop view (the
## camera frames the forge and Bram, and the window opens at the side).

## The blacksmith (NPCData id) the shop view looks for.
@export var keeper_id: StringName = &"bram"


func get_prompt() -> String:
	return "%s   ·   F: shop view" % prompt_text


func _on_interact(_interactor: Node) -> void:
	var panel := _panel()
	if panel:
		panel.open(false)


func focus_shop(player: Node) -> void:
	var panel := _panel()
	if panel == null or panel.is_open():
		return
	ShopFocus.start(player, get_parent() as Node3D, self, keeper_id)
	panel.open(true)
	ShopFocus.release_when_closed(player, panel)


func _panel() -> ForgePanel:
	return get_tree().get_first_node_in_group(&"forge_panel") as ForgePanel
