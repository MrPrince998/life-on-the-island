extends Node
## FULL PLAYTHROUGH BOT: plays Life on the Island from "New game" to the closing credits,
## the way a player would, and reports soft-locks, pacing and the economy.
##
##   Godot --headless --fixed-fps 60 --path . res://tests/playthrough_runner.tscn
##
## Rules the bot keeps (so a pass means a real player can finish the story):
## - It never sets story flags, adds items or coins, or starts quests itself. Everything
##   happens through the game's own systems: walking up to things and pressing E (real
##   input events through PlayerInteraction), talking, the shop panel, farming plots,
##   gathering spots, the sawhorse, the bed, doors, and real fishing (cast, wait for the
##   bite, hook, and reel by watching the line tension with a human-like reaction delay).
## - Walking is a teleport (walking costs no game time anyway), but only to places a
##   flood-fill walk map says are reachable on foot from the arrival jetty in the current
##   story state (tests/playthrough_walkmap.gd). An unreachable quest target = soft-lock.
## - It saves, quits and continues twice along the way.
## Exits 0 when the credits roll with no problems, 1 otherwise (2 on a hang).

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const WalkMap := preload("res://tests/playthrough_walkmap.gd")
const MAX_DAYS := 90
const REAL_TIME_LIMIT_MS := 45 * 60 * 1000
const FISH_IDS := [&"silver_minnow", &"sunfish", &"moonfin_koi", &"sea_bream", &"blue_mackerel", &"flying_fish", &"azure_manta"]
const CROP_IDS := [&"turnip", &"carrot", &"sunflower", &"tomato", &"pumpkin", &"kale"]
## Garden beds the bot looks after (a modest farm, like a new player's).
const FARM_PLOTS := 6
## Seconds between seeing the line tension and reacting to it (a person, not a machine).
const REACTION_FRAMES := 9

var main: Node3D
var player: PlayerController
var reach: PlayerInteraction
var fishing: FishingController
var farming: FarmingController
var shop: ShopPanel
var walk: WalkMap
var start_point := Vector3.ZERO

var problems: PackedStringArray = []
var notes: PackedStringArray = []
var timeline: PackedStringArray = []
var minutes_by_activity := {}
var stats := {
	"casts": 0, "caught": 0, "lost": 0, "dry_casts": 0, "no_bite": 0,
	"by_fish": {}, "lost_by_fish": {}, "earned_selling": 0, "spent_buying": 0, "spent_upgrades": 0, "upgrades": [],
	"bought": {}, "gathered": {}, "sleeps": 0, "walk_maps": 0, "teleports": 0,
}

var _walk_key := "?"
var _last_notice := ""
var _notices: PackedStringArray = []
var _tension_hist: Array[float] = []
var _power := 0.0
var _caught_flag := false
var _started_ms := 0
var _stopped := false
var _credits_seen := false
var _saw_credits_lines := false


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	SaveManager.use_test_slot()
	SaveManager.delete_save()
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	GameManager.notification_posted.connect(func(text: String) -> void:
		_last_notice = text
		_notices.append(text))
	ActivityClock.time_advanced.connect(func(minutes: int, activity: StringName) -> void:
		minutes_by_activity[activity] = int(minutes_by_activity.get(activity, 0)) + minutes)
	await _play()
	_report()
	SaveManager.delete_save()
	get_tree().quit(1 if not problems.is_empty() or not _credits_seen else 0)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started_ms > REAL_TIME_LIMIT_MS and not _stopped:
		_stopped = true
		print("TIMEOUT: the playthrough bot ran out of real time")
		_report()
		get_tree().quit(2)


# =====================================================================================
#  The story, beat by beat
# =====================================================================================

