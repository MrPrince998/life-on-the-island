class_name ProcessingMachine
extends Interactable
## A machine that turns one thing into others, worked by hand (press E): the pedal
## thresher beats rice or wheat sheaves into grain and straw; the huller rubs the husks off
## rice; the windmill's millstones grind wheat into flour. It works through as many
## batches as you have (up to `max_batches` per recipe), each taking its minutes of
## in-game time (an activity). While it works, `spinner` turns and `particles` puff.
##
## What it does comes from `recipes` (MachineRecipe). The single input_item / outputs
## fields are the simple one-recipe form, used when `recipes` is empty.

signal processed(machine: ProcessingMachine, batches: int)

@export var recipes: Array[MachineRecipe] = []
@export var input_item: StringName = &"rice_sheaf"
@export var input_amount: int = 1
## What one batch makes: item id -> amount.
@export var outputs: Dictionary = {}
@export var minutes_per_batch: int = 5
@export var max_batches: int = 20
@export var verb_text: String = "Thresh the rice"
@export var quest_event: StringName = &"thresh_rice"
## Spins while working (the thresher's drum, the huller's crank wheel).
@export var spinner_path: NodePath
@export var spin_axis: Vector3 = Vector3.RIGHT
@export var spin_speed: float = 14.0
@export var particles_path: NodePath
## Shown when you have nothing to put in.
@export_multiline var missing_message: String = ""
## Only works once this story flag is set (&"" = always), e.g. the restored windmill.
@export var requires_flag: StringName = &""

var _working := false
var _spin := 0.0


func is_working() -> bool:
	return _working


## The recipes this machine knows.
func get_recipes() -> Array[MachineRecipe]:
	if not recipes.is_empty():
		return recipes
	var single := MachineRecipe.new()
	single.input_item = input_item
	single.input_amount = input_amount
	single.outputs = outputs
	single.minutes_per_batch = minutes_per_batch
	single.quest_event = quest_event
	return [single]


func get_prompt() -> String:
	var all := get_recipes()
	# Show what you can put in now (or the first recipe, as a hint).
	var shown: Array[String] = []
	for recipe in all:
		var have := InventoryManager.get_count(recipe.input_item)
		if have >= recipe.input_amount or all.size() == 1:
			shown.append("%d %s → %s · you have %d" % [recipe.input_amount, _name(recipe.input_item, recipe.input_amount), _outputs_text(recipe), have])
	if shown.is_empty():
		var hint: Array[String] = []
		for recipe in all:
			hint.append(_name(recipe.input_item, 2))
		return "%s  (needs %s)" % [verb_text, " or ".join(hint)]
	return "%s  (%s · %d min each)" % [verb_text, "; ".join(shown), all[0].minutes_per_batch]


func can_interact_now(player: Node) -> bool:
	if requires_flag != &"" and not GameManager.has_flag(requires_flag):
		return false
	return not _working and not (player is PlayerController and (player as PlayerController).is_hands_busy())


## How many batches can be made right now, over all recipes (materials and bag space).
func get_batches() -> int:
	var total := 0
	for recipe in get_recipes():
		total += _batches_for(recipe)
	return total


func _batches_for(recipe: MachineRecipe) -> int:
	var batches := mini(InventoryManager.get_count(recipe.input_item) / maxi(recipe.input_amount, 1), max_batches)
	while batches > 0 and not _fits(recipe, batches):
		batches -= 1
	return batches


func _on_interact(interactor: Node) -> void:
	if _working:
		return
	var batches := get_batches()
	if batches <= 0:
		var any_input := get_recipes().any(func(r: MachineRecipe) -> bool: return InventoryManager.get_count(r.input_item) >= r.input_amount)
		GameManager.notify("Your bag is full. Make some room first." if any_input else missing_message)
		return
	_working = true
	var player := interactor as PlayerController
	if player:
		player.set_input_locked(true)
		var to_spot := global_position - player.global_position
		player.face_yaw(atan2(-to_spot.x, -to_spot.z))
	var particles := get_node_or_null(particles_path) as CPUParticles3D
	if particles:
		particles.emitting = true
	# A little real time to watch it work (longer for bigger loads, but never a chore).
	await get_tree().create_timer(clampf(0.9 + batches * 0.3, 1.2, 4.0)).timeout
	if particles:
		particles.emitting = false
	process_now(batches)
	if player:
		player.set_input_locked(false)
	_working = false


## Processes everything you have (no animation), up to `limit` batches in all
## (-1 = no limit). Returns how many batches were done.
func process_now(limit: int = -1) -> int:
	if requires_flag != &"" and not GameManager.has_flag(requires_flag):
		return 0
	var done := 0
	var made: Array[String] = []
	for recipe in get_recipes():
		var batches := _batches_for(recipe)
		if limit >= 0:
			batches = mini(batches, limit - done)
		if batches <= 0:
			continue
		InventoryManager.remove_item(recipe.input_item, recipe.input_amount * batches)
		for item_id: StringName in recipe.outputs:
			var amount := int(recipe.outputs[item_id]) * batches
			InventoryManager.add_item(item_id, amount)
			made.append("%d %s" % [amount, _name(item_id, amount)])
		ActivityClock.advance_minutes(recipe.minutes_per_batch * batches, recipe.quest_event if recipe.quest_event != &"" else &"processing")
		if recipe.quest_event != &"":
			QuestLog.record_event(recipe.quest_event, batches)
		done += batches
	if done > 0:
		GameManager.notify("+" + ", +".join(made))
		processed.emit(self, done)
	return done


func _process(delta: float) -> void:
	var spinner := get_node_or_null(spinner_path) as Node3D
	if spinner == null:
		return
	var target := spin_speed if _working else 0.0
	_spin = lerpf(_spin, target, 1.0 - exp(-3.0 * delta))
	if absf(_spin) > 0.01:
		spinner.rotate_object_local(spin_axis.normalized(), _spin * delta)


func _fits(recipe: MachineRecipe, batches: int) -> bool:
	for item_id: StringName in recipe.outputs:
		var amount := int(recipe.outputs[item_id]) * batches
		# The inputs leave the bag first, which can free a slot.
		var room := InventoryManager.get_room_for(item_id)
		if recipe.input_amount * batches >= InventoryManager.get_count(recipe.input_item) and room < amount:
			room += ItemDB.get_max_stack(item_id)
		if room < amount:
			return false
	return true


func _outputs_text(recipe: MachineRecipe) -> String:
	var parts: Array[String] = []
	for item_id: StringName in recipe.outputs:
		parts.append("%d %s" % [int(recipe.outputs[item_id]), _name(item_id, int(recipe.outputs[item_id]))])
	return " + ".join(parts)


static func _name(item_id: StringName, amount: int) -> String:
	return BlacksmithService.item_name(item_id, amount)
