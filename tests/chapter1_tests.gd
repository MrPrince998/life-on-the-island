extends RefCounted
## Checks for Chapter 1, "Seeds of Spring" (the windmill with Mia). Called from
## test_runner.gd:  await preload("res://tests/chapter1_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Chapter 1: Seeds of Spring ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var farm := main.get_node("Island/StoryPlaces/Farm") as Node3D
	var brambles := farm.get_node("BrambleGate") as StoryVariant
	var clear := farm.get_node("BrambleGate/BeforeClearSpot/Clear") as StoryActivity
	var windmill := farm.get_node("Windmill") as StoryVariant
	var repair := farm.get_node("Windmill/RepairBase/Repair") as RestorationSite
	var shard := farm.get_node("Windmill/AfterShard/Pickup") as StoryPickup
	var planting := farm.get_node("OrchardPlanting/Plant") as StoryActivity
	var player := main.get_node("Player") as PlayerController

	t.check(ShopService.get_stock().any(func(item: ItemData) -> bool: return item.id == &"stone"), "stone is sold at the General Store")
	t.check(not QuestLog.is_active(&"seeds_of_spring"), "Chapter 1 waits until you've met Mia")
	var clock := ActivityClock.total_minutes
	t.check(not clear.finish_now() and not GameManager.has_flag(&"ch1_hedge_cleared"), "the brambles can't be cleared before meeting Mia")
	t.check(not repair.is_unlocked() and not repair.can_restore(), "the windmill can't be repaired yet")

	GameManager.set_flag(&"met_mia")
	await t._frames(2)
	t.check(QuestLog.is_active(&"seeds_of_spring"), "meeting Mia starts Chapter 1 in the quest tracker")
	t.check(clear.enabled and clear.get_prompt().begins_with("Clear the brambles with Mia"), "the brambles offer \"Clear the brambles with Mia (1 hour)\"")
	t.check(clear.finish_now() and GameManager.has_flag(&"ch1_hedge_cleared"), "clearing the brambles with Mia sets ch1_hedge_cleared")
	t.check(ActivityClock.total_minutes == clock + 60, "clearing takes an hour of activity time")
	await t._frames(2)
	t.check(not brambles.get_node("Before1").visible and not clear.enabled, "the brambles are gone from the farm path")
	var mia := main.get_node("Villagers/Mia") as Villager
	mia.talk(player)
	var expected: Array = Array(mia.data.story_lines.get(&"ch1_hedge_cleared", []))
	t.check(not expected.is_empty() and mia.get_bubble_text() == str(expected[0]), "Mia thanks you and explains what the windmill needs")
	mia.end_conversation()

	QuestLog.record_event(&"harvest", 3)
	await t._frames(1)
	t.check(QuestLog.get_step_index(&"seeds_of_spring") == 2, "harvesting 3 crops helps Mia (the quest moves on)")
	t.check(repair.is_unlocked() and not repair.can_restore(), "the windmill now asks for materials")
	InventoryManager.add_item(&"wooden_plank", 10)
	InventoryManager.add_item(&"stone", 5)
	InventoryManager.add_money(200 - InventoryManager.get_money())
	t.check(repair.can_restore() and repair.get_prompt().contains("Stone 5/5"), "with 10 planks, 5 stone and 180 coins the repair is ready")
	clock = ActivityClock.total_minutes
	t.check(repair.restore_now() and GameManager.has_flag(&"restored_windmill"), "repairing the windmill sets restored_windmill")
	t.check(InventoryManager.get_count(&"wooden_plank") == 0 and InventoryManager.get_count(&"stone") == 0 and InventoryManager.get_money() == 20, "the planks, stone and 180 coins are used")
	t.check(ActivityClock.total_minutes == clock + 120, "the repair takes 2 hours")
	await t._frames(3)
	t.check(windmill.get_node("After").visible and not windmill.get_node("Before").visible, "the repaired windmill replaces the ruin")
	var sails := windmill.get_node("After/Sails") as SpinningSails
	var pivot := sails.get_pivot()
	var turn_before := pivot.transform.basis if pivot else Basis()
	await t._frames(30)
	t.check(pivot != null and not pivot.transform.basis.is_equal_approx(turn_before), "its sails turn")
	t.check(shard.is_visible_in_tree() and shard.enabled, "something glows in the gearbox")

	t.check(not planting.finish_now(), "the orchard waits for the Glowstone")
	var coins_before := InventoryManager.get_money()
	shard.interact(player)
	t.check(GameManager.has_flag(&"shard_1") and InventoryManager.get_count(&"glowstone_shard") == 1, "looking in the gearbox finds Glowstone shard 1")
	t.check(planting.finish_now() and GameManager.has_flag(&"ch1_orchard_planted"), "you plant Grandpa's orchard with Mia")
	await t._frames(3)
	var sapling := farm.get_node("Orchard1/After") as Node3D
	var butterflies := farm.get_node("Butterflies/After") as CPUParticles3D
	t.check(sapling.visible and butterflies.visible and butterflies.emitting, "blossom saplings stand in the orchard and butterflies arrive")
	t.check(QuestLog.is_done(&"seeds_of_spring") and InventoryManager.get_money() == coins_before + 80, "Chapter 1 is complete (and Mia's thanks: 80 coins)")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	main.queue_free()
	await t._frames(3)
