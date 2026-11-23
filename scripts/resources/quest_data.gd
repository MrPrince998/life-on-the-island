class_name QuestData
extends Resource
## A quest: a few steps done in order. Add one by making a .tres in data/quests/ and
## listing it in data/quests/quest_catalog.tres.
##
## A quest starts when the game starts (starts_active), when story flag `start_flag`
## turns on, or when the quest named in another quest's `next_quest` is finished.
## Nothing is timed and nothing can fail.

## Stable ID used by saves. Never rename.
@export var id: StringName = &""
@export var title: String = ""
## Who asked ("Grandpa's letter", "Oliver"...), shown under the title.
@export var giver: String = ""
@export_multiline var description: String = ""
@export var steps: Array[QuestStep] = []
@export var starts_active: bool = false
@export var start_flag: StringName = &""
## Started automatically when this quest is finished.
@export var next_quest: StringName = &""
@export var reward_coins: int = 0
## Items given when finished, {item_id: amount}.
@export var reward_items: Dictionary = {}
## Story flags turned on when finished (world changes listen to these).
@export var reward_flags: Array[StringName] = []
## Friendship points with the giver when finished (100 = one heart).
@export var reward_friendship: int = 0

@export_group("Villager quest")
## The villager who offers this quest in conversation ("" = not offered by anyone).
@export var giver_id: StringName = &""
## Hearts with the giver needed before they ask (after you've met them).
@export var offer_hearts: int = 1
## Also needed before they ask: a finished quest and/or a story flag.
@export var requires_quest: StringName = &""
@export var requires_flag: StringName = &""
## What the villager says when asking.
@export var offer_lines: PackedStringArray = PackedStringArray()
## Shown when the quest is finished.
@export_multiline var complete_message: String = ""
