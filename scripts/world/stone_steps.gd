@tool
class_name StoneSteps
extends Node3D
## A short flight of stone steps with a smooth walkable ramp for collision (the player
## glides up instead of bumping on each step). Built in code.
##
## In this node's space: the steps run along -z, from the bottom step's front edge at
## z = `bottom_z` (ground, y = 0) back to z = `top_z`, where they reach `top_height`.

@export var bottom_z: float = 4.9
@export var top_z: float = 2.8
@export var top_height: float = 1.61
@export var x_min: float = -0.55
@export var x_max: float = 0.98
@export var step_count: int = 6
@export var stone_color: Color = Color(0.66, 0.6, 0.5)
@export var rebuild: bool = false:
	set(value):
		if value:
			build()


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()
	var width := x_max - x_min
	var center_x := (x_min + x_max) * 0.5
	var run := (bottom_z - top_z) / step_count
	var rise := top_height / step_count
	var edge := StandardMaterial3D.new()
	edge.albedo_color = stone_color.darkened(0.22)
	edge.roughness = 0.95
	for i in step_count:
		# Each step is a solid block down to the ground, with a slightly darker lip.
		var top := (i + 1) * rise
		var front := bottom_z - i * run
		var block := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, top, run + 0.02)
		# Each step a slightly different shade, like hand-cut stone.
		var stone := StandardMaterial3D.new()
		stone.albedo_color = stone_color.lightened(0.06 * float((i * 7) % 3) - 0.03)
		stone.roughness = 0.95
		box.material = stone
		block.mesh = box
		block.position = Vector3(center_x, top * 0.5, front - run * 0.5)
		block.set_meta(&"generated", true)
		add_child(block)
		var lip := MeshInstance3D.new()
		var lip_box := BoxMesh.new()
		lip_box.size = Vector3(width + 0.02, 0.05, 0.06)
		lip_box.material = edge
		lip.mesh = lip_box
		lip.position = Vector3(center_x, top - 0.025, front - 0.03)
		lip.set_meta(&"generated", true)
		add_child(lip)
	# Collision: one smooth ramp over the step noses.
	var body := StaticBody3D.new()
	body.name = "StepsBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	var length := Vector2(bottom_z - top_z, top_height).length()
	var angle := atan2(top_height, bottom_z - top_z)
	var ramp := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(width, 0.2, length + 0.3)
	ramp.shape = ramp_box
	# Tilt so the far (-z) end is raised; drop by half the thickness so the top surface
	# runs through the step noses.
	var basis := Basis(Vector3.RIGHT, angle)
	ramp.transform = Transform3D(basis, Vector3(center_x, top_height * 0.5, (bottom_z + top_z) * 0.5) - basis.y * 0.1)
	body.add_child(ramp)
	add_child(body)
