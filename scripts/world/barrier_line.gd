class_name BarrierLine
extends Node3D
## A line you can't walk through: one of IslandShape's barrier lines (the bramble
## hedge).
##
## VegetationScatter plants its bushes and rocks; this node adds the solid part:
## a wall down the middle of the band. Where a story path crosses it there is a gate:
## that bit of wall stays shut until `gate_flag` is set (clearing the brambles), then
## opens. Walking into the barrier shows a gentle hint now and then.
## Built in code from IslandShape, like the terrain.

## Which IslandShape barrier line this is (&"brambles").
@export var barrier_id: StringName = &"brambles"
## The story flag that opens the gate (empty = no gate).
@export var gate_flag: StringName = &""
## Where the path crosses the line (world x, z). Only used with a gate_flag.
@export var gate_center: Vector2 = Vector2.ZERO
@export_multiline var hint: String = ""

## Wall pieces follow the line in steps of at most this length (metres).
const PIECE_LENGTH := 4.0
## The wall reaches this far below and above the ground.
const BELOW := 3.0
const ABOVE := 6.0
const THICKNESS := 1.4
## The hint zone reaches this far out from the wall on each side.
const HINT_REACH := 1.6
const HINT_COOLDOWN := 30.0

var _wall: StaticBody3D
var _gate: StaticBody3D
var _hint_area: Area3D
var _hint_cooldown := 0.0


func _ready() -> void:
	build()
	GameManager.flag_changed.connect(func(flag: StringName, _value: bool) -> void:
		if flag == gate_flag:
			_update_gate())


func _process(delta: float) -> void:
	_hint_cooldown = maxf(_hint_cooldown - delta, 0.0)


## Number of solid wall pieces, gate included (used by tests).
func get_piece_count() -> int:
	return (_wall.get_child_count() if _wall else 0) + (_gate.get_child_count() if _gate else 0)


## True while the gate's bit of wall still blocks the path.
func is_gate_shut() -> bool:
	return _gate != null and _gate.get_child_count() > 0 and _gate.collision_layer != 0


## The plants filling the gate's gap (hidden once it's cleared).
func get_gate_plants() -> Array[Node]:
	return get_tree().get_nodes_in_group(StringName("barrier_gate_" + str(barrier_id)))


func build() -> void:
	for child in get_children():
		child.queue_free()
	var shape := IslandShape.shared()
	_wall = _make_body("Wall")
	_gate = _make_body("Gate")
	_hint_area = Area3D.new()
	_hint_area.name = "Hint"
	_hint_area.collision_layer = 0
	_hint_area.collision_mask = 2  # the player
	_hint_area.monitorable = false
	_hint_area.body_entered.connect(_on_body_entered)
	var line := shape.get_barrier_line(barrier_id)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var pieces := maxi(int(ceil(a.distance_to(b) / PIECE_LENGTH)), 1)
		for k in pieces:
			var from := a.lerp(b, float(k) / pieces)
			var to := a.lerp(b, float(k + 1) / pieces)
			var mid := (from + to) * 0.5
			# Lowest ground under the piece, so it never floats above a dip.
			var ground := minf(shape.get_height(mid.x, mid.y), minf(shape.get_height(from.x, from.y), shape.get_height(to.x, to.y)))
			var length := from.distance_to(to) + 0.6  # overlap, so there are no gaps at bends
			var basis := Basis(Vector3.UP, atan2(to.x - from.x, to.y - from.y))
			var wall := _box(Vector3(THICKNESS, BELOW + ABOVE, length), Transform3D(basis, Vector3(mid.x, ground - BELOW + (BELOW + ABOVE) * 0.5, mid.y)))
			if gate_flag != &"" and mid.distance_to(gate_center) < IslandShape.BARRIER_GATE_RADIUS:
				_gate.add_child(wall)
				continue  # no hint on the path itself
			_wall.add_child(wall)
			_hint_area.add_child(_box(Vector3(THICKNESS + HINT_REACH * 2.0, 4.0, length), Transform3D(basis, Vector3(mid.x, ground + 1.5, mid.y))))
	add_child(_wall)
	add_child(_gate)
	add_child(_hint_area)
	_update_gate.call_deferred()


func _make_body(body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	return body


func _update_gate() -> void:
	var open := gate_flag != &"" and GameManager.has_flag(gate_flag)
	if _gate:
		_gate.collision_layer = 0 if open else 1
	# The plants that fill the gap (planted by VegetationScatter) go once it's cleared.
	for node in get_tree().get_nodes_in_group(StringName("barrier_gate_" + str(barrier_id))):
		(node as Node3D).visible = not open


func _box(size: Vector3, xform: Transform3D) -> CollisionShape3D:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.transform = xform
	return shape


func _on_body_entered(body: Node3D) -> void:
	if hint != "" and body.is_in_group(&"player") and _hint_cooldown <= 0.0:
		_hint_cooldown = HINT_COOLDOWN
		GameManager.notify(hint)
