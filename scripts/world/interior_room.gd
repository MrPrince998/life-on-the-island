@tool
class_name InteriorRoom
extends Node3D
## The shell of a cosy room, built in code: plank floor, plaster walls with a wooden
## panel, a plank ceiling with beams and corner posts, window frames with glass that
## follows the time of day, and a closed front door. Collision is a solid box room.
##
## In this node's space the floor is at y = 0 and the room spans x in [-size.x/2,
## size.x/2], z in [-size.z/2, size.z/2]; the front wall (with the door) is at +z.
##
## Interiors sit high above their building (so walking around them costs nothing and
## they never touch the terrain or water) and only draw while the camera is inside.

const PLANKS := preload("res://shaders/interior_planks.gdshader")
const PLASTER := preload("res://shaders/interior_plaster.gdshader")
const WALL := 0.2

## Inside size (metres): width, height, depth.
@export var size: Vector3 = Vector3(8.0, 3.0, 6.0)
## Door in the front (+z) wall: centre x and width; it is 2.2 m tall.
@export var door_x: float = 0.27
@export var door_width: float = 1.2
## Windows as Vector4(wall, centre, width, unused). wall: 0 = front (+z), 1 = back (-z),
## 2 = left (-x), 3 = right (+x). Sill at 0.95 m, top at 2.05 m.
@export var windows: Array[Vector4] = []
@export var rebuild: bool = false:
	set(value):
		if value:
			build()

var _planks_floor: ShaderMaterial
var _planks_beam: ShaderMaterial
var _planks_post: ShaderMaterial
var _plaster: ShaderMaterial
var _frame: StandardMaterial3D
var _glass: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"indoors")
	build()
	if not Engine.is_editor_hint():
		ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _update_glass())
		_update_glass()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Only draw the room while the camera is in it (it floats far above the village).
	var camera := get_viewport().get_camera_3d()
	var inside := camera != null and contains_point(camera.global_position, 0.6)
	if visible != inside:
		visible = inside


## True if a world point is inside this room (with an optional margin).
func contains_point(point: Vector3, margin: float = 0.0) -> bool:
	var p := to_local(point)
	return absf(p.x) <= size.x * 0.5 + margin and absf(p.z) <= size.z * 0.5 + margin and p.y >= -0.5 - margin and p.y <= size.y + margin


## True if the point is inside any interior (used to stop rain indoors).
static func is_indoors(tree: SceneTree, point: Vector3) -> bool:
	for room in tree.get_nodes_in_group(&"indoors"):
		if (room as InteriorRoom).contains_point(point, 0.3):
			return true
	return false


