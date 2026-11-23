extends Node
## QuestLog (autoload): which quests are active, which step each is on, and ticking
## steps off as the player plays. The quest tracker (under the minimap) shows it.
##
## Steps check themselves against story flags, the bag and coins whenever those change,
## and against events that gameplay reports with record_event() ("dig", "plant",
## "harvest", "catch_fish", "sell_crop", "sell_fish"...). Quests never fail or expire,
## and the quest log never changes in-game time.
##
## Saved through SaveManager's "persistent" group (save key "quests").

signal quest_started(quest: QuestData)
## A quest started during play (not at the start of a new game or on load).
signal quest_announced(quest: QuestData)
signal step_completed(quest: QuestData, step_index: int)
signal quest_updated(quest: QuestData)
signal quest_completed(quest: QuestData)

enum Status { INACTIVE, ACTIVE, DONE }

const CATALOG_PATH := "res://data/quests/quest_catalog.tres"
const SAVE_VERSION := 1

var catalog: QuestCatalog
## quest id -> {"status": Status, "step": int, "count": int}
var _state: Dictionary = {}
## Active and finished quests, in the order they started.
var _order: Array[StringName] = []


func _ready() -> void:
	add_to_group(&"persistent")
	catalog = load(CATALOG_PATH) as QuestCatalog
	GameManager.flag_changed.connect(_on_flag_changed)
	InventoryManager.inventory_changed.connect(func(_i: StringName, _n: int) -> void: _check_all())
	InventoryManager.money_changed.connect(func(_m: int) -> void: _check_all())
	# Fish-species steps follow the fish journal.
	Journal.fish_recorded.connect(_on_fish_recorded)
	reset()


## New game: the starting quests (and any whose start flag is already on).
func reset() -> void:
	_state.clear()
	_order.clear()
	if catalog == null:
		return
	for quest in catalog.quests:
		_state[quest.id] = {"status": Status.INACTIVE, "step": 0, "count": 0}
	for quest in catalog.quests:
		if quest.starts_active or (quest.start_flag != &"" and GameManager.has_flag(quest.start_flag)):
			_start(quest, false)


# ---- Reading ----------------------------------------------------------------------

func get_status(quest_id: StringName) -> Status:
	return int(_state.get(quest_id, {}).get("status", Status.INACTIVE)) as Status


func is_active(quest_id: StringName) -> bool:
	return get_status(quest_id) == Status.ACTIVE


func is_done(quest_id: StringName) -> bool:
	return get_status(quest_id) == Status.DONE


## Active quests, oldest first.
func get_active_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for quest_id in _order:
		if is_active(quest_id):
			result.append(catalog.get_quest(quest_id))
	return result


func get_step_index(quest_id: StringName) -> int:
	return int(_state.get(quest_id, {}).get("step", 0))


func get_current_step(quest_id: StringName) -> QuestStep:
	var quest := catalog.get_quest(quest_id)
	var index := get_step_index(quest_id)
	return quest.steps[index] if quest and index < quest.steps.size() else null


## How far along the current step is: Vector2i(done, needed).
func get_step_progress(quest_id: StringName) -> Vector2i:
	var step := get_current_step(quest_id)
	if step == null:
		return Vector2i.ZERO
	if step.kind == QuestStep.Kind.DELIVER:
		var have := 0
		for item_id in step.items:
			have += mini(InventoryManager.get_count(StringName(str(item_id))), int(step.items[item_id]))
		return Vector2i(have, step.get_delivery_total())
	return Vector2i(mini(_step_value(step, _state[quest_id]), step.amount), step.amount)


# ---- Updating -----------------------------------------------------------------------

## Gameplay reports things the player did. Steps waiting for this event move on.
func record_event(event_id: StringName, amount: int = 1) -> void:
	for quest_id in _order:
		if not is_active(quest_id):
			continue
		var step := get_current_step(quest_id)
		if step == null:
			continue
		if step.kind == QuestStep.Kind.EVENT and step.target == event_id:
			_state[quest_id]["count"] = int(_state[quest_id]["count"]) + amount
			_check(catalog.get_quest(quest_id))
		elif step.or_event == event_id:
			_state[quest_id]["or_done"] = true
			_check(catalog.get_quest(quest_id))