func _play() -> void:
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	for service in [Friendship, Journal]:
		if service.has_method(&"reset"):
			service.call(&"reset")
	await _load_main(true)

	# ---- Prologue -------------------------------------------------------------------
	var opening := main.get_node_or_null("OpeningScene") as OpeningScene
	if not _expect(opening != null and opening.is_running(), "a new game starts with the opening scene"):
		return
	opening.speed = 14.0
	var guard := 0
	while is_instance_valid(opening) and opening.is_running() and guard < 3000:
		await _frames(1)
		guard += 1
	await _frames(30)
	_expect(not player.is_input_locked() and GameManager.has_flag(&"opening_seen"), "the opening hands control to the player")
	start_point = player.global_position
	_log("Arrived on the island at the beach jetty")
	_expect(QuestLog.is_active(&"arrival"), "the first quest (find Emma) is in the tracker")
	_expect(not fishing.has_rod(), "the player arrives without a fishing rod (Oliver gives it)")

	await _talk(_villager("Emma"))
	_expect(GameManager.has_flag(&"met_emma") and QuestLog.is_done(&"arrival"), "meeting Emma finishes \"Welcome to Willowbrook\"")
	await _talk(_villager("Oliver"))
	_expect(fishing.has_rod(), "Oliver gives you Grandpa's fishing rod")
	await _talk(_villager("Mia"))
	_expect(GameManager.has_flag(&"met_mia"), "you meet Mia at the farm")
	_log("Met Emma, Oliver and Mia")
	await _read_page_if_any("Island/Buildings/Cottage/Interior/JournalPage1/Page")
	await _read_page_if_any("Island/StoryPlaces/Story/JournalPage2/Page")

	# Grandpa's garden: the watering can, a first crop.
	await _use_path("Island/Buildings/FarmField/GardenShed/GrandpasCan")
	_expect(InventoryManager.has_item(&"watering_can"), "Grandpa's watering can is in the garden shed")
	await _shop_visit({}, true)
	await _tend_farm()
	# First fish for Oliver's lessons (and the first coins).
	await _fish_until(func() -> bool: return stats.caught >= 3, "lake", 20)
	await _shop_visit({}, true)
	_expect(QuestLog.is_done(&"fishing_lessons"), "Oliver's lessons: catch a fish and sell it")
	_log("Prologue: rod, can, first seeds and first fish sold")

	# ---- Chapter 1: Seeds of Spring --------------------------------------------------
	_expect(QuestLog.is_active(&"seeds_of_spring"), "Chapter 1 starts after meeting Mia")
	await _use_path("Island/StoryPlaces/Farm/BrambleGate/BeforeClearSpot/Clear")
	_expect(GameManager.has_flag(&"ch1_hedge_cleared"), "Ch1: you clear the brambles with Mia")
	await _talk(_villager("Mia"))
	if not await _days_until(func() -> bool: return QuestLog.get_step_index(&"seeds_of_spring") >= 2 or QuestLog.is_done(&"seeds_of_spring"), "Ch1: harvest 3 crops", 8):
		return
	if not await _get_building_materials(&"windmill", "the windmill"):
		return
	await _use_path("Island/StoryPlaces/Farm/Windmill/RepairBase/Repair")
	if not _expect(GameManager.has_flag(&"restored_windmill"), "Ch1: the windmill is repaired"):
		return
	await _frames(4)
	await _use_path("Island/StoryPlaces/Farm/Windmill/AfterShard/Pickup")
	_expect(GameManager.has_flag(&"shard_1"), "Ch1: Glowstone 1 in the windmill gearbox")
	await _use_path("Island/StoryPlaces/Farm/OrchardPlanting/Plant")
	if not _expect(QuestLog.is_done(&"seeds_of_spring"), "Chapter 1 complete"):
		return
	_log("CHAPTER 1 complete (windmill, Glowstone 1, orchard)")

	# ---- Chapter 2: The Carpenter's Bridge -------------------------------------------
	await _talk(_villager("Theo"))
	if not _expect(GameManager.has_flag(&"met_theo") and QuestLog.is_active(&"carpenters_bridge"), "Ch2: meeting Theo starts the bridge chapter"):
		return
	if not await _get_building_materials(&"bridge", "the Willow Creek bridge"):
		return
	await _use_path("Island/StoryPlaces/Forest/BridgeRepairBase/Repair")
	if not _expect(GameManager.has_flag(&"restored_bridge"), "Ch2: the bridge is rebuilt"):
		return
	await _use_path("Island/StoryPlaces/Story/JournalPage4/Page")
	_expect(GameManager.has_flag(&"journal_page_4"), "Ch2: journal page 4 under the ancient oak")
	await _use_path("Island/StoryPlaces/Forest/SaplingPlanting/Plant")
	_expect(GameManager.has_flag(&"ch2_saplings_planted"), "Ch2: saplings planted with Theo")
	await _sleep()
	_expect(GameManager.has_flag(&"ch2_tree_restored"), "Ch2: next morning the ancient oak is in leaf")
	await _use_path("Island/StoryPlaces/Forest/ShrineShard/AfterShard/Pickup")
	if not _expect(GameManager.has_flag(&"shard_2") and QuestLog.is_done(&"carpenters_bridge"), "Chapter 2 complete (Glowstone 2 at the shrine)"):
		return
	_log("CHAPTER 2 complete (bridge, oak, Glowstone 2)")
	await _save_quit_continue()

	# ---- Chapter 3: Market Day -------------------------------------------------------
	_expect(QuestLog.is_active(&"market_ledger"), "Ch3 starts after Glowstone 2")
	await _talk(_villager("Emma"))
	await _talk(_villager("MrAmbrose"))
	if not _expect(QuestLog.is_active(&"market_day"), "Ch3: Mr. Ambrose reads Grandpa's ledger (pages 5-6)"):
		return
	if not await _get_building_materials(&"market", "the market stalls"):
		return
	await _use_path("Island/StoryPlaces/Village/MarketRepairBase/Repair")
	if not _expect(GameManager.has_flag(&"restored_market"), "Ch3: the market stalls are restored"):
		return
	if not await _days_until(func() -> bool: return QuestLog.get_step_index(&"market_day") >= 3 or QuestLog.is_done(&"market_day"), "Ch3: sell 10 fish and 10 crops", 10):
		return
	await _talk(_villager("Emma"))
	if not _expect(QuestLog.is_done(&"market_day") and GameManager.has_flag(&"ch3_market_day"), "Ch3: Market Day!"):
		return
	await _pass_time_until(19)
	await _frames(4)
	await _use_path("Island/StoryPlaces/Village/WellGlow/AfterWell/Pickup")
	if not _expect(GameManager.has_flag(&"shard_3") and QuestLog.is_done(&"well_light"), "Chapter 3 complete (Glowstone 3 in the glowing well)"):
		return
	_log("CHAPTER 3 complete (market, Market Day, Glowstone 3)")
	await _sleep()

	# ---- Chapter 4: The Keeper's Light -------------------------------------------------
	_expect(QuestLog.is_active(&"keepers_light"), "Ch4 starts after Glowstone 3")
	await _use_path("Island/StoryPlaces/Coast/Rockfall/BeforeClearSpot/Clear")
	if not _expect(GameManager.has_flag(&"ch4_rockfall_cleared"), "Ch4: the cliff bridge is mended with Theo"):
		return
	await _talk(_villager("Luna"))
	_expect(QuestLog.get_step_index(&"keepers_light") >= 2, "Ch4: you meet Luna at the lighthouse")
	if ActivityClock.get_hour() >= 10 or ActivityClock.get_hour() < 6:
		await _sleep()
	await _use_path("Island/StoryPlaces/Coast/CaveShard/Pickup")
	_expect(GameManager.has_flag(&"shard_4"), "Ch4: Glowstone 4 in the sea cave at low tide")
	await _use_path("Island/StoryPlaces/Story/MessageBottle/Page")
	_expect(GameManager.has_flag(&"journal_page_8"), "Ch4: the message in a bottle (page 8)")
	await _use_path("Island/StoryPlaces/Coast/ChestShard/Pickup")
	if not _expect(GameManager.has_flag(&"shard_5") and QuestLog.is_done(&"keepers_light"), "Chapter 4 complete (Glowstone 5 in the captain's chest)"):
		return
	_log("CHAPTER 4 complete (cliff bridge, Luna, Glowstones 4 and 5)")
	await _save_quit_continue()

	# ---- Finale: The Moonwell ----------------------------------------------------------
	_expect(QuestLog.is_active(&"finale_page9"), "the finale starts with all five Glowstones")
	await _talk(_villager("Oliver"))
	if not _expect(GameManager.has_flag(&"journal_page_9") and QuestLog.is_active(&"finale_lens"), "Finale: Oliver gives you page 9"):
		return
	if not await _get_building_materials(&"lighthouse", "the lighthouse lens"):
		return
	_expect(InventoryManager.get_count(&"glowstone_shard") == 5, "all five Glowstones are still in the bag for the lens")
	await _use_path("Island/StoryPlaces/Coast/LensRepairBase/Repair")
	if not _expect(GameManager.has_flag(&"restored_lighthouse"), "Finale: the lens is mended"):
		return
	await _pass_time_until(20)
	await _frames(4)
	if not _expect(GameManager.has_flag(&"lighthouse_lit"), "Finale: at nightfall the lighthouse shines"):
		return
	await _use_path("Island/StoryPlaces/Lake/RowToIsle")
	_expect(player.global_position.distance_to((main.get_node("Island/StoryPlaces/Lake/IsleLanding") as Node3D).global_position) < 2.0, "Finale: you row out to the little isle")
	await _use_path("Island/StoryPlaces/Lake/IslePage/After/Page", false)
	await _frames(3)
	var credits := get_tree().root.get_node_or_null(^"FinaleCredits") as FinaleCredits
	_credits_seen = credits != null and credits.is_running() and GameManager.has_flag(&"journal_page_10") and QuestLog.is_done(&"finale_lens")
	_expect(_credits_seen, "Finale: Grandpa's last letter (page 10) and the closing credits")
	_log("FINALE: page 10 read, credits roll")
	guard = 0
	while is_instance_valid(credits) and credits.is_running() and guard < 4000:
		await _frames(1)
		guard += 1
	_expect(not is_instance_valid(credits) and not player.is_input_locked(), "after the credits the game carries on (free play)")
	await _use_path("Island/StoryPlaces/Lake/IsleDock/RowBack")
	_expect(player.global_position.distance_to((main.get_node("Island/StoryPlaces/Lake/DockLanding") as Node3D).global_position) < 2.0, "you can row back to the dock")
	_log("Free play")
	await _spend_on_upgrades()


