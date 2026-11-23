extends Node
## The game's trailer, filmed inside the real game: a scripted camera visits the island
## from dawn to night, over the opening theme, with a few handwritten captions.
##
## Make the video (see tools/trailer/make_trailer.sh):
##   Godot --path . --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie <dir>/frame.png res://tools/trailer/trailer.tscn
## Preview stills instead (one PNG per shot, quick):
##   Godot --path . --fixed-fps 30 res://tools/trailer/trailer.tscn -- --preview=<dir>
##
## It never touches the player's save (it uses its own save file, autosave off) and
## the story moments it stages are only for the camera.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const MUSIC := preload("res://assets/audio/opening/music.wav")
const FONT := preload("res://assets/ui/fonts/Caveat.ttf")
## Each change of time steps back a day, so the light snaps to the new time at once
## (going forward it would ease over a few seconds). Day 20 is still spring.
var _day: int = 20
const CAPTION_FADE := 0.7
## A hidden warm-up before the trailer: the camera visits every place by day, at night
## and in the rain behind a black screen, so all the graphics are ready (otherwise the
## first moments of each new sight stutter). make_trailer.sh cuts exactly this many
## frames (10 s at 30 fps) off the start of the video.
const PREROLL_FRAMES := 300

var _main: Node3D
var _player: PlayerController
var _cam: Camera3D
var _fade: ColorRect
var _caption: Label
var _title: Label
var _subtitle: Label
var _cam_fn: Callable
var _shot_time: float = 0.0
var _shot_length: float = 1.0
var _preview_dir: String = ""
var _shot_index: int = 0
## For quick test renders: stop after this many shots (0 = the whole trailer).
var _max_shots: int = 0
var _shots_played: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_max_shots = arg.trim_prefix("--shots=").to_int()
		if arg.begins_with("--preview="):
			_preview_dir = arg.trim_prefix("--preview=")
			DirAccess.make_dir_recursive_absolute(_preview_dir)
	SaveManager.save_path = "user://trailer_save.json"
	SaveManager.autosave_enabled = false
	WeatherManager.auto_change = false
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	GameManager.reset_flags()
	InventoryManager.reset()
	_build_overlay()
	_main = MAIN_SCENE.instantiate() as Node3D
	add_child(_main)
	_player = _main.get_node("Player") as PlayerController
	# Only the camera's view: no HUD, no pause menu, no interface or story-moment sounds.
	for child in _main.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var pause := _main.get_node_or_null("PauseMenu")
	if pause:
		pause.queue_free()
	get_node("/root/UISounds").set(&"enabled", false)
	get_node("/root/StorySounds").process_mode = Node.PROCESS_MODE_DISABLED
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambience"), -5.0)
	_cam = Camera3D.new()
	_cam.name = "TrailerCamera"
	_cam.fov = 50.0
	_cam.far = 4000.0
	# The camera moves every drawn frame, so it must not wait for physics steps
	# (with interpolation on, it would stall and stutter between them).
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_cam)
	_cam.make_current()
	# The island partly restored already; the windmill waits for its moment on camera.
	for flag in [&"has_fishing_rod", &"restored_bridge", &"restored_market", &"restored_greenhouse",
			&"restored_inn", &"restored_boathouse", &"ch1_hedge_cleared", &"ch1_orchard_planted"]:
		GameManager.set_flag(flag)
	_plant_the_garden()
	await _warm_up()
	_set_time(5, 40)
	if Engine.get_process_frames() > PREROLL_FRAMES:
		push_error("Trailer warm-up ran past PREROLL_FRAMES (%d): raise it, and the cut in make_trailer.sh." % Engine.get_process_frames())
	while Engine.get_process_frames() < PREROLL_FRAMES:
		await get_tree().process_frame
	_run.call_deferred()


