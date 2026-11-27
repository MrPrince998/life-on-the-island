extends RefCounted
## Checks for the background music (MusicDirector autoload, the user's Suno tracks).
## Called from test_runner.gd:
##   await preload("res://tests/music_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Background music ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	var md := MusicDirector
	var all_there := true
	for track in [&"title_theme", &"village_day", &"fields_day", &"amber_plains", &"lake_forest", &"finale"]:
		var stream := md._stream(track) as AudioStreamMP3
		all_there = all_there and stream != null and not stream.loop and stream.get_length() > 60.0
	t.check(all_there, "all six Suno tracks load (and play through once, not looping)")
	t.check(not md.has_track(&"night") and not md.has_track(&"rain"), "(night, evening, rain and winter aren't made yet)")
	t.check(md._players.all(func(p: AudioStreamPlayer) -> bool: return p.bus == &"Music"), "the music plays on the Music bus (the Settings slider)")

	# Title screen and finale pick their own tracks.
	var saved_mode: int = md.mode
	md.mode = MusicDirector.Mode.TITLE
	var title := md.pick_track()
	md.mode = MusicDirector.Mode.FINALE
	var finale := md.pick_track()
	md.mode = saved_mode
	t.check(title == &"title_theme" and finale == &"finale", "title screen: title_theme; finale and credits: finale")

	# ---- In the world ----
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(20)
	var clock := ActivityClock.total_minutes
	t.check(md.mode == MusicDirector.Mode.WORLD, "on the island the director is in world mode")
	var regions := {&"willowbrook_village": &"village_day", &"sunflower_fields": &"fields_day", &"amber_plains": &"amber_plains", &"moonlit_lake": &"lake_forest", &"fernwood_forest": &"lake_forest"}
	var right := true
	var wrong: Array[String] = []
	for region: StringName in regions:
		GameManager.current_region_id = region
		await t.get_tree().create_timer(0.35).timeout
		if md.get_current_track() != regions[region]:
			right = false
			wrong.append("%s -> %s" % [region, md.get_current_track()])
	t.check(right, "each region has its music: village, fields, Amber Plains, lake and forest (%s)" % ", ".join(wrong))
	var playing: AudioStreamPlayer = md._players[md._active]
	t.check(playing.playing and playing.stream == md._stream(&"lake_forest"), "and the track really plays (crossfading from the last)")

	# Late at night there's no night track yet: the calm lake music stands in.
	GameManager.current_region_id = &"willowbrook_village"
	ActivityClock.advance_minutes(ActivityClock.minutes_until(23), &"test")
	clock = ActivityClock.total_minutes
	await t.get_tree().create_timer(0.35).timeout
	t.check(md.get_current_track() == &"lake_forest", "late at night the calmest track plays (until night.mp3 is made)")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(9), &"test")
	clock = ActivityClock.total_minutes
	await t.get_tree().create_timer(0.35).timeout
	t.check(md.get_current_track() == &"village_day", "next morning the village music is back")

	# Dips while you chat.
	var player := main.get_node("Player") as PlayerController
	var villager: Villager = null
	for child in main.get_node("Villagers").get_children():
		if child is Villager:
			villager = child
			break
	player.teleport_to(villager.global_position + Vector3(1.2, 0.3, 0))
	await t._frames(3)
	villager.talk(player)
	await t.get_tree().create_timer(0.35).timeout
	t.check(md._duck_db <= MusicDirector.TALK_DUCK_DB + 0.01, "the music dips while you chat with %s" % villager.data.display_name)
	villager.end_conversation()
	await t.get_tree().create_timer(0.35).timeout
	t.check(is_zero_approx(md._duck_db), "and comes back after")

	# A quiet rest between tracks, then music again.
	md.skip_to_rest()
	t.check(md.is_resting() and md.get_current_track() == &"", "after a track ends there's a quiet rest (only the island's sounds)")
	md._rest_left = 0.1
	await t.get_tree().create_timer(0.5).timeout
	t.check(not md.is_resting() and md.get_current_track() != &"" and md.get_current_track() == md.pick_track(), "then the music starts again (%s)" % md.get_current_track())

	# The finale and credits.
	var credits := FinaleCredits.play(t.get_tree())
	await t.get_tree().create_timer(0.35).timeout
	t.check(md.mode == MusicDirector.Mode.FINALE and md.get_current_track() == &"finale", "the credits play the finale track")
	credits._end()
	credits.queue_free()
	await t.get_tree().create_timer(0.35).timeout
	t.check(md.mode == MusicDirector.Mode.WORLD and md.get_current_track() != &"finale", "and the island's music returns after")

	t.check(ActivityClock.total_minutes == clock, "music never changes the in-game time")

	GameManager.current_region_id = &""
	GameManager.reset_flags()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
