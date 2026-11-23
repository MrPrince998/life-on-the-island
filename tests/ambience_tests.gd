extends RefCounted
## Checks for the island's ambient sound. Called from test_runner.gd:
##   await preload("res://tests/ambience_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Volume settings ==")
	var buses_ok := true
	for bus: StringName in [&"Music", &"Ambience", &"Effects"]:
		var i := AudioServer.get_bus_index(bus)
		buses_ok = buses_ok and i > 0 and AudioServer.get_bus_send(i) == &"Master"
	t.check(buses_ok, "Music, Ambience and Effects buses exist and feed Master")
	var before := [GameSettings.master_volume, GameSettings.music_volume, GameSettings.ambience_volume, GameSettings.effects_volume]
	GameSettings.set_volume(&"Music", 0.25)
	GameSettings.set_volume(&"Ambience", 0.5)
	GameSettings.set_volume(&"Effects", 0.0)
	GameSettings.apply()
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	t.check(absf(music_db - linear_to_db(0.25)) < 0.1 and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects")), "each slider sets its own bus (Effects at 0 is muted)")
	var path := "user://test_settings.cfg"
	GameSettings.save_to(path)
	GameSettings.reset_to_defaults()
	GameSettings.load_from(path)
	t.check(is_equal_approx(GameSettings.music_volume, 0.25) and is_equal_approx(GameSettings.ambience_volume, 0.5) and is_equal_approx(GameSettings.effects_volume, 0.0), "the volumes are saved and loaded back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var panel := SettingsPanel.new()
	t.add_child(panel)
	var music_slider := panel.find_child("MusicSlider", true, false) as HSlider
	t.check(music_slider != null and panel.find_child("AmbienceSlider", true, false) != null and panel.find_child("EffectsSlider", true, false) != null and is_equal_approx(music_slider.value, 0.25), "Settings has Music, Ambience and Effects sliders showing the saved values")
	panel.queue_free()
	GameSettings.master_volume = before[0]
	GameSettings.music_volume = before[1]
	GameSettings.ambience_volume = before[2]
	GameSettings.effects_volume = before[3]
	GameSettings.apply()

	print("== Ambient sound ==")
	WeatherManager.auto_change = false  # weather only changes when the test says so
	ActivityClock.reset()
	GameManager.reset_flags()
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(10)
	var amb := main.get_node_or_null("Ambience") as IslandAmbience
	var player := main.get_node("Player") as PlayerController
	t.check(amb != null and AudioServer.get_bus_index(&"Ambience") >= 0, "the island has ambient sound on its own Ambience bus")
	if amb == null:
		main.queue_free()
		await t._frames(3)
		return

	await _go(t, amb, player, Vector2(0, 115))
	t.check(amb.get_target(&"birds_day") > 0.4 and amb.get_target(&"crickets") < 0.05, "morning in the village: birdsong, no crickets")
	t.check(amb.get_target(&"coast_waves") < 0.3 and amb.get_target(&"lake_lap") < 0.1, "the sea and the lake are far from the square")
	await t._frames(150)
	t.check(amb.get_master() > 0.5 and amb.get_level(&"birds_day") > 0.2, "it fades in when the island loads")

	await _go(t, amb, player, Vector2(-87.5, 180))
	t.check(amb.get_target(&"coast_waves") > 0.6, "on the beach the surf is loud (%.2f)" % amb.get_target(&"coast_waves"))
	await _go(t, amb, player, Vector2(11, 64))
	t.check(amb.get_target(&"lake_lap") > 0.6 and amb.get_target(&"coast_waves") < 0.3, "at the fishing dock: lake water, not the sea")

	ActivityClock.advance_minutes(ActivityClock.minutes_until(22), &"test")
	var minutes := ActivityClock.total_minutes
	amb.update_targets()
	t.check(amb.get_target(&"birds_day") < 0.05 and amb.get_target(&"frogs") > 0.5, "at night by the lake: the birds rest and the frogs call")
	await _go(t, amb, player, Vector2(0, 115))
	t.check(amb.get_target(&"crickets") > 0.2, "at night in the village: crickets (fewer in spring)")

	WeatherManager.set_weather(WeatherManager.Weather.RAIN)
	amb.update_targets()
	t.check(amb.get_target(&"rain") > 0.9, "rain can be heard when it rains")
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	amb.update_targets()
	t.check(amb.get_target(&"rain") < 0.01, "and stops when it clears")

	# Chapter 3: the market's music and chatter, the glowing well's hum.
	t.check(amb.get_target(&"market_music") < 0.01 and amb.get_target(&"well_hum") < 0.01, "before Market Day the square has no market sounds")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(10), &"test")
	GameManager.set_flag(&"ch3_market_day")
	amb.update_targets()
	var speaker := amb.get_node_or_null("market_music") as AudioStreamPlayer3D
	t.check(amb.get_target(&"market_music") > 0.9 and amb.get_target(&"chatter_square") > 0.9 and speaker != null and speaker.bus == &"Music" and Vector2(speaker.global_position.x, speaker.global_position.z).distance_to(Vector2(0, 115)) < 10.0, "once the market reopens, music (Music bus) and chatter fill the square by day")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(23), &"test")
	amb.update_targets()
	t.check(amb.get_target(&"market_music") < 0.01 and amb.get_target(&"chatter_square") < 0.01, "the market goes quiet at night")
	GameManager.set_flag(&"ch3_well_glow")
	amb.update_targets()
	t.check(amb.get_target(&"well_hum") > 0.9, "the glowing well hums")
	GameManager.set_flag(&"shard_3")
	amb.update_targets()
	t.check(amb.get_target(&"well_hum") < 0.01, "and falls silent once the shard is taken")
	# The finale: the Moonwell's shimmer and the lit lighthouse.
	ActivityClock.from_dict({"total_minutes": 10 * 60})
	amb.update_targets()
	t.check(amb.get_target(&"moonwell") < 0.01 and amb.get_target(&"lighthouse") < 0.01, "by day the lake and the lighthouse are quiet")
	ActivityClock.from_dict({"total_minutes": 22 * 60})
	amb.update_targets()
	var faint := amb.get_target(&"moonwell")
	GameManager.set_flag(&"shard_1")
	GameManager.set_flag(&"shard_2")
	amb.update_targets()
	t.check(faint > 0.05 and amb.get_target(&"moonwell") > faint and amb.get_target(&"lighthouse") < 0.01, "at night the Moonwell shimmers, fuller with every shard (%.2f -> %.2f)" % [faint, amb.get_target(&"moonwell")])
	GameManager.set_flag(&"lighthouse_lit")
	amb.update_targets()
	var lamp := amb.get_node_or_null("lighthouse") as Node3D
	t.check(amb.get_target(&"lighthouse") > 0.9 and amb.get_target(&"moonwell") > 0.9 and lamp != null and _lamp_xz(main) != Vector2.INF and Vector2(lamp.global_position.x, lamp.global_position.z).distance_to(_lamp_xz(main)) < 5.0, "once the lighthouse is lit it hums from the lamp, and the Moonwell sings fully")
	var swell := amb.beam_swell()
	t.check(swell >= 0.5 and swell <= 1.0, "the hum swells as the beam sweeps past (%.2f now)" % swell)

	# Seasons reshape the mix (28 days each: spring, summer, autumn, winter).
	var at := func(day: int, hour: int) -> void:
		ActivityClock.from_dict({"total_minutes": (day - 1) * 1440 + hour * 60})
		amb.update_targets()
	at.call(10, 10)
	var spring_birds := amb.get_target(&"birds_day")
	t.check(amb.get_target(&"cicadas") < 0.01 and amb.get_target(&"leaves") < 0.01, "spring: no cicadas or dry leaves")
	at.call(30, 10)
	var summer_wind := amb.get_target(&"wind")
	t.check(amb.get_target(&"cicadas") > 0.2, "summer days: cicadas buzz")
	at.call(60, 10)
	t.check(amb.get_target(&"leaves") > 0.3 and amb.get_target(&"birds_day") < spring_birds and amb.get_target(&"cicadas") < 0.01, "autumn: dry leaves rustle, fewer birds")
	at.call(90, 10)
	t.check(amb.get_target(&"wind") > summer_wind and amb.get_target(&"birds_day") < spring_birds * 0.4, "winter: colder wind, only a few hardy birds")
	at.call(90, 22)
	await _go(t, amb, player, Vector2(11, 64))
	t.check(amb.get_target(&"crickets") < 0.01 and amb.get_target(&"frogs") < 0.01, "winter nights: no crickets or frogs")
	WeatherManager.set_weather(WeatherManager.Weather.SNOW)
	amb.update_targets()
	await t._frames(120)
	t.check(amb.get_cutoff() < 6000.0 and amb.get_target(&"rain") < 0.01, "falling snow hushes the island (low-pass %.0f Hz)" % amb.get_cutoff())
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	amb.update_targets()
	minutes = ActivityClock.total_minutes

	var room := t.get_tree().get_first_node_in_group(&"indoors") as Node3D
	if room:
		player.teleport_to(room.global_position + Vector3(0, 0.3, 0))
		await t._frames(5)
		amb.update_targets()
		await t._frames(120)
		t.check(amb.is_indoors() and amb.get_cutoff() < 3000.0, "indoors the outside sounds muffled (low-pass %.0f Hz)" % amb.get_cutoff())
	t.check(ActivityClock.total_minutes == minutes, "the ambience never moves the clock")
	main.queue_free()
	await t._frames(3)
	ActivityClock.reset()
	GameManager.reset_flags()


func _go(t: Node, amb: IslandAmbience, player: PlayerController, xz: Vector2) -> void:
	var y := IslandShape.shared().get_height(xz.x, xz.y) + 0.3
	player.teleport_to(Vector3(xz.x, maxf(y, IslandShape.SEA_LEVEL + 0.3), xz.y))
	await t._frames(4)
	amb.update_targets()


## Where the lighthouse lamp is (wherever the lighthouse stands), or INF.
func _lamp_xz(main: Node) -> Vector2:
	var lamp := main.get_node_or_null("Island/Buildings/Lighthouse") as Node3D
	for node in main.find_children("*", "Node3D", true, false):
		if node is LighthouseBeam:
			lamp = node
			break
	return Vector2(lamp.global_position.x, lamp.global_position.z) if lamp else Vector2.INF
