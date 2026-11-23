class_name RegionArea
extends Area3D
## Marks a named island region. When the player walks in, the HUD shows its name.
## region_id is the stable ID used by saves, quests and unlocks.

@export var region_id: StringName = &""
@export var display_name: String = ""
## Higher priority wins when regions overlap (e.g. the dock inside the lake region).
@export var region_priority: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.enter_region(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.exit_region(self)
