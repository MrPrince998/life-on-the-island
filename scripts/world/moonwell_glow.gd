class_name MoonwellGlow
extends OmniLight3D
## The Moonwell: a soft blue light deep under Moonlit Lake, seen only at night. Faint at
## first, a little brighter for every Glowstone found, and bright once the lighthouse
## shines again (the island answers you).

const SHARD_FLAGS: Array[StringName] = [&"shard_1", &"shard_2", &"shard_3", &"shard_4", &"shard_5"]

@export var base_energy: float = 0.6
@export var per_shard: float = 0.5
@export var lit_energy: float = 6.0
## Radius of the soft glow seen through the water (metres).
@export var halo_radius: float = 16.0

var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D


func _ready() -> void:
	light_color = Color(0.45, 0.85, 1.0)
	_make_halo()
	ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _apply())
	GameManager.flag_changed.connect(func(_f: StringName, _v: bool) -> void: _apply())
	_apply()


func get_target_energy() -> float:
	if GameManager.has_flag(&"lighthouse_lit"):
		return lit_energy
	var found := 0
	for flag in SHARD_FLAGS:
		if GameManager.has_flag(flag):
			found += 1
	return base_energy + per_shard * found


func _apply() -> void:
	var hour := ActivityClock.get_hour()
	var night := hour >= 19 or hour < 5
	light_energy = get_target_energy() if night else 0.0
	visible = night
	if _halo_material:
		_halo_material.albedo_color.a = clampf(light_energy / lit_energy, 0.0, 1.0) * 0.75


## A soft round glow just under the lake's surface, so the water itself seems to shine.
func _make_halo() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.95, 1.0, 1.0))
	gradient.set_color(1, Color(0.2, 0.6, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_material.albedo_texture = texture
	var plane := PlaneMesh.new()
	plane.size = Vector2(halo_radius * 2.0, halo_radius * 2.0)
	plane.material = _halo_material
	_halo = MeshInstance3D.new()
	_halo.name = "Halo"
	_halo.mesh = plane
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# Just under the surface of Moonlit Lake (the isle pokes up through it).
	_halo.top_level = true
	_halo.global_position = Vector3(global_position.x, IslandShape.LAKE_LEVEL - 0.25, global_position.z)
