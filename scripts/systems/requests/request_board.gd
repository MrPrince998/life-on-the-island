extends Node
## RequestBoard (autoload): the village notice board's daily requests.
##
## Each morning, villagers you've met pin small requests on the board in the village
## square ("Nana Bea would love 3 Carrots for a hearty stew"). Read the board (E) and
## take a request: it becomes a quest in the tracker, and handing the things over to
## that villager finishes it for coins and friendship (QuestLog runtime quests).
##
## Cozy rules: requests never fail. A request nobody takes is quietly replaced after
## STAY_DAYS days; a request you took waits as long as you like. Only things you can get
## in the current season are asked for. Reading the board costs no time.
##
## Saved through SaveManager's "persistent" group (save key "requests").

signal board_changed

const SLOTS := 3
## How many requests you can be helping with at once.
const MAX_ACTIVE := 3
## An untaken request stays up this many days before a new one replaces it.
const STAY_DAYS := 3
const FRIENDSHIP_POINTS := 30
const ID_PREFIX := "request_"
const SAVE_VERSION := 1
## Villagers who pin requests (the captain is only passing through).
const GIVERS: Array[String] = [
	"res://data/npcs/emma.tres", "res://data/npcs/oliver.tres", "res://data/npcs/mia.tres",
	"res://data/npcs/theo.tres", "res://data/npcs/nana_bea.tres", "res://data/npcs/pip.tres",
	"res://data/npcs/ambrose.tres", "res://data/npcs/luna.tres",
]
const MATERIALS: Array[StringName] = [&"wood", &"stone", &"wooden_plank"]
const REASONS := {
	&"fish": ["for supper tonight", "to share with a neighbour", "for a little fish pie", "to try a new recipe"],
	&"crop": ["for a hearty stew", "to fill the pantry", "for a picnic by the lake", "to bake something nice"],
	&"material": ["to mend a fence", "for a small repair", "to build a planter", "to fix a wobbly shelf"],
	&"dish": ["for a cosy dinner", "to cheer up a friend", "for a little celebration", "after a long day"],
	&"flower": ["to brighten the window", "for a pretty vase", "to make someone smile"],
}
const THANKS: Array[String] = [
	"Oh, %s! You remembered. Thank you so much!",
	"Just what I needed: %s. You're a kind neighbour.",
	"Perfect, %s! Here, take this for your trouble.",
	"You brought %s? That made my whole day.",
]

var board_seed: int = 0
## Requests finished (all time).
var completed: int = 0
## Each slot: {"request": Dictionary (empty when free), "refill_day": int}
var _slots: Array = []
var _next_id: int = 1
## The last day the board was read (for the "new requests" marker).
var _read_day: int = 0
var _npcs: Dictionary = {}


func _ready() -> void:
	add_to_group(&"persistent")
	for path in GIVERS:
		var npc := load(path) as NPCData
		if npc:
			_npcs[npc.id] = npc
	ActivityClock.day_started.connect(func(_day: int) -> void: top_up())
	QuestLog.quest_completed.connect(_on_quest_completed)
	# Meeting someone new: they may pin a request straight away.
	GameManager.flag_changed.connect(func(flag: StringName, value: bool) -> void:
		if value and String(flag).begins_with("met_") and _npcs.has(StringName(String(flag).trim_prefix("met_"))):
			top_up())
	reset()


## New game: an empty board with a fresh shuffle of requests ahead.
func reset() -> void:
	board_seed = randi()
	completed = 0
	_next_id = 1
	_read_day = 0
	_slots.clear()
	for i in SLOTS:
		_slots.append({"request": {}, "refill_day": 0})
	board_changed.emit()


# ---- Reading the board ----------------------------------------------------------------

## The requests pinned on the board right now (filling any free spots first).
func get_requests() -> Array[Dictionary]:
	top_up()
	var result: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		if not (slot["request"] as Dictionary).is_empty():
			result.append(slot["request"])
	return result


## Requests you've taken and not finished yet (their quests).
func get_active() -> Array[QuestData]:
	var result: Array[QuestData] = []
	for quest in QuestLog.get_active_quests():
		if is_request(quest.id):
			result.append(quest)
	return result


static func is_request(quest_id: StringName) -> bool:
	return String(quest_id).begins_with(ID_PREFIX)


## True when requests are waiting that you haven't seen yet (the board shows a "!").
func has_news() -> bool:
	for slot: Dictionary in _slots:
		var request: Dictionary = slot["request"]
		if not request.is_empty() and int(request.get("posted", 0)) > _read_day:
			return true
	return false


## The board was read: nothing new until the next requests go up.
func mark_read() -> void:
	if _read_day != ActivityClock.get_day():
		_read_day = ActivityClock.get_day()
		board_changed.emit()


## Why the board is empty, if it is ("" when it isn't).
func get_empty_reason() -> String:
	if not get_requests().is_empty():
		return ""
	if _met_givers().is_empty():
		return "The board is bare. Say hello to the villagers: they'll pin up requests once they know you."
	return "All of today's requests have been taken. New ones go up every morning."


