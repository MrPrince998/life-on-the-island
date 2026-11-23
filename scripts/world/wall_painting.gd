@tool
class_name WallPainting
extends Node3D
## A small framed painting of the island for the cottage walls (the "Island Paintings"
## upgrade). The picture is painted in code: soft sky, sea or fields, a sun. The canvas
## faces this node's +Z; place the node against a wall facing into the room.

enum Scene { SEA, LIGHTHOUSE, FIELDS }

@export var scene: Scene = Scene.SEA:
	set(value):
		scene = value
		if is_inside_tree():
			_build()
## Canvas size in metres (the frame adds a border round it).
@export var canvas_size: Vector2 = Vector2(0.62, 0.46):
	set(value):
		canvas_size = value
		if is_inside_tree():
			_build()

const FRAME := 0.06
const FRAME_COLOR := Color(0.42, 0.27, 0.15)
const PIXELS := Vector2i(96, 72)


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var box := BoxMesh.new()
	box.size = Vector3(canvas_size.x + FRAME * 2.0, canvas_size.y + FRAME * 2.0, 0.04)
	frame.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = FRAME_COLOR
	wood.roughness = 0.8
	frame.material_override = wood
	frame.position.z = 0.02
	add_child(frame)
	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	var quad := QuadMesh.new()
	quad.size = canvas_size
	canvas.mesh = quad
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = ImageTexture.create_from_image(_paint())
	paint.roughness = 0.9
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	canvas.material_override = paint
	canvas.position.z = 0.0405
	add_child(canvas)


## A little landscape: sky gradient, sun, then sea or fields, and the scene's subject.
func _paint() -> Image:
	var image := Image.create(PIXELS.x, PIXELS.y, false, Image.FORMAT_RGB8)
	var w := PIXELS.x
	var h := PIXELS.y
	var horizon := int(h * (0.55 if scene != Scene.FIELDS else 0.45))
	var sky_top := Color(0.55, 0.74, 0.9) if scene != Scene.LIGHTHOUSE else Color(0.32, 0.36, 0.62)
	var sky_low := Color(0.98, 0.86, 0.66) if scene != Scene.LIGHTHOUSE else Color(0.95, 0.62, 0.48)
	for y in h:
		for x in w:
			var c: Color
			if y < horizon:
				c = sky_top.lerp(sky_low, float(y) / horizon)
			elif scene == Scene.FIELDS:
				var t := float(y - horizon) / (h - horizon)
				var stripe := 0.06 * sin(x * 0.35 + y * 0.9)
				c = Color(0.48, 0.68, 0.3).lerp(Color(0.85, 0.72, 0.28), t * 0.6) * (1.0 + stripe)
			else:
				var t := float(y - horizon) / (h - horizon)
				var ripple := 0.05 * sin(x * 0.6 + y * 1.7)
				c = Color(0.25, 0.5, 0.66).lerp(Color(0.16, 0.34, 0.5), t) * (1.0 + ripple)
			image.set_pixel(x, y, c)
	# The sun (or the moon over the lighthouse at dusk).
	var sun := Vector2(w * 0.72, horizon * 0.45)
	_disc(image, sun, h * 0.09, Color(1.0, 0.92, 0.6) if scene != Scene.LIGHTHOUSE else Color(1.0, 0.97, 0.85))
	match scene:
		Scene.SEA:
			# A little island with a palm-green hill.
			_hill(image, Vector2(w * 0.3, horizon + 1), w * 0.22, h * 0.12, Color(0.4, 0.6, 0.32))
			_hill(image, Vector2(w * 0.3, horizon + 1), w * 0.26, h * 0.03, Color(0.92, 0.84, 0.62))
		Scene.LIGHTHOUSE:
			_hill(image, Vector2(w * 0.35, horizon + 2), w * 0.2, h * 0.14, Color(0.3, 0.38, 0.3))
			var base := Vector2i(int(w * 0.35), horizon - int(h * 0.12))
			for y in range(base.y - int(h * 0.3), base.y):
				for x in range(base.x - 3, base.x + 4):
					var band := int((base.y - y) / 5) % 2 == 0
					image.set_pixel(x, y, Color(0.92, 0.9, 0.86) if band else Color(0.78, 0.22, 0.2))
			_disc(image, Vector2(base.x + 0.5, base.y - h * 0.32), 3.0, Color(1.0, 0.86, 0.45))
		Scene.FIELDS:
			# A little red windmill on the hill.
			_hill(image, Vector2(w * 0.25, horizon + 2), w * 0.3, h * 0.1, Color(0.42, 0.62, 0.3))
			var mill := Vector2i(int(w * 0.25), horizon - int(h * 0.08))
			for y in range(mill.y - int(h * 0.14), mill.y):
				for x in range(mill.x - 3, mill.x + 4):
					image.set_pixel(x, y, Color(0.9, 0.86, 0.78))
			for k in 4:
				var dir := Vector2.from_angle(PI * 0.25 + k * PI * 0.5)
				for s in 12:
					var p := Vector2(mill.x, mill.y - h * 0.14) + dir * s
					if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
						image.set_pixel(int(p.x), int(p.y), Color(0.55, 0.36, 0.2))
	return image


static func _disc(image: Image, centre: Vector2, radius: float, color: Color) -> void:
	for y in range(int(centre.y - radius) - 1, int(centre.y + radius) + 2):
		for x in range(int(centre.x - radius) - 1, int(centre.x + radius) + 2):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and Vector2(x, y).distance_to(centre) <= radius:
				image.set_pixel(x, y, color)


static func _hill(image: Image, foot: Vector2, half_width: float, height: float, color: Color) -> void:
	for x in range(int(foot.x - half_width), int(foot.x + half_width) + 1):
		if x < 0 or x >= image.get_width():
			continue
		var t := (x - foot.x) / half_width
		var top := foot.y - height * (1.0 - t * t)
		for y in range(int(top), int(foot.y) + 1):
			if y >= 0 and y < image.get_height():
				image.set_pixel(x, y, color)
