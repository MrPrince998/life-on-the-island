class_name MachineRecipe
extends Resource
## One thing a ProcessingMachine can do: `input_amount` of `input_item` in, `outputs` out,
## taking `minutes_per_batch` of in-game time per batch. (The pedal thresher has one for
## rice sheaves and one for wheat sheaves.)

@export var input_item: StringName = &""
@export var input_amount: int = 1
## What one batch makes: item id -> amount.
@export var outputs: Dictionary = {}
@export var minutes_per_batch: int = 5
@export var quest_event: StringName = &""
