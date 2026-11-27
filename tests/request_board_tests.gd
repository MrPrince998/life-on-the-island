extends RefCounted
## Checks for the village notice board's daily requests (RequestBoard). Called from
## test_runner.gd:
##   await preload("res://tests/request_board_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Notice board requests ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	QuestLog.reset()
	RequestBoard.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var spot := main.get_node("Island/StoryPlaces/Village/Mailbox/Requests") as NoticeBoardSpot
	var panel := main.get_node("RequestBoardPanel") as RequestBoardPanel
	var tracker := main.get_node("HUD").get_node("%QuestTracker") as QuestTracker

	# Before you know anyone, the board is bare.
	t.check(RequestBoard.get_requests().is_empty() and not spot.has_marker() and RequestBoard.get_empty_reason().contains("Say hello"), "before you've met anyone the board is bare, with a hint to say hello")

	# Meeting villagers: they pin up requests.
	for id in [&"emma", &"oliver", &"mia"]:
		GameManager.set_flag(StringName("met_" + String(id)))
	var requests := RequestBoard.get_requests()
	var givers := {}
	for request in requests:
		givers[str(request["giver"])] = true
	t.check(requests.size() == RequestBoard.SLOTS and givers.size() == requests.size(), "after meeting Emma, Oliver and Mia, three requests go up, one from each")
	t.check(spot.has_marker() and spot.get_prompt().contains("3 requests"), "a \"!\" over the mailbox says something new is up (\"Check village requests (3 requests)\")")
	var sensible := true
	for request in requests:
		var item_id := StringName(str(request["item"]))
		var price := ItemDB.get_item(item_id).sell_price
		var crop := _crop_for(item_id)
		sensible = sensible and ItemDB.has_item(item_id) and int(request["amount"]) >= 1 \
			and int(request["coins"]) > price * int(request["amount"]) and str(request["text"]).contains(_name_of(str(request["giver"]))) \
			and (crop == null or crop.grows_in(ActivityClock.get_season_id()))
	t.check(sensible, "each request names the villager, asks for something you can get this season, and pays better than selling it")

	# Reading the board.
	var clock := ActivityClock.total_minutes
	spot.interact(player)
	t.check(panel.is_open() and player.is_input_locked() and panel.get_card_ids().size() == 3, "pressing E opens the board with a card for each request")
	await t._frames(2)
	t.check(not spot.has_marker(), "once read, the \"!\" goes away")

	# Taking a request.
	var first: Dictionary = requests[0]
	var first_id := StringName(str(first["id"]))
	var taken := panel.take(first_id)
	var quest: QuestData = taken.get("quest")
	t.check(taken.get("ok", false) and quest != null and QuestLog.is_active(quest.id) and panel.get_card_ids().size() == 2, "taking a request starts it as a quest and takes it off the board")
	t.check(panel.get_note().contains("help " + quest.giver), "the board says who you promised to help")
	panel.close()
	await t._frames(3)
	t.check(not panel.is_open() and not player.is_input_locked(), "closing the board lets the player walk again")
	t.check(ActivityClock.total_minutes == clock, "reading the board and taking a request cost no time")
	var on_tracker := false
	for line: Variant in tracker.get_lines():
		on_tracker = on_tracker or str(line).contains(quest.title)
	t.check(on_tracker, "the request shows in the quest list (\"%s\")" % quest.title)
	t.check(RequestBoard.get_requests().size() == 2, "its spot stays empty until tomorrow (no endless requests in one day)")

	# Handing it over.
	var villager := _villager(main, quest.giver_id)
	var item_id := StringName(str(first["item"]))
	var amount := int(first["amount"])
	t.check(villager != null and villager.get_quest_marker() == "", "no \"?\" until you have everything")
	InventoryManager.add_item(item_id, amount)
	t.check(villager.get_quest_marker() == "?", "with the things in your bag, a \"?\" shows %s is waiting" % quest.giver)
	var coins := InventoryManager.get_money()
	var points := Friendship.get_points(quest.giver_id)
	villager.talk(player)
	var thanks := villager.get_bubble_text()
	villager.end_conversation()
	await t._frames(2)
	t.check(QuestLog.is_done(quest.id) and InventoryManager.get_count(item_id) == 0 and thanks == str(first["thanks"]), "talking to %s hands it over and they thank you" % quest.giver)
	t.check(InventoryManager.get_money() == coins + int(first["coins"]) and Friendship.get_points(quest.giver_id) >= points + RequestBoard.FRIENDSHIP_POINTS, "the reward: %d coins and friendship" % int(first["coins"]))
	t.check(RequestBoard.completed == 1, "the board counts finished requests")

	# Helping with up to three at once.
	var second := RequestBoard.get_requests()
	t.check(RequestBoard.accept(StringName(str(second[0]["id"])))["ok"] and RequestBoard.accept(StringName(str(second[1]["id"])))["ok"], "you can take more requests")
	GameManager.set_flag(&"met_theo")
	GameManager.set_flag(&"met_nana_bea")
	GameManager.set_flag(&"met_pip")

	# A new morning.
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) + 24 * 60, &"test")
	await t._frames(2)
	var morning := RequestBoard.get_requests()
	t.check(morning.size() == RequestBoard.SLOTS and RequestBoard.has_news() and spot.has_marker(), "next morning new requests fill the board, and the \"!\" is back")
	t.check(RequestBoard.get_morning_note().contains("mailbox"), "the wake-up message mentions the new requests")
	t.check(QuestLog.get_quest(quest.id) == null, "yesterday's finished request is tidied away")
	var taken_givers := {}
	for active in RequestBoard.get_active():
		taken_givers[active.giver_id] = true
	var no_double := true
	for request in morning:
		no_double = no_double and not taken_givers.has(StringName(str(request["giver"])))
	t.check(no_double, "nobody pins a second request while you're helping them with one")
	t.check(RequestBoard.accept(StringName(str(morning[0]["id"])))["ok"], "a third request can be taken")
	var refused := RequestBoard.accept(StringName(str(morning[1]["id"])))
	t.check(not refused["ok"] and str(refused["reason"]).contains("already helping"), "a fourth is kindly refused until one is finished")

	# Save and load (JSON), mid-request.
	var saved_quests: Dictionary = JSON.parse_string(JSON.stringify(QuestLog.save_state()))
	var saved_board: Dictionary = JSON.parse_string(JSON.stringify(RequestBoard.save_state()))
	var active_ids: Array[StringName] = []
	for active in RequestBoard.get_active():
		active_ids.append(active.id)
	var board_ids := RequestBoard.get_requests().map(func(r: Dictionary) -> String: return str(r["id"]))
	QuestLog.reset()
	RequestBoard.reset()
	QuestLog.load_state(saved_quests)
	RequestBoard.load_state(saved_board)
	var restored: Array[StringName] = []
	for active in RequestBoard.get_active():
		restored.append(active.id)
	var restored_quest := QuestLog.get_quest(active_ids[0])
	t.check(restored == active_ids and restored_quest != null and QuestLog.get_current_step(active_ids[0]).kind == QuestStep.Kind.DELIVER, "requests you're helping with survive save and load (%d)" % restored.size())
	t.check(RequestBoard.get_requests().map(func(r: Dictionary) -> String: return str(r["id"])) == board_ids and RequestBoard.completed == 1, "the board itself survives save and load")

	# Untaken requests are quietly replaced after a few days.
	var waiting_id := str(RequestBoard.get_requests()[0]["id"])
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) + 24 * 60 * RequestBoard.STAY_DAYS, &"test")
	await t._frames(2)
	var still_there := RequestBoard.get_requests().any(func(r: Dictionary) -> bool: return str(r["id"]) == waiting_id)
	t.check(not still_there and not RequestBoard.get_requests().is_empty(), "a request nobody takes is replaced by a new one after %d days" % RequestBoard.STAY_DAYS)
	t.check(RequestBoard.get_active().size() == 3, "requests you took never run out of time")

	# Only in-season things: in winter nobody asks for summer crops.
	QuestLog.reset()
	RequestBoard.reset()
	ActivityClock.from_dict({"total_minutes": (ActivityClock.DAYS_PER_SEASON * 3) * 24 * 60 + 6 * 60})
	var winter_ok := ActivityClock.get_season_id() == &"winter"
	for round in 6:
		ActivityClock.advance_minutes(24 * 60, &"test")
		for request in RequestBoard.get_requests():
			var crop := _crop_for(StringName(str(request["item"])))
			winter_ok = winter_ok and (crop == null or crop.grows_in(&"winter"))
	t.check(winter_ok, "in winter, crop requests are only for winter crops")
	t.check(RequestBoard.amount_text(&"carrot", 3) == "3 Carrots" and RequestBoard.amount_text(&"pumpkin", 1) == "a Pumpkin" and RequestBoard.amount_text(&"tomato", 2) == "2 Tomatoes" and RequestBoard.amount_text(&"wood", 6) == "6 Wood" \
		and RequestBoard.amount_text(&"turnip_soup", 1) == "a bowl of Turnip Soup" and RequestBoard.amount_text(&"roasted_carrots", 2) == "2 plates of Roasted Carrots", "requests read naturally (3 Carrots, a Pumpkin, 2 Tomatoes, 6 Wood, a bowl of Turnip Soup)")

	GameManager.reset_flags()
	QuestLog.reset()
	RequestBoard.reset()
	Friendship.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


func _crop_for(item_id: StringName) -> CropData:
	for crop in CropCatalog.shared().crops:
		if crop.harvest_item_id == item_id:
			return crop
	return null


func _name_of(npc_id: String) -> String:
	var npc := load("res://data/npcs/%s.tres" % npc_id) as NPCData
	return npc.display_name if npc else npc_id


func _villager(main: Node, npc_id: StringName) -> Villager:
	for child in main.get_node("Villagers").get_children():
		if child is Villager and (child as Villager).data and (child as Villager).data.id == npc_id:
			return child
	return null
