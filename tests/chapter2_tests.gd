extends RefCounted
## Checks for Chapter 2, "The Carpenter's Bridge" (Theo, Willow Creek, the ancient oak).
## Called from test_runner.gd:  await preload("res://tests/chapter2_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Chapter 2: The Carpenter's Bridge ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var forest := main.get_node("Island/StoryPlaces/Forest") as Node3D
	var bridge := forest.get_node("Bridge") as StoryVariant
	var workshop := forest.get_node("Workshop") as StoryVariant
	var repair := forest.get_node("BridgeRepairBase/Repair") as RestorationSite
	var planting := forest.get_node("SaplingPlanting/Plant") as StoryActivity
	var oak := forest.get_node("AncientTree") as StoryVariant
	var saplings := forest.get_node("OakSaplings") as StoryVariant
	var shrine := forest.get_node("ShrineShard") as StoryVariant
	var player := main.get_node("Player") as PlayerController
	var theo := main.get_node("Villagers/Theo") as Villager

	t.check(not QuestLog.is_active(&"carpenters_bridge") and not repair.is_unlocked(), "the bridge waits until you've met Theo")
	t.check(not shrine.get_node("AfterShard").visible, "no Glowstone at the shrine while the forest sleeps")
	GameManager.set_flag(&"met_theo")
	await t._frames(2)
	t.check(QuestLog.is_active(&"carpenters_bridge"), "meeting Theo starts Chapter 2")
	theo.talk(player)
	t.check(theo.get_bubble_text() == str(Array(theo.data.story_lines[&"met_theo"])[0]), "Theo explains what the bridge needs")
	theo.end_conversation()
	t.check(repair.is_unlocked() and not repair.can_restore() and repair.get_prompt().contains("15"), "the bridge asks for 15 planks and 10 stone")

	InventoryManager.add_item(&"wooden_plank", 15)
	InventoryManager.add_item(&"stone", 10)
	var coins := InventoryManager.get_money()
	var clock := ActivityClock.total_minutes
	t.check(repair.restore_now() and GameManager.has_flag(&"restored_bridge"), "rebuilding the bridge with Theo sets restored_bridge")
	t.check(InventoryManager.get_count(&"wooden_plank") == 0 and InventoryManager.get_count(&"stone") == 0 and InventoryManager.get_money() == coins, "it uses the planks and stone (no coins)")
	t.check(ActivityClock.total_minutes == clock + 180, "the rebuild takes 3 hours")
	await t._frames(3)
	t.check(bridge.get_node("After").visible and workshop.get_node("After").visible, "the stone bridge is back and Theo's workshop reopens")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(-75, 40, 45), Vector3(-75, -10, 45), 1)
	var hit: Dictionary = space.intersect_ray(query)
	var creek := IslandShape.shared().get_creek_info(IslandShape.CREEK_BRIDGE)
	t.check(not hit.is_empty() and (hit.position as Vector3).y > creek.y + 1.5, "you can walk across the new bridge")

	var page := forest.get_node("../Story/JournalPage4/Page") as JournalPage
	page.interact(player)
	await t._frames(1)
	# Late night (found by the playthrough bot): planting after midnight and sleeping till
	# 6 AM the same calendar day must still bring "the next morning".
	ActivityClock.advance_minutes(ActivityClock.minutes_until(1), &"test")
	clock = ActivityClock.total_minutes
	t.check(planting.finish_now() and GameManager.has_flag(&"ch2_saplings_planted") and ActivityClock.total_minutes == clock + 60, "you plant oak saplings round the old tree with Theo (1 hour)")
	await t._frames(2)
	t.check(saplings.get_node("After1").visible and not oak.get_node("After").visible, "three saplings stand round the oak, which is still asleep")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	await t._frames(3)
	t.check(GameManager.has_flag(&"ch2_tree_restored") and oak.get_node("After").visible and not oak.get_node("Before").visible, "the next morning the ancient oak is in full leaf (even after planting at 1 AM)")
	var pickup := shrine.get_node("AfterShard/Pickup") as StoryPickup
	t.check(shrine.get_node("AfterShard").visible and pickup.enabled, "sunlight reaches the shrine, and something glints")
	coins = InventoryManager.get_money()
	pickup.interact(player)
	await t._frames(2)
	t.check(GameManager.has_flag(&"shard_2") and InventoryManager.get_count(&"glowstone_shard") == 1, "you find Glowstone shard 2 at the shrine")
	t.check(QuestLog.is_done(&"carpenters_bridge") and InventoryManager.get_money() == coins + 100, "Chapter 2 is complete (Theo's thanks: 100 coins)")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