## After the story: spend the savings at the store's Upgrades tab, the way a player
## might (most useful first), and check what was bought shows up.
func _spend_on_upgrades() -> void:
	var counter := main.get_node("Island/Buildings/GeneralStore/ShopCounter") as Interactable
	if not await _use(counter, false):
		return
	var g := 0
	while not shop.is_open() and g < 30:
		await _frames(1)
		g += 1
	if not _expect(shop.is_open(), "Upgrades: the store opens"):
		return
	shop.show_upgrades()
	var order := [&"tool_bag_satchel", &"farm_beds_1", &"tool_rod_oak", &"tool_can_copper", &"home_plants",
		&"home_paintings", &"village_flowers", &"home_trophy", &"home_bench", &"village_benches",
		&"village_lamps", &"home_lantern", &"home_barrel", &"home_beehive", &"village_bunting",
		&"farm_beds_2", &"tool_bag_pack", &"tool_rod_moonwood"]
	for id: StringName in order:
		if UpgradeService.can_buy(id) == UpgradeService.Result.OK:
			var before := InventoryManager.get_money()
			shop.buy_upgrade(id)
			stats.spent_upgrades += before - InventoryManager.get_money()
			stats.upgrades.append(String(id))
	shop.close()
	await _frames(3)
	var bought: Array = stats.upgrades
	_expect(not bought.is_empty(), "Upgrades: the savings buy something")
	if bought.has("farm_beds_1"):
		var field := main.get_node("Island/Buildings/FarmField") as FarmField
		_expect(field.get_plots().filter(func(p: FarmPlot) -> bool: return p.is_visible_in_tree()).size() >= 16, "Upgrades: the new garden beds are there")
	if bought.has("tool_bag_satchel"):
		_expect(InventoryManager.get_bag_slots() >= 30, "Upgrades: the bag is bigger")
	_log("Spent %d coins on %d of %d upgrades" % [stats.spent_upgrades, bought.size(), UpgradeService.get_all().size()])


