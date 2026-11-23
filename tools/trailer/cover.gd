extends Node
## Cover pictures for the trailer reel: portrait (1080x1920) stills filmed in the real game,
## each saved plain and with the title.
##   Godot --path . res://tools/trailer/cover.tscn -- --out=<dir> [--only=<shot name>]
## Rendered at twice the size and scaled down, for smooth edges. Uses its own save file.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const FONT := preload("res://assets/ui/fonts/Caveat.ttf")
const SIZE := Vector2i(1080, 1920)
const SUPERSAMPLE := 2

var _day: int = 40
var _out: String = ""
var _only: String = ""
var _view: SubViewport
var _main: Node3D
var _player: PlayerController
var _cam: Camera3D
var _sun: DirectionalLight3D
var _text: Control
var _title: Label
var _tagline: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	if _out == "":
		_out = OS.get_user_data_dir().path_join("cover")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().always_on_top = true
	SaveManager.save_path = "user://trailer_save.json"
	SaveManager.autosave_enabled = false
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	GameManager.reset_flags()
	InventoryManager.reset()
	get_node("/root/UISounds").set(&"enabled", false)
	get_node("/root/StorySounds").process_mode = Node.PROCESS_MODE_DISABLED
	AudioServer.set_bus_mute(0, true)

	_view = SubViewport.new()
	_view.size = SIZE * SUPERSAMPLE
	_view.size_2d_override = SIZE
	_view.size_2d_override_stretch = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_main = MAIN_SCENE.instantiate() as Node3D
	_view.add_child(_main)
	_player = _main.get_node("Player") as PlayerController
	for child in _main.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var pause := _main.get_node_or_null("PauseMenu")
	if pause:
		pause.queue_free()
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 4000.0
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_view.add_child(_cam)
	_cam.make_current()
	_sun = _main.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	_build_text()
	for flag in [&"has_fishing_rod", &"restored_bridge", &"restored_market", &"restored_greenhouse",
			&"restored_inn", &"restored_boathouse", &"restored_windmill", &"ch1_hedge_cleared", &"ch1_orchard_planted"]:
		GameManager.set_flag(flag)
	_run.call_deferred()


func _run() -> void:
	await _frames(30)
	var dock := _main.get_node("Island/Buildings/FishingDock") as Node3D
	var ahead := -dock.global_basis.z
	var side := dock.global_basis.x
	var dock_end := dock.global_position + ahead * 13.0
	var beam: Node3D = null
	for node in _main.find_children("*", "Node3D", true, false):
		var s := node.get_script() as Script
		if s and s.get_global_name() == "LighthouseBeam":
			beam = node
	var lh := beam.global_position if beam else Vector3(172, 30, -92)
	var away := Vector3(lh.x, 0, lh.z).direction_to(Vector3(0, 0, 40))
	var windmill := _main.get_node_or_null("Island/StoryPlaces/Farm/Windmill") as Node3D
	var village := _ground(IslandShape.VILLAGE_CENTER.x, IslandShape.VILLAGE_CENTER.y)

	# Fishing off the dock at sunset, line in the water.
	_set_time(20, 30)
	_player.teleport_to(dock_end + Vector3(0, 0.3, 0), _yaw_of(ahead))
	await _cast()
	await _snap("dock_sunset", dock_end - ahead * 4.5 + side * 1.4 + Vector3(0, 1.7, 0), dock_end + ahead * 30.0 + Vector3(0, 4.0, 0))
	var to_sun := _to_sun_flat()
	await _snap("dock_into_sun", dock_end - to_sun * 5.5 + Vector3(0, 1.4, 0), dock_end + to_sun * 40.0 + Vector3(0, 6.0, 0))
	var across := to_sun.cross(Vector3.UP)
	await _snap("dock_hero", dock_end - to_sun * 3.2 - across * 0.9 + Vector3(0, 0.9, 0), dock_end + to_sun * 40.0 + across * 3.0 + Vector3(0, 8.0, 0))
	_stop_fishing()

	# The windmill turning in the evening light.
	if windmill:
		_set_time(20, 30)
		var wm := windmill.global_position
		var from := _ground(wm.x - 12.0, wm.z + 14.0) + Vector3(0, 1.2, 0)
		await _snap("windmill_golden", from, wm + Vector3(0, 9.0, 0))

	# The village at dusk, lanterns coming on.
	_set_time(20, 40)
	await _snap("village_dusk", village + Vector3(20, 9, 26), village + Vector3(-2, 3, -2))

	# The lighthouse, lit again.
	for i in 5:
		GameManager.set_flag(StringName("shard_%d" % (i + 1)))
	GameManager.set_flag(&"finale_lens")
	GameManager.set_flag(&"restored_lighthouse")
	GameManager.set_flag(&"lighthouse_lit")
	var sea := lh + away * 60.0 + away.cross(Vector3.UP) * 14.0 + Vector3(0, -12.0, 0)
	_set_time(20, 50)
	await _snap("lighthouse_dusk", sea, lh + Vector3(0, -3.0, 0))
	_set_time(22, 30)
	await _snap("lighthouse_night", sea, lh + Vector3(0, -3.0, 0))

	# The whole island from the sea at sunset.
	_set_time(20, 35)
	await _snap("island_sunset", Vector3(-60, 40, 330), Vector3(-10, 4, 60))
	get_tree().quit()


