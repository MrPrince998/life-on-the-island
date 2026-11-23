extends RefCounted
## Checks for gathering wood and stone, and sawing planks. Called from test_runner.gd:
##   await preload("res://tests/gathering_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Gathering ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var gathering := main.get_node("Island/StoryPlaces/Gathering") as Node3D
	var wood_spawner := gathering.get_node("WoodSpots") as GatherSpawner
	var stone_spawner := gathering.get_node("StoneSpots") as GatherSpawner
	var wood_spots := wood_spawner.get_spots()
	var stone_spots := stone_spawner.get_spots()
	var shape := IslandShape.shared()
	t.check(wood_spots.size() >= 18 and stone_spots.size() >= 14, "%d branch piles and %d rocks to gather are scattered over the island" % [wood_spots.size(), stone_spots.size()])

	# Every spot is somewhere sensible.
	var bad: Array[String] = []
	for spot in wood_spots + stone_spots:
		var p := Vector2(spot.global_position.x, spot.global_position.z)
		var h := shape.get_height(p.x, p.y)
		if h < 1.3 or shape.distance_to_paths(p) < IslandShape.PATH_HALF_WIDTH + 1.0 or shape.is_in_creek(p, 1.0) or shape.get_lake_distance(p) < 1.1:
			bad.append(String(spot.name))
		elif absf(spot.global_position.y - h) > 0.3:
			bad.append("%s (%.1f m off the ground)" % [spot.name, spot.global_position.y - h])
	t.check(bad.is_empty(), "gather spots sit on dry ground, off the paths, out of the creek and the lake (%s)" % ", ".join(bad))
	var forest_wood := wood_spots.filter(func(s: GatherNode) -> bool: return Vector2(s.global_position.x, s.global_position.z).distance_to(IslandShape.FOREST_CENTER) < 75.0).size()
	var hills_stone := stone_spots.filter(func(s: GatherNode) -> bool: return Vector2(s.global_position.x, s.global_position.z).distance_to(IslandShape.HILLS_CENTER) < 60.0).size()
	t.check(forest_wood >= 3 and hills_stone >= 3, "Fernwood Forest has branches (%d) and the Northern Hills have rocks (%d)" % [forest_wood, hills_stone])
	var ids := {}
	for spot in wood_spots + stone_spots:
		ids[spot.get_save_key()] = true
	t.check(ids.size() == wood_spots.size() + stone_spots.size() and wood_spots[0].is_in_group(&"persistent"), "each spot has its own save key")

	# Gathering.
	var player := main.get_node("Player") as PlayerController
	var branch := wood_spots[0]
	var clock := ActivityClock.total_minutes
	t.check(branch.get_prompt().begins_with("Gather wood"), "a branch pile offers \"Gather wood (10 min)\"")
	var got := branch.gather_now()
	t.check(got >= 2 and got <= 3 and InventoryManager.get_count(&"wood") == got, "gathering a branch pile gives 2-3 wood (%d)" % got)
	t.check(ActivityClock.total_minutes == clock + 10, "gathering takes 10 minutes of activity time")
	t.check(not branch.is_ready() and not branch.enabled and not branch.get_node("Model").visible, "the gathered pile is gone")
	t.check(branch.gather_now() == 0, "you can't gather the same pile twice")
	var rock := stone_spots[0]
	var stone := rock.gather_now()
	t.check(stone >= 1 and InventoryManager.get_count(&"stone") == stone, "a rock gives stone (%d)" % stone)

	# Things grow back.
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) + 24 * 60, &"test")
	await t._frames(1)
	t.check(ActivityClock.get_day() >= 3 and branch.is_ready() and branch.get_node("Model").visible, "after two mornings the branches are back")
	var saved := rock.save_state()
	rock.load_state({"gathered_day": ActivityClock.get_day()})
	t.check(not rock.is_ready(), "a gathered rock stays gathered after loading a save")
	rock.load_state(saved)

	# Sawing planks at Grandpa's sawhorse.
	var saw := gathering.get_node("Sawhorse/Saw") as CraftingSpot
	InventoryManager.remove_item(&"wood", InventoryManager.get_count(&"wood"))
	t.check(saw.craft_now() == 0 and InventoryManager.get_count(&"wooden_plank") == 0, "the sawhorse needs at least 2 wood")
	InventoryManager.add_item(&"wood", 7)
	clock = ActivityClock.total_minutes
	t.check(saw.get_prompt().contains("you have 7"), "the sawhorse shows how much wood you have")
	t.check(saw.craft_now() == 3 and InventoryManager.get_count(&"wooden_plank") == 3 and InventoryManager.get_count(&"wood") == 1, "7 wood saw into 3 planks (1 wood left over)")
	t.check(ActivityClock.total_minutes == clock + 45, "sawing takes 15 minutes per plank")

	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