## Starts a quest (if it hasn't started yet). Returns true if it started now.
func start_quest(quest_id: StringName) -> bool:
	var quest := catalog.get_quest(quest_id) if catalog else null
	if quest == null or get_status(quest_id) != Status.INACTIVE:
		return false
	_start(quest, true)
	return true


func _start(quest: QuestData, announce: bool) -> void:
	_state[quest.id] = {"status": Status.ACTIVE, "step": 0, "count": 0}
	if not quest.id in _order:
		_order.append(quest.id)
	# The quest tracker announces new quests itself, so other messages (like Oliver's
	# gift) aren't covered up by a second toast.
	quest_started.emit(quest)
	if announce:
		quest_announced.emit(quest)
	_check(quest)


func _check_all() -> void:
	for quest_id in _order.duplicate():
		if is_active(quest_id):
			_check(catalog.get_quest(quest_id))


func _check(quest: QuestData) -> void:
	if quest == null or not is_active(quest.id):
		return
	var state: Dictionary = _state[quest.id]
	var advanced := false
	while int(state["step"]) < quest.steps.size():
		var step: QuestStep = quest.steps[int(state["step"])]
		if _step_value(step, state) < step.amount:
			break
		var done_index := int(state["step"])
		state["step"] = done_index + 1
		state["count"] = 0
		state.erase("or_done")
		advanced = true
		step_completed.emit(quest, done_index)
	if int(state["step"]) >= quest.steps.size():
		_complete(quest)
		return
	if advanced:
		quest_updated.emit(quest)


func _step_value(step: QuestStep, state: Dictionary) -> int:
	if bool(state.get("or_done", false)):
		return step.amount
	match step.kind:
		QuestStep.Kind.TALK, QuestStep.Kind.DELIVER:
			# Done only when handed over in conversation (turn_in sets or_done).
			return 0
		QuestStep.Kind.SPECIES:
			return Journal.species_caught()
		QuestStep.Kind.FLAG_COUNT:
			var count := 0
			for flag in GameManager.flags_to_dict().get("flags", []):
				if String(flag).begins_with(String(step.target)):
					count += 1
			return count
		QuestStep.Kind.FLAG:
			return step.amount if GameManager.has_flag(step.target) else 0
		QuestStep.Kind.HAVE_ITEM:
			return InventoryManager.get_count(step.target)
		QuestStep.Kind.HAVE_COINS:
			return InventoryManager.get_money()
		QuestStep.Kind.EVENT:
			return int(state.get("count", 0))
	return 0


func _complete(quest: QuestData) -> void:
	_state[quest.id]["status"] = Status.DONE
	if quest.reward_coins > 0:
		InventoryManager.add_money(quest.reward_coins)
	var gifts: Array[String] = []
	for item_id in quest.reward_items:
		var amount := int(quest.reward_items[item_id])
		var added := InventoryManager.add_item(StringName(str(item_id)), amount)
		if added > 0:
			gifts.append("%d %s" % [added, ItemDB.get_display_name(StringName(str(item_id)))])
	if quest.reward_friendship > 0 and quest.giver_id != &"":
		Friendship.add_points(quest.giver_id, quest.reward_friendship)
	for flag in quest.reward_flags:
		GameManager.set_flag(flag)
	var text := "Quest complete: %s!" % quest.title
	if quest.reward_coins > 0:
		text += "  +%d coins" % quest.reward_coins
	if not gifts.is_empty():
		text += "  +" + ", ".join(gifts)
	if not quest.complete_message.is_empty():
		text += "  " + quest.complete_message
	GameManager.notify(text)
	quest_completed.emit(quest)
	if quest.next_quest != &"":
		start_quest(quest.next_quest)


func _on_fish_recorded(_fish_id: StringName, _size: float, _new: bool, _record: bool) -> void:
	_check_all()


# ---- Villager quests ----------------------------------------------------------------

## A quest this villager would like to ask you about now (or null): not started yet,
## you've met them, you're friends enough, and anything it needs first is done.
func get_offer_for(npc_id: StringName) -> QuestData:
	if catalog == null:
		return null
	for quest in catalog.quests:
		if quest.giver_id != npc_id or get_status(quest.id) != Status.INACTIVE:
			continue
		if not GameManager.has_flag(StringName("met_" + String(npc_id))):
			continue
		if Friendship.get_hearts(npc_id) < quest.offer_hearts:
			continue
		if quest.requires_quest != &"" and not is_done(quest.requires_quest):
			continue
		if quest.requires_flag != &"" and not GameManager.has_flag(quest.requires_flag):
			continue
		return quest
	return null


