extends RefCounted
## Checks for the story places (buildings, ruins, gates, Willow Creek, the beach
## jetty and the new villagers). Called from test_runner.gd:
##   await preload("res://tests/story_places_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const NEW_VILLAGERS := ["Emma", "Theo", "Luna", "NanaBea", "Pip", "MrAmbrose"]
const STORY_FLAGS: Array[StringName] = [
	&"restored_market", &"restored_inn", &"restored_house_1", &"restored_house_2", &"restored_house_3",
	&"restored_house_4", &"restored_boathouse", &"restored_windmill", &"restored_bridge", &"restored_workshop",
	&"ch2_tree_restored", &"ch1_orchard_planted", &"ch1_hedge_cleared", &"ch4_rockfall_cleared",
]


func run(t: Node) -> void:
	print("== Story places ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var island := main.get_node("Island") as Node3D
	var places := island.get_node("StoryPlaces") as Node3D
	var shape := IslandShape.shared()

	# Every placed model loaded and was sized.
	var fitted: Array[FittedModel] = []
	for node in places.find_children("*", "FittedModel", true, false):
		fitted.append(node as FittedModel)
	var broken: Array[String] = []
	for model in fitted:
		if model.model == null or model.fitted_size.length() < 0.05:
			broken.append(str(places.get_path_to(model)))
	t.check(fitted.size() > 90 and broken.is_empty(), "%d story models are placed and sized (%s)" % [fitted.size(), ", ".join(broken)])

	# Nothing floats: models standing on the ground sit at (or slightly into) it.
	var floating: Array[String] = []
	for model in fitted:
		if not model.snap_to_ground or not model.is_visible_in_tree():
			continue
		var p := model.global_position
		var ground := shape.get_height(p.x, p.z)
		if p.y > ground + 0.06 and p.y > model.min_height + 0.01:
			floating.append("%s %.2f m" % [model.name, p.y - ground])
	t.check(floating.is_empty(), "no building or prop floats above the ground (%s)" % ", ".join(floating))

	# Street lamps stand beside the paths, not on them.
	var lamps := places.get_node("Village/StreetLamps").get_children()
	var lamp_on_path := false
	for lamp: Node3D in lamps:
		lamp_on_path = lamp_on_path or shape.distance_to_paths(Vector2(lamp.global_position.x, lamp.global_position.z)) < IslandShape.PATH_HALF_WIDTH + 0.8
	t.check(lamps.size() >= 12 and not lamp_on_path, "%d street lamps line the paths out of the village, beside the path" % lamps.size())

	# Ruins until the story restores them.
	var variants: Array[StoryVariant] = []
	for node in places.find_children("*", "StoryVariant", true, false):
		variants.append(node as StoryVariant)
	var wrong_start := false
	for v in variants:
		for child: Node3D in v.get_children():
			if String(child.name).begins_with("After") and child.visible:
				wrong_start = true
			if String(child.name).begins_with("Before") and not child.visible:
				wrong_start = true
	t.check(variants.size() >= 20 and not wrong_start, "a new game shows the ruined look of all %d restorable places" % variants.size())
	var windmill := places.get_node("Farm/Windmill") as StoryVariant
	var ruined_body := windmill.get_node("Before").find_child("Body", true, false) as StaticBody3D
	GameManager.set_flag(&"restored_windmill")
	await t._frames(2)
	t.check(windmill.get_node("After").visible and not windmill.get_node("Before").visible, "setting restored_windmill swaps in the repaired windmill")
	t.check(ruined_body != null and not ruined_body.can_process(), "the hidden ruin's collision is switched off")

	# The bramble tangle's own models sit beside the path (the hedge's gate blocks it).
	var gate_blocks := false
	for gate_name in ["Farm/BrambleGate"]:
		for rock: Node3D in places.get_node(gate_name).get_children():
			if not rock is FittedModel:
				continue  # the spot where you clear the gate sits on the path on purpose
			var r := rock.global_position
			gate_blocks = gate_blocks or shape.distance_to_paths(Vector2(r.x, r.z)) < 2.8
	t.check(not gate_blocks, "the bramble tangle's models stand beside the path, not on it")

	# Willow Creek and its bridge.
	var bridge_xz := IslandShape.CREEK_BRIDGE
	var creek := shape.get_creek_info(bridge_xz)
	var samples := shape.creek_samples
	# From its spring (the highest point) it only flows downhill: east to the lake, west to the sea.
	var spring := 0
	for i in samples.size():
		if samples[i].z > samples[spring].z:
			spring = i
	var downhill := spring > 0 and spring < samples.size() - 1
	for i in range(spring, samples.size() - 1):
		downhill = downhill and samples[i + 1].z <= samples[i].z + 0.001
	for i in range(spring, 0, -1):
		downhill = downhill and samples[i - 1].z <= samples[i].z + 0.001
	t.check(creek.x < 1.0 and shape.get_height(bridge_xz.x, bridge_xz.y) < creek.y - 1.0, "Willow Creek runs under the forest-path bridge, with deep water over its bed")
	t.check(downhill and samples[-1].z <= IslandShape.LAKE_LEVEL + 0.05 and samples[0].z <= IslandShape.SEA_LEVEL + 0.05, "the creek only flows downhill from its spring: east into Moonlit Lake, west into the sea")
	# It's a real gate: too deep to wade or jump, and its ends reach deep water.
	var mid := Vector3.ZERO
	for sample in samples:
		if Vector2(sample.x, sample.y).distance_to(bridge_xz) > 14.0 and sample.x > bridge_xz.x:
			mid = Vector3(sample.x, 0.0, sample.y)
			break
	mid.y = shape.get_height(mid.x, mid.z)
	t.check(shape.get_creek_depth(mid) > 1.0, "the creek is too deep to wade away from the bridge (%.1f m)" % shape.get_creek_depth(mid))
	var sea_end := Vector2(samples[0].x, samples[0].y)
	var lake_end := Vector2(samples[-1].x, samples[-1].y)
	t.check(shape.get_height(sea_end.x, sea_end.y) < IslandShape.SEA_LEVEL - 1.25 and IslandShape.LAKE_LEVEL - shape.get_height(lake_end.x, lake_end.y) > 1.25, "both ends of the creek run into water too deep to wade round")
	var veg := main.get_node("Island/Vegetation") as VegetationScatter
	var physics: PhysicsDirectSpaceState3D = places.get_world_3d().direct_space_state
	# The bramble hedge: a real barrier whose gate on the farm path opens when cleared.
	for gate_info in [["Farm/BrambleHedge", &"ch1_hedge_cleared", IslandShape.BRAMBLE_GATE, "bramble hedge"]]:
		var barrier := places.get_node(gate_info[0]) as BarrierLine
		var flag: StringName = gate_info[1]
		var gate: Vector2 = gate_info[2]
		var was_set := GameManager.has_flag(flag)
		GameManager.set_flag(flag, false)
		var line_ok := barrier.get_piece_count() > 20
		var plants := barrier.get_gate_plants()
		var shut := barrier.is_gate_shut() and not plants.is_empty() and plants.all(func(n: Node) -> bool: return (n as Node3D).visible)
		GameManager.set_flag(flag, true)
		var open := not barrier.is_gate_shut() and plants.all(func(n: Node) -> bool: return not (n as Node3D).visible)
		GameManager.set_flag(flag, was_set)
		var far_ok := shape.distance_to_paths(gate) < 1.0
		t.check(line_ok and shut and open and far_ok, "the %s is a solid line whose gate on the path stays shut (and overgrown) until it's cleared" % gate_info[3])
	var hedge_line := shape.get_barrier_line(&"brambles")
	t.check(shape.get_height(hedge_line[0].x, hedge_line[0].y) < IslandShape.SEA_LEVEL - 1.25, "the hedge runs out into deep sea, so you can't wade round it")
	t.check(shape.distance_to_paths(hedge_line[-1]) > 5.0, "the hedge stops short of the lake path, so the farm can be reached the long way round")
	t.check(veg.get_instance_count(&"brambles_bush") > 60, "the hedge is planted thick with thorny bushes (%d)" % veg.get_instance_count(&"brambles_bush"))
	# Lighthouse Isle is a small island in the sea; the coast path runs out to it on a
	# footbridge that a rockfall smashed (Ch. 4).
	var isle_c := IslandShape.ISLE_CENTER
	var bridge_ends := shape.get_isle_bridge_ends()
	var sea_round := true
	for i in 24:
		var q := isle_c + Vector2.from_angle(TAU * i / 24.0) * IslandShape.ISLE_RADIUS * 1.35
		sea_round = sea_round and shape.get_height(q.x, q.y) < IslandShape.SEA_LEVEL - 1.25
	t.check(shape.get_height(isle_c.x, isle_c.y) > 10.0 and sea_round, "Lighthouse Isle stands on its own, with deep sea all round it")
	var lighthouse := main.get_node("Island/Buildings/Lighthouse") as Node3D
	t.check(shape.get_isle_distance(Vector2(lighthouse.global_position.x, lighthouse.global_position.z)) < 0.5, "the lighthouse stands on the isle")
	var mid_span := bridge_ends[0].lerp(bridge_ends[1], 0.5)
	t.check(shape.get_height(mid_span.x, mid_span.y) < IslandShape.SEA_LEVEL - 1.25 and shape.distance_to_paths(bridge_ends[0]) < 0.5, "the coast path ends at the cliff, with open sea between it and the isle")
	var rockfall := places.get_node("Coast/Rockfall") as StoryVariant
	# Probe the first span out from the main island's cliff (the one the rockfall took).
	var gap := bridge_ends[0].lerp(bridge_ends[1], 0.25)
	var bridge_ray := func() -> float:
		var hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(gap.x, 40.0, gap.y), Vector3(gap.x, -10.0, gap.y), 1))
		return (hit.position as Vector3).y if not hit.is_empty() else -INF
	var was_mended := GameManager.has_flag(&"ch4_rockfall_cleared")
	GameManager.set_flag(&"ch4_rockfall_cleared", false)
	await t._frames(3)
	var broken_ok: bool = rockfall.get_node("BeforeBridge").visible and not rockfall.get_node("AfterBridge").visible and bridge_ray.call() < 0.0
	GameManager.set_flag(&"ch4_rockfall_cleared", true)
	await t._frames(3)
	var deck_y: float = bridge_ray.call()
	GameManager.set_flag(&"ch4_rockfall_cleared", was_mended)
	await t._frames(2)
	t.check(broken_ok, "before Chapter 4 the footbridge is smashed: nothing to stand on over the sea")
	t.check(deck_y > 12.0, "once mended, its deck carries the coast path out to the isle (deck %.1f m)" % deck_y)
	t.check(rockfall.get_node("Scree").get_child_count() >= 10, "fallen rocks from the cliff lie along the cliff top and in the sea")
	t.check((rockfall.get_node("AfterBridge") as IsleBridge).get_pier_count() >= 3, "the long bridge stands on stone piers in the sea")
	var isle := places.get_node("Coast/IsleRocks") as LighthouseIsle
	t.check(isle.get_stack_count() >= 12 and isle.get_stone_count() >= 25, "sea stacks rise round Lighthouse Isle (%d) and mossy stones dot its shore (%d)" % [isle.get_stack_count(), isle.get_stone_count()])
	var creek_water := places.get_node("Forest/WillowCreek") as CreekWater
	t.check(creek_water.mesh != null and creek_water.mesh.get_aabb().size.length() > 60.0, "the creek has a water surface")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var down := func(x: float, z: float) -> float:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -20.0, z), 1)
		var hit: Dictionary = space.intersect_ray(query)
		return (hit.position as Vector3).y if hit else -INF
	var bank := shape.get_height(-70.6, 51.2)
	t.check(down.call(bridge_xz.x, bridge_xz.y) < creek.y, "the broken bridge has a gap in the middle (you wade across)")
	GameManager.set_flag(&"restored_bridge")
	await t._frames(3)
	var deck := down.call(bridge_xz.x, bridge_xz.y) as float
	t.check(deck > creek.y + 1.5 and absf(deck - bank) < 1.6, "once restored, the stone bridge carries the path over the creek (deck %.1f m, bank %.1f m)" % [deck, bank])

	# The beach jetty for the arrival (the opening scene looks these up by name).
	var jetty := places.get_node("Coast/BeachJetty") as Node3D
	var arrival := jetty.get_node("ArrivalPoint") as Marker3D
	var boat := jetty.get_node("MailBoat") as Node3D
	var a := arrival.global_position
	t.check(absf(down.call(a.x, a.z) - a.y) < 0.15, "the arrival point is on the jetty deck")
	var out_to_sea := Vector2(a.x, a.z).normalized()
	var bow := -boat.global_basis.z
	t.check(Vector2(bow.x, bow.z).normalized().dot(out_to_sea) < -0.8, "the mail boat is moored bow-in, as it arrived from the sea (its -Z points to the shore)")
	var to_village := -arrival.global_basis.z
	t.check(Vector2(to_village.x, to_village.z).dot(Vector2(0, 115) - Vector2(a.x, a.z)) > 0.0, "the arrival point faces up the beach towards the village")
	var marlow := jetty.get_node("CaptainMarlow") as Villager
	t.check(absf(marlow.global_position.y - a.y) < 0.15, "Captain Marlow stands on the jetty, not in the sea")

	# The new villagers.
	var villagers := main.get_node("Villagers")
	var all_ok := true
	var off_spot: Array[String] = []
	for v_name in NEW_VILLAGERS:
		var v := villagers.get_node_or_null(v_name) as Villager
		if v == null or v.data.animations.get_animation_list().size() != 15 or v.data.intro_lines.is_empty():
			all_ok = false
			continue
		var entry := v.get_entry()
		if v_name == "Theo":
			continue  # just rebuilt the bridge: he's on his way home (checked below)
		if Vector2(v.global_position.x - entry.position.x, v.global_position.z - entry.position.z).length() > 0.6:
			off_spot.append(v_name)
	t.check(all_ok and marlow.data.animations.get_animation_list().size() == 15, "Emma, Theo, Luna, Nana Bea, Pip, Mr. Ambrose and Captain Marlow each have a model, 15 animations and lines")
	t.check(off_spot.is_empty(), "each villager starts the day at their schedule spot (%s)" % ", ".join(off_spot))
	var theo := villagers.get_node("Theo") as Villager
	var ends := shape.get_bridge_ends()
	var over_bridge := false
	for point in theo.get_walk_path():
		over_bridge = over_bridge or Vector2(point.x, point.z).distance_to(ends[1]) < 0.5
	t.check(theo.get_mode() == Villager.Mode.WALKING and over_bridge and theo.get_entry() == theo.data.entry_for_hour(ActivityClock.get_hour()), "with the bridge rebuilt, Theo leaves the broken-bridge bank and walks home over it")
	var emma := villagers.get_node("Emma") as Villager
	var player := main.get_node("Player") as PlayerController
	var clock := ActivityClock.total_minutes
	emma.talk(player)
	t.check(emma.get_bubble_text() == emma.data.intro_lines[0], "Emma introduces herself the first time")
	emma.end_conversation()
	t.check(GameManager.has_flag(&"met_emma") and ActivityClock.total_minutes == clock, "meeting Emma is remembered and costs no time")

	# Grandpa's journal pages.
	var page := island.get_node("Buildings/Cottage/Interior/JournalPage1/Page") as JournalPage
	t.check(page.enabled and page.get_node("Model").visible, "journal page 1 waits on Grandpa's desk")
	page.interact(player)
	t.check(GameManager.has_flag(&"journal_page_1") and not page.enabled and not page.get_node("Model").visible, "reading it keeps the page (story flag) and it disappears")
	t.check(ActivityClock.total_minutes == clock, "reading a page costs no time")

	await _cottage_interior(t, main, island, player)

	for flag in STORY_FLAGS:
		GameManager.set_flag(flag, false)
	GameManager.reset_flags()
	main.queue_free()
	await t._frames(3)


