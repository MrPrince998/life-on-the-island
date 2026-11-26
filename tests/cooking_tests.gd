extends RefCounted
## Checks for cooking at Grandpa's stove. Called from test_runner.gd:
##   await preload("res://tests/cooking_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Cooking ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var stove := main.get_node("Island/Buildings/Cottage/Interior/CookingSpot") as CookingSpot
	var player := main.get_node("Player") as PlayerController
	var recipes := CookingService.get_recipes()
	t.check(recipes.size() == 8, "Grandpa's recipe book has 8 recipes (with the Fish and Rice Bowl and the Farmhouse Loaf)")
	var bad_items: Array[String] = []
	for r in recipes:
		var dish := ItemDB.get_item(r.result_item)
		if dish == null or dish.icon == null or dish.sell_price <= 0:
			bad_items.append(String(r.id))
		for ingredient in r.ingredients:
			var key := StringName(str(ingredient))
			if key != CookingService.ANY_FISH and not ItemDB.has_item(key):
				bad_items.append("%s needs unknown %s" % [r.id, key])
	t.check(bad_items.is_empty(), "every dish is a real item with an icon and a price, made from real ingredients (%s)" % ", ".join(bad_items))

	stove.interact(player)
	var panel := CookingPanel.get_instance(main.get_tree())
	await t._frames(2)
	t.check(panel.is_open() and player.is_input_locked(), "E at Grandpa's stove opens the cooking window")

	var soup := CookingService.get_recipe(&"turnip_soup")
	t.check(CookingService.max_cookable(soup) == 0 and CookingService.cook(soup) == 0, "nothing cooks without ingredients")
	InventoryManager.add_item(&"turnip", 5)
	var clock := ActivityClock.total_minutes
	panel.select(recipes.find(soup))
	t.check(panel.cook(false) == 1 and InventoryManager.get_count(&"turnip_soup") == 1 and InventoryManager.get_count(&"turnip") == 3, "Cook 1 turns 2 turnips into Turnip Soup")
	t.check(ActivityClock.total_minutes == clock + 30, "cooking soup takes 30 minutes")
	t.check(panel.cook(true) == 1 and InventoryManager.get_count(&"turnip") == 1, "Cook all makes as many as you have ingredients for")
	var soup_price := ItemDB.get_item(&"turnip_soup").sell_price
	t.check(soup_price > ItemDB.get_item(&"turnip").sell_price * 2, "soup sells for more than its turnips (%d coins)" % soup_price)

	# Any fish: the cheapest goes first.
	InventoryManager.add_item(&"azure_manta", 1)
	InventoryManager.add_item(&"silver_minnow", 1)
	var grilled := CookingService.get_recipe(&"grilled_fish")
	t.check(CookingService.cook(grilled) == 1 and InventoryManager.get_count(&"silver_minnow") == 0 and InventoryManager.get_count(&"azure_manta") == 1, "grilling uses the cheapest fish and keeps the rare manta")

	# Recipes villagers teach.
	var stew := CookingService.get_recipe(&"fishermans_stew")
	InventoryManager.add_item(&"carrot", 1)
	InventoryManager.add_item(&"turnip", 1)
	t.check(not CookingService.is_known(stew) and CookingService.cook(stew) == 0, "Fisherman's Stew is unknown until Oliver teaches it")
	GameManager.set_flag(&"hearts_oliver_2")
	t.check(CookingService.is_known(stew) and CookingService.cook(stew) == 1, "at 2 hearts with Oliver you can cook his stew")
	t.check(ActivityClock.total_minutes > clock and InventoryManager.get_count(&"fishermans_stew") == 1, "the stew is in your bag")

	var pie := CookingService.get_recipe(&"garden_pie")
	t.check(not CookingService.is_known(pie), "Nana's Garden Pie waits for Nana Bea's quest")
	GameManager.set_flag(&"nana_recipe_done")
	t.check(CookingService.is_known(pie), "finishing Nana Bea's quest teaches her Garden Pie")
	# Grandpa's memorial bench (Theo's quest).
	var bench := main.get_node("Island/StoryPlaces/Village/MemorialBench") as StoryVariant
	t.check(not bench.get_node("After").visible, "there's no memorial bench yet")
	GameManager.set_flag(&"theo_bench_built")
	await t._frames(2)
	var seat := bench.get_node("After/SitRest") as RestSpot
	t.check(bench.get_node("After").visible and seat.interaction_id == &"memorial_bench", "when Theo builds it, Grandpa's memorial bench appears by the cottage (and you can sit on it)")
	panel.close()
	t.check(not panel.is_open() and not player.is_input_locked(), "closing the window lets you walk again")
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
