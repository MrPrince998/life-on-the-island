extends RefCounted
## Checks for slice 3: Amber Plains (the new farmland on the east coast) and wheat, start
## to finish: hoe, sow, grow, scythe, tie, thresh, grind at the windmill, bake.
## Called from test_runner.gd:
##   await preload("res://tests/wheat_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Amber Plains and wheat ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	QuestLog.reset()

	# ---- The new land ----
	var shape := IslandShape.shared()
	var centre := shape.get_height(IslandShape.PLAINS_CENTER.x, IslandShape.PLAINS_CENTER.y)
	var flat := true
	for dx in range(-25, 26, 5):
		for dz in range(-25, 26, 5):
			flat = flat and absf(shape.get_height(IslandShape.PLAINS_CENTER.x + dx, IslandShape.PLAINS_CENTER.y + dz) - IslandShape.PLAINS_HEIGHT) < 0.1
	t.check(absf(centre - IslandShape.PLAINS_HEIGHT) < 0.1 and flat, "Amber Plains: a wide flat stretch of farmland (50 m across, level within 10 cm)")
	t.check(shape.get_height(290, 66) > 1.0 and shape.get_height(320, 66) < IslandShape.SEA_LEVEL, "the island reaches further east now, then meets the sea")
	t.check(shape.get_height(175, 128) < -1.0 and shape.get_height(168.8, 130.1) < -1.0, "the shipping bay by the jetty is still open water")
	t.check(shape.distance_to_paths(Vector2(196, 72)) < 2.0, "a path leads from the farm's east gate out to the plains")
	t.check(Minimap.MAP_WORLD_MIN.x + Minimap.MAP_WORLD_SIZE >= 305.0, "the minimap covers the new land")

	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var field := main.get_node("Island/Buildings/WheatField") as CropField
	var thresher := main.get_node("Island/Buildings/ThreshingShed/Thresher/Use") as ProcessingMachine
	var mill := main.get_node("Island/StoryPlaces/Farm/Windmill/AfterMillstones") as ProcessingMachine
	var region := main.get_node("Island/Regions/AmberPlains") as Area3D
	t.check(region != null and str(region.get("display_name")) == "Amber Plains", "arriving there shows \"Amber Plains\"")
	t.check(field != null and field.get_row_count() == 10 and field.crop.id == &"wheat" and absf(field.global_position.y - shape.get_height(field.global_position.x, field.global_position.z)) < 0.1, "a big wheat field lies on the plains (10 rows, 36 m long)")

	# ---- Tilling ----
	var row := field.get_row_spot(0)
	t.check(row.get_prompt().contains("you need a hoe"), "wheat ground must be tilled first, with a hoe")
	InventoryManager.add_item(&"log", 1)
	InventoryManager.add_money(500)
	t.check(BlacksmithService.forge(&"hoe").result == BlacksmithService.Result.OK, "Bram forges a hoe (1 log + 25 coins)")
	t.check(row.get_prompt().begins_with("Till the row with your hoe"), "with a hoe: \"%s\"" % row.get_prompt())
	var clock := ActivityClock.total_minutes
	Engine.time_scale = 8.0
	var strokes := [0]
	field.till_stroke.connect(func(_i: int) -> void: strokes[0] += 1)
	await field.act_on_row(0, player)
	t.check(field.get_row_state(0) == CropField.RowState.TILLED and field.is_row_tilled(0) and strokes[0] == field.crop.till_swings and ActivityClock.total_minutes == clock + field.crop.till_minutes, "%d hoe strokes turn the row to dark furrowed soil (%d min)" % [field.crop.till_swings, field.crop.till_minutes])
	t.check((field.get_node("Soil0") as Node3D).visible and not (field.get_node("Soil1") as Node3D).visible, "you can see which rows are tilled")

	# ---- Sowing ----
	t.check(ShopService.get_stock().any(func(i: ItemData) -> bool: return i.id == &"wheat_seed"), "Emma sells wheat seed in spring")
	t.check(row.get_prompt().contains("Wheat Seed"), "no seed yet: the row says what to buy")
	InventoryManager.add_item(&"wheat_seed", 3)
	t.check(not field.plant_now(1), "an untilled row can't be sown")
	clock = ActivityClock.total_minutes
	await field.act_on_row(0, player)
	t.check(field.get_row_state(0) == CropField.RowState.GROWING and InventoryManager.get_count(&"wheat_seed") == 2 and ActivityClock.total_minutes == clock + field.crop.plant_minutes, "sowing a tilled row uses one sack of seed (%d min)" % field.crop.plant_minutes)

	# ---- Growing (no watering: it lives on the rain) ----
	for i in field.crop.grow_days:
		_next_morning()
	await t._frames(2)
	t.check(field.get_row_state(0) == CropField.RowState.RIPE, "after %d days the wheat is ripe, no watering needed" % field.crop.grow_days)

	# ---- Cutting: sickle vs scythe ----
	InventoryManager.add_item(&"sickle")
	t.check(field.cut_swings() == field.crop.cut_swings and field.cut_minutes() == field.crop.cut_minutes, "with a sickle a row takes %d strokes, %d min" % [field.crop.cut_swings, field.crop.cut_minutes])
	InventoryManager.add_item(&"log", 3)
	t.check(BlacksmithService.forge(&"scythe").result == BlacksmithService.Result.OK, "Bram forges a scythe (3 logs + 80 coins)")
	t.check(field.cut_swings() < field.crop.cut_swings and field.cut_minutes() < field.crop.cut_minutes and row.get_prompt().contains("scythe"), "the scythe is quicker: \"%s\"" % row.get_prompt())
	strokes[0] = 0
	field.cut_stroke.connect(func(_i: int) -> void: strokes[0] += 1)
	clock = ActivityClock.total_minutes
	await field.act_on_row(0, player)
	var sheaves := int(field.get_row(0).sheaves)
	t.check(field.get_row_state(0) == CropField.RowState.CUT and strokes[0] == field.cut_swings() and ActivityClock.total_minutes == clock + field.cut_minutes(), "%d scythe sweeps cut the row; the wheat lies in it" % strokes[0])
	t.check(field.count_visible(0).y > 100 and field.count_visible(0).x == 0, "(%d bundles lying)" % field.count_visible(0).y)

	# ---- Tying ----
	await field.act_on_row(0, player)
	t.check(InventoryManager.get_count(&"wheat_sheaf") == sheaves and field.get_row_state(0) == CropField.RowState.EMPTY and not field.is_row_tilled(0), "gathered into %d sheaves; the row needs tilling again" % sheaves)
	Engine.time_scale = 1.0

	# ---- Threshing (the same pedal thresher as rice) ----
	t.check(thresher.get_prompt().contains("Wheat Sheaf"), "the thresher takes wheat too: \"%s\"" % thresher.get_prompt())
	thresher.process_now()
	t.check(InventoryManager.get_count(&"wheat_grain") == sheaves * 3 and InventoryManager.get_count(&"straw") == sheaves, "threshing: each wheat sheaf gives 3 grain and 1 straw")

	# ---- The windmill's millstones ----
	t.check(not mill.can_interact_now(player) and mill.process_now() == 0, "the millstones don't turn until the windmill is restored")
	GameManager.set_flag(&"restored_windmill")
	await t._frames(2)
	var grain := InventoryManager.get_count(&"wheat_grain")
	clock = ActivityClock.total_minutes
	t.check(mill.can_interact_now(player) and mill.get_prompt().begins_with("Grind wheat"), "with the windmill turning: \"%s\"" % mill.get_prompt())
	var batches := mill.process_now()
	t.check(InventoryManager.get_count(&"flour") == batches * 2 and InventoryManager.get_count(&"wheat_grain") == grain % 3 and ActivityClock.total_minutes == clock + batches * 5, "3 grain grind into 2 flour (5 min a batch)")
	var flour_value := InventoryManager.get_count(&"flour") * ItemDB.get_item(&"flour").sell_price
	var sheaf_value := sheaves * ItemDB.get_item(&"wheat_sheaf").sell_price
	t.check(flour_value > sheaf_value * 2, "each step adds value: %d coins of sheaves became %d coins of flour" % [sheaf_value, flour_value])
	var loaf := CookingService.get_recipe(&"fresh_loaf")
	t.check(loaf != null and CookingService.is_known(loaf) and CookingService.max_cookable(loaf) >= 1, "flour bakes into a Fresh Farmhouse Loaf")

	# ---- Save and load ----
	field.till_now(3)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(field.save_state()))
	field.load_state({"rows": [{}, {}, {}, {}, {}, {}, {}, {}, {}, {}]})
	t.check(field.get_row_state(3) == CropField.RowState.EMPTY, "(clearing the field for the load check)")
	field.load_state(saved)
	t.check(field.get_row_state(3) == CropField.RowState.TILLED and field.is_row_tilled(3), "tilled rows survive save and load")

	# ---- Seasons: wheat for the cool months, rice for the warm ones ----
	ActivityClock.from_dict({"total_minutes": (ActivityClock.DAYS_PER_SEASON * 3) * 24 * 60 + 8 * 60})
	t.check(ActivityClock.get_season_id() == &"winter" and field.plant_now(3), "wheat can be sown in winter (rice can't)")
	ActivityClock.from_dict({"total_minutes": (ActivityClock.DAYS_PER_SEASON * 1) * 24 * 60 + 8 * 60})
	field.till_now(4)
	t.check(ActivityClock.get_season_id() == &"summer" and not field.plant_now(4) and field.get_row_spot(4).get_prompt().contains("only grows in"), "but not in summer")

	Engine.time_scale = 1.0
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


func _next_morning() -> void:
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) if ActivityClock.minutes_until(6) > 0 else 24 * 60, &"test")
