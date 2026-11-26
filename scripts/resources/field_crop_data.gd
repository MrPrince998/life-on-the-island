class_name FieldCropData
extends Resource
## A field crop grown the realistic way, in rows (CropField): rice now, wheat later.
##   plant a row (seedlings) -> it grows a day at a time (in a flooded paddy, for rice)
##   -> ripe -> cut it with a sickle (the stalks lie in the row) -> gather and tie them
##   into sheaves -> a machine (the thresher) turns sheaves into grain.
## Neglect never kills it: growth just pauses until conditions are right again.

## Stable id (saves).
@export var id: StringName = &""
@export var display_name: String = ""
## Planted from this item (one per row), e.g. &"rice_seedlings".
@export var planting_item: StringName = &""
## What the cut row is tied into, e.g. &"rice_sheaf".
@export var sheaf_item: StringName = &""
## Sheaves one row gives (min, max).
@export var sheaves_per_row: Vector2i = Vector2i(6, 8)
## Days of growing (each new morning counts, if conditions were right) until it's ripe.
@export var grow_days: int = 4
## Seasons it can be planted in (empty = any). Planted rows keep growing when the season turns.
@export var seasons: Array[StringName] = []
## Rice: the paddy must be flooded to grow, and drained before it's cut.
@export var needs_flooding: bool = false
## Wheat: each row must be tilled with a hoe before it's sown (and again after harvest).
@export var needs_tilling: bool = false
## How the plants are drawn (FieldCropMeshes): &"rice" (drooping heads) or &"wheat"
## (upright ears).
@export var look: StringName = &"rice"

@export_group("Time (in-game minutes per row)")
@export var till_minutes: int = 30
## Hoe strokes to till one row.
@export var till_swings: int = 4
@export var plant_minutes: int = 20
@export var cut_minutes: int = 25
@export var tie_minutes: int = 15
## Sickle swings to cut one row.
@export var cut_swings: int = 4

@export_group("Look")
@export var young_color: Color = Color(0.45, 0.72, 0.3)
@export var growing_color: Color = Color(0.36, 0.62, 0.22)
@export var ripe_color: Color = Color(0.86, 0.72, 0.32)
@export var grain_color: Color = Color(0.93, 0.79, 0.4)
## Height of a full-grown plant (metres).
@export var height: float = 1.0


func grows_in(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons


## "spring, summer and autumn" for messages.
func get_seasons_text() -> String:
	if seasons.is_empty():
		return "any season"
	var names: Array[String] = []
	for s in seasons:
		names.append(String(s))
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names.back()


## Every field crop (data/field_crops/*.tres).
static func all() -> Array[FieldCropData]:
	var result: Array[FieldCropData] = []
	for path in ["res://data/field_crops/rice.tres", "res://data/field_crops/wheat.tres"]:
		var crop := load(path) as FieldCropData
		if crop:
			result.append(crop)
	return result


## The field crop planted from `item_id` (null if none).
static func for_planting_item(item_id: StringName) -> FieldCropData:
	for crop in all():
		if crop.planting_item == item_id:
			return crop
	return null
