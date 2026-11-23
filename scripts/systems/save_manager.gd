extends Node
## Saving and loading, with autosave. Autoload "SaveManager".
##
## The game saves itself (no save button needed):
##   - a couple of seconds after something changes: an activity that uses time (fishing,
##     resting, sleeping), a catch, buying or selling;
##   - straight away when a new day starts;
##   - every two minutes of play as a safety net;
##   - when leaving to the main menu, quitting, or closing the window.
## Nothing is saved on the title screen, so the title's demo island never overwrites a save.
##
## The save is versioned JSON in user://. Each save is written to a temporary file first
## and then swapped in, and the previous save is kept as a backup. If the save is ever
## damaged, Continue loads the backup instead.
##
## Other systems join in by adding a node to the group "persistent" with:
##   func get_save_key() -> String
##   func save_state() -> Dictionary     (JSON-safe values)
##   func load_state(data: Dictionary) -> void
## Never changes game time itself.

signal saved(reason: String)
signal save_failed(reason: String)

const SAVE_VERSION := 1
const DEFAULT_SLOT := "user://savegame.json"
## Automated tests save here, so they never touch the player's real save.
const TEST_SLOT := "user://test_savegame.json"
const PERSISTENT_GROUP := &"persistent"
## Real seconds to wait after a change before autosaving (groups several changes).
const AUTOSAVE_DELAY := 2.0
## Real seconds of play between safety-net autosaves.
const AUTOSAVE_INTERVAL := 120.0

var autosave_enabled: bool = true
var save_path: String = DEFAULT_SLOT

var _session_running: bool = false
var _dirty_timer: float = -1.0
var _interval_timer: float = 0.0
## World part of a save waiting to be applied when the island scene is ready.
var _pending_world: Dictionary = {}
var _last_save_unix: float = 0.0


func _ready() -> void:
	ActivityClock.time_advanced.connect(func(_m: int, _a: StringName) -> void: _mark_dirty())
	ActivityClock.day_started.connect(func(_d: int) -> void: _save_soon(0.2))
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void: _mark_dirty())
	InventoryManager.money_changed.connect(func(_m: int) -> void: _mark_dirty())
	Journal.fish_recorded.connect(func(_a: StringName, _b: float, _c: bool, _d: bool) -> void: _mark_dirty())


## Tests call this first so they write to a separate file. Each running copy of the game
## gets its own file (by process id), so two test runs at once can't disturb each other.
func use_test_slot() -> void:
	save_path = TEST_SLOT.get_basename() + "_%d.json" % OS.get_process_id()


func get_backup_path() -> String:
	return save_path.get_basename() + ".backup.json"


# ---- Session (set by the main scene) -------------------------------------------

## The island is loaded and the player is playing: autosave may run.
func begin_session() -> void:
	_session_running = true
	_dirty_timer = -1.0
	_interval_timer = 0.0


func end_session() -> void:
	_session_running = false
	_dirty_timer = -1.0


func is_session_running() -> bool:
	return _session_running


func _mark_dirty() -> void:
	if _session_running and _dirty_timer < 0.0:
		_dirty_timer = AUTOSAVE_DELAY


func _save_soon(seconds: float) -> void:
	if _session_running:
		_dirty_timer = seconds if _dirty_timer < 0.0 else minf(_dirty_timer, seconds)


func _process(delta: float) -> void:
	if not _session_running or not autosave_enabled:
		return
	_interval_timer += delta
	if _dirty_timer >= 0.0:
		_dirty_timer -= delta
		if _dirty_timer < 0.0:
			_autosave()
	elif _interval_timer >= AUTOSAVE_INTERVAL:
		_autosave()


func _autosave() -> void:
	# Don't save mid-jump: try again a moment later.
	var player := _player()
	if player and not player.is_on_floor():
		_dirty_timer = 0.5
		return
	save_game("autosave")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _session_running:
		save_game("quit")


# ---- Saving --------------------------------------------------------------------

## Saves now. Returns true on success. Only works while a game is being played.
func save_game(reason: String = "manual") -> bool:
	if not _session_running:
		return false
	var data := collect_state()
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: can't write %s (%s)" % [temp, error_string(FileAccess.get_open_error())])
		save_failed.emit(reason)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		save_failed.emit(reason)
		return false
	# Keep the previous save as a backup, then swap the new one in.
	var save_name := save_path.get_file()
	var backup_name := get_backup_path().get_file()
	if dir.file_exists(save_name):
		if dir.file_exists(backup_name):
			dir.remove(backup_name)
		dir.rename(save_name, backup_name)
	var err := dir.rename(temp.get_file(), save_name)
	if err != OK:
		push_warning("SaveManager: couldn't finish saving (%s)" % error_string(err))
		save_failed.emit(reason)
		return false
	_dirty_timer = -1.0
	_interval_timer = 0.0
	_last_save_unix = Time.get_unix_time_from_system()
	saved.emit(reason)
	return true