# =====================================================================================
#  Goals that take days: materials, waiting for things to grow or for the evening
# =====================================================================================

## Gathers wood and stone, saws planks, earns coins and buys what's still missing, a day
## at a time, until the bag holds `planks` planks, `stone` stone and `coins` coins.
## What a repair needs, read from its BuildingData (so price changes never break the bot).
func _get_building_materials(building_id: StringName, what: String) -> bool:
	var building := load("res://data/buildings/%s.tres" % building_id) as BuildingData
	return await _get_materials(int(building.materials.get("wooden_plank", 0)), int(building.materials.get("stone", 0)), building.cost_coins, what)


func _get_materials(planks: int, stone: int, coins: int, what: String) -> bool:
	var day0 := ActivityClock.get_day()
	for attempt in 20:
		if _have(planks, stone, coins):
			_log("Materials ready for %s (after %d day(s) of work)" % [what, ActivityClock.get_day() - day0])
			return true
		if ActivityClock.get_day() > MAX_DAYS:
			break
		# Mornings: look after the farm, then gather.
		await _tend_farm()
		var wood_for_planks := maxi(0, (planks - InventoryManager.get_count(&"wooden_plank")) * 2 - InventoryManager.get_count(&"wood"))
		if wood_for_planks > 0:
			await _gather(&"wood", InventoryManager.get_count(&"wood") + wood_for_planks)
		if InventoryManager.get_count(&"wood") >= 2 and InventoryManager.get_count(&"wooden_plank") < planks:
			await _saw(planks)
		if InventoryManager.get_count(&"stone") < stone:
			await _gather(&"stone", stone)
		if _have(planks, stone, coins):
			continue
		# Afternoons: fish, sell, and buy whatever is still missing.
		await _fish_until(func() -> bool: return ActivityClock.get_hour() >= 17 or InventoryManager.get_slots_used() >= 20, "sea", 40)
		var buy := {}
		var short_planks := planks - InventoryManager.get_count(&"wooden_plank")
		var short_stone := stone - InventoryManager.get_count(&"stone")
		if short_planks > 0:
			buy[&"wooden_plank"] = short_planks
		if short_stone > 0:
			buy[&"stone"] = short_stone
		await _shop_visit(buy, true, coins)
		if not _have(planks, stone, coins):
			await _sleep()
	return _fail("could not gather %d planks, %d stone and %d coins for %s (have %d, %d, %d)" % [planks, stone, coins, what,
			InventoryManager.get_count(&"wooden_plank"), InventoryManager.get_count(&"stone"), InventoryManager.get_money()])


func _have(planks: int, stone: int, coins: int) -> bool:
	return InventoryManager.get_count(&"wooden_plank") >= planks and InventoryManager.get_count(&"stone") >= stone and InventoryManager.get_money() >= coins


## Ordinary days (farm in the morning, fish, sell, sleep) until `done` is true.
func _days_until(done: Callable, what: String, max_days: int) -> bool:
	var day0 := ActivityClock.get_day()
	while not done.call():
		if ActivityClock.get_day() - day0 >= max_days or ActivityClock.get_day() > MAX_DAYS:
			return _fail("%s: still not done after %d days" % [what, ActivityClock.get_day() - day0])
		await _tend_farm()
		if done.call():
			break
		await _fish_until(func() -> bool: return ActivityClock.get_hour() >= 17 or InventoryManager.get_slots_used() >= 20, "sea", 40)
		await _shop_visit({}, true)
		if done.call():
			break
		await _tend_farm()
		await _sleep()
	_log("%s (took %d day(s))" % [what, ActivityClock.get_day() - day0])
	return true


## Passes the time until `hour` the way a player would: fishing.
func _pass_time_until(hour: int) -> void:
	var guard := 0
	while ActivityClock.get_hour() < hour and ActivityClock.get_hour() >= 5 and guard < 6:
		await _fish_until(func() -> bool: return ActivityClock.get_hour() >= hour or InventoryManager.get_slots_used() >= 22, "sea", 60)
		if ActivityClock.get_hour() < hour:
			await _shop_visit({}, true)
		guard += 1


# =====================================================================================
#  Everyday actions
# =====================================================================================

