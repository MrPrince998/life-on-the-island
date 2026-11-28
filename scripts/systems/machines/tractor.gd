class_name Tractor
extends CharacterBody3D
## Grandpa's old tractor, once it's restored (BuildingData "tractor", flag
## restored_tractor). Press E beside it to climb on.
##
## Driving:  W / S  forward / reverse    A / D  steer    E  climb down (when slow)
##           Space  lower / raise the implement    Q  change implement (when stopped)
## Implements (bought from Bram): plough, seed drill and harvester. Lowered and driven along
## a field row (CropField), they work it a stretch at a time: the plough tills it, the seed
## drill sows it, the harvester cuts and threshes the ripe crop straight into grain. Each
## finished row costs a little in-game time (CropField.MACHINE_MINUTES); driving itself,
## like walking, never does. Hitching a different implement takes HITCH_MINUTES.
##
## Imported tractor and implements retain the gameplay pivots. Saved through the
## "persistent" group: where it's parked and what's hitched.

signal engine_changed(on: bool)
signal implement_changed(implement: StringName)
signal lowered_changed(lowered: bool)
signal row_worked(field: CropField, index: int, tool: StringName)

const IMPLEMENTS: Array[StringName] = [&"plough", &"seed_drill", &"harvester"]
const HITCH_MINUTES := 5

@export var tractor_id: StringName = &"grandpa_tractor"
@export var restored_flag: StringName = &"restored_tractor"
@export var max_speed: float = 5.5
## Top speed with an implement lowered (working pace).
@export var work_speed: float = 3.0
@export var reverse_speed: float = 2.2
@export var acceleration: float = 2.2
@export var braking: float = 5.0
@export var coasting: float = 2.6
@export var max_steer: float = 0.55
@export var steer_rate: float = 2.4
@export var wheelbase: float = 2.0

var implement: StringName = &""
var lowered: bool = false

var _driver: PlayerController
var _speed := 0.0
var _steer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
## Tests drive with this instead of the keys (null = use the keys).
var _test_input: Variant = null
var _status := ""
var _prompt_timer := 0.0
var _model: Node3D
var _seat: Marker3D
var _implements: Dictionary = {}  # id -> Node3D (with a "WorkPoint" child)
var _smoke: CPUParticles3D
var _seat_spot: TractorSeat


func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"tractor")
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(42.0)
	floor_snap_length = 0.4
	_build()
	_show_implement()


# ---- Queries ------------------------------------------------------------------

func is_restored() -> bool:
	return restored_flag == &"" or GameManager.has_flag(restored_flag)


func has_driver() -> bool:
	return _driver != null


func get_driver() -> PlayerController:
	return _driver


func get_seat() -> Node3D:
	return _seat


## Forward speed in m/s (negative when reversing).
func get_speed() -> float:
	return _speed


## 0..1: how hard the engine is working (for engine sounds).
func get_throttle() -> float:
	return clampf(absf(_speed) / max_speed, 0.0, 1.0)


func is_engine_on() -> bool:
	return _driver != null


## The implements you own (items from Bram's forge).
func owned_implements() -> Array[StringName]:
	var owned: Array[StringName] = []
	for id in IMPLEMENTS:
		if InventoryManager.has_item(id):
			owned.append(id)
	return owned


## Where the hitched implement does its work (world), or null without one.
func get_work_point() -> Variant:
	var node: Node3D = _implements.get(implement)
	if node == null:
		return null
	return (node.get_node("WorkPoint") as Node3D).global_position


func get_status() -> String:
	return _status


func get_drive_prompt() -> String:
	var parts: Array[String] = ["Get off"]
	if implement != &"":
		parts.append("Space: %s the %s" % ["raise" if lowered else "lower", _implement_name(implement)])
	if owned_implements().size() > 0:
		parts.append("Q: change implement")
	var text := "  ·  ".join(parts)
	if _status != "":
		text = "%s   |   %s" % [_status, text]
	return text


# ---- Getting on and off -------------------------------------------------------

func mount(player: PlayerController) -> bool:
	if player == null or _driver or not is_restored():
		return false
	if not player.start_driving(self):
		return false
	_driver = player
	_smoke.emitting = true
	engine_changed.emit(true)
	if not GameManager.has_flag(&"drove_tractor"):
		GameManager.set_flag(&"drove_tractor")
		GameManager.notify("W/S to drive, A/D to steer. Buy implements from Bram, then Q hitches one and Space lowers it over a field row.")
	_prompt_timer = 0.0
	return true


