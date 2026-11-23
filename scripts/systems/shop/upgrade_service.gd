class_name UpgradeService
extends RefCounted
## Buying upgrades (data/upgrades/*.tres) and what the tool upgrades do.
##
## An upgrade is bought once; buying it takes the coins and sets its flag
## ("bought_<id>"), which GameManager saves. Shopping uses no in-game time.
## Furniture, garden beds and village projects appear through StoryVariant nodes that
## watch those flags; the tool upgrades are read here by the systems they change:
##   bag_bonus()   - InventoryManager (more bag slots)
##   rod_ease()    - FishingController (fish fight less)
##   rare_bonus()  - FishCatalog.pick (uncommon and rare fish bite more often)
##   has_big_can() - FarmingController (watering soaks the neighbouring beds too)

const CATALOG_PATH := "res://data/upgrades/upgrade_catalog.tres"

enum Result { OK, NOT_ENOUGH_MONEY, ALREADY_OWNED, LOCKED, UNKNOWN }

const MESSAGES := {
	Result.OK: "Done!",
	Result.NOT_ENOUGH_MONEY: "You don't have enough coins for that yet.",
	Result.ALREADY_OWNED: "You already have that.",
	Result.LOCKED: "That isn't available yet.",
	Result.UNKNOWN: "Emma doesn't know what that is.",
}

## Extra bag slots from each bag upgrade.
const BAG_UPGRADES := {&"tool_bag_satchel": 6, &"tool_bag_pack": 6}

static var _catalog: UpgradeCatalog


static func catalog() -> UpgradeCatalog:
	if _catalog == null:
		_catalog = load(CATALOG_PATH) as UpgradeCatalog
	return _catalog


static func get_all() -> Array[UpgradeData]:
	var cat := catalog()
	return cat.upgrades if cat else ([] as Array[UpgradeData])


static func get_upgrade(id: StringName) -> UpgradeData:
	for upgrade in get_all():
		if upgrade.id == id:
			return upgrade
	return null


static func is_bought(id: StringName) -> bool:
	return GameManager.has_flag(StringName("bought_" + String(id)))


## True when nothing stands in the way except, perhaps, the price.
static func is_unlocked(upgrade: UpgradeData) -> bool:
	if upgrade.requires_upgrade != &"" and not is_bought(upgrade.requires_upgrade):
		return false
	return upgrade.requires_flag == &"" or GameManager.has_flag(upgrade.requires_flag)


## Why a locked upgrade can't be bought yet ("" when it can).
static func lock_reason(upgrade: UpgradeData) -> String:
	if upgrade.requires_upgrade != &"" and not is_bought(upgrade.requires_upgrade):
		var first := get_upgrade(upgrade.requires_upgrade)
		return "First buy the %s." % (first.display_name if first else String(upgrade.requires_upgrade))
	if upgrade.requires_flag != &"" and not GameManager.has_flag(upgrade.requires_flag):
		return upgrade.requires_text if upgrade.requires_text != "" else "Not available yet."
	return ""


static func can_buy(id: StringName) -> Result:
	var upgrade := get_upgrade(id)
	if upgrade == null:
		return Result.UNKNOWN
	if is_bought(id):
		return Result.ALREADY_OWNED
	if not is_unlocked(upgrade):
		return Result.LOCKED
	if InventoryManager.get_money() < upgrade.price:
		return Result.NOT_ENOUGH_MONEY
	return Result.OK


## Buys an upgrade. Returns {"result": Result, "coins": price paid}.
static func buy(id: StringName) -> Dictionary:
	var result := can_buy(id)
	if result != Result.OK:
		return {"result": result, "coins": 0}
	var upgrade := get_upgrade(id)
	InventoryManager.spend_money(upgrade.price)
	GameManager.set_flag(upgrade.get_flag())
	QuestLog.record_event(&"buy_upgrade")
	return {"result": Result.OK, "coins": upgrade.price}


static func message_for(result: Result) -> String:
	return MESSAGES.get(result, "")


# ---- What the tools do ------------------------------------------------------------

## Extra bag slots from the bag upgrades bought.
static func bag_bonus() -> int:
	var bonus := 0
	for id: StringName in BAG_UPGRADES:
		if is_bought(id):
			bonus += BAG_UPGRADES[id]
	return bonus


## How much easier a hooked fish is to reel in with the rod you own (0 = Grandpa's
## old rod; the fish's difficulty is scaled by 1 - this).
static func rod_ease() -> float:
	if is_bought(&"tool_rod_moonwood"):
		return 0.35
	if is_bought(&"tool_rod_oak"):
		return 0.2
	return 0.0


## How much more often uncommon and rare fish bite with the rod you own: a fish's bite
## weight is scaled by 1 + this × its rarity (0 = common, 1 = uncommon, 2 = rare).
static func rare_bonus() -> float:
	if is_bought(&"tool_rod_moonwood"):
		return 0.8
	if is_bought(&"tool_rod_oak"):
		return 0.35
	return 0.0


## The Copper Watering Can soaks the beds right next to the one you water.
static func has_big_can() -> bool:
	return is_bought(&"tool_can_copper")
