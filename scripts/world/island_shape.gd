class_name IslandShape
extends RefCounted
## Deterministic description of the island's landform and layout.
##
## This is the *blockout* terrain: a height function built from a noisy
## coastline, rolling hills, a north ridge, north-east cliffs, a lake basin and
## flattened building zones. The terrain mesh, collision and vegetation are all
## generated from this one source so they always agree.
##
## Gameplay data (region IDs, interactable IDs, water IDs) deliberately lives in
## scenes, not here, so this terrain can later be replaced by a hand-sculpted
## Terrain3D island without breaking saved state.
##
## Coordinates: X = east, Z = south, Y = up. Sea level is Y = 0.

const SEED := 20261118
const SEA_LEVEL := 0.0
const LAKE_LEVEL := 3.2
## Side length of the square terrain patch (metres). The island sits inside it.
const TERRAIN_SIZE := 640.0
const COAST_RADIUS := 210.0
const EAST_WEST_STRETCH := 1.12

const VILLAGE_CENTER := Vector2(0.0, 115.0)
const VILLAGE_RADIUS := 55.0
const VILLAGE_HEIGHT := 4.0
const LAKE_CENTER := Vector2(10.0, 15.0)
const LAKE_RADIUS := 42.0
const LAKE_ISLAND_CENTER := Vector2(-8.0, 2.0)
const FARM_CENTER := Vector2(115.0, 70.0)
const FARM_RADIUS := 36.0
const FARM_HEIGHT := 5.0
## Centre of the garden beds, relative to FARM_CENTER (see FarmField in island.tscn).
const FARM_BEDS_OFFSET := Vector2(2.4, -1.2)
const HILLS_CENTER := Vector2(-20.0, -125.0)
const FOREST_CENTER := Vector2(-115.0, -20.0)
const FOREST_RADIUS := 95.0
const HEADLAND_CENTER := Vector2(172.0, -92.0)
const CLIFF_DIRECTION := Vector2(0.8, -0.6)
const PATH_HALF_WIDTH := 1.8

## Willow Creek: a stream that rises at a spring in the western meadows (CREEK_SPRING)
## and runs two ways: east to the lake's west shore and west to the sea. It is too deep
## and quick to wade, so the old stone bridge (~(-75, 45)) is the only way across: the
## Ch. 2 gate into Fernwood Forest. Both ends run on until the water is deep (the lake
## and the sea are too deep to wade there), so you can't walk round them.
const CREEK_POINTS: Array[Vector2] = [
	Vector2(-246, 31), Vector2(-222, 35), Vector2(-198, 33), Vector2(-176, 38),
	Vector2(-156, 37), Vector2(-138, 42), Vector2(-114, 49), Vector2(-92, 52),
	Vector2(-75, 45), Vector2(-56, 38), Vector2(-38, 28), Vector2(-24, 20),
	Vector2(-15, 18),
]
## Index in CREEK_POINTS of the spring: water flows away from it both ways.
const CREEK_SPRING := 5
## Water half-width, then the sloping bank on each side (metres).
const CREEK_HALF_WIDTH := 2.6
const CREEK_BANK := 4.0
const CREEK_DEPTH := 1.6
## Water stays at least this far below the surrounding ground.
const CREEK_BELOW_GROUND := 0.75
const CREEK_BRIDGE := Vector2(-75.0, 45.0)

