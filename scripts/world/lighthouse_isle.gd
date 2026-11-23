@tool
class_name LighthouseIsle
extends Node3D
## The rocks of Lighthouse Isle, built in code round the isle's shore (found from
## IslandShape: where its cliffs meet the sea):
## - Sea stacks: tall, tapering pillars of layered rock standing in the water, like
##   giant dripstones, wet and dark at the waterline and mossy on top, some with smaller
##   spires beside them.
## - Mossy stones: boulders scattered along the cliff tops and round the lighthouse.
## Deterministic, so the isle looks the same every launch. Keeps clear of the bridge,
## the path and the story places (`keep_clear` points below).

const SEA_STACKS := 14
const MOSSY_STONES := 26
const ROCK_COLOR := Color(0.55, 0.55, 0.53)
const WET_COLOR := Color(0.24, 0.26, 0.27)
const MOSS_COLOR := Color(0.37, 0.52, 0.19)
const MOSSY_ROCK := preload("res://source_assets/tripo/rock_boulder_a.glb")
## Places the rocks keep away from (x, z, radius): the cottage, the lighthouse, the lens
## workshop, the tide pool and sea cave, journal page 7 and Luna's spots.
const KEEP_CLEAR: Array[Vector3] = [
	Vector3(197.7, -166.1, 8.0), Vector3(207.9, -169.0, 6.5), Vector3(204.4, -165.5, 3.0),
	Vector3(200.5, -161.9, 2.5), Vector3(201.9, -163.8, 2.5), Vector3(201.3, -149.2, 2.5),
]

var _rng := RandomNumberGenerator.new()
## Vertices added to the sea-stack mesh so far (for its triangle indices).
var _vertex_count := 0


func _ready() -> void:
	build()


## Number of sea stacks (main pillars and their smaller spires) and mossy stones (tests).
func get_stack_count() -> int:
	return get_node("SeaStacks").get_meta(&"stacks", 0) if has_node("SeaStacks") else 0


func get_stone_count() -> int:
	return get_node("MossyStones").get_child_count() if has_node("MossyStones") else 0


func build() -> void:
	for child in get_children():
		child.queue_free()
	_rng.seed = 90210
	_vertex_count = 0
	var shore := _find_shore()
	_build_stacks(shore)
	_build_stones(shore)


## Shore points round the isle: [point at the foot of the cliff, outward direction].
func _find_shore() -> Array:
	var shape := IslandShape.shared()
	var out := []
	for i in 72:
		var dir := Vector2.from_angle(TAU * i / 72.0)
		var r := 4.0
		while r < 60.0:
			var p := IslandShape.ISLE_CENTER + dir * r
			if shape.get_height(p.x, p.y) < IslandShape.SEA_LEVEL + 0.3:
				out.append([p, dir])
				break
			r += 0.5
	return out


func _is_clear(p: Vector2, extra: float) -> bool:
	for zone in KEEP_CLEAR:
		if p.distance_to(Vector2(zone.x, zone.y)) < zone.z + extra:
			return false
	var shape := IslandShape.shared()
	var ends := shape.get_isle_bridge_ends()
	if Geometry2D.get_closest_point_to_segment(p, ends[0], ends[1]).distance_to(p) < 9.0 + extra:
		return false
	return true


func _build_stacks(shore: Array) -> void:
	var shape := IslandShape.shared()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed: Array[Vector2] = []
	var count := 0
	var tries := 0
	while placed.size() < SEA_STACKS and tries < 400 and not shore.is_empty():
		tries += 1
		var entry: Array = shore[_rng.randi() % shore.size()]
		var p: Vector2 = entry[0]
		var dir: Vector2 = entry[1]
		# Out in the water, near the foot of the cliffs.
		var base := p + dir * _rng.randf_range(3.0, 15.0)
		if shape.get_height(base.x, base.y) > IslandShape.SEA_LEVEL - 1.2 or not _is_clear(base, 4.0):
			continue
		var too_close := false
		for other in placed:
			too_close = too_close or other.distance_to(base) < 7.0
		if too_close:
			continue
		placed.append(base)
		var height := _rng.randf_range(5.0, 15.0)
		var radius := _rng.randf_range(1.6, 3.4)
		_stack(st, base, height, radius)
		count += 1
		# One or two smaller spires at its foot, like a cluster of dripstones.
		for k in _rng.randi_range(0, 2):
			var near := base + Vector2.from_angle(_rng.randf() * TAU) * (radius + _rng.randf_range(1.2, 2.6))
			if shape.get_height(near.x, near.y) < IslandShape.SEA_LEVEL - 0.6:
				_stack(st, near, height * _rng.randf_range(0.3, 0.55), radius * _rng.randf_range(0.4, 0.6))
				count += 1
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	var mesh := MeshInstance3D.new()
	mesh.name = "SeaStacks"
	mesh.mesh = st.commit()
	mesh.material_override = material
	mesh.set_meta(&"stacks", count)
	add_child(mesh)


