class_name Footsteps
extends Node3D
## Footstep sounds that match the ground underfoot: grass, earth paths, sand, wooden
## boards, stone, shallow water and (while it snows) snow.
##
## Add it as a child of the player or a villager. Each step is heard the moment a foot
## touches down in the walk or run animation (found from the skeleton's foot bones), so
## the sound always lands with the feet at any speed. Footsteps never move the clock.

signal stepped(surface: StringName, landing: bool)

const SURFACES: Array[StringName] = [&"grass", &"dirt", &"sand", &"wood", &"stone", &"water", &"snow"]
const VARIANTS := 4
## Per-surface balance (dB): the hard surfaces are a touch quieter than the soft ones.
const SURFACE_DB := {
	&"grass": -1.0, &"dirt": 0.0, &"sand": 0.0, &"wood": -1.0,
	&"stone": -3.0, &"water": 0.0, &"snow": -1.0,
}
## A foot has landed when it drops to within this of the lowest it goes (metres)...
const LAND_BELOW := 0.025
## ...having first lifted at least this far.
const LIFT_ABOVE := 0.06
## Without a skeleton, one step every this many metres.
const FALLBACK_STRIDE := 0.62
## Slowest movement that makes footsteps (m/s).
const MIN_SPEED := 0.35
## Faster than this counts as running: heavier steps.
const RUN_SPEED := 2.4
## Falling at least this fast (m/s) gives a landing thump.
const LANDING_SPEED := 3.0

## NPCs: true (heard from where they are). The player: false (always close to the camera).
@export var positional: bool = false
@export var base_db: float = -14.0
@export var run_db: float = 3.0
@export var landing_db: float = 5.0

static var _streams: Dictionary = {}

var step_count: int = 0
var last_surface: StringName = &""

var _body: Node3D
var _audio: Node
var _skeleton: Skeleton3D
var _feet: PackedInt32Array = []
var _lowest: PackedFloat32Array = []
var _armed: Array[bool] = []
var _last_position: Vector3
var _speed: float = 0.0
var _distance: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0


func _ready() -> void:
	name = "Footsteps"
	_body = get_parent() as Node3D
	if positional:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_distance = 24.0
		p.max_polyphony = 3
		p.bus = &"Effects"
		_audio = p
	else:
		var p := AudioStreamPlayer.new()
		p.max_polyphony = 3
		p.bus = &"Effects"
		_audio = p
	_audio.name = "StepPlayer"
	add_child(_audio)
	if _body:
		_last_position = _body.global_position


static func stream_for(surface: StringName) -> AudioStream:
	if not _streams.has(surface):
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		r.random_pitch = 1.08
		r.random_volume_offset_db = 2.0
		for v in VARIANTS:
			var s := load("res://assets/audio/footsteps/%s_%d.wav" % [surface, v + 1]) as AudioStream
			if s:
				r.add_stream(-1, s)
		_streams[surface] = r
	return _streams[surface]


## What the ground is like at `point` (a foot position). `from` is any node in the world;
## its own collision body (if any) is ignored.
static func surface_at(from: Node3D, point: Vector3) -> StringName:
	var tree := from.get_tree()
	if WaterBody.deepest_at(tree, point + Vector3.UP * 0.05) > 0.08:
		return &"water"
	var collider: Object = null
	if from.is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4, point + Vector3.DOWN * 0.8)
		query.collide_with_areas = false
		var exclude: Array[RID] = []
		var n: Node = from
		while n:
			if n is CollisionObject3D:
				exclude.append((n as CollisionObject3D).get_rid())
				break
			n = n.get_parent()
		query.exclude = exclude
		var hit := from.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			collider = hit.collider
	if collider and not _is_terrain(collider):
		return _object_surface(collider as Node)
	if WeatherManager.is_snowing() and not InteriorRoom.is_indoors(tree, point):
		return &"snow"
	return terrain_surface(point.x, point.z)


## The island's own ground at (x, z), from the same paint weights the terrain uses.
static func terrain_surface(x: float, z: float) -> StringName:
	var shape := IslandShape.shared()
	var h := shape.get_height(x, z)
	var w := shape.get_surface_weights(x, z, h, shape.get_normal(x, z))
	if w.g > 0.5:
		return &"stone"
	if w.b > 0.5:
		return &"dirt"
	if w.r > 0.5:
		return &"sand"
	return &"grass"