func _run() -> void:
	var music := AudioStreamPlayer.new()
	music.stream = MUSIC
	music.volume_db = -2.0
	add_child(music)
	music.play()
	var dock := _main.get_node("Island/Buildings/FishingDock") as Node3D
	var farm := _node_pos("FarmField", Vector3(IslandShape.FARM_CENTER.x, IslandShape.FARM_HEIGHT, IslandShape.FARM_CENTER.y))
	var windmill := _main.get_node_or_null("Island/StoryPlaces/Farm/Windmill") as Node3D
	var village := _ground(IslandShape.VILLAGE_CENTER.x, IslandShape.VILLAGE_CENTER.y)

	# 1. Dawn, out at sea: the island ahead.
	_fade_to(0.0, 2.5)
	await _shot(5.5, Vector3(-60, 6, 330), Vector3(-20, 8, 120), Vector3(-45, 9, 285), Vector3(-15, 8, 120),
		"Grandpa left you a cottage by the sea...")
	# 2. Over the island in the morning.
	await _dip(func() -> void: _set_time(8, 0))
	await _shot(5.0, Vector3(-190, 95, 250), Vector3(-10, 0, 40), Vector3(110, 110, 245), Vector3(15, 0, 30),
		"...on a quiet island, waiting to wake up.")
	# 3. Willowbrook village.
	await _dip(func() -> void:
		_set_time(9, 30)
		_player.teleport_to(_ground(-6.0, 128.0), PI))
	await _shot(4.5, village + Vector3(-24, 9, 30), village + Vector3(0, 1.5, -2), village + Vector3(-10, 6, 26), village + Vector3(2, 1.5, -4))
	# 4. Fishing off the dock.
	var dock_end := dock.global_position - dock.global_basis.z * 13.0
	await _dip(func() -> void:
		_set_time(10, 30)
		_player.teleport_to(dock_end + Vector3(0, 0.3, 0), _yaw_of(-dock.global_basis.z)))
	_fish.call_deferred()
	var side := dock.global_basis.x
	var ahead := -dock.global_basis.z
	await _shot(6.5, dock_end + side * 3.5 + ahead * -3.5 + Vector3(0, 2.4, 0), dock_end + ahead * 7.0 + Vector3(0, 0.5, 0),
		dock_end + side * 2.6 + ahead * -2.2 + Vector3(0, 1.9, 0), dock_end + ahead * 8.0 + Vector3(0, 0.3, 0), "Fish at your own pace")
	_stop_fishing()
	# 5. The garden: watering the beds.
	var bed := (_main.get_node("Island/Buildings/FarmField") as FarmField).get_plot(&"farm_plot_01")
	await _dip(func() -> void:
		_set_time(11, 30)
		_player.teleport_to(bed.global_position + Vector3(0, 0.3, 1.4), 0.0))
	_water_a_bed.call_deferred(bed)
	await _shot(4.5, farm + Vector3(-13, 6, 15), farm + Vector3(0, 0.5, 0), farm + Vector3(-7, 4, 11), farm + Vector3(1, 0.5, -1), "Grow a little garden")
	# 6. The windmill comes back to life.
	var wm := windmill.global_position if windmill else farm + Vector3(25, 0, -22)
	await _dip(func() -> void: _set_time(13, 0))
	_restore_later.call_deferred(&"restored_windmill", 2.2)
	await _shot(6.0, wm + Vector3(-20, 5, 18), wm + Vector3(0, 7, 0), wm + Vector3(-14, 4, 13), wm + Vector3(0, 8, 0), "Bring the island back to life")
	# 7. A walk in Fernwood Forest.
	var walk := _forest_path()
	await _dip(func() -> void:
		_set_time(15, 0)
		_player.teleport_to(walk[0], walk[1]))
	Input.action_press(&"move_forward")
	await _follow_shot(5.0, Vector3(0.7, 2.6, 4.2), "Wander the woods")
	Input.action_release(&"move_forward")
	# 8. Rain over Moonlit Lake.
	await _dip(func() -> void:
		_set_time(16, 30)
		WeatherManager.set_weather(WeatherManager.Weather.RAIN)
		_player.teleport_to(_ground(-38.0, 34.0), 0.0))
	var lake := Vector3(IslandShape.LAKE_CENTER.x, IslandShape.LAKE_LEVEL, IslandShape.LAKE_CENTER.y)
	await _shot(4.0, lake + Vector3(-28, 5, 22), lake + Vector3(10, 1, -10), lake + Vector3(-22, 4, 16), lake + Vector3(14, 1, -12))
	# 9. Evening in the village: lanterns and home.
	await _dip(func() -> void:
		WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
		_set_time(20, 25))
	await _shot(4.5, village + Vector3(28, 10, 26), village + Vector3(0, 2, 0), village + Vector3(20, 7, 22), village + Vector3(-2, 2, -2), "Make friends, make it home")
	# 10. Night: the lighthouse shines again.
	await _dip(func() -> void:
		_set_time(22, 30)
		for i in 5:
			GameManager.set_flag(StringName("shard_%d" % (i + 1)))
		GameManager.set_flag(&"finale_lens")
		GameManager.set_flag(&"restored_lighthouse")
		GameManager.set_flag(&"lighthouse_lit"))
	var beam := _node_of_class("LighthouseBeam")
	var lh := beam.global_position if beam else Vector3(172, 30, -92)
	var away := Vector3(lh.x, 0, lh.z).direction_to(Vector3(0, 0, 40))
	await _shot(6.5, lh + away * 75.0 + Vector3(0, 14, 0) + away.cross(Vector3.UP) * 30.0, lh + Vector3(0, -4, 0),
		lh + away * 55.0 + Vector3(0, 10, 0) + away.cross(Vector3.UP) * 8.0, lh + Vector3(0, -2, 0), "Uncover Grandpa's secret")
	# 11. Title, over the island at night.
	await _dip(func() -> void: pass)
	_show_title()
	await _shot(8.0, Vector3(-120, 140, 300), Vector3(10, 0, 20), Vector3(60, 160, 310), Vector3(20, 0, 0))
	_fade_to(1.0, 1.6)
	await _wait(2.0)
	get_tree().quit()