func _tend_farm() -> void:
	var plots := main.get_node("Island/Buildings/FarmField/Plots").get_children()
	for i in mini(FARM_PLOTS, plots.size()):
		var plot := plots[i] as FarmPlot
		for step in 3:
			var action := farming.get_action(plot)
			if action == FarmingController.Action.NEED_SEEDS:
				await _shop_visit(_seed_order(), true)
				action = farming.get_action(plot)
			if action not in [FarmingController.Action.DIG, FarmingController.Action.PLANT, FarmingController.Action.WATER, FarmingController.Action.HARVEST]:
				break
			if not await _use(plot):
				break
			var g := 0
			while farming.is_busy() and g < 300:
				await _frames(1)
				g += 1


## The cheapest in-season seeds, enough for the beds that need them.
func _seed_order() -> Dictionary:
	var best: ItemData = null
	for item in ShopService.get_stock():
		if str(item.id).ends_with("_seeds") and ShopService.is_in_season(item.id):
			if best == null or item.buy_price < best.buy_price:
				best = item
	if best == null:
		return {}
	var have := InventoryManager.get_count(best.id)
	var want := FARM_PLOTS - have
	var afford := InventoryManager.get_money() / maxi(best.buy_price, 1)
	return {best.id: clampi(want, 0, afford)} if want > 0 and afford > 0 else {}


func _gather(item_id: StringName, target: int) -> void:
	var holder := main.get_node("Island/StoryPlaces/Gathering/WoodSpots" if item_id == &"wood" else "Island/StoryPlaces/Gathering/StoneSpots")
	var spots: Array = holder.get_children().filter(func(n: Node) -> bool: return n is GatherNode)
	spots.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for spot in spots:
		if InventoryManager.get_count(item_id) >= target:
			return
		var node := spot as GatherNode
		if not node.is_ready() or not node.enabled:
			continue
		await _ensure_walkmap()
		if not walk.is_reachable(node.global_position):
			continue
		var before := InventoryManager.get_count(item_id)
		if await _use(node):
			stats.gathered[item_id] = int(stats.gathered.get(item_id, 0)) + InventoryManager.get_count(item_id) - before


func _saw(planks_wanted: int) -> void:
	var saw := main.get_node("Island/StoryPlaces/Gathering/Sawhorse/Saw") as Interactable
	var guard := 0
	while InventoryManager.get_count(&"wood") >= 2 and InventoryManager.get_count(&"wooden_plank") < planks_wanted and guard < 6:
		var before := InventoryManager.get_count(&"wooden_plank")
		await _use(saw)
		if InventoryManager.get_count(&"wooden_plank") == before:
			problems.append("the sawhorse made no planks (prompt: %s, notice: %s)" % [saw.get_prompt(), _last_notice])
			return
		guard += 1


## Opens the store: sells fish, crops and dishes, then buys `buy` ({item: amount}) while
## keeping `keep_coins` in the purse.
func _shop_visit(buy: Dictionary, sell_all: bool, keep_coins: int = 0) -> void:
	var counter := main.get_node("Island/Buildings/GeneralStore/ShopCounter") as Interactable
	if not await _use(counter, false):
		return
	var g := 0
	while not shop.is_open() and g < 30:
		await _frames(1)
		g += 1
	if not shop.is_open():
		_fail("the shop panel didn't open at the counter")
		return
	if sell_all:
		for item_id in FISH_IDS + CROP_IDS:
			var n := InventoryManager.get_count(item_id)
			if n > 0:
				var before := InventoryManager.get_money()
				shop.sell(item_id, n)
				stats.earned_selling += InventoryManager.get_money() - before
	if buy.is_empty() and InventoryManager.get_count(&"turnip_seeds") + InventoryManager.get_count(&"carrot_seeds") == 0:
		buy = _seed_order()
	for item_id in buy:
		var item := ItemDB.get_item(item_id)
		var afford := (InventoryManager.get_money() - keep_coins) / maxi(item.buy_price, 1)
		var n := mini(int(buy[item_id]), afford)
		if n <= 0:
			continue
		var before := InventoryManager.get_money()
		shop.buy(item_id, n)
		if InventoryManager.get_money() < before:
			stats.spent_buying += before - InventoryManager.get_money()
			stats.bought[item_id] = int(stats.bought.get(item_id, 0)) + n
	shop.close()
	await _frames(3)


func _sleep() -> void:
	var bed := main.get_node("Island/Buildings/Cottage/Interior/BedRest") as Interactable
	var before := ActivityClock.total_minutes
	await _use(bed)
	stats.sleeps += 1
	if ActivityClock.total_minutes == before or ActivityClock.get_hour() != 6:
		_fail("sleeping in Grandpa's bed didn't start a new day (%s)" % ActivityClock.get_time_string())


func _read_page_if_any(path: String) -> void:
	var page := main.get_node_or_null(path) as Interactable
	if page and page.is_visible_in_tree() and page.enabled:
		await _use(page)


# =====================================================================================
#  Fishing, with a human-like reeler
# =====================================================================================

