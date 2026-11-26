class_name NPCData
extends Resource
## Everything that makes a villager who they are: name, model, animations, what they
## say and where they spend the day. One .tres per villager in data/npcs/.

## Stable ID for saves and quests.
@export var id: StringName
@export var display_name: String = ""
@export var role: String = ""
@export var model: PackedScene
## Built by tools/build_npc_animations.gd from the Mixamo clips.
@export var animations: AnimationLibrary
@export var model_scale: float = 1.75
@export var walk_speed: float = 1.25
## Colour multiplied into the model's materials (white = as modelled). Lets a stand-in
## model look like someone else until their own model is made.
@export var tint: Color = Color.WHITE

@export_group("Talking")
## First conversation. `intro_action` runs when line `intro_action_line` is shown.
@export var intro_lines: PackedStringArray = PackedStringArray()
## What has to be true for the intro to play: "" = only the first time you meet,
## "no_rod" = whenever the player doesn't have a fishing rod yet.
@export var intro_needs: StringName = &""
@export var intro_action: StringName = &""
@export var intro_action_line: int = -1
## After the intro: one of these, picked in turn.
@export var later_lines: PackedStringArray = PackedStringArray()

## Extra lines once you're good friends (FRIEND_LINES_HEARTS hearts or more), mixed in
## with later_lines.
@export var friend_lines: PackedStringArray = PackedStringArray()

## Story conversations: {flag: PackedStringArray}. The first chat after one of these
## story flags turns on plays that conversation (if several are on, the one listed last
## wins, so list them in story order); after that it's back to everyday lines.
@export var story_lines: Dictionary = {}

@export_group("Gifts")
## Items this villager loves / likes / would rather not have. Anything else is a
## pleasant "thank you". Gifts never lower friendship.
@export var loved_items: Array[StringName] = []
@export var liked_items: Array[StringName] = []
## Whole kinds of item they like (ItemData.Category values, e.g. 0 = fish).
@export var liked_categories: Array[int] = []
@export var disliked_items: Array[StringName] = []
## What they say for each kind of gift ("" = a friendly default).
@export var loved_line: String = ""
@export var liked_line: String = ""
@export var neutral_line: String = ""
@export var disliked_line: String = ""

@export_group("Day")
@export var schedule: Array[NPCScheduleEntry] = []
## Until this story flag is set, the villager keeps to `early_schedule` instead (Theo
## stays by the broken bridge, on the village side of the creek, until it's rebuilt).
@export var schedule_flag: StringName = &""
@export var early_schedule: Array[NPCScheduleEntry] = []


## The schedule in use right now (see schedule_flag).
func get_active_schedule() -> Array[NPCScheduleEntry]:
	if schedule_flag != &"" and not early_schedule.is_empty() and not GameManager.has_flag(schedule_flag):
		return early_schedule
	return schedule


## The schedule entry for an hour of the day (the last one that has started; before
## the first entry of the day, yesterday's last entry is still going).
func entry_for_hour(hour: int) -> NPCScheduleEntry:
	var entries := get_active_schedule()
	if entries.is_empty():
		return null
	var best: NPCScheduleEntry = null
	for entry in entries:
		if entry.from_hour <= hour and (best == null or entry.from_hour >= best.from_hour):
			best = entry
	if best:
		return best
	for entry in entries:
		if best == null or entry.from_hour > best.from_hour:
			best = entry
	return best
