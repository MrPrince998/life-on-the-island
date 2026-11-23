extends RefCounted
## Checks for the interface sounds (autoload UISounds). Called from test_runner.gd:
##   await preload("res://tests/ui_sound_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Interface sounds ==")
	var ui := t.get_node_or_null("/root/UISounds")
	t.check(ui != null, "interface sounds are always on hand (UISounds)")
	if ui == null:
		return
	var missing: Array[StringName] = []
	for s: StringName in ui.SOUNDS:
		if not ResourceLoader.exists(ui.DIR + String(s) + ".wav"):
			missing.append(s)
	t.check(missing.is_empty(), "all %d interface sounds exist %s" % [ui.SOUNDS.size(), str(missing) if missing else ""])
	var heard: Array[StringName] = []
	var listen := func(s: StringName) -> void: heard.append(s)
	ui.played.connect(listen)

	# Buttons, found by themselves: no sound code in the menus.
	var box := VBoxContainer.new()
	t.add_child(box)
	var ok_button := Button.new()
	ok_button.text = "Buy"
	var back_button := Button.new()
	back_button.text = "Back"
	var locked := Button.new()
	locked.text = "Restore"
	locked.disabled = true
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	for c: Control in [ok_button, back_button, locked, slider]:
		box.add_child(c)
	await _idle(t)
	ok_button.pressed.emit()
	back_button.pressed.emit()
	t.check(heard.size() >= 2 and heard[-2] == &"click" and heard[-1] == &"back", "buttons click; Back gets a softer, lower click")
	ok_button.mouse_entered.emit()
	t.check(heard[-1] == &"hover", "pointing at a button ticks")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	locked.gui_input.emit(press)
	t.check(heard[-1] == &"deny", "a button you can't use yet gives a muted bonk")
	heard.clear()
	slider.value = 0.5
	t.check(heard.is_empty(), "a slider set by a screen refreshing stays quiet")
	slider.grab_focus()
	slider.value = 0.8
	t.check(heard == [&"slider"], "moving a slider ticks")
	box.remove_child(ok_button)
	box.add_child(ok_button)
	await t._frames(1)
	var wait_ms := Time.get_ticks_msec() + 60
	while Time.get_ticks_msec() < wait_ms:
		await t._frames(1)
	heard.clear()
	ok_button.pressed.emit()
	t.check(heard == [&"click"], "a button moved to a new place still clicks once")
	box.queue_free()

	# The island: panels, money, quests, friendship and dialogue.
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	var autosave_was: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	heard.clear()
	InventoryManager.add_money(5)
	t.check(not (&"coin_gain" in heard), "loading the island doesn't jingle the money")
	var until := Time.get_ticks_msec() + 1700  # past the quiet moment after loading
	while Time.get_ticks_msec() < until:
		await t._frames(1)
	var minutes := ActivityClock.total_minutes
	heard.clear()
	var journal := main.get_node("JournalPanel") as JournalPanel
	journal.open()
	await _idle(t)
	t.check(&"book_open" in heard, "the journal opens like a book")
	var tab := journal.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.toggle_mode)
	heard.clear()
	if not tab.is_empty():
		(tab[tab.size() - 1] as Button).pressed.emit()
	t.check(heard == [&"page"], "its tabs turn the page")
	journal.close()
	await _idle(t)
	t.check(&"book_close" in heard, "and it shuts like a book")
	var pause := main.get_node("PauseMenu") as PauseMenu
	heard.clear()
	pause.open()
	await _idle(t)
	pause.resume()
	await _idle(t)
	t.check(&"open" in heard and &"close" in heard, "other panels (the pause menu) open and close with a chime")

	heard.clear()
	InventoryManager.add_money(30)
	await t._frames(10)
	InventoryManager.spend_money(10)
	t.check(&"coin_gain" in heard and &"coin_spend" in heard, "coins jingle in when you sell and clink out when you buy")
	heard.clear()
	var quest := load("res://data/quests/arrival.tres") as QuestData
	QuestLog.quest_announced.emit(quest)
	await _idle(t)
	QuestLog.step_completed.emit(quest, 0)
	await _idle(t)
	QuestLog.step_completed.emit(quest, 0)
	QuestLog.quest_completed.emit(quest)
	await _idle(t)
	t.check(heard == [&"quest_new", &"quest_step", &"quest_done"], "quests: a chime to begin, one per step, a fanfare to finish (%s)" % str(heard))
	heard.clear()
	Friendship.heart_gained.emit(&"test_friend", 1)
	t.check(&"heart" in heard, "a new friendship heart chimes")
	until = Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < until:
		await t._frames(1)
	heard.clear()
	GameManager.notify("A message")
	t.check(&"notify" in heard, "messages arrive with a soft blip")
	var villager := t.get_tree().get_first_node_in_group(&"villagers") as Villager
	heard.clear()
	if villager:
		villager.line_shown.emit("Mia", "Hello there!")
	t.check(&"talk" in heard, "each line a villager says comes with a hummed \"mm\"")
	t.check(ActivityClock.total_minutes == minutes, "interface sounds never move the clock")

	ui.played.disconnect(listen)
	main.queue_free()
	await t._frames(3)
	SaveManager.autosave_enabled = autosave_was
	InventoryManager.reset()
	ActivityClock.reset()
	GameManager.reset_flags()


## Waits two ordinary (not physics) frames: panels and quest chimes are checked once a frame.
func _idle(t: Node) -> void:
	for i in 2:
		await t.get_tree().process_frame