## Climbs down (only when nearly stopped).
func request_exit() -> bool:
	if _driver == null:
		return false
	if absf(_speed) > 1.0:
		GameManager.notify("Slow down before you climb off.")
		return false
	var side := -global_basis.x * 1.9
	var point := global_position + side
	point.y = IslandShape.shared().get_height(point.x, point.z) + 0.15
	var player := _driver
	_driver = null
	_speed = 0.0
	_status = ""
	_smoke.emitting = false
	player.stop_driving(point)
	GameManager.set_interaction_prompt("")
	engine_changed.emit(false)
	return true


# ---- Implements ---------------------------------------------------------------

## Hitches the next implement you own (or none). Only when stopped; takes HITCH_MINUTES.
func cycle_implement() -> StringName:
	if absf(_speed) > 0.3:
		GameManager.notify("Stop the tractor to change implements.")
		return implement
	var options: Array[StringName] = [&""]
	options.append_array(owned_implements())
	if options.size() == 1:
		GameManager.notify("You don't have any implements yet. Bram makes ploughs, seed drills and harvesters.")
		return implement
	var at := options.find(implement)
	return hitch(options[(at + 1) % options.size()])


## Hitches `id` (&"" = unhitch). Returns what's hitched now.
func hitch(id: StringName) -> StringName:
	if id != &"" and not InventoryManager.has_item(id):
		return implement
	if id == implement:
		return implement
	implement = id
	lowered = false
	if id != &"":
		ActivityClock.advance_minutes(HITCH_MINUTES, &"hitching")
		GameManager.notify("Hitched the %s. Space lowers it." % _implement_name(id))
	_show_implement()
	implement_changed.emit(implement)
	return implement


func set_lowered(value: bool) -> void:
	if implement == &"":
		value = false
	if value == lowered:
		return
	lowered = value
	lowered_changed.emit(lowered)


static func _implement_name(id: StringName) -> String:
	return ItemDB.get_display_name(id).to_lower() if id != &"" else "implement"


# ---- Driving ------------------------------------------------------------------

## For tests: drive with (steer, throttle) like the keys' get_vector (x = right, y = back).
func set_drive_input(input: Variant) -> void:
	_test_input = input


func _unhandled_input(event: InputEvent) -> void:
	if _driver == null:
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		request_exit()
	elif event.is_action_pressed(&"jump"):
		get_viewport().set_input_as_handled()
		set_lowered(not lowered)
	elif event.is_action_pressed(&"cycle_seed"):
		get_viewport().set_input_as_handled()
		cycle_implement()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if _driver:
		input = _test_input if _test_input != null else Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var throttle := -input.y
	var top := work_speed if lowered else max_speed
	var target := 0.0
	if throttle > 0.1:
		target = top * throttle
	elif throttle < -0.1:
		target = -reverse_speed * -throttle
	var rate := acceleration
	if absf(target) < 0.01:
		rate = coasting
	elif signf(target) != signf(_speed) and absf(_speed) > 0.1:
		rate = braking
	_speed = move_toward(_speed, target, rate * delta)
	_steer = move_toward(_steer, -input.x * max_steer, steer_rate * delta)
	if absf(_speed) > 0.01:
		rotate_y(_speed / wheelbase * tan(_steer) * delta)
	var forward := -global_basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	# Ran into something: it stops you.
	var real := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if absf(_speed) > 1.0 and real < absf(_speed) * 0.3:
		_speed *= 0.5
	_animate(delta)
	_work()
	if _driver:
		_prompt_timer -= delta
		if _prompt_timer <= 0.0:
			_prompt_timer = 0.2
			GameManager.set_interaction_prompt(get_drive_prompt())


## Works the field row under the lowered implement.
func _work() -> void:
	_status = ""
	if _driver == null or implement == &"" or not lowered:
		return
	var point: Variant = get_work_point()
	if point == null:
		return
	for node in get_tree().get_nodes_in_group(&"crop_fields"):
		var field := node as CropField
		if field == null:
			continue
		var result := field.machine_check(implement, point) if _speed < 0.3 else field.machine_work(implement, point)
		if result.is_empty():
			continue
		if not result.ok:
			_status = result.reason
		elif result.get("finished", false):
			_status = "%s row %d: done!" % [result.verb, int(result.index) + 1]
			row_worked.emit(field, int(result.index), implement)
		else:
			_status = "%s row %d: %d%%" % [result.verb, int(result.index) + 1, int(round(float(result.get("progress", field.get_machine_progress(int(result.index)))) * 100.0))]
		return


