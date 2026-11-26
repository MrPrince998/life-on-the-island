@tool
class_name VegetationScatter
extends Node3D
## Scatters the island's plants (Tripo models) using FoliageLayer rules.
##
## - Placement is deterministic: the same seed gives the same island every launch.
## - Plants are drawn with MultiMesh, split into chunks so off-screen and distant
##   chunks are culled, and Godot's automatic mesh LODs keep distant trees cheap.
## - Trees and bushes get simple trunk collision.

const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const ISLAND_HALF_EXTENT := Vector2(310.0, 245.0)
const BIG_CHUNK := 64.0
const SMALL_CHUNK := 32.0
## The fishing dock runs north from the shore into Moonlit Lake (world x, z).
const DOCK_SHORE := Vector2(10.0, 60.0)
const DOCK_END := Vector2(10.0, 36.0)

@export var random_seed: int = 7
@export var layers: Array[FoliageLayer] = []
## Model used for the lone tree on the island in Moonlit Lake.
@export var landmark_tree: FoliageLayer
@export var regenerate: bool = false:
	set(value):
		if value and is_inside_tree():
			generate()

var _generated: Array[Node] = []
var _blocking: Dictionary = {}  # Vector2i cell -> Array of Vector3(x, z, radius)
var _shape: IslandShape
var _instance_counts: Dictionary = {}
## Placed transforms per layer id (kept so tests and gameplay can query positions; the
## headless/dummy renderer does not store MultiMesh transforms).
var _placements: Dictionary = {}
## Circles (x, z, radius) around buildings and props, from nodes in group "keep_clear".
var _clear_zones: Array[Vector3] = []
## Trees you can fell (FoliageLayer.choppable), per layer id:
##   {layer, mesh, mesh_xform, material, slots: Array[[MultiMesh, slot]], shapes: Array[CollisionShape3D]}
var _choppable: Dictionary = {}
## Choppable trees by 8 m grid cell: Vector2i -> Array of [layer_id, index].
var _tree_grid: Dictionary = {}


func _ready() -> void:
	generate()


## Where each plant of a layer was placed (world transforms of the plant base).
func get_placements(layer_id: StringName) -> Array:
	return _placements.get(layer_id, [])


## Number of placed instances per layer id (used by tests).
func get_instance_count(layer_id: StringName) -> int:
	return _instance_counts.get(layer_id, 0)


# ---- Woodcutting (ForestService) ---------------------------------------------------

## The layer ids of trees you can fell.
func get_choppable_layers() -> Array:
	return _choppable.keys()


## The FoliageLayer of a choppable layer id (null if it isn't one).
func get_choppable_layer(layer_id: StringName) -> FoliageLayer:
	var entry: Dictionary = _choppable.get(layer_id, {})
	return entry.get("layer")


## {mesh, mesh_xform, material} to draw one tree of the layer on its own (a falling tree).
func get_tree_visual(layer_id: StringName) -> Dictionary:
	var entry: Dictionary = _choppable.get(layer_id, {})
	if entry.is_empty():
		return {}
	return {"mesh": entry.mesh, "mesh_xform": entry.mesh_xform, "material": entry.material}


## The choppable tree whose trunk is nearest to `point` (world x/z) within `radius`,
## as {layer_id, index, transform} ({} when none). `skip(layer_id, index) -> bool` can rule
## trees out (felled ones).
func find_tree_near(point: Vector3, radius: float, skip: Callable = Callable()) -> Dictionary:
	var p := Vector2(point.x, point.z)
	var best := {}
	var best_d := radius
	var cell := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	var reach := int(ceil(radius / 8.0))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for entry: Array in _tree_grid.get(cell + Vector2i(dx, dz), []):
				var t: Transform3D = _placements[entry[0]][entry[1]]
				var d := Vector2(t.origin.x, t.origin.z).distance_to(p)
				if d < best_d and (not skip.is_valid() or not skip.call(entry[0], entry[1])):
					best_d = d
					best = {"layer_id": entry[0], "index": entry[1], "transform": t}
	return best


