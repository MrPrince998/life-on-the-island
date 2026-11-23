@tool
class_name SoilMound
extends Node3D
## A grassy mound of soil under a building, so a model whose walls stand higher than its
## front steps sits on raised ground instead of floating. Uses the terrain's own material,
## so it blends into the island, and has walkable collision (gentle slopes).
##
## Shape (in this node's space, metres; y = 0 is the ground):
##   - a flat top at `height` over the rectangle `top_min`..`top_max` (x, z);
##   - slopes down to the ground over `slope_width` on the back and both sides;
##   - in front of `front_cut_z` nothing is raised between the sides (the building's front
##     yard and steps stay at ground level), but the side slopes carry on to `front_end_z`,
##     hugging the front garden walls.

@export var top_min := Vector2(-4.25, -4.5)
@export var top_max := Vector2(4.25, 2.75)
@export var height: float = 1.25
@export var slope_width: float = 3.0
@export var front_cut_z: float = 2.75
@export var front_end_z: float = 4.45
@export var cell: float = 0.25
@export var material: Material = preload("res://resources/materials/terrain_material.tres")
@export var rebuild: bool = false:
	set(value):
		if value:
			build()

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D


func _ready() -> void:
	build()


func height_at(x: float, z: float) -> float:
	if z > front_cut_z:
		var side := maxf(top_min.x - x, x - top_max.x)
		if side <= 0.0:
			return 0.0
		var shoulder := height * (1.0 - smoothstep(0.0, slope_width, side))
		return shoulder * (1.0 - smoothstep(front_end_z - 0.4, front_end_z + slope_width * 0.6, z))
	var dx := maxf(maxf(top_min.x - x, x - top_max.x), 0.0)
	var dz := maxf(top_min.y - z, 0.0)
	var d := Vector2(dx, dz).length()
	return height * (1.0 - smoothstep(0.0, slope_width, d))


func build() -> void:
	for child in get_children():
		if child.has_meta(&"generated"):
			child.free()
	var x0 := top_min.x - slope_width
	var x1 := top_max.x + slope_width
	var z0 := top_min.y - slope_width
	var z1 := front_end_z + slope_width * 0.6
	var nx := int(ceil((x1 - x0) / cell)) + 1
	var nz := int(ceil((z1 - z0) / cell)) + 1
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for zi in nz:
		for xi in nx:
			var x := x0 + xi * cell
			var z := z0 + zi * cell
			var h := height_at(x, z)
			# Where there is no mound, tuck the surface under the terrain.
			verts.append(Vector3(x, h if h > 0.01 else -0.3, z))
			colors.append(Color(0, 0, 0, 1))  # plain grass in the terrain shader
	var indices := PackedInt32Array()
	for zi in nz - 1:
		for xi in nx - 1:
			var a := zi * nx + xi
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# Skip cells that are entirely under the ground.
			if verts[a].y < 0.0 and verts[b].y < 0.0 and verts[c].y < 0.0 and verts[d].y < 0.0:
				continue
			indices.append_array([a, b, c, b, d, c])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for zi in nz:
		for xi in nx:
			var l := verts[zi * nx + maxi(xi - 1, 0)].y
			var r := verts[zi * nx + mini(xi + 1, nx - 1)].y
			var u := verts[maxi(zi - 1, 0) * nx + xi].y
			var dn := verts[mini(zi + 1, nz - 1) * nx + xi].y
			normals[zi * nx + xi] = Vector3(l - r, 2.0 * cell, u - dn).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MoundMesh"
	_mesh_instance.mesh = mesh
	_mesh_instance.set_meta(&"generated", true)
	add_child(_mesh_instance)
	_body = StaticBody3D.new()
	_body.name = "MoundBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta(&"generated", true)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	_body.add_child(shape)
	add_child(_body)
