class_name UIPalette
extends RefCounted
## The cozy UI colours, in one place. The theme (assets/ui/cozy_theme.tres, built by
## tools/build_ui_theme.gd) and any UI drawn in code (bars, markers) use these.

const PARCHMENT := Color("f6ead2f7")
const PARCHMENT_DARK := Color("ead8b4")
const WOOD := Color("7a4e2d")
const WOOD_DARK := Color("5a3a22")
const WOOD_LIGHT := Color("a8754a")
const INK := Color("4a3222")
const INK_SOFT := Color("7d6450")
const CREAM := Color("fff7e6")
const HONEY := Color("f2b84b")
const LEAF := Color("7fb069")
const SKY := Color("6fb7d6")
const BERRY := Color("d9604c")
const SHADOW := Color(0, 0, 0, 0.28)

## Fish rarity colours (common, uncommon, rare) that read on parchment.
const RARITY := [Color("6b7f5a"), Color("2f7fa6"), Color("c27a12")]

const THEME_PATH := "res://assets/ui/cozy_theme.tres"
const ICONS := "res://assets/ui/icons/"


static func icon(icon_name: String) -> Texture2D:
	return load(ICONS + icon_name + ".svg") as Texture2D


## An item's own icon if it has one, otherwise one for its kind (fish, seeds, tools...).
static func item_icon(item_id: StringName) -> Texture2D:
	var data := ItemDB.get_item(item_id)
	if data and data.icon:
		return data.icon
	if data == null:
		return icon("bag")
	match data.category:
		ItemData.Category.FISH:
			return icon("fish")
		ItemData.Category.SEED:
			return icon("leaf")
		ItemData.Category.TOOL:
			return icon("can")
		ItemData.Category.FOOD:
			return icon("bread")
		ItemData.Category.MATERIAL:
			return icon("plank")
	return icon("bag")
