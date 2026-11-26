class_name WoodcuttingController
extends Node
## The player's axe work: shows the axe in the right hand and swings it at a tree
## (felling) or a fallen trunk (cutting it into logs). Lives on the player as "Woodcutting".
## The ForestService decides what happens on each hit; this only does the swinging.
## Swinging itself costs no time: the ForestService charges the activity when it's done.

signal swing_hit(index: int, at: Vector3)

const AXE := &"axe"
const STEEL_AXE := &"steel_axe"
## One swing (the farm_swing clip); the blade bites at HIT_TIME.
const SWING_LENGTH := 1.25
const HIT_TIME := 0.55

var _player: PlayerController
var _animator: CharacterAnimator
var _skeleton: Skeleton3D
var _hand_bone := -1
var _axe: Node3D
var _swinging := false
var _swing_time := 0.0
var _chips: CPUParticles3D


## The best axe in the bag (&"" when there is none).
static func best_axe() -> StringName:
	if InventoryManager.has_item(STEEL_AXE):
		return STEEL_AXE
	if InventoryManager.has_item(AXE):
		return AXE
	return &""


static func has_axe() -> bool:
	return best_axe() != &""


## Swings needed for `hits` at the layer's toughness with the best axe (steel: half).
static func swings_for(hits: int) -> int:
	return maxi(ceili(hits / 2.0), 2) if best_axe() == STEEL_AXE else hits


static func find(player: Node) -> WoodcuttingController:
	return player.get_node_or_null(^"Woodcutting") as WoodcuttingController if player else null


func _ready() -> void:
	_player = get_parent() as PlayerController
	if _player == null:
		return
	_animator = _player.get_node_or_null(^"Visual/Character") as CharacterAnimator
	if _animator:
		_skeleton = _animator.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_hand_bone = _skeleton.find_bone("mixamorig_RightHand")
	_build_axe()


func is_swinging() -> bool:
	return _swinging


func get_axe_node() -> Node3D:
	return _axe


## Swings the axe `times` times at `target` (a world point). Locks the player while
## swinging and calls `on_hit(i)` as each swing lands. Await it.
func swing(times: int, target: Vector3, on_hit: Callable = Callable()) -> void:
	if _swinging or _player == null:
		return
	_swinging = true
	_player.set_input_locked(true)
	var to_target := target - _player.global_position
	_player.face_yaw(atan2(-to_target.x, -to_target.z))
	_axe.visible = true
	if not _chips.is_inside_tree():
		await _player.get_tree().process_frame
	_chips.global_position = Vector3(target.x, _player.global_position.y + 0.9, target.z)
	var tree := _player.get_tree()
	for i in times:
		_swing_time = 0.0
		if _animator:
			_animator.play_action(&"farm_swing")
		await tree.create_timer(HIT_TIME).timeout
		_chips.restart()
		_chips.emitting = true
		swing_hit.emit(i, target)
		if on_hit.is_valid():
			on_hit.call(i)
		await tree.create_timer(SWING_LENGTH - HIT_TIME).timeout
	_axe.visible = false
	_player.set_input_locked(false)
	_swinging = false


func _process(delta: float) -> void:
	if _axe == null or not _axe.visible:
		return
	_swing_time += delta
	var visual := _player.get_node(^"Visual") as Node3D
	var facing := Basis(Vector3.UP, visual.global_rotation.y)
	var hand := _player.global_position + Vector3.UP * 1.0 + facing * Vector3(0.25, 0, -0.3)
	if _skeleton and _hand_bone >= 0:
		hand = _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone).origin
	# Raised over the shoulder, then brought down and forward into the trunk.
	var t := _swing_time
	var down := smoothstep(0.25, HIT_TIME, t) * (1.0 - smoothstep(0.85, SWING_LENGTH, t))
	var pitch := lerpf(1.2, -0.25, down)  # radians: + = head back over the shoulder
	_axe.global_transform = Transform3D(facing * Basis(Vector3.RIGHT, pitch), hand)


## A simple iron axe until a modelled one arrives: an ash handle and a grey head.
## The node's origin is where the hand grips the handle; the handle runs up local +Y.
func _build_axe() -> void:
	_axe = Node3D.new()
	_axe.name = "Axe"
	_axe.top_level = true
	_axe.visible = false
	_attach(_axe)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.43, 0.25)
	wood.roughness = 0.8
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.55, 0.58, 0.6)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.018
	handle_mesh.bottom_radius = 0.022
	handle_mesh.height = 0.72
	handle_mesh.radial_segments = 8
	handle.mesh = handle_mesh
	handle.material_override = wood
	handle.position = Vector3(0, 0.26, 0)
	_axe.add_child(handle)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.035, 0.11, 0.17)
	head.mesh = head_mesh
	head.material_override = iron
	# The blade faces forward (-Z), the way the axe swings.
	head.position = Vector3(0, 0.56, -0.05)
	_axe.add_child(head)
	var edge := MeshInstance3D.new()
	edge.name = "Edge"
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.02, 0.15, 0.03)
	edge.mesh = edge_mesh
	var bright := iron.duplicate() as StandardMaterial3D
	bright.albedo_color = Color(0.85, 0.88, 0.9)
	edge.material_override = bright
	edge.position = Vector3(0, 0.56, -0.145)
	_axe.add_child(edge)
	# Wood chips when the blade bites.
	_chips = CPUParticles3D.new()
	_chips.name = "Chips"
	_chips.top_level = true
	_chips.emitting = false
	_chips.one_shot = true
	_chips.explosiveness = 0.9
	_chips.amount = 14
	_chips.lifetime = 0.7
	_chips.direction = Vector3(0, 1, 0)
	_chips.spread = 70.0
	_chips.initial_velocity_min = 1.5
	_chips.initial_velocity_max = 3.0
	_chips.gravity = Vector3(0, -9.8, 0)
	var chip := BoxMesh.new()
	chip.size = Vector3(0.04, 0.012, 0.03)
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = Color(0.86, 0.7, 0.48)
	chip.material = chip_material
	_chips.mesh = chip
	_attach(_chips)


## Adds a node to the player now, or once the player has finished loading.
func _attach(node: Node) -> void:
	if _player.is_node_ready():
		_player.add_child(node)
	else:
		_player.add_child.call_deferred(node)
