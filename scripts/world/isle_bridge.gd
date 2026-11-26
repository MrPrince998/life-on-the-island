@tool
class_name IsleBridge
extends Node3D
## Grandpa's wooden footbridge to Lighthouse Isle: planks and rails on mossy stone piers
## across the sea from the main island's cliffs to the isle, carrying the coast path
## (ends from IslandShape.get_isle_bridge_ends). Built in code.
##
## One node per look, switched by the Rockfall StoryVariant (flag ch4_rockfall_cleared):
## - WHOLE: the mended bridge you can walk across.
## - BROKEN: a rockfall from the main island's cliff smashed the spans nearest it. They
##   are gone (broken planks hang from both edges) and fallen boulders block the way on.
## - ROCKFALL: fallen rocks along the main island's cliff top by the bridge, and more
##   in the sea below (stays after the repair: the island remembers the storm).

enum Part { WHOLE, BROKEN, ROCKFALL }

@export var part: Part = Part.WHOLE:
	set(value):
		part = value
		if is_inside_tree():
			build()

const DECK_WIDTH := 2.4
const RAIL_HEIGHT := 1.05
## Piers stand in the water every this many metres (measured from the crossing).
const PIER_SPACING := 7.0
const PLANK_COLOR := Color(0.50, 0.32, 0.18)
const BEAM_COLOR := Color(0.34, 0.21, 0.12)
const POST_COLOR := Color(0.27, 0.17, 0.10)
const STONE_COLOR := Color(0.50, 0.51, 0.52)
const WET_STONE_COLOR := Color(0.27, 0.29, 0.30)
const MOSS_COLOR := Color(0.36, 0.50, 0.20)
const BOULDER := preload("res://source_assets/tripo/boulder.glb")
const MOSSY_ROCK := preload("res://source_assets/tripo/rock_boulder_a.glb")

var _st: SurfaceTool
var _rng := RandomNumberGenerator.new()
var _body: StaticBody3D


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.queue_free()
	_rng.seed = 4242 + part
	var shape := IslandShape.shared()
	var ends := shape.get_isle_bridge_ends()
	var a := to_local(Vector3(ends[0].x, shape.get_height(ends[0].x, ends[0].y) + 0.12, ends[0].y))
	var b := to_local(Vector3(ends[1].x, shape.get_height(ends[1].x, ends[1].y) + 0.12, ends[1].y))
	_body = null
	if not Engine.is_editor_hint() and part != Part.ROCKFALL:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = 1
		_body.collision_mask = 0
		add_child(_body)
	match part:
		Part.WHOLE:
			_begin()
			for t in _pier_positions(a, b):
				var p := a.lerp(b, t)
				_pier_at(p, b - a, p.y - 0.33, false)
			_span(a, b)
			_end_posts(a, b - a)
			_end_posts(b, a - b)
			_commit("Bridge")
		Part.BROKEN:
			_build_broken(a, b)
		Part.ROCKFALL:
			_build_rockfall(a, b)


## Number of stone piers under the whole bridge (used by tests).
func get_pier_count() -> int:
	var shape := IslandShape.shared()
	var ends := shape.get_isle_bridge_ends()
	var a := Vector3(ends[0].x, shape.get_height(ends[0].x, ends[0].y), ends[0].y)
	var b := Vector3(ends[1].x, shape.get_height(ends[1].x, ends[1].y), ends[1].y)
	return _pier_positions(to_local(a), to_local(b)).size()


## Where along the bridge (0 = main island end, 1 = isle end) each pier stands: every
## PIER_SPACING metres, wherever there is deep enough sea under it.
func _pier_positions(a: Vector3, b: Vector3) -> Array[float]:
	var length := a.distance_to(b)
	var shape := IslandShape.shared()
	var count := maxi(int(length / PIER_SPACING), 1)
	var out: Array[float] = []
	for k in range(1, count):
		var t := float(k) / count
		var world := to_global(a.lerp(b, t))
		if shape.get_height(world.x, world.z) < IslandShape.SEA_LEVEL - 1.0:
			out.append(t)
	return out


