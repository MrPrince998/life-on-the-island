class_name ItemData
extends Resource
## One kind of item the player can carry, buy or sell.
## Add an item by making a .tres in data/items/ and listing it in data/items/item_catalog.tres.
## Fish don't need one: ItemDB makes item entries for every fish in the fish catalog.

enum Category { FISH, SEED, TOOL, MATERIAL, FOOD, MISC }

## Stable ID used by saves, inventory and shops. Never rename.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.MISC
## Coins the store charges. 0 = the store doesn't sell it.
@export var buy_price: int = 0
## Coins the store pays. 0 = can't be sold.
@export var sell_price: int = 0
## How many fit in one bag slot.
@export var max_stack: int = 99
## Tools: you only ever need one, so the store stops selling it once you own it.
@export var unique: bool = false
@export var icon: Texture2D


func get_category_name() -> String:
	return ["Fish", "Seeds", "Tool", "Material", "Food", "Misc"][category]
