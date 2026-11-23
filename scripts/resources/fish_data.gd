class_name FishData
extends Resource
## One fish species. Add a species by making a new .tres in data/fish/ and listing
## it in data/fish/fish_catalog.tres.

enum Rarity { COMMON, UNCOMMON, RARE }

## Stable ID used by saves, inventory and the journal. Never rename.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Which waters it lives in (WaterBody.water_id values, e.g. "moonlit_lake", "sea").
@export var water_ids: PackedStringArray = PackedStringArray()
## Seasons it bites in ("spring", "summer", "autumn", "winter"; empty = all year).
@export var seasons: Array[StringName] = []
## Active hours, 0-24. If start > end it wraps past midnight (e.g. 19 -> 5).
@export_range(0, 24) var start_hour: int = 0
@export_range(0, 24) var end_hour: int = 24
## Relative chance to bite compared to other fish available at the same spot and time.
@export var weight: float = 10.0
## 0 = gentle, 1 = strong fighter. Drives the reeling minigame.
@export_range(0.0, 1.0) var difficulty: float = 0.3
@export var min_size_cm: float = 10.0
@export var max_size_cm: float = 30.0
## Shop value (used from Phase 3).
@export var sell_price: int = 10
## Colour for UI accents until the fish has a model.
@export var ui_color: Color = Color(0.6, 0.75, 0.85)
## Optional 3D model. If empty, source_assets/tripo/fish_<id>.glb is used when it exists.
@export var model: PackedScene
## Turn (degrees around up) that makes the model's head point along +X.
@export var model_yaw_degrees: float = 0.0


## The fish's 3D model, or null if there isn't one yet.
func get_model() -> PackedScene:
	if model:
		return model
	var path := "res://source_assets/tripo/fish_%s.glb" % id
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


func is_active_at_hour(hour: int) -> bool:
	if start_hour == end_hour or (start_hour == 0 and end_hour == 24):
		return true
	if start_hour < end_hour:
		return hour >= start_hour and hour < end_hour
	return hour >= start_hour or hour < end_hour


func lives_in(water_id: StringName) -> bool:
	return String(water_id) in water_ids


func get_rarity_name() -> String:
	return ["Common", "Uncommon", "Rare"][rarity]


func is_in_season(season_id: StringName) -> bool:
	return seasons.is_empty() or season_id in seasons