# ---------------------------------------------------------------- shots

func _shot(seconds: float, from_pos: Vector3, from_look: Vector3, to_pos: Vector3, to_look: Vector3, caption: String = "") -> void:
	_cam_fn = func(e: float) -> void:
		_cam.look_at_from_position(from_pos.lerp(to_pos, e), from_look.lerp(to_look, e))
	await _play(seconds, caption)


## The camera rides along behind the player (offset in the player's facing frame).
func _follow_shot(seconds: float, offset: Vector3, caption: String = "") -> void:
	var visual := _player.get_node("Visual") as Node3D
	_cam_fn = func(e: float) -> void:
		var basis := Basis(Vector3.UP, visual.global_rotation.y)
		var o := offset.lerp(offset * Vector3(1.0, 0.85, 0.8), e)
		var head := _player.global_position + Vector3(0, 1.4, 0)
		var target := _player.global_position + Vector3(0, 1.1, 0) + basis * Vector3(0, 0, -6)
		var want := _player.global_position + basis * o
		# Slide in front of anything solid between the player and the camera.
		var query := PhysicsRayQueryParameters3D.create(head, want)
		query.exclude = [_player.get_rid()]
		var hit := _cam.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			want = head.lerp(hit.position, 0.85)
		_cam.look_at_from_position(want, target)
	await _play(seconds, caption)


func _play(seconds: float, caption: String) -> void:
	_shots_played += 1
	if _max_shots > 0 and _shots_played > _max_shots:
		get_tree().quit()
		await get_tree().create_timer(10.0).timeout
	_shot_time = 0.0
	_shot_length = seconds
	_caption.text = caption
	_cam_fn.call(0.0)
	var t := 0.0
	var snapped := false
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		_shot_time = t
		var e := smoothstep(0.0, 1.0, t / seconds)
		_cam_fn.call(e)
		var a := 0.0
		if caption != "":
			a = clampf(minf((t - 0.5) / CAPTION_FADE, (seconds - 0.3 - t) / CAPTION_FADE), 0.0, 1.0)
		_caption.modulate.a = a
		if _preview_dir != "" and not snapped and t >= seconds * 0.6:
			snapped = true
			_shot_index += 1
			get_viewport().get_texture().get_image().save_png(_preview_dir.path_join("shot_%02d.png" % _shot_index))
	_caption.modulate.a = 0.0


## A short dip to black to hide a change of time or place.
func _dip(change: Callable) -> void:
	_fade_to(1.0, 0.35)
	await _wait(0.4)
	change.call()
	await _frames(6)
	_fade_to(0.0, 0.45)


func _fade_to(alpha: float, seconds: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, seconds)


# ---------------------------------------------------------------- staging

func _warm_up() -> void:
	var looks := [
		[Vector3(-45, 9, 285), Vector3(-15, 8, 120)], [Vector3(-190, 95, 250), Vector3(-10, 0, 40)],
		[Vector3(-24, 13, 145), Vector3(0, 5, 115)], [Vector3(28, 14, 141), Vector3(0, 5, 115)],
		[Vector3(14, 6, 58), Vector3(10, 4, 35)], [Vector3(102, 11, 85), Vector3(115, 5, 70)],
		[Vector3(120, 10, 66), Vector3(140, 12, 48)], [Vector3(-100, 8, 10), Vector3(-115, 4, -20)],
		[Vector3(-18, 8, 37), Vector3(10, 3, 15)], [Vector3(-120, 140, 300), Vector3(10, 0, 20)],
	]
	var beam := _node_of_class("LighthouseBeam")
	if beam:
		var away := Vector3(beam.global_position.x, 0, beam.global_position.z).direction_to(Vector3(0, 0, 40))
		looks.append([beam.global_position + away * 60.0 + Vector3(0, 10, 0), beam.global_position])
	for time in [[9, 0], [20, 25], [22, 30]]:
		_set_time(time[0], time[1])
		for weather in [WeatherManager.Weather.SUNNY, WeatherManager.Weather.RAIN]:
			WeatherManager.set_weather(weather)
			for look: Array in looks:
				_cam.look_at_from_position(look[0], look[1])
				await _frames(3)
	WeatherManager.set_weather(WeatherManager.Weather.SUNNY)
	# The night lights and the lit lighthouse too (then back to the story's start).
	GameManager.set_flag(&"lighthouse_lit")
	for look: Array in looks:
		_cam.look_at_from_position(look[0], look[1])
		await _frames(2)
	GameManager.set_flag(&"lighthouse_lit", false)

