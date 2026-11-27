class_name ReviewCheats
extends RefCounted
## Temporary development tools. Every mutation first branches the current save.
static var original_path := ""
static var _original_auto_weather := true

static func is_active() -> bool:
	return not original_path.is_empty()

static func begin() -> bool:
	if is_active(): return true
	if not SaveManager.save_game("before_review"):
		GameManager.notify("Could not save your progress. Review cheats were not enabled.")
		return false
	_original_auto_weather = WeatherManager.auto_change
	original_path = SaveManager.save_path
	SaveManager.save_path = original_path.get_basename() + ".review.json"
	return true

## Called on the title screen, after the island and its autosave session have ended.
static func leave_review() -> void:
	if is_active():
		SaveManager.save_path = original_path
		original_path = ""
		WeatherManager.auto_change = _original_auto_weather

static func give_item(id: StringName, amount: int = 20) -> String:
	if not begin(): return "Save failed; no changes made."
	var added := InventoryManager.add_item(id, amount)
	return "Added %d %s%s" % [added, ItemDB.get_display_name(id), " (bag full)" if added < amount else ""]

static func money() -> String:
	if not begin(): return "Save failed; no changes made."
	InventoryManager.add_money(10000)
	return "Added 10,000 coins."

static func tools() -> String:
	if not begin(): return "Save failed; no changes made."
	GameManager.set_flag(&"has_fishing_rod")
	var missed := 0
	for id in [&"watering_can", &"hoe", &"axe", &"scythe", &"plough", &"seed_drill", &"harvester", &"turnip_seeds", &"wheat_seed", &"rice_seedlings", &"corn_seed"]:
		if InventoryManager.has_item(id): continue
		if InventoryManager.add_item(id, 1 if not String(id).contains("seed") else 10) == 0: missed += 1
	return "Tools and seeds supplied." if missed == 0 else "Some supplies did not fit. Sell items or expand your bag, then try again."

static func restore_tractor() -> String:
	if not begin(): return "Save failed; no changes made."
	GameManager.set_flag(&"restored_tractor")
	return "Tractor repaired. Use Tools + seeds for implements, then Travel → Tractor."

static func advance(minutes: int) -> String:
	if not begin(): return "Save failed; no changes made."
	ActivityClock.advance_minutes(minutes, &"review")
	return ActivityClock.get_date_string() + " · " + ActivityClock.get_time_string()

static func weather(value: int) -> String:
	if not begin(): return "Save failed; no changes made."
	WeatherManager.auto_change = false
	WeatherManager.set_weather(value)
	return "Weather changed (automatic changes disabled for this review)."

static func ready_crops(tree: SceneTree) -> String:
	if not begin(): return "Save failed; no changes made."
	var count := 0
	for plot: FarmPlot in tree.get_nodes_in_group(&"farm_plot"):
		if plot.has_crop():
			plot.growth_minutes = plot.get_crop().get_grow_minutes()
			plot._changed()
			count += 1
	for field: CropField in tree.get_nodes_in_group(&"crop_fields"):
		var data := field.save_state()
		for row in data.rows:
			if int(row.state) == CropField.RowState.GROWING:
				row.state = CropField.RowState.RIPE
				row.grown = field.crop.grow_days
				count += 1
		field._coverage.clear()
		field.load_state(data)
	return "%d planted beds/rows ready. Drain rice before harvesting." % count

static func prepare_fields(tree: SceneTree) -> String:
	if not begin(): return "Save failed; no changes made."
	for plot: FarmPlot in tree.get_nodes_in_group(&"farm_plot"):
		if not plot.has_crop():
			plot.dig()
			plot.plant(CropCatalog.shared().get_crop(&"turnip"))
		plot.water()
	for field: CropField in tree.get_nodes_in_group(&"crop_fields"):
		var data := field.save_state()
		data.flooded = field.needs_water()
		for row in data.rows:
			if int(row.state) in [CropField.RowState.EMPTY, CropField.RowState.TILLED]:
				row.state = CropField.RowState.GROWING
				row.grown = 0
		field._coverage.clear()
		field.load_state(data)
	return "Empty garden beds and field rows planted. Existing crops kept."

## Deliberately bypasses objectives only in the isolated review save. Normal quest
## completion still grants rewards, emits signals, and starts dependent quests.
static func finish_quest(id: StringName) -> String:
	if not begin(): return "Save failed; no changes made."
	var quest := QuestLog.get_quest(id)
	if quest == null or QuestLog.is_done(id): return "Quest already completed or unavailable."
	QuestLog.start_quest(id)
	for step in quest.steps:
		if step.kind == QuestStep.Kind.FLAG:
			if String(step.target).begins_with("shard_") and not GameManager.has_flag(step.target):
				InventoryManager.add_item(&"glowstone_shard")
			GameManager.set_flag(step.target)
	if not QuestLog.is_done(id):
		QuestLog._state[id]["step"] = quest.steps.size()
		QuestLog._complete(quest)
	return "Completed: " + quest.title

static func chapter(index: int) -> String:
	if not begin(): return "Save failed; no changes made."
	var groups := [
		[&"arrival", &"neighbours", &"grandpas_garden", &"fishing_lessons"],
		[&"seeds_of_spring"], [&"carpenters_bridge"],
		[&"market_ledger", &"market_day", &"well_light"],
		[&"keepers_light", &"finale_page9"]]
	for i in mini(index, groups.size()):
		for id in groups[i]: finish_quest(id)
	GameManager.set_flag(&"has_fishing_rod")
	if index >= 2: GameManager.set_flag(&"met_theo")
	if index >= 3: GameManager.set_flag(&"met_ambrose")
	if index >= 4: GameManager.set_flag(&"met_luna")
	return "Unlocked chapter %d. Earlier progress is kept; use Travel below." % index if index < 5 else "Finale ready. Visit the lighthouse to repair the lens."
