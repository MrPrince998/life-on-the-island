class_name StoryPickup
extends ItemPickup
## An ItemPickup that is also a story step: taking it sets `sets_flag` (for example the
## first Glowstone shard sets "shard_1"). Saved like any pickup.
##
## Optional: it can wait for an earlier story step (`requires_flag`) and only be
## reachable at some hours (`open_from_hour`..`open_to_hour`), like the sea cave at
## low tide in the morning. Outside those, pressing E just shows a message.

@export var sets_flag: StringName = &""
@export var requires_flag: StringName = &""
@export_multiline var locked_message: String = ""
## -1 = any time. Otherwise reachable from this hour...
@export var open_from_hour: int = -1
## ...until this hour (exclusive).
@export var open_to_hour: int = 24
@export_multiline var closed_message: String = ""


func is_unlocked() -> bool:
	return requires_flag == &"" or GameManager.has_flag(requires_flag)


func is_open_now() -> bool:
	if open_from_hour < 0:
		return true
	var hour := ActivityClock.get_hour()
	return hour >= open_from_hour and hour < open_to_hour


func _on_interact(interactor: Node) -> void:
	if is_taken:
		return
	if not is_unlocked():
		if not locked_message.is_empty():
			GameManager.notify(locked_message)
		return
	if not is_open_now():
		if not closed_message.is_empty():
			GameManager.notify(closed_message)
		return
	super._on_interact(interactor)
	if is_taken and sets_flag != &"" and not GameManager.has_flag(sets_flag):
		GameManager.set_flag(sets_flag)
