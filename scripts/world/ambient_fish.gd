class_name AmbientFish
extends Node3D
## Fish you can see swimming just under the water. Purely decoration: they don't affect
## fishing, never use time, and are not saved.
##
## Spawned by each WaterBody (see water_body.gd). Species come from the fish catalog:
## fish whose water_ids include this water, that have a model and whose hours include
## the current time. Fish swim in small schools that wander slowly, wiggle as they swim
## and only go where the water is deep enough.
##
## Bounded water (the lake) keeps its schools inside. Unbounded water (the sea) keeps its
## schools near the player (or the camera, on the title screen), moving schools that fall
## far behind to new spots ahead, so the whole coast feels alive without thousands of fish.
## Each species is drawn as one MultiMesh, so the cost is a few draw calls.

const CATALOG := preload("res://data/fish/fish_catalog.tres")

## Which water this is ("moonlit_lake", "sea").
var water_id: StringName = &""
## Water surface height (world y).
var surface: float = 0.0
## Bounded water: centre and radius on the map. Radius 0 = unbounded (follow the viewer).
var area_center := Vector2.ZERO
var area_radius: float = 0.0
var school_count: int = 5
var fish_per_school := Vector2i(3, 5)
## How far below the surface fish swim (metres), and the least water depth they need.
var swim_depth := Vector2(0.35, 0.7)
var min_water_depth: float = 1.0
## Fish are hidden beyond this distance from the camera (metres).
var visible_distance: float = 70.0
## Unbounded water: schools stay between these distances from the viewer.
var follow_near: float = 18.0
var follow_far: float = 75.0
## Ambient fish are drawn a little bigger than life so they read through the water.
const SIZE_BOOST := 1.6
const MIN_LENGTH := 0.2

var _shape: IslandShape
var _rng := RandomNumberGenerator.new()
## species id -> {"mmi": MultiMeshInstance3D, "fish": Array of fish indices}
var _species_draw: Dictionary = {}
## Each school: {"center": Vector3, "target": Vector3, "speed": float, "species": StringName, "members": Array}
var _schools: Array[Dictionary] = []
## Each fish: {"school": int, "offset": Vector3, "pos": Vector3, "yaw": float, "phase": float, "scale": float}
var _fish: Array[Dictionary] = []
var _time: float = 0.0
var _spawn_timer: float = 0.0


func setup(water: StringName, surface_y: float, center: Vector2, radius: float) -> void:
	water_id = water
	surface = surface_y
	area_center = center
	area_radius = radius


func _ready() -> void:
	_rng.seed = hash(String(water_id)) ^ 0x51F15
	_shape = IslandShape.shared()
	top_level = true
	global_transform = Transform3D.IDENTITY
	# Wait a frame: the main scene moves the player to the spawn point after the island loads.
	_spawn_missing.call_deferred()
	ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _refresh_species())


func get_fish_count() -> int:
	return _fish.size()


## World positions of every fish (for tests).
func get_fish_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for f in _fish:
		out.append(f.pos)
	return out


# ---- Schools --------------------------------------------------------------------

## Adds schools until there are school_count (the sea may have none in view inland).
func _spawn_missing() -> void:
	var viewer := _viewer_xz()
	var tries := school_count - _schools.size()
	for i in tries:
		var start := _find_spot(viewer, true)
		if start != Vector3.INF:
			_add_school(start)

func _add_school(start: Vector3) -> void:
	var species := _pick_species()
	if species == null:
		return
	var school := {"center": start, "target": start, "speed": _rng.randf_range(0.5, 1.1), "species": species.id, "members": []}
	var index := _schools.size()
	_schools.append(school)
	var count := _rng.randi_range(fish_per_school.x, fish_per_school.y)
	if species.max_size_cm > 80.0:
		count = 1  # big fish (mantas) swim alone
	for i in count:
		var length := maxf(lerpf(species.min_size_cm, species.max_size_cm, _rng.randf()) / 100.0 * SIZE_BOOST, MIN_LENGTH)
		var offset := Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-1.2, 1.2)) * clampf(length * 3.0, 1.0, 2.5)
		var fish := {"school": index, "offset": offset, "pos": start + offset, "yaw": _rng.randf() * TAU, "phase": _rng.randf() * TAU, "scale": length}
		(school.members as Array).append(_fish.size())
		_fish.append(fish)
	_assign_draw(school)


