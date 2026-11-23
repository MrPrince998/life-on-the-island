extends MeshInstance3D
## Shows Grandpa's ukulele (the same mesh the player plays), e.g. lying in the cottage.


func _ready() -> void:
	mesh = UkuleleVisuals.mesh()
