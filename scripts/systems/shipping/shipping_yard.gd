class_name ShippingYard
extends Node3D
## Captain Marlow's daily shipping orders, and everything you handle to fill them.
##
## Each morning (from Day 2) up to MAX_OPEN_ORDERS orders are posted: a buyer on the
## mainland wants some crops, fish or goods and pays better than the store. To fill one:
##   1. at the PackingTable by the farm's east gate, pack the order into a crate (the
##      items leave your bag; packing takes PACK_MINUTES of activity time);
##   2. lift the crate (PlayerCarry), carry it or load it onto the HandCart and push the
##      cart down the path to the shipping jetty;
##   3. set the crate on the ShippingPad at the end of the jetty.
## At SAIL_HOUR Captain Marlow's boat takes every crate on the pad and you're paid.
## Orders never expire and nothing is ever lost: crates left anywhere just wait.
## Walking, carrying and pushing never use time (only packing does).
##
## Built in code (positions in world space; this node sits at the origin). Saved by
## SaveManager through the "persistent" group (save key "shipping").

signal orders_changed
signal shipped(crates: int, coins: int)

const SAVE_VERSION := 1
const MAX_OPEN_ORDERS := 3
const FIRST_ORDER_DAY := 2
const PACK_MINUTES := 15
const SAIL_HOUR := 18
## Orders pay this much more than the store would for the same goods.
const PAY_FACTOR := 1.6

const JETTY_SCENE := preload("res://scenes/buildings/beach_jetty.tscn")
const BOAT_MODEL := preload("res://source_assets/tripo/mail_boat.glb")
const CRATE_STACK_MODEL := preload("res://source_assets/tripo/wooden_crate.glb")

## The jetty: where it leaves the beach, its deck height and the way it points out to sea.
const JETTY_ROOT := Vector3(161.0, 1.7, 116.0)
const JETTY_DIRECTION := Vector2(0.7071, 0.7071)
## The packing table, just inside the farm's east gate, and where the cart waits.
const TABLE_POSITION := Vector3(127.6, 0.0, 79.4)
const TABLE_YAW := PI
const CART_POSITION := Vector3(126.0, 0.0, 75.0)
const CART_YAW := -PI * 0.5

const BUYERS: Array[String] = [
	"Bellmere Harbour Market", "The Gull & Lantern Inn", "Captain Marlow's galley",
	"Bellmere School kitchen", "Mrs. Penrose's grocery", "The mainland bakery",
]
## What buyers may ask for, once you can make it: [item, min, max, needs flag].
const WANTED: Array = [
	[&"turnip", 3, 6, &""], [&"carrot", 3, 6, &""], [&"tomato", 3, 6, &""],
	[&"kale", 3, 6, &""], [&"pumpkin", 1, 2, &""], [&"sunflower", 2, 4, &""],
	[&"sea_bream", 2, 5, &""], [&"sunfish", 2, 4, &""], [&"silver_minnow", 3, 6, &""],
	[&"blue_mackerel", 1, 3, &"shard_1"], [&"wooden_plank", 4, 8, &"restored_bridge"],
	[&"stone", 4, 8, &""], [&"grilled_fish", 2, 3, &"restored_market"],
	[&"turnip_soup", 1, 2, &"restored_market"],
]

## Open orders: {"id": int, "buyer": String, "items": {item_id: count}, "reward": int}.
var orders: Array[Dictionary] = []
var _next_id: int = 1
var _rng := RandomNumberGenerator.new()

var table: PackingTable
var cart: HandCart
var pad: ShippingPad
var _crates_root: Node3D
var _boat: Node3D


func _ready() -> void:
	add_to_group(&"persistent")
	add_to_group(&"shipping_yard")
	_build()
	if not Engine.is_editor_hint():
		ActivityClock.day_started.connect(_on_day_started)
		ActivityClock.time_advanced.connect(_on_time_advanced)
		ActivityClock.time_changed.connect(func(_d: int, _m: int) -> void: _update_boat())
		if ActivityClock.get_day() >= FIRST_ORDER_DAY and orders.is_empty():
			_post_orders()
	_update_boat()


# ---- Orders -------------------------------------------------------------------------

func get_order(order_id: int) -> Dictionary:
	for order in orders:
		if order.id == order_id:
			return order
	return {}


## True when the bag holds everything an order needs.
func can_pack(order_id: int) -> bool:
	var order := get_order(order_id)
	if order.is_empty() or table.free_slot() < 0 or is_packed(order_id):
		return false
	for item_id in order.items:
		if InventoryManager.get_count(item_id) < int(order.items[item_id]):
			return false
	return true


## True once a crate for this order has been packed (wherever it is now).
func is_packed(order_id: int) -> bool:
	for crate in get_crates():
		if crate.order_id == order_id:
			return true
	return false


