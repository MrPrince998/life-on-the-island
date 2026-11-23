class_name CropVisuals
extends RefCounted
## Builds the stylized crop, soil-bed and watering-can meshes in code, until hand-made
## models exist (CropData.stage_models replaces the crop meshes when set).
## Meshes are cached, so every bed shares the same few meshes.
##
## Each mesh uses vertex colours with soft, warm, slightly varied tones to sit with the
## hand-painted Tripo models.

const LEAF := Color(0.42, 0.66, 0.29)
const LEAF_DARK := Color(0.30, 0.52, 0.22)
const LEAF_LIGHT := Color(0.56, 0.76, 0.36)
const SOIL_MOUND := Color(0.33, 0.22, 0.14)
const TURNIP_WHITE := Color(0.96, 0.93, 0.85)
const TURNIP_PURPLE := Color(0.58, 0.32, 0.62)
const CARROT_ORANGE := Color(0.95, 0.52, 0.18)
const TOMATO_RED := Color(0.88, 0.25, 0.18)
const TOMATO_GREEN := Color(0.55, 0.72, 0.3)
const PUMPKIN := Color(0.95, 0.55, 0.16)
const KALE := Color(0.24, 0.46, 0.3)
const KALE_LIGHT := Color(0.42, 0.6, 0.42)
const PETAL := Color(0.98, 0.78, 0.22)
const PETAL_DEEP := Color(0.95, 0.66, 0.15)
const SEED_HEAD := Color(0.38, 0.24, 0.13)
const WOOD := Color(0.55, 0.37, 0.22)
const WOOD_LIGHT := Color(0.66, 0.47, 0.29)
const TIN := Color(0.47, 0.63, 0.61)
const TIN_DARK := Color(0.33, 0.47, 0.46)

static var _cache: Dictionary = {}
static var _plant_material: StandardMaterial3D
static var _soil_materials: Dictionary = {}


## Material for every mesh built here (vertex colours, soft and matte, two-sided leaves).
static func plant_material() -> StandardMaterial3D:
	if _plant_material == null:
		_plant_material = StandardMaterial3D.new()
		_plant_material.vertex_color_use_as_albedo = true
		# Colours below are written as sRGB, like a painter's palette.
		_plant_material.vertex_color_is_srgb = true
		_plant_material.roughness = 0.85
		_plant_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _plant_material


## Soil material: "wild" (overgrown, dry), "dry" (dug) or "damp" (watered).
static func soil_material(kind: StringName) -> StandardMaterial3D:
	if _soil_materials.has(kind):
		return _soil_materials[kind]
	var colors: Array
	match kind:
		&"damp":
			colors = [Color(0.17, 0.11, 0.07), Color(0.24, 0.16, 0.10), Color(0.30, 0.20, 0.13)]
		&"wild":
			colors = [Color(0.40, 0.31, 0.20), Color(0.47, 0.37, 0.25), Color(0.52, 0.44, 0.30)]
		_:
			colors = [Color(0.34, 0.23, 0.14), Color(0.43, 0.30, 0.19), Color(0.50, 0.36, 0.23)]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray(colors)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = gradient
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.75 if kind == &"damp" else 1.0
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	_soil_materials[kind] = material
	return material