## One pillar: rings of rock that bulge and narrow as they rise (layered, like a
## dripstone), leaning a little, ending in a rounded point.
func _stack(st: SurfaceTool, base: Vector2, height: float, radius: float) -> void:
	var shape := IslandShape.shared()
	var bottom := minf(shape.get_height(base.x, base.y), IslandShape.SEA_LEVEL - 1.0) - 0.8
	var top := IslandShape.SEA_LEVEL + height
	var sides := 11
	var rings := int((top - bottom) / 0.6) + 2
	var lean := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.02, 0.09)
	var phase := _rng.randf() * TAU
	var tip_radius := radius * _rng.randf_range(0.18, 0.35)
	var start := _vertex_count
	for j in rings:
		var t := float(j) / (rings - 1)
		var y := lerpf(bottom, top, t)
		var rise := y - bottom
		var r := lerpf(radius, tip_radius, pow(t, 0.75)) * (1.0 + 0.13 * sin(t * 11.0 + phase) + 0.06 * sin(t * 29.0 + phase * 2.0))
		var centre := base + lean * rise
		for k in sides:
			var angle := TAU * k / sides + 0.15 * sin(j * 1.7 + k)
			var rr := r * (1.0 + 0.16 * sin(k * 2.3 + j * 0.9 + phase) + 0.08 * sin(k * 5.1 + j * 2.7))
			var v := Vector3(centre.x + cos(angle) * rr, y, centre.y + sin(angle) * rr)
			st.set_color(_rock_color(y, t, k, j))
			st.add_vertex(to_local(v))
			_vertex_count += 1
	# The rounded tip.
	var tip_centre := base + lean * (top - bottom)
	st.set_color(MOSS_COLOR)
	st.add_vertex(to_local(Vector3(tip_centre.x, top + tip_radius * 1.4, tip_centre.y)))
	_vertex_count += 1
	for j in rings - 1:
		for k in sides:
			var a := start + j * sides + k
			var b := start + j * sides + (k + 1) % sides
			var c := a + sides
			var d := b + sides
			for index in [a, c, b, b, c, d]:
				st.add_index(index)
	var tip := start + rings * sides
	var last := start + (rings - 1) * sides
	for k in sides:
		for index in [last + k, tip, last + (k + 1) % sides]:
			st.add_index(index)


func _rock_color(y: float, t: float, k: int, j: int) -> Color:
	# Wet and dark round the waterline and below.
	if y < IslandShape.SEA_LEVEL + 0.7:
		return WET_COLOR.lerp(ROCK_COLOR, clampf((y - IslandShape.SEA_LEVEL) / 0.7, 0.0, 1.0) * 0.4)
	# Layered rock: faint bands, a little warmer or cooler.
	var band := 0.05 * sin(y * 2.4 + k * 0.2) + 0.03 * sin(y * 7.0)
	var rock := ROCK_COLOR * (1.0 + band)
	rock.a = 1.0
	# Moss creeps over the upper part and in patches lower down.
	var moss := smoothstep(0.62, 0.92, t)
	if sin(k * 1.9 + j * 0.7) > 0.82 and t > 0.25:
		moss = maxf(moss, 0.7)
	return rock.lerp(MOSS_COLOR, moss)


func _build_stones(shore: Array) -> void:
	var shape := IslandShape.shared()
	var stones := Node3D.new()
	stones.name = "MossyStones"
	add_child(stones)
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < MOSSY_STONES and tries < 600:
		tries += 1
		var p: Vector2
		if placed.size() < MOSSY_STONES - 8 and not shore.is_empty():
			# Along the cliff tops.
			var entry: Array = shore[_rng.randi() % shore.size()]
			p = (entry[0] as Vector2) - (entry[1] as Vector2) * _rng.randf_range(6.0, 11.0)
		else:
			# A few round the lighthouse.
			p = IslandShape.ISLE_LIGHTHOUSE + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(6.0, 11.0)
		var h := shape.get_height(p.x, p.y)
		if h < IslandShape.SEA_LEVEL + 0.8 or shape.get_normal(p.x, p.y).y < 0.7:
			continue
		if shape.distance_to_paths(p) < 3.0 or shape.get_isle_distance(p) > 0.78 or not _is_clear(p, 1.5):
			continue
		var too_close := false
		for other in placed:
			too_close = too_close or other.distance_to(p) < 2.8
		if too_close:
			continue
		placed.append(p)
		var rock := FittedModel.new()
		rock.model = MOSSY_ROCK
		rock.size = _rng.randf_range(1.0, 3.2)
		rock.collision = FittedModel.Collision.BOX if not Engine.is_editor_hint() else FittedModel.Collision.NONE
		rock.position = to_local(Vector3(p.x, h, p.y))
		rock.rotation.y = _rng.randf() * TAU
		stones.add_child(rock)
