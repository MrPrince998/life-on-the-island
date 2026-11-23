class_name Minimap
extends Control
## Round, north-up minimap for the top-left corner.
##
## The island map is painted once (in a background thread) from IslandShape: sea, lake,
## sand, grass, forest, hills, rock and paths, with soft hill shading. The minimap shows
## the area around the player with an arrow for the player, a soft cone for where the
## camera looks, and icons for important places (clamped to the rim when far away).
## Purely visual: never changes game state or time.

## Part of the world the map image covers (metres, x/z), and its resolution.
const MAP_WORLD_MIN := Vector2(-256.0, -256.0)
const MAP_WORLD_SIZE := 512.0
const MAP_RESOLUTION := 384
## Radius of the area shown around the player (metres).
@export var view_radius: float = 70.0
## Width of the wooden ring around the map (pixels).
const RING := 9.0

## Places shown on the map: [node path under Island/Buildings, icon].
const LANDMARKS := [
	["Cottage", "house"], ["GeneralStore", "coin"], ["FishingDock", "fish"],
	["FarmField", "leaf"], ["Lighthouse", "lighthouse"],
]

var _map_view: ColorRect
var _overlay: Control
var _material := ShaderMaterial.new()
var _player: Node3D
var _visual: Node3D
var _camera_rig: Node
var _landmarks: Array = []  # [Node3D, Texture2D]
var _task_id: int = -1
var _image: Image
var _map_ready: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view = ColorRect.new()
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.offset_left = RING
	_map_view.offset_top = RING
	_map_view.offset_right = -RING
	_map_view.offset_bottom = -RING
	_material.shader = preload("res://shaders/minimap.gdshader")
	_material.set_shader_parameter(&"sea_color", MAP_SEA_DEEP)
	_material.set_shader_parameter(&"blank_color", UIPalette.PARCHMENT)
	_map_view.material = _material
	add_child(_map_view)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_task_id = WorkerThreadPool.add_task(_paint_map, false, "Paint minimap")
	_find_world.call_deferred()


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func is_map_ready() -> bool:
	return _map_ready


func _find_world() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player == null:
		return
	_visual = _player.get_node_or_null("Visual") as Node3D
	_camera_rig = _player.get_node_or_null("CameraRig")
	var buildings := _player.get_parent().get_node_or_null("Island/Buildings")
	if buildings == null:
		return
	for entry in LANDMARKS:
		var node := buildings.get_node_or_null(entry[0]) as Node3D
		if node:
			_landmarks.append([node, UIPalette.icon(entry[1])])


func _process(_delta: float) -> void:
	if not _map_ready and _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_material.set_shader_parameter(&"map_tex", ImageTexture.create_from_image(_image))
		_material.set_shader_parameter(&"map_ready", true)
		_map_ready = true
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player.global_position
	_material.set_shader_parameter(&"center_uv", (Vector2(p.x, p.z) - MAP_WORLD_MIN) / MAP_WORLD_SIZE)
	_material.set_shader_parameter(&"span", view_radius * 2.0 / MAP_WORLD_SIZE)
	_overlay.queue_redraw()


## Where a world position appears on the minimap (pixels, in this control).
## `clamped` is true when it lies outside the shown area and was pulled to the rim.
func world_to_minimap(world: Vector3) -> Dictionary:
	var center := size * 0.5
	var radius := size.x * 0.5 - RING
	var offset := Vector2(world.x - _player.global_position.x, world.z - _player.global_position.z) * (radius / view_radius)
	var limit := radius - 13.0
	var clamped := offset.length() > limit
	if clamped:
		offset = offset.normalized() * limit
	return {"position": center + offset, "clamped": clamped}


func _draw_overlay() -> void:
	var center := size * 0.5
	var outer := size.x * 0.5
	var radius := outer - RING
	# Wooden ring with a cream inner line, and a little "N" plate at the top.
	_overlay.draw_circle(center, outer - RING * 0.5, UIPalette.WOOD, false, RING, true)
	_overlay.draw_circle(center, outer - 1.0, UIPalette.WOOD_DARK, false, 2.0, true)
	_overlay.draw_circle(center, radius + 1.0, Color(UIPalette.CREAM, 0.8), false, 2.0, true)
	if _player == null or not is_instance_valid(_player):
		return

	# Camera view cone.
	if _camera_rig and _camera_rig.has_method(&"get_yaw"):
		var yaw: float = _camera_rig.call(&"get_yaw")
		var look := Vector2(-sin(yaw), -cos(yaw))
		var cone := PackedVector2Array([center])
		for i in 9:
			var a := deg_to_rad(-35.0 + 70.0 * i / 8.0)
			cone.append(center + look.rotated(a) * radius * 0.55)
		_overlay.draw_colored_polygon(cone, Color(UIPalette.CREAM, 0.28))

	# Landmarks (smaller and faded when pulled to the rim).
	for entry in _landmarks:
		var node := entry[0] as Node3D
		if not is_instance_valid(node):
			continue
		var spot := world_to_minimap(node.global_position)
		var r := 9.0 if spot.clamped else 12.0
		var pos: Vector2 = spot.position
		_overlay.draw_circle(pos, r + 1.5, UIPalette.WOOD_DARK, true, -1.0, true)
		_overlay.draw_circle(pos, r, UIPalette.CREAM if not spot.clamped else Color(UIPalette.CREAM, 0.85), true, -1.0, true)
		var icon := entry[1] as Texture2D
		if icon:
			var s := r * 1.45
			_overlay.draw_texture_rect(icon, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false)

	# The player: a honey arrow pointing where the character faces.
	var facing := Vector2(0, -1)
	if _visual:
		var f := -_visual.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			facing = Vector2(f.x, f.z).normalized()
	var side := facing.orthogonal()
	var arrow := PackedVector2Array([
		center + facing * 11.0, center - facing * 7.0 + side * 7.5,
		center - facing * 3.5, center - facing * 7.0 - side * 7.5,
	])
	_overlay.draw_colored_polygon(arrow, UIPalette.HONEY)
	arrow.append(arrow[0])
	_overlay.draw_polyline(arrow, UIPalette.WOOD_DARK, 2.0, true)

	# North marker on the ring.
	var font := get_theme_font(&"font", &"KeyLabel")
	var n_pos := center + Vector2(0, -(outer - RING * 0.5))
	_overlay.draw_circle(n_pos, 10.0, UIPalette.CREAM, true, -1.0, true)
	_overlay.draw_circle(n_pos, 10.0, UIPalette.WOOD_DARK, false, 2.0, true)
	if font:
		_overlay.draw_string(font, n_pos + Vector2(-5.5, 5.5), "N", HORIZONTAL_ALIGNMENT_CENTER, 11.0, 14, UIPalette.WOOD_DARK)


