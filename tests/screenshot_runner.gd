extends Node
## Renders reference screenshots of the island (needs a real window, not --headless).
## Run:  Godot --path . res://tests/screenshot_runner.tscn -- --out=/some/folder
## Default output folder: user://screenshots

const MAIN_SCENE := preload("res://scenes/main/main.tscn")

var _out_dir := "user://screenshots"


func _ready() -> void:
	SaveManager.use_test_slot()  # screenshots must never overwrite the player's save
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(1600, 900)
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	var player := main.get_node("Player") as PlayerController
	var rig := player.get_node("CameraRig") as CameraRig
	var player_camera := rig.get_camera()
	var shape := IslandShape.new()
	var ground := func(x: float, z: float) -> Vector3: return Vector3(x, shape.get_height(x, z) + 0.3, z)
	await _wait(1.0)
	await _shot("01_spawn_morning")

	ActivityClock.advance_minutes(4 * 60, &"screenshot")
	await _wait(3.5)
	await _shot("02_spawn_10am")

	var aerial := Camera3D.new()
	aerial.far = 3000.0
	aerial.fov = 55.0
	add_child(aerial)
	aerial.look_at_from_position(Vector3(40, 330, 420), Vector3(10, 0, 0))
	aerial.make_current()
	await _wait(0.6)
	await _shot("03_aerial_island")

	aerial.look_at_from_position(Vector3(-60, 40, 150), Vector3(0, 6, 60))
	await _wait(0.6)
	await _shot("04_village_lake_overview")

	player_camera.make_current()
	var dock := main.get_node("Island/Buildings/FishingDock") as Node3D
	player.teleport_to(dock.global_position + Vector3(0, 0.3, -2.0), 0.0)
	await _wait(1.0)
	await _shot("05_dock")

	player.teleport_to(ground.call(-11.0, 100.0), PI * 0.5)
	await _wait(1.0)
	await _shot("06_cottage")

	player.teleport_to(ground.call(1.5, 123.0), 0.0)
	await _wait(1.0)
	await _shot("06b_village_well")

	player.teleport_to(ground.call(4.5, 99.5), 0.0)
	await _wait(1.0)
	await _shot("06c_signpost")

	player.teleport_to(Vector3(-24.5, 4.35, 100.5), PI * 0.5)
	await _wait(1.0)
	await _shot("07_cottage_interior")

	player.teleport_to(ground.call(-95.0, 0.0), PI * 0.75)
	await _wait(1.0)
	await _shot("08_forest")

	var beach := _find_beach(shape)
	player.teleport_to(ground.call(beach.x, beach.y), atan2(-0.89, -0.45))
	await _wait(1.0)
	await _shot("08b_beach")

	player.teleport_to(ground.call(-30.0, 30.0), deg_to_rad(-60.0))
	await _wait(1.0)
	await _shot("08c_lakeshore")

	player.teleport_to(ground.call(-4.0, 102.0), 0.0)
	ActivityClock.advance_minutes(ActivityClock.minutes_until(19, 30), &"screenshot")
	await _wait(3.5)
	await _shot("09_dusk")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(23), &"screenshot")
	await _wait(3.5)
	await _shot("10_night")
	get_tree().quit()


## A sandy spot on the south-west coast, a few metres above the waterline.
func _find_beach(shape: IslandShape) -> Vector2:
	for r in range(140, 240, 2):
		var p := Vector2(-0.45, 0.89).normalized() * r
		if shape.get_height(p.x, p.y) < 1.6:
			return p
	return Vector2(-80, 170)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path)
