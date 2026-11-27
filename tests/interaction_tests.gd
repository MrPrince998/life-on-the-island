extends RefCounted
## Real overlap/input tests for camera-directed interaction selection.

class RestrictedSpot extends Interactable:
	var allowed := false
	func can_interact_now(_player: Node) -> bool:
		return allowed

func _spot(parent: Node, at: Vector3, label: String) -> Interactable:
	var spot := Interactable.new()
	spot.prompt_text = label
	spot.position = at
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	spot.add_child(shape)
	parent.add_child(spot)
	return spot

func run(t: Node) -> void:
	print("== Interaction clarity ==")
	var world := Node3D.new()
	t.add_child(world)
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerController
	player.position = Vector3(500, 100, 500)
	world.add_child(player)
	player.set_physics_process(false)
	var interaction := player.get_node("InteractionArea") as PlayerInteraction
	var rig := player.get_node("CameraRig") as CameraRig
	var origin := player.position + Vector3.UP
	var front := _spot(world, origin + Vector3(0, 0, -1.3), "Water carrots")
	var back := _spot(world, origin + Vector3(0, 0, 0.6), "Open chest")
	rig.set_yaw(0)
	await t._frames(5)
	t.check(interaction.get_current() == front, "looking forward selects the front object over a closer object behind")
	t.check(interaction.is_focus_marker_visible() and interaction.get_prompt_text() == "Water carrots", "visible focus marker matches the selected action")
	t.check((interaction.get_node("FocusMarker") as Node3D).global_position.is_equal_approx(front.get_focus_position()), "marker is attached to the selected object's focus point")
	rig.set_yaw(PI)
	await t._frames(2)
	t.check(interaction.get_current() == back, "turning the camera switches to the object being faced")
	# Near-equal scores retain the same target until the camera clearly turns.
	front.position = origin + Vector3(-0.7, 0, -1)
	back.position = origin + Vector3(0.7, 0, -1)
	rig.set_yaw(0.5)
	await t._frames(3)
	t.check(interaction.get_current() == front, "leftward look selects the left object")
	for yaw in [0.01, -0.01, 0.01, -0.01]:
		rig.set_yaw(yaw)
		await t._frames(1)
	t.check(interaction.get_current() == front, "small camera jitter does not flicker between equal targets")
	rig.set_yaw(-0.5)
	await t._frames(2)
	t.check(interaction.get_current() == back, "deliberate rightward look overcomes selection stability")
	back.prompt_text = "Harvest carrots"
	await t._frames(2)
	t.check(interaction.get_prompt_text() == "Harvest carrots", "prompts refresh when an object's state changes")
	var calls := [0]
	back.interacted.connect(func(_actor: Node): calls[0] += 1)
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	player.set_input_locked(true)
	interaction._unhandled_input(press)
	await t._frames(2)
	t.check(calls[0] == 0 and interaction.get_current() == null and not interaction.is_focus_marker_visible(), "opening a modal prevents stale interactions and hides focus")
	player.set_input_locked(false)
	await t._frames(2)
	interaction._unhandled_input(press)
	t.check(calls[0] == 1, "interact triggers the selected object exactly once")
	back.enabled = false
	await t._frames(2)
	t.check(interaction.get_current() == front, "a disabled target immediately yields focus")
	front.queue_free()
	await t._frames(3)
	t.check(interaction.get_current() == null and not interaction.is_focus_marker_visible(), "freed targets leave no stale marker or prompt")
	var restricted := RestrictedSpot.new()
	restricted.position = origin + Vector3(0, 0, -0.5)
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	restricted.add_child(collision)
	world.add_child(restricted)
	await t._frames(3)
	t.check(interaction.get_current() == null, "ineligible shipping-style actions cannot take focus")
	restricted.allowed = true
	await t._frames(2)
	t.check(interaction.get_current() == restricted, "eligibility changes allow focus without moving")
	restricted.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(2)
	t.check(interaction.get_current() == null, "disabled scene branches do not offer interactions")
	world.queue_free()
	await t._frames(3)
