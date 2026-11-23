class_name RainEffect
extends GPUParticles3D
## Falling rain (or, in winter, drifting snow) around the camera, following
## WeatherManager. Pure decoration: no collision, no effect on time. Hidden indoors.

const AREA := 36.0
const HEIGHT_ABOVE_CAMERA := 9.0

enum Mode { NONE, RAIN, SNOW }

var _mode: int = -1
var _rain_material: ParticleProcessMaterial
var _snow_material: ParticleProcessMaterial
var _rain_mesh: QuadMesh
var _snow_mesh: QuadMesh


func _ready() -> void:
	top_level = true
	local_coords = false
	preprocess = 1.0
	visibility_aabb = AABB(Vector3(-AREA, -30.0, -AREA), Vector3(AREA * 2.0, 40.0, AREA * 2.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_rain()
	_build_snow()
	_apply_mode(_wanted_mode())
	WeatherManager.weather_changed.connect(func(_w: int) -> void: _apply_mode(_wanted_mode()))


## What's falling right now (for tests): "rain", "snow" or "".
func get_falling() -> String:
	if not emitting:
		return ""
	return "snow" if _mode == Mode.SNOW else "rain"


func _wanted_mode() -> int:
	if WeatherManager.is_snowing():
		return Mode.SNOW
	if WeatherManager.is_raining():
		return Mode.RAIN
	return Mode.NONE


func _apply_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	match mode:
		Mode.RAIN:
			amount = 2600
			lifetime = 1.0
			process_material = _rain_material
			draw_pass_1 = _rain_mesh
		Mode.SNOW:
			amount = 1800
			lifetime = 6.0
			process_material = _snow_material
			draw_pass_1 = _snow_mesh
	emitting = mode != Mode.NONE


func _build_rain() -> void:
	_rain_material = ParticleProcessMaterial.new()
	_rain_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_material.emission_box_extents = Vector3(AREA * 0.5, 0.5, AREA * 0.5)
	_rain_material.direction = Vector3(0.08, -1.0, 0.03)
	_rain_material.spread = 2.0
	_rain_material.initial_velocity_min = 15.0
	_rain_material.initial_velocity_max = 18.0
	_rain_material.gravity = Vector3(0, -6.0, 0)
	_rain_material.scale_min = 0.7
	_rain_material.scale_max = 1.2
	_rain_mesh = QuadMesh.new()
	_rain_mesh.size = Vector2(0.018, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.82, 0.88, 0.95, 0.38)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	_rain_mesh.material = material


func _build_snow() -> void:
	_snow_material = ParticleProcessMaterial.new()
	_snow_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_snow_material.emission_box_extents = Vector3(AREA * 0.5, 0.5, AREA * 0.5)
	_snow_material.direction = Vector3(0.15, -1.0, 0.05)
	_snow_material.spread = 25.0
	_snow_material.initial_velocity_min = 1.2
	_snow_material.initial_velocity_max = 2.0
	_snow_material.gravity = Vector3(0, -0.6, 0)
	# Flakes wander a little as they fall.
	_snow_material.turbulence_enabled = true
	_snow_material.turbulence_noise_strength = 1.2
	_snow_material.turbulence_noise_speed = Vector3(0.2, 0.0, 0.15)
	_snow_material.turbulence_influence_min = 0.05
	_snow_material.turbulence_influence_max = 0.12
	_snow_material.scale_min = 0.6
	_snow_material.scale_max = 1.3
	_snow_mesh = QuadMesh.new()
	_snow_mesh.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	var flake := GradientTexture2D.new()
	flake.fill = GradientTexture2D.FILL_RADIAL
	flake.fill_from = Vector2(0.5, 0.5)
	flake.fill_to = Vector2(1.0, 0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	flake.gradient = gradient
	flake.width = 32
	flake.height = 32
	material.albedo_texture = flake
	_snow_mesh.material = material


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + Vector3.UP * HEIGHT_ABOVE_CAMERA
		# Nothing falls indoors (the cottage interior and other rooms).
		var indoors := InteriorRoom.is_indoors(get_tree(), camera.global_position)
		visible = not indoors
		var want := _mode != Mode.NONE and not indoors
		if emitting != want:
			emitting = want