## The index of the tree of `layer_id` standing at world x/z `at` (within 0.5 m), or -1.
func find_tree_at(layer_id: StringName, at: Vector2) -> int:
	var cell := Vector2i(floori(at.x / 8.0), floori(at.y / 8.0))
	for entry: Array in _tree_grid.get(cell, []):
		if entry[0] == layer_id:
			var t: Transform3D = _placements[layer_id][entry[1]]
			if Vector2(t.origin.x, t.origin.z).distance_to(at) < 0.5:
				return entry[1]
	return -1


## Shows a tree at a fraction of its size: 0 = gone (felled), 1 = full grown. It only
## blocks the way when full grown. `lean` tips it slightly (radians, toward `lean_dir`)
## for the shake when the axe bites.
func set_tree_growth(layer_id: StringName, index: int, growth: float, lean: float = 0.0, lean_dir: Vector3 = Vector3.FORWARD) -> void:
	var entry: Dictionary = _choppable.get(layer_id, {})
	if entry.is_empty() or index < 0 or index >= entry.slots.size():
		return
	var placed: Transform3D = _placements[layer_id][index]
	var xform: Transform3D
	if growth <= 0.001:
		xform = Transform3D(Basis().scaled(Vector3.ONE * 0.0001), placed.origin + Vector3.DOWN * 50.0)
	else:
		var basis := placed.basis * growth
		if absf(lean) > 0.0001:
			var axis := Vector3.UP.cross(lean_dir.normalized())
			if axis.length() > 0.01:
				basis = Basis(axis.normalized(), lean) * basis
		xform = Transform3D(basis, placed.origin)
	var slot: Array = entry.slots[index]
	if slot[0]:
		(slot[0] as MultiMesh).set_instance_transform(slot[1], xform * (entry.mesh_xform as Transform3D))
	if index < entry.shapes.size() and entry.shapes[index]:
		(entry.shapes[index] as CollisionShape3D).disabled = growth < 0.999


func generate() -> void:
	for node in _generated:
		if is_instance_valid(node):
			node.queue_free()
	_generated.clear()
	_blocking.clear()
	_instance_counts.clear()
	_placements.clear()
	_choppable.clear()
	_tree_grid.clear()
	_shape = IslandShape.shared()
	_collect_clear_zones()

	var collision_body: StaticBody3D = null
	if not Engine.is_editor_hint():
		collision_body = StaticBody3D.new()
		collision_body.name = "VegetationCollision"
		collision_body.collision_layer = 1
		collision_body.collision_mask = 0

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	if landmark_tree and landmark_tree.model:
		var isle := IslandShape.LAKE_ISLAND_CENTER
		var placements: Array[Transform3D] = [_make_transform(landmark_tree, isle, 9.0, 0.6, Vector3.UP)]
		var tints: Array[Color] = [Color(1.05, 1.02, 0.9)]
		_reserve(isle, landmark_tree.spacing)
		_build_layer(landmark_tree, placements, tints, collision_body, &"landmark")

	_plant_barriers()

	for layer in layers:
		if layer == null or layer.model == null:
			continue
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		var own: Dictionary = {}
		var attempts := 0
		# Beach plants get more tries: the coast is a thin band of a big area.
		var max_attempts := layer.count * (45 if layer.coast > 0.0 else 25)
		while transforms.size() < layer.count and attempts < max_attempts:
			attempts += 1
			var p := _sample_point(layer, rng)
			var height := _shape.get_height(p.x, p.y)
			if height < IslandShape.SEA_LEVEL + 0.5:
				continue
			var normal := _shape.get_normal(p.x, p.y)
			if rng.randf() > _density(layer, p, height, normal):
				continue
			if not _is_free(own, p, layer.spacing, false):
				continue
			if layer.blocks_others and not _is_free(_blocking, p, layer.spacing, true):
				continue
			_mark(own, p, layer.spacing)
			if layer.blocks_others:
				_reserve(p, layer.spacing)
			var s := rng.randf_range(layer.scale_range.x, layer.scale_range.y)
			var up := normal if layer.align_to_ground else Vector3.UP
			transforms.append(_make_transform(layer, p, s, rng.randf() * TAU, up))
			var warm := rng.randf_range(-1.0, 1.0) * layer.tint_variation
			var bright := 1.0 + rng.randf_range(-1.0, 1.0) * layer.tint_variation * 0.6
			colors.append(Color(1.0 + warm * 0.4, 1.0 + warm * 0.1, 1.0 - warm * 0.5) * bright * layer.base_tint)
		_build_layer(layer, transforms, colors, collision_body, layer.id)

	if collision_body:
		add_child(collision_body)
		_generated.append(collision_body)


