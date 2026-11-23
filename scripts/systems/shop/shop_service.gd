class_name ShopService
extends RefCounted
## Buying and selling rules, kept apart from the shop screen so they can be tested.
## Shopping is like talking to a shopkeeper: it costs no in-game time.

enum Result { OK, INVALID, NOT_FOR_SALE, NOT_ENOUGH_MONEY, BAG_FULL, ALREADY_OWNED, NOT_SELLABLE, NOT_ENOUGH_ITEMS }

const MESSAGES := {
	Result.OK: "",
	Result.INVALID: "That doesn't seem right.",
	Result.NOT_FOR_SALE: "That isn't for sale here.",
	Result.NOT_ENOUGH_MONEY: "You don't have enough coins.",
	Result.BAG_FULL: "Your bag is too full.",
	Result.ALREADY_OWNED: "You already have one.",
	Result.NOT_SELLABLE: "The store won't buy that.",
	Result.NOT_ENOUGH_ITEMS: "You don't have that many.",
}


## Items the store sells (anything with a buy price), in catalog order.
static func get_stock() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in ItemDB.all_items():
		if item.buy_price > 0 and is_in_season(item.id):
			result.append(item)
	return result


## Seeds are only stocked in the seasons their crop grows in; everything else always is.
static func is_in_season(item_id: StringName) -> bool:
	var crop := CropCatalog.shared().get_crop_for_seed(item_id)
	return crop == null or crop.grows_in(ActivityClock.get_season_id())


## Items in the bag the store will buy, as [item, count] pairs.
static func get_sellable() -> Array:
	var result := []
	var bag := InventoryManager.get_all()
	for item_id in bag:
		var item := ItemDB.get_item(item_id)
		if item and item.sell_price > 0:
			result.append([item, bag[item_id]])
	return result


static func can_buy(item_id: StringName, quantity: int = 1) -> Result:
	var item := ItemDB.get_item(item_id)
	if item == null or quantity < 1:
		return Result.INVALID
	if item.buy_price <= 0 or not is_in_season(item_id):
		return Result.NOT_FOR_SALE
	if item.unique and (quantity > 1 or InventoryManager.get_count(item_id) > 0):
		return Result.ALREADY_OWNED
	if item.buy_price * quantity > InventoryManager.get_money():
		return Result.NOT_ENOUGH_MONEY
	if InventoryManager.get_room_for(item_id) < quantity:
		return Result.BAG_FULL
	return Result.OK


## Buys `quantity` (all or nothing). Returns {result, quantity, coins}.
static func buy(item_id: StringName, quantity: int = 1) -> Dictionary:
	var check := can_buy(item_id, quantity)
	if check != Result.OK:
		return {"result": check, "quantity": 0, "coins": 0}
	var cost := ItemDB.get_item(item_id).buy_price * quantity
	InventoryManager.spend_money(cost)
	InventoryManager.add_item(item_id, quantity)
	return {"result": Result.OK, "quantity": quantity, "coins": cost}


## Sells `quantity` (all or nothing). Returns {result, quantity, coins}.
static func sell(item_id: StringName, quantity: int = 1) -> Dictionary:
	var item := ItemDB.get_item(item_id)
	if item == null or quantity < 1:
		return {"result": Result.INVALID, "quantity": 0, "coins": 0}
	if item.sell_price <= 0:
		return {"result": Result.NOT_SELLABLE, "quantity": 0, "coins": 0}
	if InventoryManager.get_count(item_id) < quantity:
		return {"result": Result.NOT_ENOUGH_ITEMS, "quantity": 0, "coins": 0}
	InventoryManager.remove_item(item_id, quantity)
	var earned := item.sell_price * quantity
	InventoryManager.add_money(earned)
	# Quests: "sell_fish", "sell_crop" (food and flowers you grew) and any sale.
	match item.category:
		ItemData.Category.FISH:
			QuestLog.record_event(&"sell_fish", quantity)
		ItemData.Category.FOOD, ItemData.Category.MISC:
			if CropCatalog.shared().crops.any(func(c: CropData) -> bool: return c.harvest_item_id == item_id):
				QuestLog.record_event(&"sell_crop", quantity)
	QuestLog.record_event(&"sell", quantity)
	return {"result": Result.OK, "quantity": quantity, "coins": earned}


static func message_for(result: Result) -> String:
	return MESSAGES.get(result, "")
