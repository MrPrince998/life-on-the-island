class_name CraftingSpot
extends Interactable
## A place where you turn one thing into another (press E): the sawhorse in Grandpa's
## yard saws 2 wood into 1 plank. Works through as many batches as you have materials
## for (up to `max_batches`), each taking `minutes_per_batch` of in-game time (an
## activity, D-001).

signal crafted(spot: CraftingSpot, batches: int)

const SWING_LENGTH := 1.3

@export var input_item: StringName = &"wood"
@export var input_amount: int = 2
@export var output_item: StringName = &"wooden_plank"
@export var output_amount: int = 1
@export var minutes_per_batch: int = 15
@export var max_batches: int = 10
@export var verb_text: String = "Saw planks"
@export var quest_event: StringName = &"saw_planks"
## Shown when you don't have enough to make one batch.
@export_multiline var missing_message: String = ""

var _working: bool = false


func get_prompt() -> String:
	return "%s  (%d %s → %d %s · you have %d)" % [verb_text, input_amount, _name(input_item), output_amount,
			_name(output_item), InventoryManager.get_count(input_item)]


## How many batches can be made right now.
func get_batches() -> int:
	var by_input := InventoryManager.get_count(input_item) / maxi(input_amount, 1)
	var by_room := InventoryManager.get_room_for(output_item) / maxi(output_amount, 1)
	return mini(mini(by_input, by_room), max_batches)


func _on_interact(interactor: Node) -> void:
	if _working:
		return
	if get_batches() <= 0:
		GameManager.notify(missing_message if InventoryManager.get_count(input_item) < input_amount else "Your bag is full. Make some room first.")
		return
	_working = true
	var player := interactor as PlayerController
	if player:
		player.set_input_locked(true)
		var to_spot := global_position - player.global_position
		player.face_yaw(atan2(-to_spot.x, -to_spot.z))
		var animator := player.get_node_or_null(^"Visual/Character") as CharacterAnimator
		for i in 2:
			if animator:
				animator.play_action(&"farm_swing")
			await get_tree().create_timer(SWING_LENGTH).timeout
	craft_now()
	if player:
		player.set_input_locked(false)
	_working = false


## Makes as many batches as possible at once. Returns the number of batches.
func craft_now() -> int:
	var batches := get_batches()
	if batches <= 0:
		return 0
	InventoryManager.remove_item(input_item, batches * input_amount)
	InventoryManager.add_item(output_item, batches * output_amount)
	ActivityClock.advance_minutes(batches * minutes_per_batch, &"crafting")
	if quest_event != &"":
		QuestLog.record_event(quest_event, batches * output_amount)
	GameManager.notify("You made %d %s." % [batches * output_amount, _name(output_item).to_lower() + ("" if batches * output_amount == 1 else "s")])
	crafted.emit(self, batches)
	return batches


static func _name(item_id: StringName) -> String:
	return ItemDB.get_display_name(item_id)