## Mesh for one plant of this crop at this stage.
static func crop_mesh(look: StringName, stage: int) -> Mesh:
	var key := "%s_%d" % [look, stage]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	if stage == CropData.Stage.SEED:
		_seed_mound(st)
	else:
		match look:
			&"carrot":
				_carrot(st, stage)
			&"sunflower":
				_sunflower(st, stage)
			&"tomato":
				_tomato(st, stage)
			&"pumpkin":
				_pumpkin(st, stage)
			&"kale":
				_kale(st, stage)
			_:
				_turnip(st, stage)
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Low raised ridge of dug soil (lies along Z, 1 m long before scaling).
static func ridge_mesh() -> Mesh:
	if _cache.has("ridge"):
		return _cache["ridge"]
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.17
	capsule.height = 1.0
	capsule.radial_segments = 12
	capsule.rings = 4
	var arrays := capsule.get_mesh_arrays()
	var mesh := ArrayMesh.new()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Lay the capsule along Z, then flatten it into a low mound.
	var xf := Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 1.0)) * Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var normal_basis := xf.basis.inverse().transposed()
	for i in verts.size():
		verts[i] = xf * verts[i]
		normals[i] = (normal_basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["ridge"] = mesh
	return mesh


## Wooden border around a bed `size` metres square.
static func bed_border_mesh(size: float) -> Mesh:
	var key := "border_%.2f" % size
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var half := size * 0.5
	var plank_h := 0.14
	var plank_w := 0.12
	for i in 4:
		var along_x := i < 2
		var sign_ := -1.0 if i % 2 == 0 else 1.0
		var box := BoxMesh.new()
		box.size = Vector3(size + plank_w if along_x else plank_w, plank_h, plank_w if along_x else size - plank_w)
		var pos := Vector3(0.0, plank_h * 0.5, sign_ * half) if along_x else Vector3(sign_ * half, plank_h * 0.5, 0.0)
		_add(st, box, Transform3D(Basis(), pos), WOOD if i % 3 == 0 else WOOD_LIGHT)
	# Corner posts.
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var post := BoxMesh.new()
		post.size = Vector3(0.16, 0.2, 0.16)
		_add(st, post, Transform3D(Basis(), Vector3(corner.x * half, 0.1, corner.y * half)), WOOD)
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Overgrown bed: a few grass tufts, weeds and pebbles (one mesh for the whole bed).
static func weeds_mesh(size: float, seed_value: int) -> Mesh:
	var key := "weeds_%.2f_%d" % [size, seed_value % 4]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value % 4 + 11
	var st := _begin()
	var half := size * 0.5 - 0.2
	for i in 9:
		var p := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		var blades := rng.randi_range(4, 7)
		for b in blades:
			var yaw := TAU * b / blades + rng.randf() * 0.5
			var tilt := rng.randf_range(0.25, 0.55)
			var len_ := rng.randf_range(0.14, 0.26)
			_leaf(st, p, yaw, tilt, len_, 0.035, LEAF_DARK.lerp(LEAF_LIGHT, rng.randf()))
	for i in 3:
		var pebble := SphereMesh.new()
		pebble.radius = 0.06
		pebble.height = 0.08
		pebble.radial_segments = 8
		pebble.rings = 4
		var p := Vector3(rng.randf_range(-half, half), 0.01, rng.randf_range(-half, half))
		_add(st, pebble, Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 0.85)), p), Color(0.62, 0.6, 0.55))
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## Pale specks of fertilizer scattered over a bed.
static func fertilizer_mesh(size: float) -> Mesh:
	var key := "fert_%.2f" % size
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var st := _begin()
	var half := size * 0.5 - 0.15
	for i in 70:
		var speck := SphereMesh.new()
		speck.radius = 0.018
		speck.height = 0.022
		speck.radial_segments = 6
		speck.rings = 3
		var p := Vector3(rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))
		_add(st, speck, Transform3D(Basis(), p), Color(0.86, 0.8, 0.62) if i % 3 else Color(0.6, 0.5, 0.36))
	var mesh := _finish(st)
	_cache[key] = mesh
	return mesh


## A small burlap sack of fertilizer (origin at its base).
static func sack_mesh() -> Mesh:
	if _cache.has("sack"):
		return _cache["sack"]
	var st := _begin()
	var body := SphereMesh.new()
	body.radius = 0.2
	body.height = 0.4
	body.radial_segments = 12
	body.rings = 6
	_add(st, body, Transform3D(Basis.from_scale(Vector3(1.0, 1.05, 0.8)), Vector3(0, 0.19, 0)), Color(0.72, 0.58, 0.38))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.07
	neck.bottom_radius = 0.05
	neck.height = 0.1
	neck.radial_segments = 8
	_add(st, neck, Transform3D(Basis(), Vector3(0, 0.42, 0)), Color(0.66, 0.52, 0.33))
	var tie := TorusMesh.new()
	tie.inner_radius = 0.045
	tie.outer_radius = 0.06
	tie.rings = 10
	tie.ring_segments = 5
	_add(st, tie, Transform3D(Basis(), Vector3(0, 0.39, 0)), Color(0.42, 0.62, 0.32))
	var mesh := _finish(st)
	_cache["sack"] = mesh
	return mesh


## A wooden seedling tray with little green sprouts (origin at its base).
static func seed_tray_mesh() -> Mesh:
	if _cache.has("tray"):
		return _cache["tray"]
	var st := _begin()
	var tray := BoxMesh.new()
	tray.size = Vector3(0.5, 0.09, 0.34)
	_add(st, tray, Transform3D(Basis(), Vector3(0, 0.045, 0)), WOOD_LIGHT)
	var soil := BoxMesh.new()
	soil.size = Vector3(0.44, 0.02, 0.28)
	_add(st, soil, Transform3D(Basis(), Vector3(0, 0.09, 0)), SOIL_MOUND)
	for x in 4:
		for z in 3:
			var base := Vector3(-0.165 + x * 0.11, 0.1, -0.1 + z * 0.1)
			_leaf(st, base, 0.3 + x, 0.5, 0.05, 0.03, LEAF_LIGHT)
			_leaf(st, base, 3.4 + x, 0.5, 0.05, 0.03, LEAF)
	var mesh := _finish(st)
	_cache["tray"] = mesh
	return mesh


