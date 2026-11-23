class_name RecipeData
extends Resource
## One dish you can cook at Grandpa's stove. Ingredients are {item_id: amount}; the
## special id "any_fish" takes any fish from your bag (the cheapest first, so rare
## catches are kept). Some recipes are taught by villagers (`requires_flag`).

## Stable ID used by quests ("cook_<id>"). Never rename.
@export var id: StringName = &""
@export var ingredients: Dictionary = {}
@export var result_item: StringName = &""
@export var result_amount: int = 1
## In-game minutes per dish (cooking is an activity, D-001).
@export var minutes: int = 30
## Story/friendship flag needed to know this recipe ("" = known from the start).
@export var requires_flag: StringName = &""
## Shown while the recipe is still unknown.
@export var unlock_hint: String = ""
