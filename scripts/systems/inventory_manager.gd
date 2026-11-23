extends Node
## InventoryManager (autoload) — what the player is carrying, and their coins.
##
## Items are stored by stable string ID with a count. The bag has BAG_SLOTS slots;
## each slot holds up to the item's max_stack (see ItemData / ItemDB). Adding more
## than fits adds what it can and returns how many went in.

signal inventory_changed(item_id: StringName, new_count: int)
signal money_changed(new_total: int)

const SAVE_VERSION := 2
const BAG_SLOTS := 24
## The most the bag can grow to with every bag upgrade (UpgradeService.bag_bonus).
const MAX_BAG_SLOTS := 36
const STARTING_MONEY := 50

var _items: Dictionary = {}  # StringName -> int
var _money: int = STARTING_MONEY


# ---- Items -----------------------------------------------------------------

## Adds up to `amount`, as far as the bag has room. Returns how many were added.
func add_item(item_id: StringName, amount: int = 1) -> int:
	if amount <= 0:
		return 0
	var added := mini(amount, get_room_for(item_id))
	if added <= 0:
		return 0
	var total: int = _items.get(item_id, 0) + added
	_items[item_id] = total
	inventory_changed.emit(item_id, total)
	return added


## Removes up to `amount`. Returns how many were actually removed.
func remove_item(item_id: StringName, amount: int = 1) -> int:
	var have: int = _items.get(item_id, 0)
	var removed := mini(have, maxi(amount, 0))
	if removed == 0:
		return 0
	if have - removed <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = have - removed
	inventory_changed.emit(item_id, have - removed)
	return removed


func get_count(item_id: StringName) -> int:
	return _items.get(item_id, 0)


func has_item(item_id: StringName, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


## How many more of this item fit in the bag right now.
func get_room_for(item_id: StringName) -> int:
	var stack := ItemDB.get_max_stack(item_id)
	var have: int = _items.get(item_id, 0)
	var room_in_own_slots := (ceili(have / float(stack)) * stack) - have
	var free_slots := get_bag_slots() - get_slots_used()
	return room_in_own_slots + free_slots * stack


func get_slots_used() -> int:
	var used := 0
	for item_id in _items:
		used += ceili(_items[item_id] / float(ItemDB.get_max_stack(item_id)))
	return used


func is_full() -> bool:
	return get_slots_used() >= get_bag_slots()


## Slots in the bag right now: BAG_SLOTS, plus any bag upgrades bought.
func get_bag_slots() -> int:
	return mini(BAG_SLOTS + UpgradeService.bag_bonus(), MAX_BAG_SLOTS)


## Copy of all items: {item_id: count}.
func get_all() -> Dictionary:
	return _items.duplicate()


# ---- Coins ------------------------------------------------------------------

func get_money() -> int:
	return _money


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	_money += amount
	money_changed.emit(_money)


## Spends coins if there are enough. Returns false (and spends nothing) otherwise.
func spend_money(amount: int) -> bool:
	if amount < 0 or amount > _money:
		return false
	if amount > 0:
		_money -= amount
		money_changed.emit(_money)
	return true


# ---- Save ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var items := {}
	for key in _items:
		items[String(key)] = _items[key]
	return {"version": SAVE_VERSION, "items": items, "money": _money}


## Loads saved data. Version 1 saves had no coins; they start with STARTING_MONEY.
func from_dict(data: Dictionary) -> void:
	_items.clear()
	var items: Dictionary = data.get("items", {})
	for key in items:
		var count := int(items[key])
		if count > 0:
			_items[StringName(key)] = count
	var version := int(data.get("version", 1))
	_money = maxi(int(data.get("money", STARTING_MONEY)), 0) if version >= 2 else STARTING_MONEY
	inventory_changed.emit(&"", 0)
	money_changed.emit(_money)


## Empties the bag (coins are kept). Use reset() for a brand-new game.
func clear() -> void:
	_items.clear()
	inventory_changed.emit(&"", 0)


func reset() -> void:
	_items.clear()
	_money = STARTING_MONEY
	inventory_changed.emit(&"", 0)
	money_changed.emit(_money)
