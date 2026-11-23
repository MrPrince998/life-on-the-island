@tool
class_name FenceLine
extends Node3D
## Lays fence sections (a Tripo fence model) in a straight line from `from` to `to`
## (local positions), stretching them slightly so they fit exactly, with one collision box.

@export var segment: PackedScene
@export var from: Vector3 = Vector3.ZERO:
	set(value):
		from = value
		_rebuild()
@export var to: Vector3 = Vector3(4, 0, 0):
	set(value):
		to = value
		_rebuild()
## Size of one section in metres (model width 1 unit -> this many metres).
@export var section_length: float = 1.96
@export var section_scale: float = 2.0
@export var collision_height: float = 1.2

var _generated: Array[Node] = []


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() or segment == null:
		return
	for node in _generated:
		if is_instance_valid(node):
			node.queue_free()
	_generated.clear()
	var span := to - from
	var length := Vector2(span.x, span.z).length()
	if length < 0.1:
		return
	var count := maxi(1, int(round(length / section_length)))
	var stretch := length / (count * section_length)
	var yaw := atan2(-span.z, span.x)
	for i in count:
		var piece := segment.instantiate() as Node3D
		var centre := from.lerp(to, (i + 0.5) / count)
		piece.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(section_scale * stretch, section_scale, section_scale)), centre)
		add_child(piece)
		_generated.append(piece)
	if Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(length, collision_height, 0.25)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.transform = Transform3D(Basis(Vector3.UP, yaw), from.lerp(to, 0.5) + Vector3.UP * collision_height * 0.5)
	body.add_child(shape)
	add_child(body)
	_generated.append(body)
