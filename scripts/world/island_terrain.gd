@tool
class_name IslandTerrain
extends Node3D
## Builds the blockout terrain mesh and collision from IslandShape.
##
## Generated children are not saved into the scene (they have no owner), so the
## .tscn stays small. The terrain is rebuilt each time the scene loads, both in
## the editor and in game. Tick "Regenerate" in the Inspector to rebuild.

@export var cell_size: float = 2.0
@export var terrain_material: Material
@export var regenerate: bool = false:
	set(value):
		if value and is_inside_tree():
			generate()

var shape: IslandShape

var _generated: Array[Node] = []


func _ready() -> void:
	generate()


func generate() -> void:
	for node in _generated:
		if is_instance_valid(node):
			node.queue_free()
	_generated.clear()

	shape = IslandShape.shared()
	var n := int(round(IslandShape.TERRAIN_SIZE / cell_size)) + 1
	var half := (n - 1) * cell_size * 0.5

	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for zi in n:
		var z := -half + zi * cell_size
		for xi in n:
			heights[zi * n + xi] = shape.get_height(-half + xi * cell_size, z)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for zi in n:
		var z := -half + zi * cell_size
		for xi in n:
			var x := -half + xi * cell_size
			var i := zi * n + xi
			var h := heights[i]
			var left := heights[zi * n + maxi(xi - 1, 0)]
			var right := heights[zi * n + mini(xi + 1, n - 1)]
			var up := heights[maxi(zi - 1, 0) * n + xi]
			var down := heights[mini(zi + 1, n - 1) * n + xi]
			var normal := Vector3(left - right, 2.0 * cell_size, up - down).normalized()
			vertices[i] = Vector3(x, h, z)
			normals[i] = normal
			colors[i] = shape.get_surface_weights(x, z, h, normal) if h > -3.0 else Color(1, 0, 0, 1)

	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k := 0
	for zi in n - 1:
		for xi in n - 1:
			var a := zi * n + xi
			var b := a + 1
			var c := a + n
			var d := c + 1
			# Godot treats clockwise triangles (seen from above) as front faces.
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if terrain_material:
		mesh.surface_set_material(0, terrain_material)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	_add_generated(mesh_instance)

	if Engine.is_editor_hint():
		return
	var height_map := HeightMapShape3D.new()
	height_map.map_width = n
	height_map.map_depth = n
	height_map.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = height_map
	collision.scale = Vector3(cell_size, 1.0, cell_size)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(collision)
	_add_generated(body)


func _add_generated(node: Node) -> void:
	add_child(node)
	_generated.append(node)