## A small tin watering can. Origin = where the hand holds the top handle;
## the spout points along -Z (forward).
static func watering_can_mesh() -> Mesh:
	if _cache.has("can"):
		return _cache["can"]
	var st := _begin()
	var body := CylinderMesh.new()
	body.top_radius = 0.085
	body.bottom_radius = 0.095
	body.height = 0.17
	body.radial_segments = 16
	_add(st, body, Transform3D(Basis(), Vector3(0, -0.16, 0.02)), TIN)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.07
	rim.bottom_radius = 0.087
	rim.height = 0.03
	rim.radial_segments = 16
	_add(st, rim, Transform3D(Basis(), Vector3(0, -0.06, 0.02)), TIN_DARK)
	# Spout: leans forward and up from the lower front of the body.
	var spout := CylinderMesh.new()
	spout.top_radius = 0.014
	spout.bottom_radius = 0.022
	spout.height = 0.24
	spout.radial_segments = 8
	var spout_basis := Basis(Vector3.RIGHT, -0.85)
	_add(st, spout, Transform3D(spout_basis, Vector3(0, -0.13, -0.15)), TIN)
	var rose := CylinderMesh.new()
	rose.top_radius = 0.035
	rose.bottom_radius = 0.016
	rose.height = 0.04
	rose.radial_segments = 10
	_add(st, rose, Transform3D(spout_basis, Vector3(0, -0.04, -0.245)), TIN_DARK)
	# Handle: an arch over the top, from front to back.
	var handle := TorusMesh.new()
	handle.inner_radius = 0.075
	handle.outer_radius = 0.095
	handle.rings = 16
	handle.ring_segments = 6
	_add(st, handle, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).scaled(Vector3(1, 1, 1)), Vector3(0, -0.06, 0.04)), TIN_DARK)
	var mesh := _finish(st)
	_cache["can"] = mesh
	return mesh


## Where water leaves the can's spout, in the can mesh's space.
static func watering_can_spout_tip() -> Vector3:
	return Vector3(0, -0.03, -0.26)


# ---- Crops ------------------------------------------------------------------

static func _seed_mound(st: SurfaceTool) -> void:
	var mound := SphereMesh.new()
	mound.radius = 0.09
	mound.height = 0.06
	mound.radial_segments = 10
	mound.rings = 5
	_add(st, mound, Transform3D(Basis(), Vector3(0, 0.01, 0)), SOIL_MOUND)
	# A hint of a seedling poking out.
	_leaf(st, Vector3(0, 0.03, 0), 0.4, 0.25, 0.035, 0.02, LEAF_LIGHT)


static func _turnip(st: SurfaceTool, stage: int) -> void:
	var leaves := 2
	var length := 0.09
	var bulb := 0.0
	match stage:
		CropData.Stage.GROWING:
			leaves = 5
			length = 0.17
			bulb = 0.05
		CropData.Stage.READY:
			leaves = 6
			length = 0.24
			bulb = 0.095
	for i in leaves:
		var yaw := TAU * i / leaves + 0.3
		var color := LEAF if i % 2 == 0 else LEAF_DARK
		_leaf(st, Vector3(0, bulb * 0.9, 0), yaw, 0.55 if stage == CropData.Stage.SPROUT else 0.75, length, length * 0.42, color)
	if bulb > 0.0:
		var white := SphereMesh.new()
		white.radius = bulb
		white.height = bulb * 2.0
		white.radial_segments = 12
		white.rings = 6
		_add(st, white, Transform3D(Basis(), Vector3(0, bulb * 0.35, 0)), TURNIP_WHITE)
		var cap := SphereMesh.new()
		cap.radius = bulb * 1.03
		cap.height = bulb * 1.03
		cap.is_hemisphere = true
		cap.radial_segments = 12
		cap.rings = 4
		_add(st, cap, Transform3D(Basis.from_scale(Vector3(1, 0.9, 1)), Vector3(0, bulb * 0.45, 0)), TURNIP_PURPLE)


