@tool
class_name Bunting
extends Node3D
## Festival bunting (the "Festival Bunting" village project): wooden poles with ropes
## strung between them, hung with bright triangle flags. Built in code from `poles`
## (positions relative to this node; the poles stand on the island's ground).

@export var poles: PackedVector3Array = PackedVector3Array():
	set(value):
		poles = value
		if is_inside_tree():
			_build()
## Join the last pole back to the first.
@export var closed_loop: bool = true
@export var pole_height: float = 3.6
## How far the rope dips in the middle of each span (metres).
@export var sag: float = 0.55
@export var flag_spacing: float = 0.55

const POLE_COLOR := Color(0.45, 0.3, 0.17)
const ROPE_COLOR := Color(0.85, 0.8, 0.68)
const FLAG_COLORS: Array[Color] = [
	Color(0.89, 0.36, 0.32), Color(0.96, 0.78, 0.3), Color(0.42, 0.68, 0.86),
	Color(0.55, 0.78, 0.42), Color(0.93, 0.6, 0.75), Color(0.98, 0.95, 0.9),
]


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	if poles.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops: Array[Vector3] = []
	for p in poles:
		var ground := _ground_at(p)
		_cylinder(st, Vector3(p.x, ground - 0.3, p.z), Vector3(p.x, ground + pole_height, p.z), 0.07, POLE_COLOR)
		tops.append(Vector3(p.x, ground + pole_height - 0.15, p.z))
	var spans := tops.size() if closed_loop else tops.size() - 1
	var flag_index := 0
	for i in spans:
		var a := tops[i]
		var b := tops[(i + 1) % tops.size()]
		var length := a.distance_to(b)
		var steps := maxi(int(length / 0.4), 2)
		var prev := a
		for k in range(1, steps + 1):
			var t := float(k) / steps
			var point := _rope(a, b, t)
			_cylinder(st, prev, point, 0.015, ROPE_COLOR)
			prev = point
		# Flags hang from the rope, all along the span.
		var flags := maxi(int(length / flag_spacing) - 1, 1)
		var across := (b - a).normalized()
		for k in flags:
			var t := (k + 1.0) / (flags + 1.0)
			var top := _rope(a, b, t)
			var color := FLAG_COLORS[flag_index % FLAG_COLORS.size()]
			flag_index += 1
			var half := across * 0.17
			_triangle(st, top - half, top + half, top + Vector3.DOWN * 0.38, color)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	var mesh := MeshInstance3D.new()
	mesh.name = "Bunting"
	st.generate_normals()
	mesh.mesh = st.commit()
	mesh.material_override = material
	add_child(mesh)


func _rope(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


func _ground_at(local: Vector3) -> float:
	var world := to_global(Vector3(local.x, 0.0, local.z))
	return IslandShape.shared().get_height(world.x, world.z) - global_position.y


func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for v in [a, b, c]:
		st.set_color(color)
		st.add_vertex(v)


func _cylinder(st: SurfaceTool, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side).normalized()
	var sides := 6
	for i in sides:
		var a0 := (side * cos(TAU * i / sides) + other * sin(TAU * i / sides)) * radius
		var a1 := (side * cos(TAU * (i + 1) / sides) + other * sin(TAU * (i + 1) / sides)) * radius
		for v in [from + a0, to + a0, to + a1, from + a0, to + a1, from + a1]:
			st.set_color(color)
			st.add_vertex(v)
