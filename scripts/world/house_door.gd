class_name HouseDoor
extends Interactable
## A door you press E on to go inside or back out. The screen fades, the player is
## moved to `destination` (a Marker3D; its -Z is the way you then face) and the
## screen fades back. Going through a door costs no time.

signal passed_through(door: HouseDoor)

@export var destination: NodePath
@export var fade_seconds: float = 0.28
## Optional story flag needed first (the rowboat to the lake isle waits for the
## lighthouse); "" = always open.
@export var requires_flag: StringName = &""
@export_multiline var locked_message: String = ""

var _busy: bool = false


func _on_interact(interactor: Node) -> void:
	var player := interactor as PlayerController
	var target := get_node_or_null(destination) as Node3D
	if _busy or player == null or target == null:
		return
	if requires_flag != &"" and not GameManager.has_flag(requires_flag):
		if not locked_message.is_empty():
			GameManager.notify(locked_message)
		return
	_busy = true
	player.set_input_locked(true)
	var fade := ScreenFade.get_instance(get_tree())
	await fade.fade_to(1.0, fade_seconds)
	player.teleport_to(target.global_position, target.global_rotation.y)
	await get_tree().physics_frame
	await get_tree().physics_frame
	passed_through.emit(self)
	await fade.fade_to(0.0, fade_seconds)
	player.set_input_locked(false)
	_busy = false


func is_busy() -> bool:
	return _busy