## Starts a quest the villager just asked about.
func accept_offer(quest_id: StringName) -> bool:
	return start_quest(quest_id)


## An active quest waiting for you to talk to this villager (and, for a delivery, with
## everything in your bag), or null.
func get_turn_in_for(npc_id: StringName) -> QuestData:
	for quest_id in _order:
		if not is_active(quest_id):
			continue
		var step := get_current_step(quest_id)
		if step == null or step.target != npc_id:
			continue
		if step.kind == QuestStep.Kind.TALK:
			return catalog.get_quest(quest_id)
		if step.kind == QuestStep.Kind.DELIVER and _has_delivery(step):
			return catalog.get_quest(quest_id)
	return null


## A quest step waiting on this villager that you can't hand over yet (or null).
func get_waiting_step_for(npc_id: StringName) -> QuestStep:
	for quest_id in _order:
		if is_active(quest_id):
			var step := get_current_step(quest_id)
			if step and step.kind == QuestStep.Kind.DELIVER and step.target == npc_id and not _has_delivery(step):
				return step
	return null


## Hands over the current TALK/DELIVER step (taking the items) and returns what the
## villager says. Empty when nothing could be handed over.
func turn_in(quest_id: StringName) -> PackedStringArray:
	var quest := catalog.get_quest(quest_id) if catalog else null
	if quest == null or not is_active(quest_id):
		return PackedStringArray()
	var step := get_current_step(quest_id)
	if step == null or not step.kind in [QuestStep.Kind.TALK, QuestStep.Kind.DELIVER]:
		return PackedStringArray()
	if step.kind == QuestStep.Kind.DELIVER:
		if not _has_delivery(step):
			return PackedStringArray()
		for item_id in step.items:
			InventoryManager.remove_item(StringName(str(item_id)), int(step.items[item_id]))
	var lines := step.lines
	if step.minutes > 0:
		ActivityClock.advance_minutes(step.minutes, &"quest")
	_state[quest_id]["or_done"] = true
	_check(quest)
	if lines.is_empty():
		lines = PackedStringArray(["Thank you!"])
	return lines


func _has_delivery(step: QuestStep) -> bool:
	for item_id in step.items:
		if InventoryManager.get_count(StringName(str(item_id))) < int(step.items[item_id]):
			return false
	return true


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if value and catalog:
		for quest in catalog.quests:
			if quest.start_flag == flag and get_status(quest.id) == Status.INACTIVE:
				_start(quest, true)
	_check_all()


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "quests"


func save_state() -> Dictionary:
	var quests := {}
	for quest_id in _state:
		quests[String(quest_id)] = (_state[quest_id] as Dictionary).duplicate()
	var order: Array[String] = []
	for quest_id in _order:
		order.append(String(quest_id))
	return {"version": SAVE_VERSION, "quests": quests, "order": order}


func load_state(data: Dictionary) -> void:
	var saved: Variant = data.get("quests", {})
	if typeof(saved) != TYPE_DICTIONARY or catalog == null:
		return
	_state.clear()
	_order.clear()
	for quest in catalog.quests:
		var entry: Variant = (saved as Dictionary).get(String(quest.id))
		if typeof(entry) == TYPE_DICTIONARY:
			_state[quest.id] = {
				"status": clampi(int(entry.get("status", 0)), 0, Status.DONE),
				"step": clampi(int(entry.get("step", 0)), 0, quest.steps.size()),
				"count": maxi(int(entry.get("count", 0)), 0),
			}
		else:
			_state[quest.id] = {"status": Status.INACTIVE, "step": 0, "count": 0}
	var order: Variant = data.get("order", [])
	if typeof(order) == TYPE_ARRAY:
		for quest_id in order:
			var id := StringName(str(quest_id))
			if _state.has(id) and not id in _order:
				_order.append(id)
	for quest in catalog.quests:
		if get_status(quest.id) != Status.INACTIVE and not quest.id in _order:
			_order.append(quest.id)
	# Quests added after this save was made: start them if they would have started.
	for quest in catalog.quests:
		if not (saved as Dictionary).has(String(quest.id)):
			if quest.starts_active or (quest.start_flag != &"" and GameManager.has_flag(quest.start_flag)):
				_start(quest, false)
	for quest in catalog.quests:
		quest_updated.emit(quest)
	_check_all()
