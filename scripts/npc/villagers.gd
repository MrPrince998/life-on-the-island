extends Node3D
## Holds the villagers. Sits exactly where the Island node is, so schedule positions
## (island coordinates) line up with the terrain even if the island is moved.


func _enter_tree() -> void:
	var island := get_parent().get_node_or_null(^"Island") as Node3D if get_parent() else null
	if island:
		transform = island.transform