## Packs an order into a crate on the packing table. Returns the crate (or null).
func pack(order_id: int) -> ShippingCrate:
	if not can_pack(order_id):
		return null
	var order := get_order(order_id)
	for item_id in order.items:
		InventoryManager.remove_item(item_id, int(order.items[item_id]))
	var crate := _spawn_crate(order_id, order.buyer)
	table.place(crate, table.free_slot())
	ActivityClock.advance_minutes(PACK_MINUTES, &"packing")
	QuestLog.record_event(&"pack_crate")
	orders_changed.emit()
	return crate


func _on_day_started(day: int) -> void:
	if day >= FIRST_ORDER_DAY:
		_post_orders()


## Tops the order list up to MAX_OPEN_ORDERS with new orders for today.
func _post_orders() -> void:
	_rng.seed = hash(ActivityClock.get_day() * 7919 + _next_id)
	var first := orders.is_empty() and _next_id == 1
	while orders.size() < MAX_OPEN_ORDERS:
		orders.append(_make_order())
	orders_changed.emit()
	if first:
		GameManager.notify("Captain Marlow has started taking orders! Pack them into crates at the farm's packing table and set them on the new jetty. He sails at 6 PM.")
	else:
		GameManager.notify("New shipping orders are pinned at the farm's packing table.")


func _make_order() -> Dictionary:
	var choices := _wanted_now()
	var items := {}
	var lines := 1 if _rng.randf() < 0.55 or choices.size() < 2 else 2
	for i in lines:
		var pick: Array = choices[_rng.randi() % choices.size()]
		items[pick[0]] = _rng.randi_range(pick[1], pick[2])
	var value := 0
	for item_id in items:
		var item := ItemDB.get_item(item_id)
		value += (item.sell_price if item else 10) * int(items[item_id])
	var order := {
		"id": _next_id,
		"buyer": BUYERS[_rng.randi() % BUYERS.size()],
		"items": items,
		"reward": int(snappedf(value * PAY_FACTOR + 20.0, 5.0)),
	}
	_next_id += 1
	return order


## The goods buyers can ask for right now: crops in season, fish, and later goods.
func _wanted_now() -> Array:
	var out := []
	var season := ActivityClock.get_season_id()
	for entry in WANTED:
		var flag: StringName = entry[3]
		if flag != &"" and not GameManager.has_flag(flag):
			continue
		var crop := _crop_for_harvest(entry[0])
		if crop and not crop.seasons.is_empty() and not crop.seasons.has(season):
			continue
		out.append(entry)
	return out


static func _crop_for_harvest(item_id: StringName) -> CropData:
	for crop in CropCatalog.shared().crops:
		if crop.harvest_item_id == item_id:
			return crop
	return null


# ---- Crates ---------------------------------------------------------------------------

func get_crates() -> Array[ShippingCrate]:
	var out: Array[ShippingCrate] = []
	for node in get_tree().get_nodes_in_group(&"shipping_crate"):
		if node is ShippingCrate and not node.is_queued_for_deletion():
			out.append(node)
	return out


func _spawn_crate(order_id: int, buyer: String) -> ShippingCrate:
	var crate := ShippingCrate.new()
	crate.order_id = order_id
	crate.buyer = buyer
	_crates_root.add_child(crate)
	return crate


## Puts a crate down on the open ground (world transform).
func set_on_ground(crate: ShippingCrate, xform: Transform3D) -> void:
	if crate.get_parent() != _crates_root:
		crate.reparent(_crates_root, false)
	crate.global_transform = xform
	crate.set_location(ShippingCrate.Location.GROUND)


# ---- Sailing --------------------------------------------------------------------------

func _on_time_advanced(minutes: int, _activity_id: StringName) -> void:
	var now := ActivityClock.total_minutes
	var before := now - minutes
	var sail := SAIL_HOUR * 60
	# Did the clock pass 6 PM (on any day) during this activity?
	if floori((now - sail) / 1440.0) > floori((before - sail) / 1440.0):
		sail_now()


## Captain Marlow takes every crate on the pad and pays for the orders in them.
func sail_now() -> void:
	var crates := pad.get_crates()
	if crates.is_empty():
		return
	var coins := 0
	for crate in crates:
		var order := get_order(crate.order_id)
		if not order.is_empty():
			coins += int(order.reward)
			orders.erase(order)
		crate.queue_free()
	if coins > 0:
		InventoryManager.add_money(coins)
	QuestLog.record_event(&"ship_crates", crates.size())
	GameManager.notify("Captain Marlow sails at six with %d %s for the mainland. +%d coins!" % [crates.size(), "crate" if crates.size() == 1 else "crates", coins])
	orders_changed.emit()
	shipped.emit(crates.size(), coins)


func _update_boat() -> void:
	if _boat:
		var hour := ActivityClock.get_hour()
		_boat.visible = hour >= 6 and hour < SAIL_HOUR


# ---- Building -------------------------------------------------------------------------

func _jetty_basis() -> Basis:
	# The jetty scene runs out along its own -Z.
	var yaw := atan2(-JETTY_DIRECTION.x, -JETTY_DIRECTION.y)
	return Basis(Vector3.UP, yaw)


