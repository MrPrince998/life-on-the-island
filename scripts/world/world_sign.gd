@tool
class_name WorldSign
extends Node3D
## A readable timber sign: text is mounted on both faces and fitted inside the board.
const SIGN_FONT := preload("res://assets/ui/fonts/Fredoka.ttf")
const FONT_SIZE := 64
const FACE_Z := 0.071
@export_enum("Plain plaque", "Welcome model", "Signpost model") var model_style: int = 0
@export_multiline var text: String = "Island sign":
	set(value):
		text = value
		if is_node_ready():
			_update_text()
@export var board_size: Vector2 = Vector2(2.6, 0.9)
## Centre of the board above the sign's origin; 0 for a wall plaque.
@export var board_height: float = 1.7
@export_range(0, 2) var posts: int = 1
@export var snap_to_ground: bool = false
@export var back_text: String = ""
var _faces: Array[Label3D] = []
var _text_area := Vector2.ZERO
var _lettering_font: Font

func _ready() -> void:
	add_to_group(&"world_signs")
	if snap_to_ground and not Engine.is_editor_hint():
		global_position.y = IslandShape.shared().get_height(global_position.x, global_position.z)
	_build()

func _build() -> void:
	var lettering := FontVariation.new()
	lettering.base_font = SIGN_FONT
	lettering.variation_opentype = {2003265652: 700}
	_lettering_font = lettering
	_text_area = board_size
	if model_style != 0:
		_build_existing_model()
		return
	var dark := _material(Color(0.26, 0.14, 0.075))
	var wood := _material(Color(0.62, 0.42, 0.23))
	_box("Frame", Vector3(board_size.x + 0.12, board_size.y + 0.12, 0.12), Vector3(0, board_height, 0), dark)
	_box("Board", Vector3(board_size.x, board_size.y, 0.135), Vector3(0, board_height, 0), wood)
	for i in posts:
		var x := 0.0 if posts == 1 else (-1.0 if i == 0 else 1.0) * board_size.x * 0.35
		var height := maxf(board_height + board_size.y * 0.25, 0.1)
		_box("Post%d" % i, Vector3(0.12, height, 0.12), Vector3(x, height * 0.5, -0.015), dark)
	for side in 2:
		var label := Label3D.new()
		label.name = "FrontText" if side == 0 else "BackText"
		label.font = _lettering_font
		label.font_size = FONT_SIZE
		label.modulate = Color(1.0, 0.94, 0.77)
		label.outline_size = 0
		label.double_sided = false
		label.no_depth_test = false
		label.position = Vector3(0, board_height, FACE_Z if side == 0 else -FACE_Z)
		label.rotation.y = 0 if side == 0 else PI
		add_child(label)
		_faces.append(label)
	_update_text()

func _update_text() -> void:
	for i in _faces.size():
		var label := _faces[i]
		label.text = back_text if i % 2 == 1 and not back_text.is_empty() else text
		if model_style == 2:
			var planks := label.text.split("\n")
			label.text = _plank_lines(planks[mini(i / 2, planks.size() - 1)])
		var widest := 1.0
		var lines := label.text.split("\n")
		for line in lines:
			widest = maxf(widest, label.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
		var height := label.font.get_height(FONT_SIZE) * maxi(lines.size(), 1)
		label.pixel_size = minf(0.006, minf(maxf(_text_area.x - 0.08, 0.1) / widest, maxf(_text_area.y - 0.06, 0.1) / height))
		_update_engraving(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

func _box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)

func _build_existing_model() -> void:
	var asset: PackedScene = preload("res://source_assets/tripo/welcome_sign.glb") if model_style == 1 else preload("res://source_assets/tripo/signpost.glb")
	var model := asset.instantiate() as Node3D
	model.name = "Model"
	var factor := board_height / (0.66 if model_style == 1 else 0.58)
	model.scale = Vector3.ONE * factor
	add_child(model)
	if model_style == 2:
		_build_vines(factor)
	_text_area = Vector2(0.61, 0.25) * factor if model_style == 1 else Vector2(0.26, 0.105) * factor
	var centers: Array = [Vector3(0, 0.66, 0.078)] if model_style == 1 else [Vector3(-0.012, 0.785, 0.105), Vector3(-0.055, 0.581, 0.105), Vector3(0.027, 0.405, 0.108)]
	for plank in centers.size():
		for side in 2:
			var label := Label3D.new()
			label.name = ("FrontText" if side == 0 else "BackText") + (str(plank) if plank > 0 else "")
			label.font = _lettering_font
			label.font_size = FONT_SIZE
			label.modulate = Color(0.24, 0.12, 0.055)
			label.outline_size = 0
			label.double_sided = false
			label.position = centers[plank] * factor
			if model_style == 2:
				# Follow the slope of each carved plank; keep clear of the arrow tips.
				label.rotation.z = deg_to_rad([-3.0, 5.0, 4.0][plank])
			if side == 1:
				label.position.z = (0.018 if model_style == 1 else -0.145) * factor
				label.rotation.y = PI
			add_child(label)
			_faces.append(label)
	# Preserve a physical obstacle for the existing freestanding model.
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.95, 0.18) * factor
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	add_child(body)
	_update_text()

