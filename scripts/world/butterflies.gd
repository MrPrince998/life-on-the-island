class_name Butterflies
extends CPUParticles3D
## A few butterflies drifting over an area (the fields after Chapter 1). Built in code;
## pure decoration, real-time only.

@export var area: Vector3 = Vector3(30.0, 2.0, 22.0)
@export var count: int = 40


func _ready() -> void:
	amount = count
	lifetime = 9.0
	preprocess = 9.0
	randomness = 0.6
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = area * 0.5
	direction = Vector3(1, 0.15, 0)
	spread = 180.0
	gravity = Vector3.ZERO
	initial_velocity_min = 0.4
	initial_velocity_max = 1.1
	angular_velocity_min = -40.0
	angular_velocity_max = 40.0
	scale_amount_min = 0.7
	scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.82, 0.3))
	ramp.set_color(1, Color(0.95, 0.95, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.25))
	ramp.add_point(0.7, Color(0.55, 0.75, 1.0))
	color_initial_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34, 0.27)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/butterfly.gdshader")
	quad.material = material
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 120.0
	emitting = true
