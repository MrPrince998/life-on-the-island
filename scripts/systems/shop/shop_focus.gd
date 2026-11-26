class_name ShopFocus
extends RefCounted
## "Shop view" (F at a shop counter): the camera glides round to frame the shop front and
## its shopkeeper, and the shop's window opens down the right-hand side so the view stays
## in sight. Closing the window glides the camera back behind the player.
##
## Any counter can offer it: give it `func focus_shop(player)` that calls ShopFocus.start()
## with the shop's root node, the counter and the shopkeeper's NPC id, then opens its
## window docked. The shot is worked out from where things stand, so it follows the
## shopkeeper if they've wandered a little; a Marker3D named "FocusShot" in the shop scene
## overrides it.

## Camera distance in front of the counter, and height above it (metres).
const DISTANCE := 9.0
const HEIGHT := 1.7
## The shopkeeper only counts when they're this close to the counter.
const KEEPER_RANGE := 12.0
## Where across the screen (0 = left edge, 1 = right) the shop and shopkeeper sit, so
## they stay clear of the window docked on the right.
const DOCKED_SCREEN_X := 0.27


## The camera transform that frames the shop (`shop` = its root node, `counter` = the
## interaction spot at the front) and the shopkeeper villager (null if not nearby).
## With `docked`, the camera turns so the subject sits at DOCKED_SCREEN_X across a screen of
## `aspect` (width / height) seen with vertical field of view `fov` (degrees).
static func shot_for(shop: Node3D, counter: Node3D, keeper: Node3D, docked: bool = false, fov: float = 70.0, aspect: float = 16.0 / 9.0) -> Transform3D:
	var marker := shop.find_child("FocusShot", true, false) as Node3D
	if marker:
		return marker.global_transform
	# The way the shop faces: from the building out through the counter.
	var front := counter.global_position - shop.global_position
	front.y = 0.0
	front = front.normalized() if front.length() > 0.1 else -shop.global_basis.z
	var counter_point := counter.global_position
	var building_point := shop.global_position + Vector3.UP * 3.2
	var target := counter_point.lerp(building_point, 0.45)
	var side := Vector3.UP.cross(front).normalized()
	var eye := counter_point + front * DISTANCE + Vector3.UP * HEIGHT
	if keeper:
		var head := keeper.global_position + Vector3.UP * 1.5
		target = target.lerp(head, 0.45)
		# Step round to the far side from the shopkeeper so they aren't hidden behind the counter.
		var keeper_side := signf((keeper.global_position - counter_point).dot(side))
		eye -= side * keeper_side * 1.5
	else:
		eye += side * 1.2
	# Stand on the ground, not under it.
	var shape := IslandShape.shared()
	eye.y = maxf(eye.y, shape.get_height(eye.x, eye.z) + 1.2)
	var basis := Basis.looking_at(target - eye, Vector3.UP)
	if docked:
		# Turn right until the subject sits in the left part of the picture.
		var half_width := tan(deg_to_rad(fov) * 0.5) * aspect
		var turn := atan((0.5 - DOCKED_SCREEN_X) * 2.0 * half_width)
		basis = Basis(Vector3.UP, -turn) * basis
	return Transform3D(basis, eye)


## The villager with `npc_id` if they're near `counter` (else null).
static func find_keeper(tree: SceneTree, npc_id: StringName, counter: Node3D) -> Node3D:
	if npc_id == &"":
		return null
	for node in tree.get_nodes_in_group(&"villagers"):
		var villager := node as Villager
		if villager and villager.data and villager.data.id == npc_id:
			if villager.global_position.distance_to(counter.global_position) <= KEEPER_RANGE:
				return villager
	return null


## Glides `player`'s camera to the shop view. Returns false if there's no camera rig.
static func start(player: Node, shop: Node3D, counter: Node3D, keeper_id: StringName) -> bool:
	var rig := player.get_node_or_null(^"CameraRig") as CameraRig if player else null
	if rig == null:
		return false
	var keeper := find_keeper(counter.get_tree(), keeper_id, counter)
	var view := counter.get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	rig.focus_on(shot_for(shop, counter, keeper, true, rig.get_camera().fov, aspect))
	if keeper and keeper.has_method(&"greet_from_counter"):
		keeper.call(&"greet_from_counter")
	return true


## Glides the camera back once `panel` (a CanvasLayer shop window) is closed.
static func release_when_closed(player: Node, panel: CanvasLayer) -> void:
	var rig := player.get_node_or_null(^"CameraRig") as CameraRig if player else null
	if rig == null or panel == null:
		return
	panel.visibility_changed.connect(func() -> void:
		if not panel.visible:
			rig.release_focus(), CONNECT_ONE_SHOT)
