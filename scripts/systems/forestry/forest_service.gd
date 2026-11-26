class_name ForestService
extends Node
## Woodcutting on the island's trees (the VegetationScatter's choppable layers).
##
##   1. With an axe in the bag, stand by a tree: "Fell the tree". A few swings (fewer with
##      the steel axe) and it topples over, away from you. A stump is left behind.
##   2. The trunk lies where it fell. E: cut it into logs (another couple of swings).
##   3. The logs lie in a row. E: pick them up (Log items for Bram the blacksmith).
##   4. Once the trunk is cut up, a sapling sprouts from the stump and grows back into a
##      full tree over about a week (GROWTH), so the woods never run out.
##
## Felling and cutting are activities and advance the clock (D-001); walking up to a tree,
## and picking up logs, do not. Felled trees are saved by layer id + position (not node
## paths or instance numbers), so the save survives small changes to the scatter.

signal tree_felled(key: String, at: Vector3)
## The falling trunk hit the ground (for the thump).
signal tree_landed(key: String, at: Vector3)
signal chop_hit(at: Vector3)
signal logs_cut(key: String, count: int)
signal logs_collected(key: String, count: int)
signal tree_regrown(key: String)

const SAVE_VERSION := 1
const FELL_MINUTES := 30
const STEEL_FELL_MINUTES := 20
const BUCK_SWINGS := 2
const BUCK_MINUTES := 15
## Days after the trunk is cut up -> how big the new tree is (0 = just the stump).
const GROWTH := [[7, 1.0], [5, 0.6], [3, 0.3], [0, 0.0]]
## How close (metres, trunk to player) a tree must be to fell it.
const REACH := 2.3
const STUMP_MODEL := preload("res://source_assets/tripo/tree_strump.glb")

@export var scatter_path: NodePath = ^"../Vegetation"

var _scatter: VegetationScatter
var _spot: TreeChopSpot
## key -> {layer, x, z, day, grow_from, yaw, stage, logs}
var _felled: Dictionary = {}
## "layer#index" -> key (felled trees, so they can't be felled again while regrowing).
var _by_index: Dictionary = {}
var _index_of: Dictionary = {}
var _nodes: Dictionary = {}
var _stumps: Dictionary = {}
var _busy := false


func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"forest_service")
	_scatter = get_node_or_null(scatter_path) as VegetationScatter
	_spot = TreeChopSpot.new()
	_spot.name = "ChopSpot"
	_spot.service = self
	_spot.enabled = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	_spot.add_child(shape)
	add_child(_spot)
	ActivityClock.day_started.connect(func(_day: int) -> void: _regrow_all())


static func find(tree: SceneTree) -> ForestService:
	return tree.get_first_node_in_group(&"forest_service") as ForestService


func fell_minutes() -> int:
	return STEEL_FELL_MINUTES if WoodcuttingController.best_axe() == WoodcuttingController.STEEL_AXE else FELL_MINUTES


func get_layer(layer_id: StringName) -> FoliageLayer:
	return _scatter.get_choppable_layer(layer_id) if _scatter else null


func get_tree_visual(layer_id: StringName) -> Dictionary:
	return _scatter.get_tree_visual(layer_id) if _scatter else {}


func get_chop_spot() -> TreeChopSpot:
	return _spot


## Felled trees right now (keys), for tests.
func get_felled_keys() -> Array:
	return _felled.keys()


func get_felled(key: String) -> Dictionary:
	return _felled.get(key, {})


func get_felled_node(key: String) -> FelledTree:
	return _nodes.get(key) as FelledTree


func has_stump(key: String) -> bool:
	return _stumps.has(key)


func is_felled(layer_id: StringName, index: int) -> bool:
	return _by_index.has("%s#%d" % [layer_id, index])


## The standing tree nearest `point` within `radius` ({} when none).
func find_standing_tree(point: Vector3, radius: float = REACH) -> Dictionary:
	if _scatter == null:
		return {}
	return _scatter.find_tree_near(point, radius, is_felled)


## How big a felled tree has grown back (0 = stump only, 1 = full).
func get_growth(key: String) -> float:
	var entry: Dictionary = _felled.get(key, {})
	if entry.is_empty():
		return 1.0
	if int(entry.stage) == FelledTree.Stage.TRUNK:
		return 0.0
	var age := ActivityClock.get_day() - int(entry.grow_from)
	for step: Array in GROWTH:
		if age >= int(step[0]):
			return float(step[1])
	return 0.0


# ---- Following the player -----------------------------------------------------

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	var tree := {}
	if player and not _busy and not player.is_input_locked() and WoodcuttingController.has_axe():
		tree = find_standing_tree(player.global_position)
	_spot.tree = tree
	_spot.enabled = not tree.is_empty()
	if not tree.is_empty():
		_spot.global_position = (tree.transform as Transform3D).origin + Vector3.UP * 1.0


# ---- Felling ------------------------------------------------------------------

