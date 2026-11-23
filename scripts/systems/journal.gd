extends Node
## Journal (autoload) — the player's collection records.
## Fish: which species were caught, how many, and the biggest one.
## Crops: how many of each crop you've harvested.

signal fish_recorded(fish_id: StringName, size_cm: float, is_new_species: bool, is_record: bool)
signal crop_recorded(crop_id: StringName, total: int)

const SAVE_VERSION := 1

var _fish: Dictionary = {}  # StringName -> {"count": int, "best_cm": float}
var _crops: Dictionary = {}  # StringName -> int (harvested)


func record_harvest(crop_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	_crops[crop_id] = int(_crops.get(crop_id, 0)) + amount
	crop_recorded.emit(crop_id, int(_crops[crop_id]))


func get_harvest_count(crop_id: StringName) -> int:
	return int(_crops.get(crop_id, 0))


func record_fish(fish_id: StringName, size_cm: float) -> Dictionary:
	var is_new := not _fish.has(fish_id)
	var entry: Dictionary = _fish.get(fish_id, {"count": 0, "best_cm": 0.0})
	var is_record := not is_new and size_cm > float(entry.best_cm)
	entry.count = int(entry.count) + 1
	entry.best_cm = maxf(float(entry.best_cm), size_cm)
	_fish[fish_id] = entry
	fish_recorded.emit(fish_id, size_cm, is_new, is_record)
	return {"is_new": is_new, "is_record": is_record}


func has_caught(fish_id: StringName) -> bool:
	return _fish.has(fish_id)


func get_fish_entry(fish_id: StringName) -> Dictionary:
	return _fish.get(fish_id, {}).duplicate()


func species_caught() -> int:
	return _fish.size()


func to_dict() -> Dictionary:
	var fish := {}
	for key in _fish:
		fish[String(key)] = _fish[key]
	var crops := {}
	for key in _crops:
		crops[String(key)] = _crops[key]
	return {"version": SAVE_VERSION, "fish": fish, "crops": crops}


func from_dict(data: Dictionary) -> void:
	_fish.clear()
	_crops.clear()
	var crops: Variant = data.get("crops", {})
	if typeof(crops) == TYPE_DICTIONARY:
		for key in crops:
			_crops[StringName(str(key))] = maxi(int(crops[key]), 0)
	var fish: Dictionary = data.get("fish", {})
	for key in fish:
		_fish[StringName(key)] = {"count": int(fish[key].get("count", 0)), "best_cm": float(fish[key].get("best_cm", 0.0))}


func clear() -> void:
	_fish.clear()
	_crops.clear()
