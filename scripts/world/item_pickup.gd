class_name ItemPickup
extends Interactable
## Something left lying in the world that the player can take once (press E):
## Grandpa's watering can, a packet of seeds, later letters and keepsakes.
##
## Remembered in saves by its interaction_id through the "persistent" group, so a
## taken pickup stays gone. Taking things costs no time.

signal taken(pickup: ItemPickup)

## Items given, as {item_id: amount}.
@export var items: Dictionary = {}
## Toast shown when taken.
@export_multiline var message: String = ""
## Nodes hidden once taken (the visible objects). Empty = hide this node's children.
@export var hide_when_taken: Array[NodePath] = []

var is_taken: bool = false


func _ready() -> void:
	add_to_group(&"persistent")
	_apply_taken()


func _on_interact(_interactor: Node) -> void:
	if is_taken:
		return
	var got_any := false
	var no_room := false
	for item_id in items:
		var wanted := int(items[item_id])
		var id := StringName(str(item_id))
		var item := ItemDB.get_item(id)
		# Unique tools you already own are left where they are.
		if item and item.unique and InventoryManager.has_item(id):
			continue
		var added := InventoryManager.add_item(id, wanted)
		got_any = got_any or added > 0
		no_room = no_room or added < wanted
	if not got_any and no_room:
		GameManager.notify("Your bag is full. Make some room and come back.")
		return
	is_taken = true
	_apply_taken()
	if not message.is_empty():
		GameManager.notify(message)
	taken.emit(self)


func _apply_taken() -> void:
	enabled = not is_taken
	if hide_when_taken.is_empty():
		for child in get_children():
			if child is Node3D:
				(child as Node3D).visible = not is_taken
	else:
		for path in hide_when_taken:
			var node := get_node_or_null(path) as Node3D
			if node:
				node.visible = not is_taken


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "pickup_%s" % interaction_id


func save_state() -> Dictionary:
	return {"taken": is_taken}


func load_state(data: Dictionary) -> void:
	is_taken = bool(data.get("taken", false))
	_apply_taken()