func _fish_until(done: Callable, where: String, max_casts: int) -> void:
	var spot_path := "Island/Buildings/FishingDock/WatchTheWater" if where == "lake" else "Island/StoryPlaces/Coast/BeachJetty/Jetty/WatchTheWater"
	var spot := main.get_node(spot_path) as RestSpot
	var stand := spot.get_stand_point()
	var yaw := _find_cast_yaw(stand)
	if is_nan(yaw):
		_fail("no direction to cast from the %s fishing spot" % where)
		return
	if not await _go_to_point(stand, yaw):
		return
	if fishing.state == FishingController.State.STOWED:
		await _press(&"toggle_rod")
		await _frames(10)
	if fishing.state != FishingController.State.READY:
		_fail("the rod didn't come out (state %d)" % fishing.state)
		return
	var casts := 0
	while not done.call() and casts < max_casts and not InventoryManager.is_full():
		(player.get_node("CameraRig") as CameraRig).set_yaw(yaw)
		await _cast_once()
		casts += 1
	if fishing.state == FishingController.State.READY:
		await _press(&"toggle_rod")
		await _frames(4)


func _find_cast_yaw(stand: Vector3) -> float:
	for k in 48:
		var yaw := TAU * k / 48.0
		var dir := Vector3.FORWARD.rotated(Vector3.UP, yaw)
		var ok := true
		for d in [5.0, 8.0, 10.0]:
			if fishing.find_water_at(stand + dir * d) == null:
				ok = false
				break
		if ok:
			return yaw
	return NAN


func _cast_once() -> void:
	stats.casts += 1
	_power = 0.0
	await _hold(&"use_tool", true)
	var g := 0
	while (fishing.state != FishingController.State.CHARGING or _power < 0.62) and g < 240:
		await _frames(1)
		g += 1
	await _hold(&"use_tool", false)
	g = 0
	while fishing.state == FishingController.State.CASTING or fishing.state == FishingController.State.CHARGING:
		await _frames(1)
		g += 1
		if g > 400:
			break
	if fishing.state != FishingController.State.WAITING:
		stats.dry_casts += 1
		await _wait_ready()
		return
	g = 0
	while fishing.state == FishingController.State.WAITING and g < 1200:
		await _frames(1)
		g += 1
	if fishing.state != FishingController.State.BITE:
		stats.no_bite += 1
		await _wait_ready()
		return
	await _frames(18)  # a person notices the bobber dip
	var fish := fishing.get_hooked_fish()
	_tension_hist.clear()
	_caught_flag = false
	await _hold(&"use_tool", true)
	var holding := true
	g = 0
	while fishing.state == FishingController.State.REELING and g < 6000:
		var seen: float = _tension_hist[maxi(0, _tension_hist.size() - REACTION_FRAMES)] if not _tension_hist.is_empty() else 0.3
		var want := seen < 0.6
		if want != holding:
			holding = want
			await _hold(&"use_tool", holding)
		else:
			await _frames(1)
		g += 1
	if holding:
		await _hold(&"use_tool", false)
	var fish_id := str(fish.id) if fish else "?"
	if _caught_flag:
		stats.caught += 1
		stats.by_fish[fish_id] = int(stats.by_fish.get(fish_id, 0)) + 1
	else:
		stats.lost += 1
		stats.lost_by_fish[fish_id] = int(stats.lost_by_fish.get(fish_id, 0)) + 1
	await _wait_ready()


func _wait_ready() -> void:
	var g := 0
	while fishing.state != FishingController.State.READY and fishing.state != FishingController.State.STOWED and g < 600:
		await _frames(1)
		g += 1


# =====================================================================================
#  Moving about and pressing E
# =====================================================================================

func _villager(node_name: String) -> Villager:
	return main.get_node("Villagers/" + node_name) as Villager


func _talk(villager: Villager) -> PackedStringArray:
	var lines: PackedStringArray = []
	var spot := villager.get_node("TalkSpot") as Interactable
	if not await _use(spot, false):
		return lines
	var g := 0
	while villager.get_mode() == Villager.Mode.TALKING and g < 40:
		lines.append(villager.get_bubble_text())
		await _press(&"interact")
		await _frames(2)
		g += 1
	if villager.get_mode() == Villager.Mode.TALKING:
		_fail("a conversation with %s never ended" % villager.name)
	await _settle()
	return lines


func _use_path(path: String, settle: bool = true) -> bool:
	var target := main.get_node_or_null(path) as Interactable
	if target == null:
		return _fail("missing node %s" % path)
	return await _use(target, settle)


## Walks up to an interactable, checks it is the one in focus, and presses E.
func _use(target: Interactable, settle: bool = true) -> bool:
	# (The cottage's rooms are only drawn while you're inside, so skip the visibility test there.)
	var indoors := target.global_position.y > 150.0
	if not target.enabled or (not indoors and not target.is_visible_in_tree()):
		return _fail("%s isn't available (enabled=%s, visible=%s; last notice: %s)" % [main.get_path_to(target), target.enabled, target.is_visible_in_tree(), _last_notice])
	if not await _go_to(target):
		return false
	var notices_before := _notices.size()
	await _press(&"interact")
	if settle:
		await _settle()
	if player.is_sitting():
		await _press(&"interact")
		await _settle()
	if _notices.size() > notices_before:
		var said := _notices[_notices.size() - 1]
		if said.contains("need") or said.contains("first") or said.contains("full"):
			notes.append("Day %d: at %s the game said: \"%s\"" % [ActivityClock.get_day(), target.name, said])
	return true


