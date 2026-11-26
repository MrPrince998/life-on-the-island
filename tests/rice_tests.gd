extends RefCounted
## Checks for rice, start to finish: Grandpa's paddy (CropField), the pump, the sickle,
## the pedal thresher and the huller (ProcessingMachine). Called from test_runner.gd:
##   await preload("res://tests/rice_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Rice: paddy, sickle, thresher, huller ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	QuestLog.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var field := main.get_node("Island/Buildings/RicePaddy") as CropField
	var pump := main.get_node("Island/Buildings/RicePaddy/Pump/PaddyPump") as PaddyPump
	var thresher := main.get_node("Island/Buildings/ThreshingShed/Thresher/Use") as ProcessingMachine
	var huller := main.get_node("Island/Buildings/ThreshingShed/Huller/Use") as ProcessingMachine
	t.check(field != null and field.get_row_count() == 5 and field.crop.id == &"rice", "Grandpa's paddy by the farm has 5 rows for rice")
	var ground := IslandShape.shared().get_height(field.global_position.x, field.global_position.z)
	t.check(absf(ground - field.global_position.y) < 0.1, "the paddy sits flat on level ground")

	# ---- Seedlings from the store ----
	t.check(ShopService.get_stock().any(func(i: ItemData) -> bool: return i.id == &"rice_seedlings"), "Emma sells rice seedlings in spring")

	# ---- Water first ----
	var row := field.get_row_spot(0)
	t.check(field.get_row_state(0) == CropField.RowState.EMPTY and not field.flooded and row.get_prompt().begins_with("Flood the paddy first"), "a dry paddy asks to be flooded first")
	InventoryManager.add_item(&"rice_seedlings", 2)
	t.check(not field.plant_now(0), "rice can't go into a dry paddy")
	var clock := ActivityClock.total_minutes
	Engine.time_scale = 8.0
	t.check(pump.get_prompt().begins_with("Pump water into the paddy"), "the pump: \"%s\"" % pump.get_prompt())
	await field.use_pump(player)
	t.check(field.flooded and ActivityClock.total_minutes == clock + CropField.FLOOD_MINUTES, "pumping floods the paddy (%d min)" % CropField.FLOOD_MINUTES)

	# ---- Planting ----
	t.check(row.get_prompt().begins_with("Plant a row of rice"), "flooded, with seedlings: \"%s\"" % row.get_prompt())
	clock = ActivityClock.total_minutes
	await field.act_on_row(0, player)
	t.check(field.get_row_state(0) == CropField.RowState.GROWING and InventoryManager.get_count(&"rice_seedlings") == 1 and ActivityClock.total_minutes == clock + field.crop.plant_minutes, "planting a row uses one bundle of seedlings (%d min)" % field.crop.plant_minutes)
	t.check(field.count_visible(0).x > 50 and not player.is_input_locked(), "the row fills with young rice (%d plants)" % field.count_visible(0).x)

	# ---- Growing ----
	_next_morning()
	await t._frames(2)
	t.check(int(field.get_row(0).grown) == 1, "a day in standing water: it grows")
	field.set_flooded(false)
	_next_morning()
	await t._frames(2)
	t.check(int(field.get_row(0).grown) == 1 and field.get_row_state(0) == CropField.RowState.GROWING, "drained, it waits (it doesn't die)")
	t.check(row.get_prompt().contains("the paddy is dry"), "the row says it needs water")
	field.set_flooded(true)
	for i in field.crop.grow_days - 1:
		_next_morning()
	await t._frames(2)
	t.check(field.get_row_state(0) == CropField.RowState.RIPE, "after %d days in water the rice is ripe and golden" % field.crop.grow_days)

	# ---- Cutting ----
	t.check(row.get_prompt().begins_with("Ripe! Drain the paddy"), "ripe rice is cut on dry ground: drain first")
	t.check(not field.cut_now(0), "no cutting while it's flooded")
	field.set_flooded(false)
	t.check(row.get_prompt().contains("You need a sickle"), "and you need a sickle")
	InventoryManager.add_item(&"log", 2)
	InventoryManager.add_money(100)
	var forged := BlacksmithService.forge(&"sickle")
	t.check(forged.result == BlacksmithService.Result.OK and WoodcuttingController.has_sickle(), "Bram forges a sickle from 2 logs + 30 coins")
	t.check(row.get_prompt().begins_with("Cut the rice with your sickle"), "with a sickle: \"%s\"" % row.get_prompt())
	var strokes := [0]
	field.cut_stroke.connect(func(_i: int) -> void: strokes[0] += 1)
	clock = ActivityClock.total_minutes
	await field.act_on_row(0, player)
	var sheaves := int(field.get_row(0).sheaves)
	t.check(field.get_row_state(0) == CropField.RowState.CUT and strokes[0] == field.crop.cut_swings and ActivityClock.total_minutes == clock + field.crop.cut_minutes, "%d sickle strokes cut the row (%d min)" % [field.crop.cut_swings, field.crop.cut_minutes])
	var seen := field.count_visible(0)
	t.check(seen.x == 0 and seen.y > 50, "the cut rice lies down in the row (%d bundles lying, none standing)" % seen.y)
	t.check(sheaves >= field.crop.sheaves_per_row.x and sheaves <= field.crop.sheaves_per_row.y, "the row will make %d sheaves" % sheaves)

	# ---- Tying ----
	t.check(row.get_prompt().begins_with("Gather and tie"), "the cut row: \"%s\"" % row.get_prompt())
	await field.act_on_row(0, player)
	t.check(InventoryManager.get_count(&"rice_sheaf") == sheaves and field.get_row_state(0) == CropField.RowState.EMPTY and bool(field.get_row(0).stubble), "gathering ties it into %d sheaves; stubble is left in the row" % sheaves)
	Engine.time_scale = 1.0

	# ---- Threshing ----
	t.check(thresher.get_prompt().begins_with("Thresh sheaves") and thresher.get_prompt().contains("Rice Sheaf"), "the thresher: \"%s\"" % thresher.get_prompt())
	clock = ActivityClock.total_minutes
	var threshed := thresher.process_now()
	t.check(threshed == sheaves and InventoryManager.get_count(&"rice_sheaf") == 0 and InventoryManager.get_count(&"paddy_rice") == sheaves * 3 and InventoryManager.get_count(&"straw") == sheaves, "threshing: each sheaf gives 3 unhusked rice and 1 straw")
	t.check(ActivityClock.total_minutes == clock + 5 * sheaves, "threshing takes 5 minutes a sheaf")

	# ---- Hulling ----
	var paddy := InventoryManager.get_count(&"paddy_rice")
	huller.process_now()
	t.check(InventoryManager.get_count(&"rice") == (paddy / 3) * 2 and InventoryManager.get_count(&"paddy_rice") == paddy % 3, "hulling: 3 unhusked rice make 2 rice")
	var rice := InventoryManager.get_count(&"rice")
	var sheaf_value := sheaves * ItemDB.get_item(&"rice_sheaf").sell_price
	var rice_value := rice * ItemDB.get_item(&"rice").sell_price + sheaves * ItemDB.get_item(&"straw").sell_price
	t.check(rice_value > sheaf_value * 2, "each step adds value: %d coins of sheaves become %d coins of rice and straw" % [sheaf_value, rice_value])
	var coins := InventoryManager.get_money()
	ShopService.sell(&"rice", 2)
	t.check(InventoryManager.get_money() == coins + 2 * ItemDB.get_item(&"rice").sell_price, "the store buys rice")
	var bowl := CookingService.get_recipe(&"fish_rice_bowl")
	t.check(bowl != null and CookingService.is_known(bowl), "there's a new recipe: Fish and Rice Bowl")
	t.check(thresher.process_now() == 0, "nothing to thresh: nothing happens")

	# ---- Save and load ----
	field.set_flooded(true)
	field.plant_now(1)
	_next_morning()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(field.save_state()))
	field.set_flooded(false)
	field.load_state({"rows": [{}, {}, {}, {}, {}]})
	t.check(field.get_row_state(1) == CropField.RowState.EMPTY, "(clearing the field for the load check)")
	field.load_state(saved)
	t.check(field.flooded and field.get_row_state(1) == CropField.RowState.GROWING and int(field.get_row(1).grown) == 1 and bool(field.get_row(0).stubble), "the paddy survives save and load (water, growing rows, stubble)")

	# ---- Seasons ----
	ActivityClock.from_dict({"total_minutes": (ActivityClock.DAYS_PER_SEASON * 3) * 24 * 60 + 8 * 60})
	InventoryManager.add_item(&"rice_seedlings", 1)
	t.check(ActivityClock.get_season_id() == &"winter" and not field.plant_now(2) and field.get_row_spot(2).get_prompt().contains("only grows in"), "rice can't be planted in winter")
	t.check(not ShopService.get_stock().any(func(i: ItemData) -> bool: return i.id == &"rice_seedlings"), "and the store doesn't stock seedlings then")

	Engine.time_scale = 1.0
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


func _next_morning() -> void:
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) if ActivityClock.minutes_until(6) > 0 else 24 * 60, &"test")
