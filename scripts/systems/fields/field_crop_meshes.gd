class_name FieldCropMeshes
extends RefCounted
## Builds the plant clumps for a field crop (rice) in code: a tuft of thin leaf blades,
## and at heading/ripe stages drooping grain heads (panicles). One mesh per stage, made
## once and shared by every clump in every row (drawn with MultiMesh).
## Until a modelled plant exists this gives a convincing stylized paddy.

enum Stage { SEEDLING, GROWING, HEADING, RIPE, STUBBLE }

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D


static func get_mesh(crop: FieldCropData, stage: int) -> Mesh:
	var key := "%s:%d" % [crop.id, stage]
	if not _cache.has(key):
		_cache[key] = _build(crop, stage)
	return _cache[key]


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# The colours are picked by eye (sRGB), like everything else in the game.
		_material.vertex_color_is_srgb = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.roughness = 0.85
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _material


static func _build(crop: FieldCropData, stage: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + stage
	var h := crop.height
	if crop.look == &"wheat":
		_build_wheat(st, rng, crop, stage)
		st.generate_normals()
		var wheat_mesh := st.commit()
		wheat_mesh.surface_set_material(0, material())
		return wheat_mesh
	match stage:
		Stage.SEEDLING:
			_tuft(st, rng, 6, h * 0.28, 0.018, 0.35, crop.young_color)
		Stage.GROWING:
			_tuft(st, rng, 11, h * 0.72, 0.022, 0.45, crop.growing_color)
		Stage.HEADING:
			var tops := _tuft(st, rng, 12, h * 0.92, 0.022, 0.4, crop.growing_color)
			for i in 4:
				_panicle(st, rng, tops[i], 0.16, crop.growing_color.lerp(crop.grain_color, 0.45), 0.6)
		Stage.RIPE:
			var tops := _tuft(st, rng, 12, h, 0.022, 0.42, crop.ripe_color)
			for i in 5:
				_panicle(st, rng, tops[i], 0.22, crop.grain_color, 1.0)
		Stage.STUBBLE:
			_tuft(st, rng, 9, 0.12, 0.012, 0.1, crop.ripe_color.darkened(0.15))
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	return mesh


## Wheat: a clump of straight stalks with a few leaves; from heading on, each stalk
## carries an upright ear (two crossed spikes with whiskery awns).
static func _build_wheat(st: SurfaceTool, rng: RandomNumberGenerator, crop: FieldCropData, stage: int) -> void:
	var h := crop.height
	match stage:
		Stage.SEEDLING:
			_tuft(st, rng, 7, h * 0.22, 0.016, 0.3, crop.young_color)
		Stage.GROWING:
			_tuft(st, rng, 8, h * 0.55, 0.02, 0.35, crop.growing_color)
			_tuft(st, rng, 6, h * 0.7, 0.008, 0.05, crop.growing_color.darkened(0.1))
		Stage.HEADING, Stage.RIPE:
			var ripe := stage == Stage.RIPE
			var stalk_color := crop.ripe_color if ripe else crop.growing_color
			var ear_color := crop.grain_color if ripe else crop.growing_color.lerp(crop.grain_color, 0.25)
			_tuft(st, rng, 5, h * 0.45, 0.018, 0.4, stalk_color.darkened(0.08))
			var tops := _tuft(st, rng, 9, h, 0.007, 0.06, stalk_color)
			for top in tops:
				_ear(st, rng, top, 0.11, ear_color, 0.12 if ripe else 0.0)
		Stage.STUBBLE:
			_tuft(st, rng, 10, 0.1, 0.008, 0.06, crop.ripe_color.darkened(0.15))


## An upright ear of grain on top of a stalk: two crossed tapered spikes and a few
## awns, nodding over a little when ripe (`nod`).
static func _ear(st: SurfaceTool, rng: RandomNumberGenerator, top: Vector3, length: float, color: Color, nod: float) -> void:
	var out := Vector3(top.x, 0.0, top.z)
	out = out.normalized() if out.length() > 0.001 else Vector3.RIGHT
	var axis := (Vector3.UP + out * nod).normalized()
	var tint := color * rng.randf_range(0.92, 1.06)
	for side: Vector3 in [Vector3.UP.cross(out).normalized(), out]:
		var w := side * 0.017
		var mid := top + axis * length * 0.45
		var tip := top + axis * length
		_quad(st, top - w * 0.4, top + w * 0.4, mid + w, mid - w, tint, tint)
		_quad(st, mid - w, mid + w, tip + w * 0.15, tip - w * 0.15, tint, tint * 1.05)
	# Awns: fine whiskers off the tip.
	for i in 3:
		var a := axis.rotated(out if i % 2 == 0 else Vector3.UP.cross(out).normalized(), rng.randf_range(-0.35, 0.35))
		var base := top + axis * length * rng.randf_range(0.6, 0.95)
		var side := Vector3.UP.cross(a).normalized() * 0.002
		_quad(st, base - side, base + side, base + a * 0.08 + side, base + a * 0.08 - side, tint, tint)


## A tuft of `count` blades. Returns the tip of each blade (for grain heads).
static func _tuft(st: SurfaceTool, rng: RandomNumberGenerator, count: int, length: float, width: float, lean: float, color: Color) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var base := out * rng.randf_range(0.0, 0.04)
		var blade_length := length * rng.randf_range(0.75, 1.0)
		var blade_lean := lean * rng.randf_range(0.5, 1.2)
		var side := Vector3.UP.cross(out).normalized()
		var tint := color * rng.randf_range(0.88, 1.08)
		tips.append(_blade(st, base, out, side, blade_length, blade_lean, width, tint))
	return tips


## One tapering, outward-curving blade. Returns its tip.
static func _blade(st: SurfaceTool, base: Vector3, out: Vector3, side: Vector3, length: float, lean: float, width: float, color: Color) -> Vector3:
	const SEGMENTS := 4
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var tip := base
	for s in SEGMENTS + 1:
		var t := float(s) / SEGMENTS
		var p := base + Vector3.UP * length * t * (1.0 - 0.25 * lean * t) + out * length * lean * t * t
		var w := width * (1.0 - t * 0.85)
		var l := p - side * w
		var r := p + side * w
		if s > 0:
			var c0 := Color(color * (0.7 + 0.3 * (t - 1.0 / SEGMENTS)), 1.0)
			var c1 := Color(color * (0.7 + 0.3 * t), 1.0)
			_quad(st, prev_l, prev_r, r, l, c0, c1)
		prev_l = l
		prev_r = r
		tip = p
	return tip


## A grain head: a beaded strip arching over and drooping from `top`.
static func _panicle(st: SurfaceTool, rng: RandomNumberGenerator, top: Vector3, length: float, color: Color, droop: float) -> void:
	var out := Vector3(top.x, 0.0, top.z)
	out = out.normalized() if out.length() > 0.001 else Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)
	var side := Vector3.UP.cross(out).normalized()
	const SEGMENTS := 6
	var prev := top
	for s in SEGMENTS:
		var t := float(s + 1) / SEGMENTS
		# Up and out, then curving down (heavier when ripe).
		var p := top + out * length * t + Vector3.UP * length * (0.35 * t - droop * t * t * 0.9)
		var w := 0.022 * (1.0 - 0.5 * absf(t - 0.4))
		var c := color * rng.randf_range(0.92, 1.06)
		_quad(st, prev - side * w, prev + side * w, p + side * w, p - side * w, c, c)
		prev = p


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, low: Color, high: Color) -> void:
	st.set_color(low)
	st.add_vertex(a)
	st.set_color(low)
	st.add_vertex(b)
	st.set_color(high)
	st.add_vertex(c)
	st.set_color(low)
	st.add_vertex(a)
	st.set_color(high)
	st.add_vertex(c)
	st.set_color(high)
	st.add_vertex(d)
