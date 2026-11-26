class_name HandCart
extends StaticBody3D
## A wooden hand-cart for moving shipping crates: a flat bed with side rails, two big
## wheels and a pair of push handles. It holds four crates. Built in code.
##
## Press E at the handles to push it (PlayerCarry moves it in front of you, its wheels
## turning as it rolls) and E again to let go. Carrying a crate, press E at the handles
## to load the crate onto the bed. Crates on the bed ride along (they're its children).
## Local frame: the cart rolls towards its -Z; the handles are at the +Z end.

const SLOTS := 4
const BED_HEIGHT := 0.62
const WHEEL_RADIUS := 0.34
const WHEEL_Z := -0.3
## Where the hands go on the handle grips (local).
const GRIP_LEFT := Vector3(-0.4, 0.98, 1.2)
const GRIP_RIGHT := Vector3(0.4, 0.98, 1.2)
const WOOD := Color(0.56, 0.38, 0.22)
const DARK_WOOD := Color(0.36, 0.24, 0.14)
const IRON := Color(0.3, 0.3, 0.32)

var _rack: CrateRack
var _wheels: Array[Node3D] = []
var _handle: CartHandle
var _pushed := false


func _ready() -> void:
	add_to_group(&"hand_cart")
	collision_layer = 1
	collision_mask = 0
	_build()
	_rack = CrateRack.new()
	_rack.name = "Rack"
	_rack.location = ShippingCrate.Location.CART
	_rack.slots = PackedVector3Array([
		Vector3(-0.34, BED_HEIGHT + 0.04, -0.4), Vector3(0.34, BED_HEIGHT + 0.04, -0.4),
		Vector3(-0.34, BED_HEIGHT + 0.04, 0.3), Vector3(0.34, BED_HEIGHT + 0.04, 0.3),
	])
	add_child(_rack)
	_handle = CartHandle.new()
	_handle.name = "Handle"
	_handle.cart = self
	_handle.position = Vector3(0, 0.9, 1.25)
	add_child(_handle)
	settle.call_deferred()


func get_crates() -> Array[ShippingCrate]:
	return _rack.get_crates() if _rack else ([] as Array[ShippingCrate])


func free_slot() -> int:
	return _rack.free_slot() if _rack else -1


func place(crate: ShippingCrate, slot: int = -1) -> bool:
	return _rack.place(crate, slot) if _rack else false


func is_pushed() -> bool:
	return _pushed


## While pushed it doesn't block the player (it's right in front of them).
func set_pushed(pushed: bool) -> void:
	_pushed = pushed
	collision_layer = 0 if pushed else 1
	if not pushed:
		settle()


## Sits the cart on whatever is under it (ground or a jetty deck).
func settle() -> void:
	if not is_inside_tree():
		return
	global_position.y = floor_height_at(global_position, [get_rid()])


## The floor height under a point: the jetty deck if there is one, else the ground.
func floor_height_at(point: Vector3, exclude: Array[RID]) -> float:
	var ground := IslandShape.shared().get_height(point.x, point.z)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return ground
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, point.y + 2.0, point.z), Vector3(point.x, ground - 0.5, point.z), 1, exclude)
	var hit := space.intersect_ray(query)
	return maxf(ground, (hit.position as Vector3).y) if not hit.is_empty() else ground


## Turns the wheels for `distance` metres of rolling (negative = backwards).
func roll(distance: float) -> void:
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.RIGHT, -distance / WHEEL_RADIUS)


func get_grip(left: bool) -> Vector3:
	return to_global(GRIP_LEFT if left else GRIP_RIGHT)


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The bed and its rails.
	_box(st, Vector3(0, BED_HEIGHT, 0.0), Vector3(1.4, 0.06, 1.5), WOOD)
	for x: float in [-0.7, 0.7]:
		_box(st, Vector3(x, BED_HEIGHT + 0.12, 0.0), Vector3(0.05, 0.2, 1.5), DARK_WOOD)
	_box(st, Vector3(0, BED_HEIGHT + 0.12, -0.75), Vector3(1.4, 0.2, 0.05), DARK_WOOD)
	# Two beams under the bed, running back into the handles.
	for x: float in [-0.4, 0.4]:
		_box(st, Vector3(x, BED_HEIGHT - 0.07, 0.0), Vector3(0.08, 0.08, 1.5), DARK_WOOD)
		var start := Vector3(x, BED_HEIGHT - 0.04, 0.72)
		var end := Vector3(x, 0.98, 1.3)
		_beam(st, start, end, 0.07, DARK_WOOD)
		# A grip wrapped in cord at the end.
		_beam(st, end - (end - start).normalized() * 0.18, end, 0.085, Color(0.82, 0.74, 0.55))
	# Axle, and a stand at the back so it sits level when parked.
	_box(st, Vector3(0, WHEEL_RADIUS, WHEEL_Z), Vector3(1.62, 0.06, 0.06), IRON)
	for x: float in [-0.4, 0.4]:
		_beam(st, Vector3(x, BED_HEIGHT - 0.08, 0.55), Vector3(x, 0.0, 0.62), 0.05, DARK_WOOD)
	_commit(st, "Body")
	for x: float in [-0.8, 0.8]:
		var wheel := Node3D.new()
		wheel.name = "Wheel"
		wheel.position = Vector3(x, WHEEL_RADIUS, WHEEL_Z)
		var wst := SurfaceTool.new()
		wst.begin(Mesh.PRIMITIVE_TRIANGLES)
		_wheel(wst, WHEEL_RADIUS, 0.08)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _finish(wst)
		mesh.material_override = _material()
		wheel.add_child(mesh)
		add_child(wheel)
		_wheels.append(wheel)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.9, 1.6)
	shape.shape = box
	shape.position = Vector3(0, 0.45, 0.1)
	add_child(shape)


func _wheel(st: SurfaceTool, radius: float, width: float) -> void:
	# A rim of planks and eight spokes, in the YZ plane (the wheel turns about X).
	var sides := 16
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(0, sin(a0), cos(a0)) * radius
		var p1 := Vector3(0, sin(a1), cos(a1)) * radius
		var mid := (p0 + p1) * 0.5
		_oriented_box(st, mid, (p1 - p0).normalized(), Vector3(width, 0.06, p0.distance_to(p1) + 0.01), WOOD if i % 2 == 0 else DARK_WOOD)
	for i in 8:
		var a := TAU * i / 8.0
		_beam(st, Vector3.ZERO, Vector3(0, sin(a), cos(a)) * radius * 0.95, 0.025, DARK_WOOD)
	_box(st, Vector3.ZERO, Vector3(width * 1.6, 0.1, 0.1), IRON)


func _beam(st: SurfaceTool, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	_oriented_box(st, (from + to) * 0.5, (to - from).normalized(), Vector3(thickness, thickness, from.distance_to(to)), color)


func _oriented_box(st: SurfaceTool, center: Vector3, along: Vector3, size: Vector3, color: Color) -> void:
	var up := Vector3.UP if absf(along.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(along, up)
	_box(st, center, size, color, basis)


func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, basis: Basis = Basis()) -> void:
	var cube := BoxMesh.new()
	cube.size = size
	var data := cube.get_mesh_arrays()
	var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	for index in indices:
		st.set_color(color)
		st.set_normal(basis * normals[index])
		st.add_vertex(basis * verts[index] + center)


func _commit(st: SurfaceTool, mesh_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = mesh_name
	mesh.mesh = _finish(st)
	mesh.material_override = _material()
	add_child(mesh)


static func _finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


static func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.85
	return material