func _pick_species() -> FishData:
	var hour := ActivityClock.get_hour()
	var options: Array[FishData] = []
	for fish: FishData in CATALOG.fish:
		if fish.model == null or not fish.water_ids.has(String(water_id)):
			continue
		var awake := fish.start_hour <= hour and hour < fish.end_hour if fish.start_hour <= fish.end_hour else (hour >= fish.start_hour or hour < fish.end_hour)
		if awake:
			options.append(fish)
	if options.is_empty():
		return null
	return options[_rng.randi() % options.size()]


## When the hour changes, a school whose species has gone to sleep switches to one that is awake.
func _refresh_species() -> void:
	var hour := ActivityClock.get_hour()
	for school in _schools:
		var fish := CATALOG.get_fish(school.species)
		if fish == null:
			continue
		var awake := fish.start_hour <= hour and hour < fish.end_hour if fish.start_hour <= fish.end_hour else (hour >= fish.start_hour or hour < fish.end_hour)
		if not awake:
			var replacement := _pick_species()
			if replacement:
				school.species = replacement.id
	_rebuild_draws()


# ---- Where fish can swim ----------------------------------------------------------

func _viewer_xz() -> Vector2:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if player:
		return Vector2(player.global_position.x, player.global_position.z)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		return Vector2(cam.global_position.x, cam.global_position.z)
	return area_center


func _is_swimmable(xz: Vector2) -> bool:
	if area_radius > 0.0 and xz.distance_to(area_center) > area_radius:
		return false
	return _shape.get_height(xz.x, xz.y) < surface - min_water_depth


## A random swimmable spot: inside the lake, or (for the sea) at a comfortable distance
## from the viewer. Vector3.INF when nothing was found.
func _find_spot(viewer: Vector2, anywhere: bool) -> Vector3:
	for attempt in 40:
		var xz: Vector2
		if area_radius > 0.0:
			xz = area_center + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * area_radius
		else:
			var dist := _rng.randf_range(follow_near, follow_far) if anywhere else _rng.randf_range(follow_near * 2.0, follow_far)
			xz = viewer + Vector2.from_angle(_rng.randf() * TAU) * dist
		if _is_swimmable(xz):
			return Vector3(xz.x, surface - _rng.randf_range(swim_depth.x, swim_depth.y), xz.y)
	return Vector3.INF


func _new_target(school: Dictionary) -> Vector3:
	var c: Vector3 = school.center
	for attempt in 12:
		var xz := Vector2(c.x, c.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, 12.0)
		if _is_swimmable(xz):
			return Vector3(xz.x, surface - _rng.randf_range(swim_depth.x, swim_depth.y), xz.y)
	return c


