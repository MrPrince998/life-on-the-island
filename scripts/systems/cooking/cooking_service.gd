class_name CookingService
extends RefCounted
## Cooking rules, kept apart from the stove and the window so they can be tested.

const BOOK_PATH := "res://data/recipes/recipe_book.tres"
const ANY_FISH := &"any_fish"


static func get_recipes() -> Array[RecipeData]:
	var book := load(BOOK_PATH) as RecipeBook
	return book.recipes if book else ([] as Array[RecipeData])


static func get_recipe(recipe_id: StringName) -> RecipeData:
	for recipe in get_recipes():
		if recipe.id == recipe_id:
			return recipe
	return null


static func is_known(recipe: RecipeData) -> bool:
	return recipe.requires_flag == &"" or GameManager.has_flag(recipe.requires_flag)


## How many of an ingredient you have ("any_fish" counts every fish in the bag).
static func have(ingredient: StringName) -> int:
	if ingredient == ANY_FISH:
		var total := 0
		for item_id in _fish_in_bag():
			total += InventoryManager.get_count(item_id)
		return total
	return InventoryManager.get_count(ingredient)


static func ingredient_name(ingredient: StringName) -> String:
	return "Any fish" if ingredient == ANY_FISH else ItemDB.get_display_name(ingredient)


## How many dishes you could cook right now (ingredients and bag room).
static func max_cookable(recipe: RecipeData) -> int:
	if recipe == null or not is_known(recipe):
		return 0
	var best := 99
	for ingredient in recipe.ingredients:
		var need := maxi(int(recipe.ingredients[ingredient]), 1)
		best = mini(best, have(StringName(str(ingredient))) / need)
	var room := InventoryManager.get_room_for(recipe.result_item) / maxi(recipe.result_amount, 1)
	return maxi(mini(best, room), 0)


## Cooks up to `count` dishes. Uses the ingredients, adds the dishes and passes the
## time. Returns how many were cooked.
static func cook(recipe: RecipeData, count: int = 1) -> int:
	var dishes := mini(count, max_cookable(recipe))
	if dishes <= 0:
		return 0
	for ingredient in recipe.ingredients:
		var key := StringName(str(ingredient))
		_use(key, int(recipe.ingredients[ingredient]) * dishes)
	InventoryManager.add_item(recipe.result_item, recipe.result_amount * dishes)
	ActivityClock.advance_minutes(recipe.minutes * dishes, &"cooking")
	QuestLog.record_event(&"cook", dishes)
	QuestLog.record_event(StringName("cook_" + String(recipe.id)), dishes)
	return dishes


static func _use(ingredient: StringName, amount: int) -> void:
	if ingredient != ANY_FISH:
		InventoryManager.remove_item(ingredient, amount)
		return
	# Cheapest fish first, so a rare catch is never cooked by accident.
	var fish := _fish_in_bag()
	fish.sort_custom(func(a: StringName, b: StringName) -> bool:
		return ItemDB.get_item(a).sell_price < ItemDB.get_item(b).sell_price)
	var left := amount
	for item_id in fish:
		if left <= 0:
			break
		left -= InventoryManager.remove_item(item_id, left)


static func _fish_in_bag() -> Array[StringName]:
	var result: Array[StringName] = []
	var bag := InventoryManager.get_all()
	for item_id in bag:
		var item := ItemDB.get_item(item_id)
		if item and item.category == ItemData.Category.FISH:
			result.append(item_id)
	return result
