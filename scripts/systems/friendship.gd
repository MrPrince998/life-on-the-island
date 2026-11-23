extends Node
## Friendship (autoload): how close you are to each villager, in hearts.
##
##   Chatting:  the first conversation each day adds TALK_POINTS.
##   Gifts:     one gift per villager per day. Loved, liked, ordinary and disliked gifts
##              add different amounts; nothing ever lowers friendship.
##
## Each heart is POINTS_PER_HEART points, up to MAX_HEARTS. Reaching a heart sets story
## flags "hearts_<villager>_<n>" and "hearts_any_<n>" (GameManager), so quests, dialogue
## and the world can react. Talking and giving gifts never use in-game time.
##
## Saved through SaveManager's "persistent" group (save key "friendship").

signal friendship_changed(npc_id: StringName, points: int)
signal heart_gained(npc_id: StringName, hearts: int)

enum Taste { LOVED, LIKED, NEUTRAL, DISLIKED }

const POINTS_PER_HEART := 100
const MAX_HEARTS := 5
const TALK_POINTS := 10
## Playing the Serenade (ukulele) to a villager, once a day each.
const SERENADE_POINTS := 15
const GIFT_POINTS := {Taste.LOVED: 80, Taste.LIKED: 45, Taste.NEUTRAL: 20, Taste.DISLIKED: 5}
const DEFAULT_LINES := {
	Taste.LOVED: "Oh! I love this. Thank you so much!",
	Taste.LIKED: "How thoughtful of you. Thank you!",
	Taste.NEUTRAL: "That's kind of you. Thank you.",
	Taste.DISLIKED: "Oh… that's very kind. I'm sure I'll find a use for it.",
}
const SAVE_VERSION := 1

## npc id -> {"points": int, "talk_day": int, "gift_day": int}
var _state: Dictionary = {}


func _ready() -> void:
	add_to_group(&"persistent")


func reset() -> void:
	_state.clear()


func get_points(npc_id: StringName) -> int:
	return int(_entry(npc_id)["points"])


func get_hearts(npc_id: StringName) -> int:
	return mini(get_points(npc_id) / POINTS_PER_HEART, MAX_HEARTS)


## Progress towards the next heart, 0..1 (1 when all hearts are full).
func get_heart_progress(npc_id: StringName) -> float:
	if get_hearts(npc_id) >= MAX_HEARTS:
		return 1.0
	return float(get_points(npc_id) % POINTS_PER_HEART) / POINTS_PER_HEART


func talked_today(npc_id: StringName) -> bool:
	return int(_entry(npc_id)["talk_day"]) == ActivityClock.get_day()


func gifted_today(npc_id: StringName) -> bool:
	return int(_entry(npc_id)["gift_day"]) == ActivityClock.get_day()


## Items that can be given: anything in the item list except one-of-a-kind tools and
## story keepsakes (items with no price at all, such as Glowstone shards).
func is_giftable(item_id: StringName) -> bool:
	var item := ItemDB.get_item(item_id)
	return item != null and not item.unique and (item.buy_price > 0 or item.sell_price > 0)


## Giftable items in the bag, as [item_id, count] pairs.
func get_giftable_items() -> Array:
	var result := []
	var bag := InventoryManager.get_all()
	for item_id in bag:
		if is_giftable(item_id):
			result.append([item_id, bag[item_id]])
	return result


## Gift tastes you've found out by giving gifts: {item_id: Taste}.
func get_known_tastes(npc_id: StringName) -> Dictionary:
	var result := {}
	var known: Dictionary = _entry(npc_id).get("known", {})
	for key in known:
		result[StringName(str(key))] = int(known[key])
	return result


static func get_taste_name(taste: Taste) -> String:
	return ["loved", "liked", "neutral", "disliked"][taste]


func taste_for(npc: NPCData, item_id: StringName) -> Taste:
	if item_id in npc.loved_items:
		return Taste.LOVED
	if item_id in npc.disliked_items:
		return Taste.DISLIKED
	if item_id in npc.liked_items:
		return Taste.LIKED
	var item := ItemDB.get_item(item_id)
	if item and int(item.category) in npc.liked_categories:
		return Taste.LIKED
	return Taste.NEUTRAL


## The first chat of the day. Returns the points gained (0 if already chatted today).
func record_talk(npc_id: StringName) -> int:
	if talked_today(npc_id):
		return 0
	_entry(npc_id)["talk_day"] = ActivityClock.get_day()
	return _add_points(npc_id, TALK_POINTS)


