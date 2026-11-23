@tool
class_name Sawhorse
extends Node3D
## A simple wooden sawhorse with a plank across it and a little sawdust, built from
## boxes (no model needed). Collision is a small box so you can walk around it.

@export var rebuild: bool = false:
	set(value):
		if value:
			build()


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.free()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.43, 0.26)
	wood.roughness = 0.9
	var wood_dark := StandardMaterial3D.new()
	wood_dark.albedo_color = Color(0.45, 0.3, 0.18)
	wood_dark.roughness = 0.9
	var plank := StandardMaterial3D.new()
	plank.albedo_color = Color(0.8, 0.62, 0.4)
	plank.roughness = 0.85
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.88, 0.76, 0.55)
	dust.roughness = 1.0
	# Top beam and two pairs of splayed legs.
	_box(Vector3(0, 0.72, 0), Vector3(1.3, 0.12, 0.14), Vector3.ZERO, wood)
	for x in [-0.5, 0.5]:
		for side in [-1.0, 1.0]:
			_box(Vector3(x, 0.36, side * 0.16), Vector3(0.09, 0.8, 0.09), Vector3(side * 22.0, 0, 0), wood_dark)
		_box(Vector3(x, 0.3, 0), Vector3(0.07, 0.07, 0.36), Vector3.ZERO, wood_dark)
	# A plank being sawn, and the cut-off end on the ground.
	_box(Vector3(0.15, 0.82, 0.02), Vector3(1.6, 0.06, 0.28), Vector3(0, 8.0, 0), plank)
	_box(Vector3(-0.95, 0.04, 0.35), Vector3(0.5, 0.06, 0.26), Vector3(0, 40.0, 0), plank)
	# Sawdust heap.
	var heap := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.16
	sphere.material = dust
	heap.mesh = sphere
	heap.position = Vector3(0.1, 0.0, 0.05)
	heap.scale = Vector3(1.6, 1.0, 1.2)
	heap.set_meta(&"generated", true)
	add_child(heap)
	# A small log_mesh pile beside it.
	for i in 3:
		var log_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.11
		cylinder.bottom_radius = 0.11
		cylinder.height = 0.9
		cylinder.material = wood if i != 1 else wood_dark
		log_mesh.mesh = cylinder
		log_mesh.rotation_degrees = Vector3(0, 0, 90)
		log_mesh.position = Vector3(0.05, 0.11 + (0.19 if i == 2 else 0.0), -0.55 + (0.12 if i == 2 else i * 0.23))
		log_mesh.set_meta(&"generated", true)
		add_child(log_mesh)
	if not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta(&"generated", true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 0.9, 1.0)
		shape.shape = box
		shape.position = Vector3(0, 0.45, -0.15)
		body.add_child(shape)
		add_child(body)


func _box(pos: Vector3, size: Vector3, rot_degrees: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.rotation_degrees = rot_degrees
	instance.set_meta(&"generated", true)
	add_child(instance)