func _settle() -> void:
	var g := 0
	while (player.is_input_locked() or player.is_sitting()) and g < 1800 and not (shop and shop.is_open()):
		await _frames(1)
		g += 1
	await _frames(3)


func _go_to(target: Interactable) -> bool:
	var inside_target := target.global_position.y > 150.0
	if inside_target != _inside():
		var door_path := "Island/Buildings/Cottage/FrontDoor" if inside_target else "Island/Buildings/Cottage/Interior/ExitDoor"
		var door := main.get_node(door_path) as Interactable
		if not await _approach(door, false):
			return false
		await _press(&"interact")
		await _settle()
		if _inside() != inside_target:
			return _fail("the cottage door didn't take you %s" % ("in" if inside_target else "out"))
	return await _approach(target, inside_target)


func _inside() -> bool:
	return player.global_position.y > 150.0


## Stands next to `target`, on a spot reachable on foot, with `target` in focus.
func _approach(target: Interactable, _indoors_hint: bool) -> bool:
	var indoors := target.global_position.y > 150.0
	if not indoors:
		await _ensure_walkmap()
	var center := target.global_position
	var space := main.get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	var tried := 0
	var reachable_spot := false
	for radius: float in [0.9, 1.4, 2.0, 2.7]:
		for k in 12:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 12.0)
			var p := center + dir * radius
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, center.y + 1.2, p.z), Vector3(p.x, center.y - 4.0, p.z), 1, exclude))
			if hit.is_empty() or (hit.normal as Vector3).y < 0.66:
				continue
			var floor_point: Vector3 = hit.position
			if WaterBody.deepest_at(get_tree(), floor_point) > 1.0:
				continue
			if not indoors and not walk.is_reachable(floor_point, 1.5):
				continue
			reachable_spot = true
			if not _fits(space, floor_point, exclude):
				continue
			tried += 1
			var to := center - floor_point
			player.teleport_to(floor_point + Vector3.UP * 0.05, atan2(-to.x, -to.z))
			stats.teleports += 1
			await _frames(4)
			if reach.get_current() == target:
				return true
			if tried >= 10:
				break
		if tried >= 10:
			break
	if not reachable_spot:
		return _fail("SOFT-LOCK? %s at %s can't be reached on foot right now" % [main.get_path_to(target), _v(center)])
	return _fail("couldn't get %s in focus (in focus instead: %s)" % [main.get_path_to(target), main.get_path_to(reach.get_current()) if reach.get_current() else "nothing"])


func _go_to_point(point: Vector3, yaw: float) -> bool:
	if _inside():
		var door := main.get_node("Island/Buildings/Cottage/Interior/ExitDoor") as Interactable
		await _approach(door, true)
		await _press(&"interact")
		await _settle()
	await _ensure_walkmap()
	if not walk.is_reachable(point, 1.5):
		return _fail("SOFT-LOCK? the spot %s can't be reached on foot" % _v(point))
	player.teleport_to(point + Vector3.UP * 0.05, yaw)
	stats.teleports += 1
	await _frames(6)
	return true


func _fits(space: PhysicsDirectSpaceState3D, floor_point: Vector3, exclude: Array[RID]) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), floor_point + Vector3.UP * 1.05)
	query.collision_mask = 1
	query.exclude = exclude
	return space.intersect_shape(query, 1).is_empty()


## Rebuilds the walk map when the story has opened (or closed) a way.
func _ensure_walkmap() -> void:
	var key := ""
	for flag: String in GameManager.flags_to_dict().get("flags", []):
		var f := flag
		if f.begins_with("restored_") or f.begins_with("ch1_") or f.begins_with("ch2_") or f.begins_with("ch4_") or f == "lighthouse_lit":
			key += f + ","
	if key == _walk_key and walk != null:
		return
	await _frames(3)
	_walk_key = key
	walk = WalkMap.new()
	var links := []
	var places := main.get_node("Island/StoryPlaces/Lake")
	if GameManager.has_flag(&"lighthouse_lit"):
		links.append([(places.get_node("RowToIsle") as Node3D).global_position, (places.get_node("IsleLanding") as Node3D).global_position])
	links.append([(places.get_node("IsleDock/RowBack") as Node3D).global_position, (places.get_node("DockLanding") as Node3D).global_position])
	var t0 := Time.get_ticks_msec()
	var exclude: Array[RID] = [player.get_rid()]
	walk.build(main.get_world_3d().direct_space_state, get_tree(), exclude, start_point, links)
	stats.walk_maps += 1
	print("  [walk map: %d m² reachable on foot, %.1f s, story: %s]" % [walk.reached_cells, (Time.get_ticks_msec() - t0) / 1000.0, key])


# =====================================================================================
#  Save, quit and continue
# =====================================================================================