## Everything that makes up a save, as a JSON-safe dictionary.
func collect_state() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"clock": ActivityClock.to_dict(),
		"inventory": InventoryManager.to_dict(),
		"journal": Journal.to_dict(),
		"flags": GameManager.flags_to_dict(),
		"player": {},
		"world": {},
	}
	var player := _player()
	if player:
		var p := player.global_position
		var visual := player.get_node_or_null("Visual") as Node3D
		var rig := player.get_node_or_null("CameraRig")
		data.player = {
			"position": [p.x, p.y, p.z],
			"facing": visual.rotation.y if visual else 0.0,
			"camera_yaw": float(rig.call(&"get_yaw")) if rig and rig.has_method(&"get_yaw") else 0.0,
		}
	for node in get_tree().get_nodes_in_group(PERSISTENT_GROUP):
		if node.has_method(&"get_save_key") and node.has_method(&"save_state"):
			data.world[str(node.call(&"get_save_key"))] = node.call(&"save_state")
	return data


# ---- Loading -------------------------------------------------------------------

func has_save() -> bool:
	return not read_latest().is_empty()


## The newest readable save (falls back to the backup), or {} if there is none.
func read_latest() -> Dictionary:
	var data := _read_file(save_path)
	if data.is_empty():
		data = _read_file(get_backup_path())
	return data


## Short description of the save for the title screen, e.g. "Day 3 · 2:40 PM".
func get_save_summary() -> String:
	var data := read_latest()
	if data.is_empty():
		return ""
	var minutes := int((data.get("clock", {}) as Dictionary).get("total_minutes", 0))
	var day := minutes / (24 * 60) + 1
	var minute_of_day := minutes % (24 * 60)
	var hour := minute_of_day / 60
	var suffix := "AM" if hour < 12 else "PM"
	var hour12 := hour % 12
	if hour12 == 0:
		hour12 = 12
	return "Day %d  ·  %d:%02d %s" % [day, hour12, minute_of_day % 60, suffix]


## Loads the global parts of a save (time, bag, coins, journal, story flags) right away, and keeps
## the world parts (player position, persistent objects) for apply_pending_world().
## Call after resetting to a new game, before switching to the island scene.
func load_into_game(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	ActivityClock.from_dict(data.get("clock", {}))
	InventoryManager.from_dict(data.get("inventory", {}))
	Journal.from_dict(data.get("journal", {}))
	GameManager.flags_from_dict(data.get("flags", {}))
	_pending_world = {"player": data.get("player", {}), "world": data.get("world", {})}
	return true


func has_pending_world() -> bool:
	return not _pending_world.is_empty()


## Called by the main scene once the island is ready: puts the player back where they
## were and hands each persistent object its saved state.
func apply_pending_world(player: Node3D) -> void:
	if _pending_world.is_empty():
		return
	var p: Dictionary = _pending_world.get("player", {})
	var pos: Array = p.get("position", [])
	if player and pos.size() == 3:
		var target := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		var shape := IslandShape.shared()
		var ground := shape.get_height(target.x, target.z)
		# Never put the player under the ground (e.g. if the terrain changed since).
		target.y = maxf(target.y, ground + 0.2)
		if player.has_method(&"teleport_to"):
			player.call(&"teleport_to", target, float(p.get("facing", 0.0)))
		var rig := player.get_node_or_null("CameraRig")
		if rig and rig.has_method(&"set_yaw"):
			rig.call(&"set_yaw", float(p.get("camera_yaw", p.get("facing", 0.0))))
	var world: Dictionary = _pending_world.get("world", {})
	for node in get_tree().get_nodes_in_group(PERSISTENT_GROUP):
		if node.has_method(&"get_save_key") and node.has_method(&"load_state"):
			var key := str(node.call(&"get_save_key"))
			if world.has(key) and world[key] is Dictionary:
				node.call(&"load_state", world[key])
	_pending_world = {}


func clear_pending_world() -> void:
	_pending_world = {}


## Removes the save and its backup (used by tests).
func delete_save() -> void:
	for path in [save_path, get_backup_path(), save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("SaveManager: %s is damaged; ignoring it." % path)
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		push_warning("SaveManager: %s is damaged; ignoring it." % path)
		return {}
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION or not data.has("clock"):
		push_warning("SaveManager: %s has an unknown format (version %s)." % [path, str(data.get("version"))])
		return {}
	return data


func _player() -> PlayerController:
	return get_tree().get_first_node_in_group(&"player") as PlayerController
