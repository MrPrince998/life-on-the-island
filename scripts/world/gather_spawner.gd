class_name GatherSpawner
extends Node3D
## Scatters gather spots (GatherNode) over parts of the island: branch piles for wood,
## cracked rocks for stone. Placement is seeded, so the spots (and their save IDs) are
## the same every time. They avoid paths, water, Willow Creek, steep ground and
## anything in the "keep_clear" group, and keep_clear themselves so trees don't grow
## through them.
##
## Built in _enter_tree, before the vegetation scatters itself in _ready.

@export var item_id: StringName = &"wood"
@export var verb_text: String = "Gather"
@export var count: int = 20
## Areas to scatter in, as Vector3(x, z, radius) in island coordinates.
@export var areas: Array[Vector3] = []
@export var models: Array[PackedScene] = []
@export var size_range: Vector2 = Vector2(1.8, 2.4)
@export var amount_min: int = 2
@export var amount_max: int = 3
@export var regrow_days: int = 2
@export var gather_minutes: int = 10
@export var min_spacing: float = 7.0
@export var random_seed: int = 1

var _built: bool = false


func _enter_tree() -> void:
	if _built or Engine.is_editor_hint():
		return
	_built = true
	build()


func get_spots() -> Array[GatherNode]:
	var spots: Array[GatherNode] = []
	for child in get_children():
		if child is GatherNode:
			spots.append(child as GatherNode)
	return spots


func build() -> void:
	if areas.is_empty() or models.is_empty():
		return
	var shape := IslandShape.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var zones: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group(&"keep_clear"):
		var n := node as Node3D
		if n and n.is_inside_tree():
			zones.append(Vector3(n.global_position.x, n.global_position.z, float(n.get_meta(&"clear_radius", 3.0))))
	var points: Array[Vector2] = []
	var attempts := 0
	while points.size() < count and attempts < count * 120:
		attempts += 1
		var area := areas[attempts % areas.size()]
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * area.z
		var p := Vector2(area.x, area.y) + Vector2(cos(angle), sin(angle)) * dist
		if not _good_spot(shape, p, zones, points):
			continue
		points.append(p)
	for i in points.size():
		_make_spot(i, points[i], rng)


func _good_spot(shape: IslandShape, p: Vector2, zones: Array[Vector3], taken: Array[Vector2]) -> bool:
	if not shape.is_open_ground(p, 0.5):
		return false
	var h := shape.get_height(p.x, p.y)
	if h < 1.4 or shape.get_normal(p.x, p.y).y < 0.86:
		return false
	for zone in zones:
		if p.distance_to(Vector2(zone.x, zone.y)) < zone.z + 2.0:
			return false
	for q in taken:
		if p.distance_to(q) < min_spacing:
			return false
	return true


func _make_spot(index: int, p: Vector2, rng: RandomNumberGenerator) -> void:
	var spot := GatherNode.new()
	spot.name = "%s_%02d" % [String(item_id).capitalize().replace(" ", ""), index + 1]
	spot.interaction_id = StringName("%s_%02d" % [item_id, index + 1])
	spot.item_id = item_id
	spot.verb_text = verb_text
	spot.amount_min = amount_min
	spot.amount_max = amount_max
	spot.regrow_days = regrow_days
	spot.gather_minutes = gather_minutes
	spot.add_to_group(&"keep_clear")
	# Wide enough that a tree trunk (and its roots) never grows through the pile.
	spot.set_meta(&"clear_radius", 3.6)
	add_child(spot)
	var shape := IslandShape.shared()
	spot.global_position = Vector3(p.x, shape.get_height(p.x, p.y), p.y)
	spot.rotation.y = rng.randf() * TAU
	var model := FittedModel.new()
	model.name = "Model"
	model.model = models[rng.randi() % models.size()]
	model.size = rng.randf_range(size_range.x, size_range.y)
	model.collision_fraction = Vector3(0.7, 0.7, 0.7)
	model.view_distance = 140.0
	model.sink = 0.08
	spot.add_child(model)
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(model.size * 0.5 + 0.6, 1.2)
	shape_node.shape = sphere
	shape_node.position = Vector3(0, 0.7, 0)
	spot.add_child(shape_node)
