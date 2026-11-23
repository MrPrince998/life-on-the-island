extends RefCounted
## Checks for the fishing and farming sounds. Called from test_runner.gd:
##   await preload("res://tests/action_sound_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FILES := [
	"rod_out", "rod_away", "cast_swish", "reel_click", "drag_click", "bobber_plop", "bite_plunk",
	"fish_splash", "catch_splash", "catch_jingle", "line_snap", "fish_escape", "line_strain",
	"dig", "plant", "water_pour", "fertilize", "harvest", "harvest_jingle", "seed_rattle",
]


func run(t: Node) -> void:
	print("== Fishing and farming sounds ==")
	var missing: Array[String] = []
	for f in FILES:
		if not ResourceLoader.exists(ActionSounds.DIR + f + ".wav"):
			missing.append(f)
	t.check(missing.is_empty(), "all %d action sounds exist %s" % [FILES.size(), str(missing) if missing else ""])

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
	var player := main.get_node("Player") as PlayerController
	var sounds := player.get_node_or_null("ActionSounds") as ActionSounds
	t.check(sounds != null, "the player has fishing and farming sounds")
	if sounds == null:
		main.queue_free()
		await t._frames(3)
		return
	var heard: Array[StringName] = []
	sounds.played.connect(func(s: StringName) -> void: heard.append(s))

	# ---- Fishing: from the end of the dock, out over the lake.
	var fishing := player.get_node("Fishing") as FishingController
	var dock := main.find_child("FishingDock", true, false) as Node3D
	player.teleport_to(dock.global_position + Vector3(0, 0.3, -13.0), 0.0)
	await t._frames(20)
	fishing.grant_rod()
	fishing.toggle_rod()
	t.check(&"rod_out" in heard, "taking the rod out rustles")
	await t._frames(20)
	fishing.bite_wait_override = 0.5
	fishing.begin_charge()
	await t._frames(100)
	heard.clear()
	var clicks_before := sounds.click_count
	fishing.release_cast(0.5)
	var swish_frame := -1
	var plop_frame := -1
	var waited := 0
	while fishing.state != FishingController.State.BITE and waited < 400:
		await t._frames(1)
		waited += 1
		if swish_frame < 0 and &"cast_swish" in heard:
			swish_frame = waited
		if plop_frame < 0 and &"bobber_plop" in heard:
			plop_frame = waited
	t.check(swish_frame > 0 and plop_frame > swish_frame, "the cast swishes, then the bobber plops into the water (frames %d, %d)" % [swish_frame, plop_frame])
	t.check(sounds.click_count - clicks_before > 10, "the reel buzzes as the line runs out (%d clicks)" % (sounds.click_count - clicks_before))
	var far := sounds.get_node("AtBobber") as AudioStreamPlayer3D
	t.check(far.global_position.distance_to(player.global_position) > 3.0, "the plop is heard out on the water (%.1f m away)" % far.global_position.distance_to(player.global_position))
	t.check(&"bite_plunk" in heard, "a bite plunks the bobber under")
	fishing.hook()
	t.check(&"fish_splash" in heard, "hooking the fish makes it splash")
	clicks_before = sounds.click_count
	var strained := false
	waited = 0
	while fishing.state == FishingController.State.REELING and waited < 60 * 90:
		fishing.reel_override = 1 if fishing.get_minigame().tension < 0.62 else 0
		await t._frames(1)
		waited += 1
	fishing.reel_override = -1
	t.check(sounds.click_count - clicks_before > 20, "reeling in clicks with the crank (%d clicks)" % (sounds.click_count - clicks_before))
	t.check(&"catch_splash" in heard and &"catch_jingle" in heard, "a catch: a big splash and a happy jingle")
	waited = 0
	while fishing.state == FishingController.State.LANDING and waited < 400:
		await t._frames(1)
		waited += 1

	# Reeling hard: the line strains, then snaps.
	fishing.bite_wait_override = 0.1
	fishing.begin_charge()
	await t._frames(100)
	fishing.release_cast(0.5)
	waited = 0
	while fishing.state != FishingController.State.BITE and waited < 400:
		await t._frames(1)
		waited += 1
	fishing.hook()
	heard.clear()
	waited = 0
	while fishing.state == FishingController.State.REELING and waited < 60 * 30:
		fishing.reel_override = 1
		await t._frames(1)
		waited += 1
		strained = strained or sounds.is_straining()
	fishing.reel_override = -1
	t.check(strained, "a too-tight line creaks and strains")
	t.check(&"line_snap" in heard, "and then it snaps")
	await t._frames(10)
	fishing.toggle_rod()
	t.check(&"rod_away" in heard, "putting the rod away")

	# ---- Farming: each job sounds when it's done; the can sprinkles while it pours.
	var farm := main.get_node("Island/Buildings/FarmField") as FarmField
	var farming := player.get_node("Farming") as FarmingController
	var bed := farm.get_plot(&"farm_plot_01")
	player.teleport_to(bed.global_position + Vector3(0, 0.3, 1.2), 0.0)
	await t._frames(10)
	heard.clear()
	farming.use_plot(bed, false)
	t.check(&"dig" in heard, "digging: the spade bites into the soil")
	InventoryManager.add_item(&"turnip_seeds", 2)
	InventoryManager.add_item(&"carrot_seeds", 1)
	farming.cycle_seed()
	t.check(&"seed_rattle" in heard, "switching seeds rattles the packet")
	farming.cycle_seed()
	farming.use_plot(bed, false)
	t.check(&"plant" in heard, "planting: seeds dropped and patted in")
	InventoryManager.add_item(&"watering_can", 1)
	var poured := false
	farming.use_plot(bed)
	waited = 0
	while farming.is_busy() and waited < 200:
		await t._frames(1)
		waited += 1
		poured = poured or sounds.is_pouring()
	await t._frames(40)
	t.check(poured and bed.is_damp(), "watering: the can sprinkles while it pours")
	t.check(not sounds.is_pouring(), "and stops when the can is lifted")
	ActivityClock.advance_minutes(bed.get_minutes_to_harvest() + 60, &"test")
	while not bed.is_ready() and bed.needs_water():
		bed.water()
		ActivityClock.advance_minutes(bed.get_minutes_to_harvest() + 60, &"test")
	heard.clear()
	if bed.is_ready():
		farming.use_plot(bed, false)
	t.check(&"harvest" in heard and &"harvest_jingle" in heard, "harvesting: the crop pops out of the soil, with a little chime")
	var minutes := ActivityClock.total_minutes
	sounds.play(&"dig")
	sounds.play(&"catch_jingle")
	await t._frames(5)
	t.check(ActivityClock.total_minutes == minutes, "the sounds never move the clock")
	main.queue_free()
	await t._frames(3)
	InventoryManager.reset()
	ActivityClock.reset()
	GameManager.reset_flags()
	SaveManager.autosave_enabled = autosave_was