# ---- Movement ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var viewer := _viewer_xz()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.5
		if _schools.size() < school_count:
			_spawn_missing()
	for i in _schools.size():
		var school := _schools[i]
		var center: Vector3 = school.center
		# Sea schools left far behind move to a new spot near the viewer.
		if area_radius <= 0.0 and Vector2(center.x, center.z).distance_to(viewer) > follow_far * 1.3:
			var spot := _find_spot(viewer, false)
			if spot != Vector3.INF:
				var shift: Vector3 = spot - center
				school.center = spot
				school.target = spot
				for m in school.members:
					_fish[m].pos += shift
				continue
		var to_target: Vector3 = (school.target as Vector3) - center
		if to_target.length() < 0.8:
			school.target = _new_target(school)
			school.speed = _rng.randf_range(0.5, 1.1)
		else:
			var step := to_target.normalized() * float(school.speed) * delta
			var next := center + step
			if _is_swimmable(Vector2(next.x, next.z)):
				school.center = next
			else:
				school.target = _new_target(school)
	for f in _fish:
		var school := _schools[f.school]
		var goal: Vector3 = (school.center as Vector3) + (f.offset as Vector3)
		var pos: Vector3 = f.pos
		var move := goal - pos
		var speed := clampf(move.length() * 1.5, 0.0, float(school.speed) * 1.4)
		if move.length() > 0.02:
			pos += move.normalized() * speed * delta
			f.yaw = lerp_angle(f.yaw, atan2(-move.x, -move.z), 1.0 - exp(-4.0 * delta))
		f.pos = pos
	_update_draws()


# ---- Drawing (one MultiMesh per species) ----------------------------------------

func _assign_draw(_school: Dictionary) -> void:
	_rebuild_draws()


func _rebuild_draws() -> void:
	var by_species := {}
	for i in _fish.size():
		var sid: StringName = _schools[_fish[i].school].species
		if not by_species.has(sid):
			by_species[sid] = []
		by_species[sid].append(i)
	for sid in _species_draw.keys():
		if not by_species.has(sid):
			(_species_draw[sid].mmi as Node).queue_free()
			_species_draw.erase(sid)
	for sid in by_species:
		if not _species_draw.has(sid):
			var mmi := _make_draw(CATALOG.get_fish(sid))
			if mmi == null:
				continue
			_species_draw[sid] = {"mmi": mmi, "fish": []}
		var entry: Dictionary = _species_draw[sid]
		entry.fish = by_species[sid]
		(entry.mmi as MultiMeshInstance3D).multimesh.instance_count = (entry.fish as Array).size()
	_update_draws()


func _make_draw(fish: FishData) -> MultiMeshInstance3D:
	if fish == null or fish.model == null:
		return null
	var model := fish.model.instantiate() as Node3D
	var source := model.find_children("*", "MeshInstance3D", true, false)
	if source.is_empty():
		model.free()
		return null
	var mesh_instance := source[0] as MeshInstance3D
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_instance.mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fish_%s" % fish.id
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The fish are moved every frame in _process, so physics interpolation (which
	# smooths movement made in _physics_process) must stay off for them, or they jitter.
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mmi.visibility_range_end = visible_distance
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if mesh_instance.get_surface_override_material(0):
		mmi.material_override = mesh_instance.get_surface_override_material(0)
	# Centre the model and turn it so its head points along -Z (the swim direction).
	# FishData.model_yaw_degrees turns the head to +X; another 90 degrees takes it to -Z.
	var center := mesh_instance.get_aabb().get_center()
	var turn := Basis(Vector3.UP, deg_to_rad(fish.model_yaw_degrees + 90.0))
	mmi.set_meta(&"model_fix", Transform3D(turn, turn * -center))
	model.free()
	add_child(mmi)
	return mmi


func _update_draws() -> void:
	for sid in _species_draw:
		var entry: Dictionary = _species_draw[sid]
		var mmi := entry.mmi as MultiMeshInstance3D
		var fix: Transform3D = mmi.get_meta(&"model_fix")
		var members: Array = entry.fish
		for k in members.size():
			var f: Dictionary = _fish[members[k]]
			# Tail wiggle: a quick small sway, faster when the school is moving.
			var wiggle := sin(_time * 7.0 + float(f.phase)) * 0.12
			var bob := sin(_time * 1.3 + float(f.phase)) * 0.04
			var basis := Basis(Vector3.UP, float(f.yaw) + wiggle).scaled(Vector3.ONE * float(f.scale))
			mmi.multimesh.set_instance_transform(k, Transform3D(basis, (f.pos as Vector3) + Vector3(0, bob, 0)) * fix)
