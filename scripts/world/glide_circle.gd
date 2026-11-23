class_name GlideCircle
extends Node3D
## Moves this node slowly round a circle, banking gently: gliding seagulls.
## Purely ambient; real-time and never touches the activity clock.

@export var radius: float = 14.0
## Degrees per second (negative = clockwise).
@export var speed_degrees: float = 9.0
@export var bob_height: float = 0.8
@export var start_degrees: float = 0.0

var _center: Vector3
var _angle: float


func _ready() -> void:
	_center = position
	_angle = deg_to_rad(start_degrees)
	_place()


func _process(delta: float) -> void:
	_angle += deg_to_rad(speed_degrees) * delta
	_place()


func _place() -> void:
	var offset := Vector3(cos(_angle), 0.0, sin(_angle)) * radius
	position = _center + offset + Vector3.UP * sin(_angle * 2.0) * bob_height
	# Face along the direction of travel, leaning into the turn.
	var forward := Vector3(-sin(_angle), 0.0, cos(_angle)) * signf(speed_degrees)
	basis = Basis.looking_at(forward, Vector3.UP, true).rotated(forward.normalized(), -0.25 * signf(speed_degrees))
