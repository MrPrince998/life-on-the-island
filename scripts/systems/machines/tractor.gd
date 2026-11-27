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
## The model is built in code (until a modelled tractor exists). Saved through the
## "persistent" group: where it's parked and what's hitched.

signal engine_changed(on: bool)
signal implement_changed(implement: StringName)
signal lowered_changed(lowered: bool)
signal row_worked(field: CropField, index: int, tool: StringName)

const IMPLEMENTS: Array[StringName] = [&"plough", &"seed_drill", &"harvester"]
const HITCH_MINUTES := 5
const RED := Color(0.72, 0.19, 0.13)
const IRON := Color(0.22, 0.22, 0.24)
const RUBBER := Color(0.1, 0.1, 0.1)
const CREAM := Color(0.93, 0.86, 0.66)
const REAR_WHEEL := 0.72
const FRONT_WHEEL := 0.42

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
var _rear_wheels: Array[Node3D] = []
var _front_pivots: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _implements: Dictionary = {}  # id -> Node3D (with a "WorkPoint" child)
var _reel: Node3D
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
	var travel := _speed * delta
	for wheel in _rear_wheels:
		wheel.rotate_object_local(Vector3.UP, -travel / REAR_WHEEL)
	for wheel in _front_wheels:
		wheel.rotate_object_local(Vector3.UP, -travel / FRONT_WHEEL)
	for pivot in _front_pivots:
		pivot.rotation.y = _steer
	for id: StringName in _implements:
		var node: Node3D = _implements[id]
		var y := 0.0 if (lowered and id == implement) else 0.35
		node.position.y = lerpf(node.position.y, y, 1.0 - exp(-5.0 * delta))
	if _reel and implement == &"harvester":
		_reel.rotate_object_local(Vector3.RIGHT, (3.0 if lowered else 0.6) * delta)
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
	var red := _mat(RED, 0.55)
	var iron := _mat(IRON, 0.6, 0.5)
	var rubber := _mat(RUBBER, 0.95)
	var cream := _mat(CREAM, 0.6)
	var dark := _mat(Color(0.16, 0.13, 0.11), 0.9)
	_box(_model, Vector3(0.75, 0.35, 2.7), Vector3(0, 0.78, 0.1), iron)  # chassis
	_box(_model, Vector3(0.85, 0.72, 1.45), Vector3(0, 1.18, -0.62), red)  # hood
	_box(_model, Vector3(0.88, 0.62, 0.07), Vector3(0, 1.12, -1.36), dark)  # grille
	_box(_model, Vector3(0.95, 0.75, 0.8), Vector3(0, 1.12, 0.45), red)  # body under the seat
	for side in [-1.0, 1.0]:
		_box(_model, Vector3(0.42, 0.08, 1.15), Vector3(side * 0.82, 1.52, 0.55), red)  # fenders
		_box(_model, Vector3(0.06, 0.55, 1.0), Vector3(side * 0.6, 1.25, 0.55), red)
		var lamp := _cyl(_model, 0.08, 0.06, Vector3(side * 0.3, 1.38, -1.4), cream)
		lamp.rotation = Vector3(PI * 0.5, 0, 0)
	_cyl(_model, 0.05, 0.85, Vector3(0.28, 1.92, -0.95), iron)  # exhaust
	_box(_model, Vector3(0.52, 0.1, 0.46), Vector3(0, 1.48, 0.62), dark)  # seat
	_box(_model, Vector3(0.52, 0.42, 0.08), Vector3(0, 1.72, 0.86), dark)
	var column := _cyl(_model, 0.03, 0.7, Vector3(0, 1.6, 0.1), iron)
	column.rotation = Vector3(-0.5, 0, 0)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.21
	wheel.mesh = torus
	wheel.material_override = dark
	wheel.position = Vector3(0, 1.88, 0.25)
	wheel.rotation = Vector3(0.5, 0, 0)
	_model.add_child(wheel)
	_seat = Marker3D.new()
	_seat.name = "Seat"
	_seat.position = Vector3(0, 1.62, 0.62)
	_model.add_child(_seat)
	for side in [-1.0, 1.0]:
		var rear := Node3D.new()
		rear.position = Vector3(side * 0.84, REAR_WHEEL, 0.55)
		rear.rotation = Vector3(0, 0, PI * 0.5)
		_model.add_child(rear)
		_cyl(rear, REAR_WHEEL, 0.4, Vector3.ZERO, rubber)
		_cyl(rear, REAR_WHEEL * 0.5, 0.42, Vector3.ZERO, cream)
		for i in 6:
			var tread := _box(rear, Vector3(0.12, 0.42, 0.08), Vector3.ZERO, rubber)
			var a := TAU * i / 6.0
			tread.position = Vector3(cos(a) * REAR_WHEEL, 0, sin(a) * REAR_WHEEL)
			tread.rotation = Vector3(0, -a, 0)
		_rear_wheels.append(rear)
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.58, FRONT_WHEEL, -1.2)
		_model.add_child(pivot)
		var front := Node3D.new()
		front.rotation = Vector3(0, 0, PI * 0.5)
		pivot.add_child(front)
		_cyl(front, FRONT_WHEEL, 0.22, Vector3.ZERO, rubber)
		_cyl(front, FRONT_WHEEL * 0.5, 0.24, Vector3.ZERO, cream)
		_front_pivots.append(pivot)
		_front_wheels.append(front)
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
	_build_implements(iron, dark)
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