## The barriers (IslandShape.barrier_lines): the bramble hedge (thorny bushes). Where a
## line runs out into the water it becomes a spit of boulders. The bramble gate on the
## farm path has its own bushes, shown only until it's cleared. The solid walls are
## BarrierLine's; these plants are what you see. Placed before the other plants (and
## reserved) so everything else grows round them.
func _plant_barriers() -> void:
	var by_id := {}
	for layer in layers:
		if layer:
			by_id[layer.id] = layer
	var bush: FoliageLayer = by_id.get(&"bush")
	var fern: FoliageLayer = by_id.get(&"fern")
	var rock: FoliageLayer = by_id.get(&"rock_boulder")
	if bush == null or rock == null:
		return
	var gates := {&"brambles": IslandShape.BRAMBLE_GATE}
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 991
	for barrier_id: StringName in barrier_ids():
		var placed := {}  # FoliageLayer -> [transforms, colors]
		var gate_placed := {}
		var gate: Vector2 = gates.get(barrier_id, Vector2(INF, INF))
		var line := _shape.get_barrier_line(barrier_id)
		var tint := Color(0.86, 0.86, 0.86)
		if barrier_id == &"brambles":
			tint = Color(0.82, 0.74, 0.66)  # dark, thorny, a little red-brown
		var step_index := 0
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var tangent := (b - a).normalized()
			var side := Vector2(-tangent.y, tangent.x)
			var steps := maxi(int(a.distance_to(b) / 1.7), 1)
			for k in steps:
				step_index += 1
				var p := a.lerp(b, float(k) / steps)
				if p.distance_to(gate) < IslandShape.BARRIER_GATE_RADIUS + 1.0:
					# The gate: its own plants, shown only while it's shut (BarrierLine).
					if p.distance_to(gate) < IslandShape.BARRIER_GATE_RADIUS + 0.5:
						var gate_layer := bush
						for row in [-1.2, 1.2]:
							var q: Vector2 = p + side * row + tangent * rng.randf_range(-0.4, 0.4)
							_barrier_plant(gate_placed, gate_layer, q, rng.randf_range(3.0, 4.2) if gate_layer == rock else rng.randf_range(2.6, 3.6), rng, tint)
					continue
				for row in [-2.2, 0.0, 2.2]:
					var q: Vector2 = p + side * (row + rng.randf_range(-0.5, 0.5)) + tangent * rng.randf_range(-0.6, 0.6)
					if not _footprint_is_dry(q, 0.6):
						# Out in the water: a spit of boulders.
						if row == 0.0 and step_index % 2 == 0:
							_barrier_plant(placed, rock, q, rng.randf_range(3.2, 4.4), rng, tint)
						continue
					_barrier_plant(placed, bush, q, rng.randf_range(3.2, 4.6), rng, tint)
					_reserve(q, 2.2)
				if fern and rng.randf() < 0.6:
					var q := p + side * (3.1 if rng.randf() < 0.5 else -3.1) + tangent * rng.randf_range(-0.8, 0.8)
					if _footprint_is_dry(q, 0.5):
						_barrier_plant(placed, fern, q, rng.randf_range(fern.scale_range.y, fern.scale_range.y * 1.3), rng, tint)
		for layer: FoliageLayer in placed:
			var entry: Array = placed[layer]
			var transforms: Array[Transform3D] = []
			transforms.assign(entry[0])
			var colors: Array[Color] = []
			colors.assign(entry[1])
			_build_layer(layer, transforms, colors, null, StringName("%s_%s" % [barrier_id, layer.id]))
		for layer: FoliageLayer in gate_placed:
			var entry: Array = gate_placed[layer]
			var transforms: Array[Transform3D] = []
			transforms.assign(entry[0])
			var colors: Array[Color] = []
			colors.assign(entry[1])
			var prefix := "%s_gate_%s" % [barrier_id, layer.id]
			_build_layer(layer, transforms, colors, null, StringName(prefix))
			# BarrierLine hides these once the gate is cleared.
			for node in _generated:
				if is_instance_valid(node) and str(node.name).begins_with(prefix):
					node.add_to_group(StringName("barrier_gate_" + str(barrier_id)))