## Barriers: lines you can't walk through (a solid wall down the middle, with plants
## along it: see BarrierLine and VegetationScatter). Ends that touch water are carried on
## into water too deep to wade, so you can't go round them there.
## The bramble hedge between the village and the farm, from the south coast to just
## short of the lake path. The farm path crosses it at the bramble gate (Ch. 1, cleared
## with Mia); until then the way to the farm is round the north end, by the lake path.
const BRAMBLE_POINTS: Array[Vector2] = [
	Vector2(86, 158), Vector2(80, 125), Vector2(72.08, 90.96), Vector2(67, 70),
	Vector2(63, 50),
]
const BRAMBLE_GATE := Vector2(72.08, 90.96)
## Lighthouse Isle: a small, steep, rocky island in the sea off the north-east coast,
## with the lighthouse and the keeper's cottage. Grandpa's old footbridge joins it to the
## main island's cliffs at the end of the coast path (Ch. 4: a rockfall from the cliff
## smashed it; mended with Theo). Open sea all round, so the bridge is the only way over.
const ISLE_CENTER := Vector2(205.8, -164.5)
const ISLE_RADIUS := 24.0
## Height of the isle's grassy top (it drops to the sea in cliffs all round).
const ISLE_HEIGHT := 13.0
## On the headland where the coast path ends and the footbridge sets out.
const ISLE_BRIDGE_START := Vector2(178.0, -106.0)
## The lighthouse stands on the far side of the isle from the bridge.
const ISLE_LIGHTHOUSE := Vector2(207.9, -169.0)
## Half-width of a barrier's band of plants (the solid wall runs down its middle).
const BARRIER_HALF_WIDTH := 3.2
## A gate leaves this much of its barrier line open (round the path) once it's cleared.
const BARRIER_GATE_RADIUS := 4.5
## How deep the water must be before a barrier can stop: deeper than the player can
## wade (PlayerController.max_water_depth), with a margin.
const BARRIER_WATER_DEPTH := 1.7

## Dirt paths as polylines of (x, z) points.
var paths: Array[PackedVector2Array] = []

static var _shared: IslandShape

var _coast_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _path_bounds: Array[Rect2] = []
## Dense creek centre line: x, z and the water level there (flows downhill only).
var creek_samples: PackedVector3Array = PackedVector3Array()
var _creek_bounds: Rect2
## Barrier centre lines by id (&"brambles"), ends carried on into deep water where they
## reach it.
var barrier_lines: Dictionary = {}
var _barrier_bounds: Dictionary = {}
var _isle_bridge_ends := PackedVector2Array()


## One shared instance: the shape is deterministic, so everyone can use the same one.
static func shared() -> IslandShape:
	if _shared == null:
		_shared = IslandShape.new()
	return _shared


func _init() -> void:
	_coast_noise.seed = SEED
	_coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast_noise.frequency = 0.011
	_coast_noise.fractal_octaves = 3

	_hill_noise.seed = SEED + 1
	_hill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hill_noise.frequency = 0.0075
	_hill_noise.fractal_octaves = 4

	_detail_noise.seed = SEED + 2
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.045
	_detail_noise.fractal_octaves = 2

	paths = [
		# Village square -> fishing dock on Moonlit Lake
		PackedVector2Array([Vector2(0, 115), Vector2(4, 92), Vector2(10, 72), Vector2(10, 62)]),
		# Village -> Sunflower Fields (farm)
		PackedVector2Array([Vector2(0, 115), Vector2(35, 108), Vector2(70, 92), Vector2(98, 78)]),
		# Village -> Fernwood Forest (bends north round Grandpa's cottage at (-25.5, 100))
		PackedVector2Array([Vector2(0, 115), Vector2(-10, 104), Vector2(-17, 90), Vector2(-34, 82), Vector2(-62, 62), Vector2(-90, 25), Vector2(-112, -10)]),
		# Footpath from the forest road to the cottage's front porch
		PackedVector2Array([Vector2(-11.4, 101.2), Vector2(-21.5, 100.2)]),
		# Village -> south-west beach
		PackedVector2Array([Vector2(0, 115), Vector2(-30, 140), Vector2(-62, 162), Vector2(-85, 178)]),
		# Lake shore -> lighthouse headland (Whispering Coast)
		PackedVector2Array([Vector2(52, 20), Vector2(88, -20), Vector2(128, -58), Vector2(160, -84)]),
		# Village -> lake east shore
		PackedVector2Array([Vector2(35, 108), Vector2(52, 70), Vector2(56, 40), Vector2(52, 20)]),
		# Farm's east gate -> the shipping jetty (ShippingYard), clear of the orchard
		PackedVector2Array([Vector2(131, 75), Vector2(148, 84), Vector2(158, 102), Vector2(161, 116)]),
	]
	for path in paths:
		_path_bounds.append(_bounds_of(path))
	_build_creek()
	_build_barriers()
	# The coast path runs on to the footbridge, and a path crosses the isle to the
	# lighthouse.
	var ends := get_isle_bridge_ends()
	var coast_path: PackedVector2Array = paths[5]
	coast_path.append(ISLE_BRIDGE_START)
	coast_path.append(ends[0])
	paths[5] = coast_path
	_path_bounds[5] = _bounds_of(coast_path)
	paths.append(PackedVector2Array([ends[1], ISLE_LIGHTHOUSE]))
	_path_bounds.append(_bounds_of(paths[-1]))


