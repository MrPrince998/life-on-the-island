extends Node
## Headless checks for the Phase 1 foundation.
## Run:  Godot --headless --path . res://tests/test_runner.tscn
## Exits with code 0 when everything passes, 1 otherwise.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _failures: Array[String] = []
var _passes := 0


func _ready() -> void:
	# Watchdog: a script error inside _run() would otherwise leave Godot running forever.
	get_tree().create_timer(300.0, true, true).timeout.connect(func() -> void:
		print("TIMEOUT: tests did not finish (a script error above probably stopped them)")
		get_tree().quit(2))
	await _run()
	print("\n==== %d passed, %d failed ====" % [_passes, _failures.size()])
	for failure in _failures:
		print("  FAIL: " + failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   " + label)
	else:
		_failures.append(label)
		print("  FAIL " + label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _run() -> void:
	# Tests (which load the island, so autosave runs) must never touch the player's real save.
	SaveManager.use_test_slot()
	SaveManager.delete_save()
	# Weather would otherwise change at random each time a test sleeps past midnight.
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	print("== ActivityClock ==")
	ActivityClock.reset()
	check(ActivityClock.get_day() == 1 and ActivityClock.get_time_string() == "6:00 AM", "starts Day 1, 6:00 AM")
	var advanced := []
	var on_advance := func(minutes: int, activity: StringName) -> void: advanced.append([minutes, activity])
	ActivityClock.time_advanced.connect(on_advance)
	ActivityClock.advance_minutes(90, &"test")
	check(ActivityClock.get_time_string() == "7:30 AM", "advance 90 min -> 7:30 AM")
	check(advanced.size() == 1 and advanced[0][1] == &"test", "time_advanced signal carries activity id")
	ActivityClock.advance_minutes(0, &"test")
	check(ActivityClock.get_time_string() == "7:30 AM", "non-positive advance ignored")
	check(ActivityClock.minutes_until(6) == 1350, "minutes_until(6) wraps to next morning")
	var days := []
	var on_day := func(day: int) -> void: days.append(day)
	ActivityClock.day_started.connect(on_day)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	check(ActivityClock.get_day() == 2 and ActivityClock.get_time_string() == "6:00 AM" and days == [2], "sleeping rolls to Day 2, 6:00 AM")
	ActivityClock.advance_minutes(1440 * 27, &"test")
	check(ActivityClock.get_season_id() == &"summer" and ActivityClock.get_day_of_season() == 1, "Day 29 is Summer 1")
	var saved := ActivityClock.to_dict()
	ActivityClock.reset()
	ActivityClock.from_dict(saved)
	check(ActivityClock.get_day() == 29, "to_dict/from_dict round trip")
	ActivityClock.time_advanced.disconnect(on_advance)
	ActivityClock.day_started.disconnect(on_day)
	ActivityClock.reset()

	print("== Island shape ==")
	var shape := IslandShape.new()
	check(shape.get_height(0, 0) > 0.0 or Vector2(0, 0).distance_to(IslandShape.LAKE_CENTER) < IslandShape.LAKE_RADIUS, "centre is land or lake")
	check(shape.get_height(300, 0) < -2.0 and shape.get_height(0, -300) < -2.0 and shape.get_height(-300, 0) < -2.0 and shape.get_height(0, 300) < -2.0, "edges are open sea")
	check(shape.get_height(IslandShape.LAKE_CENTER.x, IslandShape.LAKE_CENTER.y) < IslandShape.LAKE_LEVEL - 2.0, "lake is deep in the middle")
	check(shape.get_height(IslandShape.LAKE_CENTER.x, IslandShape.LAKE_CENTER.y) > IslandShape.SEA_LEVEL, "lake bed stays above sea level")
	check(shape.get_height(IslandShape.HILLS_CENTER.x, IslandShape.HILLS_CENTER.y) > 20.0, "northern hills are tall")
	check(absf(shape.get_height(10, 57) - 3.85) < 0.6, "dock meets the shore")
	check(shape.get_height(10, 42) < IslandShape.LAKE_LEVEL - 1.0, "dock end is over water")

	print("== Main scene ==")
	var load_start := Time.get_ticks_msec()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	print("  (world built in %d ms)" % (Time.get_ticks_msec() - load_start))
	await _frames(30)
	var player := main.get_node("Player") as PlayerController
	var terrain := main.get_node("Island/Terrain") as IslandTerrain
	check(player.is_on_floor(), "player is standing at spawn")
	check(absf(player.global_position.y - terrain.shape.get_height(player.global_position.x, player.global_position.z)) < 0.5, "player rests on the terrain surface")
	check(GameManager.current_region_id == &"willowbrook_village", "spawn is in Willowbrook Village")

	var minutes_before := ActivityClock.total_minutes
	var start := player.global_position
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(180)
	Input.action_release(&"sprint")
	Input.action_press(&"move_left")
	await _frames(60)
	Input.action_release(&"move_left")
	Input.action_release(&"move_forward")
	await _frames(40)
	var travelled := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	check(travelled > 6.0, "player walks/sprints (moved %.1f m)" % travelled)
	check(ActivityClock.total_minutes == minutes_before, "walking and sprinting do NOT advance time")
	check(player.get_horizontal_speed() < 0.3, "player decelerates to a stop")

	Input.action_press(&"jump")
	await _frames(8)
	Input.action_release(&"jump")
	check(not player.is_on_floor() and player.velocity.y > 0.0, "jump leaves the ground")
	await _frames(90)
	check(player.is_on_floor(), "player lands again")
	check(ActivityClock.total_minutes == minutes_before, "jumping does NOT advance time")

	var rig := player.get_node("CameraRig") as CameraRig
	var camera_pos := rig.get_camera().global_position
	check(camera_pos.y > terrain.shape.get_height(camera_pos.x, camera_pos.z), "camera stays above the terrain")

	print("== Vegetation (Tripo models) ==")
	var vegetation := main.get_node("Island/Vegetation") as VegetationScatter
	for layer in vegetation.layers:
		var placed := vegetation.get_instance_count(layer.id)
		check(placed >= int(layer.count * 0.6), "%s placed %d of %d" % [layer.id, placed, layer.count])
	check(vegetation.get_instance_count(&"landmark") == 1, "lone tree stands on the lake island")
	var lake_plants_ok := true
	var lily_float_ok := vegetation.get_placements(&"lily_pads").size() > 0
	for lake_layer in [&"reeds", &"lily_pads"]:
		for xf: Transform3D in vegetation.get_placements(lake_layer):
			var o := xf.origin
			if Geometry2D.get_closest_point_to_segment(Vector2(o.x, o.z), Vector2(10, 60), Vector2(10, 36)).distance_to(Vector2(o.x, o.z)) < 4.5:
				lake_plants_ok = false
			if lake_layer == &"lily_pads" and absf(o.y - IslandShape.LAKE_LEVEL) > 0.1:
				lily_float_ok = false
	check(vegetation.get_instance_count(&"reeds") > 60 and vegetation.get_instance_count(&"lily_pads") > 25, "reeds line the lake and lily pads float on it (%d reeds, %d lily pads)" % [vegetation.get_instance_count(&"reeds"), vegetation.get_instance_count(&"lily_pads")])
	check(lily_float_ok, "lily pads sit on the water surface")
	check(lake_plants_ok, "reeds and lily pads keep clear of the fishing dock")
	# Trees, bushes and other land plants never stand in the lake or the sea.
	var wet_plants: Array[String] = []
	for layer in vegetation.layers:
		if layer.float_on_water or layer.lake_edge > 0.0 or layer.lake_surface > 0.0:
			continue
		for xf: Transform3D in vegetation.get_placements(layer.id):
			var spot := Vector2(xf.origin.x, xf.origin.z)
			var water := IslandShape.LAKE_LEVEL if terrain.shape.get_lake_distance(spot) < 1.6 else IslandShape.SEA_LEVEL
			if terrain.shape.get_height(spot.x, spot.y) < water + 0.25:
				wet_plants.append("%s at (%.0f, %.0f)" % [layer.id, spot.x, spot.y])
	check(wet_plants.is_empty(), "no tree or land plant grows in the water %s" % (str(wet_plants.slice(0, 4)) if not wet_plants.is_empty() else ""))
	var lakeside_trees := 0
	for tree_id in [&"tree_broadleaf", &"tree_slender", &"tree_cherry", &"tree_blossom", &"tree_white_blossom"]:
		for xf: Transform3D in vegetation.get_placements(tree_id):
			var lake_d := terrain.shape.get_lake_distance(Vector2(xf.origin.x, xf.origin.z))
			if lake_d > 0.85 and lake_d < 1.5:
				lakeside_trees += 1
	check(lakeside_trees >= 30, "trees grow around Moonlit Lake (%d)" % lakeside_trees)
	# Buildings rest on the ground: the walls at the back of each house reach the terrain
	# (a model whose front steps hang lower than its walls once left a farmhouse floating).
	var floating: Array[String] = []
	for building_path in ["Island/Buildings/FarmField/Farmhouse", "Island/Buildings/FarmField/Barn", "Island/Buildings/FarmField/Greenhouse", "Island/Buildings/FarmField/GardenShed", "Island/Buildings/Cottage", "Island/Buildings/GeneralStore"]:
		var building := main.get_node_or_null(building_path) as Node3D
		if building == null:
			continue
		var pts: Array[Vector3] = []
		for mesh_node: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
			if mesh_node.mesh == null:
				continue
			for surface in mesh_node.mesh.get_surface_count():
				for v: Vector3 in mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					pts.append(mesh_node.global_transform * v)
		if pts.is_empty():
			continue
		var bounds := AABB(pts[0], Vector3.ZERO)
		for q in pts:
			bounds = bounds.expand(q)
		# Lowest point in each of the four back/side corners of the footprint.
		var gaps: Array[float] = []
		# A building may stand on its own soil mound (SoilMound); that counts as ground.
		var mound := building.get_node_or_null("SoilMound") as SoilMound
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var lowest := INF
			for q in pts:
				var rx := (q.x - bounds.get_center().x) / (bounds.size.x * 0.5)
				var rz := (q.z - bounds.get_center().z) / (bounds.size.z * 0.5)
				if rx * corner.x > 0.25 and rz * corner.y > 0.25:
					lowest = minf(lowest, q.y)
			if lowest < INF:
				var ground := terrain.shape.get_height(bounds.get_center().x, bounds.get_center().z)
				if mound:
					var corner_local := building.to_local(Vector3(bounds.get_center().x + corner.x * bounds.size.x * 0.4, 0.0, bounds.get_center().z + corner.y * bounds.size.z * 0.4))
					ground += mound.height_at(corner_local.x, corner_local.z)
				gaps.append(lowest - ground)
		gaps.sort()
		# At most one corner (e.g. a porch or steps) may sit higher than 0.35 m.
		if gaps.size() >= 3 and gaps[gaps.size() - 2] > 0.35:
			floating.append("%s %.2f m" % [building.name, gaps[gaps.size() - 2]])
	check(floating.is_empty(), "farm and village buildings rest on the ground %s" % str(floating))
	# The farmhouse's garden gate is open: the player can walk through it, up the steps,
	# onto the porch to the front door.
	var before_gate := player.global_position
	var before_yaw := (player.get_node("CameraRig") as CameraRig).get_yaw()
	var farmhouse := main.get_node("Island/Buildings/FarmField/Farmhouse") as Node3D
	var gate_start := farmhouse.to_global(Vector3(0.46, 0.0, 8.5))
	gate_start.y = terrain.shape.get_height(gate_start.x, gate_start.z) + 0.3
	var gate_yaw := atan2(farmhouse.global_basis.z.x, farmhouse.global_basis.z.z)
	player.teleport_to(gate_start, gate_yaw)
	(player.get_node("CameraRig") as CameraRig).set_yaw(gate_yaw)
	await _frames(10)
	Input.action_press(&"move_forward")
	await _frames(300)
	Input.action_release(&"move_forward")
	await _frames(30)
	var on_porch := farmhouse.to_local(player.global_position)
	check(on_porch.z < 2.6 and on_porch.y > 1.4, "the player can walk through the farmhouse gate and up onto the porch (%.2f m up, %.2f m in)" % [on_porch.y, on_porch.z])
	player.teleport_to(before_gate, before_yaw)
	(player.get_node("CameraRig") as CameraRig).set_yaw(before_yaw)
	await _frames(20)
	# Visible fish swimming in the lake and the sea (decoration).
	await _frames(5)
	var lake_school := main.get_node("Island/MoonlitLake/AmbientFish") as AmbientFish
	var lake_fish_ok := lake_school != null and lake_school.get_fish_count() >= 10
	if lake_school:
		for pos in lake_school.get_fish_positions():
			var lake_floor := terrain.shape.get_height(pos.x, pos.z)
			if pos.y >= IslandShape.LAKE_LEVEL or pos.y <= lake_floor or terrain.shape.get_lake_distance(Vector2(pos.x, pos.z)) > 1.0:
				lake_fish_ok = false
	check(lake_fish_ok, "fish swim under the surface of Moonlit Lake (%d)" % (lake_school.get_fish_count() if lake_school else 0))
	var sea_school := main.get_node("Island/Sea/AmbientFish") as AmbientFish
	check(sea_school != null, "the sea has its own swimming fish")

	print("== New models ==")
	for new_layer in [&"tree_pine", &"tree_slender", &"tree_cherry", &"tree_blossom", &"tree_white_blossom", &"sapling", &"mushrooms"]:
		check(vegetation.get_instance_count(new_layer) > 0, "%s is placed on the island (%d)" % [new_layer, vegetation.get_instance_count(new_layer)])
	var flower_layer: FoliageLayer = null
	for l in vegetation.layers:
		if l.id == &"flowers":
			flower_layer = l
	check(flower_layer != null and flower_layer.model.resource_path.ends_with("flowers_cluster.glb"), "flowers use the new flower-cluster model")
	var fish_catalog := load("res://data/fish/fish_catalog.tres") as FishCatalog
	var modelled: Array[StringName] = [&"silver_minnow", &"sunfish", &"sea_bream", &"blue_mackerel", &"flying_fish", &"azure_manta"]
	var all_modelled := true
	for fish_id in modelled:
		all_modelled = all_modelled and fish_catalog.get_fish(fish_id).get_model() != null
	check(all_modelled, "minnow, sunfish, sea bream, mackerel, flying fish and manta have their 3D models")
	var lighthouse := main.get_node("Island/Buildings/Lighthouse") as Node3D
	check(lighthouse.get_node_or_null("Model") != null and absf(lighthouse.global_position.y - (terrain.shape.get_height(lighthouse.global_position.x, lighthouse.global_position.z) - 0.4)) < 0.05, "the lighthouse model stands on the headland")
	var rowboat := main.get_node("Island/Buildings/Rowboat") as Node3D
	var boat_bed := terrain.shape.get_height(rowboat.global_position.x, rowboat.global_position.z)
	check(rowboat.global_position.y < IslandShape.LAKE_LEVEL and boat_bed < rowboat.global_position.y - 0.2, "the rowboat floats on the lake beside the dock (lake bed %.2f m below the hull)" % (rowboat.global_position.y - boat_bed))
	var bench_rest := main.get_node("Island/Buildings/LakeBench/SitRest") as RestSpot
	check(bench_rest.mode == RestSpot.Mode.SIT and bench_rest.get_seat().position.x > 0.2 and bench_rest.get_minutes_for_activity() == 0, "the lakeshore bench is a seat (on the end Oliver leaves free) and sitting uses no time")
	var fence_pieces := 0
	var fence_bodies := 0
	for edge in main.get_node("Island/Buildings/FarmField/Fence").get_children():
		for c in edge.get_children():
			if c is StaticBody3D:
				fence_bodies += 1
			elif c is Node3D:
				fence_pieces += 1
	check(fence_pieces >= 40 and fence_bodies == 6, "the farm fence is built from fence sections with collision (%d sections)" % fence_pieces)
	var veg_body := vegetation.get_node_or_null("VegetationCollision") as StaticBody3D
	check(veg_body != null and veg_body.get_child_count() > 300, "trees and bushes have trunk collision")
	var clear_ok := true
	for layer in vegetation.layers:
		for xf: Transform3D in vegetation.get_placements(layer.id):
			var o := xf.origin
			if Vector2(o.x, o.z).distance_to(Vector2(-25.5, 100)) < 6.0 or Vector2(o.x, o.z).distance_to(Vector2(0, 115)) < 2.5:
				clear_ok = false
	check(clear_ok, "no plants grow inside the cottage or the well")
	var lanterns := main.get_node("Island/Buildings/Lanterns").get_children()
	var grounded := lanterns.size() >= 6
	for lantern: Node3D in lanterns:
		grounded = grounded and absf(lantern.global_position.y - terrain.shape.get_height(lantern.global_position.x, lantern.global_position.z)) < 0.2
	check(grounded, "village lantern posts stand on the ground")

	print("== Character animation ==")
	var animator := player.get_node("Visual/Character") as CharacterAnimator
	var lib := load("res://resources/animations/character_library.tres") as AnimationLibrary
	var needed: Array[StringName] = [&"idle", &"walk", &"run", &"jump", &"fish_cast", &"fish_reel", &"farm_swing", &"wave"]
	var all_present := true
	for anim_name in needed:
		all_present = all_present and lib.has_animation(anim_name)
	check(all_present, "animation library has all 8 clips")
	if ResourceLoader.exists("res://source_assets/mixamo/Running.fbx"):
		check(is_equal_approx(lib.get_animation(&"run").length, 0.7), "the run clip is the retargeted Mixamo run")
	check(animator.get_current_animation() == &"idle", "standing still plays idle")
	Input.action_press(&"move_forward")
	await _frames(20)
	check(animator.get_current_animation() == &"walk", "walking switches to walk")
	var ap := animator.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var expected_rate: float = player.get_horizontal_speed() / CharacterAnimator.WALK_METRES_PER_SECOND_AT_SCALE_ONE
	check(absf(ap.speed_scale - expected_rate) < 0.35, "leg speed matches walking speed (scale %.2f, expected %.2f)" % [ap.speed_scale, expected_rate])
	Input.action_press(&"sprint")
	await _frames(40)
	check(animator.get_current_animation() == &"run", "sprinting switches to the run clip (got %s)" % animator.get_current_animation())
	var run_rate: float = player.get_horizontal_speed() / CharacterAnimator.RUN_METRES_PER_SECOND_AT_SCALE_ONE
	check(absf(ap.speed_scale - run_rate) < 0.2, "run leg speed matches sprint speed (scale %.2f, expected %.2f)" % [ap.speed_scale, run_rate])
	Input.action_release(&"sprint")
	await _frames(40)
	check(animator.get_current_animation() == &"walk", "releasing sprint goes back to walk")
	Input.action_release(&"move_forward")
	await _frames(90)
	check(animator.get_current_animation() == &"idle", "stopping returns to idle")
	var skel := animator.find_child("Skeleton3D", true, false) as Skeleton3D
	var arms_ok := true
	for pair in [["mixamorig_LeftArm", "mixamorig_LeftForeArm"], ["mixamorig_RightArm", "mixamorig_RightForeArm"]]:
		var a := skel.find_bone(pair[0])
		var b := skel.find_bone(pair[1])
		var dir := (skel.get_bone_global_pose(b).origin - skel.get_bone_global_pose(a).origin).normalized()
		arms_ok = arms_ok and dir.y < -0.9
	check(arms_ok, "arms hang down at the sides when standing")
	var legs_ok := true
	for leg in ["mixamorig_LeftLeg", "mixamorig_RightLeg", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg"]:
		var idx := skel.find_bone(leg)
		var off := rad_to_deg(skel.get_bone_rest(idx).basis.get_rotation_quaternion().angle_to(skel.get_bone_pose_rotation(idx)))
		legs_ok = legs_ok and off < 3.0
	check(legs_ok, "legs return to the model's own standing pose after stopping")
	check(animator.play_action(&"wave") and animator.get_current_animation() == &"wave", "an action (wave) can be started")
	await _frames(180)
	check(animator.get_current_animation() == &"idle", "a one-shot action ends and the character returns to idle")
	check(animator.play_action(&"fish_reel"), "looping action (fish_reel) starts")
	animator.stop_action()
	check(not animator.play_action(&"not_a_clip"), "unknown action name is refused")

	print("== Cottage ==")
	var cottage := main.get_node("Island/Buildings/Cottage") as Node3D
	check(cottage.get_node_or_null("Model") != null, "the cottage uses the Tripo house model")
	var bench := main.get_node("Island/Buildings/Cottage/PorchRest") as RestSpot
	var bed := main.get_node("Island/Buildings/Cottage/Interior/BedRest") as RestSpot
	var front_door := main.get_node("Island/Buildings/Cottage/FrontDoor") as HouseDoor
	var interaction := player.get_node("InteractionArea") as PlayerInteraction
	# Walk from the path, up the porch steps, to the front door.
	player.teleport_to(Vector3(-16.0, terrain.shape.get_height(-16.0, 100.0) + 0.2, 100.0), PI * 0.5)
	await _frames(10)
	Input.action_press(&"move_forward")
	var saw_porch_prompt := false
	for i in 300:
		await _frames(1)
		saw_porch_prompt = saw_porch_prompt or interaction.get_current() == bench
	Input.action_release(&"move_forward")
	await _frames(20)
	var ground_here := terrain.shape.get_height(player.global_position.x, player.global_position.z)
	check(player.is_on_floor() and player.global_position.y > ground_here + 0.3 and player.global_position.x < -21.5, "player can walk up the steps onto the porch (x=%.2f, %.2f m above the ground)" % [player.global_position.x, player.global_position.y - ground_here])
	check(player.global_position.x > -23.8, "the house walls stop the player at the front door")
	check(saw_porch_prompt, "walking past the steps offers to sit on them")
	check(interaction.get_current() == front_door, "at the front door the \"Go inside\" prompt appears")
	var before := ActivityClock.total_minutes
	var character_anim := player.get_node("Visual/Character") as CharacterAnimator
	bench.interact(player)
	await _frames(100)
	var seat_y := bench.get_seat().global_position.y
	check(player.is_sitting() and player.is_input_locked() and character_anim.is_seated(), "E on the porch steps sits you down")
	check(absf(player.global_position.y + PlayerController.SIT_HIP_ABOVE_ORIGIN - seat_y) < 0.02, "the player is lowered onto the step")
	check(ActivityClock.total_minutes == before, "sitting doesn't use any time")
	check(interaction.get_prompt_text() == PlayerInteraction.STAND_UP_PROMPT, "while seated, E offers to stand up")
	await _frames(60)
	check(character_anim.get_current_animation() == &"sit_idle" and ActivityClock.total_minutes == before, "the sitting pose holds, and still no time passes")
	player.stand_up()
	await _frames(150)
	check(not player.is_sitting() and not player.is_input_locked() and player.is_on_floor(), "standing up lets the player walk again")
	check(ActivityClock.total_minutes == before, "getting up uses no time either")
	bed.interact(player)
	check(ActivityClock.get_day() == 2 and ActivityClock.get_time_string() == "6:00 AM", "sleeping in Grandpa's bed wakes you at 6:00 AM next day")
	await _frames(10)

	print("== Fishing dock ==")
	var dock := main.get_node("Island/Buildings/FishingDock") as Node3D
	player.teleport_to(dock.global_position + Vector3(0, 0.3, -12.0), 0.0)
	await _frames(40)
	check(player.is_on_floor() and absf(player.global_position.y - dock.global_position.y) < 0.2, "player can stand on the dock")
	check(GameManager.current_region_id == &"moonlit_lake", "dock is in Moonlit Lake region")
	var respawns := [0]
	var on_respawn := func() -> void:
		respawns[0] += 1
		Input.action_release(&"move_forward")
	player.respawned.connect(on_respawn)
	Input.action_press(&"move_forward")
	await _frames(240)
	Input.action_release(&"move_forward")
	await _frames(30)
	check(respawns[0] >= 1, "walking off the dock into deep water returns you to safety")
	check(player.global_position.y > IslandShape.LAKE_LEVEL, "after rescue the player is above the water")
	player.respawned.disconnect(on_respawn)

	print("== Fishing data ==")
	var catalog := load("res://data/fish/fish_catalog.tres") as FishCatalog
	check(catalog.fish.size() == 7, "seven fish species are defined")
	var lake_noon := catalog.available(&"moonlit_lake", 12).map(func(f: FishData) -> StringName: return f.id)
	var lake_night := catalog.available(&"moonlit_lake", 22).map(func(f: FishData) -> StringName: return f.id)
	var sea_morning := catalog.available(&"sea", 8).map(func(f: FishData) -> StringName: return f.id)
	var sea_night := catalog.available(&"sea", 23).map(func(f: FishData) -> StringName: return f.id)
	check(&"sunfish" in lake_noon and not &"moonfin_koi" in lake_noon, "lake at noon: sunfish yes, moonfin koi no")
	check(&"moonfin_koi" in lake_night and not &"sunfish" in lake_night, "lake at night: moonfin koi yes, sunfish no")
	check(&"blue_mackerel" in sea_morning and not &"blue_mackerel" in sea_night, "blue mackerel only bites in the morning")
	check(&"silver_minnow" in lake_night and &"sea_bream" in sea_night, "every water always has something to catch")
	check(&"azure_manta" in sea_morning and &"azure_manta" in sea_night and catalog.get_fish(&"azure_manta").rarity == FishData.Rarity.RARE, "the Azure Manta is a rare sea fish")
	check(&"flying_fish" in catalog.available(&"sea", 12).map(func(f: FishData) -> StringName: return f.id) and not &"flying_fish" in sea_night, "flying fish bite in the daytime sea")
	check(catalog.get_fish(&"azure_manta").get_model() != null and catalog.get_fish(&"flying_fish").get_model() != null, "the manta and flying fish have their Tripo models")

	print("== Reeling minigame ==")
	var all_fair := true
	for fish in catalog.fish:
		var outcomes := {"good": 0, "hold": 0, "none": 0}
		for policy in outcomes:
			for seed_value in range(1, 31):
				var game := ReelMinigame.new()
				game.setup(fish.difficulty, 10.0, seed_value)
				var r := ReelMinigame.Result.NONE
				var t := 0.0
				while r == ReelMinigame.Result.NONE and t < 120.0:
					var reel: bool = game.tension < 0.62 if policy == "good" else policy == "hold"
					r = game.update(1.0 / 60.0, reel)
					t += 1.0 / 60.0
				if r == ReelMinigame.Result.CAUGHT:
					outcomes[policy] += 1
		all_fair = all_fair and outcomes.good == 30 and outcomes.hold == 0 and outcomes.none == 0
	check(all_fair, "steady reeling lands every species; always-hold and never-reel both fail")

	print("== Fishing at the dock ==")
	var fishing := player.get_node("Fishing") as FishingController
	var dock_node := main.get_node("Island/Buildings/FishingDock") as Node3D
	check(fishing.find_water_at(dock_node.global_position + Vector3(0, 0, -20)) != null, "water ahead of the dock counts as fishable")
	check(fishing.find_water_at(Vector3(0, 0, 115)) == null, "the village square is not water")
	InventoryManager.clear()
	Journal.clear()
	player.teleport_to(dock_node.global_position + Vector3(0, 0.3, -13.0), 0.0)
	await _frames(20)
	# Story: no rod until Oliver gives you one.
	GameManager.reset_flags()
	var rod_toasts: Array[String] = []
	var collect_toast := func(text: String) -> void: rod_toasts.append(text)
	GameManager.notification_posted.connect(collect_toast)
	fishing.toggle_rod()
	check(not fishing.has_rod() and fishing.state == FishingController.State.STOWED and rod_toasts.size() == 1 and rod_toasts[0].contains("dock"), "without a rod, R just hints that someone at the dock can help")
	fishing.grant_rod()
	fishing.grant_rod()
	check(fishing.has_rod() and GameManager.has_flag(FishingController.ROD_FLAG) and rod_toasts.size() == 2, "Oliver's gift gives you the rod (once)")
	GameManager.notification_posted.disconnect(collect_toast)
	check(GameManager.flags_to_dict().flags.has("has_fishing_rod"), "owning the rod is part of the save")
	fishing.toggle_rod()
	check(fishing.state == FishingController.State.READY, "R takes the rod out")
	await _frames(30)
	var char_anim := player.get_node("Visual/Character") as CharacterAnimator
	check(char_anim.get_current_animation() == &"fish_hold", "standing with the rod plays the two-handed rod-holding pose (%s)" % char_anim.get_current_animation())
	var tackle := fishing.get_node("Tackle") as FishingTackle
	var hand_grip := player.find_child("HandGrip", true, false) as HandGrip
	check(hand_grip != null and hand_grip.holding, "the right hand closes into a fist around the rod")
	var rod := tackle.get_node("Rod") as Node3D
	check(rod.global_position.distance_to(tackle.get_hand_position()) < 0.2, "the rod sits in the hand (%.2f m from the wrist)" % rod.global_position.distance_to(tackle.get_hand_position()))
	check(tackle.left_hand == FishingTackle.LeftHand.HANDLE and tackle.get_left_hand_influence() > 0.99, "the left hand takes hold of the rod")
	var butt_error := tackle.get_left_hand_reach_error()
	check(butt_error >= 0.0 and butt_error < 0.03, "the left fist rests on the rod butt (%.3f m off)" % butt_error)
	var rod_dir := -rod.global_basis.z.normalized()
	var hands_dir := tackle.get_hands_aim()
	check(hands_dir != Vector3.ZERO and rad_to_deg(rod_dir.angle_to(hands_dir)) < 12.0, "the rod follows the direction recorded in the holding clip (%.1f deg off)" % rad_to_deg(rod_dir.angle_to(hands_dir)))
	var facing := -(player.get_node("Visual") as Node3D).global_basis.z
	facing.y = 0.0
	var rod_pitch_deg := rad_to_deg(asin(rod_dir.y))
	check(rod_dir.dot(facing.normalized()) > 0.4 and rod_pitch_deg > 35.0 and rod_pitch_deg < 75.0, "the rod is held up in front, not out to the side (pitch %.0f deg, forward %.2f)" % [rod_pitch_deg, rod_dir.dot(facing.normalized())])
	var clock_before := ActivityClock.total_minutes
	fishing.bite_wait_override = 0.5
	fishing.begin_charge()
	check(player.is_input_locked(), "the player stands still while fishing")
	await _frames(110)
	check(ActivityClock.total_minutes == clock_before, "charging a cast costs no time")
	var windup_at := char_anim.get_action_position()
	check(char_anim.get_current_animation() == &"fish_cast" and absf(windup_at - FishingController.CAST_WINDUP) < 0.1, "charging winds up and holds at the top of the cast (%.2f s)" % windup_at)
	check(tackle.get_tip_position().y > player.global_position.y + 0.1, "the wound-up rod tip stays above the ground")
	fishing.release_cast(0.5)
	var waited := 0
	while fishing.state != FishingController.State.BITE and waited < 400:
		await _frames(1)
		waited += 1
	check(fishing.state == FishingController.State.BITE, "the bobber lands in the lake and a fish bites")
	var line_tackle := fishing.get_node("Tackle") as FishingTackle
	var line_pts := line_tackle.get_line_points()
	var reel_mount := line_tackle.find_child("ReelMount", true, false) as Node3D
	check(line_pts.size() >= 7 and reel_mount != null and line_pts[0].distance_to(reel_mount.global_position) < 0.1, "the fishing line starts at the reel")
	var climbs := line_pts.size() >= 7
	for i in range(1, 5):
		climbs = climbs and line_pts[i].distance_to(line_pts[0]) > line_pts[i - 1].distance_to(line_pts[0])
	check(climbs and line_pts[4].distance_to(line_tackle.get_tip_position()) < 0.01, "the line runs up through the rod guides to the tip")
	var bobber_pt := line_pts[line_pts.size() - 2]
	var hook_pt := line_pts[line_pts.size() - 1]
	check(hook_pt.y < bobber_pt.y - 0.4 and line_tackle.get_hook().global_position.distance_to(hook_pt) < 0.01, "a hook hangs on the line below the bobber, under the water")
	check(ActivityClock.total_minutes == clock_before, "waiting for a bite costs no time")
	fishing.hook()
	check(fishing.state == FishingController.State.REELING, "clicking on the bite hooks the fish")
	var hooked := fishing.get_hooked_fish()
	var tackle_node := fishing.get_node("Tackle") as FishingTackle
	check(tackle_node.get_node_or_null("Rod/Model") != null, "the Tripo fishing rod model is used")
	var max_bend := 0.0
	var reel_angles := {}
	var crank_error_max := -1.0
	waited = 0
	while fishing.state == FishingController.State.REELING and waited < 60 * 90:
		fishing.reel_override = 1 if fishing.get_minigame().tension < 0.62 else 0
		await _frames(1)
		waited += 1
		max_bend = maxf(max_bend, tackle_node.rod_bend)
		reel_angles[snappedf(tackle_node.get_reel_angle(), 0.1)] = true
		if waited > 30:
			crank_error_max = maxf(crank_error_max, tackle_node.get_left_hand_reach_error())
	check(crank_error_max >= 0.0 and crank_error_max < 0.03, "while reeling the left hand stays on the turning crank knob (max %.3f m off)" % crank_error_max)
	check(max_bend > 0.3, "the rod bends under line tension while reeling (max bend %.2f)" % max_bend)
	check(reel_angles.size() > 5, "the reel crank turns while reeling (%d distinct angles over %d frames, fish %s)" % [reel_angles.size(), waited, hooked.id if hooked else &"?"])
	fishing.reel_override = -1
	check(fishing.state == FishingController.State.LANDING, "steady reeling lands the fish")
	check(hooked != null and InventoryManager.get_count(hooked.id) == 1, "the fish goes into the bag")
	check(hooked != null and Journal.has_caught(hooked.id), "the fish journal records the species")
	check(ActivityClock.total_minutes == clock_before + fishing.catch_minutes, "a catch advances time by exactly %d minutes" % fishing.catch_minutes)
	waited = 0
	while fishing.state == FishingController.State.LANDING and waited < 400:
		await _frames(1)
		waited += 1
	check(fishing.state == FishingController.State.READY and not player.is_input_locked(), "after the catch you can move again")

	clock_before = ActivityClock.total_minutes
	fishing.begin_charge()
	fishing.release_cast(0.5)
	waited = 0
	while fishing.state != FishingController.State.BITE and waited < 400:
		await _frames(1)
		waited += 1
	waited = 0
	while fishing.state == FishingController.State.BITE and waited < 200:
		await _frames(1)
		waited += 1
	check(fishing.state == FishingController.State.READY and ActivityClock.total_minutes == clock_before + fishing.missed_bite_minutes, "missing a bite costs %d minutes" % fishing.missed_bite_minutes)

	clock_before = ActivityClock.total_minutes
	fishing.bite_wait_override = 30.0
	fishing.begin_charge()
	fishing.release_cast(0.5)
	waited = 0
	while fishing.state != FishingController.State.WAITING and waited < 400:
		await _frames(1)
		waited += 1
	fishing.cancel()
	check(fishing.state == FishingController.State.READY and ActivityClock.total_minutes == clock_before, "reeling in before a bite is free")
	fishing.bite_wait_override = -1.0

	player.teleport_to(Vector3(-4.0, terrain.shape.get_height(-4.0, 110.0) + 0.2, 110.0), PI)
	await _frames(20)
	clock_before = ActivityClock.total_minutes
	fishing.begin_charge()
	fishing.release_cast(0.3)
	waited = 0
	while fishing.state != FishingController.State.READY and waited < 400:
		await _frames(1)
		waited += 1
	check(fishing.state == FishingController.State.READY and ActivityClock.total_minutes == clock_before, "casting onto grass just reels back in, no time used")
	fishing.toggle_rod()
	check(fishing.state == FishingController.State.STOWED, "R puts the rod away")
	await _frames(30)
	check((player.get_node("Visual/Character") as CharacterAnimator).get_current_animation() == &"idle" and not (player.find_child("HandGrip", true, false) as HandGrip).holding, "putting the rod away returns to the normal idle and opens the hand")

	print("== Economy ==")
	QuestLog.reset()  # Quest rewards would otherwise add coins to the sums below.
	check(ItemDB.get_display_name(&"turnip_seeds") == "Turnip Seeds" and ItemDB.get_item(&"turnip_seeds").buy_price == 20, "items are defined as data (Turnip Seeds cost 20)")
	check(ItemDB.get_item(&"sunfish") != null and ItemDB.get_item(&"sunfish").sell_price == 10, "every fish is also a sellable item")
	InventoryManager.reset()
	check(InventoryManager.get_money() == InventoryManager.STARTING_MONEY, "a new game starts with %d coins" % InventoryManager.STARTING_MONEY)
	check(InventoryManager.add_item(&"wooden_plank", 120) == 120 and InventoryManager.get_slots_used() == 3, "items stack (120 planks fill 3 slots of 50)")
	check(InventoryManager.remove_item(&"wooden_plank", 20) == 20 and InventoryManager.get_count(&"wooden_plank") == 100, "items can be removed")
	var fill := InventoryManager.add_item(&"wooden_plank", 5000)
	check(InventoryManager.is_full() and fill == InventoryManager.BAG_SLOTS * 50 - 100, "the bag holds %d slots, then refuses more" % InventoryManager.BAG_SLOTS)
	check(InventoryManager.add_item(&"sunfish") == 0, "a full bag has no room for a fish")
	var full_buy := ShopService.buy(&"turnip_seeds", 1)
	check(full_buy.result == ShopService.Result.BAG_FULL and InventoryManager.get_money() == InventoryManager.STARTING_MONEY, "buying with a full bag fails and costs nothing")
	InventoryManager.reset()
	check(not InventoryManager.spend_money(60) and InventoryManager.get_money() == 50, "you can't spend more coins than you have")
	var seeds := ShopService.buy(&"turnip_seeds", 2)
	check(seeds.result == ShopService.Result.OK and InventoryManager.get_money() == 10 and InventoryManager.get_count(&"turnip_seeds") == 2, "buying 2 turnip seeds costs 40 coins")
	check(ShopService.buy(&"watering_can").result == ShopService.Result.NOT_ENOUGH_MONEY, "can't buy what you can't afford")
	InventoryManager.add_item(&"sunfish", 4)
	var sold := ShopService.sell(&"sunfish", 4)
	check(sold.result == ShopService.Result.OK and InventoryManager.get_money() == 50 and InventoryManager.get_count(&"sunfish") == 0, "selling 4 sunfish earns 40 coins")
	InventoryManager.add_money(10)
	check(ShopService.buy(&"watering_can").result == ShopService.Result.OK and ShopService.buy(&"watering_can").result == ShopService.Result.ALREADY_OWNED, "tools are bought once")
	check(ShopService.sell(&"watering_can").result == ShopService.Result.NOT_SELLABLE and ShopService.sell(&"carrot_seeds").result == ShopService.Result.NOT_ENOUGH_ITEMS, "the store refuses things it doesn't buy or you don't have")
	var saved_bag := InventoryManager.to_dict()
	InventoryManager.reset()
	InventoryManager.from_dict(saved_bag)
	check(InventoryManager.get_money() == 0 and InventoryManager.get_count(&"turnip_seeds") == 2 and InventoryManager.get_count(&"watering_can") == 1, "coins and items survive save and load")
	InventoryManager.from_dict({"version": 1, "items": {"sunfish": 2}})
	check(InventoryManager.get_money() == InventoryManager.STARTING_MONEY and InventoryManager.get_count(&"sunfish") == 2, "old saves without coins load with starting coins")

	var counter := main.get_node("Island/Buildings/GeneralStore/ShopCounter") as ShopCounter
	var shop := main.get_node("ShopPanel") as ShopPanel
	var shop_interaction := player.get_node("InteractionArea") as PlayerInteraction
	var store_node := main.get_node("Island/Buildings/GeneralStore") as Node3D
	var front: Vector3 = counter.global_position + (counter.global_position - store_node.global_position).normalized() * 1.0
	player.teleport_to(Vector3(front.x, terrain.shape.get_height(front.x, front.z) + 0.3, front.z))
	await _frames(20)
	check(shop_interaction.get_current() == counter, "standing at the General Store shows its prompt")
	var shop_clock := ActivityClock.total_minutes
	counter.interact(player)
	check(shop.is_open() and player.is_input_locked(), "pressing E opens the store and the player stands still")
	InventoryManager.reset()
	var ui_buy := shop.buy(&"carrot_seeds", 1)
	shop.show_tab(true)
	InventoryManager.add_item(&"sea_bream", 1)
	var ui_sell := shop.sell(&"sea_bream", 1)
	check(ui_buy.result == ShopService.Result.OK and ui_sell.result == ShopService.Result.OK and InventoryManager.get_money() == 50 - 30 + 9, "buying and selling works from the store screen")
	shop.close()
	check(not shop.is_open() and not player.is_input_locked(), "leaving the store lets the player walk again")
	check(ActivityClock.total_minutes == shop_clock, "shopping doesn't use any time")
	InventoryManager.reset()

	print("== Farming ==")
	# These checks sleep through nights; keep autosave from writing a test save mid-way.
	SaveManager.autosave_enabled = false
	var crops := CropCatalog.shared()
	var crops_ok := crops.crops.size() >= 3
	for crop in crops.crops:
		var seed_item := ItemDB.get_item(crop.seed_item_id)
		var harvest_item := ItemDB.get_item(crop.harvest_item_id)
		crops_ok = crops_ok and seed_item != null and seed_item.buy_price > 0 and harvest_item != null and harvest_item.sell_price > 0
		crops_ok = crops_ok and harvest_item.icon != null and crop.get_stage(crop.get_grow_minutes()) == CropData.Stage.READY
	check(crops_ok, "crops (turnip, carrot, sunflower and the seasonal ones): seeds sold at the store, harvests sellable")
	var farm := main.get_node("Island/Buildings/FarmField") as FarmField
	var plots := farm.get_plots()
	var plot_ids := {}
	for farm_p in plots:
		plot_ids[farm_p.interaction_id] = true
	var open_beds := plots.filter(func(p: FarmPlot) -> bool: return p.is_visible_in_tree()).size()
	check(open_beds == 12 and plots.size() == 20 and plot_ids.size() == 20 and farm.is_in_group(&"persistent"), "the farm has 12 garden beds (and room for 8 more, bought later), each with its own save ID")
	var farming := player.get_node("Farming") as FarmingController
	var farm_bed := farm.get_plot(&"farm_plot_01")
	var ground_y := terrain.shape.get_height(farm_bed.global_position.x, farm_bed.global_position.z)
	check(absf(farm_bed.global_position.y - ground_y) < 0.05 and not farm_bed.tilled and farm_bed.get_node("Weeds").visible, "beds start overgrown and sit on the ground")
	InventoryManager.reset()
	ActivityClock.reset()  # Day 1, 6:00 AM: a morning on the farm.
	var farm_clock := ActivityClock.total_minutes
	check(farming.get_action(farm_bed) == FarmingController.Action.DIG and farming.use_plot(farm_bed, false) and farm_bed.tilled, "E on an overgrown bed digs it over")
	check(ActivityClock.total_minutes - farm_clock == farming.dig_minutes, "digging takes %d minutes" % farming.dig_minutes)
	check(farming.get_action(farm_bed) == FarmingController.Action.NEED_SEEDS and not farming.use_plot(farm_bed, false), "no seeds: nothing is planted")
	InventoryManager.add_item(&"turnip_seeds", 2)
	InventoryManager.add_item(&"carrot_seeds", 1)
	check(farming.get_selected_seed() == &"turnip_seeds" and farming.cycle_seed() == &"carrot_seeds" and farming.cycle_seed() == &"turnip_seeds", "Q switches between the seeds in the bag")
	farm_clock = ActivityClock.total_minutes
	check(farming.use_plot(farm_bed, false) and farm_bed.crop_id == &"turnip" and InventoryManager.get_count(&"turnip_seeds") == 1, "planting uses one packet of seeds")
	check(ActivityClock.total_minutes - farm_clock == farming.plant_minutes and farm_bed.get_stage() == CropData.Stage.SEED and farm_bed.get_plant_count() == 9, "planting takes %d minutes and shows 9 seedlings" % farming.plant_minutes)
	ActivityClock.advance_minutes(120, &"test")
	check(farm_bed.growth_minutes == 0, "crops don't grow in dry soil")
	check(farming.get_action(farm_bed) == FarmingController.Action.NEED_CAN and not farming.use_plot(farm_bed, false), "no watering can: the bed stays dry")
	var shed_pickup := main.get_node("Island/Buildings/FarmField/GardenShed/GrandpasCan") as ItemPickup
	shed_pickup.interact(player)
	check(InventoryManager.has_item(&"watering_can") and InventoryManager.get_count(&"turnip_seeds") == 4 and shed_pickup.is_taken and not shed_pickup.enabled, "Grandpa's watering can and seeds wait by the garden shed")
	shed_pickup.interact(player)
	check(InventoryManager.get_count(&"turnip_seeds") == 4, "and can only be taken once")
	var shed_saved := shed_pickup.save_state()
	shed_pickup.load_state({"taken": false})
	check(shed_pickup.enabled and (shed_pickup.get_node("Can") as Node3D).visible, "a fresh game puts the can back")
	shed_pickup.load_state(shed_saved)
	check(not shed_pickup.enabled and not (shed_pickup.get_node("Can") as Node3D).visible, "a loaded game remembers it was taken")
	farm_clock = ActivityClock.total_minutes
	check(farming.get_action(farm_bed) == FarmingController.Action.WATER and farming.use_plot(farm_bed, false) and farm_bed.is_damp(), "E with a watering can waters the bed")
	check(ActivityClock.total_minutes - farm_clock == farming.water_minutes and (farm_bed.get_node("Soil") as MeshInstance3D).material_override == CropVisuals.soil_material(&"damp"), "watering takes %d minutes and darkens the soil" % farming.water_minutes)
	check(farming.get_action(farm_bed) == FarmingController.Action.GROWING and not farming.use_plot(farm_bed, false), "a watered crop just needs time")
	var walk_growth := farm_bed.growth_minutes
	player.teleport_to(farm_bed.global_position + Vector3(3, 0.3, 0))
	await _frames(30)
	check(farm_bed.growth_minutes == walk_growth, "walking around doesn't grow crops")
	ActivityClock.advance_minutes(4 * 60, &"test")
	check(farm_bed.get_stage() == CropData.Stage.SPROUT, "after a few hours the turnips sprout")
	ActivityClock.advance_minutes(8 * 60, &"test")
	check(farm_bed.get_stage() == CropData.Stage.GROWING, "then grow bigger")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	check(farm_bed.is_ready() and farming.get_action(farm_bed) == FarmingController.Action.HARVEST, "turnips planted in the morning are ready after a night's sleep")
	ActivityClock.advance_minutes(1440 * 10, &"test")
	check(farm_bed.is_ready() and farm_bed.has_crop(), "ready crops wait patiently and never wither")
	InventoryManager.add_item(&"wooden_plank", 5000)
	check(not farming.use_plot(farm_bed, false) and farm_bed.is_ready(), "a full bag leaves the crop in the ground")
	InventoryManager.remove_item(&"wooden_plank", 5000)
	farm_clock = ActivityClock.total_minutes
	check(farming.use_plot(farm_bed, false) and InventoryManager.get_count(&"turnip") == 3 and not farm_bed.has_crop() and farm_bed.tilled, "harvesting gives 3 turnips and leaves the bed dug")
	check(ActivityClock.total_minutes - farm_clock == farming.harvest_minutes and farm_bed.get_plant_count() == 0, "harvesting takes %d minutes" % farming.harvest_minutes)
	var turnip_sale := ShopService.sell(&"turnip", 3)
	check(turnip_sale.result == ShopService.Result.OK and turnip_sale.coins == 3 * ItemDB.get_item(&"turnip").sell_price, "turnips sell at the General Store")
	# Dry soil pauses growth part-way; watering again carries on.
	var carrot_bed := farm.get_plot(&"farm_plot_02")
	farming.use_plot(carrot_bed, false)
	farming.cycle_seed()
	if farming.get_selected_seed() != &"carrot_seeds":
		farming.cycle_seed()
	farming.use_plot(carrot_bed, false)
	farming.use_plot(carrot_bed, false)
	check(carrot_bed.crop_id == &"carrot" and carrot_bed.is_damp(), "carrots planted and watered")
	ActivityClock.advance_minutes(2 * 1440, &"test")
	var carrot_growth := carrot_bed.growth_minutes
	check(carrot_growth > 0 and carrot_growth < CropCatalog.shared().get_crop(&"carrot").get_grow_minutes() and not carrot_bed.is_damp() and carrot_bed.needs_water(), "soil dries after a day and growth pauses until watered again")
	var farm_saved := farm.save_state()
	carrot_bed.reset()
	farm_bed.reset()
	farm.load_state(JSON.parse_string(JSON.stringify(farm_saved)))
	check(carrot_bed.crop_id == &"carrot" and carrot_bed.growth_minutes == carrot_growth and farm_bed.tilled and not farm_bed.has_crop(), "the farm survives save and load (JSON)")
	var sunflower_bed := farm.get_plot(&"farm_plot_03")
	sunflower_bed.from_dict({"tilled": true, "crop": "sunflower", "growth": 99999, "damp": 0})
	check(sunflower_bed.is_ready() and sunflower_bed.get_plant_count() == 4, "ready sunflowers stand four to a bed")
	# Turnips and carrots use the Tripo models (growing and ready); the tiny early sprouts stay built-in.
	var model_bed_ok := true
	for model_case: Array in [["turnip", 0.6, true], ["turnip", 9.0, true], ["carrot", 9.0, true], ["carrot", 0.1, false]]:
		var model_crop := CropCatalog.shared().get_crop(StringName(model_case[0]))
		sunflower_bed.from_dict({"tilled": true, "crop": model_case[0], "growth": int(model_crop.get_grow_minutes() * float(model_case[1])), "damp": 0})
		var first_plant := sunflower_bed.get_node("Plants").get_child(0)
		var uses_model := first_plant.get_node_or_null("Model") != null
		model_bed_ok = model_bed_ok and uses_model == bool(model_case[2]) and sunflower_bed.get_plant_count() == 9
	check(model_bed_ok, "turnips and carrots grow as the Tripo models (sprouts stay simple)")
	var held_can := farming.get_node_or_null("../WateringCan/Mesh/Model")
	var held_water := farming.get_node_or_null("../WateringCan/Water") as CPUParticles3D
	check(held_can != null and held_water != null and held_water.position.z < -0.1, "the held watering can is Grandpa's model, pouring from its spout")
	for farm_p in plots:
		farm_p.reset()
	InventoryManager.reset()
	shed_pickup.load_state({"taken": false})
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Weather ==")
	SaveManager.autosave_enabled = false
	var wx_farm := main.get_node("Island/Buildings/FarmField") as FarmField
	var wx_bed := wx_farm.get_plot(&"farm_plot_05")
	var wx_empty := wx_farm.get_plot(&"farm_plot_06")
	var wx_wild := wx_farm.get_plot(&"farm_plot_07")
	wx_bed.from_dict({"tilled": true, "crop": "turnip", "growth": 0, "damp": 0})
	wx_empty.from_dict({"tilled": true})
	wx_wild.reset()
	var wx_daynight := main.get_node("Island/DayNightController") as DayNightController
	var wx_clock := ActivityClock.total_minutes
	WeatherManager.set_weather(WeatherManager.Weather.RAIN)
	check(wx_bed.is_damp() and wx_empty.is_damp() and not wx_wild.is_damp(), "rain waters every dug bed (not the overgrown ones)")
	check(ActivityClock.total_minutes == wx_clock, "rain itself uses no time")
	ActivityClock.advance_minutes(6 * 60, &"test")
	check(wx_bed.growth_minutes == 6 * 60 and wx_bed.damp_minutes == FarmPlot.DAMP_MINUTES, "crops keep growing while it rains")
	await get_tree().create_timer(2.3).timeout
	var wx_rain := wx_daynight.get_node("Rain") as GPUParticles3D
	check(wx_rain.emitting and wx_daynight.get_overcast() > 0.95, "rain falls and the sky turns grey")
	var wx_icon := main.get_node("HUD").get_node("%ClockIcon") as TextureRect
	check(wx_icon.texture.resource_path.ends_with("rain.svg"), "the clock shows a rain icon")
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	await get_tree().create_timer(2.3).timeout
	check(not wx_rain.emitting and wx_daynight.get_overcast() < 0.05, "the sun comes back after rain")
	WeatherManager.weather_seed = 12345
	var wx_counts := [0, 0, 0, 0]
	for day in range(2, 302):
		wx_counts[WeatherManager.roll_for_day(day)] += 1
	check(WeatherManager.roll_for_day(1) == WeatherManager.Weather.SUNNY and wx_counts[2] > 30 and wx_counts[2] < 110 and wx_counts[0] > 100 and wx_counts[3] > 10, "day 1 is sunny; later days are mostly sunny, with rain (and snow in winter) (%s)" % str(wx_counts))
	check(WeatherManager.roll_for_day(17) == WeatherManager.roll_for_day(17), "the same save gets the same weather each day")
	var wx_saved := WeatherManager.save_state()
	WeatherManager.load_state({"weather": 2, "seed": 1})
	check(WeatherManager.is_raining(), "weather loads from a save")
	WeatherManager.load_state(wx_saved)
	WeatherManager.auto_change = true
	WeatherManager.weather_seed = 12345
	var wx_rain_day := 2
	while WeatherManager.roll_for_day(ActivityClock.get_day() + wx_rain_day - 1) != WeatherManager.Weather.RAIN:
		wx_rain_day += 1
	wx_bed.from_dict({"tilled": true, "crop": "carrot", "growth": 60, "damp": 0})
	for i in wx_rain_day - 1:
		ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	check(WeatherManager.is_raining() and wx_bed.is_damp(), "waking up to rain finds the garden already watered")
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)

	print("== Compost and fertilizer ==")
	InventoryManager.reset()
	var cmp := main.get_node("Island/Buildings/FarmField/CompostBin/Compost") as DailyProduce
	var cmp_farming := player.get_node("Farming") as FarmingController
	cmp.load_state({"stock": ["fertilizer"]})
	check(cmp.stock.size() == 1 and cmp.get_prompt().begins_with("Take 1 Fertilizer") and cmp.get_node("Waiting1").visible, "a sack of fertilizer waits by the compost bin")
	var cmp_clock := ActivityClock.total_minutes
	cmp.interact(player)
	check(InventoryManager.get_count(&"fertilizer") == 1 and cmp.stock.is_empty() and not cmp.get_node("Waiting1").visible and ActivityClock.total_minutes == cmp_clock, "taking it is free and the sack disappears")
	for i in 5:
		ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	check(cmp.stock.size() == DailyProduce.new().max_stock, "the bin makes one sack every morning, up to three")
	cmp.load_state({"stock": []})
	wx_bed.from_dict({"tilled": true, "crop": "turnip", "growth": 0, "damp": 0})
	InventoryManager.add_item(&"watering_can")
	cmp_farming.use_plot(wx_bed, false)
	check(cmp_farming.get_action(wx_bed) == FarmingController.Action.FERTILIZE, "a watered bed offers fertilizer")
	cmp_clock = ActivityClock.total_minutes
	check(cmp_farming.use_plot(wx_bed, false) and wx_bed.fertilized and InventoryManager.get_count(&"fertilizer") == 0 and ActivityClock.total_minutes - cmp_clock == cmp_farming.fertilize_minutes, "spreading fertilizer takes %d minutes" % cmp_farming.fertilize_minutes)
	check((wx_bed.get_node("Fertilizer") as Node3D).visible, "fertilizer shows on the soil")
	var cmp_growth := wx_bed.growth_minutes
	ActivityClock.advance_minutes(120, &"test")
	check(wx_bed.growth_minutes - cmp_growth == 240, "fertilized crops grow twice as fast")
	ActivityClock.advance_minutes(24 * 60, &"test")
	wx_bed.harvest()
	check(not wx_bed.fertilized and not (wx_bed.get_node("Fertilizer") as Node3D).visible, "fertilizer is used up by the harvest")
	check(ItemDB.get_item(&"fertilizer").buy_price > 0, "the General Store sells fertilizer too")

	print("== Restoration ==")
	InventoryManager.reset()
	GameManager.set_flag(&"restored_greenhouse", false)
	var gh := main.get_node("Island/Buildings/FarmField/Greenhouse/Restoration") as RestorationSite
	var gh_root := main.get_node("Island/Buildings/FarmField/Greenhouse") as Node3D
	var gh_trays := gh_root.get_node("SeedTrays") as DailyProduce
	var gh_mesh: MeshInstance3D = gh_root.get_node("Model").find_children("*", "MeshInstance3D", true, false)[0]
	check(not gh.is_restored() and gh.enabled and gh_mesh.material_overlay != null and gh.get_node("RunDown").visible, "the greenhouse starts run-down: grimy, with planks and weeds around it")
	check(not gh_trays.enabled and not (gh_root.get_node("GlowInside") as Node3D).visible, "its seedling trays and lights wait for the repair")
	check(gh.get_prompt().contains("Wooden Plank 0/8") and gh.get_prompt().contains("250 coins"), "the prompt lists what the repair needs")
	var gh_clock := ActivityClock.total_minutes
	gh.interact(player)
	check(not gh.is_restored() and ActivityClock.total_minutes == gh_clock and InventoryManager.get_money() == InventoryManager.STARTING_MONEY, "without materials nothing happens and nothing is spent")
	InventoryManager.add_money(400)
	check(ShopService.buy(&"wooden_plank", 8).result == ShopService.Result.OK and gh.can_restore(), "planks from the General Store and coins are enough")
	var gh_money := InventoryManager.get_money()
	gh.interact(player)
	check(player.is_input_locked(), "the player gets to work")
	await get_tree().create_timer(RestorationSite.WORK_SWINGS * RestorationSite.SWING_LENGTH + 0.6).timeout
	check(gh.is_restored() and GameManager.has_flag(&"restored_greenhouse") and not player.is_input_locked(), "the greenhouse is restored")
	check(InventoryManager.get_count(&"wooden_plank") == 0 and gh_money - InventoryManager.get_money() == 250, "the repair uses 8 planks and 250 coins")
	check(ActivityClock.total_minutes - gh_clock == gh.building.work_minutes, "the work takes %d minutes" % gh.building.work_minutes)
	check(gh_mesh.material_overlay == null and not gh.get_node("RunDown").visible and not gh.enabled, "the grime, planks and weeds are gone")
	check(gh_trays.enabled and gh_trays.stock.size() == 2 and (gh_root.get_node("GlowInside") as Node3D).visible, "seedling trays and a warm light appear")
	gh_trays.interact(player)
	var gh_seeds := 0
	for seed_id in [&"turnip_seeds", &"carrot_seeds", &"sunflower_seeds"]:
		gh_seeds += InventoryManager.get_count(seed_id)
	check(gh_seeds == 2 and gh_trays.stock.is_empty(), "the trays give free seed packets")
	GameManager.set_flag(&"restored_greenhouse", false)
	check(gh_mesh.material_overlay != null and gh.get_node("RunDown").visible and not gh_trays.enabled, "a new game shows it run-down again")
	for farm_p in wx_farm.get_plots():
		farm_p.reset()
	InventoryManager.reset()
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Quests ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	QuestLog.reset()
	var q_tracker := main.get_node("HUD").get_node("%QuestTracker") as QuestTracker
	var q_ids: Array[StringName] = []
	for q in QuestLog.get_active_quests():
		q_ids.append(q.id)
	check(&"grandpas_garden" in q_ids and &"neighbours" in q_ids and not &"fishing_lessons" in q_ids and not &"mend_greenhouse" in q_ids, "a new game starts with Grandpa's Garden and Friendly Faces")
	await _frames(3)
	var q_tracker_rect := q_tracker.get_global_rect()
	var q_map_rect := (main.get_node("HUD").get_node("%Minimap") as Control).get_global_rect()
	check(q_tracker.visible and q_tracker_rect.position.y >= q_map_rect.end.y and absf(q_tracker_rect.position.x - q_map_rect.position.x) < 1.0, "the quest list sits right under the minimap")
	var q_lines := q_tracker.get_lines()
	check(q_lines.size() == 2 and q_lines[1][1] == "Say hello to Oliver at the fishing dock" and q_lines[0][1] == "Find Grandpa's watering can by the farm shed", "it shows each quest's next step (newest first)")
	var q_clock := ActivityClock.total_minutes
	InventoryManager.add_item(&"watering_can")
	check(QuestLog.get_current_step(&"grandpas_garden").target == &"dig", "picking up the watering can ticks the step off")
	QuestLog.record_event(&"plant")
	check(QuestLog.get_current_step(&"grandpas_garden").target == &"dig", "steps go in order (planting first doesn't skip digging)")
	for ev in [&"dig", &"plant", &"harvest"]:
		QuestLog.record_event(ev)
	await _frames(3)
	check(q_tracker.get_lines()[0][1] == "Sell a crop at the General Store" and q_tracker.find_child("Flashes", true, false).get_child_count() > 0, "the tracker moves to the next step and flashes a tick")
	var q_money := InventoryManager.get_money()
	InventoryManager.add_item(&"turnip", 1)
	ShopService.sell(&"turnip", 1)
	check(QuestLog.is_done(&"grandpas_garden") and InventoryManager.get_money() == q_money + ItemDB.get_item(&"turnip").sell_price + 30, "selling a crop finishes Grandpa's Garden (+30 coins)")
	check(QuestLog.is_active(&"mend_greenhouse") and ActivityClock.total_minutes == q_clock, "the greenhouse quest follows, and quests use no time")
	InventoryManager.add_item(&"wooden_plank", 3)
	await _frames(3)
	var q_green := ""
	for line in q_tracker.get_lines():
		if line[0] == "Mend the Greenhouse":
			q_green = line[1]
	check(q_green == "Buy wooden planks at the General Store  3/8", "item steps count up (planks 3/8)")
	GameManager.set_flag(&"has_fishing_rod")
	check(QuestLog.is_active(&"fishing_lessons"), "getting Oliver's rod starts his fishing lessons")
	GameManager.set_flag(&"met_oliver")
	GameManager.set_flag(&"met_mia")
	check(QuestLog.is_done(&"neighbours"), "meeting Oliver and Mia finishes Friendly Faces")
	GameManager.set_flag(&"opening_seen")
	check(QuestLog.is_active(&"arrival"), "after the opening scene, Welcome to Willowbrook begins")
	(main.get_node("ShopPanel") as ShopPanel).open()
	(main.get_node("ShopPanel") as ShopPanel).close()
	check(QuestLog.is_done(&"arrival"), "visiting the General Store finds Emma")
	var q_saved := QuestLog.save_state()
	QuestLog.reset()
	QuestLog.load_state(JSON.parse_string(JSON.stringify(q_saved)))
	check(QuestLog.is_done(&"grandpas_garden") and QuestLog.is_active(&"mend_greenhouse") and QuestLog.get_step_progress(&"mend_greenhouse") == Vector2i(3, 8), "quests survive save and load (JSON)")
	GameManager.reset_flags()
	InventoryManager.reset()
	QuestLog.reset()
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Friendship ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	QuestLog.reset()
	var fr_mia := main.get_node("Villagers/Mia") as Villager
	var fr_oliver := main.get_node("Villagers/Oliver") as Villager
	var fr_panel := main.get_node("GiftPanel") as GiftPanel
	var fr_all := true
	for fr_villager in main.get_node("Villagers").get_children():
		var fr_data := (fr_villager as Villager).data
		fr_all = fr_all and not fr_data.loved_items.is_empty() and not fr_data.friend_lines.is_empty()
		for fr_item in fr_data.loved_items + fr_data.liked_items + fr_data.disliked_items:
			fr_all = fr_all and ItemDB.has_item(fr_item)
	check(fr_all, "every villager has favourite gifts (real items) and friendly lines")
	check(Friendship.get_hearts(&"mia") == 0 and Friendship.get_taste_name(Friendship.taste_for(fr_mia.data, &"sunflower")) == "loved" and Friendship.taste_for(fr_mia.data, &"silver_minnow") == Friendship.Taste.DISLIKED and Friendship.taste_for(fr_oliver.data, &"sunfish") == Friendship.Taste.LIKED, "tastes: Mia loves sunflowers, Oliver likes any fish")
	var fr_clock := ActivityClock.total_minutes
	fr_mia.talk(player)
	check(Friendship.get_points(&"mia") == Friendship.TALK_POINTS, "the first chat of the day adds a little friendship")
	fr_mia.end_conversation()
	fr_mia.talk(player)
	fr_mia.end_conversation()
	check(Friendship.get_points(&"mia") == Friendship.TALK_POINTS, "chatting again the same day adds nothing more")
	GameManager.set_flag(&"met_mia")
	InventoryManager.add_item(&"sunflower", 2)
	InventoryManager.add_item(&"watering_can")
	player.teleport_to(fr_mia.global_position + Vector3(1.2, 0.3, 0))
	await _frames(15)
	var fr_interaction := player.get_node("InteractionArea") as PlayerInteraction
	check(fr_interaction.get_prompt_text().contains("G: give a gift"), "near a villager you've met, the prompt offers a gift (G)")
	fr_panel.open_for(fr_mia)
	check(fr_panel.is_open() and player.is_input_locked(), "G opens the gift screen and the player stands still")
	check(&"sunflower" in fr_panel.get_item_ids() and not &"watering_can" in fr_panel.get_item_ids(), "you can give crops, fish and goods, but not your tools")
	var fr_result := fr_panel.give(&"sunflower")
	check(fr_result.ok and fr_result.taste == Friendship.Taste.LOVED and not fr_panel.is_open() and not player.is_input_locked(), "giving a loved gift closes the screen")
	check(Friendship.get_points(&"mia") == Friendship.TALK_POINTS + int(Friendship.GIFT_POINTS[Friendship.Taste.LOVED]) and InventoryManager.get_count(&"sunflower") == 1, "a loved gift adds a lot of friendship and uses one item")
	check(fr_mia.get_bubble_text() == fr_mia.data.loved_line and fr_mia.are_hearts_visible() and fr_mia.get_shown_hearts() == 0, "Mia says thank you in her speech bubble, with her hearts above")
	var fr_again := Friendship.give_gift(fr_mia.data, &"sunflower")
	check(not fr_again.ok and fr_again.reason == "already_gifted" and InventoryManager.get_count(&"sunflower") == 1, "one gift per villager per day")
	check(ActivityClock.total_minutes == fr_clock, "talking and giving gifts use no time")
	var fr_hearts := [0]
	var fr_on_heart := func(npc_id: StringName, hearts: int) -> void:
		if npc_id == &"mia":
			fr_hearts[0] = hearts
	Friendship.heart_gained.connect(fr_on_heart)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	InventoryManager.add_item(&"silver_minnow")
	var fr_minnow := Friendship.give_gift(fr_mia.data, &"silver_minnow")
	check(fr_minnow.ok and fr_minnow.points == int(Friendship.GIFT_POINTS[Friendship.Taste.DISLIKED]) and Friendship.get_points(&"mia") > Friendship.TALK_POINTS, "a gift she dislikes still never lowers friendship")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	Friendship.give_gift(fr_mia.data, &"sunflower")
	check(Friendship.get_hearts(&"mia") == 1 and fr_hearts[0] == 1 and GameManager.has_flag(&"hearts_mia_1") and GameManager.has_flag(&"hearts_any_1"), "reaching a heart sets story flags and tells you")
	Friendship.heart_gained.disconnect(fr_on_heart)
	Friendship.load_state({"villagers": {"mia": {"points": 420}}})
	check(Friendship.get_hearts(&"mia") == 4 and absf(Friendship.get_heart_progress(&"mia") - 0.2) < 0.01, "hearts load from a save")
	var fr_friend_line := false
	var fr_story_saved := fr_mia.data.story_lines
	fr_mia.data.story_lines = {}
	for i in 4:
		fr_mia.talk(player)
		fr_friend_line = fr_friend_line or fr_mia.get_bubble_text() in fr_mia.data.friend_lines
		fr_mia.end_conversation()
	check(fr_friend_line, "good friends share more personal things")
	fr_mia.data.story_lines = fr_story_saved
	Friendship.load_state({"villagers": {"mia": {"points": 9999}}})
	check(Friendship.get_hearts(&"mia") == Friendship.MAX_HEARTS, "friendship tops out at %d hearts" % Friendship.MAX_HEARTS)
	var fr_saved := Friendship.save_state()
	Friendship.reset()
	Friendship.load_state(JSON.parse_string(JSON.stringify(fr_saved)))
	check(Friendship.get_points(&"mia") == Friendship.POINTS_PER_HEART * Friendship.MAX_HEARTS, "friendship survives save and load (JSON)")
	GameManager.set_flag(&"met_oliver")
	check(QuestLog.is_active(&"little_kindness"), "after meeting Oliver and Mia, A Little Kindness begins")
	var fr_story_before := fr_mia.data.story_lines
	fr_mia.data.story_lines = {&"test_story_a": PackedStringArray(["A line."]), &"test_story_b": PackedStringArray(["B one.", "B two."])}
	GameManager.set_flag(&"test_story_a")
	GameManager.set_flag(&"test_story_b")
	fr_mia.talk(player)
	var fr_first := fr_mia.get_bubble_text()
	fr_mia.talk(player)
	check(fr_first == "B one." and fr_mia.get_bubble_text() == "B two.", "story flags switch a villager to that chapter's conversation (latest flag wins)")
	fr_mia.end_conversation()
	fr_mia.data.story_lines = fr_story_before
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	QuestLog.reset()
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Ukulele ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	ActivityClock.reset()
	var uk := player.get_node("Ukulele") as UkuleleController
	var uk_fishing := player.get_node("Fishing") as FishingController
	player.teleport_to(Vector3(-8, terrain.shape.get_height(-8, 70) + 0.3, 70), 0.0)
	await _frames(20)
	check(not uk.start() and not uk.is_playing(), "without the ukulele, U just hints where Grandpa kept it")
	var uk_pickup := main.find_child("Interior", true, false).get_node("Ukulele") as ItemPickup
	uk_pickup.interact(player)
	check(uk.has_ukulele() and not uk_pickup.enabled, "Grandpa's ukulele waits in the cottage")
	var uk_known := uk.get_known_melodies()
	check(uk_known.size() == 2 and uk.get_book_entries()[2][0] == "? ? ?", "it comes with two tunes; the rest are hidden in journal pages")
	var uk_clock := ActivityClock.total_minutes
	check(uk.start() and uk.is_playing() and player.is_input_locked(), "U takes it out and the player stands to play")
	await _frames(5)
	var uk_anim := player.get_node("Visual/Character") as CharacterAnimator
	check(uk_anim.get_current_animation() == &"uke_play" and (player.get_node("Instrument") as Node3D).visible, "the player holds the ukulele and strums")
	var uk_notes := uk.get_synth().notes_played
	for n in [1, 2, 3, 4, 5, 6, 7, 8]:
		uk.play_note(n)
	check(uk.get_synth().notes_played == uk_notes + 8, "keys 1-8 play the eight notes of a scale")
	check(ActivityClock.total_minutes == uk_clock, "playing freely uses no time")
	var uk_results := []
	var uk_on_melody := func(m: MelodyData, worked: bool) -> void: uk_results.append([m.id, worked])
	uk.melody_played.connect(uk_on_melody)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(9), &"test")
	for n in [5, 3, 2, 1]:
		uk.play_note(n)
	check(uk_results.back() == [&"sunset_song", true] and ActivityClock.get_time_string() == "6:00 PM", "the Sunset Song passes the day until 6 PM")
	for n in [5, 3, 2, 1]:
		uk.play_note(n)
	check(uk_results.back() == [&"sunset_song", false] and ActivityClock.get_time_string() == "6:00 PM", "after sunset it does nothing (and costs nothing)")
	var uk_mia := main.get_node("Villagers/Mia") as Villager
	player.teleport_to(uk_mia.global_position + Vector3(1.5, 0.3, 0))
	await _frames(10)
	uk_clock = ActivityClock.total_minutes
	for n in [1, 3, 5, 8, 5]:
		uk.play_note(n)
	check(uk_results.back() == [&"serenade", true] and Friendship.get_points(&"mia") == Friendship.SERENADE_POINTS and ActivityClock.total_minutes - uk_clock == uk.melody_minutes, "the Serenade brightens a villager's day (%d min)" % uk.melody_minutes)
	check(uk_mia.get_bubble_text().contains("lovely tune"), "and they say so")
	for n in [1, 3, 5, 8, 5]:
		uk.play_note(n)
	check(Friendship.get_points(&"mia") == Friendship.SERENADE_POINTS, "once a day per villager")
	for n in [8, 7, 5, 3, 1]:
		uk.play_note(n)
	check(not WeatherManager.is_raining() and uk_results.back()[0] == &"serenade", "the Rain Song isn't known before reading its journal page")
	GameManager.set_flag(&"journal_page_2")
	uk_clock = ActivityClock.total_minutes
	for n in [8, 7, 5, 3, 1]:
		uk.play_note(n)
	check(WeatherManager.is_raining() and ActivityClock.total_minutes - uk_clock == uk.melody_minutes, "after reading Grandpa's page, the Rain Song brings rain")
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	for n in [8, 7, 5, 3, 1]:
		uk.play_note(n)
	check(not WeatherManager.is_raining(), "only once a day")
	GameManager.set_flag(&"journal_page_3")
	uk_fishing.grant_rod()
	var uk_dock := main.get_node("Island/Buildings/FishingDock") as Node3D
	player.teleport_to(uk_dock.global_position + Vector3(0, 0.3, -12.0), 0.0)
	await _frames(20)
	for n in [3, 5, 6, 5, 3]:
		uk.play_note(n)
	check(uk_fishing.quick_bite_next, "the Lake Lullaby by the water readies a quick bite")
	GameManager.set_flag(&"journal_page_4")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(22), &"test")
	var uk_day := ActivityClock.get_day()
	for n in [1, 5, 4, 3, 2, 1]:
		uk.play_note(n)
	check(ActivityClock.get_day() == uk_day + 1 and ActivityClock.get_time_string() == "6:00 AM" and not uk.is_playing(), "the Starlight Song sleeps under the stars until morning")
	uk.melody_played.disconnect(uk_on_melody)
	uk.start()
	uk.stop()
	check(not uk.is_playing() and not player.is_input_locked() and not (player.get_node("Instrument") as Node3D).visible, "U puts it away again")
	uk_fishing.quick_bite_next = false
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	uk_pickup.load_state({"taken": false})
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Villager quests ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	Journal.clear()
	QuestLog.reset()
	ActivityClock.reset()
	var vq_mia := main.get_node("Villagers/Mia") as Villager
	var vq_theo := main.get_node("Villagers/Theo") as Villager
	var vq_oliver := main.get_node("Villagers/Oliver") as Villager
	var vq_ambrose := main.get_node("Villagers/MrAmbrose") as Villager
	var vq_tracker := main.get_node("HUD").get_node("%QuestTracker") as QuestTracker
	var vq_givers := {}
	for vq_q in QuestLog.catalog.quests:
		if vq_q.giver_id != &"":
			vq_givers[vq_q.giver_id] = true
	check(vq_givers.size() >= 8, "most villagers have a personal quest (%d)" % vq_givers.size())
	GameManager.set_flag(&"met_mia")
	check(QuestLog.get_offer_for(&"mia") == null and vq_mia.get_quest_marker() == "", "Mia waits until you're friends before asking")
	Friendship.load_state({"villagers": {"mia": {"points": 100}}})
	check(QuestLog.get_offer_for(&"mia") != null and QuestLog.get_offer_for(&"mia").id == &"sunny_seeds" and vq_mia.get_quest_marker() == "!", "at 1 heart a \"!\" shows she has something to ask")
	vq_mia.talk(player)
	var vq_offer := QuestLog.catalog.get_quest(&"sunny_seeds").offer_lines
	check(vq_mia.get_bubble_text() == vq_offer[0] and QuestLog.is_active(&"sunny_seeds"), "talking to her, she asks for help and the quest begins")
	vq_mia.end_conversation()
	await _frames(3)
	check(QuestLog.get_current_step(&"sunny_seeds").text == "Bring Mia a turnip, a carrot and a sunflower" and QuestLog.get_step_progress(&"sunny_seeds") == Vector2i(0, 3) and vq_tracker.get_lines().size() > 0, "the quest list shows what to bring (0/3)")
	check(vq_mia.get_quest_marker() == "", "no marker while you're still gathering things")
	InventoryManager.add_item(&"turnip")
	InventoryManager.add_item(&"carrot")
	check(QuestLog.get_step_progress(&"sunny_seeds") == Vector2i(2, 3) and QuestLog.get_turn_in_for(&"mia") == null, "progress counts up as you collect them")
	InventoryManager.add_item(&"sunflower")
	check(vq_mia.get_quest_marker() == "?", "with everything in your bag, a \"?\" shows she's waiting for it")
	var vq_points := Friendship.get_points(&"mia")
	vq_mia.talk(player)
	check(vq_mia.get_bubble_text() == QuestLog.catalog.get_quest(&"sunny_seeds").steps[0].lines[0], "handing it over, she thanks you")
	vq_mia.end_conversation()
	check(QuestLog.is_done(&"sunny_seeds") and InventoryManager.get_count(&"turnip") == 0 and InventoryManager.get_count(&"sunflower") == 0, "the items are handed over and the quest is done")
	check(InventoryManager.get_count(&"sunflower_seeds") == 5 and Friendship.get_points(&"mia") >= vq_points + 100, "rewards: sunflower seeds and a whole heart with Mia")
	var vq_border := main.get_node("Island/Buildings/FarmField").get_node_or_null("SunflowerBorder") as Node3D
	check(vq_border != null and vq_border.visible and vq_border.get_child_count() >= 8 and GameManager.has_flag(&"mia_sunny_seeds_done"), "and sunflowers now line the farm fence by the gate")
	GameManager.set_flag(&"met_theo")
	Friendship.load_state({"villagers": {"theo": {"points": 100}}})
	check(QuestLog.get_offer_for(&"theo") == null, "Theo's bench waits until the bridge is mended")
	GameManager.set_flag(&"restored_bridge")
	vq_theo.talk(player)  # Chapter 2: Theo first talks about the mended bridge (story_lines, once)
	vq_theo.end_conversation()
	vq_theo.talk(player)
	vq_theo.end_conversation()
	InventoryManager.add_item(&"wooden_plank", 6)
	var vq_clock := ActivityClock.total_minutes
	vq_theo.talk(player)
	vq_theo.end_conversation()
	check(QuestLog.is_done(&"bench_for_elias") and GameManager.has_flag(&"theo_bench_built") and ActivityClock.total_minutes - vq_clock == 60, "Theo's bench: six planks and an hour carving together")
	GameManager.set_flag(&"met_oliver")
	Friendship.load_state({"villagers": {"oliver": {"points": 150}}})
	check(QuestLog.get_offer_for(&"oliver") == null, "Oliver's fishing quest waits until he's given you a rod")
	GameManager.set_flag(&"has_fishing_rod")
	vq_oliver.talk(player)
	vq_oliver.end_conversation()
	check(QuestLog.is_active(&"fish_tales"), "then he asks for fish tales")
	for vq_fish in [&"silver_minnow", &"sunfish", &"sea_bream", &"blue_mackerel"]:
		Journal.record_fish(vq_fish, 20.0)
	check(QuestLog.get_step_index(&"fish_tales") == 0 and QuestLog.get_step_progress(&"fish_tales") == Vector2i(4, 5), "four kinds caught: 4/5")
	Journal.record_fish(&"flying_fish", 25.0)
	check(QuestLog.get_step_index(&"fish_tales") == 1 and vq_oliver.get_quest_marker() == "?", "the fifth kind sends you back to tell him")
	vq_oliver.talk(player)
	vq_oliver.end_conversation()
	check(QuestLog.is_done(&"fish_tales") and GameManager.has_flag(&"restored_boathouse"), "Fish Tales done: the old boathouse is fixed up")
	check(QuestLog.get_offer_for(&"oliver") == null or Friendship.get_hearts(&"oliver") >= 2, "his next request follows when you're closer still")
	GameManager.set_flag(&"met_ambrose")
	check(QuestLog.get_offer_for(&"ambrose") != null and QuestLog.get_offer_for(&"ambrose").id == &"grandpas_pages", "Mr. Ambrose asks about Grandpa's pages as soon as you meet")
	vq_ambrose.talk(player)
	vq_ambrose.end_conversation()
	for vq_page in [&"journal_page_1", &"journal_page_2", &"journal_page_3"]:
		GameManager.set_flag(vq_page)
	check(QuestLog.get_step_index(&"grandpas_pages") == 1, "finding three pages counts them")
	var vq_saved := QuestLog.save_state()
	QuestLog.reset()
	QuestLog.load_state(JSON.parse_string(JSON.stringify(vq_saved)))
	check(QuestLog.is_done(&"sunny_seeds") and QuestLog.get_step_index(&"grandpas_pages") == 1 and vq_ambrose.get_quest_marker() == "?", "villager quests survive save and load")
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	Journal.clear()
	QuestLog.reset()
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Journal ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	Journal.clear()
	var jn := main.get_node("JournalPanel") as JournalPanel
	var jn_clock := ActivityClock.total_minutes
	check(jn.open(JournalPanel.Tab.FISH) and jn.is_open() and player.is_input_locked(), "J opens the journal and the player stands still")
	var jn_fish := jn.get_entries()
	check(jn_fish.size() >= 7 and jn_fish[0][0] == "? ? ?" and jn_fish[0][1].contains("Try "), "uncaught fish are a mystery with a hint about where and when")
	Journal.record_fish(&"sunfish", 18.5)
	Journal.record_fish(&"sunfish", 22.0)
	jn.show_tab(JournalPanel.Tab.FISH)
	var jn_sun := []
	for e in jn.get_entries():
		if e[0] == "Sunfish":
			jn_sun = e
	check(not jn_sun.is_empty() and jn_sun[1].contains("Caught 2") and jn_sun[1].contains("22.0 cm"), "caught fish show how many and the biggest")
	Journal.record_harvest(&"turnip", 3)
	jn.show_tab(JournalPanel.Tab.CROPS)
	check(jn.get_entries()[0][1].contains("Harvested 3"), "crops show how many you've harvested")
	var jn_saved := Journal.to_dict()
	Journal.clear()
	Journal.from_dict(JSON.parse_string(JSON.stringify(jn_saved)))
	check(Journal.get_harvest_count(&"turnip") == 3 and Journal.get_fish_entry(&"sunfish").count == 2, "crop and fish records survive save and load")
	Journal.from_dict({"version": 1, "fish": {}})
	check(Journal.get_harvest_count(&"turnip") == 0, "older saves without crops still load")
	GameManager.set_flag(&"met_mia")
	InventoryManager.add_item(&"carrot")
	var jn_mia := main.get_node("Villagers/Mia") as Villager
	Friendship.give_gift(jn_mia.data, &"carrot")
	jn.show_tab(JournalPanel.Tab.VILLAGERS)
	var jn_mia_entry := []
	for e in jn.get_entries():
		if e[0] == "Mia":
			jn_mia_entry = e
	check(not jn_mia_entry.is_empty() and jn_mia_entry[1].contains("Loves: Carrot") and jn_mia_entry[1].contains("Farmer"), "villagers show their hearts and the favourite gifts you've discovered")
	check(jn.get_entries().any(func(e: Array) -> bool: return e[0] == "? ? ?"), "villagers you haven't met stay a mystery")
	var jn_fr := Friendship.save_state()
	Friendship.reset()
	Friendship.load_state(JSON.parse_string(JSON.stringify(jn_fr)))
	check(Friendship.get_known_tastes(&"mia").get(&"carrot", -1) == Friendship.Taste.LOVED, "discovered tastes are saved")
	GameManager.set_flag(&"journal_page_1")
	jn.show_tab(JournalPanel.Tab.PAGES)
	var jn_page := []
	for e in jn.get_entries():
		if e[0] == "Page 1":
			jn_page = e
	check(not jn_page.is_empty() and jn_page[1].begins_with("\""), "found journal pages can be read again")
	jn.show_tab(JournalPanel.Tab.SONGS)
	check(jn.get_entries().size() == MelodyCatalog.shared().melodies.size() and jn.get_entries()[0][0] == "? ? ?", "songs list Grandpa's melodies (unknown without the ukulele)")
	jn.close()
	check(not jn.is_open() and not player.is_input_locked() and ActivityClock.total_minutes == jn_clock, "closing it lets you walk again; reading uses no time")
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	Journal.clear()
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Seasons ==")
	SaveManager.autosave_enabled = false
	GameManager.reset_flags()
	InventoryManager.reset()
	ActivityClock.reset()
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	var ss_started := []
	var ss_on_season := func(id: StringName) -> void: ss_started.append(id)
	ActivityClock.season_started.connect(ss_on_season)
	ActivityClock.advance_minutes(ActivityClock.MINUTES_PER_DAY * 28, &"test")
	check(ss_started == [&"summer"] and ActivityClock.get_season_id() == &"summer", "after 28 days, summer begins (and says so)")
	ActivityClock.season_started.disconnect(ss_on_season)
	var ss_all_ok := true
	var ss_fish_ok := true
	var ss_fish_catalog := load("res://data/fish/fish_catalog.tres") as FishCatalog
	for ss_season in ActivityClock.SEASON_IDS:
		var ss_any := false
		for ss_crop in CropCatalog.shared().crops:
			ss_any = ss_any or ss_crop.grows_in(ss_season)
		ss_all_ok = ss_all_ok and ss_any
		ss_fish_ok = ss_fish_ok and not ss_fish_catalog.available(&"moonlit_lake", 10, ss_season).is_empty() and not ss_fish_catalog.available(&"sea", 10, ss_season).is_empty()
	check(ss_all_ok and ss_fish_ok, "every season has something to plant and fish to catch")
	check(CropCatalog.shared().crops.size() >= 6 and CropCatalog.shared().get_crop(&"pumpkin").grows_in(&"autumn") and CropCatalog.shared().get_crop(&"kale").grows_in(&"winter"), "new seasonal crops: tomato (summer), pumpkin (autumn), kale (winter)")
	var ss_meshes := true
	for ss_look in [&"tomato", &"pumpkin", &"kale"]:
		for ss_stage in 4:
			ss_meshes = ss_meshes and CropVisuals.crop_mesh(ss_look, ss_stage).get_surface_count() > 0
	check(ss_meshes, "and they have their own look at every stage")
	var ss_stock: Array[StringName] = []
	for ss_item in ShopService.get_stock():
		ss_stock.append(ss_item.id)
	check(&"sunflower_seeds" in ss_stock and &"tomato_seeds" in ss_stock and not &"turnip_seeds" in ss_stock and not &"kale_seeds" in ss_stock and &"wooden_plank" in ss_stock, "the store sells only seeds that grow this season")
	check(ShopService.can_buy(&"turnip_seeds") == ShopService.Result.NOT_FOR_SALE, "out-of-season seeds can't be bought")
	var ss_farming := player.get_node("Farming") as FarmingController
	var ss_bed := (main.get_node("Island/Buildings/FarmField") as FarmField).get_plot(&"farm_plot_08")
	ss_bed.from_dict({"tilled": true})
	InventoryManager.add_item(&"turnip_seeds", 2)
	check(ss_farming.get_action(ss_bed) == FarmingController.Action.NEED_SEEDS and ss_farming.get_prompt(ss_bed).contains("Summer") and not ss_farming.use_plot(ss_bed, false), "turnip seeds won't go in the ground in summer (the prompt explains)")
	InventoryManager.add_item(&"tomato_seeds", 1)
	check(ss_farming.use_plot(ss_bed, false) and ss_bed.crop_id == &"tomato", "but summer tomatoes will")
	ss_bed.water()
	ActivityClock.advance_minutes(ActivityClock.MINUTES_PER_DAY * 28 + 600, &"test")
	check(ActivityClock.get_season_id() == &"autumn" and ss_bed.has_crop(), "crops planted before the season changes keep growing (nothing dies)")
	var ss_daynight := main.get_node("Island/DayNightController") as DayNightController
	await get_tree().create_timer(DayNightController.SEASON_FADE + 0.4).timeout
	var ss_vals := ss_daynight.get_season_values()
	var ss_global: Variant = RenderingServer.global_shader_parameter_get(&"season_autumn")
	check(ss_vals[1] > 0.99 and ss_vals[0] < 0.01 and (ss_global == null or absf(float(ss_global) - 1.0) < 0.01), "the island fades into autumn colours")
	check((load("res://data/foliage/tree_pine.tres") as FoliageLayer).autumn_leaves == false and (load("res://data/foliage/tree_broadleaf.tres") as FoliageLayer).autumn_leaves, "broadleaf trees turn, pines stay green")
	WeatherManager.weather_seed = 777
	var ss_snow := 0
	var ss_rain := 0
	for ss_day in range(85, 113):
		var ss_w := WeatherManager.roll_for_day(ss_day)
		ss_snow += 1 if ss_w == WeatherManager.Weather.SNOW else 0
		ss_rain += 1 if ss_w == WeatherManager.Weather.RAIN else 0
	check(ss_snow > 3 and ss_rain == 0, "winter brings snow, not rain (%d snowy days)" % ss_snow)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	while ActivityClock.get_season_id() != &"winter":
		ActivityClock.advance_minutes(ActivityClock.MINUTES_PER_DAY, &"test")
	check(WeatherManager.get_morning_line().contains("Winter has arrived") and WeatherManager.get_morning_line().contains("Kale"), "the first winter morning announces the season and what to plant")
	var ss_winter_bed := (main.get_node("Island/Buildings/FarmField") as FarmField).get_plot(&"farm_plot_09")
	ss_winter_bed.from_dict({"tilled": true, "crop": "kale", "growth": 0, "damp": 0})
	WeatherManager.set_weather(WeatherManager.Weather.SNOW)
	var ss_rain_node := ss_daynight.get_node("Rain") as RainEffect
	await _frames(3)
	check(ss_winter_bed.is_damp() and ss_rain_node.get_falling() == "snow", "snow falls and waters the garden like rain")
	var ss_icon := main.get_node("HUD").get_node("%ClockIcon") as TextureRect
	check(ss_icon.texture.resource_path.ends_with("snow.svg"), "the clock shows a snow icon")
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	ss_bed.reset()
	ss_winter_bed.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	await _frames(3)
	check(ss_daynight.get_season_values() == [0.0, 0.0, 0.0], "a new game snaps back to spring")
	SaveManager.end_session()
	SaveManager.begin_session()
	SaveManager.autosave_enabled = true

	print("== Regions ==")
	var region_checks := {
		&"fernwood_forest": Vector2(-115, -20), &"sunflower_fields": Vector2(115, 70),
		&"whispering_coast": Vector2(160, -80), &"northern_hills": Vector2(-20, -125),
	}
	for region_id in region_checks:
		var p: Vector2 = region_checks[region_id]
		player.teleport_to(Vector3(p.x, terrain.shape.get_height(p.x, p.y) + 1.0, p.y))
		await _frames(15)
		check(GameManager.current_region_id == region_id, "entering %s updates the region" % region_id)

	print("== UI ==")
	check(str(ProjectSettings.get_setting("gui/theme/custom", "")) == UIPalette.THEME_PATH, "the cozy UI theme is the project's theme")
	var cozy := load(UIPalette.THEME_PATH) as Theme
	check(cozy != null and cozy.default_font is FontVariation and cozy.has_stylebox("panel", "WoodPanel") and cozy.has_stylebox("panel", "KeyCap"), "the theme has its fonts, wooden plaque and key caps")
	var weights_ok := false
	if cozy and cozy.default_font is FontVariation:
		var body_font := cozy.default_font as FontVariation
		weights_ok = not body_font.variation_opentype.is_empty() and body_font.base_font != null and body_font.base_font.get_font_name().begins_with("Nunito")
	check(weights_ok, "body text uses Nunito at a set weight")
	var all_icons := true
	for icon_name in ["sun", "moon", "leaf", "bag", "fish", "coin", "book"]:
		all_icons = all_icons and UIPalette.icon(icon_name) != null
	check(all_icons, "all UI icons load")
	var hud := main.get_node("HUD")
	check((hud.get_node("Root/ClockPanel") as Control).theme_type_variation == &"WoodPanel", "the clock sits on a wooden plaque")
	GameManager.interaction_prompt_changed.emit("Test prompt")
	await _frames(2)
	check((hud.get_node("%PromptKey") as Label).text == "E" and (hud.get_node("%PromptLabel") as Label).text == "Test prompt", "prompts show an [E] key cap and the action")
	GameManager.interaction_prompt_changed.emit("")
	var night_minutes := ActivityClock.minutes_until(21)
	ActivityClock.advance_minutes(night_minutes, &"test")
	await _frames(2)
	check((hud.get_node("%ClockIcon") as TextureRect).texture.resource_path.ends_with("moon.svg"), "the clock shows the moon at night")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(9), &"test")
	await _frames(2)
	check((hud.get_node("%ClockIcon") as TextureRect).texture.resource_path.ends_with("sun.svg"), "and the sun by day")
	InventoryManager.add_money(7)
	await _frames(2)
	check((hud.get_node("%CoinLabel") as Label).text == str(InventoryManager.get_money()), "the HUD coin counter follows your coins (%s)" % (hud.get_node("%CoinLabel") as Label).text)

	# Minimap (top-left).
	var minimap := hud.get_node("%Minimap") as Minimap
	var map_wait := 0
	while not minimap.is_map_ready() and map_wait < 900:
		await _frames(1)
		map_wait += 1
	check(minimap.is_map_ready(), "the minimap paints the island map (%d frames)" % map_wait)
	check(minimap.get_global_rect().position.x < 60 and minimap.get_global_rect().position.y < 60, "the minimap sits in the top-left corner")
	var self_spot: Dictionary = minimap.world_to_minimap(player.global_position)
	check((self_spot.position as Vector2).distance_to(minimap.size * 0.5) < 1.0 and not self_spot.clamped, "the player is at the centre of the minimap")
	var lighthouse_spot: Dictionary = minimap.world_to_minimap((main.get_node("Island/Buildings/Lighthouse") as Node3D).global_position)
	check(lighthouse_spot.clamped, "far-away places sit on the minimap's rim")

	# Bag pop-up.
	var bag := main.get_node("BagPanel")
	InventoryManager.clear()
	InventoryManager.add_item(&"sunfish", 2)
	InventoryManager.add_item(&"wooden_plank", 120)
	check(bag.open() and bag.is_open() and player.is_input_locked(), "the bag opens as a pop-up and the player stands still")
	await _frames(2)
	var plank_slots := 0
	for i in InventoryManager.BAG_SLOTS:
		if bag.get_slot_item(i).get("id", &"") == &"wooden_plank":
			plank_slots += 1
	check(plank_slots == 3 and bag.get_slot_item(0).get("count", 0) == 2, "the bag grid shows one slot per stack (120 planks = 3 slots)")
	bag.select_slot(1)
	check(bag.get_detail_name() == ItemDB.get_display_name(&"wooden_plank"), "choosing a slot shows that item's details")
	bag.close()
	check(not bag.is_open() and not player.is_input_locked(), "closing the bag lets the player walk again")
	player.set_input_locked(true)
	check(not bag.open() and not bag.is_open(), "the bag won't open while the player is busy (store, fishing)")
	player.set_input_locked(false)
	InventoryManager.clear()
	main.queue_free()
	await _frames(2)

	print("== Menus ==")
	check(str(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/ui/title_screen.tscn", "the game opens on the title screen")
	var settings_path := "user://test_settings.cfg"
	GameSettings.mouse_sensitivity = 1.6
	GameSettings.master_volume = 0.3
	GameSettings.save_to(settings_path)
	GameSettings.reset_to_defaults()
	GameSettings.load_from(settings_path)
	check(is_equal_approx(GameSettings.mouse_sensitivity, 1.6) and is_equal_approx(GameSettings.master_volume, 0.3), "settings are saved and loaded back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	GameSettings.reset_to_defaults()

	ActivityClock.advance_minutes(120, &"test")
	InventoryManager.add_item(&"sunfish", 3)
	SaveManager.delete_save()  # earlier sections autosave; the menu checks below expect no save
	var title := (load("res://scenes/ui/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	add_child(title)
	await _frames(3)
	check(ActivityClock.get_time_string() == "6:00 AM" and InventoryManager.get_count(&"sunfish") == 0 and InventoryManager.get_money() == InventoryManager.STARTING_MONEY, "the title screen starts a fresh game (Day 1, 6:00 AM, starting coins)")
	check(title.get_state() == TitleScreen.State.TITLE and (title.get_node("UI/Root").find_child("PressAnyKey", true, false) as Control).visible, "the title card asks you to press any key")
	var any_key := InputEventKey.new()
	any_key.keycode = KEY_SPACE
	any_key.pressed = true
	get_viewport().push_input(any_key)
	await _frames(2)
	var menu_box := title.get_node("UI/Root").find_child("MainMenu", true, false) as Control
	check(title.get_state() == TitleScreen.State.MENU and menu_box.visible, "pressing a key opens the main menu")
	var continue_button := menu_box.get_node("ContinueButton") as Button
	var new_game_button := menu_box.get_node("NewGameButton") as Button
	check(continue_button.disabled and not new_game_button.disabled, "with no save yet, Continue is greyed out and New game is ready")
	title.open_settings()
	await _frames(2)
	var title_settings := title.get_node("UI/Root").find_child("SettingsScreen", true, false) as Control
	check(title_settings.visible and not menu_box.visible, "Settings opens as its own screen in place of the menu")
	check((title_settings.find_child("ControlsGrid", true, false) as GridContainer).get_child_count() == SettingsPanel.CONTROLS.size() * 2, "Settings lists every control with a key cap")
	get_viewport().push_input(esc_key())
	await _frames(2)
	check(not title_settings.visible and menu_box.visible, "Esc in Settings goes back to the main menu")
	title.queue_free()
	await _frames(2)

	var game := MAIN_SCENE.instantiate()
	add_child(game)
	await _frames(5)
	var pause := game.get_node("PauseMenu") as PauseMenu
	check(pause != null and not pause.is_open(), "the game has a pause menu, closed at the start")
	var esc := InputEventAction.new()
	esc.action = &"toggle_mouse"
	esc.pressed = true
	var pause_clock := ActivityClock.total_minutes
	get_viewport().push_input(esc)
	await _frames(2)
	check(pause.is_open() and get_tree().paused, "Esc opens the pause menu and freezes the game")
	var game_player := game.get_node("Player") as PlayerController
	var frozen_at := game_player.global_position
	await _frames(10)
	check(game_player.global_position.is_equal_approx(frozen_at) and ActivityClock.total_minutes == pause_clock, "nothing moves and no time passes while paused")
	pause._show_page(PauseMenu.Page.SETTINGS)
	var pause_settings := pause.find_child("SettingsPanel", true, false) as SettingsPanel
	check(pause_settings.visible and pause.get_page() == PauseMenu.Page.SETTINGS, "Settings opens from the pause menu")
	pause_settings.back_pressed.emit()
	await _frames(1)
	check(pause.get_page() == PauseMenu.Page.MAIN, "Back in Settings returns to the pause menu")
	pause.ask_leave(true)
	check(pause.get_page() == PauseMenu.Page.CONFIRM, "Main menu asks first (the island is saved before leaving)")
	get_viewport().push_input(esc)
	await _frames(2)
	check(pause.is_open() and pause.get_page() == PauseMenu.Page.MAIN, "Esc on a sub-page goes back to the pause menu")
	get_viewport().push_input(esc)
	await _frames(2)
	check(not pause.is_open() and not get_tree().paused, "Esc again resumes the game")
	var game_bag := game.get_node("BagPanel")
	game_bag.open()
	await _frames(2)
	get_viewport().push_input(esc)
	await _frames(2)
	check(not game_bag.is_open() and not pause.is_open(), "Esc closes the bag first instead of pausing")
	get_tree().paused = false
	game.queue_free()
	await _frames(2)

	print("== Saving ==")
	SaveManager.delete_save()
	TitleScreen.reset_game_state()
	# A stand-in for a world object that saves itself (farm plots will work the same way).
	var probe_script := GDScript.new()
	probe_script.source_code = "extends Node\nvar value := 0\nfunc get_save_key() -> String:\n\treturn \"test_probe\"\nfunc save_state() -> Dictionary:\n\treturn {\"value\": value}\nfunc load_state(data: Dictionary) -> void:\n\tvalue = int(data.get(\"value\", -1))\n"
	probe_script.reload()
	var probe := Node.new()
	probe.set_script(probe_script)
	probe.add_to_group(SaveManager.PERSISTENT_GROUP)
	add_child(probe)
	probe.set(&"value", 42)

	var save_game := MAIN_SCENE.instantiate()
	add_child(save_game)
	await _frames(5)
	check(SaveManager.is_session_running(), "autosave runs while the island is being played")
	var save_player := save_game.get_node("Player") as PlayerController
	var save_spot := Vector3(-12.0, IslandShape.shared().get_height(-12.0, 96.0) + 0.3, 96.0)
	save_player.teleport_to(save_spot, 1.2)
	await _frames(30)
	var saves_before := [0]
	SaveManager.saved.connect(func(_r: String) -> void: saves_before[0] += 1)
	ActivityClock.advance_minutes(90, &"fishing")
	InventoryManager.add_item(&"sunfish", 2)
	InventoryManager.add_money(15)
	Journal.record_fish(&"sunfish", 24.5)
	GameManager.set_flag(FishingController.ROD_FLAG)
	var save_wait := 0
	while saves_before[0] == 0 and save_wait < 400:
		await _frames(1)
		save_wait += 1
	check(saves_before[0] > 0 and FileAccess.file_exists(SaveManager.save_path), "the game autosaves a moment after something changes (%d frames)" % save_wait)
	check((save_game.get_node("HUD").get_node("%SavedPanel") as Control).modulate.a > 0.0, "a quiet \"Game saved\" note appears")
	var saved_data := SaveManager.read_latest()
	check(int(saved_data.get("version", 0)) == SaveManager.SAVE_VERSION and int(saved_data.clock.total_minutes) == ActivityClock.total_minutes, "the save is versioned and records the time of day")
	check(int(saved_data.inventory.items.get("sunfish", 0)) == 2 and int(saved_data.inventory.money) == InventoryManager.get_money(), "the save records the bag and coins")
	check(int((saved_data.world.get("test_probe", {}) as Dictionary).get("value", 0)) == 42, "objects in the \"persistent\" group save themselves")
	var expected_minutes := ActivityClock.total_minutes
	var expected_money := InventoryManager.get_money()
	var expected_spot := save_player.global_position
	check(SaveManager.save_game("test"), "saving by hand works too")
	save_game.queue_free()
	await _frames(3)
	check(not SaveManager.is_session_running(), "autosave stops when leaving the island")

	# Start fresh, then continue from the save (what the title screen's Continue does).
	TitleScreen.reset_game_state()
	probe.set(&"value", 0)
	check(ActivityClock.total_minutes != expected_minutes and InventoryManager.get_count(&"sunfish") == 0, "a new game starts empty")
	check(SaveManager.load_into_game(SaveManager.read_latest()), "the save loads")
	check(ActivityClock.total_minutes == expected_minutes and InventoryManager.get_count(&"sunfish") == 2 and InventoryManager.get_money() == expected_money and Journal.has_caught(&"sunfish"), "time, bag, coins and journal come back")
	check(GameManager.has_flag(FishingController.ROD_FLAG), "story progress (Oliver's rod) comes back")
	var loaded_game := MAIN_SCENE.instantiate()
	add_child(loaded_game)
	await _frames(5)
	var loaded_player := loaded_game.get_node("Player") as PlayerController
	check(Vector2(loaded_player.global_position.x, loaded_player.global_position.z).distance_to(Vector2(expected_spot.x, expected_spot.z)) < 0.5, "the player is back where they saved")
	check(int(probe.get(&"value")) == 42, "persistent objects get their saved state back")
	loaded_game.queue_free()
	await _frames(3)

	# A damaged save falls back to the backup.
	var broken := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	broken.store_string("{ not json")
	broken.close()
	check(not SaveManager.read_latest().is_empty(), "a damaged save falls back to the backup")

	# The title screen offers Continue, and New game asks before replacing the save.
	var save_title := (load("res://scenes/ui/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	add_child(save_title)
	await _frames(3)
	var save_menu := save_title.get_node("UI/Root").find_child("MainMenu", true, false) as Control
	var cont := save_menu.get_node("ContinueButton") as Button
	check(not cont.disabled and SaveManager.get_save_summary().begins_with("Day"), "Continue is ready when there's a save (%s)" % SaveManager.get_save_summary())
	save_title.start_new_game()
	await _frames(2)
	check(save_title.get_state() != TitleScreen.State.LOADING and (save_menu.get_node("NewGameButton") as Button).text.begins_with("Replace"), "New game asks before replacing a saved island")
	save_title.queue_free()
	probe.queue_free()
	SaveManager.delete_save()
	await _frames(2)


	await preload("res://tests/opening_tests.gd").new().run(self)
	await preload("res://tests/ambience_tests.gd").new().run(self)
	await preload("res://tests/footstep_tests.gd").new().run(self)
	await preload("res://tests/action_sound_tests.gd").new().run(self)
	await preload("res://tests/ui_sound_tests.gd").new().run(self)
	await preload("res://tests/story_sound_tests.gd").new().run(self)
	await preload("res://tests/weather_sound_tests.gd").new().run(self)
	await preload("res://tests/story_places_tests.gd").new().run(self)
	await preload("res://tests/chapter1_tests.gd").new().run(self)
	await preload("res://tests/chapter2_tests.gd").new().run(self)
	await preload("res://tests/chapter3_tests.gd").new().run(self)
	await preload("res://tests/chapter4_tests.gd").new().run(self)
	await preload("res://tests/finale_tests.gd").new().run(self)
	await preload("res://tests/gathering_tests.gd").new().run(self)
	await preload("res://tests/lakeside_tests.gd").new().run(self)
	await preload("res://tests/cooking_tests.gd").new().run(self)
	await preload("res://tests/upgrade_tests.gd").new().run(self)
	await preload("res://tests/shipping_tests.gd").new().run(self)
	await preload("res://tests/request_board_tests.gd").new().run(self)
	await preload("res://tests/shipping_sound_tests.gd").new().run(self)
	await preload("res://tests/forestry_tests.gd").new().run(self)
	await preload("res://tests/rice_tests.gd").new().run(self)
	await preload("res://tests/wheat_tests.gd").new().run(self)

	print("== NPCs ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	var town := MAIN_SCENE.instantiate()
	add_child(town)
	await _frames(5)
	var town_player := town.get_node("Player") as PlayerController
	var oliver := town.get_node("Villagers/Oliver") as Villager
	var mia := town.get_node("Villagers/Mia") as Villager
	var rod_owner := get_tree().get_first_node_in_group(&"fishing_controller")
	check(oliver.data.animations.get_animation_list().size() == 15 and mia.data.animations.get_animation_list().size() == 15, "Oliver and Mia each have their 15 Mixamo animations")
	check(oliver.get_entry().activity == NPCScheduleEntry.IDLE and oliver.get_current_clip() == &"idle", "at 6 AM Oliver waits by the dock")
	check(mia.get_current_clip() == &"plant", "at 6 AM Mia is planting in the field")
	# She kneels right at a garden bed, so her hands reach into the soil (no gap of path).
	var mia_reach := mia.global_position + Vector3(sin(mia.global_rotation.y), 0, cos(mia.global_rotation.y)) * 0.54
	var bed_gap := INF
	for garden_bed: Node3D in town.get_node("Island/Buildings/FarmField/Plots").get_children():
		var local := garden_bed.to_local(mia_reach)
		bed_gap = minf(bed_gap, Vector2(maxf(absf(local.x) - 1.1, 0.0), maxf(absf(local.z) - 1.1, 0.0)).length())
	check(bed_gap < 0.05, "Mia plants with her hands in a garden bed, not on the path (%.2f m off)" % bed_gap)
	check(not rod_owner.has_rod(), "a new game starts without a fishing rod")
	var talk_clock := ActivityClock.total_minutes
	town_player.teleport_to(oliver.global_position + Vector3(0, 0.3, 2.0), 0.0)
	await _frames(3)
	oliver.talk(town_player)
	await _frames(2)
	check(oliver.get_mode() == Villager.Mode.TALKING and oliver.get_bubble_text() == oliver.data.intro_lines[0], "pressing E on Oliver starts his first conversation")
	check(oliver.get_talk_prompt() == "Next" and oliver.get_current_clip() in Villager.TALK_CLIPS, "he talks with gestures, and E shows the next line")
	for i in oliver.data.intro_action_line:
		oliver.talk(town_player)
	await _frames(2)
	check(rod_owner.has_rod(), "Oliver hands over a fishing rod in his first conversation")
	while oliver.get_mode() == Villager.Mode.TALKING:
		oliver.talk(town_player)
	check(ActivityClock.total_minutes == talk_clock, "talking doesn't use any time")
	oliver.talk(town_player)
	check(oliver.get_bubble_text() in oliver.data.later_lines, "once you have the rod, Oliver chats instead of giving it again")
	town_player.teleport_to(oliver.global_position + Vector3(0, 0.3, 12.0), 0.0)
	await _frames(4)
	check(oliver.get_mode() != Villager.Mode.TALKING, "walking away ends the conversation")

	mia.talk(town_player)
	check(mia.get_bubble_text() == mia.data.intro_lines[0], "Mia introduces herself the first time")
	mia.end_conversation()
	check(mia.has_met(), "and remembers that you've met (a saved story flag)")
	mia.talk(town_player)
	var mia_story: Variant = mia.data.story_lines.get(&"met_mia", PackedStringArray())
	if not (mia_story as PackedStringArray).is_empty():
		# Chapter 1: next she tells you about the windmill (a story conversation)...
		check(mia.get_bubble_text() == (mia_story as PackedStringArray)[0], "next she tells you about Grandpa's windmill")
		mia.end_conversation()
		mia.talk(town_player)
	check(mia.get_bubble_text() in mia.data.later_lines, "after that she shares farming tips")
	mia.end_conversation()

	ActivityClock.advance_minutes(ActivityClock.minutes_until(12, 30), &"test")
	await _frames(2)
	check(oliver.get_mode() == Villager.Mode.WALKING, "when the clock reaches noon Oliver sets off for the lake bench")
	var npc_waited := 0
	while not (oliver.get_mode() == Villager.Mode.ACTIVITY and oliver.is_sitting() and oliver.get_current_clip() == &"sit_idle") and npc_waited < 2400:
		await _frames(10)
		npc_waited += 10
	check(oliver.is_sitting() and oliver.get_current_clip() == &"sit_idle", "he walks to the bench and sits down (%d frames)" % npc_waited)
	check(mia.get_current_clip() == &"water", "Mia moves on to watering")
	town.queue_free()
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	await _frames(3)

func esc_key() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"toggle_mouse"
	e.pressed = true
	return e