# ---- Painting the island map (runs in a worker thread) ------------------------

const MAP_SEA_DEEP := Color("3e8fb0")
const MAP_SEA_SHALLOW := Color("7cc3dc")
const MAP_LAKE := Color("5aa9cb")
const MAP_LAKE_SHALLOW := Color("8fd0e3")
const MAP_SAND := Color("ecd9a6")
const MAP_GRASS := Color("9fc86c")
const MAP_GRASS_HIGH := Color("7fae5a")
const MAP_FOREST := Color("5f8f4b")
const MAP_ROCK := Color("a79d8b")
const MAP_PATH := Color("c99f68")
const MAP_COAST_LINE := Color("5a3a22")


func _paint_map() -> void:
	var shape := IslandShape.shared()
	var n := MAP_RESOLUTION
	var step := MAP_WORLD_SIZE / n
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for y in n:
		for x in n:
			var w := MAP_WORLD_MIN + Vector2(x + 0.5, y + 0.5) * step
			heights[y * n + x] = shape.get_height(w.x, w.y)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var light := Vector3(-0.55, 0.75, -0.4).normalized()
	for y in n:
		for x in n:
			var h := heights[y * n + x]
			var w := MAP_WORLD_MIN + Vector2(x + 0.5, y + 0.5) * step
			var c := _ground_color(shape, w, h)
			# Hill shading from the height grid.
			var hx := heights[y * n + mini(x + 1, n - 1)] - heights[y * n + maxi(x - 1, 0)]
			var hz := heights[mini(y + 1, n - 1) * n + x] - heights[maxi(y - 1, 0) * n + x]
			var normal := Vector3(-hx, 2.0 * step * 2.0, -hz).normalized()
			if h > IslandShape.SEA_LEVEL:
				c = c * clampf(0.78 + 0.32 * normal.dot(light), 0.7, 1.12)
			# Ink outline along the coast for a storybook look.
			if absf(h - IslandShape.SEA_LEVEL) < 0.35:
				c = c.lerp(MAP_COAST_LINE, 0.45)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_image = img


func _ground_color(shape: IslandShape, w: Vector2, h: float) -> Color:
	if h < IslandShape.SEA_LEVEL:
		return MAP_SEA_DEEP.lerp(MAP_SEA_SHALLOW, clampf(1.0 + h / 6.0, 0.0, 1.0))
	var lake_d := shape.get_lake_distance(w)
	if lake_d < 1.3 and h < IslandShape.LAKE_LEVEL:
		return MAP_LAKE.lerp(MAP_LAKE_SHALLOW, clampf(1.0 - (IslandShape.LAKE_LEVEL - h) / 2.0, 0.0, 1.0))
	var c := MAP_GRASS.lerp(MAP_GRASS_HIGH, clampf((h - 4.0) / 14.0, 0.0, 1.0))
	var forest := 1.0 - smoothstep(IslandShape.FOREST_RADIUS * 0.55, IslandShape.FOREST_RADIUS, w.distance_to(IslandShape.FOREST_CENTER))
	c = c.lerp(MAP_FOREST, forest * 0.75)
	if h > 22.0:
		c = c.lerp(MAP_ROCK, clampf((h - 22.0) / 8.0, 0.0, 0.7))
	var sand := 1.0 - smoothstep(1.3, 2.6, h)
	if lake_d < 1.3:
		sand = maxf(sand, 1.0 - smoothstep(0.15, 0.7, h - IslandShape.LAKE_LEVEL))
	c = c.lerp(MAP_SAND, sand)
	var dirt := 1.0 - smoothstep(IslandShape.PATH_HALF_WIDTH * 0.7, IslandShape.PATH_HALF_WIDTH * 1.5, shape.distance_to_paths(w))
	dirt = maxf(dirt, 1.0 - smoothstep(9.0, 13.0, w.distance_to(IslandShape.VILLAGE_CENTER)))
	dirt = maxf(dirt, 1.0 - smoothstep(IslandShape.FARM_RADIUS * 0.5, IslandShape.FARM_RADIUS * 0.62, w.distance_to(IslandShape.FARM_CENTER)))
	return c.lerp(MAP_PATH, dirt)
