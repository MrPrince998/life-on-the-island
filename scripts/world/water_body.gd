class_name WaterBody
extends Node3D
## A body of water whose surface is at this node's global Y.
## Used for "too deep" checks, for valid fishing water, and it fills itself with
## swimming fish you can see (AmbientFish), using the species that live in it.

@export var water_id: StringName = &""
## Horizontal radius of the water around this node. 0 = unbounded (the sea).
@export var radius: float = 0.0
## Fill this water with visible swimming fish (decoration only).
@export var ambient_fish: bool = true


func _ready() -> void:
	add_to_group("water_body")
	if ambient_fish and water_id != &"":
		_add_ambient_fish()


func _add_ambient_fish() -> void:
	var fish := AmbientFish.new()
	fish.name = "AmbientFish"
	var center := Vector2(global_position.x, global_position.z)
	if radius > 0.0:
		# A lake: schools stay inside, a little in from the shore.
		fish.setup(water_id, get_surface_height(), center, radius * 0.85)
		fish.school_count = 5
		# Below the shoreline-foam band (lake foam reaches ~0.4 m), in clear water.
		fish.swim_depth = Vector2(0.55, 0.9)
		fish.min_water_depth = 1.3
	else:
		# The sea: schools follow the player along the coast.
		fish.setup(water_id, get_surface_height(), center, 0.0)
		fish.school_count = 8
		# Below the shoreline-foam band (sea foam reaches ~0.8 m).
		fish.min_water_depth = 2.0
		fish.swim_depth = Vector2(0.9, 1.3)
	add_child(fish)


func get_surface_height() -> float:
	return global_position.y


func contains_xz(point: Vector3) -> bool:
	if radius <= 0.0:
		return true
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= radius


## How far below the surface the point is (0 if above water or outside).
func get_depth_at(point: Vector3) -> float:
	if not contains_xz(point):
		return 0.0
	return maxf(get_surface_height() - point.y, 0.0)


## The deepest water at a point: lakes and the sea (WaterBody nodes) and Willow Creek
## (a carved stream, not a WaterBody: see IslandShape.get_creek_depth).
static func deepest_at(tree: SceneTree, point: Vector3) -> float:
	var depth := IslandShape.shared().get_creek_depth(point)
	for node in tree.get_nodes_in_group("water_body"):
		var water := node as WaterBody
		if water:
			depth = maxf(depth, water.get_depth_at(point))
	return depth