## 1 at the island centre, 0 at the nominal coastline, negative out at sea.
func get_land_factor(x: float, z: float) -> float:
	var angle := atan2(z, x)
	var dir := Vector2(cos(angle), sin(angle))
	var coast := COAST_RADIUS * (1.0 + 0.17 * _coast_noise.get_noise_2d(dir.x * 100.0, dir.y * 100.0))
	var q := Vector2(x / EAST_WEST_STRETCH, z)
	return 1.0 - q.length() / coast


func get_height(x: float, z: float) -> float:
	var h := _base_height(x, z)
	var p := Vector2(x, z)
	if _creek_bounds.has_point(p):
		h = _carve_creek(p, h)
	return h


## The landform before Willow Creek is carved into it.
func _base_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var land := get_land_factor(x, z)

	# Sea floor -> beach -> lowland.
	var shore := smoothstep(-0.16, 0.12, land)
	var h := lerpf(-8.0, 3.6, shore)

	# Rolling hills inland (never below the lowland, so no accidental ponds).
	var inland := smoothstep(0.04, 0.32, land)
	h += inland * (_hill_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 7.0
	h += inland * _gauss(p, HILLS_CENTER, 60.0) * 24.0
	h += inland * _gauss(p, FOREST_CENTER, 75.0) * 6.0

	# North-east cliffs and the lighthouse headland.
	if p.length_squared() > 1.0:
		var cliff := smoothstep(0.45, 0.85, p.normalized().dot(CLIFF_DIRECTION.normalized()))
		h += cliff * 9.0 * smoothstep(-0.01, 0.035, land)
	h += _gauss(p, HEADLAND_CENTER, 30.0) * 6.0 * smoothstep(0.0, 0.05, land)

	# Small surface variation everywhere above water.
	h += _detail_noise.get_noise_2d(x, z) * 0.6 * shore

	# Flatten building zones.
	h = lerpf(h, VILLAGE_HEIGHT + _detail_noise.get_noise_2d(x, z) * 0.15, _flat_weight(p, VILLAGE_CENTER, VILLAGE_RADIUS))
	h = lerpf(h, FARM_HEIGHT, _flat_weight(p, FARM_CENTER, FARM_RADIUS))

	# Carve Moonlit Lake (bottom stays above sea level so the sea never shows through).
	var lake_d := get_lake_distance(p)
	var bowl := LAKE_LEVEL - 2.8 + 3.3 * lake_d * lake_d
	h = lerpf(h, bowl, 1.0 - smoothstep(0.85, 1.6, lake_d))
	# A small island in the lake (only inside the lake basin).
	if lake_d < 0.8:
		h = maxf(h, LAKE_LEVEL - 2.6 + 4.2 * _gauss(p, LAKE_ISLAND_CENTER, 6.0))
	# Lighthouse Isle: a grassy top on sheer cliffs, out in the sea.
	var isle_d := get_isle_distance(p)
	if isle_d < 1.3:
		var top := ISLE_HEIGHT + 1.6 * (1.0 - isle_d * isle_d) + _detail_noise.get_noise_2d(x, z) * 0.5
		h = lerpf(h, maxf(h, top), 1.0 - smoothstep(0.8, 1.0, isle_d))
	return h


## Distance from the lake centre, normalised by an irregular (noisy) shore radius.
## About 0.92 is the waterline.
func get_lake_distance(p: Vector2) -> float:
	var offset := p - LAKE_CENTER
	if offset.length_squared() < 0.01:
		return 0.0
	var dir := offset.normalized()
	var wobble := 1.0 + 0.15 * _coast_noise.get_noise_2d(dir.x * 45.0 + 500.0, dir.y * 45.0 + 500.0)
	return offset.length() / (LAKE_RADIUS * wobble)


## Distance to Willow Creek's centre line (x) and the water level there (y).
func get_creek_info(p: Vector2) -> Vector2:
	if not _creek_bounds.has_point(p):
		return Vector2(INF, 0.0)
	var best := INF
	var level := 0.0
	for i in creek_samples.size() - 1:
		var a := Vector2(creek_samples[i].x, creek_samples[i].y)
		var b := Vector2(creek_samples[i + 1].x, creek_samples[i + 1].y)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			level = lerpf(creek_samples[i].z, creek_samples[i + 1].z, t)
	return Vector2(best, level)


## True in Willow Creek's water (not on its banks).
func is_in_creek(p: Vector2, margin: float = 0.0) -> bool:
	return get_creek_info(p).x < CREEK_HALF_WIDTH + margin


func _build_creek() -> void:
	creek_samples.clear()
	var points: Array[Vector2] = CREEK_POINTS.duplicate()
	# The sea end runs on until the sea is too deep to wade round it.
	points.push_front(_run_into_sea(points[0], points[0] - points[1]))
	var spring_point := CREEK_SPRING + 1
	var positions: Array[Vector2] = []
	var spring_sample := 0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(int(a.distance_to(b) / 1.5), 1)
		if i == spring_point:
			spring_sample = positions.size()
		for s in steps + (1 if i == points.size() - 2 else 0):
			positions.append(a.lerp(b, float(s) / steps))
	# Water level: from the spring it only ever flows downhill, both ways.
	var levels := PackedFloat32Array()
	levels.resize(positions.size())
	for i in positions.size():
		levels[i] = _base_height(positions[i].x, positions[i].y) - CREEK_BELOW_GROUND
	for i in range(spring_sample + 1, positions.size()):
		levels[i] = minf(levels[i], levels[i - 1])
	for i in range(spring_sample - 1, -1, -1):
		levels[i] = minf(levels[i], levels[i + 1])
	var bounds := Rect2(positions[0], Vector2.ZERO)
	for i in positions.size():
		var q := positions[i]
		var water: float
		if i >= spring_sample:
			water = maxf(levels[i], LAKE_LEVEL + 0.02)
			# Meet the lake surface smoothly where the creek runs into it.
			water = lerpf(LAKE_LEVEL + 0.02, water, smoothstep(0.95, 1.2, get_lake_distance(q)))
		else:
			water = maxf(levels[i], SEA_LEVEL + 0.02)
		creek_samples.append(Vector3(q.x, q.y, water))
		bounds = bounds.expand(q)
	_creek_bounds = bounds.grow(CREEK_HALF_WIDTH + CREEK_BANK + 1.0)


## Carries a line on from `from` in `direction` until the sea floor is deeper than
## BARRIER_WATER_DEPTH (a few metres past that, to be safe).
func _run_into_sea(from: Vector2, direction: Vector2) -> Vector2:
	var dir := direction.normalized()
	var p := from
	for i in 40:
		if _base_height(p.x, p.y) < SEA_LEVEL - BARRIER_WATER_DEPTH:
			return p + dir * 4.0
		p += dir * 2.0
	return p


func _build_barriers() -> void:
	# The bramble hedge: into the sea at its south end; the north end stops on land.
	var brambles := PackedVector2Array(BRAMBLE_POINTS)
	brambles.insert(0, _run_into_sea(brambles[0], brambles[0] - brambles[1]))
	barrier_lines = {&"brambles": brambles}
	for id: StringName in barrier_lines:
		var line: PackedVector2Array = barrier_lines[id]
		var bounds := Rect2(line[0], Vector2.ZERO)
		for q in line:
			bounds = bounds.expand(q)
		_barrier_bounds[id] = bounds.grow(BARRIER_HALF_WIDTH + 2.0)


func _bounds_of(path: PackedVector2Array) -> Rect2:
	var rect := Rect2(path[0], Vector2.ZERO)
	for point in path:
		rect = rect.expand(point)
	return rect.grow(PATH_HALF_WIDTH * 3.0)


## Distance from the isle's centre, normalised by its irregular radius (1 = cliff foot).
func get_isle_distance(p: Vector2) -> float:
	var offset := p - ISLE_CENTER
	if offset.length_squared() < 0.01:
		return 0.0
	var dir := offset.normalized()
	var wobble := 1.0 + 0.12 * _coast_noise.get_noise_2d(dir.x * 60.0 + 900.0, dir.y * 60.0 + 900.0)
	return offset.length() / (ISLE_RADIUS * wobble)


## The two ends of the footbridge on solid ground, at the top of the cliffs on either
## side: [main island end, isle end].
func get_isle_bridge_ends() -> PackedVector2Array:
	if not _isle_bridge_ends.is_empty():
		return _isle_bridge_ends
	var dir := (ISLE_CENTER - ISLE_BRIDGE_START).normalized()
	var start_h := get_height(ISLE_BRIDGE_START.x, ISLE_BRIDGE_START.y)
	var main_end := ISLE_BRIDGE_START
	for i in 120:
		var next := main_end + dir * 0.5
		var h := get_height(next.x, next.y)
		if h < start_h - 1.2 or h < SEA_LEVEL + 1.5:
			break
		main_end = next
	var isle_end := ISLE_CENTER
	for i in 120:
		var next := isle_end - dir * 0.5
		if get_height(next.x, next.y) < ISLE_HEIGHT - 0.8:
			break
		isle_end = next
	_isle_bridge_ends = PackedVector2Array([main_end, isle_end])
	return _isle_bridge_ends


## A barrier's centre line (empty for an unknown id).
func get_barrier_line(id: StringName) -> PackedVector2Array:
	return barrier_lines.get(id, PackedVector2Array())


## Distance to a barrier's centre line, or to the nearest one when id is empty (INF far
## away from them).
func distance_to_barrier(p: Vector2, id: StringName = &"") -> float:
	var best := INF
	for key: StringName in barrier_lines:
		if id != &"" and key != id:
			continue
		if not (_barrier_bounds[key] as Rect2).grow(20.0).has_point(p):
			continue
		var line: PackedVector2Array = barrier_lines[key]
		for i in line.size() - 1:
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p))
	return best


