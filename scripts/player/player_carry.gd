class_name PlayerCarry
extends Node
## Carrying shipping crates and pushing the hand-cart (see ShippingYard).
##
## - Lift (E on a crate): you bend down to it (a deep squat for one on the ground, a
##   slight bend for a table or the cart), take it by the sides (HandGrip IK) and stand
##   up with it; it rises with your hands to chest height. Setting it down is the same,
##   in reverse.
## - Set down (E): on the cart, the jetty pad or the packing table when one is in reach
##   (they call put_down_into), otherwise on the ground in front of you.
## - Push (E at the cart handles): hands on the grips, the cart rolls ahead of you with
##   its wheels turning; E again lets go.
## While your hands are full you walk a little slower, can't run or jump, and other
## tools (fishing rod, ukulele, seeds) and interactions wait. None of this uses time.
## Uses the Mixamo carry clips when the character library has them (carry_lift,
## carry_reach, carry_walk, carry_idle, cart_push); otherwise the usual idle and walk.

signal picked_up(crate: ShippingCrate)
signal put_down(crate: ShippingCrate)
signal cart_grabbed(cart: HandCart)
signal cart_released(cart: HandCart)

## Bending down (and the same back up) and the pause at the bottom, in seconds: deep for
## a crate near your feet, a reach for one on a table or the cart. The animation tool
## builds carry_lift / carry_reach with these timings.
const LIFT_DOWN := 0.65
const LIFT_HOLD := 0.12
const REACH_DOWN := 0.35
const REACH_HOLD := 0.08
## Below this height above your feet a crate needs the deep squat.
const LOW_HEIGHT := 0.4
## Where the crate is held (relative to the feet, facing forward).
const CARRY_HEIGHT := 0.78
const CARRY_FORWARD := 0.42
## How far in front of you the cart's grips are while pushing.
const CART_REACH := 0.42
const CARRY_SPEED := 0.8
const PUSH_SPEED := 0.85
const GRIP_BLEND_SPEED := 4.0

var _player: PlayerController
var _crate: ShippingCrate
var _cart: HandCart
var _anchor: Node3D
var _busy := false
var _grip_right: HandGrip
var _grip_left: HandGrip
var _grip_weight := 0.0
## The crate you're bending down to take (before it's in your hands).
var _reaching: ShippingCrate


## The carry helper of a player (or of the player a node belongs to).
static func find(node: Node) -> PlayerCarry:
	if node == null:
		return null
	if node is PlayerCarry:
		return node
	return node.get_node_or_null(^"Carry") as PlayerCarry


func _ready() -> void:
	name = "Carry"
	_player = get_parent() as PlayerController
	var visual := _player.get_node(^"Visual") as Node3D
	_anchor = Node3D.new()
	_anchor.name = "CarryAnchor"
	_anchor.position = Vector3(0.0, CARRY_HEIGHT, -CARRY_FORWARD)
	visual.add_child(_anchor)
	_setup_grips.call_deferred()


# ---- State ----------------------------------------------------------------------------

func is_carrying() -> bool:
	return _crate != null


func is_pushing() -> bool:
	return _cart != null


func is_hands_busy() -> bool:
	return _crate != null or _cart != null or _busy


func get_crate() -> ShippingCrate:
	return _crate


func get_cart() -> HandCart:
	return _cart


## What E does with nothing else in reach.
func get_free_prompt() -> String:
	if _cart:
		return "Let go of the cart"
	if _crate:
		return "Set the crate down"
	return ""


# ---- Crates ---------------------------------------------------------------------------

## Lifts a crate (from the ground, table, cart or jetty). Returns false if you can't now.
func pick_up(crate: ShippingCrate) -> bool:
	if is_hands_busy() or crate == null or crate.location == ShippingCrate.Location.CARRIED:
		return false
	_busy = true
	_stow_tools()
	_player.set_input_locked(true)
	_face(crate.global_position)
	var deep := _is_low(crate.global_position.y)
	_play_bend(deep)
	_reaching = crate
	await _wait(_half_bend(deep))
	_reaching = null
	if not is_instance_valid(crate) or crate.location == ShippingCrate.Location.CARRIED:
		_finish_busy()
		return false
	crate.reparent(_anchor, true)
	crate.set_location(ShippingCrate.Location.CARRIED)
	_crate = crate
	_set_mode()
	await _ease_crate(crate, &"transform", _carry_transform(), _half_bend(deep))
	_finish_busy()
	picked_up.emit(crate)
	return true


