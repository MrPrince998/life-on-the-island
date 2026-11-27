extends RefCounted
## Checks for the story-moment sounds (autoload StorySounds) and the work-swing sounds.
## Called from test_runner.gd:
##   await preload("res://tests/story_sound_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Story moment sounds ==")
	var story := t.get_node_or_null("/root/StorySounds")
	t.check(story != null, "story moments have their own music (StorySounds)")
	if story == null:
		return
	var missing: Array[String] = []
	for s: StringName in story.SOUNDS:
		if not ResourceLoader.exists(story.DIR + String(s) + ".wav"):
			missing.append(String(s))
	for s in ["work_hammer", "work_wood", "work_stone", "work_brush"]:
		if not ResourceLoader.exists(ActionSounds.WORK_DIR + s + ".wav"):
			missing.append(s)
	t.check(missing.is_empty(), "all the story and work sounds exist %s" % (str(missing) if missing else ""))
	var map_ok: bool = story.sound_for_flag(&"shard_3") == &"shard_found" \
		and story.sound_for_flag(&"journal_page_4") == &"memory_found" \
		and story.sound_for_flag(&"restored_inn") == &"restored_inn" \
		and story.sound_for_flag(&"restored_house_1") == &"restored" \
		and story.sound_for_flag(&"lighthouse_lit") == &"lighthouse_lit" \
		and story.sound_for_flag(&"ch2_tree_restored") == &"bloom" \
		and story.sound_for_flag(&"ch3_market_day") == &"market_bell" \
		and story.sound_for_flag(&"has_fishing_rod") == &"gift" \
		and story.sound_for_flag(&"met_mia") == &""
	t.check(map_ok, "each kind of story moment has its sound (shards, journal pages, restorations, the lighthouse...)")

	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	var autosave_was: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(10)
	var minutes := ActivityClock.total_minutes
	var heard: Array[StringName] = []
	var listen := func(s: StringName) -> void: heard.append(s)
	story.played.connect(listen)

	GameManager.flags_from_dict({"flags": ["shard_1", "restored_inn", "journal_page_2"]})
	await _idle(t)
	t.check(heard.is_empty(), "loading a save plays none of them")
	GameManager.reset_flags()

	var sting := story.get_node("Sting") as AudioStreamPlayer
	GameManager.set_flag(&"shard_1")
	await _idle(t)
	var first_pitch := sting.pitch_scale
	t.check(heard == [&"shard_found"] and sting.playing and sting.bus == &"Music", "finding a Glowstone shard shimmers (on the Music bus)")
	GameManager.set_flag(&"shard_5")
	await _idle(t)
	t.check(sting.pitch_scale > first_pitch * 1.3, "each shard sounds a step higher (%.2f -> %.2f)" % [first_pitch, sting.pitch_scale])
	var amb := main.get_node_or_null("Ambience") as IslandAmbience
	await t._frames(60)
	t.check(amb != null and amb.get_duck() < 0.8, "the island's ambience dips under the moment (%.2f)" % (amb.get_duck() if amb else -1.0))

	var ui := t.get_node_or_null("/root/UISounds")
	var ui_heard: Array[StringName] = []
	var ui_listen := func(s: StringName) -> void: ui_heard.append(s)
	ui.played.connect(ui_listen)
	var quest := load("res://data/quests/arrival.tres") as QuestData
	heard.clear()
	GameManager.set_flag(&"restored_inn")
	QuestLog.quest_completed.emit(quest)
	GameManager.notify("The inn is open again!")
	await t._frames(3)
	t.check(heard == [&"restored_inn"] and not (&"quest_done" in ui_heard) and not (&"notify" in ui_heard), "a restored building gets its \"ta-da\", and the smaller chimes hold back")
	ui.played.disconnect(ui_listen)
	heard.clear()
	GameManager.set_flag(&"journal_page_3")
	await _idle(t)
	GameManager.set_flag(&"lighthouse_lit")
	await _idle(t)
	t.check(heard == [&"memory_found", &"lighthouse_lit"], "a journal page plays a music box; lighting the lighthouse, a big swell")
	GameManager.set_flag(&"met_mia")
	await _idle(t)
	t.check(heard.size() == 2, "ordinary flags stay quiet")

	# Every building has its own restoration sound; at Market Day only one plays.
	heard.clear()
	for building in ["market", "windmill", "bridge", "greenhouse", "lighthouse", "boathouse"]:
		GameManager.set_flag(StringName("restored_" + building))
		await _idle(t)
	t.check(heard == [&"restored_market", &"restored_windmill", &"restored_bridge", &"restored_greenhouse", &"restored_lighthouse", &"restored_boathouse"], "each building's restoration has its own sound (%s)" % str(heard))
	heard.clear()
	GameManager.set_flag(&"restored_house_1")
	await _idle(t)
	t.check(heard == [&"restored"], "a village house gets the general \"ta-da\"")
	heard.clear()
	GameManager.set_flag(&"ch3_market_day")
	GameManager.set_flag(&"restored_house_2")
	await _idle(t)
	t.check(heard == [&"market_bell"], "Market Day (which also reopens houses) rings its bell once, not a pile of sounds")

	# Restored buildings come back to life: each has its own sound, placed on it.
	ActivityClock.from_dict({"total_minutes": 11 * 60})
	amb.update_targets()
	var alive := true
	var placed := true
	for spot: StringName in IslandAmbience.BUILDINGS:
		var speaker := amb.get_node_or_null(NodePath(String(spot))) as Node3D
		var building := main.get_node_or_null(IslandAmbience.BUILDINGS[spot][1]) as Node3D
		placed = placed and speaker != null and building != null and speaker.global_position.distance_to(building.global_position) < 8.0
		if spot != &"inn_fire" and spot != &"workshop":
			alive = alive and amb.get_target(spot) > 0.9
	t.check(placed, "each restored building's sound comes from the building itself")
	t.check(alive and amb.get_target(&"inn_fire") < 0.01, "the windmill's sails creak round, the greenhouse mists, the boathouse ropes creak (the inn's fire waits for evening)")
	GameManager.set_flag(&"restored_inn")
	ActivityClock.from_dict({"total_minutes": 19 * 60})
	amb.update_targets()
	t.check(amb.get_target(&"inn_fire") > 0.9 and amb.get_target(&"workshop") < 0.01, "evening: the inn's fire crackles and Theo has finished work")
	ActivityClock.from_dict({"total_minutes": 11 * 60})
	amb.update_targets()
	t.check(amb.get_target(&"workshop") > 0.9, "by day Theo saws and hammers in his workshop")
	ActivityClock.from_dict({"total_minutes": minutes})

	# The end credits have the finale track (MusicDirector): story sounds stay out of it.
	await _idle(t)  # flush queued story sounds before waiting for playback
	var sting_wait := 0
	while story.is_playing() and sting_wait < 600:
		await t._frames(1)
		sting_wait += 1
	var credits := FinaleCredits.play(t.get_tree())
	await t._frames(20)
	t.check(not story.is_playing() and story.get_node_or_null("CreditsMusic") == null, "the end credits are left to the finale music")
	credits._end()
	await t._frames(5)

	# Work swings: gathering wood snaps branches.
	var player := main.get_node("Player") as PlayerController
	var action := player.get_node("ActionSounds") as ActionSounds
	var work_heard: Array[StringName] = []
	action.played.connect(func(s: StringName) -> void: work_heard.append(s))
	var wood: GatherNode = null
	for node in t.get_tree().get_nodes_in_group(&"gather_node"):
		if (node as GatherNode).item_id == &"wood" and (node as GatherNode).is_ready():
			wood = node
			break
	if wood:
		player.teleport_to(wood.global_position + Vector3(0, 0.3, 1.0), 0.0)
		await t._frames(10)
		wood.interact(player)
		var waited := 0
		while player.is_input_locked() and waited < 600:
			await t._frames(1)
			waited += 1
	t.check(wood != null and &"work_wood" in work_heard, "gathering wood: branches snap with each swing (%d)" % work_heard.count(&"work_wood"))
	# A job with several swings (clearing brambles, crafting): every swing is seen and heard.
	var animator := player.get_node("Visual/Character") as CharacterAnimator
	work_heard.clear()
	player.set_input_locked(true)
	for i in 3:
		animator.play_action(&"farm_swing")
		await t._frames(78)  # 1.3 s, a little shorter than the 1.4 s swing
	await t._frames(30)
	player.set_input_locked(false)
	t.check(work_heard.size() == 3, "three work swings in a row: three swings, three sounds (%d)" % work_heard.size())
	var site := t.get_tree().get_first_node_in_group(&"restoration_site") as RestorationSite
	t.check(ActionSounds.work_sound_for(site) == &"work_hammer" and ActionSounds.work_sound_for(null) == &"work_brush", "repairs hammer; clearing brambles brushes through leaves")
	t.check(ActivityClock.total_minutes - minutes == (wood.gather_minutes if wood else 0), "the sounds never move the clock (only the gathering itself did)")

	story.played.disconnect(listen)
	main.queue_free()
	await t._frames(3)
	SaveManager.autosave_enabled = autosave_was
	InventoryManager.reset()
	ActivityClock.reset()
	GameManager.reset_flags()


## Waits two ordinary (not physics) frames: story moments play at the end of a frame.
func _idle(t: Node) -> void:
	for i in 2:
		await t.get_tree().process_frame