func _build_implements(iron: Material, dark: Material) -> void:
	var green := _mat(Color(0.25, 0.45, 0.25), 0.6)
	var yellow := _mat(Color(0.88, 0.68, 0.18), 0.55)
	var steel := _mat(Color(0.7, 0.72, 0.74), 0.4, 0.6)
	# Plough: a drawbar, a frame and three curved shares that bite into the soil.
	var plough := _implement_node(&"plough", Vector3(0, 0, 2.35))
	_box(plough, Vector3(0.1, 0.1, 0.9), Vector3(0, 0.62, -0.55), iron)
	_box(plough, Vector3(2.4, 0.12, 0.16), Vector3(0, 0.6, 0), iron)
	for x in [-0.8, 0.0, 0.8]:
		_box(plough, Vector3(0.08, 0.5, 0.08), Vector3(x, 0.32, 0.05), iron)
		var share := _box(plough, Vector3(0.3, 0.05, 0.38), Vector3(x + 0.08, 0.08, 0.15), steel)
		share.rotation = Vector3(0.35, 0.5, 0.2)
	# Seed drill: a long green seed box over a row of little discs.
	var drill := _implement_node(&"seed_drill", Vector3(0, 0, 2.35))
	_box(drill, Vector3(0.1, 0.1, 0.9), Vector3(0, 0.62, -0.55), iron)
	_box(drill, Vector3(2.5, 0.5, 0.6), Vector3(0, 0.95, 0.05), green)
	_box(drill, Vector3(2.55, 0.06, 0.66), Vector3(0, 1.22, 0.05), dark)
	for i in 7:
		var disc := _cyl(drill, 0.17, 0.03, Vector3(-1.05 + i * 0.35, 0.18, 0.2), steel)
		disc.rotation = Vector3(0, 0, PI * 0.5)
	for side in [-1.0, 1.0]:
		var w := _cyl(drill, 0.3, 0.12, Vector3(side * 1.35, 0.3, 0.05), _mat(RUBBER, 0.95))
		w.rotation = Vector3(0, 0, PI * 0.5)
	# Harvester: a wide header out front with a turning reel that gathers the crop in.
	var header := _implement_node(&"harvester", Vector3(0, 0, -2.3))
	_box(header, Vector3(2.9, 0.3, 0.8), Vector3(0, 0.4, 0), yellow)
	_box(header, Vector3(2.9, 0.6, 0.08), Vector3(0, 0.75, 0.38), yellow)
	for side in [-1.0, 1.0]:
		_box(header, Vector3(0.08, 0.9, 0.9), Vector3(side * 1.46, 0.7, 0), yellow)
		_box(header, Vector3(0.08, 0.08, 0.8), Vector3(side * 1.2, 1.0, 0.6), iron)
	_reel = Node3D.new()
	_reel.name = "Reel"
	_reel.position = Vector3(0, 0.95, -0.15)
	header.add_child(_reel)
	var axle := _cyl(_reel, 0.05, 2.8, Vector3.ZERO, iron)
	axle.rotation = Vector3(0, 0, PI * 0.5)
	for i in 5:
		var a := TAU * i / 5.0
		_box(_reel, Vector3(2.7, 0.05, 0.12), Vector3(0, sin(a) * 0.38, cos(a) * 0.38), _mat(Color(0.8, 0.2, 0.15), 0.6))
	_show_implement()


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


func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


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
