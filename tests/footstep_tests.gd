extends RefCounted
## Checks for footsteps. Called from test_runner.gd:
##   await preload("res://tests/footstep_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Footsteps ==")
	var files_ok := true
	for surface in Footsteps.SURFACES:
		var r := Footsteps.stream_for(surface) as AudioStreamRandomizer
		files_ok = files_ok and r != null and r.streams_count == Footsteps.VARIANTS
	t.check(files_ok, "every surface has %d step sounds" % Footsteps.VARIANTS)

	t.check(Footsteps.terrain_surface(0, 115) == &"dirt", "the village square is earth")
	t.check(Footsteps.terrain_surface(-87.5, 180) == &"sand", "the beach is sand")
	var grass := _find_grass()
	t.check(grass != Vector2.INF, "there is grassy ground (%s)" % str(grass))

	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	ActivityClock.reset()
	GameManager.reset_flags()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(10)
	var player := main.get_node("Player") as PlayerController
	var steps := player.get_node_or_null("Footsteps") as Footsteps
	t.check(steps != null, "the player has footsteps")
	if steps == null:
		main.queue_free()
		await t._frames(3)
		return
	var minutes := ActivityClock.total_minutes

	# Built things: the fishing dock's boards are wood.
	var dock := main.find_child("FishingDock", true, false) as Node3D
	var deck := _top_at(player, dock.global_position - dock.global_basis.z * 6.0 if dock else Vector3(10, 4, 51))
	t.check(deck != Vector3.INF and Footsteps.surface_at(player, deck) == &"wood", "the fishing dock sounds like wooden boards")
	var shore := _shallow_water()
	t.check(Footsteps.surface_at(player, shore) == &"water", "wading in the lake's shallows splashes")
	var g3 := Vector3(grass.x, IslandShape.shared().get_height(grass.x, grass.y), grass.y)
	t.check(Footsteps.surface_at(player, g3) == &"grass", "grass sounds like grass")
	WeatherManager.set_weather(WeatherManager.Weather.SNOW)
	t.check(Footsteps.surface_at(player, g3) == &"snow" and Footsteps.surface_at(player, deck) == &"wood", "falling snow crunches underfoot (the dock stays wood)")
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)

	# Walking: one step each time a foot lands, in time with the walk.
	var start := Vector3(grass.x, IslandShape.shared().get_height(grass.x, grass.y) + 0.3, grass.y)
	player.teleport_to(start, 0.0)
	await t._frames(30)
	var idle_steps := steps.step_count
	await t._frames(45)
	t.check(steps.step_count == idle_steps, "standing still makes no steps")
	var surfaces: Array[StringName] = []
	steps.stepped.connect(func(s: StringName, _l: bool) -> void: surfaces.append(s))
	var before := steps.step_count
	Input.action_press(&"move_forward")
	await t._frames(180)
	Input.action_release(&"move_forward")
	var walked := steps.step_count - before
	t.check(walked >= 3 and walked <= 9, "three seconds of walking: %d steps (one per footfall)" % walked)
	t.check(not surfaces.is_empty() and surfaces[0] in [&"grass", &"dirt"], "the steps match the ground (%s)" % str(surfaces.slice(0, 3)))
	await t._frames(60)
	var stopped := steps.step_count
	await t._frames(60)
	t.check(steps.step_count == stopped, "the steps stop when you stop")

	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	before = steps.step_count
	var loud := [-INF]
	var on_run := func(_s: StringName, _l: bool) -> void: loud[0] = maxf(loud[0], (steps.get_node("StepPlayer") as AudioStreamPlayer).volume_db - float(Footsteps.SURFACE_DB.get(_s, 0.0)))
	steps.stepped.connect(on_run)
	await t._frames(180)
	steps.stepped.disconnect(on_run)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	var ran := steps.step_count - before
	# The run's long stride lands about as often as a brisk walk; its steps are heavier.
	t.check(ran >= 4 and loud[0] > steps.base_db, "running: %d heavier steps in three seconds" % ran)
	await t._frames(60)

	# Landing from a jump or a drop gives a heavier thump.
	var landed := [false]
	steps.stepped.connect(func(_s: StringName, l: bool) -> void:
		if l:
			landed[0] = true)
	player.teleport_to(player.global_position + Vector3.UP * 2.5)
	await t._frames(90)
	t.check(landed[0], "landing after a drop thumps")

	# Villagers have their own steps; hidden ones stay silent.
	var villager := t.get_tree().get_first_node_in_group(&"villagers") as Node3D
	t.check(villager != null and villager.get_node_or_null("Footsteps") is Footsteps and (villager.get_node("Footsteps") as Footsteps).positional, "villagers' steps are heard from where they walk")
	t.check(ActivityClock.total_minutes == minutes, "footsteps never move the clock")
	main.queue_free()
	await t._frames(3)
	ActivityClock.reset()
	GameManager.reset_flags()


## The top of whatever is built at `p` (casting down from above), or INF.
func _top_at(from: Node3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 6.0, p.z), Vector3(p.x, p.y - 6.0, p.z))
	q.exclude = [(from as CollisionObject3D).get_rid()]
	var hit := from.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3.INF


## A spot just inside Moonlit Lake where the water is ankle-deep.
func _shallow_water() -> Vector3:
	var shape := IslandShape.shared()
	for k in 72:
		var dir := Vector2.from_angle(k * TAU / 72.0)
		for r in range(30, 50):
			var p := IslandShape.LAKE_CENTER + dir * float(r)
			var h := shape.get_height(p.x, p.y)
			if h < IslandShape.LAKE_LEVEL - 0.15 and h > IslandShape.LAKE_LEVEL - 0.6:
				return Vector3(p.x, h, p.y)
	return Vector3(IslandShape.LAKE_CENTER.x, IslandShape.LAKE_LEVEL - 0.3, IslandShape.LAKE_CENTER.y)


## Open, gently sloping grass near the village, with room to walk north.
func _find_grass() -> Vector2:
	for r in range(20, 60, 4):
		for k in 24:
			var p := IslandShape.VILLAGE_CENTER + Vector2.from_angle(k * TAU / 24.0) * float(r)
			var ok := true
			for d in range(0, 8):
				if Footsteps.terrain_surface(p.x, p.y - d) != &"grass" or IslandShape.shared().get_height(p.x, p.y - d) < 2.0:
					ok = false
					break
			if ok:
				return p
	return Vector2.INF