## The barrier lines that get plants (all of IslandShape's).
func barrier_ids() -> Array:
	return _shape.barrier_lines.keys()


func _barrier_plant(placed: Dictionary, layer: FoliageLayer, p: Vector2, s: float, rng: RandomNumberGenerator, tint: Color) -> void:
	if not placed.has(layer):
		placed[layer] = [[], []]
	var up := _shape.get_normal(p.x, p.y) if layer.align_to_ground else Vector3.UP
	placed[layer][0].append(_make_transform(layer, p, s, rng.randf() * TAU, up))
	var warm := rng.randf_range(-1.0, 1.0) * layer.tint_variation
	placed[layer][1].append(Color(1.0 + warm * 0.4, 1.0 + warm * 0.1, 1.0 - warm * 0.5) * tint * layer.base_tint)


## A random spot to try. Plants that only grow at the lake are tried around the lake,
## so the small lake gets as many tries as the whole island would.
func _sample_point(layer: FoliageLayer, rng: RandomNumberGenerator) -> Vector2:
	# Plants that also grow in open meadow, on beaches or on cliffs can be anywhere.
	if layer.meadow > 0.0 or layer.coast > 0.0 or layer.rocky > 0.0:
		return Vector2(rng.randf_range(-ISLAND_HALF_EXTENT.x, ISLAND_HALF_EXTENT.x), rng.randf_range(-ISLAND_HALF_EXTENT.y, ISLAND_HALF_EXTENT.y))
	# Otherwise try spots only inside the areas where this plant grows, picked by weight,
	# so small areas (the village, the lake) get as many tries as the whole island would.
	var areas: Array = []
	if layer.forest > 0.0:
		areas.append([IslandShape.FOREST_CENTER, IslandShape.FOREST_RADIUS * 1.1, layer.forest])
	if layer.hills > 0.0:
		areas.append([IslandShape.HILLS_CENTER, 100.0, layer.hills])
	if layer.village > 0.0:
		areas.append([IslandShape.VILLAGE_CENTER, IslandShape.VILLAGE_RADIUS * 1.3, layer.village])
	if layer.lakeshore > 0.0 or layer.lake_edge > 0.0 or layer.lake_surface > 0.0:
		areas.append([IslandShape.LAKE_CENTER, IslandShape.LAKE_RADIUS * 1.35, maxf(layer.lakeshore, maxf(layer.lake_edge, layer.lake_surface))])
	if areas.is_empty():
		return Vector2(rng.randf_range(-ISLAND_HALF_EXTENT.x, ISLAND_HALF_EXTENT.x), rng.randf_range(-ISLAND_HALF_EXTENT.y, ISLAND_HALF_EXTENT.y))
	var total := 0.0
	for area in areas:
		total += area[2]
	var roll := rng.randf() * total
	var chosen: Array = areas.back()
	for area in areas:
		roll -= area[2]
		if roll <= 0.0:
			chosen = area
			break
	return (chosen[0] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (chosen[1] as float)


## 0..1 chance that this layer grows at p.
func _density(layer: FoliageLayer, p: Vector2, height: float, normal: Vector3) -> float:
	var best := 0.0
	if _in_clear_zone(p):
		return 0.0
	# Land plants (everything except reeds and lily pads) never stand in water: the ground
	# must be dry around the trunk/base, not just at its centre. (A canopy may lean over.)
	if not layer.float_on_water and layer.lake_edge <= 0.0 and layer.lake_surface <= 0.0:
		if not _footprint_is_dry(p, clampf(layer.spacing * 0.25, 0.5, 1.5)):
			return 0.0
	var gentle := normal.y > 0.84
	var open := _shape.is_open_ground(p, 1.0)
	if layer.forest > 0.0 and open and gentle and height > 2.3:
		var d := p.distance_to(IslandShape.FOREST_CENTER)
		best = maxf(best, layer.forest * (1.0 - smoothstep(IslandShape.FOREST_RADIUS * 0.55, IslandShape.FOREST_RADIUS * 1.08, d)))
	if layer.hills > 0.0 and open and gentle and height > 2.3:
		var d := p.distance_to(IslandShape.HILLS_CENTER)
		best = maxf(best, layer.hills * (1.0 - smoothstep(35.0, 100.0, d)))
	if layer.meadow > 0.0 and open and normal.y > 0.88 and height > 2.3:
		best = maxf(best, layer.meadow)
	if layer.coast > 0.0 and gentle and height > 0.7 and height < 3.0 and _shape.get_land_factor(p.x, p.y) < 0.14:
		if _shape.distance_to_paths(p) > 3.5 and p.distance_to(IslandShape.HEADLAND_CENTER) > 20.0:
			best = maxf(best, layer.coast)
	if layer.village > 0.0 and normal.y > 0.9 and _is_village_garden(p):
		best = maxf(best, layer.village)
	if layer.lakeshore > 0.0 and _is_lakeshore(p, height):
		best = maxf(best, layer.lakeshore)
	if layer.lake_edge > 0.0 or layer.lake_surface > 0.0:
		var lake_d := _shape.get_lake_distance(p)
		var clear_of_features := _away_from_dock_and_isle(p)
		if layer.lake_edge > 0.0 and lake_d > 0.82 and lake_d < 1.02 and clear_of_features:
			best = maxf(best, layer.lake_edge)
		if layer.lake_surface > 0.0 and lake_d > 0.25 and lake_d < 0.8 and IslandShape.LAKE_LEVEL - height > 0.5 and clear_of_features:
			best = maxf(best, layer.lake_surface)
	if layer.rocky > 0.0 and height > 0.8 and normal.y > 0.45 and normal.y < 0.86 and not _shape.is_reserved(p, 1.0):
		best = maxf(best, layer.rocky)
	return best


## Height above the water a land plant needs, everywhere under its footprint (metres).
const DRY_MARGIN := 0.3

## True when the ground under a circle of `radius` around p is above the lake and the sea.
func _footprint_is_dry(p: Vector2, radius: float) -> bool:
	var near_lake := _shape.get_lake_distance(p) < 1.6
	var water := IslandShape.LAKE_LEVEL if near_lake else IslandShape.SEA_LEVEL
	if _shape.get_height(p.x, p.y) < water + DRY_MARGIN:
		return false
	# Only low ground near water needs the (slower) check around the edge.
	if _shape.get_height(p.x, p.y) > water + 3.0:
		return true
	for i in 8:
		var q := p + Vector2.from_angle(TAU * i / 8.0) * radius
		if _shape.get_height(q.x, q.y) < water + DRY_MARGIN:
			return false
	return true


## Buildings and props mark themselves with group "keep_clear" and optional
## metadata "clear_radius" so plants never grow through them.
func _collect_clear_zones() -> void:
	_clear_zones.clear()
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(&"keep_clear"):
		var node_3d := node as Node3D
		if node_3d:
			var radius: float = node_3d.get_meta(&"clear_radius", 3.0)
			_clear_zones.append(Vector3(node_3d.global_position.x, node_3d.global_position.z, radius))


func _in_clear_zone(p: Vector2) -> bool:
	for zone in _clear_zones:
		if Vector2(zone.x, zone.y).distance_to(p) < zone.z:
			return true
	return false


## Keeps lake plants off the fishing dock (and the water right around it) and the little island.
func _away_from_dock_and_isle(p: Vector2) -> bool:
	if p.distance_to(IslandShape.LAKE_ISLAND_CENTER) < 9.0:
		return false
	var closest := Geometry2D.get_closest_point_to_segment(p, DOCK_SHORE, DOCK_END)
	return closest.distance_to(p) > 5.0


func _is_village_garden(p: Vector2) -> bool:
	var d := p.distance_to(IslandShape.VILLAGE_CENTER)
	if d < 15.0 or d > IslandShape.VILLAGE_RADIUS * 1.3:
		return false
	return not _shape.is_reserved(p, 0.0)


func _is_lakeshore(p: Vector2, height: float) -> bool:
	var lake_d := _shape.get_lake_distance(p)
	if lake_d < 0.9 or lake_d > 1.3 or height < IslandShape.LAKE_LEVEL + 0.35:
		return false
	return not _shape.is_reserved(p, 0.0)


func _make_transform(layer: FoliageLayer, p: Vector2, s: float, yaw: float, up: Vector3) -> Transform3D:
	var tilt := Basis(Quaternion(Vector3.UP, up.normalized())) if not up.is_equal_approx(Vector3.UP) else Basis()
	var basis := tilt * Basis(Vector3.UP, yaw) * Basis().scaled(Vector3(s, s * layer.vertical_scale, s))
	var y := _shape.get_height(p.x, p.y) - layer.sink * s * layer.vertical_scale
	if layer.float_on_water:
		y = IslandShape.LAKE_LEVEL - layer.sink * s * layer.vertical_scale
	return Transform3D(basis, Vector3(p.x, y, p.y))


func _build_layer(layer: FoliageLayer, transforms: Array[Transform3D], colors: Array[Color], body: StaticBody3D, count_id: StringName) -> void:
	_instance_counts[count_id] = transforms.size()
	_placements[count_id] = transforms.duplicate()
	if transforms.is_empty():
		return
	var source := _extract_mesh(layer.model)
	if source.is_empty():
		push_warning("VegetationScatter: no mesh found in %s" % layer.model.resource_path)
		return
	var mesh: Mesh = source.mesh
	var mesh_xform: Transform3D = source.xform
	if layer.float_on_water:
		mesh_xform = level_floating_mesh(mesh, mesh_xform)
	var aabb: AABB = mesh.get_aabb()

	var material: ShaderMaterial = null if layer.use_model_material else ShaderMaterial.new()
	if material:
		_setup_foliage_material(material, layer, source, aabb)
	var chunk_size := SMALL_CHUNK if layer.visibility_range > 0.0 else BIG_CHUNK
	var choppable := layer.choppable and count_id == layer.id
	if choppable:
		var slots: Array = []
		slots.resize(transforms.size())
		_choppable[count_id] = {"layer": layer, "mesh": mesh, "mesh_xform": mesh_xform, "material": material, "slots": slots, "shapes": []}
		for i in transforms.size():
			var o := transforms[i].origin
			var cell := Vector2i(floori(o.x / 8.0), floori(o.z / 8.0))
			if not _tree_grid.has(cell):
				_tree_grid[cell] = []
			_tree_grid[cell].append([count_id, i])
	_add_chunks(layer, transforms, colors, mesh, mesh_xform, material, chunk_size, count_id)
	if body and layer.collision_radius > 0.0:
		var shapes := _add_collision(layer, transforms, body)
		if choppable:
			_choppable[count_id].shapes = shapes


func _setup_foliage_material(material: ShaderMaterial, layer: FoliageLayer, source: Dictionary, aabb: AABB) -> void:
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter(&"albedo_tex", source.texture)
	material.set_shader_parameter(&"wind_strength", layer.wind_strength)
	material.set_shader_parameter(&"sway_start", layer.sway_start)
	material.set_shader_parameter(&"mesh_min_y", aabb.position.y)
	material.set_shader_parameter(&"mesh_height", aabb.size.y)
	material.set_shader_parameter(&"ground_tint", Color(0.52, 0.74, 0.27, layer.ground_blend))
	material.set_shader_parameter(&"ground_tint_height", layer.ground_blend_height)
	material.set_shader_parameter(&"seasonal_leaves", 1.0 if layer.autumn_leaves else 0.0)


func _add_chunks(layer: FoliageLayer, transforms: Array[Transform3D], colors: Array[Color], mesh: Mesh, mesh_xform: Transform3D, material: ShaderMaterial, chunk_size: float, count_id: StringName) -> void:
	var chunks: Dictionary = {}
	for i in transforms.size():
		var origin := transforms[i].origin
		var key := Vector2i(floori(origin.x / chunk_size), floori(origin.z / chunk_size))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(i)

	for key: Vector2i in chunks:
		var indices: Array = chunks[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = material != null
		multimesh.mesh = mesh
		multimesh.instance_count = indices.size()
		for j in indices.size():
			var index: int = indices[j]
			multimesh.set_instance_transform(j, transforms[index] * mesh_xform)
			if multimesh.use_colors:
				multimesh.set_instance_color(j, colors[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "%s_%d_%d" % [count_id, key.x, key.y]
		instance.multimesh = multimesh
		if _choppable.has(count_id):
			var slots: Array = _choppable[count_id].slots
			for j in indices.size():
				slots[indices[j]] = [multimesh, j]
		if material:
			instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if layer.cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if layer.visibility_range > 0.0:
			instance.visibility_range_end = layer.visibility_range + chunk_size * 0.5
			instance.visibility_range_end_margin = 8.0
		add_child(instance)
		_generated.append(instance)


func _add_collision(layer: FoliageLayer, transforms: Array[Transform3D], body: StaticBody3D) -> Array:
	var shapes: Array = []
	for t in transforms:
		var s := t.basis.get_scale().x
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(layer.collision_radius * s, 0.15)
		cylinder.height = maxf(layer.collision_height * t.basis.get_scale().y, 0.3)
		var cs := CollisionShape3D.new()
		cs.shape = cylinder
		cs.position = t.origin + Vector3.UP * cylinder.height * 0.5
		body.add_child(cs)
		shapes.append(cs)
	return shapes


## Floating plants (lily pads) are often modelled tilted. This fits a plane through the
## outer leaves (least squares y = a*x + b*z + c), turns the model so that plane is level,
## and lowers it so the leaves sit at height 0 (the water surface). Returns the transform
## to apply before the plant's own placement.
static func level_floating_mesh(mesh: Mesh, mesh_xform: Transform3D) -> Transform3D:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_r := 0.0
	for v in verts:
		var w := mesh_xform * v
		max_r = maxf(max_r, Vector2(w.x, w.z).length())
	var sxx := 0.0; var sxz := 0.0; var szz := 0.0; var sx := 0.0; var sz := 0.0
	var sy := 0.0; var sxy := 0.0; var szy := 0.0; var n := 0.0
	var outer: Array[Vector3] = []
	for v in verts:
		var w := mesh_xform * v
		if Vector2(w.x, w.z).length() < max_r * 0.45:
			continue
		outer.append(w)
		sxx += w.x * w.x; sxz += w.x * w.z; szz += w.z * w.z
		sx += w.x; sz += w.z; sy += w.y; sxy += w.x * w.y; szy += w.z * w.y; n += 1.0
	if n < 10.0:
		return mesh_xform
	# Solve the 3x3 normal equations for a, b, c.
	var m := Basis(Vector3(sxx, sxz, sx), Vector3(sxz, szz, sz), Vector3(sx, sz, n))
	var abc := m.inverse() * Vector3(sxy, szy, sy)
	var normal := Vector3(-abc.x, 1.0, -abc.y).normalized()
	var level := Basis(Quaternion(normal, Vector3.UP))
	var heights: Array[float] = []
	for w in outer:
		heights.append((level * w).y)
	heights.sort()
	var leaf_height := heights[heights.size() / 2]
	return Transform3D(level, Vector3(0, -leaf_height, 0)) * mesh_xform


## Returns {mesh, xform, texture} for the first mesh in a model scene.
static func _extract_mesh(model: PackedScene) -> Dictionary:
	var root := model.instantiate()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	var result := {}
	if not found.is_empty():
		var mesh_instance := found[0] as MeshInstance3D
		var xform := Transform3D()
		var node: Node = mesh_instance
		while node != null and node != root:
			if node is Node3D:
				xform = (node as Node3D).transform * xform
			node = node.get_parent()
		var material := mesh_instance.get_surface_override_material(0)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(0)
		var texture: Texture2D = null
		if material is BaseMaterial3D:
			texture = (material as BaseMaterial3D).albedo_texture
		result = {"mesh": mesh_instance.mesh, "xform": xform, "texture": texture}
	root.free()
	return result


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))


func _is_free(grid: Dictionary, p: Vector2, radius: float, shared_radius: bool) -> bool:
	var reach := int(ceil(radius / 4.0)) + 1
	var cell := _cell(p)
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var entries: Variant = grid.get(cell + Vector2i(dx, dz))
			if entries == null:
				continue
			for entry: Vector3 in entries:
				var needed := (radius + entry.z) * 0.5 if shared_radius else radius
				if Vector2(entry.x, entry.y).distance_to(p) < needed:
					return false
	return true


func _mark(grid: Dictionary, p: Vector2, radius: float) -> void:
	var cell := _cell(p)
	if not grid.has(cell):
		grid[cell] = []
	grid[cell].append(Vector3(p.x, p.y, radius))


func _reserve(p: Vector2, radius: float) -> void:
	_mark(_blocking, p, radius)
