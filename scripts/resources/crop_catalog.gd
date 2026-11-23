class_name CropCatalog
extends Resource
## All crops in the game. The default catalog lives at data/crops/crop_catalog.tres.

const DEFAULT_PATH := "res://data/crops/crop_catalog.tres"

@export var crops: Array[CropData] = []

static var _shared: CropCatalog


## The game's crop catalog (loaded once).
static func shared() -> CropCatalog:
	if _shared == null:
		_shared = load(DEFAULT_PATH) as CropCatalog
	return _shared


func get_crop(crop_id: StringName) -> CropData:
	for crop in crops:
		if crop.id == crop_id:
			return crop
	return null


## The crop these seeds grow into, or null if the item isn't a seed.
func get_crop_for_seed(seed_item_id: StringName) -> CropData:
	for crop in crops:
		if crop.seed_item_id == seed_item_id:
			return crop
	return null
