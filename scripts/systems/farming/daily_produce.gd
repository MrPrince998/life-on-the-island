class_name DailyProduce
extends Interactable
## Something that makes an item every new in-game morning and holds a few until you
## press E to take them: Grandpa's compost bin (fertilizer), the restored greenhouse's
## seedling trays (seed packets).
##
## It only produces when the clock reaches a new day (sleeping), never on a timer, and
## taking things costs no time. With requires_flag set it stays idle until that story
## flag is on (e.g. "restored_greenhouse"). Saved through the "persistent" group.

## Items made, one per morning, taking turns through the list.
@export var item_ids: Array[StringName] = [&"fertilizer"]
@export var max_stock: int = 3
## Waiting on a new game (when active from the start).
@export var starting_stock: int = 1
## How the waiting items look: "sack" (fertilizer) or "seed_tray" (seedlings).
@export var look: StringName = &"sack"
## Where the waiting items sit, relative to this node (one per item, up to max_stock).
@export var spots: PackedVector3Array = PackedVector3Array([Vector3(0.95, -0.6, 0.35), Vector3(0.95, -0.6, -0.15), Vector3(1.3, -0.6, 0.12)])
## Story flag needed before anything is made ("" = always).
@export var requires_flag: StringName = &""
@export var empty_prompt: String = "Nothing ready yet · more every morning"
@export_multiline var taken_message: String = "You took %s."

## Items waiting to be taken, oldest first.
var stock: Array[StringName] = []
var _shown: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"persistent")
	ActivityClock.day_started.connect(_on_day_started)
	GameManager.flag_changed.connect(_on_flag_changed)
	for i in starting_stock:
		if is_active():
			stock.append(_item_for(i))
	for i in mini(max_stock, spots.size()):
		var mesh := MeshInstance3D.new()
		mesh.name = "Waiting%d" % (i + 1)
		mesh.mesh = CropVisuals.seed_tray_mesh() if look == &"seed_tray" else CropVisuals.sack_mesh()
		mesh.position = spots[i]
		mesh.rotation.y = 0.6 * i
		add_child(mesh)
		_shown.append(mesh)
	_refresh()


func is_active() -> bool:
	return requires_flag == &"" or GameManager.has_flag(requires_flag)


func get_prompt() -> String:
	if stock.is_empty():
		return empty_prompt
	return "Take %s" % _describe(stock)


func _on_interact(_interactor: Node) -> void:
	if stock.is_empty():
		GameManager.notify(empty_prompt.replace(" · ", ". ") + ".")
		return
	var taken: Array[StringName] = []
	var kept: Array[StringName] = []
	for item_id in stock:
		if InventoryManager.add_item(item_id, 1) == 1:
			taken.append(item_id)
		else:
			kept.append(item_id)
	if taken.is_empty():
		GameManager.notify("Your bag is full. Make some room first.")
		return
	stock = kept
	_refresh()
	GameManager.notify(taken_message % _describe(taken))


## Just switched on (e.g. the greenhouse was restored): the first batch is ready now.
func _on_flag_changed(flag: StringName, value: bool) -> void:
	if flag == requires_flag and value and stock.is_empty():
		for i in starting_stock:
			stock.append(_item_for(ActivityClock.get_day() + i))
	_refresh()


func _on_day_started(day: int) -> void:
	if is_active() and stock.size() < max_stock:
		stock.append(_item_for(day))
		_refresh()


func _item_for(index: int) -> StringName:
	return item_ids[posmod(index, item_ids.size())] if not item_ids.is_empty() else &""


func _refresh() -> void:
	enabled = is_active()
	for i in _shown.size():
		_shown[i].visible = i < stock.size()


## "2 Fertilizer" / "1 Carrot Seeds and 1 Turnip Seeds".
static func _describe(items: Array[StringName]) -> String:
	var counts := {}
	for item_id in items:
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	var parts: Array[String] = []
	for item_id in counts:
		parts.append("%d %s" % [counts[item_id], ItemDB.get_display_name(item_id)])
	return " and ".join(parts)


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "produce_%s" % interaction_id


func save_state() -> Dictionary:
	var ids: Array[String] = []
	for item_id in stock:
		ids.append(String(item_id))
	return {"stock": ids}


func load_state(data: Dictionary) -> void:
	stock.clear()
	var ids: Variant = data.get("stock", [])
	if typeof(ids) == TYPE_ARRAY:
		for item_id in ids:
			if ItemDB.has_item(StringName(str(item_id))) and stock.size() < max_stock:
				stock.append(StringName(str(item_id)))
	_refresh()