func build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.free()
	_make_materials()
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	# Floor and ceiling.
	_box(Vector3(0, -0.1, 0), Vector3(size.x + WALL * 2, 0.2, size.z + WALL * 2), _planks_floor)
	_box(Vector3(0, h + 0.1, 0), Vector3(size.x + WALL * 2, 0.2, size.z + WALL * 2), _planks_beam)
	# Walls, split around the door and windows.
	_wall(Vector3(0, 0, hz + WALL * 0.5), true, size.x, _openings(0, true))
	_wall(Vector3(0, 0, -hz - WALL * 0.5), true, size.x, _openings(1, false))
	_wall(Vector3(-hx - WALL * 0.5, 0, 0), false, size.z, _openings(2, false))
	_wall(Vector3(hx + WALL * 0.5, 0, 0), false, size.z, _openings(3, false))
	# Beams across the ceiling, corner posts and a skirting board.
	var beams := int(size.x / 1.7)
	for i in beams:
		var x := -hx + (i + 0.5) * size.x / beams
		_box(Vector3(x, h - 0.14, 0), Vector3(0.22, 0.28, size.z), _planks_beam)
	_box(Vector3(0, h - 0.12, 0), Vector3(size.x, 0.24, 0.26), _planks_beam)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(sx * (hx - 0.12), h * 0.5, sz * (hz - 0.12)), Vector3(0.26, h, 0.26), _planks_post)
	# Door: a closed plank door with a frame and an iron latch.
	var door_z := hz - 0.02
	_box(Vector3(door_x, 1.1, door_z - 0.03), Vector3(door_width - 0.08, 2.18, 0.08), _planks_post)
	_box(Vector3(door_x - door_width * 0.5, 1.15, door_z - 0.05), Vector3(0.12, 2.3, 0.14), _planks_beam)
	_box(Vector3(door_x + door_width * 0.5, 1.15, door_z - 0.05), Vector3(0.12, 2.3, 0.14), _planks_beam)
	_box(Vector3(door_x, 2.26, door_z - 0.05), Vector3(door_width + 0.12, 0.14, 0.14), _planks_beam)
	var latch := StandardMaterial3D.new()
	latch.albedo_color = Color(0.18, 0.17, 0.16)
	latch.metallic = 0.6
	latch.roughness = 0.5
	_box(Vector3(door_x + door_width * 0.32, 1.05, door_z - 0.1), Vector3(0.06, 0.18, 0.05), latch)
	for w in windows:
		_window(w)
	# Collision: one solid box room.
	var body := StaticBody3D.new()
	body.name = "RoomBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body)
	for shape_def in [
		[Vector3(0, -0.25, 0), Vector3(size.x + 1, 0.5, size.z + 1)],
		[Vector3(0, h + 0.25, 0), Vector3(size.x + 1, 0.5, size.z + 1)],
		[Vector3(0, h * 0.5, hz + 0.25), Vector3(size.x + 1, h, 0.5)],
		[Vector3(0, h * 0.5, -hz - 0.25), Vector3(size.x + 1, h, 0.5)],
		[Vector3(-hx - 0.25, h * 0.5, 0), Vector3(0.5, h, size.z + 1)],
		[Vector3(hx + 0.25, h * 0.5, 0), Vector3(0.5, h, size.z + 1)],
	]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = shape_def[1]
		shape.shape = box
		shape.position = shape_def[0]
		body.add_child(shape)


func _make_materials() -> void:
	_planks_floor = ShaderMaterial.new()
	_planks_floor.shader = PLANKS
	_planks_floor.set_shader_parameter(&"plank_axis", 0)
	_planks_floor.set_shader_parameter(&"base_color", Color(0.6, 0.4, 0.24))
	_planks_beam = ShaderMaterial.new()
	_planks_beam.shader = PLANKS
	_planks_beam.set_shader_parameter(&"base_color", Color(0.42, 0.27, 0.16))
	_planks_beam.set_shader_parameter(&"dark_color", Color(0.26, 0.16, 0.09))
	_planks_beam.set_shader_parameter(&"plank_width", 0.3)
	_planks_beam.set_shader_parameter(&"plank_length", 3.0)
	_planks_post = ShaderMaterial.new()
	_planks_post.shader = PLANKS
	_planks_post.set_shader_parameter(&"plank_axis", 2)
	_planks_post.set_shader_parameter(&"base_color", Color(0.45, 0.29, 0.17))
	_planks_post.set_shader_parameter(&"plank_width", 0.18)
	_plaster = ShaderMaterial.new()
	_plaster.shader = PLASTER
	_plaster.set_shader_parameter(&"wainscot_top", global_position.y + 0.95 if is_inside_tree() else 0.95)
	_frame = StandardMaterial3D.new()
	_frame.albedo_color = Color(0.36, 0.22, 0.13)
	_frame.roughness = 0.85
	_glass = StandardMaterial3D.new()
	_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glass.albedo_color = Color(0.8, 0.9, 1.0)


## Openings in one wall as [from, to, bottom, top] along the wall's length.
func _openings(wall: int, with_door: bool) -> Array:
	var list: Array = []
	if with_door:
		list.append([door_x - door_width * 0.5, door_x + door_width * 0.5, 0.0, 2.2])
	for w in windows:
		if int(w.x) == wall:
			list.append([w.y - w.z * 0.5, w.y + w.z * 0.5, 0.95, 2.05])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return list


