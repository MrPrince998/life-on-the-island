class_name SpinningSails
extends Node3D
## Makes a windmill's sails turn. Put it under the FittedModel showing the windmill.
## The model is one piece, so the sails are split off with the cutout shader: the
## standing model hides everything in the sail region, and a second copy shows only what
## is inside it and turns around the hub. The region is shaped like the sails: a thin slab
## along the sail plane holding the hub and four arms (boxes caught bits of the roof and
## missed the blade tips, which then spun through the roof or stayed behind).
## All values are in the Tripo model's own units (measured from windmill.glb's mesh).
## Pure decoration: real-time, never touches the activity clock.

const SHADER := preload("res://shaders/model_cutout.gdshader")

## Centre of the sail hub, on the sail plane.
@export var hub: Vector3 = Vector3(0.0055, 0.5632, 0.1867)
## The sails' axle: the sail plane's normal (the sails face a little to one side).
@export var axle: Vector3 = Vector3(0.294, 0.0115, 0.9557)
## How far behind and in front of the plane the hub reaches.
@export var depth: Vector2 = Vector2(-0.012, 0.08)
@export var hub_radius: float = 0.088
@export var arm_length: float = 0.58
@export var arm_half_width: float = 0.13
## Arm directions in the sail plane, degrees (0 = towards the model's right, 90 = up).
@export var arm_degrees: Vector4 = Vector4(50.0, 145.0, 237.0, 322.0)
## Each arm's depth range off the plane (the blades are not quite flat): the wall and
## roof behind them start just past these.
@export var arm_depth_min: Vector4 = Vector4(-0.025, -0.028, 0.004, -0.022)
@export var arm_depth_max: Vector4 = Vector4(0.035, 0.035, 0.06, 0.035)
## Past `tip_from` along each arm (clear of the wall), how much further back it reaches,
## for the back of the blade frames. 0 for the lower arm, which passes the stone base.
@export var tip_extra: Vector4 = Vector4(0.05, 0.05, 0.0, 0.05)
@export var tip_from: float = 0.3
## Left out of the sails (u min, u max, w max in the sail plane). Not needed for
## windmill.glb: where the lower blade crosses the door arch, the arch sits behind the
## blade's depth range.
@export var exclude: Vector3 = Vector3(0.0, 0.0, -10.0)
## Turns per second, roughly (radians per second).
@export var speed: float = 0.55

var _pivot: Node3D


func _ready() -> void:
	_setup.call_deferred()


func _process(delta: float) -> void:
	if _pivot and is_visible_in_tree():
		_pivot.rotate_object_local(Vector3.BACK, -speed * delta)


func get_pivot() -> Node3D:
	return _pivot


func _setup() -> void:
	var fitted := get_parent() as FittedModel
	if fitted == null or fitted.model == null:
		return
	var model := fitted.get_node_or_null(^"Model") as Node3D
	if model == null:
		return
	_apply_cut(model, false)
	_pivot = Node3D.new()
	_pivot.name = "SailPivot"
	# The pivot's local Z runs along the axle, so turning about it spins the sails in
	# their own plane.
	var axis := (model.transform.basis * axle).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	_pivot.transform = Transform3D(Basis(side, side.cross(axis) * -1.0, axis).orthonormalized(), model.transform * hub)
	fitted.add_child(_pivot)
	var sails := fitted.model.instantiate() as Node3D
	sails.name = "Sails"
	sails.transform = _pivot.transform.affine_inverse() * model.transform
	_pivot.add_child(sails)
	_apply_cut(sails, true)


func _apply_cut(root: Node3D, keep_inside: bool) -> void:
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.mesh == null:
			continue
		var source := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		if source:
			mat.set_shader_parameter(&"albedo_tex", source.albedo_texture)
			mat.set_shader_parameter(&"normal_tex", source.normal_texture)
			mat.set_shader_parameter(&"use_normal_map", source.normal_enabled and source.normal_texture != null)
			mat.set_shader_parameter(&"roughness_value", source.roughness)
		var to_mesh := _chain(mesh_instance, root).affine_inverse()
		var normal := (to_mesh.basis * axle).normalized()
		var u := normal.cross(Vector3.UP).normalized()
		var w := u.cross(normal).normalized()
		mat.set_shader_parameter(&"sail_mode", true)
		mat.set_shader_parameter(&"sail_hub", to_mesh * hub)
		mat.set_shader_parameter(&"sail_normal", normal)
		mat.set_shader_parameter(&"sail_u", u)
		mat.set_shader_parameter(&"sail_w", w)
		mat.set_shader_parameter(&"sail_depth", depth)
		mat.set_shader_parameter(&"sail_hub_radius", hub_radius)
		mat.set_shader_parameter(&"sail_arm_length", arm_length)
		mat.set_shader_parameter(&"sail_arm_half_width", arm_half_width)
		mat.set_shader_parameter(&"sail_arms", Vector4(deg_to_rad(arm_degrees.x), deg_to_rad(arm_degrees.y), deg_to_rad(arm_degrees.z), deg_to_rad(arm_degrees.w)))
		mat.set_shader_parameter(&"sail_arm_depth_min", arm_depth_min)
		mat.set_shader_parameter(&"sail_arm_depth_max", arm_depth_max)
		mat.set_shader_parameter(&"sail_tip_extra", tip_extra)
		mat.set_shader_parameter(&"sail_tip_from", tip_from)
		mat.set_shader_parameter(&"sail_exclude", exclude)
		mat.set_shader_parameter(&"keep_inside", keep_inside)
		mesh_instance.material_override = mat


## Transform of `node` relative to `root` (root's own transform not included).
static func _chain(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D()
	var current := node
	while current != null and current != root:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