func _build_broken(a: Vector3, b: Vector3) -> void:
	var piers := _pier_positions(a, b)
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	# The spans from the main island's cliff out to the middle pier are gone, with the
	# first pier: the rocks came down on that end.
	var gap_to: float = piers[1] if piers.size() > 1 else 0.5
	_begin()
	for t in piers:
		var p := a.lerp(b, t)
		if t > gap_to - 0.001:
			_pier_at(p, b - a, p.y - 0.33, false)
		else:
			_pier_at(p, b - a, IslandShape.SEA_LEVEL + 1.4, true)  # a broken stump
	var edge := a.lerp(b, gap_to)
	_span(edge, b)
	_end_posts(a, b - a)
	_end_posts(b, a - b)
	# Broken planks hang down from both edges of the gap.
	for hinge in [[a + flat * 0.4, flat], [edge, -flat]]:
		var at: Vector3 = hinge[0]
		var out: Vector3 = hinge[1]
		var droop := (out * cos(deg_to_rad(38.0)) + Vector3.DOWN * sin(deg_to_rad(38.0))).normalized()
		var deck := Basis.looking_at(droop, Vector3.UP)
		for k in 4:
			var twist := Basis(droop, _rng.randf_range(-0.25, 0.25))
			_box(Transform3D(twist * deck, at + droop * (0.25 + k * 0.45) + side * _rng.randf_range(-0.3, 0.3)), Vector3(DECK_WIDTH * _rng.randf_range(0.5, 1.0), 0.09, 0.42), PLANK_COLOR.darkened(_rng.randf_range(0.0, 0.25)))
		_box(Transform3D(deck, at + droop * 1.0 + side * (DECK_WIDTH * 0.5 - 0.2)), Vector3(0.22, 0.28, 2.0), BEAM_COLOR)
	_commit("BrokenBridge")
	# Boulders from the cliff block the way onto what's left, at both ends.
	_rock(BOULDER, a - flat * 0.6 + side * 0.9, 2.3, true)
	_rock(BOULDER, a - flat * 1.0 - side * 1.0, 1.9, true)
	_rock(MOSSY_ROCK, a - flat * 1.8 + side * 2.4, 1.4, true)
	_rock(BOULDER, b + flat * 0.6 - side * 0.8, 2.1, true)
	_rock(MOSSY_ROCK, b + flat * 1.0 + side * 1.1, 1.6, true)
	for end: Vector3 in [a, b]:
		var into := flat if end == a else -flat
		_wall(end + into * 0.3 + Vector3.UP * 0.9, side, Vector3(DECK_WIDTH + 1.6, 3.2, 0.6))


func _build_rockfall(a: Vector3, b: Vector3) -> void:
	var shape := IslandShape.shared()
	var flat := Vector2(b.x - a.x, b.z - a.z).normalized()
	var along_cliff := Vector2(-flat.y, flat.x)
	var start := Vector2(to_global(a).x, to_global(a).z)
	# The cliff gave way beside the bridge on the main island's side: boulders lie along
	# the cliff top, and more in the sea at its foot.
	for k in 9:
		var p := start + along_cliff * ((k - 4) * 2.4 + _rng.randf_range(-0.6, 0.6)) - flat * _rng.randf_range(1.0, 4.0)
		if absf((p - start).dot(along_cliff)) < 2.4:
			continue  # keep the bridge's own end clear
		_rock(BOULDER if k % 3 != 1 else MOSSY_ROCK, _world_ground(p), _rng.randf_range(1.0, 2.2), true)
	for k in 8:
		var p := start + flat * _rng.randf_range(5.0, 14.0) + along_cliff * _rng.randf_range(-9.0, 9.0)
		if shape.get_height(p.x, p.y) < IslandShape.SEA_LEVEL - 1.0:
			_rock(BOULDER if k % 2 == 0 else MOSSY_ROCK, _world_ground(p), _rng.randf_range(5.0, 7.5), false)


func _world_ground(p: Vector2) -> Vector3:
	return to_local(Vector3(p.x, IslandShape.shared().get_height(p.x, p.y), p.y))


## One mossy stone pier from the sea floor up to `top` (local height).
func _pier_at(p: Vector3, along: Vector3, top: float, ruined: bool) -> void:
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	var world := to_global(p)
	var bottom := IslandShape.shared().get_height(world.x, world.z) - 0.5
	var basis := Basis.looking_at(flat, Vector3.UP)
	if ruined:
		basis = Basis(flat, deg_to_rad(9.0)) * basis
	# Wet and dark below the tide line, grey stone above, moss on the cap.
	var wet_top := minf(IslandShape.SEA_LEVEL + 0.6, top)
	_box(Transform3D(basis, Vector3(p.x, (bottom + wet_top) * 0.5, p.z)), Vector3(DECK_WIDTH + 1.5, wet_top - bottom, 2.6), WET_STONE_COLOR)
	# Above the water: courses of dressed stone, each a little narrower than the last,
	# with moss in the joints of the lower ones.
	var courses := maxi(int((top - wet_top) / 2.2), 1)
	var course_height := (top - wet_top) / courses
	for c in courses:
		var t := float(c) / courses
		var y0 := wet_top + c * course_height
		var size := Vector3(lerpf(DECK_WIDTH + 1.3, DECK_WIDTH + 0.55, t), course_height - 0.06, lerpf(2.4, 1.6, t))
		var shade := STONE_COLOR.darkened(_rng.randf_range(0.0, 0.14)) if c % 2 == 0 else STONE_COLOR.lightened(_rng.randf_range(0.0, 0.08))
		_box(Transform3D(basis, Vector3(p.x, y0 + course_height * 0.5, p.z)), size, shade)
		if c < courses - 1 and _rng.randf() < 0.6:
			_box(Transform3D(basis, Vector3(p.x, y0 + course_height, p.z)), Vector3(size.x + 0.08, 0.12, size.z + 0.08), MOSS_COLOR.darkened(0.15))
	_box(Transform3D(basis, Vector3(p.x, top - 0.08, p.z)), Vector3(DECK_WIDTH + 0.75, 0.25, 1.85), MOSS_COLOR)
	if _body:
		var box := BoxShape3D.new()
		box.size = Vector3(DECK_WIDTH + 0.9, top - bottom, 2.0)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.transform = Transform3D(basis, Vector3(p.x, (bottom + top) * 0.5, p.z))
		_body.add_child(shape)


