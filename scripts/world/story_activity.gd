class_name StoryActivity
extends Interactable
## A story job you do on the spot (press E): clearing brambles with Mia, planting the
## orchard. It can wait for an earlier story step (`requires_flag`), takes
## `work_minutes` of in-game time (an activity, D-001), plays a few work swings, then
## sets `sets_flag` (saved with the game). The world reacts to the flag (StoryVariant).

signal finished(activity: StoryActivity)

const SWING_LENGTH := 1.3

@export var requires_flag: StringName = &""
@export_multiline var locked_message: String = ""
@export var sets_flag: StringName = &""
@export var work_minutes: int = 60
@export var work_swings: int = 3
@export_multiline var done_message: String = ""
## Event reported to the quest log when done ("" = none).
@export var quest_event: StringName = &""

var _working: bool = false


func _ready() -> void:
	GameManager.flag_changed.connect(func(_flag: StringName, _value: bool) -> void: _apply())
	_apply()


func is_done() -> bool:
	return sets_flag != &"" and GameManager.has_flag(sets_flag)


func is_unlocked() -> bool:
	return requires_flag == &"" or GameManager.has_flag(requires_flag)


func get_prompt() -> String:
	if not is_unlocked():
		return "Look"
	return "%s  (%s)" % [prompt_text, _hours(work_minutes)]


func _on_interact(interactor: Node) -> void:
	if _working or is_done():
		return
	if not is_unlocked():
		GameManager.notify(locked_message)
		return
	_working = true
	var player := interactor as PlayerController
	var animator: CharacterAnimator = null
	if player:
		player.set_input_locked(true)
		var to_spot := global_position - player.global_position
		player.face_yaw(atan2(-to_spot.x, -to_spot.z))
		animator = player.get_node_or_null(^"Visual/Character") as CharacterAnimator
	for i in work_swings:
		if animator:
			animator.play_action(&"farm_swing")
		await get_tree().create_timer(SWING_LENGTH).timeout
	finish_now()
	if player:
		player.set_input_locked(false)
	_working = false


## Does the job at once (no animation). Used by the swings and by tests.
func finish_now() -> bool:
	if is_done() or not is_unlocked():
		return false
	if work_minutes > 0:
		ActivityClock.advance_minutes(work_minutes, &"story")
	if sets_flag != &"":
		GameManager.set_flag(sets_flag)
	if quest_event != &"":
		QuestLog.record_event(quest_event)
	if not done_message.is_empty():
		GameManager.notify(done_message)
	finished.emit(self)
	return true


func _apply() -> void:
	enabled = not is_done()


static func _hours(minutes: int) -> String:
	if minutes < 60:
		return "%d min" % minutes
	if minutes % 60 == 0:
		return "%d hour%s" % [minutes / 60, "" if minutes == 60 else "s"]
	return "%.1f hours" % (minutes / 60.0)
