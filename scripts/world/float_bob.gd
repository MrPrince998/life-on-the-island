extends Node3D
## Gently bobs and rocks a floating prop (a moored boat). Purely visual.

@export var bob_height: float = 0.05
@export var roll_degrees: float = 2.5
@export var speed: float = 0.9

var _base: Transform3D
var _time: float = 0.0


func _ready() -> void:
	_base = transform
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta * speed
	var bob := sin(_time) * bob_height
	var roll := deg_to_rad(sin(_time * 0.8 + 1.3) * roll_degrees)
	var pitch := deg_to_rad(sin(_time * 0.6) * roll_degrees * 0.5)
	transform = Transform3D(_base.basis * Basis.from_euler(Vector3(pitch, 0, roll)), _base.origin + Vector3(0, bob, 0))
