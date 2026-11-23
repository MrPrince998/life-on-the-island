extends RefCounted
## Checks for the things to spend coins on (UpgradeService, the store's Upgrades tab):
## tool upgrades, cottage furniture, more garden beds and village projects.
## Called from test_runner.gd:  await preload("res://tests/upgrade_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Upgrades: things to spend coins on ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)

	# The catalog.
	var all := UpgradeService.get_all()
	var ids := {}
	var categories := {}
	var total := 0
	var data_ok := true
	for up in all:
		ids[up.id] = true
		categories[up.category] = true
		total += up.price
		data_ok = data_ok and up.price > 0 and up.display_name != "" and up.description != "" and up.bought_message != ""
		if up.requires_upgrade != &"":
			data_ok = data_ok and UpgradeService.get_upgrade(up.requires_upgrade) != null
	t.check(all.size() >= 16 and ids.size() == all.size() and categories.size() == 4 and data_ok, "the store offers %d upgrades in 4 kinds (tools, home, farm, village), worth %d coins in all" % [all.size(), total])

	# Buying: coins, once only, and in order.
	t.check(UpgradeService.can_buy(&"tool_rod_oak") == UpgradeService.Result.NOT_ENOUGH_MONEY, "a new player can't afford the oak rod yet")
	t.check(UpgradeService.can_buy(&"tool_rod_moonwood") == UpgradeService.Result.LOCKED and UpgradeService.lock_reason(UpgradeService.get_upgrade(&"tool_rod_moonwood")).contains("Oak"), "the moonwood rod waits for the oak rod")
	t.check(UpgradeService.can_buy(&"village_bunting") == UpgradeService.Result.LOCKED, "the festival bunting waits for Market Day")
	InventoryManager.add_money(20000)
	var shop := t.get_tree().get_first_node_in_group(&"shop_panel") as ShopPanel
	shop.open()
	shop.show_upgrades()
	var coins := InventoryManager.get_money()
	var clock := ActivityClock.total_minutes
	var result := shop.buy_upgrade(&"tool_rod_oak")
	t.check(result.result == UpgradeService.Result.OK and InventoryManager.get_money() == coins - 600 and GameManager.has_flag(&"bought_tool_rod_oak") and ActivityClock.total_minutes == clock, "buying the oak rod at the store's Upgrades tab: 600 coins, no time")
	t.check(shop.buy_upgrade(&"tool_rod_oak").result == UpgradeService.Result.ALREADY_OWNED and InventoryManager.get_money() == coins - 600, "you can't buy the same thing twice")
	t.check(UpgradeService.can_buy(&"tool_rod_moonwood") == UpgradeService.Result.OK, "now the moonwood rod can be bought")
	shop.close()

	# Fishing rods: easier fights, more uncommon and rare fish.
	GameManager.set_flag(&"bought_tool_rod_oak", false)
	var ease0 := UpgradeService.rod_ease()
	var rare0 := _rare_share(main)
	GameManager.set_flag(&"bought_tool_rod_oak")
	var ease1 := UpgradeService.rod_ease()
	GameManager.set_flag(&"bought_tool_rod_moonwood")
	var ease2 := UpgradeService.rod_ease()
	var rare2 := _rare_share(main)
	t.check(ease0 == 0.0 and ease1 > 0.0 and ease2 > ease1, "better rods make fish fight less (ease %.2f, %.2f, %.2f)" % [ease0, ease1, ease2])
	t.check(rare2 > rare0 + 0.1, "with the moonwood rod uncommon and rare fish bite more often (%.0f%% vs %.0f%%)" % [rare2 * 100.0, rare0 * 100.0])
	var fishing := main.get_node("Player").find_children("*", "FishingController", true, false)
	t.check(not fishing.is_empty(), "(the player has a fishing controller)")

	# Bags.
	t.check(InventoryManager.get_bag_slots() == InventoryManager.BAG_SLOTS, "the bag starts with %d slots" % InventoryManager.BAG_SLOTS)
	UpgradeService.buy(&"tool_bag_satchel")
	var satchel := InventoryManager.get_bag_slots()
	UpgradeService.buy(&"tool_bag_pack")
	var pack := InventoryManager.get_bag_slots()
	var stack := ItemDB.get_max_stack(&"stone")
	InventoryManager.add_item(&"stone", stack * 36)
	t.check(satchel == 30 and pack == 36 and pack == InventoryManager.MAX_BAG_SLOTS and InventoryManager.get_count(&"stone") == stack * 36 and InventoryManager.is_full(), "the satchel and the pack grow the bag to %d, then %d slots (and it really holds 36 stacks)" % [satchel, pack])
	InventoryManager.remove_item(&"stone", InventoryManager.get_count(&"stone"))

	# The copper watering can soaks the neighbouring beds.
	var field := main.get_node("Island/Buildings/FarmField") as FarmField
	var middle := field.get_node("Plots/Plot06") as FarmPlot
	var beside := field.get_node("Plots/Plot07") as FarmPlot
	var behind := field.get_node("Plots/Plot02") as FarmPlot
	var far := field.get_node("Plots/Plot12") as FarmPlot
	for plot in [middle, beside, behind, far]:
		plot.dig()
	middle.water()
	var watered := FarmingController.water_neighbours(middle)
	t.check(watered >= 2 and beside.is_damp() and behind.is_damp() and not far.is_damp(), "the copper can soaks the beds right next to the one you water (%d), not the far ones" % watered)
	UpgradeService.buy(&"tool_can_copper")
	t.check(UpgradeService.has_big_can(), "the copper can is yours")

	# More garden beds.
	var south := field.get_node("ExtraBedsSouth") as StoryVariant
	var north := field.get_node("ExtraBedsNorth") as StoryVariant
	t.check(not south.get_node("AfterPlot13").visible and not north.get_node("AfterPlot17").visible, "the new garden beds aren't there before you pay for them")
	UpgradeService.buy(&"farm_beds_1")
	await t._frames(2)
	var after_one := _visible_beds(field)
	UpgradeService.buy(&"farm_beds_2")
	await t._frames(2)
	var after_two := _visible_beds(field)
	var new_bed := south.get_node("AfterPlot13") as FarmPlot
	t.check(after_one == 16 and after_two == 20 and new_bed.can_process() and new_bed.dig(), "Mia clears 4, then 4 more beds: %d, then %d beds, and the new ones can be dug" % [after_one, after_two])
	var saved: Dictionary = field.save_state()
	t.check((saved.plots as Dictionary).has("farm_plot_13") and (saved.plots as Dictionary).has("farm_plot_20"), "the new beds are saved with the farm")

	# Cottage furniture and the garden.
	var interior := main.get_node("Island/Buildings/Cottage").find_child("Interior", true, false) as Node3D
	var furniture := interior.get_node("Furniture")
	var home := {&"home_plants": "UpgradePlants", &"home_barrel": "UpgradeBarrel", &"home_trophy": "UpgradeTrophy", &"home_paintings": "UpgradePaintings"}
	var village := main.get_node("Island/StoryPlaces/Village")
	var outside := {&"home_bench": "HomeGardenBench", &"home_beehive": "HomeBeehive", &"home_lantern": "HomeLantern", &"village_flowers": "UpgradeFlowers", &"village_benches": "UpgradeBenches", &"village_lamps": "UpgradeLamps", &"village_bunting": "UpgradeBunting"}
	var hidden_before := true
	for id: StringName in home:
		hidden_before = hidden_before and not _shown(furniture.get_node(home[id]))
	for id: StringName in outside:
		hidden_before = hidden_before and not _shown(village.get_node(outside[id]))
	t.check(hidden_before, "no new furniture, garden things or village projects before they're bought")
	GameManager.set_flag(&"ch3_market_day")
	for id: StringName in home.keys() + outside.keys():
		var r := UpgradeService.buy(id)
		if r.result != UpgradeService.Result.OK:
			t.check(false, "could buy %s (%s)" % [id, r.result])
	await t._frames(3)
	var shown_after := true
	for id: StringName in home:
		shown_after = shown_after and _shown(furniture.get_node(home[id]))
	t.check(shown_after, "the plants, barrel and crate, mounted fish and paintings appear in Grandpa's cottage")
	var outside_ok := true
	for id: StringName in outside:
		outside_ok = outside_ok and _shown(village.get_node(outside[id]))
	t.check(outside_ok, "the garden bench, beehive and porch lantern, flower beds, benches, lamp posts and bunting appear outside")
	var painting := furniture.get_node("UpgradePaintings/AfterPaintingSea") as WallPainting
	var bunting := village.get_node("UpgradeBunting/AfterBunting") as Bunting
	t.check(painting.get_node("Canvas") != null and bunting.get_node_or_null("Bunting") != null, "the paintings have pictures and the bunting has its flags")
	var lamps := village.get_node("UpgradeLamps").get_children().filter(func(n: Node) -> bool: return n.find_children("*", "NightLight", true, false).size() > 0 or n.get_script() != null)
	t.check(lamps.size() >= 6, "six new lamp posts line the paths")

	var everything := true
	for up in UpgradeService.get_all():
		everything = everything and UpgradeService.is_bought(up.id)
	t.check(everything, "everything in the store can be bought in the end")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


## Share of uncommon and rare fish in 3000 sea bites at noon, with today's rod.
func _rare_share(main: Node) -> float:
	var catalog := main.get_node("Player").find_children("*", "FishingController", true, false)[0].catalog as FishCatalog
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var rare := 0
	for i in 3000:
		var fish := catalog.pick(&"sea", 12, rng, UpgradeService.rare_bonus())
		if fish and fish.rarity >= 1:
			rare += 1
	return rare / 3000.0


func _visible_beds(field: FarmField) -> int:
	return field.get_plots().filter(func(p: FarmPlot) -> bool: return p.is_visible_in_tree()).size()


func _shown(variant: Node) -> bool:
	for child in variant.get_children():
		if String(child.name).begins_with("After") and (child as Node3D).visible:
			return true
	return false
