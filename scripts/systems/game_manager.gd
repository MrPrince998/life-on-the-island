extends Node
## GameManager (autoload) — small global game state shared across systems.
##
## For now it tracks which island region the player is in, relays short
## notifications to the HUD, relays the current interaction prompt, and keeps story
## flags (things that have happened, e.g. "has_fishing_rod"), which are saved.

signal notification_posted(text: String)
signal region_changed(region_id: StringName, display_name: String)
signal interaction_prompt_changed(text: String)
signal flag_changed(flag: StringName, value: bool)

const DEFAULT_REGION_NAME := "The Island"

var current_region_id: StringName = &""
var current_region_name: String = DEFAULT_REGION_NAME

var _active_regions: Array[RegionArea] = []
## Story flags that are set (flag -> true).
var _flags: Dictionary = {}


# ---- Story flags ----------------------------------------------------------------

func set_flag(flag: StringName, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)
	flag_changed.emit(flag, value)


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func reset_flags() -> void:
	_flags.clear()


func flags_to_dict() -> Dictionary:
	var names: Array = []
	for flag in _flags:
		names.append(String(flag))
	names.sort()
	return {"version": 1, "flags": names}


func flags_from_dict(data: Dictionary) -> void:
	_flags.clear()
	for name in data.get("flags", []):
		_flags[StringName(str(name))] = true


func notify(text: String) -> void:
	notification_posted.emit(text)


func set_interaction_prompt(text: String) -> void:
	interaction_prompt_changed.emit(text)


func enter_region(region: RegionArea) -> void:
	if region in _active_regions:
		return
	_active_regions.append(region)
	_refresh_region()


func exit_region(region: RegionArea) -> void:
	_active_regions.erase(region)
	_refresh_region()


func _refresh_region() -> void:
	var best: RegionArea = null
	for region in _active_regions:
		if not is_instance_valid(region):
			continue
		# Highest priority wins; among equals, the most recently entered wins.
		if best == null or region.region_priority >= best.region_priority:
			best = region
	var new_id: StringName = best.region_id if best else &""
	var new_name: String = best.display_name if best else DEFAULT_REGION_NAME
	if new_id == current_region_id:
		return
	current_region_id = new_id
	current_region_name = new_name
	region_changed.emit(current_region_id, current_region_name)