func _animate(delta: float) -> void:
	# Lean with the ground.
	var up := get_floor_normal() if is_on_floor() else Vector3.UP
	var local_up := global_basis.inverse() * up
	var tilt := Basis(Quaternion(Vector3.UP, local_up.normalized()))
	_model.basis = _model.basis.slerp(tilt, 1.0 - exp(-6.0 * delta)).orthonormalized()
	for id: StringName in _implements:
		var node: Node3D = _implements[id]
		var y := 0.0 if (lowered and id == implement) else 0.35
		node.position.y = lerpf(node.position.y, y, 1.0 - exp(-5.0 * delta))
	if _smoke:
		_smoke.amount = 10
		_smoke.initial_velocity_max = 0.8 + get_throttle() * 1.5


# ---- Building the model -------------------------------------------------------

func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# From the bottom of the wheels (the tractor's origin, on the ground) up to the seat.
	box.size = Vector3(1.9, 1.56, 3.3)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_add_model(_model, preload("res://source_assets/tripo/tractor.glb"), 3.3, PI)
	_seat = Marker3D.new()
	_seat.name = "Seat"
	_seat.position = Vector3(0, 1.62, 0.62)
	_model.add_child(_seat)
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.position = Vector3(0.28, 2.38, -0.95)
	_smoke.emitting = false
	_smoke.amount = 10
	_smoke.lifetime = 1.4
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.0
	_smoke.gravity = Vector3(0, 0.3, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	puff.radial_segments = 6
	puff.rings = 3
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.45, 0.45, 0.47, 0.5)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_mat
	_smoke.mesh = puff
	_model.add_child(_smoke)
	_build_implements()
	# The "drive" spot.
	_seat_spot = TractorSeat.new()
	_seat_spot.name = "SeatSpot"
	_seat_spot.tractor = self
	_seat_spot.interaction_id = StringName("drive_" + String(tractor_id))
	var reach := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	reach.shape = sphere
	_seat_spot.add_child(reach)
	_seat_spot.position = Vector3(0, 1.0, 0.3)
	add_child(_seat_spot)


func _build_implements() -> void:
	var plough := _implement_node(&"plough", Vector3(0, 0, 2.35))
	_add_model(plough, preload("res://source_assets/tripo/tractor_plough.glb"), 2.4)
	var drill := _implement_node(&"seed_drill", Vector3(0, 0, 2.35))
	_add_model(drill, preload("res://source_assets/tripo/seed_drill.glb"), 2.7)
	var header := _implement_node(&"harvester", Vector3(0, 0, -2.3))
	_add_model(header, preload("res://source_assets/tripo/harvester_header.glb"), 3.0, PI)
	_show_implement()


func _add_model(parent: Node3D, scene: PackedScene, size: float, yaw: float = 0.0) -> void:
	var visual := FittedModel.new()
	visual.name = "ImportedModel"
	visual.model = scene
	visual.size = size
	visual.rotation.y = yaw
	visual.snap_to_ground = false
	visual.collision = FittedModel.Collision.NONE
	parent.add_child(visual)


func _implement_node(id: StringName, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = String(id).to_pascal_case()
	node.position = at + Vector3(0, 0.35, 0)
	_model.add_child(node)
	var work := Marker3D.new()
	work.name = "WorkPoint"
	node.add_child(work)
	_implements[id] = node
	return node


func _show_implement() -> void:
	for id: StringName in _implements:
		(_implements[id] as Node3D).visible = id == implement


# ---- SaveManager hook ---------------------------------------------------------

func get_save_key() -> String:
	return "tractor_%s" % tractor_id


func save_state() -> Dictionary:
	var p := global_position
	return {"position": [p.x, p.y, p.z], "yaw": global_rotation.y, "implement": String(implement)}


func load_state(data: Dictionary) -> void:
	var pos: Array = data.get("position", [])
	if pos.size() == 3:
		var target := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		target.y = maxf(target.y, IslandShape.shared().get_height(target.x, target.z) + 0.05)
		global_position = target
	global_rotation = Vector3(0, float(data.get("yaw", global_rotation.y)), 0)
	var saved := StringName(str(data.get("implement", "")))
	implement = saved if saved == &"" or InventoryManager.has_item(saved) else &""
	lowered = false
	_show_implement()