static func _is_terrain(collider: Object) -> bool:
	var node := collider as Node
	return node != null and node.get_parent() is IslandTerrain


## Built things: an explicit "footstep_surface" meta wins, then stone-ish or earthy names;
## everything else that is built (docks, jetty, bridge, porches, floors) is wood.
static func _object_surface(node: Node) -> StringName:
	var n := node
	for i in 6:
		if n == null:
			break
		if n.has_meta(&"footstep_surface"):
			return StringName(n.get_meta(&"footstep_surface"))
		if n is StoneSteps:
			return &"stone"
		var lower := String(n.name).to_lower()
		for word in ["stone", "rock", "boulder", "cliff", "well", "lighthouse", "vegetation"]:
			if lower.contains(word):
				return &"stone"
		for word in ["soil", "mound", "field"]:
			if lower.contains(word):
				return &"dirt"
		n = n.get_parent()
	return &"wood"


func _physics_process(delta: float) -> void:
	if _body == null or delta <= 0.0:
		return
	var moved := _body.global_position - _last_position
	_last_position = _body.global_position
	var character := _body as CharacterBody3D
	if character:
		_speed = Vector2(character.velocity.x, character.velocity.z).length()
	else:
		var flat := Vector2(moved.x, moved.z).length()
		# A big jump in one frame is a teleport, not walking.
		_speed = 0.0 if flat > 2.0 else flat / delta
	if not _body.is_visible_in_tree():
		return
	var on_floor := character.is_on_floor() if character else true
	if character and not on_floor:
		_fall_speed = maxf(_fall_speed, -character.velocity.y)
		_disarm()
	elif character and not _was_on_floor:
		if _fall_speed >= LANDING_SPEED:
			play_step(true)
		_fall_speed = 0.0
		_disarm()
	_was_on_floor = on_floor
	if not on_floor or _speed < MIN_SPEED or _is_seated():
		_distance = 0.0
		return
	if _skeleton == null or not is_instance_valid(_skeleton):
		_find_feet()
	if _feet.is_empty():
		_distance += _speed * delta
		if _distance >= FALLBACK_STRIDE:
			_distance -= FALLBACK_STRIDE
			play_step(false)
		return
	for k in _feet.size():
		var h := (_skeleton.global_transform * _skeleton.get_bone_global_pose(_feet[k])).origin.y - _body.global_position.y
		# Remember how low the foot goes; let it drift up slowly in case the pose changes.
		_lowest[k] = minf(_lowest[k] + 0.02 * delta, h)
		if h > _lowest[k] + LIFT_ABOVE:
			_armed[k] = true
		elif _armed[k] and h < _lowest[k] + LAND_BELOW:
			_armed[k] = false
			play_step(false)


## Plays one footstep (or a landing) for the ground under the body right now.
func play_step(landing: bool) -> void:
	if _body == null:
		return
	var surface := surface_at(_body, _body.global_position)
	last_surface = surface
	step_count += 1
	var db := base_db + float(SURFACE_DB.get(surface, 0.0))
	if _speed > RUN_SPEED:
		db += run_db
	if landing:
		db += landing_db
	_audio.set(&"stream", stream_for(surface))
	_audio.set(&"volume_db", db)
	_audio.set(&"pitch_scale", 0.85 if landing else 1.0)
	_audio.call(&"play")
	stepped.emit(surface, landing)


func get_speed() -> float:
	return _speed


func _is_seated() -> bool:
	return _body.has_method(&"is_sitting") and bool(_body.call(&"is_sitting"))


func _disarm() -> void:
	for k in _armed.size():
		_armed[k] = false


func _find_feet() -> void:
	_feet.clear()
	_lowest.clear()
	_armed.clear()
	var found := _body.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_skeleton = found[0] as Skeleton3D
	for i in _skeleton.get_bone_count():
		var bone := _skeleton.get_bone_name(i)
		if bone.ends_with("LeftFoot") or bone.ends_with("RightFoot"):
			_feet.append(i)
			_lowest.append(INF)
			_armed.append(false)