## The two ends of the old stone bridge, on the ground either side of the creek where
## the forest path crosses it: [village side, forest side].
func get_bridge_ends() -> PackedVector2Array:
	var along := (Vector2(-90, 25) - Vector2(-62, 62)).normalized()  # the forest path
	var reach := CREEK_HALF_WIDTH + CREEK_BANK + 2.5
	return PackedVector2Array([CREEK_BRIDGE - along * reach, CREEK_BRIDGE + along * reach])


## True if walking straight from a to b would cross Willow Creek.
func crosses_creek(a: Vector2, b: Vector2) -> bool:
	if not _creek_bounds.intersects(Rect2(a, Vector2.ZERO).expand(b)):
		return false
	for i in creek_samples.size() - 1:
		var c := Vector2(creek_samples[i].x, creek_samples[i].y)
		var d := Vector2(creek_samples[i + 1].x, creek_samples[i + 1].y)
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return true
	return false


## Water depth of Willow Creek at a world point (0 on dry ground, on the banks above the
## water line, on the bridge, or away from the creek).
func get_creek_depth(point: Vector3) -> float:
	var info := get_creek_info(Vector2(point.x, point.z))
	if info.x >= CREEK_HALF_WIDTH:
		return 0.0
	return maxf(info.y - point.y, 0.0)