static func _carrot(st: SurfaceTool, stage: int) -> void:
	var fronds := 3
	var length := 0.1
	var shoulder := 0.0
	match stage:
		CropData.Stage.GROWING:
			fronds = 6
			length = 0.2
			shoulder = 0.03
		CropData.Stage.READY:
			fronds = 8
			length = 0.3
			shoulder = 0.05
	for i in fronds:
		var yaw := TAU * i / fronds + 0.2
		_frond(st, Vector3(0, shoulder, 0), yaw, 0.35 + 0.1 * (i % 3), length, LEAF if i % 2 == 0 else LEAF_LIGHT)
	if shoulder > 0.0:
		var top := CylinderMesh.new()
		top.top_radius = shoulder * 0.8
		top.bottom_radius = shoulder
		top.height = shoulder * 1.2
		top.radial_segments = 10
		_add(st, top, Transform3D(Basis(), Vector3(0, shoulder * 0.4, 0)), CARROT_ORANGE)


static func _sunflower(st: SurfaceTool, stage: int) -> void:
	if stage == CropData.Stage.SPROUT:
		for i in 2:
			_leaf(st, Vector3(0, 0.06, 0), PI * i + 0.4, 0.35, 0.1, 0.07, LEAF_LIGHT)
		var sprout_stem := CylinderMesh.new()
		sprout_stem.top_radius = 0.008
		sprout_stem.bottom_radius = 0.012
		sprout_stem.height = 0.07
		sprout_stem.radial_segments = 6
		_add(st, sprout_stem, Transform3D(Basis(), Vector3(0, 0.035, 0)), LEAF_DARK)
		return
	var ready := stage == CropData.Stage.READY
	var height := 1.45 if ready else 0.6
	var stem := CylinderMesh.new()
	stem.top_radius = 0.02 if ready else 0.014
	stem.bottom_radius = 0.032 if ready else 0.02
	stem.height = height
	stem.radial_segments = 8
	_add(st, stem, Transform3D(Basis(), Vector3(0, height * 0.5, 0)), LEAF_DARK)
	var leaf_pairs := 3 if ready else 2
	for i in leaf_pairs:
		var y := height * (0.25 + 0.22 * i)
		var size := (0.26 if ready else 0.16) * (1.0 - 0.15 * i)
		for side in 2:
			_leaf(st, Vector3(0, y, 0), PI * side + i * 1.1, 0.45, size, size * 0.7, LEAF if side == 0 else LEAF_DARK)
	if not ready:
		var bud := SphereMesh.new()
		bud.radius = 0.05
		bud.height = 0.09
		bud.radial_segments = 10
		bud.rings = 5
		_add(st, bud, Transform3D(Basis(), Vector3(0, height + 0.02, 0)), LEAF_LIGHT)
		return
	# Flower head, tilted to face forward (+Z) and a little up.
	var head_basis := Basis(Vector3.RIGHT, PI * 0.5 - 0.35)
	var head_pos := Vector3(0, height + 0.04, 0.05)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.13
	disc.bottom_radius = 0.12
	disc.height = 0.05
	disc.radial_segments = 16
	_add(st, disc, Transform3D(head_basis, head_pos), SEED_HEAD)
	var petals := 16
	for i in petals:
		var angle := TAU * i / petals
		var petal := SphereMesh.new()
		petal.radius = 0.05
		petal.height = 0.1
		petal.radial_segments = 8
		petal.rings = 4
		var local := Vector3(cos(angle) * 0.19, 0.0, sin(angle) * 0.19)
		var petal_basis := head_basis * Basis(Vector3.UP, -angle) * Basis.from_scale(Vector3(1.55, 0.3, 0.75))
		_add(st, petal, Transform3D(petal_basis, head_pos + head_basis * local), PETAL if i % 2 == 0 else PETAL_DEEP)


static func _tomato(st: SurfaceTool, stage: int) -> void:
	var height := 0.12 if stage == CropData.Stage.SPROUT else (0.32 if stage == CropData.Stage.GROWING else 0.45)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.008
	stem.bottom_radius = 0.014
	stem.height = height
	stem.radial_segments = 6
	_add(st, stem, Transform3D(Basis(), Vector3(0, height * 0.5, 0)), LEAF_DARK)
	var tiers := 1 if stage == CropData.Stage.SPROUT else 3
	for t in tiers:
		var y := height * (0.35 + 0.25 * t)
		for k in 4:
			_leaf(st, Vector3(0, y, 0), TAU * k / 4.0 + t * 0.7, 0.35, 0.09 + 0.02 * t, 0.05, LEAF if k % 2 == 0 else LEAF_DARK)
	if stage < CropData.Stage.GROWING:
		return
	var ripe := stage == CropData.Stage.READY
	for i in 4:
		var fruit := SphereMesh.new()
		fruit.radius = 0.04 if ripe else 0.028
		fruit.height = fruit.radius * 1.8
		fruit.radial_segments = 10
		fruit.rings = 5
		var angle := TAU * i / 4.0 + 0.4
		_add(st, fruit, Transform3D(Basis(), Vector3(cos(angle) * 0.07, height * (0.35 + 0.12 * (i % 2)), sin(angle) * 0.07)), TOMATO_RED if ripe else TOMATO_GREEN)


