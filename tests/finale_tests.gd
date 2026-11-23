extends RefCounted
## Checks for the finale, "The Moonwell" (Oliver's page, the lens, lighthouse night,
## the lake isle and Grandpa's letter). Called from test_runner.gd:
##   await preload("res://tests/finale_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Finale: The Moonwell ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var places := main.get_node("Island/StoryPlaces") as Node3D
	var lens := places.get_node("Coast/LensRepairBase/Repair") as RestorationSite
	var lighthouse := main.get_node("Island/Buildings/Lighthouse") as Node3D
	var beam := lighthouse.get_node("Beam") as LighthouseBeam
	var beacon := lighthouse.get_node("Beacon") as Light3D
	var moonwell := places.get_node("Lake/Moonwell") as MoonwellGlow
	var row_out := places.get_node("Lake/RowToIsle") as HouseDoor
	var row_back := places.get_node("Lake/IsleDock/RowBack") as HouseDoor
	var isle_page := places.get_node("Lake/IslePage") as StoryVariant
	var player := main.get_node("Player") as PlayerController
	var oliver := main.get_node("Villagers/Oliver") as Villager
	for flag in [&"met_oliver", &"met_luna", &"met_theo", &"has_fishing_rod"]:
		GameManager.set_flag(flag)

	ActivityClock.advance_minutes(ActivityClock.minutes_until(21), &"test")
	await t._frames(2)
	t.check(not beam.visible and not beacon.visible, "the lighthouse stays dark at night before the finale")
	var faint := moonwell.light_energy
	t.check(moonwell.visible and faint > 0.0, "a faint glow stirs deep in Moonlit Lake at night")
	for n in 5:
		GameManager.set_flag(StringName("shard_%d" % (n + 1)))
	await t._frames(2)
	t.check(moonwell.light_energy > faint, "each Glowstone found makes the Moonwell glow a little brighter")
	t.check(QuestLog.is_active(&"finale_page9"), "finding all five Glowstones starts the finale")
	var start_pos := player.global_position
	row_out.interact(player)
	await t._frames(5)
	t.check(not row_out.is_busy() and player.global_position.distance_to(start_pos) < 0.5, "the rowboat waits until the lighthouse shines")

	var quest := QuestLog.catalog.get_quest(&"finale_page9")
	oliver.talk(player)
	t.check(oliver.get_bubble_text() == quest.steps[0].lines[0], "Oliver can tell you've found all five")
	oliver.end_conversation()
	await t._frames(1)
	t.check(GameManager.has_flag(&"journal_page_9") and QuestLog.is_active(&"finale_lens"), "he gives you Grandpa's page 9")

	InventoryManager.add_item(&"glowstone_shard", 5)
	InventoryManager.add_item(&"wooden_plank", 5)
	InventoryManager.add_item(&"stone", 5)
	t.check(lens.is_unlocked() and lens.can_restore() and lens.get_prompt().contains("Glowstone Shard 5/5"), "the lens needs the five Glowstones, 5 planks and 5 stone")
	var clock := ActivityClock.total_minutes
	t.check(lens.restore_now() and GameManager.has_flag(&"restored_lighthouse") and ActivityClock.total_minutes == clock + 1440, "Luna, Theo and you mend the lens (a whole day)")
	t.check(InventoryManager.get_count(&"glowstone_shard") == 0, "the five Glowstones are set into the lens")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(19, 30), &"test")
	await t._frames(3)
	t.check(GameManager.has_flag(&"lighthouse_lit") and beam.visible and beacon.visible, "at nightfall the lighthouse shines again, its beam sweeping the sea")
	var arm := beam.get_node("Arm") as Node3D
	var turn := arm.rotation.y
	await t._frames(20)
	t.check(not is_equal_approx(arm.rotation.y, turn), "the beam turns")
	t.check(moonwell.light_energy >= 5.0, "and Moonlit Lake glows brightly from below")
	t.check(isle_page.get_node("After").visible, "something waits on the little isle")

	row_out.interact(player)
	var waited := 0
	while row_out.is_busy() and waited < 300:
		await t._frames(1)
		waited += 1
	await t._frames(10)
	var landing := places.get_node("Lake/IsleLanding") as Node3D
	t.check(player.global_position.distance_to(landing.global_position) < 1.0 and player.is_on_floor(), "you row out to the little isle")
	var page := isle_page.get_node("After/Page") as JournalPage
	page.interact(player)
	await t._frames(3)
	var credits := main.get_tree().root.get_node_or_null(^"FinaleCredits") as FinaleCredits
	t.check(GameManager.has_flag(&"journal_page_10") and QuestLog.is_done(&"finale_lens"), "under Grandpa's tree: his last letter, page 10. The story is complete")
	t.check(credits != null and credits.is_running(), "the closing credits play over the island")
	if credits:
		credits.queue_free()
	row_back.interact(player)
	waited = 0
	while row_back.is_busy() and waited < 300:
		await t._frames(1)
		waited += 1
	await t._frames(10)
	var dock := places.get_node("Lake/DockLanding") as Node3D
	t.check(player.global_position.distance_to(dock.global_position) < 1.0 and player.is_on_floor(), "and row back to the dock (free play goes on)")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