## Fells `tree` ({layer_id, index, transform}) with the player's axe. Await it.
func fell(tree: Dictionary, player: Node) -> bool:
	if _busy or tree.is_empty() or not WoodcuttingController.has_axe():
		return false
	var layer := get_layer(tree.layer_id)
	if layer == null or is_felled(tree.layer_id, tree.index):
		return false
	_busy = true
	var placed: Transform3D = tree.transform
	var base := placed.origin
	var dir := Vector3.FORWARD
	var pc := player as PlayerController
	if pc:
		var away := base - pc.global_position
		away.y = 0.0
		if away.length() > 0.05:
			dir = away.normalized()
	var swings := WoodcuttingController.swings_for(layer.chop_hits)
	var cutter := _cutter_for(pc)
	if cutter:
		await cutter.swing(swings, base, func(_i: int) -> void: _shake(tree, dir))
	var key := tree_key(tree.layer_id, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + ActivityClock.get_day()
	_felled[key] = {
		"layer": String(tree.layer_id), "x": snappedf(base.x, 0.01), "z": snappedf(base.z, 0.01),
		"day": ActivityClock.get_day(), "grow_from": ActivityClock.get_day(),
		"yaw": atan2(dir.x, dir.z), "stage": FelledTree.Stage.TRUNK,
		"logs": rng.randi_range(layer.log_yield.x, layer.log_yield.y),
	}
	_link(key, tree.layer_id, tree.index)
	_scatter.set_tree_growth(tree.layer_id, tree.index, 0.0)
	_spawn(key, true)
	_apply_growth(key)
	ActivityClock.advance_minutes(fell_minutes(), &"woodcutting")
	QuestLog.record_event(&"fell_tree")
	tree_felled.emit(key, base)
	if not GameManager.has_flag(&"felled_first_tree"):
		GameManager.set_flag(&"felled_first_tree")
		GameManager.notify("Timber! Now cut the trunk into logs (E), then pick them up.")
	_busy = false
	return true


## Cuts a fallen trunk into logs (two swings). Await it.
func cut_into_logs(felled: FelledTree, player: Node) -> bool:
	if _busy or felled.stage != FelledTree.Stage.TRUNK or not WoodcuttingController.has_axe():
		return false
	_busy = true
	var cutter := _cutter_for(player as PlayerController)
	if cutter:
		var at := felled.base + felled.fall_dir * minf(felled.get_trunk_length() * 0.3, 2.5)
		await cutter.swing(BUCK_SWINGS, at, func(_i: int) -> void: chop_hit.emit(at))
	var entry: Dictionary = _felled[felled.key]
	entry.stage = FelledTree.Stage.LOGS
	entry.grow_from = ActivityClock.get_day()
	felled.set_stage(FelledTree.Stage.LOGS)
	ActivityClock.advance_minutes(BUCK_MINUTES, &"woodcutting")
	logs_cut.emit(felled.key, int(entry.logs))
	_busy = false
	return true


## Puts the logs in the bag (as many as fit). No time passes.
func collect_logs(felled: FelledTree) -> int:
	var entry: Dictionary = _felled.get(felled.key, {})
	if entry.is_empty() or int(entry.stage) != FelledTree.Stage.LOGS:
		return 0
	var added := InventoryManager.add_item(&"log", int(entry.logs))
	if added <= 0:
		GameManager.notify("Your bag is full. Make some room first (Grandpa's chest is in the cottage).")
		return 0
	entry.logs = int(entry.logs) - added
	GameManager.notify("+%d %s" % [added, ItemDB.get_display_name(&"log")])
	QuestLog.record_event(&"gather_log", added)
	logs_collected.emit(felled.key, added)
	if int(entry.logs) <= 0:
		entry.stage = FelledTree.Stage.CLEARED
		_nodes.erase(felled.key)
		felled.queue_free()
		_apply_growth(felled.key)
	else:
		felled.logs = int(entry.logs)
		felled.set_stage(FelledTree.Stage.LOGS)
	return added


static func tree_key(layer_id: StringName, at: Vector3) -> String:
	return "%s@%.1f,%.1f" % [layer_id, at.x, at.z]


func _cutter_for(player: PlayerController) -> WoodcuttingController:
	if player == null:
		return null
	var cutter := WoodcuttingController.find(player)
	if cutter == null:
		cutter = WoodcuttingController.new()
		cutter.name = "Woodcutting"
		player.add_child(cutter)
	return cutter


## The tree shivers when the axe bites.
func _shake(tree: Dictionary, dir: Vector3) -> void:
	chop_hit.emit((tree.transform as Transform3D).origin)
	_scatter.set_tree_growth(tree.layer_id, tree.index, 1.0, 0.035, dir)
	await get_tree().create_timer(0.12).timeout
	if not is_felled(tree.layer_id, tree.index):
		_scatter.set_tree_growth(tree.layer_id, tree.index, 1.0)


# ---- Regrowing ----------------------------------------------------------------

func _regrow_all() -> void:
	for key: String in _felled.keys():
		_apply_growth(key)


## Shows the stump or the young tree for how long it's been growing back. A full-grown
## tree whose logs were all picked up is forgotten (it's just a tree again).
func _apply_growth(key: String) -> void:
	var entry: Dictionary = _felled.get(key, {})
	if entry.is_empty() or not _index_of.has(key):
		return
	var growth := get_growth(key)
	var layer_id := StringName(str(entry.layer))
	var index: int = _index_of[key]
	_scatter.set_tree_growth(layer_id, index, growth)
	if growth <= 0.0:
		_ensure_stump(key)
	elif _stumps.has(key):
		(_stumps[key] as Node).queue_free()
		_stumps.erase(key)
	if growth >= 1.0 and int(entry.stage) == FelledTree.Stage.CLEARED:
		_felled.erase(key)
		_by_index.erase("%s#%d" % [layer_id, index])
		_index_of.erase(key)
		tree_regrown.emit(key)


func _ensure_stump(key: String) -> void:
	if _stumps.has(key):
		return
	var entry: Dictionary = _felled[key]
	var layer := get_layer(StringName(str(entry.layer)))
	var placed: Transform3D = _scatter.get_placements(StringName(str(entry.layer)))[_index_of[key]]
	var stump := FittedModel.new()
	stump.name = "Stump"
	stump.model = STUMP_MODEL
	stump.fit = FittedModel.Fit.LONGEST_SIDE
	stump.snap_to_ground = false
	stump.collision = FittedModel.Collision.NONE
	stump.size = stump_size(layer, placed)
	add_child(stump)
	stump.global_position = placed.origin + Vector3.DOWN * 0.05
	stump.rotation.y = float(entry.yaw)
	_stumps[key] = stump


## How wide the stump of a tree is (metres).
static func stump_size(layer: FoliageLayer, placed: Transform3D) -> float:
	var trunk := (layer.collision_radius if layer else 0.06) * placed.basis.get_scale().x
	return clampf(trunk * 3.2, 0.7, 2.2)


# ---- Building the felled trees ------------------------------------------------

func _link(key: String, layer_id: StringName, index: int) -> void:
	_index_of[key] = index
	_by_index["%s#%d" % [layer_id, index]] = key


func _spawn(key: String, animate: bool) -> void:
	var entry: Dictionary = _felled[key]
	if int(entry.stage) == FelledTree.Stage.CLEARED:
		return
	var layer_id := StringName(str(entry.layer))
	var felled := FelledTree.new()
	felled.name = "Felled_%d" % _nodes.size()
	felled.service = self
	felled.key = key
	felled.layer_id = layer_id
	felled.placed = _scatter.get_placements(layer_id)[_index_of[key]]
	felled.base = felled.placed.origin
	felled.fall_dir = Vector3(sin(float(entry.yaw)), 0.0, cos(float(entry.yaw)))
	felled.stage = int(entry.stage)
	felled.logs = int(entry.logs)
	felled.stump_size = stump_size(get_layer(layer_id), felled.placed)
	add_child(felled)
	felled.setup(animate)
	_nodes[key] = felled


func _clear_all() -> void:
	for node: Node in _nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	for node: Node in _stumps.values():
		if is_instance_valid(node):
			node.queue_free()
	for key: String in _felled.keys():
		if _index_of.has(key):
			_scatter.set_tree_growth(StringName(str(_felled[key].layer)), _index_of[key], 1.0)
	_nodes.clear()
	_stumps.clear()
	_felled.clear()
	_by_index.clear()
	_index_of.clear()


# ---- SaveManager hook ---------------------------------------------------------

func get_save_key() -> String:
	return "forestry"


func save_state() -> Dictionary:
	var trees: Array = []
	for key: String in _felled:
		trees.append((_felled[key] as Dictionary).duplicate())
	return {"version": SAVE_VERSION, "trees": trees}


func load_state(data: Dictionary) -> void:
	if _scatter == null:
		return
	_clear_all()
	for raw: Variant in data.get("trees", []):
		if not raw is Dictionary:
			continue
		var entry := (raw as Dictionary).duplicate()
		var layer_id := StringName(str(entry.get("layer", "")))
		var at := Vector2(float(entry.get("x", 0.0)), float(entry.get("z", 0.0)))
		var index := _scatter.find_tree_at(layer_id, at)
		if index < 0:
			continue  # the island changed since: that tree isn't there any more
		var placed: Transform3D = _scatter.get_placements(layer_id)[index]
		var key := tree_key(layer_id, placed.origin)
		for field in ["day", "grow_from", "stage", "logs"]:
			entry[field] = int(entry.get(field, 0))
		entry["yaw"] = float(entry.get("yaw", 0.0))
		_felled[key] = entry
		_link(key, layer_id, index)
		_spawn(key, false)
		_apply_growth(key)
