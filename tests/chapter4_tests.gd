extends RefCounted
## Checks for Chapter 4, "The Keeper's Light" (the cliff bridge, Luna, the sea cave at low
## tide, the message bottle and the captain's chest).
## Called from test_runner.gd:  await preload("res://tests/chapter4_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Chapter 4: The Keeper's Light ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var coast := main.get_node("Island/StoryPlaces/Coast") as Node3D
	var rockfall := coast.get_node("Rockfall") as StoryVariant
	var clear := coast.get_node("Rockfall/BeforeClearSpot/Clear") as StoryActivity
	var tide := coast.get_node("TidePool") as TidePool
	var cave := coast.get_node("CaveShard/Pickup") as StoryPickup
	var bottle := main.get_node("Island/StoryPlaces/Story/MessageBottle/Page") as JournalPage
	var chest := coast.get_node("ChestShard/Pickup") as StoryPickup
	var player := main.get_node("Player") as PlayerController
	var luna := main.get_node("Villagers/Luna") as Villager
	for flag in [&"met_theo", &"met_luna"]:
		GameManager.set_flag(flag)
	var shape := IslandShape.shared()
	var b := bottle.global_position
	t.check(shape.get_land_factor(b.x, b.z) > 0.0 and shape.get_height(b.x, b.z) > 0.5, "the message bottle lies on the west beach, just above the waves")

	t.check(not QuestLog.is_active(&"keepers_light") and not clear.finish_now(), "Chapter 4 waits for the end of Chapter 3")
	GameManager.set_flag(&"shard_3")
	await t._frames(2)
	t.check(QuestLog.is_active(&"keepers_light"), "finding the third Glowstone starts Chapter 4")
	var clock := ActivityClock.total_minutes
	t.check(clear.finish_now() and GameManager.has_flag(&"ch4_rockfall_cleared") and ActivityClock.total_minutes == clock + 120, "you mend the cliff bridge with Theo (2 hours)")
	await t._frames(2)
	t.check(not rockfall.get_node("BeforeBridge").visible and rockfall.get_node("AfterBridge").visible, "the bridge to Lighthouse Isle is mended: the way to the lighthouse is open")

	var quest := QuestLog.catalog.get_quest(&"keepers_light")
	luna.talk(player)
	t.check(luna.get_bubble_text() == quest.steps[1].lines[0], "Luna is amazed someone mended the bridge")
	luna.end_conversation()
	await t._frames(1)
	t.check(QuestLog.get_step_index(&"keepers_light") == 2, "Luna tells you about the lens and the sea cave")

	ActivityClock.advance_minutes(ActivityClock.minutes_until(14), &"test")
	await t._frames(2)
	cave.interact(player)
	t.check(tide.visible and not cave.is_taken and not GameManager.has_flag(&"shard_4"), "in the afternoon the tide floods the cave mouth")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(7), &"test")
	await t._frames(2)
	t.check(not tide.visible and cave.is_open_now(), "in the morning the tide is out")
	cave.interact(player)
	t.check(GameManager.has_flag(&"shard_4") and InventoryManager.get_count(&"glowstone_shard") == 1, "you find Glowstone shard 4 in the crystal pool")

	chest.interact(player)
	t.check(not chest.is_taken and not GameManager.has_flag(&"shard_5"), "the captain's chest is locked")
	bottle.interact(player)
	t.check(GameManager.has_flag(&"journal_page_8") and not bottle.enabled, "the message bottle on the beach is Grandpa's page 8, with a key")
	var coins := InventoryManager.get_money()
	chest.interact(player)
	await t._frames(2)
	t.check(GameManager.has_flag(&"shard_5") and InventoryManager.get_count(&"glowstone_shard") == 2, "the key opens the chest: Glowstone shard 5")
	t.check(QuestLog.is_done(&"keepers_light") and InventoryManager.get_money() == coins + 150, "Chapter 4 is complete")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