## Balance long names across two lines instead of shrinking them into a thin strip.
func _plank_lines(value: String) -> String:
	if value.length() <= 15:
		return value
	var words := value.split(" ")
	var best := value
	var best_width := INF
	for split in range(1, words.size()):
		var first := " ".join(words.slice(0, split))
		var second := " ".join(words.slice(split))
		var width := maxf(_lettering_font.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x, _lettering_font.get_string_size(second, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
		if width < best_width:
			best_width = width
			best = first + "\n" + second
	return best

## Small, deterministic 3D ivy follows the post and outer edge, outside the lettering.
func _build_vines(factor: float) -> void:
	var ivy := Node3D.new()
	ivy.name = "Vines"
	ivy.scale = Vector3.ONE * factor
	add_child(ivy)
	var stem_material := _material(Color(0.34, 0.29, 0.10))
	var leaves: Array[StandardMaterial3D] = []
	for color in [Color(0.43, 0.40, 0.13), Color(0.51, 0.46, 0.17), Color(0.35, 0.33, 0.11)]:
		var material := _material(color)
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.88
		leaves.append(material)
	var paths: Array[PackedVector3Array] = []
	var climbing := PackedVector3Array()
	for i in 15:
		var y := 0.025 + i * 0.022
		var angle := i * 0.48
		climbing.append(Vector3(sin(angle) * 0.075, y, cos(angle) * 0.075 + 0.04))
	paths.append(climbing)
	# A trailing sprig curls over the upper-left rim, never across a word.
	paths.append(PackedVector3Array([Vector3(0, 0.91, -0.04), Vector3(-0.08, 0.90, -0.02), Vector3(-0.17, 0.87, 0.07), Vector3(-0.205, 0.84, 0.15), Vector3(-0.22, 0.79, 0.15), Vector3(-0.225, 0.74, 0.14), Vector3(-0.21, 0.69, 0.13), Vector3(-0.23, 0.65, 0.12)]))
	var leaf_mesh := _curved_leaf_mesh()
	var leaf_index := 0
	for control_points in paths:
		var curve := Curve3D.new()
		curve.bake_interval = 0.012
		for point in control_points.size():
			var tangent := (control_points[mini(point + 1, control_points.size() - 1)] - control_points[maxi(point - 1, 0)]) * 0.18
			curve.add_point(control_points[point], -tangent, tangent)
		var path := curve.get_baked_points()
		for i in range(1, path.size()):
			var start := path[i - 1]
			var end := path[i]
			var segment := MeshInstance3D.new()
			var stem := CylinderMesh.new()
			stem.top_radius = 0.002
			stem.bottom_radius = 0.003
			stem.height = start.distance_to(end)
			stem.radial_segments = 8
			segment.mesh = stem
			segment.material_override = stem_material
			ivy.add_child(segment)
			segment.position = (start + end) * 0.5
			var direction := (end - start).normalized()
			segment.quaternion = Quaternion(Vector3.UP, direction)
			if i % 3 == 0:
				var leaf := MeshInstance3D.new()
				leaf.mesh = leaf_mesh
				leaf.material_override = leaves[leaf_index % leaves.size()]
				ivy.add_child(leaf)
				leaf.position = end
				leaf.rotation = Vector3(-0.35 + sin(leaf_index * 2.1) * 0.55, sin(leaf_index * 1.7) * 0.85, (-0.9 if leaf_index % 2 == 0 else 0.9))
				leaf.scale = Vector3.ONE * (0.8 + 0.15 * (leaf_index % 3))
				leaf_index += 1

## A shallow inset treatment: a lit lower cut edge, a dark upper lip, and
## translucent wood-brown grooves. Children inherit each board's exact angle.
## This is a visual engraving effect; the original GLB geometry stays intact.
func _update_engraving(label: Label3D) -> void:
	label.modulate = Color(0.94, 0.80, 0.57) if model_style == 0 else Color(0.32, 0.18, 0.075, 0.88)
	for layer in 2:
		var node_name := "CutHighlight" if layer == 0 else "CutShadow"
		var edge := label.get_node_or_null(NodePath(node_name)) as Label3D
		if edge == null:
			edge = Label3D.new()
			edge.name = node_name
			edge.outline_size = 0
			edge.double_sided = false
			edge.no_depth_test = false
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			label.add_child(edge)
		edge.font = label.font
		edge.font_size = label.font_size
		edge.text = label.text
		edge.pixel_size = label.pixel_size
		edge.modulate = Color(0.95, 0.72, 0.43, 0.7) if layer == 0 else Color(0.12, 0.065, 0.025, 0.68)
		var shift := 1.7 if layer == 0 else -0.55
		edge.position = Vector3(shift * label.pixel_size, -shift * label.pixel_size, -0.0004 if layer == 0 else -0.0002)
		edge.render_priority = -2 if layer == 0 else -1

## Closed, curved leaf volume with a lighter midrib and a darker underside.
## The ring cross-sections give silhouettes real thickness from oblique views.
func _curved_leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS := 10
	const SIDES := 12
	var vertices: Array[Vector3] = []
	var colors: Array[Color] = []
	for ring in range(RINGS + 1):
		var t := float(ring) / RINGS
		var profile := pow(sin(PI * t), 0.85)
		for side in SIDES:
			var angle := TAU * side / SIDES
			var arch := 0.014 * sin(PI * t) - 0.012 * t * t
			vertices.append(Vector3(cos(angle) * 0.019 * profile, t * 0.06, arch + sin(angle) * 0.0045 * profile))
			var upper := maxf(sin(angle), 0.0)
			colors.append(Color(0.72, 0.67, 0.49).lerp(Color(1.12, 1.08, 0.86), upper))
	for ring in RINGS:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := (ring + 1) * SIDES + side
			var c := ring * SIDES + (side + 1) % SIDES
			var d := (ring + 1) * SIDES + (side + 1) % SIDES
			for index in [a, b, c, c, b, d]:
				surface.set_color(colors[index])
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()