## The Serenade played for a villager. Returns the points gained (0 if they've
## already been serenaded today).
func record_serenade(npc_id: StringName) -> int:
	if serenaded_today(npc_id):
		return 0
	_entry(npc_id)["serenade_day"] = ActivityClock.get_day()
	return _add_points(npc_id, SERENADE_POINTS)


func serenaded_today(npc_id: StringName) -> bool:
	return int(_entry(npc_id).get("serenade_day", 0)) == ActivityClock.get_day()


## Gives one item. Returns {"ok", "reason", "taste", "points", "line"}.
func give_gift(npc: NPCData, item_id: StringName) -> Dictionary:
	if npc == null:
		return {"ok": false, "reason": "nobody"}
	if gifted_today(npc.id):
		return {"ok": false, "reason": "already_gifted", "line": "%s already has your gift today. Come back tomorrow!" % npc.display_name}
	if not is_giftable(item_id):
		return {"ok": false, "reason": "not_giftable"}
	if InventoryManager.remove_item(item_id, 1) != 1:
		return {"ok": false, "reason": "not_in_bag"}
	var taste := taste_for(npc, item_id)
	_entry(npc.id)["gift_day"] = ActivityClock.get_day()
	# Remember what you've learned about their taste (shown in the journal).
	var known: Dictionary = _entry(npc.id).get("known", {})
	known[String(item_id)] = int(taste)
	_entry(npc.id)["known"] = known
	var gained := _add_points(npc.id, int(GIFT_POINTS[taste]))
	QuestLog.record_event(&"gift")
	QuestLog.record_event(StringName("gift_" + String(npc.id)))
	return {"ok": true, "reason": "", "taste": taste, "points": gained, "line": _line_for(npc, taste)}


func _line_for(npc: NPCData, taste: Taste) -> String:
	var custom := ""
	match taste:
		Taste.LOVED:
			custom = npc.loved_line
		Taste.LIKED:
			custom = npc.liked_line
		Taste.NEUTRAL:
			custom = npc.neutral_line
		Taste.DISLIKED:
			custom = npc.disliked_line
	return custom if not custom.is_empty() else String(DEFAULT_LINES[taste])


## Friendship from other sources (quest rewards...). Returns the points gained.
func add_points(npc_id: StringName, amount: int) -> int:
	return _add_points(npc_id, amount) if amount > 0 else 0


func _add_points(npc_id: StringName, amount: int) -> int:
	var entry := _entry(npc_id)
	var before_hearts := get_hearts(npc_id)
	var cap := POINTS_PER_HEART * MAX_HEARTS
	var before := int(entry["points"])
	entry["points"] = mini(before + amount, cap)
	var gained := int(entry["points"]) - before
	if gained > 0:
		friendship_changed.emit(npc_id, int(entry["points"]))
	var hearts := get_hearts(npc_id)
	for h in range(before_hearts + 1, hearts + 1):
		GameManager.set_flag(StringName("hearts_%s_%d" % [npc_id, h]))
		GameManager.set_flag(StringName("hearts_any_%d" % h))
		heart_gained.emit(npc_id, h)
	return gained


func _entry(npc_id: StringName) -> Dictionary:
	if not _state.has(npc_id):
		_state[npc_id] = {"points": 0, "talk_day": 0, "gift_day": 0, "serenade_day": 0}
	return _state[npc_id]


# ---- SaveManager hook ---------------------------------------------------------------

func get_save_key() -> String:
	return "friendship"


func save_state() -> Dictionary:
	var villagers := {}
	for npc_id in _state:
		villagers[String(npc_id)] = (_state[npc_id] as Dictionary).duplicate()
	return {"version": SAVE_VERSION, "villagers": villagers}


func load_state(data: Dictionary) -> void:
	_state.clear()
	var villagers: Variant = data.get("villagers", {})
	if typeof(villagers) != TYPE_DICTIONARY:
		return
	for key in villagers:
		var entry: Variant = villagers[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_state[StringName(str(key))] = {
			"points": clampi(int(entry.get("points", 0)), 0, POINTS_PER_HEART * MAX_HEARTS),
			"talk_day": int(entry.get("talk_day", 0)),
			"gift_day": int(entry.get("gift_day", 0)),
			"serenade_day": int(entry.get("serenade_day", 0)),
			"known": (entry.get("known", {}) as Dictionary).duplicate() if typeof(entry.get("known", {})) == TYPE_DICTIONARY else {},
		}