## A short line for the morning message ("" when there's nothing new).
func get_morning_note() -> String:
	return "New requests are pinned on the village notice board." if has_news() else ""


# ---- Taking a request -----------------------------------------------------------------

## Takes a request off the board. Returns {"ok": bool, "reason": String, "quest": QuestData}.
func accept(request_id: StringName) -> Dictionary:
	for slot: Dictionary in _slots:
		var request: Dictionary = slot["request"]
		if request.is_empty() or StringName(str(request.get("id"))) != request_id:
			continue
		if get_active().size() >= MAX_ACTIVE:
			return {"ok": false, "reason": "You're already helping with %d requests. Finish one first!" % MAX_ACTIVE}
		var quest := make_quest(request)
		if quest == null or not QuestLog.add_runtime_quest(quest):
			return {"ok": false, "reason": "That request can't be taken right now."}
		slot["request"] = {}
		# A fresh request goes up in this spot tomorrow morning.
		slot["refill_day"] = ActivityClock.get_day() + 1
		board_changed.emit()
		return {"ok": true, "reason": "", "quest": quest}
	return {"ok": false, "reason": "That request isn't on the board any more."}


## The quest for a request: hand the things over to the villager who asked.
func make_quest(request: Dictionary) -> QuestData:
	var npc: NPCData = _npcs.get(StringName(str(request.get("giver", ""))))
	var item_id := StringName(str(request.get("item", "")))
	var amount := int(request.get("amount", 1))
	if npc == null or not ItemDB.has_item(item_id):
		return null
	var what := amount_text(item_id, amount)
	var step := QuestStep.new()
	step.kind = QuestStep.Kind.DELIVER
	step.target = npc.id
	step.items = {item_id: amount}
	step.text = "Bring %s to %s" % [what, npc.display_name]
	step.lines = PackedStringArray([str(request.get("thanks", "Thank you!"))])
	var quest := QuestData.new()
	quest.id = StringName(str(request.get("id")))
	quest.title = "%s for %s" % [what.substr(0, 1).to_upper() + what.substr(1), npc.display_name]
	quest.giver = npc.display_name
	quest.giver_id = npc.id
	quest.description = str(request.get("text", ""))
	quest.reward_coins = int(request.get("coins", 0))
	quest.reward_friendship = FRIENDSHIP_POINTS
	quest.steps.append(step)
	return quest


# ---- Pinning up requests --------------------------------------------------------------

## Fills free spots (and replaces requests nobody took for STAY_DAYS days).
func top_up() -> void:
	var today := ActivityClock.get_day()
	var changed := false
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var request: Dictionary = slot["request"]
		if not request.is_empty() and today - int(request.get("posted", today)) >= STAY_DAYS:
			slot["request"] = {}
			request = {}
			changed = true
		if request.is_empty() and int(slot["refill_day"]) <= today:
			var made := _make_request(today, i)
			if not made.is_empty():
				slot["request"] = made
				changed = true
	if changed:
		board_changed.emit()


