extends RefCounted
## Checks for daily shipping orders (ShippingYard) and carrying crates / pushing the
## hand-cart (PlayerCarry).
## Called from test_runner.gd:  await preload("res://tests/shipping_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Shipping orders: crates, the cart and the jetty ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var yard := t.get_tree().get_first_node_in_group(&"shipping_yard") as ShippingYard
	if yard == null:
		t.check(false, "the shipping yard is on the island")
		main.queue_free()
		await t._frames(2)
		return
	var player := main.get_node("Player") as PlayerController
	var carry := PlayerCarry.find(player)
	t.check(carry != null and not carry.is_hands_busy(), "the player can carry things (hands free to start)")

	# Orders.
	t.check(yard.orders.is_empty(), "no orders on the first day")
	ActivityClock.advance_minutes(1440, &"test")  # the next morning
	await t._frames(2)
	var orders_ok := yard.orders.size() == ShippingYard.MAX_OPEN_ORDERS
	for order in yard.orders:
		var value := 0
		for item_id in order.items:
			value += ItemDB.get_item(item_id).sell_price * int(order.items[item_id])
		orders_ok = orders_ok and not (order.items as Dictionary).is_empty() and int(order.reward) > value and str(order.buyer) != ""
	t.check(orders_ok, "from Day 2, three orders each morning, paying more than the store would")

	# Packing.
	var order: Dictionary = yard.orders[0]
	t.check(not yard.can_pack(int(order.id)), "you can't pack an order without the goods")
	for item_id in order.items:
		InventoryManager.add_item(item_id, int(order.items[item_id]))
	var clock := ActivityClock.total_minutes
	var panel := yard.table.open_panel()
	t.check(panel.is_open() and player.is_input_locked(), "the packing table shows the orders")
	var crate := panel.pack(int(order.id))
	panel.close()
	var emptied := true
	for item_id in order.items:
		emptied = emptied and InventoryManager.get_count(item_id) == 0
	t.check(crate != null and crate.location == ShippingCrate.Location.TABLE and emptied and ActivityClock.total_minutes == clock + ShippingYard.PACK_MINUTES and yard.is_packed(int(order.id)), "packing puts the goods in a crate on the table (%d minutes)" % ShippingYard.PACK_MINUTES)
	t.check(yard.pack(int(order.id)) == null, "an order is packed only once")

	# Lifting and carrying.
	player.teleport_to(yard.table.global_position + Vector3(0, 0.2, -1.5), 0.0)
	await t._frames(3)
	clock = ActivityClock.total_minutes
	var lifted: bool = await carry.pick_up(crate)
	await t._frames(2)
	t.check(lifted and carry.is_carrying() and crate.location == ShippingCrate.Location.CARRIED and player.is_hands_busy() and not player.is_input_locked(), "lifting the crate: now you're carrying it")
	t.check(ActivityClock.total_minutes == clock, "carrying uses no time")
	var interaction := player.get_node("InteractionArea") as PlayerInteraction
	var second_lift: bool = await carry.pick_up(crate)
	t.check(not second_lift, "you can't lift a crate while already carrying one")
	t.check(not crate.can_interact_now(player), "(the carried crate isn't a target)")

	# Onto the cart, push it, off again.
	player.teleport_to(yard.cart.get_grip(true) + Vector3(0, 0.2, 0) + (yard.cart.global_basis.z * 0.6), 0.0)
	await t._frames(3)
	var loaded: bool = await carry.put_down_into(yard.cart)
	t.check(loaded and not carry.is_carrying() and yard.cart.get_crates().has(crate) and crate.location == ShippingCrate.Location.CART, "the crate goes onto the hand-cart")
	t.check(carry.grab_cart(yard.cart) and carry.is_pushing() and yard.cart.is_pushed(), "grabbing the cart's handles to push it")
	var before := yard.cart.global_position
	player.teleport_to(player.global_position + (-(player.get_node("Visual") as Node3D).global_basis.z) * 3.0, (player.get_node("Visual") as Node3D).global_rotation.y)
	await t._frames(4)
	t.check(yard.cart.global_position.distance_to(before) > 2.0 and crate.get_parent().get_parent() == yard.cart, "the cart rolls along in front of you, crate and all")
	t.check(interaction.get_current() == null and carry.get_free_prompt() == "Let go of the cart", "while pushing, E lets go of the cart")
	carry.release_cart()
	t.check(not carry.is_pushing() and not yard.cart.is_pushed() and yard.cart.collision_layer == 1, "letting go: the cart stays put and is solid again")

	# Onto the jetty, and Marlow sails at six.
	var picked: bool = await carry.pick_up(crate)
	player.teleport_to(yard.jetty_point(13.5, 0.0, 0.3), 0.0)
	await t._frames(3)
	var on_pad: bool = await carry.put_down_into(yard.pad)
	t.check(picked and on_pad and yard.pad.get_crates().has(crate), "the crate is set on the jetty for Captain Marlow")
	var coins := InventoryManager.get_money()
	var reward := int(order.reward)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(ShippingYard.SAIL_HOUR) + 10, &"test")
	await t._frames(2)
	t.check(InventoryManager.get_money() == coins + reward and yard.pad.get_crates().is_empty() and yard.get_order(int(order.id)).is_empty(), "at 6 PM the boat takes the crate and pays %d coins" % reward)

	# Setting a crate on the ground, and saving it.
	var second: Dictionary = yard.orders[0]
	for item_id in second.items:
		InventoryManager.add_item(item_id, int(second.items[item_id]))
	var crate2 := yard.pack(int(second.id))
	await carry.pick_up(crate2)
	var dropped: bool = await carry.put_down_on_ground()
	t.check(dropped and crate2.location == ShippingCrate.Location.GROUND and crate2.get_node("Body").collision_layer == 1, "a crate can be set down anywhere on the ground")
	var saved := yard.save_state()
	var restored := ShippingYard.new()
	main.get_node("Island/StoryPlaces/Farm").add_child(restored)
	await t._frames(2)
	crate2.queue_free()
	await t._frames(1)
	restored.load_state(saved)
	await t._frames(2)
	var back := restored.get_crates().filter(func(c: ShippingCrate) -> bool: return c.order_id == int(second.id))
	t.check(restored.orders.size() == yard.orders.size() and back.size() == 1 and (back[0] as ShippingCrate).location == ShippingCrate.Location.GROUND, "orders and crates (where they lie) are saved and loaded")
	restored.queue_free()

	# Nothing is lost: an unshipped crate just waits for tomorrow's boat.
	var waiting := yard.orders.size()
	ActivityClock.advance_minutes(1440, &"test")
	t.check(yard.orders.size() >= waiting, "unshipped orders never expire")

	WeatherManager.auto_change = true
	GameManager.reset_flags()
	QuestLog.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)