## A point on the jetty: `along` metres out from the beach, `across` to the right.
func jetty_point(along: float, across: float, height: float = 0.0) -> Vector3:
	var basis := _jetty_basis()
	return JETTY_ROOT + basis * Vector3(across, height, -along)


func _build() -> void:
	var jetty := JETTY_SCENE.instantiate() as Node3D
	jetty.name = "Jetty"
	jetty.add_to_group(&"keep_clear")
	jetty.set_meta(&"clear_radius", 6.0)
	jetty.transform = Transform3D(_jetty_basis(), JETTY_ROOT)
	add_child(jetty)

	pad = ShippingPad.new()
	pad.name = "ShippingPad"
	add_child(pad)
	pad.global_transform = Transform3D(_jetty_basis(), jetty_point(15.0, 0.0))

	_boat = FittedModel.new()
	_boat.name = "MarlowsBoat"
	_boat.model = BOAT_MODEL
	(_boat as FittedModel).size = 7.0
	(_boat as FittedModel).snap_to_ground = false
	(_boat as FittedModel).collision = FittedModel.Collision.NONE
	add_child(_boat)
	_boat.global_transform = Transform3D(_jetty_basis(), Vector3(0, 0, 0))
	_boat.global_position = jetty_point(15.5, 4.4, -JETTY_ROOT.y - 0.15)

	table = PackingTable.new()
	table.name = "PackingTable"
	add_child(table)
	table.global_transform = Transform3D(Basis(Vector3.UP, TABLE_YAW), _ground(TABLE_POSITION))

	cart = HandCart.new()
	cart.name = "HandCart"
	add_child(cart)
	cart.global_transform = Transform3D(Basis(Vector3.UP, CART_YAW), _ground(CART_POSITION))

	# A few spare crates by the table, for the look of the place.
	for k in 3:
		var spare := FittedModel.new()
		spare.model = CRATE_STACK_MODEL
		spare.size = 0.62
		spare.collision = FittedModel.Collision.BOX
		add_child(spare)
		spare.global_position = _ground(TABLE_POSITION + Vector3(1.55 + 0.15 * (k % 2), 0.0, -0.75 + k * 0.72))
		spare.rotation.y = 0.25 * k

	_crates_root = Node3D.new()
	_crates_root.name = "Crates"
	add_child(_crates_root)


static func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, IslandShape.shared().get_height(p.x, p.z), p.z)


# ---- SaveManager hook -------------------------------------------------------------

func get_save_key() -> String:
	return "shipping"


func save_state() -> Dictionary:
	var crates := []
	for crate in get_crates():
		crates.append(crate.to_dict())
	return {
		"version": SAVE_VERSION,
		"orders": orders.duplicate(true),
		"next_id": _next_id,
		"crates": crates,
		"cart": {"x": cart.global_position.x, "z": cart.global_position.z, "yaw": cart.global_rotation.y},
	}


func load_state(data: Dictionary) -> void:
	if typeof(data.get("orders")) != TYPE_ARRAY:
		push_warning("ShippingYard: no orders in the save; starting fresh.")
		return
	orders.clear()
	for entry in data.orders:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var items := {}
		var raw_items: Variant = entry.get("items", {})
		if typeof(raw_items) == TYPE_DICTIONARY:
			for key in raw_items:
				items[StringName(str(key))] = int(raw_items[key])
		orders.append({"id": int(entry.get("id", 0)), "buyer": str(entry.get("buyer", "")), "items": items, "reward": int(entry.get("reward", 0))})
	_next_id = int(data.get("next_id", _next_id))
	for crate in get_crates():
		crate.queue_free()
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	var carry := PlayerCarry.find(player)
	if carry:
		carry.drop_everything()
	for entry in data.get("crates", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var crate := _spawn_crate(int(entry.get("order_id", 0)), str(entry.get("buyer", "")))
		_restore_crate(crate, entry)
	var cart_data: Variant = data.get("cart", {})
	if typeof(cart_data) == TYPE_DICTIONARY and cart_data.has("x"):
		cart.global_transform = Transform3D(Basis(Vector3.UP, float(cart_data.get("yaw", CART_YAW))), _ground(Vector3(float(cart_data.x), 0.0, float(cart_data.z))))
		cart.settle()
	orders_changed.emit()


func _restore_crate(crate: ShippingCrate, entry: Dictionary) -> void:
	var slot := int(entry.get("slot", -1))
	match int(entry.get("location", ShippingCrate.Location.GROUND)):
		ShippingCrate.Location.TABLE:
			if table.place(crate, slot):
				return
		ShippingCrate.Location.CART:
			if cart.place(crate, slot):
				return
		ShippingCrate.Location.PAD:
			if pad.place(crate, slot):
				return
	var pos := Vector3(float(entry.get("x", TABLE_POSITION.x)), float(entry.get("y", 0.0)), float(entry.get("z", TABLE_POSITION.z)))
	set_on_ground(crate, Transform3D(Basis(Vector3.UP, float(entry.get("yaw", 0.0))), pos))
