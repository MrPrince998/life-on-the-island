extends SceneTree
## Dev tool: renders front and side previews of Tripo models to PNG files.
## Run: Godot --path . --script res://tools/preview_models.gd -- <out_dir> name1 name2

var _frames := 0
var _shots: Array = []
var _cam: Camera3D
var _holder: Node3D
var _out := ""

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	for i in range(1, args.size()):
		for side in ["front", "side"]:
			_shots.append([args[i], side])
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	get_root().add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 1.3
	get_root().add_child(_cam)
	_holder = Node3D.new()
	get_root().add_child(_holder)
	get_root().size = Vector2i(640, 640)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames % 6 == 1:
		if _frames > 1:
			var prev = _shots.pop_front()
			get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, prev[0], prev[1]])
		if _shots.is_empty():
			return true
		for c in _holder.get_children(): c.free()
		var s = _shots[0]
		_holder.add_child((load("res://source_assets/tripo/%s.glb" % s[0]) as PackedScene).instantiate())
		if s[1] == "front":
			_cam.position = Vector3(0, 0.5, 3); _cam.rotation = Vector3.ZERO
		else:
			_cam.position = Vector3(3, 0.5, 0); _cam.rotation = Vector3(0, PI / 2, 0)
	return false
