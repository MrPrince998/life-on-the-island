class_name FelledTree
extends Interactable
## A tree you felled, lying where it came down. Made by the ForestService.
##   Stage TRUNK: the whole tree on the ground. E (with an axe): cut it into logs.
##   Stage LOGS:  a row of logs along where the trunk lay. E: pick them up.
## When the logs are all picked up the ForestService removes it.

enum Stage { TRUNK, LOGS, CLEARED }

const FALL_SECONDS := 1.7
const LOG_LENGTH := 1.1
const LOG_GAP := 0.25
const BARK := Color(0.42, 0.29, 0.19)
const END_GRAIN := Color(0.86, 0.69, 0.47)

var service: ForestService
var key: String = ""
var layer_id: StringName
## Where the trunk stood (world) and which way it fell (flat unit vector).
var base: Vector3
var fall_dir: Vector3 = Vector3.FORWARD
## The tree's transform where it stood (scale and yaw).
var placed: Transform3D
var stage: int = Stage.TRUNK
var logs: int = 3
## Width of the stump left behind (the logs are laid beyond it).
var stump_size: float = 1.0

var _trunk: Node3D
var _logs_node: Node3D
var _fallen_angle := PI * 0.5
var _working := false


func _init() -> void:
	super()
	interaction_id = &"felled_tree"


## Builds the visuals. With `animate` the tree topples over first.
func setup(animate: bool) -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	shape.shape = sphere
	add_child(shape)
	global_position = base + fall_dir * 2.4 + Vector3.UP * 0.8
	_refresh(animate)


func get_trunk_length() -> float:
	var visual := service.get_tree_visual(layer_id) if service else {}
	if visual.is_empty():
		return 6.0
	var aabb: AABB = (visual.mesh_xform as Transform3D) * (visual.mesh as Mesh).get_aabb()
	return aabb.end.y * placed.basis.get_scale().y


func can_interact_now(player: Node) -> bool:
	if _working or stage == Stage.CLEARED:
		return false
	if player is PlayerController and (player as PlayerController).is_hands_busy():
		return false
	return stage == Stage.LOGS or WoodcuttingController.has_axe()


func get_prompt() -> String:
	match stage:
		Stage.TRUNK:
			return "Cut the trunk into logs  (%d swings · %d min)" % [ForestService.BUCK_SWINGS, ForestService.BUCK_MINUTES]
		Stage.LOGS:
			return "Pick up %d log%s" % [logs, "" if logs == 1 else "s"]
	return ""


func _on_interact(interactor: Node) -> void:
	if _working or service == null:
		return
	_working = true
	if stage == Stage.TRUNK:
		await service.cut_into_logs(self, interactor)
	elif stage == Stage.LOGS:
		service.collect_logs(self)
	_working = false


## Shows the right look for the stage.
func _refresh(animate: bool = false) -> void:
	if stage == Stage.TRUNK:
		_build_trunk(animate)
	else:
		if _trunk:
			_trunk.queue_free()
			_trunk = null
	if stage == Stage.LOGS:
		_build_logs()
	elif _logs_node:
		_logs_node.queue_free()
		_logs_node = null


func set_stage(value: int) -> void:
	stage = value
	_refresh()


func is_falling() -> bool:
	return _trunk != null and _trunk.has_meta(&"falling")


# ---- Trunk --------------------------------------------------------------------

func _build_trunk(animate: bool) -> void:
	if _trunk or service == null:
		return
	var visual := service.get_tree_visual(layer_id)
	if visual.is_empty():
		return
	_trunk = Node3D.new()
	_trunk.name = "Trunk"
	_trunk.top_level = true
	add_child(_trunk)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = visual.mesh
	if visual.material:
		mesh.material_override = visual.material
	mesh.transform = visual.mesh_xform
	_trunk.add_child(mesh)
	# How far over it ends up: until the crown rests on the ground (slopes up or down).
	var length := get_trunk_length()
	var shape := IslandShape.shared()
	var tip := base + fall_dir * length * 0.75
	var rise := shape.get_height(tip.x, tip.z) - base.y
	_fallen_angle = clampf(PI * 0.5 - atan2(rise, length * 0.75), 1.1, 1.75)
	if animate:
		_trunk.set_meta(&"falling", true)
		_set_angle(0.0)
		var tween := create_tween()
		tween.tween_method(_set_angle, 0.0, _fallen_angle, FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_method(_set_angle, _fallen_angle, _fallen_angle - 0.07, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_angle, _fallen_angle - 0.07, _fallen_angle, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if _trunk:
				_trunk.remove_meta(&"falling")
			if service:
				service.tree_landed.emit(key, base + fall_dir * length * 0.5))
	else:
		_set_angle(_fallen_angle)


func _set_angle(angle: float) -> void:
	if _trunk == null:
		return
	var axis := Vector3.UP.cross(fall_dir).normalized()
	var trunk_radius := 0.25 * placed.basis.get_scale().x * 0.06
	var lift := Vector3.UP * clampf(trunk_radius, 0.0, 0.4) * (angle / maxf(_fallen_angle, 0.01))
	_trunk.global_transform = Transform3D(Basis(axis, angle) * placed.basis, base + lift)


# ---- Logs ---------------------------------------------------------------------

func _build_logs() -> void:
	if _logs_node:
		_logs_node.queue_free()
	_logs_node = Node3D.new()
	_logs_node.name = "Logs"
	_logs_node.top_level = true
	add_child(_logs_node)
	_logs_node.global_transform = Transform3D.IDENTITY
	var bark := StandardMaterial3D.new()
	bark.albedo_color = BARK
	bark.roughness = 0.95
	var grain := StandardMaterial3D.new()
	grain.albedo_color = END_GRAIN
	grain.roughness = 0.85
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var shape := IslandShape.shared()
	var side := Vector3.UP.cross(fall_dir).normalized()
	var radius := clampf(placed.basis.get_scale().x * 0.024, 0.14, 0.24)
	# Start clear of the stump.
	var start := stump_size * 0.5 + 0.35 + LOG_LENGTH * 0.5
	for i in logs:
		var along := start + i * (LOG_LENGTH + LOG_GAP)
		var p := base + fall_dir * along + side * rng.randf_range(-0.25, 0.25)
		p.y = shape.get_height(p.x, p.z) + radius * 0.9
		# Lying along the fall line, turned a little each.
		var dir := fall_dir.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25))
		var log_basis := Basis(Quaternion(Vector3.UP, dir))
		var log_node := Node3D.new()
		log_node.name = "Log%d" % i
		_logs_node.add_child(log_node)
		log_node.global_transform = Transform3D(log_basis.rotated(dir, rng.randf() * TAU), p)
		var body := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius
		cylinder.bottom_radius = radius * 1.05
		cylinder.height = LOG_LENGTH
		cylinder.radial_segments = 12
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		body.mesh = cylinder
		body.material_override = bark
		log_node.add_child(body)
		for end in [-1.0, 1.0]:
			var cap := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = radius * (0.97 if end > 0 else 1.02)
			disc.bottom_radius = disc.top_radius
			disc.height = 0.02
			disc.radial_segments = 12
			cap.mesh = disc
			cap.material_override = grain
			cap.position = Vector3(0, end * LOG_LENGTH * 0.5, 0)
			log_node.add_child(cap)