func _cottage_interior(t: Node, main: Node, island: Node3D, player: PlayerController) -> void:
	print("== Cottage interior ==")
	var cottage := island.get_node("Buildings/Cottage") as Node3D
	var interior := cottage.get_node("Interior") as InteriorRoom
	var front_door := cottage.get_node("FrontDoor") as HouseDoor
	var exit_door := interior.get_node("ExitDoor") as HouseDoor
	var clock := ActivityClock.total_minutes
	t.check(not interior.visible, "the interior isn't drawn while you're outside")
	front_door.interact(player)
	var waited := 0
	while front_door.is_busy() and waited < 200:
		await t._frames(1)
		waited += 1
	await t._frames(20)
	t.check(interior.contains_point(player.global_position) and player.is_on_floor(), "E at the front door takes you inside the cottage, standing on the floor")
	t.check(interior.visible and not player.is_input_locked(), "inside, the room is drawn and you can move again")
	t.check(ActivityClock.total_minutes == clock, "going inside costs no time")
	t.check(GameManager.current_region_id == &"grandpas_cottage", "the HUD calls it Grandpa's Cottage")
	t.check(InteriorRoom.is_indoors(main.get_tree(), player.global_position), "rain stays outside (the room counts as indoors)")
	# The furniture is all there.
	var missing: Array[String] = []
	for item in ["Bed", "BedChest", "BedsideLamp", "Suitcase", "Rug", "Desk", "Journal", "DeskChair", "Bookshelf", "Stove", "Firewood", "Chest", "WindowChair", "PottedPlant", "HangingLamp"]:
		var model := interior.get_node_or_null("Furniture/" + item) as FittedModel
		if model == null or model.fitted_size.length() < 0.1:
			missing.append(item)
	t.check(missing.is_empty(), "the bed, desk, chairs, bookshelf, stove, rug, chests and lamps are furnished (%s)" % ", ".join(missing))
	# Walk around a little: the walls hold you in.
	Input.action_press(&"move_forward")
	await t._frames(150)
	Input.action_release(&"move_forward")
	await t._frames(10)
	t.check(interior.contains_point(player.global_position), "walking into the back wall keeps you inside")
	# Sit at Grandpa's desk.
	var desk_seat := interior.get_node("DeskSeat") as RestSpot
	desk_seat.interact(player)
	await t._frames(100)
	t.check(player.is_sitting() and ActivityClock.total_minutes == clock, "you can sit at Grandpa's desk (no time passes)")
	player.stand_up()
	await t._frames(150)
	t.check(not player.is_sitting(), "and stand up again")
	# Grandpa's chest keeps things for you.
	var chest := interior.get_node("ChestStorage") as StorageChest
	InventoryManager.clear()
	InventoryManager.add_item(&"turnip_seeds", 12)
	InventoryManager.add_item(&"wooden_plank", 60)
	InventoryManager.add_item(&"watering_can", 1)
	chest.interact(player)
	var storage := StoragePanel.get_instance(main.get_tree())
	await t._frames(2)
	t.check(storage.is_open() and storage.get_chest() == chest and player.is_input_locked(), "E on Grandpa's chest opens the storage window (the player stands still)")
	var seeds_slot := -1
	for i in InventoryManager.BAG_SLOTS:
		if storage.get_bag_slot_item(i).get("id", &"") == &"turnip_seeds":
			seeds_slot = i
	t.check(storage.move_from_bag(seeds_slot) == 12 and chest.get_count(&"turnip_seeds") == 12 and InventoryManager.get_count(&"turnip_seeds") == 0, "clicking a bag stack stores it in the chest")
	var chest_slot := -1
	for i in chest.slots:
		if storage.get_chest_slot_item(i).get("id", &"") == &"turnip_seeds":
			chest_slot = i
	t.check(storage.move_from_chest(chest_slot, true) == 1 and InventoryManager.get_count(&"turnip_seeds") == 1 and chest.get_count(&"turnip_seeds") == 11, "right-clicking takes just one back")
	t.check(storage.store_all() == 61 and InventoryManager.get_count(&"watering_can") == 1 and chest.get_count(&"wooden_plank") == 60, "Store all puts everything away but keeps your tools in the bag")
	t.check(chest.get_slots_used() == 3, "planks stack 50 to a slot in the chest too (60 planks + 12 seeds = 3 slots)")
	t.check(ActivityClock.total_minutes == clock, "storing things costs no time")
	var saved := chest.save_state()
	chest.load_state({})
	t.check(chest.get_count(&"wooden_plank") == 0, "(test) the chest can be emptied")
	chest.load_state(JSON.parse_string(JSON.stringify(saved)))
	t.check(chest.get_count(&"wooden_plank") == 60 and chest.get_count(&"turnip_seeds") == 12, "the chest's contents survive saving and loading")
	t.check(chest.is_in_group(&"persistent") and chest.get_save_key() == "storage_grandpa_chest", "the chest is saved with the game")
	var full := StorageChest.new()
	full.slots = 1
	InventoryManager.add_item(&"carrot_seeds", 99)
	InventoryManager.add_item(&"bread", 5)
	t.check(full.store(&"carrot_seeds", 99) == 99 and full.store(&"bread", 5) == 0, "a full chest refuses more (nothing is lost)")
	full.free()
	storage.close()
	t.check(not storage.is_open() and not player.is_input_locked(), "closing the window lets you walk again")
	InventoryManager.clear()

	# Out through the door, back onto the porch.
	exit_door.interact(player)
	waited = 0
	while exit_door.is_busy() and waited < 200:
		await t._frames(1)
		waited += 1
	await t._frames(20)
	var porch := cottage.get_node("OutsideSpawn") as Node3D
	t.check(player.global_position.distance_to(porch.global_position) < 0.8 and player.is_on_floor(), "\"Go outside\" puts you back on the porch")
	t.check(not interior.visible and ActivityClock.total_minutes == clock, "the room is hidden again, still no time passed")
	t.check(ScreenFade.get_instance(main.get_tree()).get_alpha() < 0.01, "the screen fades back in")