func _set_time(hour: int, minute: int) -> void:
	_day -= 1
	ActivityClock.from_dict({"total_minutes": (_day - 1) * 1440 + hour * 60 + minute})


## Every garden bed planted and growing, some ready to harvest.
func _plant_the_garden() -> void:
	var field := _main.get_node_or_null("Island/Buildings/FarmField") as FarmField
	if field == null:
		return
	var crops := ["turnip", "carrot", "sunflower", "turnip", "carrot", "kale"]
	var i := 0
	for plot in field.get_plots():
		var crop := String(crops[i % crops.size()])
		var data := CropCatalog.shared().get_crop(StringName(crop))
		var full: int = data.get_grow_minutes() if data else 2000
		plot.from_dict({"tilled": true, "crop": crop, "growth": int(full * (0.55 + 0.15 * (i % 4))), "damp": 0})
		i += 1


func _fish() -> void:
	var fishing := _player.get_node("Fishing") as FishingController
	fishing.equip()
	await _wait(0.6)
	fishing.bite_wait_override = 1.6
	fishing.begin_charge()
	await _wait(0.9)
	fishing.release_cast(0.75)
	var waited := 0.0
	while fishing.state != FishingController.State.BITE and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if fishing.state == FishingController.State.BITE:
		await _wait(0.35)
		fishing.hook()
		while fishing.state == FishingController.State.REELING:
			fishing.reel_override = 1 if fishing.get_minigame().tension < 0.6 else 0
			await get_tree().process_frame


func _stop_fishing() -> void:
	var fishing := _player.get_node("Fishing") as FishingController
	fishing.reel_override = -1
	if fishing.is_busy():
		fishing.cancel()
	fishing.stow()
	_player.set_input_locked(false)


func _water_a_bed(bed: FarmPlot) -> void:
	InventoryManager.add_item(&"watering_can", 1)
	bed.from_dict({"tilled": true, "crop": "sunflower", "growth": 300, "damp": 0})
	await _wait(0.8)
	(_player.get_node("Farming") as FarmingController).use_plot(bed)


func _restore_later(flag: StringName, seconds: float) -> void:
	await _wait(seconds)
	GameManager.set_flag(flag)


func _show_title() -> void:
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(_title, "modulate:a", 1.0, 1.6)
	t.tween_property(_subtitle, "modulate:a", 1.0, 1.2)


# ---------------------------------------------------------------- helpers

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_caption = _label(54, Color(1.0, 0.97, 0.9))
	_caption.anchor_top = 0.74
	_caption.anchor_bottom = 0.9
	layer.add_child(_caption)
	_title = _label(150, Color(1.0, 0.94, 0.8))
	_title.text = "Life on the Island"
	_title.anchor_top = 0.3
	_title.anchor_bottom = 0.55
	_title.modulate.a = 0.0
	layer.add_child(_title)
	_subtitle = _label(48, Color(0.95, 0.92, 0.86))
	_subtitle.text = "Fish, farm and bring an island back to life, at your own pace."
	_subtitle.anchor_top = 0.56
	_subtitle.anchor_bottom = 0.75
	_subtitle.modulate.a = 0.0
	layer.add_child(_subtitle)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.05
	label.anchor_right = 0.95
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	return label


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, maxf(IslandShape.shared().get_height(x, z), IslandShape.SEA_LEVEL) + 0.3, z)


func _node_pos(node_name: String, fallback: Vector3) -> Vector3:
	var node := _main.find_child(node_name, true, false) as Node3D
	return node.global_position if node else fallback


func _node_of_class(class_id: String) -> Node3D:
	for node in _main.find_children("*", "Node3D", true, false):
		var s := node.get_script() as Script
		if s and s.get_global_name() == class_id:
			return node
	return null


## A point on a path through Fernwood Forest, and the way along it: [position, yaw].
func _forest_path() -> Array:
	var shape := IslandShape.shared()
	var best := Vector2(-95, 0)
	var best_d := INF
	var dir := Vector2(0, -1)
	for path in shape.paths:
		for j in path.size() - 1:
			var a: Vector2 = path[j]
			var b: Vector2 = path[j + 1]
			var mid := (a + b) * 0.5
			var d := mid.distance_to(IslandShape.FOREST_CENTER)
			if d < best_d and a.distance_to(b) > 8.0:
				best_d = d
				best = mid
				dir = (b - a).normalized()
	return [_ground(best.x, best.y), _yaw_of(Vector3(dir.x, 0, dir.y))]


func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
