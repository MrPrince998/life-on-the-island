extends RefCounted
## Checks for the shipping and notice-board sounds (ActionSounds and UISounds).
## Called from test_runner.gd:  await preload("res://tests/shipping_sound_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const ACTION_FILES := ["crate_lift", "crate_set_wood", "crate_set_soft", "crate_on_cart", "cart_grab", "cart_release", "cart_roll", "cart_roll_wood", "pack_crate"]
const UI_FILES := ["board_open", "board_close", "board_pin", "ship_bell"]

var _heard: Array[StringName] = []


func run(t: Node) -> void:
	print("== Shipping and notice board sounds ==")
	var missing: Array[String] = []
	for f in ACTION_FILES:
		if not ResourceLoader.exists(ActionSounds.DIR + f + ".wav"):
			missing.append(f)
	for f in UI_FILES:
		if not ResourceLoader.exists(UISounds.DIR + f + ".wav"):
			missing.append(f)
	t.check(missing.is_empty(), "all %d shipping and notice board sounds exist %s" % [ACTION_FILES.size() + UI_FILES.size(), str(missing) if missing else ""])

	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	Friendship.reset()
	RequestBoard.reset()
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	var autosave_was: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var sounds := player.get_node("ActionSounds") as ActionSounds
	var carry := PlayerCarry.find(player)
	var yard := t.get_tree().get_first_node_in_group(&"shipping_yard") as ShippingYard
	var ui := t.get_tree().root.get_node("UISounds")
	sounds.played.connect(func(s: StringName) -> void: _heard.append(s))
	ui.played.connect(func(s: StringName) -> void: _heard.append(s))
	if yard == null or carry == null:
		t.check(false, "the shipping yard and the carry helper are there")
		main.queue_free()
		await t._frames(2)
		return

	# Interface sounds stay quiet for a moment after the island loads.
	var wait_until := Time.get_ticks_msec() + UISounds.LOAD_QUIET_MS + 100
	while Time.get_ticks_msec() < wait_until:
		await t.get_tree().process_frame

	# The orders sheet at the packing table, and packing an order.
	ActivityClock.advance_minutes(1440, &"test")
	await _idle(t, 3)
	var order: Dictionary = yard.orders[0]
	for item_id in order.items:
		InventoryManager.add_item(item_id, int(order.items[item_id]))
	_heard.clear()
	var panel := yard.table.open_panel()
	await _idle(t, 3)
	t.check(&"board_open" in _heard and not &"open" in _heard, "the shipping orders rustle open like paper")
	var crate := panel.pack(int(order.id))
	await _idle(t, 2)
	t.check(&"pack_crate" in _heard, "packing an order: twine, the lid and the nails")
	_heard.clear()
	panel.close()
	await _idle(t, 3)
	t.check(&"board_close" in _heard, "and the sheet settles back when you close it")

	# Lifting, loading the cart, pushing it.
	player.teleport_to(yard.table.global_position + Vector3(0, 0.2, -1.5), 0.0)
	await _idle(t, 3)
	_heard.clear()
	await carry.pick_up(crate)
	await _idle(t, 2)
	t.check(_heard.count(&"crate_lift") == 1, "lifting the crate: a scrape and its contents shifting")
	player.teleport_to(yard.cart.get_grip(true) + Vector3(0, 0.2, 0) + (yard.cart.global_basis.z * 0.6), 0.0)
	await _idle(t, 3)
	_heard.clear()
	await carry.put_down_into(yard.cart)
	await _idle(t, 2)
	t.check(_only(&"crate_on_cart"), "loading it onto the cart: a thud and the cart's boards rattling")
	_heard.clear()
	carry.grab_cart(yard.cart)
	await _idle(t, 2)
	t.check(&"cart_grab" in _heard and not sounds.is_cart_rolling(), "taking the handles creaks; standing still, the wheels are quiet")
	var visual := player.get_node("Visual") as Node3D
	for i in 40:
		player.teleport_to(player.global_position - visual.global_basis.z * 0.03, visual.global_rotation.y)
		await t.get_tree().physics_frame
		await t.get_tree().process_frame
	t.check(sounds.is_cart_rolling(), "pushing it, the wheels rumble along")
	for i in 40:
		await t.get_tree().physics_frame
		await t.get_tree().process_frame
	t.check(not sounds.is_cart_rolling(), "and fall quiet when you stop")
	_heard.clear()
	carry.release_cart()
	await _idle(t, 2)
	t.check(_only(&"cart_release"), "letting go: the cart's legs knock down")

	# Onto the jetty pad (planks), and down on the grass.
	await carry.pick_up(crate)
	player.teleport_to(yard.pad.global_position + Vector3(0, 0.3, 0) - yard.pad.global_basis.z * 1.2, 0.0)
	await _idle(t, 3)
	_heard.clear()
	await carry.put_down_into(yard.pad)
	await _idle(t, 2)
	t.check(_only(&"crate_set_wood"), "setting it on the jetty pad: a hollow knock on the planks")
	var second: Dictionary = yard.orders[1]
	for item_id in second.items:
		InventoryManager.add_item(item_id, int(second.items[item_id]))
	var crate2 := yard.pack(int(second.id))
	player.teleport_to(yard.table.global_position + Vector3(0, 0.2, -1.5), 0.0)
	await carry.pick_up(crate2)
	player.teleport_to(yard.table.global_position + Vector3(4, 0.2, -6), 0.0)
	await _idle(t, 3)
	_heard.clear()
	await carry.put_down_on_ground()
	await _idle(t, 2)
	var surface := Footsteps.surface_at(player, crate2.global_position)
	var want := &"crate_set_wood" if surface == &"wood" or surface == &"stone" else &"crate_set_soft"
	t.check(_only(want), "setting it on the ground: %s on %s" % [want, surface])
	await carry.pick_up(crate2)
	await _idle(t, 2)
	_heard.clear()
	carry.drop_everything()
	await _idle(t, 3)
	t.check(not &"crate_set_soft" in _heard and not &"crate_set_wood" in _heard, "(no thud when a crate is let go of by loading a save)")

	# Six o'clock: the boat sails.
	_heard.clear()
	var clock := ActivityClock.total_minutes
	yard.sail_now()
	await _idle(t, 2)
	t.check(&"ship_bell" in _heard, "at six Captain Marlow's ship's bell rings as he sails")

	# The notice board.
	for id in [&"emma", &"oliver", &"mia"]:
		GameManager.set_flag(StringName("met_" + String(id)))
	var board := main.get_node("RequestBoardPanel") as RequestBoardPanel
	_heard.clear()
	board.open()
	await _idle(t, 3)
	t.check(&"board_open" in _heard, "the notice board: the paper lifts and rustles")
	var ids := board.get_card_ids()
	_heard.clear()
	var taken := board.take(ids[0]) if not ids.is_empty() else {}
	await _idle(t, 3)
	t.check(taken.get("ok", false) and &"board_pin" in _heard and not &"quest_new" in _heard, "taking a request pulls its pin (instead of the new-quest chime)")
	_heard.clear()
	board.close()
	await _idle(t, 3)
	t.check(&"board_close" in _heard, "and the board's paper settles when you step away")
	t.check(ActivityClock.total_minutes == clock, "the sounds never move the clock")

	main.queue_free()
	await t._frames(3)
	SaveManager.autosave_enabled = autosave_was
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	RequestBoard.reset()


func _idle(t: Node, n: int) -> void:
	for i in n:
		await t.get_tree().process_frame


## True when the only crate or cart sound heard was `sound` (once).
func _only(sound: StringName) -> bool:
	var shipping: Array[StringName] = []
	for s in _heard:
		if String(s).begins_with("crate_") or String(s).begins_with("cart_"):
			shipping.append(s)
	return shipping.size() == 1 and shipping[0] == sound