func _make_request(day: int, slot_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([board_seed, day, slot_index, _next_id])
	var givers := _free_givers()
	if givers.is_empty():
		return {}
	var npc: NPCData = givers[rng.randi() % givers.size()]
	var choices := _candidates(npc)
	if choices.is_empty():
		return {}
	var total := 0.0
	for choice: Array in choices:
		total += float(choice[2])
	var roll := rng.randf() * total
	var pick: Array = choices[-1]
	for choice: Array in choices:
		roll -= float(choice[2])
		if roll <= 0.0:
			pick = choice
			break
	var item_id: StringName = pick[0]
	var kind: StringName = pick[1]
	var price := _price(item_id)
	var amount := _amount_for(price, rng)
	var what := amount_text(item_id, amount)
	var reasons: Array = REASONS.get(kind, REASONS[&"crop"])
	var id := "%s%d" % [ID_PREFIX, _next_id]
	_next_id += 1
	return {
		"id": id,
		"giver": String(npc.id),
		"item": String(item_id),
		"amount": amount,
		"coins": reward_for(price, amount),
		"posted": day,
		"text": "%s would love %s %s." % [npc.display_name, what, reasons[rng.randi() % reasons.size()]],
		"thanks": THANKS[rng.randi() % THANKS.size()] % what,
	}


## Villagers you've met who aren't already asking for something.
func _free_givers() -> Array[NPCData]:
	var busy := {}
	for slot: Dictionary in _slots:
		var request: Dictionary = slot["request"]
		if not request.is_empty():
			busy[StringName(str(request.get("giver")))] = true
	for quest in get_active():
		busy[quest.giver_id] = true
	var result: Array[NPCData] = []
	for npc in _met_givers():
		if not busy.has(npc.id):
			result.append(npc)
	return result


func _met_givers() -> Array[NPCData]:
	var result: Array[NPCData] = []
	for npc: NPCData in _npcs.values():
		if GameManager.has_flag(StringName("met_" + String(npc.id))):
			result.append(npc)
	return result


## [item_id, kind, weight] for everything this villager might ask for right now:
## fish that bite this season (not the rare ones), crops you can plant this season,
## building materials, and dishes you know how to cook. Favourites come up more often.
func _candidates(npc: NPCData) -> Array:
	var season := ActivityClock.get_season_id()
	var found := {}
	var fish_catalog := load("res://data/fish/fish_catalog.tres") as FishCatalog
	for fish in fish_catalog.fish:
		if fish.rarity != FishData.Rarity.RARE and fish.is_in_season(season):
			found[fish.id] = &"fish"
	for crop in CropCatalog.shared().crops:
		if crop.grows_in(season):
			found[crop.harvest_item_id] = &"flower" if crop.harvest_item_id == &"sunflower" else &"crop"
	for item_id in MATERIALS:
		found[item_id] = &"material"
	for recipe in CookingService.get_recipes():
		if CookingService.is_known(recipe):
			found[recipe.result_item] = &"dish"
	var result: Array = []
	for item_id: StringName in found:
		if not ItemDB.has_item(item_id) or item_id in npc.disliked_items:
			continue
		var weight := 1.0
		if item_id in npc.loved_items:
			weight = 4.0
		elif item_id in npc.liked_items:
			weight = 2.5
		result.append([item_id, found[item_id], weight])
	return result


func _price(item_id: StringName) -> int:
	var item := ItemDB.get_item(item_id)
	return maxi(item.sell_price if item else 5, 1)


## Cheap things come by the handful, dear ones one at a time.
static func _amount_for(price: int, rng: RandomNumberGenerator) -> int:
	if price <= 5:
		return rng.randi_range(5, 8)
	if price <= 16:
		return rng.randi_range(3, 4)
	if price <= 40:
		return rng.randi_range(2, 3)
	if price <= 100:
		return rng.randi_range(1, 2)
	return 1


## Always a bit better than selling the same things at the store.
static func reward_for(price: int, amount: int) -> int:
	return maxi(roundi((price * amount * 1.5 + 20.0) / 5.0) * 5, 25)


## "3 Carrots", "a Pumpkin", "5 Wood", "2 Grilled Fish".
static func amount_text(item_id: StringName, amount: int) -> String:
	var name := ItemDB.get_display_name(item_id)
	var lower := name.to_lower()
	# Dishes come in bowls and plates ("a bowl of Turnip Soup", "2 plates of Roasted Carrots").
	var dish := ""
	if lower.ends_with("soup") or lower.ends_with("stew"):
		dish = "bowl"
	elif lower.ends_with("s") and ItemDB.get_item(item_id) and ItemDB.get_item(item_id).category == ItemData.Category.FOOD:
		dish = "plate"
	if dish != "":
		return "a %s of %s" % [dish, name] if amount == 1 else "%d %ss of %s" % [amount, dish, name]
	if amount == 1:
		if name.contains("'s "):
			return "one " + name  # "one Nana's Garden Pie"
		return ("an " if name.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name
	if lower.ends_with("s") or lower.ends_with("fish") or lower.ends_with("bream") or lower.ends_with("mackerel") \
			or lower in ["wood", "stone", "kale"] or lower.ends_with("soup") or lower.ends_with("stew"):
		return "%d %s" % [amount, name]
	if lower.ends_with("o"):
		return "%d %ses" % [amount, name]
	return "%d %ss" % [amount, name]


func _on_quest_completed(quest: QuestData) -> void:
	if is_request(quest.id):
		completed += 1
		QuestLog.record_event(&"board_request")
		board_changed.emit()


# ---- SaveManager hook -----------------------------------------------------------------

func get_save_key() -> String:
	return "requests"


func save_state() -> Dictionary:
	var slots: Array = []
	for slot: Dictionary in _slots:
		slots.append({"request": (slot["request"] as Dictionary).duplicate(), "refill_day": int(slot["refill_day"])})
	return {"version": SAVE_VERSION, "seed": board_seed, "completed": completed, "next_id": _next_id, "read_day": _read_day, "slots": slots}


func load_state(data: Dictionary) -> void:
	board_seed = int(data.get("seed", board_seed))
	completed = maxi(int(data.get("completed", 0)), 0)
	_next_id = maxi(int(data.get("next_id", 1)), 1)
	_read_day = maxi(int(data.get("read_day", 0)), 0)
	_slots.clear()
	var saved: Variant = data.get("slots", [])
	for i in SLOTS:
		var slot := {"request": {}, "refill_day": 0}
		if typeof(saved) == TYPE_ARRAY and i < (saved as Array).size() and typeof(saved[i]) == TYPE_DICTIONARY:
			var request: Variant = saved[i].get("request", {})
			if typeof(request) == TYPE_DICTIONARY and _npcs.has(StringName(str((request as Dictionary).get("giver", "")))) \
					and ItemDB.has_item(StringName(str((request as Dictionary).get("item", "")))):
				slot["request"] = request
			slot["refill_day"] = int(saved[i].get("refill_day", 0))
		_slots.append(slot)
	board_changed.emit()