## A wall centred at `center`, running along x (along_x) or z, with openings cut out.
func _wall(center: Vector3, along_x: bool, length: float, openings: Array) -> void:
	var h := size.y
	var start := -length * 0.5 - WALL
	var cursor := start
	var pieces: Array = []  # [from, to, bottom, top]
	for o in openings:
		if o[0] > cursor:
			pieces.append([cursor, o[0], 0.0, h])
		if o[2] > 0.0:
			pieces.append([o[0], o[1], 0.0, o[2]])
		pieces.append([o[0], o[1], o[3], h])
		cursor = o[1]
	pieces.append([cursor, length * 0.5 + WALL, 0.0, h])
	for piece in pieces:
		var mid := (float(piece[0]) + float(piece[1])) * 0.5
		var len := float(piece[1]) - float(piece[0])
		var y0 := float(piece[2])
		var y1 := float(piece[3])
		if len <= 0.001 or y1 - y0 <= 0.001:
			continue
		var pos := center + (Vector3(mid, (y0 + y1) * 0.5, 0) if along_x else Vector3(0, (y0 + y1) * 0.5, mid))
		var dims := Vector3(len, y1 - y0, WALL) if along_x else Vector3(WALL, y1 - y0, len)
		_box(pos, dims, _plaster)


func _window(w: Vector4) -> void:
	var wall := int(w.x)
	var along_x := wall <= 1
	var sign := 1.0 if wall == 0 or wall == 3 else -1.0
	var depth := (size.z if along_x else size.x) * 0.5
	var center := w.y
	var width := w.z
	var y0 := 0.95
	var y1 := 2.05
	var inner := depth - 0.02
	var at := func(along: float, y: float, inward: float) -> Vector3:
		var d := sign * (inner - inward)
		return Vector3(along, y, d) if along_x else Vector3(d, y, along)
	var dims := func(along_size: float, y_size: float, thick: float) -> Vector3:
		return Vector3(along_size, y_size, thick) if along_x else Vector3(thick, y_size, along_size)
	# Glass sits in the middle of the wall; frame, mullions and a sill inside.
	var glass_pos: Vector3 = at.call(center, (y0 + y1) * 0.5, -0.12)
	_box(glass_pos, dims.call(width, y1 - y0, 0.02), _glass, &"glass")
	_box(at.call(center, y0 - 0.03, 0.06), dims.call(width + 0.3, 0.08, 0.22), _frame)
	_box(at.call(center, y1 + 0.04, 0.03), dims.call(width + 0.16, 0.08, 0.12), _frame)
	_box(at.call(center - width * 0.5 - 0.04, (y0 + y1) * 0.5, 0.03), dims.call(0.08, y1 - y0 + 0.1, 0.12), _frame)
	_box(at.call(center + width * 0.5 + 0.04, (y0 + y1) * 0.5, 0.03), dims.call(0.08, y1 - y0 + 0.1, 0.12), _frame)
	_box(at.call(center, (y0 + y1) * 0.5, -0.06), dims.call(0.05, y1 - y0, 0.05), _frame)
	_box(at.call(center, (y0 + y1) * 0.5, -0.06), dims.call(width, 0.05, 0.05), _frame)


func _box(pos: Vector3, dims: Vector3, material: Material, tag: StringName = &"") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.set_meta(&"generated", true)
	if tag != &"":
		instance.add_to_group(tag)
	add_child(instance)
	return instance


## Window glass: bright sky by day, warm at dawn and dusk, deep blue at night.
func _update_glass() -> void:
	if _glass == null:
		return
	var hour := ActivityClock.get_minute_of_day() / 60.0
	var day := Color(0.86, 0.94, 1.0)
	var warm := Color(1.0, 0.78, 0.55)
	var night := Color(0.1, 0.14, 0.3)
	var color: Color
	if hour < 5.0 or hour >= 21.0:
		color = night
	elif hour < 7.0:
		color = night.lerp(warm, (hour - 5.0) / 2.0)
	elif hour < 9.0:
		color = warm.lerp(day, (hour - 7.0) / 2.0)
	elif hour < 17.0:
		color = day
	elif hour < 19.0:
		color = day.lerp(warm, (hour - 17.0) / 2.0)
	else:
		color = warm.lerp(night, (hour - 19.0) / 2.0)
	_glass.albedo_color = color
