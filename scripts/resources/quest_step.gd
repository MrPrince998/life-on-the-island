class_name QuestStep
extends Resource
## One step of a quest, shown in the quest tracker. It ticks itself off when its
## condition is met:
##   FLAG        story flag `target` is on (GameManager), e.g. "met_oliver"
##   HAVE_ITEM   you carry at least `amount` of item `target` (shows 3/8)
##   HAVE_COINS  you have at least `amount` coins
##   EVENT       `amount` of event `target` happened since this step began
##               (QuestLog.record_event: "dig", "plant", "harvest", "catch_fish", ...)
##   TALK        talk to villager `target` (their NPCData id)
##   DELIVER     bring villager `target` the `items` ({item_id: amount}); they're
##               handed over when you talk to them with everything in your bag
##   SPECIES     you've caught `amount` different kinds of fish (the fish journal)
##   FLAG_COUNT  `amount` story flags starting with `target` are on (e.g. "journal_page_")
## Once ticked off, a step stays done.

enum Kind { FLAG, HAVE_ITEM, HAVE_COINS, EVENT, TALK, DELIVER, SPECIES, FLAG_COUNT }

@export var text: String = ""
@export var kind: Kind = Kind.FLAG
@export var target: StringName = &""
@export var amount: int = 1
## Optional: this event also ticks the step off (e.g. a FLAG step "met_emma" that also
## completes on "open_shop", for when Emma isn't around).
@export var or_event: StringName = &""
## DELIVER: what to bring, {item_id: amount}.
@export var items: Dictionary = {}
## TALK / DELIVER: what the villager says when you hand it over or talk to them.
@export var lines: PackedStringArray = PackedStringArray()
## TALK / DELIVER: in-game minutes spent together when handing over (an activity,
## e.g. helping Theo carve a bench). 0 = no time.
@export var minutes: int = 0


## Progress shown in the tracker ("" when the step is a single thing to do).
func shows_count() -> bool:
	if kind == Kind.DELIVER:
		return get_delivery_total() > 1
	if kind == Kind.TALK:
		return false
	return amount > 1 or kind == Kind.HAVE_COINS


## Total number of things to bring (DELIVER).
func get_delivery_total() -> int:
	var total := 0
	for item_id in items:
		total += int(items[item_id])
	return total
