@tool
extends Node
## Hides parts of a model (for example a closed gate, so the gateway can be walked
## through). Put this node next to the model and list boxes to hide, in metres in the
## parent's space (the same space as the parent scene's other children).
## The model keeps its own textures (shaders/model_cutout.gdshader).

const SHADER := preload("res://shaders/model_cutout.gdshader")

## The model node (sibling) whose meshes get the cut.
@export var model_path: NodePath = ^"../Model"
## Boxes to hide, in the parent's space (metres). Up to 4.
@export var cut_boxes: Array[AABB] = []


func _ready() -> void:
	apply()


func apply() -> void:
	var model := get_node_or_null(model_path) as Node3D
	if model == null:
		return
	var parent := get_parent() as Node3D
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
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
		# Boxes from the parent's space into this mesh's own space.
		var to_mesh := _local_chain(mesh_instance, parent).affine_inverse()
		var mins := PackedVector3Array()
		var maxs := PackedVector3Array()
		for box in cut_boxes.slice(0, 4):
			var local_box: AABB = to_mesh * box
			mins.append(local_box.position)
			maxs.append(local_box.end)
		while mins.size() < 4:
			mins.append(Vector3.ZERO)
			maxs.append(Vector3.ZERO)
		mat.set_shader_parameter(&"cut_count", mini(cut_boxes.size(), 4))
		mat.set_shader_parameter(&"cut_min", mins)
		mat.set_shader_parameter(&"cut_max", maxs)
		mesh_instance.material_override = mat


## Transform of `node` relative to `ancestor`, from the nodes' local transforms (works
## before the scene is in the tree).
func _local_chain(node: Node, ancestor: Node) -> Transform3D:
	var xf := Transform3D()
	var current := node
	while current != null and current != ancestor:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf
