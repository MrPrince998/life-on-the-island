extends RefCounted
## Checks for the weather sounds (in IslandAmbience). Called from test_runner.gd:
##   await preload("res://tests/weather_sound_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FILES := ["rain_roof", "rain_water", "rain_leaves", "drips", "snow_wind", "thunder", "wind_gust", "snow_whump"]


func run(t: Node) -> void:
	print("== Weather sounds ==")
	var missing: Array[String] = []
	for f in FILES:
		if not ResourceLoader.exists(IslandAmbience.DIR + f + ".wav"):
			missing.append(f)
	t.check(missing.is_empty(), "all %d weather sounds exist %s" % [FILES.size(), str(missing) if missing else ""])

	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	ActivityClock.reset()
	GameManager.reset_flags()
	var autosave_was: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(10)
	var amb := main.get_node("Ambience") as IslandAmbience
	var player := main.get_node("Player") as PlayerController
	var outdoor := AudioServer.get_bus_index(IslandAmbience.OUTDOOR_BUS)
	t.check(outdoor > 0 and AudioServer.get_bus_send(outdoor) == IslandAmbience.BUS and (amb.get_node("rain") as AudioStreamPlayer).bus == IslandAmbience.OUTDOOR_BUS and (amb.get_node("rain_roof") as AudioStreamPlayer).bus == IslandAmbience.BUS, "outdoor sounds go through their own bus (into Ambience, so the Ambience slider still covers them)")

	# Rain by the lake: drops plink on the water.
	await _go(t, amb, player, Vector2(11, 64))
	WeatherManager.set_weather(WeatherManager.Weather.RAIN)
	amb.update_targets()
	t.check(amb.get_target(&"rain_water") > 0.6 and amb.get_target(&"rain_roof") < 0.01 and amb.get_target(&"rain_leaves") < 0.01, "rain on the dock: drops plinking on the lake (%.2f)" % amb.get_target(&"rain_water"))
	t.check(amb.get_target(&"thunder_day") < 0.01, "spring showers are gentle: no thunder")
	ActivityClock.from_dict({"total_minutes": 29 * 1440 + 14 * 60})  # a summer afternoon
	amb.update_targets()
	t.check(amb.get_target(&"thunder_day") > 0.9, "summer rain brings far-off thunder")
	# One-off sounds wait until the ambience has faded in after the island loads.
	var waited := 0
	while amb.get_master() < 0.6 and waited < 600:
		await t._frames(1)
		waited += 1
	amb._shot_timers[&"thunder"] = 0.0
	for i in 3:
		await t.get_tree().process_frame
	t.check(amb.last_one_shot == &"thunder", "and it rumbles now and then")

	# Rain in the forest: drops fall heavily from the canopy.
	await _go(t, amb, player, IslandShape.FOREST_CENTER + Vector2(10, 5))
	await t._frames(10)
	amb.update_targets()
	t.check(amb.get_target(&"rain_leaves") > 0.9, "under the forest trees fat drops patter on the leaves")

	# Indoors: rain drums on the roof, clear, while the outside is muffled.
	var room := t.get_tree().get_first_node_in_group(&"indoors") as Node3D
	if room:
		player.teleport_to(room.global_position + Vector3(0, 0.3, 0))
		await t._frames(5)
		amb.update_targets()
		await t._frames(150)
		var roof_db := (amb.get_node("rain_roof") as AudioStreamPlayer).volume_db
		t.check(amb.is_indoors() and amb.get_target(&"rain_roof") > 0.9 and roof_db > IslandAmbience.LAYERS[&"rain_roof"] - 6.0, "indoors the rain drums on the roof (%.0f dB)" % roof_db)
		t.check(amb.get_cutoff() < 3000.0, "while the outside stays muffled (low-pass %.0f Hz)" % amb.get_cutoff())

	# The rain stops: the island drips for a while.
	await _go(t, amb, player, IslandShape.FOREST_CENTER + Vector2(10, 5))
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	await t._frames(5)
	amb.update_targets()
	t.check(amb.get_target(&"drips") > 0.5 and amb.get_target(&"rain") < 0.01 and amb.get_target(&"rain_roof") < 0.01, "when the rain stops, the leaves keep dripping (%.2f)" % amb.get_target(&"drips"))

	# Cloudy and snowy days.
	await _go(t, amb, player, Vector2(0, 115))
	ActivityClock.from_dict({"total_minutes": 10 * 60})
	amb.update_targets()
	var calm := amb.get_target(&"wind")
	WeatherManager.set_weather(WeatherManager.Weather.CLOUDY)
	amb.update_targets()
	t.check(amb.get_target(&"wind") > calm and amb.get_target(&"gusty") > 0.5, "cloudy days are breezier, with gusts of wind")
	ActivityClock.from_dict({"total_minutes": 85 * 1440 + 10 * 60})  # winter
	WeatherManager.set_weather(WeatherManager.Weather.SNOW)
	amb.update_targets()
	t.check(amb.get_target(&"snow_wind") > 0.5 and amb.get_target(&"snow_places") > 0.5 and amb.get_target(&"rain") < 0.01, "falling snow: a soft whistle of air, snow sliding off the village roofs")
	t.check(ActivityClock.total_minutes == 85 * 1440 + 10 * 60, "weather sounds never move the clock")

	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	main.queue_free()
	await t._frames(3)
	SaveManager.autosave_enabled = autosave_was
	ActivityClock.reset()
	GameManager.reset_flags()


func _go(t: Node, amb: IslandAmbience, player: PlayerController, xz: Vector2) -> void:
	var y := IslandShape.shared().get_height(xz.x, xz.y) + 0.3
	player.teleport_to(Vector3(xz.x, maxf(y, IslandShape.SEA_LEVEL + 0.3), xz.y))
	await t._frames(4)
	amb.update_targets()
