class_name BuildingData
extends Resource
## A building the player can restore: what it costs and how long the work takes.
## Add one by making a .tres in data/buildings/ and giving a RestorationSite in the
## world this resource.
##
## Restoring sets the story flag "restored_<id>" (GameManager), which is saved with the
## game, so villagers, quests and other objects can react to it.

## Stable ID used by saves and story flags. Never rename.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost_coins: int = 0
## Items used up, as {item_id: amount}.
@export var materials: Dictionary = {}
## In-game minutes the repair work takes (an activity, so the clock moves).
@export var work_minutes: int = 120
## Toast shown when the work is done.
@export_multiline var restored_message: String = ""
## Optional run-down model (e.g. a Tripo "…_ruined.glb"). When the file exists it is
## shown instead of the weathered look until the building is restored.
@export_file("*.glb", "*.tscn") var ruined_model_path: String = ""


func get_flag() -> StringName:
	return StringName("restored_%s" % id)
