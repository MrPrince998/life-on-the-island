class_name TidePool
extends MeshInstance3D
## A pool of sea water that floods a spot except at low tide (the sea cave's mouth is
## dry only in the morning). Follows ActivityClock; purely visual. A round pool sitting
## just above the highest ground under it.

@export var radius: float = 2.8
## Dry (low tide) from this hour until `dry_to_hour` (exclusive).
@export var dry_from_hour: int = 6
@export var dry_to_hour: int = 10
@export var water_material: Material


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.06
	disc.radial_segments = 32
	mesh = disc
	if water_material:
		material_override = water_material
	# Sit just above the highest ground under the pool, so it covers the whole floor.
	var shape := IslandShape.shared()
	var top := -INF
	for i in 9:
		var offset := Vector2.ZERO if i == 0 else Vector2.from_angle(TAU * i / 8.0) * radius * 0.9
		var p := Vector2(global_position.x, global_position.z) + offset
		top = maxf(top, shape.get_height(p.x, p.y))
	global_position.y = top + 0.12
	ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _apply())
	_apply()


func is_dry() -> bool:
	var hour := ActivityClock.get_hour()
	return hour >= dry_from_hour and hour < dry_to_hour


func _apply() -> void:
	visible = not is_dry()
