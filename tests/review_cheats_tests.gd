extends RefCounted

func run(t: Node) -> void:
	print("== Review cheats ==")
	ReviewCheats.leave_review()
	TitleScreen.reset_game_state()
	var original := SaveManager.save_path
	var main := preload("res://scenes/main/main.tscn").instantiate()
	t.add_child(main)
	await t._frames(5)
	var panel := main.get_node("ReviewPanel") as ReviewPanel
	panel.open()
	t.check(panel._root.visible and t.get_tree().paused, "F8 review panel pauses the world")
	t.check(panel.get_viewport().gui_get_focus_owner() == panel._first, "review menu has keyboard focus")
	t.check(not ReviewCheats.is_active(), "opening the menu alone does not branch or alter progress")
	var before_coins := InventoryManager.get_money()
	ReviewCheats.money()
	t.check(ReviewCheats.is_active() and SaveManager.save_path != original, "first cheat switches to isolated review save")
	var normal_bytes := FileAccess.get_file_as_string(original)
	var normal_data: Dictionary = JSON.parse_string(normal_bytes)
	t.check(int(normal_data.inventory.money) == before_coins and InventoryManager.get_money() == before_coins + 10000, "normal progress is saved before money cheat")
	ReviewCheats.prepare_fields(t.get_tree())
	ReviewCheats.ready_crops(t.get_tree())
	var ready := true
	for plot: FarmPlot in t.get_tree().get_nodes_in_group(&"farm_plot"):
		ready = ready and plot.is_ready()
	for field: CropField in t.get_tree().get_nodes_in_group(&"crop_fields"):
		for i in field.get_row_count(): ready = ready and field.get_row_state(i) == CropField.RowState.RIPE
	t.check(ready, "garden and large-field review crops become harvest-ready")
	ReviewCheats.chapter(5)
	t.check(QuestLog.is_active(&"finale_lens") and GameManager.has_flag(&"journal_page_9") and GameManager.has_flag(&"ch4_rockfall_cleared"), "chapter shortcut opens coast and finale in order")
	t.check(InventoryManager.get_count(&"glowstone_shard") == 5, "skipped shard pickups supply five physical Glowstones")
	ReviewCheats.chapter(5)
	t.check(InventoryManager.get_count(&"glowstone_shard") == 5, "repeating chapter shortcut does not duplicate rewards")
	ReviewCheats.restore_tractor()
	t.check(GameManager.has_flag(&"restored_tractor"), "tractor can be enabled for review")
	var old_weather := WeatherManager.auto_change
	ReviewCheats.weather(WeatherManager.Weather.RAIN)
	t.check(WeatherManager.current == WeatherManager.Weather.RAIN and not WeatherManager.auto_change, "weather cheat applies and holds selected weather")
	var minutes := ActivityClock.total_minutes
	ReviewCheats.advance(60)
	t.check(ActivityClock.total_minutes == minutes + 60, "time shortcut advances through the activity clock")
	t.check(SaveManager.save_game("review_test") and FileAccess.get_file_as_string(original) == normal_bytes, "review autosaves leave normal save byte-for-byte unchanged")
	panel.close()
	t.check(not t.get_tree().paused, "closing standalone review panel resumes play")
	var pause := main.get_node("PauseMenu") as PauseMenu
	pause.open()
	panel.open()
	t.check(panel._root.visible and not pause.is_open(), "review menu replaces pause modal without overlapping keyboard focus")
	panel.close()
	var player := main.get_node("Player") as PlayerController
	player.set_input_locked(true)
	panel.open()
	t.check(not panel._root.visible, "review menu refuses to interrupt an active interaction")
	player.set_input_locked(false)
	ReviewCheats.leave_review()
	t.check(SaveManager.save_path == original and WeatherManager.auto_change == old_weather, "leaving review restores normal slot and automatic weather preference")
	main.queue_free()
	await t._frames(3)
	TitleScreen.reset_game_state()