static func _pumpkin(st: SurfaceTool, stage: int) -> void:
	var leaves := 3 if stage == CropData.Stage.SPROUT else 6
	var size := 0.1 if stage == CropData.Stage.SPROUT else 0.2
	for i in leaves:
		_leaf(st, Vector3(0, 0.03, 0), TAU * i / leaves + 0.3, 0.2, size, size * 0.85, LEAF if i % 2 == 0 else LEAF_DARK)
	if stage < CropData.Stage.GROWING:
		return
	var ripe := stage == CropData.Stage.READY
	var r := 0.17 if ripe else 0.08
	# Ribbed body: a few squashed spheres side by side.
	for k in 5:
		var lobe := SphereMesh.new()
		lobe.radius = r * 0.62
		lobe.height = r * 1.2
		lobe.radial_segments = 12
		lobe.rings = 6
		var a := TAU * k / 5.0
		_add(st, lobe, Transform3D(Basis(), Vector3(0.12 + cos(a) * r * 0.42, r * 0.55, sin(a) * r * 0.42)), PUMPKIN if ripe else LEAF_LIGHT)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.012
	stalk.bottom_radius = 0.018
	stalk.height = 0.06
	stalk.radial_segments = 6
	_add(st, stalk, Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(0.12, r * 1.15, 0)), Color(0.4, 0.3, 0.16))


static func _kale(st: SurfaceTool, stage: int) -> void:
	var count := 3 if stage == CropData.Stage.SPROUT else (6 if stage == CropData.Stage.GROWING else 9)
	var length := 0.08 if stage == CropData.Stage.SPROUT else (0.15 if stage == CropData.Stage.GROWING else 0.22)
	for i in count:
		var yaw := TAU * i / count + 0.25 * (i % 3)
		var tilt := 0.9 if i % 3 == 0 else 0.6
		_leaf(st, Vector3(0, 0.02 + 0.015 * (i % 3), 0), yaw, tilt, length * (1.0 - 0.15 * (i % 3)), length * 0.55, KALE if i % 2 == 0 else KALE_LIGHT)


# ---- Shape helpers -------------------------------------------------------------

## A soft pointed leaf from `base`, turned `yaw` around the stem and lifted `tilt`
## radians up from flat.
static func _leaf(st: SurfaceTool, base: Vector3, yaw: float, tilt: float, length: float, width: float, color: Color) -> void:
	var leaf := SphereMesh.new()
	leaf.radius = 0.5
	leaf.height = 1.0
	leaf.radial_segments = 8
	leaf.rings = 4
	var direction := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt)
	var xf := Transform3D(direction * Basis.from_scale(Vector3(width, 0.012 / 1.0 + width * 0.12, length)), base + direction * Vector3(0, 0, length * 0.5))
	_add(st, leaf, xf, color)


## A carrot frond: thin stem leaning `tilt` radians from upright, with three leaflets.
static func _frond(st: SurfaceTool, base: Vector3, yaw: float, tilt: float, length: float, color: Color) -> void:
	var direction := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.004
	stem.bottom_radius = 0.007
	stem.height = 1.0
	stem.radial_segments = 5
	_add(st, stem, Transform3D(direction * Basis.from_scale(Vector3(1, length, 1)), base + direction * Vector3(0, length * 0.5, 0)), LEAF_DARK)
	for k in 3:
		var t := 0.45 + 0.25 * k
		var point := base + direction * Vector3(0, length * t, 0)
		_leaf(st, point, yaw + (k - 1) * 0.9, tilt + 0.3, length * 0.32, length * 0.16, color)


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _finish(st: SurfaceTool) -> Mesh:
	var mesh := st.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, plant_material())
	return mesh


## Adds a primitive's triangles, transformed and painted one colour (with a soft
## top-to-bottom shade so shapes don't look flat).
static func _add(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xf.basis.inverse().transposed()
	var aabb := prim.get_aabb()
	for i in indices:
		var v := verts[i]
		var shade := 0.85 + 0.15 * clampf((v.y - aabb.position.y) / maxf(aabb.size.y, 0.0001), 0.0, 1.0)
		st.set_color(Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
		st.set_normal((normal_basis * normals[i]).normalized())
		st.add_vertex(xf * v)
