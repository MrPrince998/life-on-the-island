extends Node3D
## Shows Grandpa's ukulele (the same model the player plays), e.g. lying in the cottage.


func _ready() -> void:
	add_child(UkuleleVisuals.model())
