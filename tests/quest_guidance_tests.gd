extends RefCounted

func run(t: Node) -> void:
	GameManager.reset_flags()
	QuestLog.reset()
	var journal := JournalPanel.new()
	t.add_child(journal)
	var minutes := ActivityClock.total_minutes
	t.check(journal.open() and journal.get_tab() == JournalPanel.Tab.QUESTS, "journal opens on quest guidance")
	for i in 6:
		var quest := QuestData.new()
		quest.id = StringName("guidance_test_%d" % i)
		quest.title = "Guidance test %d" % i
		quest.description = "Follow the path to the village well."
		var step := QuestStep.new()
		step.kind = QuestStep.Kind.EVENT
		step.target = &"guidance_test_event"
		step.amount = 2
		step.text = "Collect two supplies"
		quest.steps.append(step)
		QuestLog.add_runtime_quest(quest)
	await t._frames(4)
	t.check(journal.get_entries().size() == QuestLog.get_active_quests().size() and journal.get_entries().size() > 4, "journal includes every active quest beyond HUD limit")
	t.check(journal.get_entries()[0][1].contains("0/2") and journal.get_entries()[0][1].contains("village well"), "quest cards include directions and counted objective")
	QuestLog.record_event(&"guidance_test_event")
	await t._frames(3)
	t.check(journal.get_entries()[0][1].contains("1/2"), "open journal refreshes progress from quest events")
	QuestLog.record_event(&"guidance_test_event")
	await t._frames(3)
	var completed_visible := false
	for entry in journal.get_entries():
		if entry[0].begins_with("Guidance test"): completed_visible = true
	t.check(not completed_visible, "completed quests leave the active list")
	t.check(ActivityClock.total_minutes == minutes, "reviewing quests costs no activity time")
	t.check(journal.get_viewport().gui_get_focus_owner() == journal._tab_buttons[JournalPanel.Tab.QUESTS], "quest tab receives keyboard focus")
	journal.show_tab(JournalPanel.Tab.FISH)
	t.check(not journal.get_entries().is_empty(), "existing collection tabs remain accessible")
	journal.close()
	journal.queue_free()
	await t._frames(2)
	QuestLog.reset()