## Sets the carried crate on a table, cart or jetty pad (anything with place()).
func put_down_into(holder: Node) -> bool:
	if _crate == null or _busy or not holder.has_method(&"place"):
		return false
	var rack := holder.get_node_or_null(^"Rack") as CrateRack
	var slot := rack.free_slot() if rack else -1
	if rack and slot < 0:
		return false
	var crate := _crate
	_busy = true
	_player.set_input_locked(true)
	_face((holder as Node3D).global_position)
	var target := rack.global_transform * rack.slot_transform(slot) if rack else crate.global_transform
	var deep := _is_low(target.origin.y)
	_play_bend(deep)
	await _ease_crate(crate, &"global_transform", target, _half_bend(deep))
	var placed: bool = is_instance_valid(crate) and holder.call(&"place", crate, slot)
	if placed:
		_crate = null
		_set_mode()
	elif is_instance_valid(crate):
		await _ease_crate(crate, &"transform", _carry_transform(), _half_bend(deep))
		_finish_busy()
		return false
	await _wait(_half_bend(deep))
	_finish_busy()
	put_down.emit(crate)
	return true


## Sets the carried crate on the ground (or a jetty deck) just in front of you.
func put_down_on_ground() -> bool:
	if _crate == null or _busy:
		return false
	var crate := _crate
	_busy = true
	_player.set_input_locked(true)
	var spot := _player.global_position + _forward() * 0.85
	spot.y = _floor_at(spot)
	var target := Transform3D(Basis(Vector3.UP, _player.get_node(^"Visual").global_rotation.y), spot)
	var deep := _is_low(spot.y)
	_play_bend(deep)
	await _ease_crate(crate, &"global_transform", target, _half_bend(deep))
	var yard := _yard()
	if yard and is_instance_valid(crate):
		yard.set_on_ground(crate, target)
	_crate = null
	_set_mode()
	await _wait(_half_bend(deep))
	_finish_busy()
	put_down.emit(crate)
	return true


## Lets go of everything at once (loading a save, being moved elsewhere).
func drop_everything() -> void:
	_reaching = null
	if _cart:
		release_cart()
	if _crate and is_instance_valid(_crate):
		var yard := _yard()
		var spot := _player.global_position + _forward() * 0.85
		spot.y = _floor_at(spot)
		if yard:
			yard.set_on_ground(_crate, Transform3D(Basis(), spot))
	_crate = null
	_busy = false
	_set_mode()


# ---- The cart -------------------------------------------------------------------------

func grab_cart(cart: HandCart) -> bool:
	if is_hands_busy() or cart == null or cart.is_pushed():
		return false
	_stow_tools()
	_cart = cart
	cart.set_pushed(true)
	# Step in behind the handles, facing the way the cart points.
	var cart_forward := -cart.global_basis.z
	cart_forward.y = 0.0
	cart_forward = cart_forward.normalized()
	var grips := (cart.get_grip(true) + cart.get_grip(false)) * 0.5
	var stand := grips - cart_forward * CART_REACH
	stand.y = _player.global_position.y
	_player.teleport_to(stand, atan2(-cart_forward.x, -cart_forward.z))
	_set_mode()
	cart_grabbed.emit(cart)
	return true


func release_cart() -> void:
	if _cart == null:
		return
	var cart := _cart
	_cart = null
	cart.set_pushed(false)
	_set_mode()
	cart_released.emit(cart)


func _physics_process(delta: float) -> void:
	if _cart:
		_move_cart()
	var wanted := 1.0 if _crate or _cart or _reaching else 0.0
	_grip_weight = move_toward(_grip_weight, wanted, GRIP_BLEND_SPEED * delta)
	for grip in [_grip_right, _grip_left]:
		if grip:
			grip.influence = _grip_weight
			grip.holding = _grip_weight > 0.001


## The cart rolls along in front of you, turning with you.
func _move_cart() -> void:
	var forward := _forward()
	var yaw := atan2(-forward.x, -forward.z)
	var grips := _player.global_position + forward * CART_REACH
	var origin := grips + forward * 1.2
	var before := _cart.global_position
	origin.y = _cart.floor_height_at(Vector3(origin.x, _player.global_position.y + 1.0, origin.z), [_player.get_rid(), _cart.get_rid()])
	_cart.global_transform = Transform3D(Basis(Vector3.UP, yaw), origin)
	_cart.roll((origin - before).dot(forward))


# ---- Input ----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact"):
		return
	if _busy:
		get_viewport().set_input_as_handled()
		return
	if _cart:
		get_viewport().set_input_as_handled()
		release_cart()
		return
	if _crate:
		var interaction := _player.get_node_or_null(^"InteractionArea") as PlayerInteraction
		if interaction == null or interaction.get_current() == null:
			get_viewport().set_input_as_handled()
			put_down_on_ground()


# ---- Helpers --------------------------------------------------------------------------

