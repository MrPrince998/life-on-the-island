extends RefCounted
## Checks for Chapter 3, "Market Day" (Emma, Mr. Ambrose, the market, the glowing well).
## Called from test_runner.gd:  await preload("res://tests/chapter3_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Chapter 3: Market Day ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var village := main.get_node("Island/StoryPlaces/Village") as Node3D
	var repair := village.get_node("MarketRepairBase/Repair") as RestorationSite
	var stall := village.get_node("MarketStall1") as StoryVariant
	var inn := village.get_node("Inn") as StoryVariant
	var house := village.get_node("House1") as StoryVariant
	var well := village.get_node("WellGlow") as StoryVariant
	var lamp_light := village.get_node("StreetLamps").get_child(0).get_node("Light") as Light3D
	var player := main.get_node("Player") as PlayerController
	var emma := main.get_node("Villagers/Emma") as Villager
	var ambrose := main.get_node("Villagers/MrAmbrose") as Villager
	var pip := main.get_node("Villagers/Pip") as Villager
	# Not met_ambrose: like a real player you meet him because Emma sends you (playthrough bot).
	for flag in [&"met_emma", &"met_pip"]:
		GameManager.set_flag(flag)

	t.check(not QuestLog.is_active(&"market_ledger") and not repair.is_unlocked(), "Chapter 3 waits for the end of Chapter 2")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(21), &"test")
	await t._frames(2)
	t.check(not lamp_light.visible, "before Market Day the village street lamps stay dark at night")
	GameManager.set_flag(&"shard_2")
	await t._frames(2)
	t.check(QuestLog.is_active(&"market_ledger"), "finding the second Glowstone starts Chapter 3")
	var ledger := QuestLog.catalog.get_quest(&"market_ledger")
	emma.talk(player)
	t.check(emma.get_bubble_text() == ledger.steps[0].lines[0], "Emma tells you about the old market")
	emma.end_conversation()
	ambrose.talk(player)
	t.check(ambrose.get_bubble_text() == ledger.steps[1].lines[0], "meeting Mr. Ambrose for the first time, he goes straight to Grandpa's ledger (no second chat needed)")
	ambrose.end_conversation()
	await t._frames(1)
	t.check(GameManager.has_flag(&"met_ambrose"), "and you've met him (he's in your journal)")
	t.check(QuestLog.is_done(&"market_ledger") and GameManager.has_flag(&"journal_page_5") and GameManager.has_flag(&"journal_page_6"), "you get journal pages 5 and 6")
	t.check(QuestLog.is_active(&"market_day") and repair.is_unlocked(), "now the market stalls can be mended")

	InventoryManager.add_item(&"wooden_plank", 12)
	InventoryManager.add_item(&"stone", 6)
	InventoryManager.add_money(400 - InventoryManager.get_money())
	t.check(repair.restore_now() and GameManager.has_flag(&"restored_market") and InventoryManager.get_money() == 100, "mending the stalls takes 12 planks, 6 stone and 300 coins")
	await t._frames(2)
	t.check(stall.get_node("After1").visible and stall.get_node("After2").visible and not stall.get_node("Before").visible, "the stalls stand again, with goods on display")

	InventoryManager.add_item(&"sunfish", 10)
	InventoryManager.add_item(&"turnip", 10)
	ShopService.sell(&"sunfish", 10)
	await t._frames(1)
	ShopService.sell(&"turnip", 10)
	await t._frames(1)
	t.check(QuestLog.get_step_index(&"market_day") == 3, "selling 10 fish and 10 crops to Emma stocks the market")
	var market := QuestLog.catalog.get_quest(&"market_day")
	emma.talk(player)
	t.check(emma.get_bubble_text() == market.steps[3].lines[0], "Emma can't believe it's really happening")
	emma.end_conversation()
	await t._frames(2)
	t.check(QuestLog.is_done(&"market_day") and GameManager.has_flag(&"ch3_market_day"), "Market Day!")
	t.check(inn.get_node("After").visible and house.get_node("After").visible, "Nana Bea's inn reopens and families move back into their houses")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(12), &"test")
	await t._frames(1)
	t.check(not GameManager.has_flag(&"ch3_well_glow") and not well.get_node("AfterWell").visible, "by day the old well looks ordinary")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(19, 30), &"test")
	await t._frames(2)
	t.check(lamp_light.visible and lamp_light.light_energy > 0.5, "the street lamps are lit for Market Day")
	t.check(GameManager.has_flag(&"ch3_well_glow") and well.get_node("AfterWell").visible, "that evening the village well glows")
	pip.talk(player)
	t.check(pip.get_bubble_text() == str(Array(pip.data.story_lines[&"ch3_well_glow"])[0]), "Pip saw it first!")
	pip.end_conversation()
	var pickup := well.get_node("AfterWell/Pickup") as StoryPickup
	var coins := InventoryManager.get_money()
	pickup.interact(player)
	await t._frames(2)
	t.check(GameManager.has_flag(&"shard_3") and InventoryManager.get_count(&"glowstone_shard") == 1, "you find Glowstone shard 3 at the bottom of the well")
	t.check(QuestLog.is_done(&"well_light") and InventoryManager.get_money() == coins + 60, "Chapter 3 is complete")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
