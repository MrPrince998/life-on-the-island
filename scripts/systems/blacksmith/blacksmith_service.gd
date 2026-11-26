class_name BlacksmithService
extends RefCounted
## Bram's forge: getting tools by forging them from your own materials (cheaper, but you
## wait while he works: an activity) or buying one ready-made (dearer, no wait).
## Talking and browsing cost no time.

const CATALOG_PATH := "res://data/tools/forge_catalog.tres"

enum Result { OK, NOT_ENOUGH_MONEY, MISSING_MATERIALS, ALREADY_OWNED, BAG_FULL, NOT_SOLD, UNKNOWN }

const MESSAGES := {
	Result.OK: "Done!",
	Result.NOT_ENOUGH_MONEY: "You haven't the coins for that just yet.",
	Result.MISSING_MATERIALS: "You'll need to bring the materials first.",
	Result.ALREADY_OWNED: "You've already got one of those.",
	Result.BAG_FULL: "Your bag's full. Make some room first.",
	Result.NOT_SOLD: "I don't keep those ready-made.",
	Result.UNKNOWN: "Never heard of it.",
}

static var _catalog: ForgeCatalog


static func get_recipes() -> Array[ToolRecipe]:
	if _catalog == null:
		_catalog = load(CATALOG_PATH) as ForgeCatalog
	return _catalog.recipes if _catalog else ([] as Array[ToolRecipe])


static func get_recipe(item_id: StringName) -> ToolRecipe:
	for recipe in get_recipes():
		if recipe.item_id == item_id:
			return recipe
	return null


static func message_for(result: int) -> String:
	return MESSAGES.get(result, "")


## "4 Wood", "6 Logs" - the materials in words.
static func materials_text(recipe: ToolRecipe) -> String:
	var parts: Array[String] = []
	for item_id: StringName in recipe.materials:
		var amount := int(recipe.materials[item_id])
		parts.append("%d %s" % [amount, item_name(item_id, amount)])
	return " + ".join(parts)


## "Log" or "Logs" for that many ("Wood" stays "Wood").
static func item_name(item_id: StringName, amount: int) -> String:
	var label := ItemDB.get_display_name(item_id)
	if amount != 1 and not label.ends_with("s") and label != "Wood":
		label += "s"
	return label


static func has_materials(recipe: ToolRecipe) -> bool:
	for item_id: StringName in recipe.materials:
		if InventoryManager.get_count(item_id) < int(recipe.materials[item_id]):
			return false
	return true


static func can_forge(item_id: StringName) -> int:
	var recipe := get_recipe(item_id)
	if recipe == null:
		return Result.UNKNOWN
	if InventoryManager.has_item(item_id):
		return Result.ALREADY_OWNED
	if not has_materials(recipe):
		return Result.MISSING_MATERIALS
	if InventoryManager.get_money() < recipe.forge_fee:
		return Result.NOT_ENOUGH_MONEY
	if InventoryManager.get_room_for(item_id) <= 0:
		return Result.BAG_FULL
	return Result.OK


static func can_buy(item_id: StringName) -> int:
	var recipe := get_recipe(item_id)
	if recipe == null:
		return Result.UNKNOWN
	if recipe.buy_price <= 0:
		return Result.NOT_SOLD
	if InventoryManager.has_item(item_id):
		return Result.ALREADY_OWNED
	if InventoryManager.get_money() < recipe.buy_price:
		return Result.NOT_ENOUGH_MONEY
	if InventoryManager.get_room_for(item_id) <= 0:
		return Result.BAG_FULL
	return Result.OK


## Forges the tool from your materials: takes them and the fee, then the clock moves on
## while Bram works. Returns {result, minutes}.
static func forge(item_id: StringName) -> Dictionary:
	var result := can_forge(item_id)
	if result != Result.OK:
		return {"result": result, "minutes": 0}
	var recipe := get_recipe(item_id)
	for material: StringName in recipe.materials:
		InventoryManager.remove_item(material, int(recipe.materials[material]))
	InventoryManager.spend_money(recipe.forge_fee)
	InventoryManager.add_item(item_id, 1)
	if recipe.forge_minutes > 0:
		ActivityClock.advance_minutes(recipe.forge_minutes, &"forging")
	QuestLog.record_event(StringName("forge_" + String(item_id)))
	QuestLog.record_event(&"get_tool")
	return {"result": Result.OK, "minutes": recipe.forge_minutes}


## Buys a ready-made one. No time passes. Returns {result, coins}.
static func buy(item_id: StringName) -> Dictionary:
	var result := can_buy(item_id)
	if result != Result.OK:
		return {"result": result, "coins": 0}
	var recipe := get_recipe(item_id)
	InventoryManager.spend_money(recipe.buy_price)
	InventoryManager.add_item(item_id, 1)
	QuestLog.record_event(&"get_tool")
	return {"result": Result.OK, "coins": recipe.buy_price}