func _set_mode() -> void:
	var animator := _animator()
	var busy := _crate != null or _cart != null
	if _player.has_method(&"set_hands_busy"):
		_player.call(&"set_hands_busy", busy, PUSH_SPEED if _cart else CARRY_SPEED)
	if animator == null:
		return
	if _cart:
		animator.call(&"set_idle_clip", &"cart_push_idle" if animator.call(&"has_clip", &"cart_push_idle") else &"idle")
		animator.call(&"set_walk_clip", &"cart_push" if animator.call(&"has_clip", &"cart_push") else &"walk")
	elif _crate:
		animator.call(&"set_idle_clip", &"carry_idle" if animator.call(&"has_clip", &"carry_idle") else &"idle")
		animator.call(&"set_walk_clip", &"carry_walk" if animator.call(&"has_clip", &"carry_walk") else &"walk")
	else:
		animator.call(&"set_idle_clip", &"idle")
		animator.call(&"set_walk_clip", &"walk")


func _finish_busy() -> void:
	_busy = false
	if is_instance_valid(_player):
		_player.set_input_locked(false)


func _stow_tools() -> void:
	var fishing := _player.get_node_or_null(^"Fishing")
	if fishing and fishing.has_method(&"stow") and fishing.get(&"state") != null:
		fishing.call(&"stow")
	var uke := _player.get_node_or_null(^"Ukulele")
	if uke and uke.has_method(&"is_playing") and uke.call(&"is_playing") and uke.has_method(&"toggle"):
		uke.call(&"toggle")


func _animator() -> Node:
	return _player.find_child("Character", true, false) if _player else null


func _forward() -> Vector3:
	var visual := _player.get_node(^"Visual") as Node3D
	var forward := -visual.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _face(point: Vector3) -> void:
	var to := point - _player.global_position
	to.y = 0.0
	if to.length() > 0.05:
		_player.face_yaw(atan2(-to.x, -to.z))


func _floor_at(point: Vector3) -> float:
	var ground := IslandShape.shared().get_height(point.x, point.z)
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, Vector3(point.x, ground - 0.5, point.z), 1, exclude))
	return maxf(ground, (hit.position as Vector3).y) if not hit.is_empty() else ground


func _yard() -> ShippingYard:
	return _player.get_tree().get_first_node_in_group(&"shipping_yard") as ShippingYard


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## A deep squat for something near your feet, a slight bend for a table or the cart.
func _is_low(height: float) -> bool:
	return height - _player.global_position.y < LOW_HEIGHT


func _play_bend(deep: bool) -> void:
	var animator := _animator()
	if animator:
		animator.call(&"play_action", &"carry_lift" if deep else &"carry_reach")


## Bending down (or straightening up), including half the pause at the bottom.
func _half_bend(deep: bool) -> float:
	return (LIFT_DOWN + LIFT_HOLD * 0.5) if deep else (REACH_DOWN + REACH_HOLD * 0.5)


## Where the crate sits in your hands (relative to the carry anchor).
func _carry_transform() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, -ShippingCrate.SIZE * 0.5, 0.0))


## Moves the crate smoothly with your hands (its transform or global_transform).
func _ease_crate(crate: ShippingCrate, property: StringName, to: Transform3D, seconds: float) -> void:
	if not is_instance_valid(crate):
		return
	var tween := create_tween()
	tween.tween_property(crate, NodePath(property), to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


# ---- Hands (IK) -------------------------------------------------------------------------

func _setup_grips() -> void:
	var skeleton := _player.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	_grip_right = _make_grip(skeleton, "Right")
	_grip_left = _make_grip(skeleton, "Left")


func _make_grip(skeleton: Skeleton3D, side: String) -> HandGrip:
	var grip := HandGrip.new()
	grip.name = "Carry%sGrip" % side
	grip.side = side
	grip.influence = 0.0
	grip.finger_curl = Vector3(12.0, 22.0, 16.0)
	grip.thumb_curl = -5.0
	grip.diagonal_degrees = 0.0
	grip.rod_radius = 0.06 / maxf(skeleton.global_basis.get_scale().x, 0.01)
	grip.reach_provider = func() -> Dictionary: return _hand_target(side == "Left")
	skeleton.add_child(grip)
	return grip


## Where a hand goes: on the side of the carried crate, or on a cart grip.
func _hand_target(left: bool) -> Dictionary:
	var forward := _forward()
	var right := forward.cross(Vector3.UP).normalized()
	var out := -right if left else right
	if _cart:
		return {
			"position": _cart.get_grip(left),
			"direction": (-forward + Vector3.UP * 0.6).normalized(),
			"palm": Vector3.DOWN + forward * 0.2,
			"pole": Vector3.DOWN + out * 0.7 - forward * 0.3,
		}
	var crate := _crate if _crate else _reaching
	if crate and is_instance_valid(crate):
		var center := crate.global_position + Vector3.UP * ShippingCrate.SIZE * 0.45
		return {
			"position": center + out * (ShippingCrate.SIZE * 0.5 + 0.03),
			"direction": forward,
			"palm": -out,
			"pole": Vector3.DOWN + out * 0.8,
		}
	return {}
