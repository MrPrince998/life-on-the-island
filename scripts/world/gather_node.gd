class_name GatherNode
extends Interactable
## Something you can gather by hand (press E): a pile of fallen branches gives wood,
## a cracked rock gives stone. Gathering is an activity: it takes `gather_minutes` of
## in-game time (D-001). The spot is then empty and grows back after `regrow_days`
## new mornings. No tools needed, nothing can fail.
##
## Children that are Node3D (the model) are hidden while the spot is empty.
## Saved through the "persistent" group (save key gather_<interaction_id>).

signal gathered(node: GatherNode, item_id: StringName, amount: int)

const SWING_LENGTH := 1.3

@export var item_id: StringName = &"wood"
@export var amount_min: int = 2
@export var amount_max: int = 3
@export var gather_minutes: int = 10
@export var regrow_days: int = 2
## The word in the prompt: "Gather wood", "Gather stone".
@export var verb_text: String = "Gather"

## The day it was last gathered (-1 = never: ready).
var gathered_day: int = -1
var _working: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"gather_node")
	_rng.seed = hash(interaction_id)
	ActivityClock.day_started.connect(func(_day: int) -> void: _apply())
	_apply()


func is_ready() -> bool:
	return gathered_day < 0 or ActivityClock.get_day() >= gathered_day + regrow_days


func get_prompt() -> String:
	return "%s %s  (%d min)" % [verb_text, ItemDB.get_display_name(item_id).to_lower(), gather_minutes]


func _on_interact(interactor: Node) -> void:
	if _working or not is_ready():
		return
	if InventoryManager.get_room_for(item_id) <= 0:
		GameManager.notify("Your bag is full. Make some room first (Grandpa's chest is in the cottage).")
		return
	_working = true
	var player := interactor as PlayerController
	if player:
		player.set_input_locked(true)
		var to_spot := global_position - player.global_position
		player.face_yaw(atan2(-to_spot.x, -to_spot.z))
		var animator := player.get_node_or_null(^"Visual/Character") as CharacterAnimator
		if animator:
			animator.play_action(&"farm_swing")
		await get_tree().create_timer(SWING_LENGTH).timeout
	gather_now()
	if player:
		player.set_input_locked(false)
	_working = false


## Gathers at once (no animation). Returns how many items went into the bag.
func gather_now() -> int:
	if not is_ready():
		return 0
	var wanted := _rng.randi_range(amount_min, amount_max)
	var added := InventoryManager.add_item(item_id, wanted)
	if added <= 0:
		GameManager.notify("Your bag is full. Make some room first (Grandpa's chest is in the cottage).")
		return 0
	gathered_day = ActivityClock.get_day()
	if gather_minutes > 0:
		ActivityClock.advance_minutes(gather_minutes, &"gathering")
	QuestLog.record_event(StringName("gather_" + String(item_id)), added)
	GameManager.notify("+%d %s" % [added, ItemDB.get_display_name(item_id)])
	gathered.emit(self, item_id, added)
	_apply()
	return added


func _apply() -> void:
	var ready := is_ready()
	enabled = ready
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D:
			(child as Node3D).visible = ready
			# Switched off while empty, so a gathered rock doesn't block the way.
			child.process_mode = Node.PROCESS_MODE_INHERIT if ready else Node.PROCESS_MODE_DISABLED


# ---- SaveManager hook ---------------------------------------------------------

func get_save_key() -> String:
	return "gather_%s" % interaction_id


func save_state() -> Dictionary:
	return {"gathered_day": gathered_day}


func load_state(data: Dictionary) -> void:
	gathered_day = int(data.get("gathered_day", -1))
	_apply()