## Deck, beams, posts and handrails from `start` to `end`, with collision.
func _span(start: Vector3, end: Vector3) -> void:
	var span := end - start
	var length := span.length()
	var dir := span / length
	var deck := Basis.looking_at(dir, Vector3.UP)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var planks := maxi(int(length / 0.5), 1)
	for i in planks:
		var t := (i + 0.5) / planks * length
		var jitter := Basis(Vector3.UP, _rng.randf_range(-0.04, 0.04))
		_box(Transform3D(deck * jitter, start + dir * t + Vector3.UP * _rng.randf_range(-0.015, 0.015)), Vector3(DECK_WIDTH, 0.09, 0.44), PLANK_COLOR.lerp(BEAM_COLOR, _rng.randf_range(0.0, 0.35)))
	for s: float in [-1.0, 1.0]:
		var edge := side * s * (DECK_WIDTH * 0.5 - 0.2)
		_box(Transform3D(deck, start + dir * length * 0.5 + edge + Vector3.DOWN * 0.19), Vector3(0.22, 0.28, length), BEAM_COLOR)
		var rail_edge := side * s * (DECK_WIDTH * 0.5 + 0.02)
		var posts := maxi(int(length / 2.2), 1)
		for i in posts + 1:
			var p := start + dir * (float(i) / posts * length) + rail_edge
			_box(Transform3D(Basis(), p + Vector3.UP * RAIL_HEIGHT * 0.5), Vector3(0.13, RAIL_HEIGHT + 0.12, 0.13), POST_COLOR)
		_box(Transform3D(deck, start + dir * length * 0.5 + rail_edge + Vector3.UP * RAIL_HEIGHT), Vector3(0.09, 0.09, length), BEAM_COLOR)
		_box(Transform3D(deck, start + dir * length * 0.5 + rail_edge + Vector3.UP * RAIL_HEIGHT * 0.5), Vector3(0.06, 0.06, length), BEAM_COLOR)
	_wall(start + dir * length * 0.5 + Vector3.DOWN * 0.1, side, Vector3(DECK_WIDTH, 0.3, length), deck)
	for s: float in [-1.0, 1.0]:
		_wall(start + dir * length * 0.5 + side * s * (DECK_WIDTH * 0.5 + 0.05) + Vector3.UP * 0.6, side, Vector3(0.15, 1.3, length), deck)


## Stout posts where the bridge meets the cliff top, sunk into the ground.
func _end_posts(at: Vector3, toward: Vector3) -> void:
	var flat := Vector3(toward.x, 0.0, toward.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	for s: float in [-1.0, 1.0]:
		var p := at + side * s * (DECK_WIDTH * 0.5 + 0.12) - flat * 0.2
		_box(Transform3D(Basis(), p + Vector3.UP * 0.35), Vector3(0.24, 2.4, 0.24), POST_COLOR)


func _rock(model: PackedScene, at: Vector3, size: float, collide: bool) -> void:
	var rock := FittedModel.new()
	rock.model = model
	rock.size = size
	rock.collision = FittedModel.Collision.BOX if collide and not Engine.is_editor_hint() else FittedModel.Collision.NONE
	rock.position = at
	rock.rotation.y = _rng.randf() * TAU
	add_child(rock)


func _wall(center: Vector3, side: Vector3, size: Vector3, basis: Basis = Basis()) -> void:
	if _body == null:
		return
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	if basis == Basis():
		basis = Basis.looking_at(Vector3.UP.cross(side).normalized(), Vector3.UP)
	shape.transform = Transform3D(basis, center)
	_body.add_child(shape)


func _begin() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _box(xform: Transform3D, size: Vector3, color: Color) -> void:
	var cube := BoxMesh.new()
	cube.size = size
	var data := cube.get_mesh_arrays()
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	for index in indices:
		_st.set_color(color)
		_st.set_normal((xform.basis * normals[index]).normalized())
		_st.add_vertex(xform * verts[index])


func _commit(mesh_name: String) -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = _st.commit()
	mesh_instance.material_override = material
	add_child(mesh_instance)
