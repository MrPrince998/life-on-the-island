extends MeshInstance3D
## Shows Grandpa's watering can (the same model the player holds while watering),
## standing on the ground. Used for Grandpa's can by the garden shed.

const MODEL := preload("res://scenes/props/watering_can_model.tscn")


func _ready() -> void:
	mesh = null
	var model := MODEL.instantiate() as Node3D
	# The model's origin is the handle; lift it so the can's base sits where this node is.
	model.position.y = -(model.get_node("Base") as Node3D).position.y
	add_child(model)
