@tool
class_name FittedModel
extends Node3D
## Shows a Tripo model at a real-world size, standing on the island's ground.
##
## Tripo exports every model about 1 unit big with its base at y = 0, so a placement
## only needs a size: the model is scaled so its longest side (or its height) is
## `size` metres, centred on this node, and set on the lowest ground under its
## footprint (on slopes the uphill side sinks in instead of the downhill side floating).
## A simple box collider is added unless `collision` is NONE; MESH follows the model's
## exact shape (for things you walk on, like bridges).

enum Fit { LONGEST_SIDE, HEIGHT }
enum Collision { NONE, BOX, MESH }

@export var model: PackedScene:
	set(value):
		model = value
		_rebuild_if_ready()
## Metres along `fit`.
@export var size: float = 1.0:
	set(value):
		size = value
		_rebuild_if_ready()
@export var fit: Fit = Fit.LONGEST_SIDE:
	set(value):
		fit = value
		_rebuild_if_ready()
@export var collision: Collision = Collision.BOX
## Collision box as a fraction of the model's bounds (roofs and porches overhang).
@export var collision_fraction: Vector3 = Vector3(0.8, 1.0, 0.8)
@export var snap_to_ground: bool = true
## How far below the lowest ground under the footprint the base goes.
@export var sink: float = 0.05
## Never set lower than this (buildings at the water's edge stand on stilts instead of
## dropping to the lake bed).
@export var min_height: float = -1000.0
## Multiplies the model's colours (white = unchanged): a withered or dusty look.
@export var tint: Color = Color.WHITE
## Hide the model beyond this distance (0 = always drawn). Saves work on small props.
@export var view_distance: float = 0.0

## The model's size in metres after fitting.
var fitted_size: Vector3 = Vector3.ZERO
var _model_node: Node3D


func _ready() -> void:
	build()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		build()


func build() -> void:
	for child in get_children():
		if child.has_meta(&"fitted"):
			remove_child(child)
			child.free()
	_model_node = null
	if model == null:
		return
	_model_node = model.instantiate() as Node3D
	if _model_node == null:
		return
	_model_node.name = "Model"
	_model_node.set_meta(&"fitted", true)
	var bounds := _bounds_of(_model_node)
	var ref := bounds.size.y if fit == Fit.HEIGHT else maxf(bounds.size.x, bounds.size.z)
	var s := size / maxf(ref, 0.001)
	_model_node.scale = Vector3.ONE * s
	_model_node.position = Vector3(-bounds.get_center().x * s, -bounds.position.y * s, -bounds.get_center().z * s)
	fitted_size = bounds.size * s
	add_child(_model_node)
	_style_meshes(_model_node)
	if collision == Collision.BOX and not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta(&"fitted", true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = fitted_size * collision_fraction
		shape.shape = box
		shape.position = Vector3(0.0, box.size.y * 0.5, 0.0)
		body.add_child(shape)
		add_child(body)
	if collision == Collision.MESH and not Engine.is_editor_hint():
		for mesh_node in _model_node.find_children("*", "MeshInstance3D", true, false):
			(mesh_node as MeshInstance3D).create_trimesh_collision()
	if snap_to_ground:
		_snap()


## The lowest ground under the footprint (centre and the four corners).
func _snap() -> void:
	var shape := IslandShape.shared()
	var half := Vector2(fitted_size.x, fitted_size.z) * 0.45
	var lowest := INF
	for corner in [Vector2.ZERO, Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, -half.y)]:
		var c: Vector2 = corner
		var world := global_transform * Vector3(c.x, 0.0, c.y)
		lowest = minf(lowest, shape.get_height(world.x, world.z))
	var p := global_position
	global_position = Vector3(p.x, maxf(lowest - sink, min_height), p.z)


func _style_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		var geo := node as GeometryInstance3D
		if tint != Color.WHITE:
			var overlay := StandardMaterial3D.new()
			overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			overlay.albedo_color = tint
			geo.material_overlay = overlay
		if view_distance > 0.0:
			geo.visibility_range_end = view_distance
			geo.visibility_range_end_margin = view_distance * 0.1
			geo.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		_style_meshes(child)


static func _bounds_of(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var box := xf * (node as MeshInstance3D).mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
		for child in node.get_children():
			var child_xf := xf * (child as Node3D).transform if child is Node3D else xf
			stack.append([child, child_xf])
	return result
