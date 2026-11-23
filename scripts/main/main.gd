extends Node3D
## Main scene: puts the player at the island's spawn point on the ground (or where
## they were, when continuing a save), adds the pause menu (Esc) and the island's
## ambient sound, and starts autosave.
## On a New game it plays the opening scene first, which ends with the player on the
## beach jetty (D-008); autosave starts only once it is over.

const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const OPENING := preload("res://scenes/ui/opening_scene.tscn")

@onready var _island: Node3D = $Island
@onready var _player: PlayerController = $Player


func _ready() -> void:
	GameSettings.ensure_loaded()
	var pause_menu := PAUSE_MENU.instantiate()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	# Background sound: surf, lake, birds, wind, rain... (fades in; silent during the opening)
	add_child(IslandAmbience.new())
	var spawn := _island.get_node("SpawnPoint") as Marker3D
	var terrain := _island.get_node("Terrain") as IslandTerrain
	var spawn_position := spawn.global_position
	spawn_position.y = terrain.shape.get_height(spawn_position.x, spawn_position.z) + 0.2
	_player.teleport_to(spawn_position, spawn.global_rotation.y)
	# Continuing a saved game: put the player back where they were and restore saved
	# world objects (farm plots and so on). Then autosave can start.
	SaveManager.apply_pending_world(_player)
	if OpeningScene.consume_request() and not GameManager.has_flag(OpeningScene.FLAG):
		play_opening()
	else:
		SaveManager.begin_session()


## Plays "A Letter from Grandpa". Autosave waits until it ends, so quitting part-way
## leaves no save and the next New game plays it again.
func play_opening() -> OpeningScene:
	var opening := OPENING.instantiate() as OpeningScene
	add_child(opening)
	opening.begin(self)
	opening.finished.connect(func(_skipped: bool) -> void: SaveManager.begin_session(), CONNECT_ONE_SHOT)
	return opening


func _exit_tree() -> void:
	SaveManager.end_session()
