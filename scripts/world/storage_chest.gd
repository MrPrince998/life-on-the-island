class_name StorageChest
extends Interactable
## A chest you can keep things in (Grandpa's chest in the cottage). Press E to open
## the storage window: your bag on one side, the chest on the other.
##
## Holds item stacks like the bag does, in `slots` slots. Saved with the game through
## the "persistent" group, so stored things stay stored. Storing costs no time.

signal contents_changed

@export var slots: int = 30
@export var display_name: String = "Grandpa's Chest"

var _items: Dictionary = {}  # StringName -> int


func _ready() -> void:
	add_to_group(&"persistent")
	if prompt_text == "Interact":
		prompt_text = "Open %s" % display_name


func _on_interact(_interactor: Node) -> void:
	StoragePanel.get_instance(get_tree()).open_for(self)


# ---- Contents ---------------------------------------------------------------

func get_count(item_id: StringName) -> int:
	return _items.get(item_id, 0)


func get_all() -> Dictionary:
	return _items.duplicate()


func get_slots_used() -> int:
	var used := 0
	for item_id in _items:
		used += ceili(int(_items[item_id]) / float(ItemDB.get_max_stack(item_id)))
	return used


func get_room_for(item_id: StringName) -> int:
	var stack := ItemDB.get_max_stack(item_id)
	var have: int = _items.get(item_id, 0)
	var room_in_own_slots := ceili(have / float(stack)) * stack - have
	return room_in_own_slots + maxi(slots - get_slots_used(), 0) * stack


## Moves up to `amount` of an item from the bag into the chest. Returns how many moved.
func store(item_id: StringName, amount: int) -> int:
	var moving := mini(mini(amount, InventoryManager.get_count(item_id)), get_room_for(item_id))
	if moving <= 0:
		return 0
	moving = InventoryManager.remove_item(item_id, moving)
	_items[item_id] = int(_items.get(item_id, 0)) + moving
	contents_changed.emit()
	return moving


## Moves up to `amount` of an item from the chest into the bag. Returns how many moved.
func take(item_id: StringName, amount: int) -> int:
	var moving := mini(amount, get_count(item_id))
	if moving <= 0:
		return 0
	moving = InventoryManager.add_item(item_id, moving)
	if moving <= 0:
		return 0
	var left := get_count(item_id) - moving
	if left > 0:
		_items[item_id] = left
	else:
		_items.erase(item_id)
	contents_changed.emit()
	return moving


## Stores everything in the bag except tools (you keep your rod and watering can).
## Returns how many items moved.
func store_all() -> int:
	var moved := 0
	var bag := InventoryManager.get_all()
	for item_id in bag:
		var data := ItemDB.get_item(item_id)
		if data and data.category == ItemData.Category.TOOL:
			continue
		moved += store(item_id, int(bag[item_id]))
	return moved


# ---- SaveManager hook ---------------------------------------------------------

func get_save_key() -> String:
	return "storage_%s" % interaction_id


func save_state() -> Dictionary:
	var items := {}
	for item_id in _items:
		items[str(item_id)] = int(_items[item_id])
	return {"items": items}


func load_state(data: Dictionary) -> void:
	_items.clear()
	var items: Dictionary = data.get("items", {})
	for key in items:
		var count := int(items[key])
		if count > 0:
			_items[StringName(str(key))] = count
	contents_changed.emit()
