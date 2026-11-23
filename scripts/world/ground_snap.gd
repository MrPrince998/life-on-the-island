@tool
extends Node3D
## Places this node on the island's ground when the scene loads, so props stay
## on the terrain even if the landform is tweaked.

@export var snap_to_ground: bool = true
@export var height_offset: float = 0.0


func _ready() -> void:
	if snap_to_ground:
		var p := global_position
		global_position = Vector3(p.x, IslandShape.shared().get_height(p.x, p.z) + height_offset, p.z)
