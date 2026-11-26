class_name ToolRecipe
extends Resource
## A tool Bram the blacksmith makes (data/tools/*.tres, listed in forge_catalog.tres).
## Two ways to get it at the forge:
##   Forge it - bring the materials and pay a smaller fee; you wait while he works
##              (forge_minutes of in-game time: an activity).
##   Buy it   - pay the full price for one he made earlier. No waiting.

## The item you get (an ItemData id, e.g. &"axe").
@export var item_id: StringName = &""
## Coins for a ready-made one (0 = not sold ready-made).
@export var buy_price: int = 0
## Coins for forging it from your own materials.
@export var forge_fee: int = 0
## Materials you bring: item id -> how many.
@export var materials: Dictionary = {}
## In-game minutes you wait while he forges it.
@export var forge_minutes: int = 60
## What Bram says about it.
@export_multiline var pitch: String = ""
