class_name UkuleleVisuals
extends RefCounted
## Builds Grandpa's ukulele mesh in code (warm koa wood, four nylon strings) until a
## hand-made model exists. Mesh space: body centred on the origin, the neck runs along
## +X and the soundboard faces +Z.

const KOA := Color(0.66, 0.40, 0.20)
const KOA_TOP := Color(0.84, 0.60, 0.33)
const NECK := Color(0.40, 0.25, 0.14)
const HOLE := Color(0.12, 0.08, 0.05)
const STRING := Color(0.96, 0.93, 0.85)
const LENGTH := 0.56

static var _mesh: Mesh


static func mesh() -> Mesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Figure-of-eight body: a big lower bout and a smaller upper bout.
	_add(st, _cylinder(0.105, 0.06), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.03, 0, 0)), KOA)
	_add(st, _cylinder(0.082, 0.06), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.1, 0, 0)), KOA)
	# Lighter soundboard on the front, and the dark sound hole.
	_add(st, _cylinder(0.098, 0.006), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.03, 0, 0.031)), KOA_TOP)
	_add(st, _cylinder(0.076, 0.006), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.1, 0, 0.031)), KOA_TOP)
	_add(st, _cylinder(0.03, 0.004), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.08, 0, 0.035)), HOLE)
	# Bridge, neck, fretboard and head.
	_add(st, _box(Vector3(0.025, 0.06, 0.012)), Transform3D(Basis(), Vector3(-0.07, 0, 0.038)), NECK)
	_add(st, _box(Vector3(0.24, 0.038, 0.025)), Transform3D(Basis(), Vector3(0.29, 0, 0.012)), NECK)
	_add(st, _box(Vector3(0.09, 0.055, 0.022)), Transform3D(Basis(Vector3.FORWARD, 0.0) * Basis(Vector3.UP, -0.15), Vector3(0.45, 0, 0.004)), NECK)
	for i in 4:
		var y := (i - 1.5) * 0.009
		_add(st, _box(Vector3(0.48, 0.0025, 0.0025)), Transform3D(Basis(), Vector3(0.17, y, 0.044)), STRING)
	_mesh = st.commit()
	_mesh.surface_set_material(0, CropVisuals.plant_material())
	return _mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 18
	c.rings = 1
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _add(st: SurfaceTool, prim: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xf.basis.inverse().transposed()
	for i in indices:
		st.set_color(color)
		st.set_normal((normal_basis * normals[i]).normalized())
		st.add_vertex(xf * verts[i])
