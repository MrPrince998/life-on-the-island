extends RefCounted
## Checks for slice 4: Grandpa's tractor (Tractor) and its implements working the field
## rows (CropField machine API). Called from test_runner.gd:
##   await preload("res://tests/tractor_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Grandpa's tractor and farm machines ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	QuestLog.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var tractor := main.get_node("Island/Buildings/TractorSpot/Tractor") as Tractor
	var site := main.get_node("Island/Buildings/TractorSpot/RestoreSpot") as RestorationSite
	var seat := tractor.get_node("SeatSpot") as TractorSeat
	var wheat := main.get_node("Island/Buildings/WheatField") as CropField
	var paddy := main.get_node("Island/Buildings/RicePaddy") as CropField

	# ---- Restoring it ----
	t.check(tractor != null and not tractor.is_restored() and not seat.can_interact_now(player) and not tractor.mount(player), "Grandpa's tractor stands rusting by the barn: it can't be driven yet")
	t.check(site.get_prompt().contains("Grandpa's Tractor") or site.get_prompt().contains("tractor"), "the repair spot: \"%s\"" % site.get_prompt())
	InventoryManager.add_item(&"log", 4)
	InventoryManager.add_item(&"wooden_plank", 6)
	InventoryManager.add_money(2000)
	var clock := ActivityClock.total_minutes
	t.check(site.restore_now() and tractor.is_restored(), "with logs, planks and coins, Theo helps get it running")
	t.check(ActivityClock.total_minutes == clock + 180, "the repair takes 3 hours")

	# ---- Getting on ----
	player.teleport_to(tractor.global_position + Vector3(0, 0.3, 2.5))
	await t._frames(3)
	t.check(seat.can_interact_now(player) and seat.get_prompt().contains("tractor"), "by the tractor: \"%s\"" % seat.get_prompt())
	seat.interact(player)
	await t._frames(3)
	t.check(player.is_driving() and tractor.has_driver() and player.is_input_locked() and tractor.is_engine_on(), "E climbs on and starts the engine")
	t.check(player.global_position.distance_to(tractor.get_seat().global_position) < 0.6, "you sit on the seat and ride along")
	var rig := player.get_node("CameraRig") as CameraRig
	t.check(rig.is_vehicle_view(), "the camera pulls back for driving")

	# ---- Driving ----
	clock = ActivityClock.total_minutes
	var start := tractor.global_position
	tractor.set_drive_input(Vector2(0, -1))
	await t._frames(90)
	var moved := tractor.global_position - start
	var forward_before := -tractor.global_basis.z
	t.check(Vector2(moved.x, moved.z).length() > 1.5 and tractor.get_speed() > 2.0, "W drives forward, picking up speed like an old tractor (%.1f m in 1.5 s)" % Vector2(moved.x, moved.z).length())
	t.check(player.global_position.distance_to(tractor.get_seat().global_position) < 0.6, "and the driver goes with it")
	tractor.set_drive_input(Vector2(-1, -1))
	await t._frames(60)
	t.check((-tractor.global_basis.z).angle_to(forward_before) > 0.3, "A/D steers")
	tractor.set_drive_input(Vector2.ZERO)
	await t._frames(180)
	t.check(absf(tractor.get_speed()) < 0.2, "let go and it rolls to a stop")
	t.check(ActivityClock.total_minutes == clock, "driving, like walking, takes no in-game time")

	# ---- Implements ----
	t.check(tractor.cycle_implement() == &"", "no implements yet")
	InventoryManager.add_money(3000)
	t.check(BlacksmithService.buy(&"plough").result == BlacksmithService.Result.OK and BlacksmithService.buy(&"seed_drill").result == BlacksmithService.Result.OK and BlacksmithService.buy(&"harvester").result == BlacksmithService.Result.OK, "Bram sells a plough, a seed drill and a harvester")
	clock = ActivityClock.total_minutes
	t.check(tractor.cycle_implement() == &"plough" and ActivityClock.total_minutes == clock + Tractor.HITCH_MINUTES, "Q hitches the plough (%d min)" % Tractor.HITCH_MINUTES)
	t.check((tractor.get_node("Model/Plough") as Node3D).visible and not (tractor.get_node("Model/Harvester") as Node3D).visible, "you can see what's hitched")
	tractor.set_lowered(true)
	t.check(tractor.lowered and tractor.get_drive_prompt().contains("raise the plough"), "Space lowers it: \"%s\"" % tractor.get_drive_prompt())

	# ---- Ploughing a row by driving along it ----
	# Wheat rows run north-south; row 0 is the westernmost. Start north of the field,
	# heading south, so the plough (behind) runs the length of the row.
	var row_x := wheat.row_center(0).x
	var north := wheat.to_global(Vector3(0, 0, -wheat.row_length * 0.5)).z
	var spot := Vector3(row_x, 0, north - 5.0)
	spot.y = IslandShape.shared().get_height(spot.x, spot.z) + 0.1
	tractor.global_position = spot
	tractor.global_rotation = Vector3(0, PI, 0)
	tractor.set_lowered(true)
	await t._frames(5)
	clock = ActivityClock.total_minutes
	Engine.time_scale = 6.0
	tractor.set_drive_input(Vector2(0, -1))
	var saw_progress := false
	for i in 900:
		await t._frames(1)
		if tractor.get_status().contains("%"):
			saw_progress = true
		if wheat.get_row_state(0) == CropField.RowState.TILLED:
			break
	tractor.set_drive_input(Vector2.ZERO)
	Engine.time_scale = 1.0
	await t._frames(150)
	t.check(saw_progress, "the prompt shows the ploughing as it goes (\"Ploughing row 1: …%\")")
	t.check(GameManager.current_region_id == &"amber_plains", "while you drive, the game still knows where you are (Amber Plains)")
	t.check(wheat.get_row_state(0) == CropField.RowState.TILLED and ActivityClock.total_minutes == clock + int(CropField.MACHINE_MINUTES[&"plough"]), "driving the length of a row ploughs it (%d min, vs 30 by hand)" % int(CropField.MACHINE_MINUTES[&"plough"]))
	t.check(wheat.get_row_state(1) == CropField.RowState.EMPTY, "only the row under the plough")

	# ---- Sowing and harvesting (the field's machine API, a metre at a time) ----
	InventoryManager.add_item(&"wheat_seed", 2)
	t.check(_run_row(wheat, 1, &"seed_drill").reason.contains("ploughing"), "the seed drill needs ploughed ground")
	t.check(_run_row(wheat, 0, &"seed_drill").get("finished", false) and wheat.get_row_state(0) == CropField.RowState.GROWING and InventoryManager.get_count(&"wheat_seed") == 1, "the seed drill sows a ploughed row (one sack of seed)")
	for i in wheat.crop.grow_days:
		ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"test")
	await t._frames(2)
	t.check(wheat.get_row_state(0) == CropField.RowState.RIPE, "(the wheat ripens)")
	var grain_before := InventoryManager.get_count(&"wheat_grain")
	clock = ActivityClock.total_minutes
	var harvested := _run_row(wheat, 0, &"harvester")
	var grain := InventoryManager.get_count(&"wheat_grain") - grain_before
	t.check(harvested.get("finished", false) and wheat.get_row_state(0) == CropField.RowState.EMPTY and bool(wheat.get_row(0).stubble), "the harvester cuts a ripe row in one pass, leaving stubble")
	t.check(grain >= wheat.crop.sheaves_per_row.x * 3 and InventoryManager.get_count(&"wheat_sheaf") == 0 and ActivityClock.total_minutes == clock + int(CropField.MACHINE_MINUTES[&"harvester"]), "and the grain goes straight into the bag: %d Wheat Grain, no sheaves to thresh" % grain)
	t.check(GameManager.has_flag(&"field_cut_wheat"), "(Marlow's wheat orders unlock as if cut by hand)")

	# The paddy: harvest only once it's drained.
	paddy.set_flooded(true)
	InventoryManager.add_item(&"rice_seedlings", 1)
	paddy.plant_now(0)
	for i in paddy.crop.grow_days:
		ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"test")
	await t._frames(2)
	t.check(_run_row(paddy, 0, &"harvester").reason.contains("Drain"), "rice in a flooded paddy: drain it first")
	paddy.set_flooded(false)
	var rice_before := InventoryManager.get_count(&"paddy_rice")
	t.check(_run_row(paddy, 0, &"harvester").get("finished", false) and InventoryManager.get_count(&"paddy_rice") > rice_before, "the harvester works the rice paddy too (unhusked rice straight into the bag)")
	t.check(_run_row(paddy, 1, &"plough").reason.contains("paddy"), "(a paddy isn't ploughed)")

	# ---- Getting off ----
	tractor.set_lowered(false)
	t.check(tractor.request_exit() and not player.is_driving() and not player.is_input_locked() and not tractor.has_driver() and not rig.is_vehicle_view(), "E climbs off (when it's stopped)")
	await t._frames(3)
	t.check(player.global_position.distance_to(tractor.global_position) < 3.5 and player.global_position.distance_to(tractor.global_position) > 1.0, "you step down beside it")

	# ---- Save and load ----
	var saved: Dictionary = JSON.parse_string(JSON.stringify(tractor.save_state()))
	var parked := tractor.global_position
	tractor.global_position += Vector3(10, 0, 0)
	tractor.hitch(&"")
	tractor.load_state(saved)
	t.check(tractor.global_position.distance_to(parked) < 0.2 and tractor.implement == &"plough", "it stays where you parked it, with the plough still hitched")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


## Runs a machine down a row a metre at a time; returns the last result.
func _run_row(field: CropField, index: int, tool: StringName) -> Dictionary:
	var result := {}
	var x := field.row_center(index)
	var steps := int(ceil(field.row_length / CropField.SEGMENT))
	for i in steps:
		var z := -field.row_length * 0.5 + (i + 0.5) * CropField.SEGMENT
		var p := field.to_global(Vector3(field.to_local(x).x, 0, z))
		result = field.machine_work(tool, p)
		if result.is_empty() or not result.ok or result.get("finished", false):
			break
	return result