func _carve_creek(p: Vector2, h: float) -> float:
	var info := get_creek_info(p)
	var d := info.x
	if d > CREEK_HALF_WIDTH + CREEK_BANK:
		return h
	var bed: float
	if d < CREEK_HALF_WIDTH:
		var t := d / CREEK_HALF_WIDTH
		bed = info.y - CREEK_DEPTH * (1.0 - t * t)
	else:
		bed = lerpf(info.y + 0.05, h, smoothstep(CREEK_HALF_WIDTH, CREEK_HALF_WIDTH + CREEK_BANK, d))
	return minf(h, bed)


func get_normal(x: float, z: float, step: float = 1.0) -> Vector3:
	var dx := get_height(x + step, z) - get_height(x - step, z)
	var dz := get_height(x, z + step) - get_height(x, z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


func distance_to_paths(p: Vector2) -> float:
	var best := INF
	for i in paths.size():
		if not _path_bounds[i].has_point(p):
			continue
		var path := paths[i]
		for j in path.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(p, path[j], path[j + 1])
			best = minf(best, closest.distance_to(p))
	return best


## Surface paint weights packed in a Color: r = sand, g = rock, b = dirt/path.
## Grass is whatever is left.
func get_surface_weights(x: float, z: float, height: float, normal: Vector3) -> Color:
	var p := Vector2(x, z)
	var sand := 1.0 - smoothstep(1.3, 2.6, height)
	var lake_d := get_lake_distance(p)
	if lake_d < 1.25:
		sand = maxf(sand, 1.0 - smoothstep(0.15, 0.7, height - LAKE_LEVEL))
	var creek_d := get_creek_info(p).x
	if creek_d < CREEK_HALF_WIDTH + CREEK_BANK:
		# A narrow pebbly strip at the waterline; the rest of the bank stays grassy.
		var strip := smoothstep(CREEK_HALF_WIDTH - 0.6, CREEK_HALF_WIDTH, creek_d)
		sand = maxf(sand, strip * (1.0 - smoothstep(CREEK_HALF_WIDTH + 0.2, CREEK_HALF_WIDTH + 1.4, creek_d)))
	var rock := 1.0 - smoothstep(0.58, 0.74, normal.y)
	# Lighthouse Isle's cliffs are bare rock right up to the top.
	var isle_d := get_isle_distance(p)
	if isle_d < 1.2:
		rock = maxf(rock, smoothstep(0.76, 0.84, isle_d))
		sand *= 1.0 - rock
	var dirt := 1.0 - smoothstep(PATH_HALF_WIDTH * 0.6, PATH_HALF_WIDTH * 1.4, distance_to_paths(p))
	dirt = maxf(dirt, 1.0 - smoothstep(9.0, 13.0, p.distance_to(VILLAGE_CENTER)))
	# Worn earth only around the garden beds; the rest of the farm stays grassy.
	dirt = maxf(dirt, 1.0 - smoothstep(8.0, 11.5, p.distance_to(FARM_CENTER + FARM_BEDS_OFFSET)))
	# Willow Creek's bed is dark earth, so the shallow water reads as water, not sand.
	if creek_d < CREEK_HALF_WIDTH:
		sand *= smoothstep(CREEK_HALF_WIDTH - 0.6, CREEK_HALF_WIDTH, creek_d)
		dirt = maxf(dirt, 1.0 - smoothstep(CREEK_HALF_WIDTH - 0.6, CREEK_HALF_WIDTH, creek_d))
	return Color(sand, rock, dirt * (1.0 - rock), 1.0)


## True on or right next to a path (keep walkways clear of plants).
func is_reserved(p: Vector2, margin: float = 0.0) -> bool:
	return distance_to_paths(p) < PATH_HALF_WIDTH + 1.6 + margin


## True where wild props (trees, rocks, bushes) may be placed.
func is_open_ground(p: Vector2, margin: float = 0.0) -> bool:
	if p.distance_to(VILLAGE_CENTER) < VILLAGE_RADIUS * 1.05 + margin:
		return false
	if p.distance_to(FARM_CENTER) < FARM_RADIUS * 1.25 + margin:
		return false
	if get_lake_distance(p) < 1.25 + margin / LAKE_RADIUS:
		return false
	if p.distance_to(HEADLAND_CENTER) < 14.0 + margin:
		return false
	if get_creek_info(p).x < CREEK_HALF_WIDTH + CREEK_BANK + 1.0 + margin:
		return false
	if distance_to_barrier(p) < BARRIER_HALF_WIDTH + 1.5 + margin:
		return false
	var bridge := get_isle_bridge_ends()
	if Geometry2D.get_closest_point_to_segment(p, bridge[0], bridge[1]).distance_to(p) < 5.0 + margin:
		return false
	if distance_to_paths(p) < PATH_HALF_WIDTH + 2.5 + margin:
		return false
	return true


func _gauss(p: Vector2, center: Vector2, sigma: float) -> float:
	return exp(-p.distance_squared_to(center) / (2.0 * sigma * sigma))


func _flat_weight(p: Vector2, center: Vector2, radius: float) -> float:
	return 1.0 - smoothstep(radius * 0.75, radius * 1.3, p.distance_to(center))
