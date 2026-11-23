class_name ItemDB
extends RefCounted
## Looks up item definitions by ID. Combines data/items/item_catalog.tres with the fish
## catalog (every fish is also a sellable item), so there's one place to ask
## "what is this item called, what does it cost, how many stack?".

const ITEM_CATALOG_PATH := "res://data/items/item_catalog.tres"
const FISH_CATALOG_PATH := "res://data/fish/fish_catalog.tres"

static var _items: Dictionary = {}
static var _loaded := false


static func get_item(item_id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(item_id)


static func has_item(item_id: StringName) -> bool:
	_ensure_loaded()
	return _items.has(item_id)


static func get_display_name(item_id: StringName) -> String:
	var item := get_item(item_id)
	return item.display_name if item else String(item_id).capitalize()


static func get_max_stack(item_id: StringName) -> int:
	var item := get_item(item_id)
	return maxi(item.max_stack, 1) if item else 99


static func all_items() -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for item in _items.values():
		result.append(item)
	return result


static func reload() -> void:
	_loaded = false
	_items.clear()
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var catalog := load(ITEM_CATALOG_PATH) as ItemCatalog
	if catalog:
		for item in catalog.items:
			if item:
				_items[item.id] = item
	var fish_catalog := load(FISH_CATALOG_PATH) as FishCatalog
	if fish_catalog:
		for fish in fish_catalog.fish:
			if fish == null or _items.has(fish.id):
				continue
			var item := ItemData.new()
			item.id = fish.id
			item.display_name = fish.display_name
			item.description = fish.description
			item.category = ItemData.Category.FISH
			item.sell_price = fish.sell_price
			item.max_stack = 30
			_items[fish.id] = item
