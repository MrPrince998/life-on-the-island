class_name CropData
extends Resource
## One kind of crop: which seeds plant it, how long it grows and what it gives.
## Add a crop by making a .tres in data/crops/ and listing it in data/crops/crop_catalog.tres.
##
## Growing rules (cozy, never punishing):
##   - A crop only grows while its soil is damp. Watering keeps soil damp for
##     FarmPlot.DAMP_MINUTES of in-game time.
##   - Growth is counted in in-game minutes, so it moves on only when the clock does
##     (sleeping, fishing, resting...). Walking around never grows anything.
##   - Crops never die. Dry soil just pauses growth until you water again.

enum Stage { SEED, SPROUT, GROWING, READY }

## Stable ID used by saves. Never rename.
@export var id: StringName = &""
## Plural name shown in prompts, e.g. "Turnips".
@export var display_name: String = ""
## Seed item that plants this crop (see data/items/).
@export var seed_item_id: StringName = &""
## Item you get when harvesting.
@export var harvest_item_id: StringName = &""
@export var harvest_amount: int = 3
## Damp (watered) in-game hours needed from planting to harvest.
@export var grow_hours: float = 18.0
## Built-in look used until real models exist: "turnip", "carrot" or "sunflower".
@export var look: StringName = &"turnip"
## Plants shown per bed are plants_per_row x plants_per_row.
@export var plants_per_row: int = 3
## Seasons it can be planted in ("spring", "summer", "autumn", "winter"; empty = any).
## Crops already in the ground keep growing when the season changes; nothing dies.
@export var seasons: Array[StringName] = []
## Size of each plant (1 = the built-in look's natural size).
@export var plant_scale: float = 1.0
## Optional models, one per Stage (SEED, SPROUT, GROWING, READY). When set, they
## replace the built-in look for that stage.
@export var stage_models: Array[PackedScene] = []


func get_grow_minutes() -> int:
	return maxi(roundi(grow_hours * 60.0), 1)


## Growth stage for this many minutes of damp growing time.
func get_stage(growth_minutes: int) -> Stage:
	if growth_minutes >= get_grow_minutes():
		return Stage.READY
	if growth_minutes <= 0:
		return Stage.SEED
	if growth_minutes < get_grow_minutes() * 0.4:
		return Stage.SPROUT
	return Stage.GROWING


func grows_in(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons


## "Spring and Autumn" for messages ("any season" when not limited).
func get_seasons_text() -> String:
	if seasons.is_empty():
		return "any season"
	var names: Array[String] = []
	for season in seasons:
		names.append(String(season).capitalize())
	return " and ".join(names) if names.size() <= 2 else ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]


## Lower-case singular-ish name for sentences ("the turnips").
func get_lower_name() -> String:
	return display_name.to_lower()
