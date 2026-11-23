class_name LighthouseBeam
extends Node3D
## The lighthouse's sweeping beam: a soft cone of light turning slowly over the sea,
## at night, once the lens is mended (story flag `requires_flag`). Real-time rotation,
## purely visual; never touches the activity clock.

@export var requires_flag: StringName = &"lighthouse_lit"
@export var beam_length: float = 90.0
@export var turns_per_minute: float = 4.0

var _arm: Node3D
var _spot: SpotLight3D


func _ready() -> void:
	_arm = Node3D.new()
	_arm.name = "Arm"
	add_child(_arm)
	# A long, faint cone pointing out from the lamp (two of them, back to back).
	for side in [1.0, -1.0]:
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 4.0
		mesh.height = beam_length
		mesh.radial_segments = 24
		mesh.cap_top = false
		mesh.cap_bottom = false
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(1.0, 0.9, 0.62, 0.05)
		mesh.material = material
		cone.mesh = mesh
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Lay the cylinder on its side, narrow end at the lamp.
		cone.rotation_degrees = Vector3(-90.0 * side, 0, 0)
		cone.position = Vector3(0, -1.5, -beam_length * 0.5 * side)
		_arm.add_child(cone)
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.9, 0.65)
	_spot.light_energy = 6.0
	_spot.spot_range = beam_length
	_spot.spot_angle = 6.0
	_spot.rotation_degrees = Vector3(-4, 0, 0)
	_arm.add_child(_spot)
	ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _apply())
	GameManager.flag_changed.connect(func(_f: StringName, _v: bool) -> void: _apply())
	_apply()


func is_shining() -> bool:
	var hour := ActivityClock.get_hour()
	return GameManager.has_flag(requires_flag) and (hour >= 19 or hour < 6)


func _process(delta: float) -> void:
	if visible:
		_arm.rotate_y(-TAU * turns_per_minute / 60.0 * delta)


func _apply() -> void:
	visible = is_shining()