func _snap(shot: String, from: Vector3, look: Vector3) -> void:
	if _only != "" and _only != shot:
		return
	_cam.look_at_from_position(from, look)
	_text.visible = false
	await _frames(90)
	# If the window is covered, macOS may stop drawing: force a fresh frame.
	RenderingServer.force_draw(false)
	_save(_grab(), shot + ".png")
	_text.visible = true
	await _frames(3)
	RenderingServer.force_draw(false)
	_save(_grab(), shot + "_title.png")
	print("cover: ", shot)


func _grab() -> Image:
	var img := _view.get_texture().get_image()
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	return img


func _save(img: Image, file: String) -> void:
	img.save_png(_out.path_join(file))


func _cast() -> void:
	var fishing := _player.get_node("Fishing") as FishingController
	fishing.equip()
	await _frames(20)
	fishing.bite_wait_override = 999.0
	fishing.begin_charge()
	await _frames(25)
	fishing.release_cast(0.75)
	await _frames(70)


func _stop_fishing() -> void:
	var fishing := _player.get_node("Fishing") as FishingController
	if fishing.is_busy():
		fishing.cancel()
	fishing.stow()
	_player.set_input_locked(false)


## Each change of time steps back a day so the light snaps instead of easing.
func _set_time(hour: int, minute: int) -> void:
	_day -= 1
	ActivityClock.from_dict({"total_minutes": (_day - 1) * 1440 + hour * 60 + minute})


func _to_sun_flat() -> Vector3:
	var d := _sun.global_basis.z
	return Vector3(d.x, 0, d.z).normalized()


func _build_text() -> void:
	var layer := CanvasLayer.new()
	_view.add_child(layer)
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_text)
	# A soft dark wash behind the words so they read on any sky.
	var wash := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.45))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	wash.texture = tex
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.anchor_right = 1.0
	wash.anchor_bottom = 0.36
	_text.add_child(wash)
	_title = _label(158, Color(1.0, 0.94, 0.8))
	_title.text = "Life on the Island"
	_title.anchor_top = 0.12
	_title.anchor_bottom = 0.22
	_text.add_child(_title)
	_tagline = _label(58, Color(0.98, 0.93, 0.85))
	_tagline.text = "Fish, farm, explore."
	_tagline.anchor_top = 0.215
	_tagline.anchor_bottom = 0.265
	_text.add_child(_tagline)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_constant_override("shadow_outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.04
	label.anchor_right = 0.96
	return label


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, maxf(IslandShape.shared().get_height(x, z), IslandShape.SEA_LEVEL) + 0.3, z)


func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