func _save_quit_continue() -> void:
	var flags := GameManager.flags_to_dict()
	var money := InventoryManager.get_money()
	var items := InventoryManager.get_all()
	var day := ActivityClock.total_minutes
	var quests := QuestLog.save_state()
	_expect(SaveManager.save_game("manual"), "the game saves")
	main.queue_free()
	await _frames(5)
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	for service in [Friendship, Journal]:
		if service.has_method(&"reset"):
			service.call(&"reset")
	_expect(SaveManager.load_into_game(SaveManager.read_latest()), "Continue reads the save")
	await _load_main(false)
	_expect(GameManager.flags_to_dict() == flags and InventoryManager.get_money() == money and InventoryManager.get_all() == items and ActivityClock.total_minutes == day,
			"after Continue: story flags, coins, bag and clock are exactly as saved")
	_expect(QuestLog.save_state() == quests, "after Continue: the quest log is exactly as saved")
	_walk_key = "?"
	_log("Saved, quit and continued")


func _load_main(new_game: bool) -> void:
	if new_game:
		OpeningScene.request()
	main = MAIN_SCENE.instantiate() as Node3D
	add_child(main)
	await _frames(8)
	player = main.get_node("Player") as PlayerController
	reach = player.find_children("*", "PlayerInteraction", true, false)[0] as PlayerInteraction
	fishing = get_tree().get_first_node_in_group(&"fishing_controller") as FishingController
	farming = main.find_children("*", "FarmingController", true, false)[0] as FarmingController
	shop = get_tree().get_first_node_in_group(&"shop_panel") as ShopPanel
	fishing.reel_updated.connect(func(tension: float, _p: float, _s: bool) -> void: _tension_hist.append(tension))
	fishing.cast_power_changed.connect(func(power: float) -> void: _power = power)
	fishing.catch_finished.connect(func(_f: FishData, _s: float, _i: Dictionary) -> void: _caught_flag = true)
	if not new_game:
		start_point = player.global_position


# =====================================================================================
#  Input, frames, logging
# =====================================================================================

func _press(action: StringName) -> void:
	await _hold(action, true)
	await _hold(action, false)


func _hold(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> bool:
	if condition:
		print("  ok   " + label)
		return true
	return _fail(label + "  [quests: %s]" % _quest_state())


func _fail(text: String) -> bool:
	var line := "Day %d %s — %s" % [ActivityClock.get_day(), ActivityClock.get_time_string(), text]
	problems.append(line)
	print("  FAIL " + line)
	if problems.size() >= 12 and not _stopped:
		_stopped = true
		print("Too many problems; stopping the playthrough here.")
		_report()
		SaveManager.delete_save()
		get_tree().quit(1)
	return false


func _log(text: String) -> void:
	var line := "Day %2d %8s  %4d coins  %s" % [ActivityClock.get_day(), ActivityClock.get_time_string(), InventoryManager.get_money(), text]
	timeline.append(line)
	print("  >>   " + line)


func _quest_state() -> String:
	var parts: PackedStringArray = []
	for quest in QuestLog.get_active_quests():
		var step := QuestLog.get_current_step(quest.id)
		parts.append("%s: \"%s\"" % [quest.id, step.text if step else "?"])
	return "; ".join(parts)


func _v(p: Vector3) -> String:
	return "(%.0f, %.0f, %.0f)" % [p.x, p.y, p.z]


func _report() -> void:
	print("\n================ PLAYTHROUGH REPORT ================")
	print("Real time: %.1f min. In-game: Day %d %s (%s)." % [(Time.get_ticks_msec() - _started_ms) / 60000.0, ActivityClock.get_day(), ActivityClock.get_time_string(), ActivityClock.get_season_name()])
	print("\nTIMELINE")
	for line in timeline:
		print("  " + line)
	print("\nTIME SPENT (in-game hours by activity)")
	for activity in minutes_by_activity:
		print("  %-14s %6.1f h" % [activity, minutes_by_activity[activity] / 60.0])
	print("\nECONOMY")
	print("  coins earned selling: %d, spent buying: %d, spent on upgrades: %d, purse now: %d" % [stats.earned_selling, stats.spent_buying, stats.spent_upgrades, InventoryManager.get_money()])
	print("  upgrades bought: %s" % ", ".join(stats.upgrades))
	print("  bought: %s" % stats.bought)
	print("  gathered: %s" % stats.gathered)
	print("\nFISHING")
	print("  casts %d, caught %d, lost in the fight %d, no bite %d, dry casts %d" % [stats.casts, stats.caught, stats.lost, stats.no_bite, stats.dry_casts])
	print("  caught: %s" % stats.by_fish)
	print("  got away: %s" % stats.lost_by_fish)
	print("\nOTHER: slept %d times, %d walk maps built, %d walks" % [stats.sleeps, stats.walk_maps, stats.teleports])
	if not notes.is_empty():
		print("\nNOTES (things the game told the player)")
		for line in notes:
			print("  " + line)
	print("\nPROBLEMS: %d" % problems.size())
	for line in problems:
		print("  ✗ " + line)
	print("RESULT: %s" % ("STORY COMPLETE, no problems" if problems.is_empty() and _credits_seen else ("story complete, with problems" if _credits_seen else "STORY NOT FINISHED")))
