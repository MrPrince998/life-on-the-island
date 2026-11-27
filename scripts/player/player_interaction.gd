class_name PlayerInteraction
extends Area3D
## Selects a nearby Interactable using distance and camera facing, with a stable
## focus marker shared by mouse and gamepad look.
## Lives on an Area3D child of the player.

var _current: Interactable = null
var _prompt: String = ""

const STAND_UP_PROMPT := "Stand up"
## A target behind the camera pays up to 3 metres of extra selection cost.
const FACING_WEIGHT := 1.5
const SWITCH_MARGIN := 0.2
var _focus_marker: Label3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # interactables
	monitoring = true
	monitorable = false
	_focus_marker = Label3D.new()
	_focus_marker.name = "FocusMarker"
	_focus_marker.text = "◇"
	_focus_marker.font_size = 64
	_focus_marker.pixel_size = 0.006
	_focus_marker.modulate = Color(1.0, 0.87, 0.52)
	_focus_marker.outline_modulate = Color(0.19, 0.12, 0.06)
	_focus_marker.outline_size = 12
	_focus_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Keep the cue readable when the character stands between camera and target.
	_focus_marker.no_depth_test = true
	_focus_marker.top_level = true
	_focus_marker.hide()
	add_child(_focus_marker)


func _physics_process(_delta: float) -> void:
	_refresh_selection()


func _eligible(candidate: Interactable, player: PlayerController) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.enabled or not candidate.can_process():
		return false
	if player and (player.is_input_locked() or player.is_sitting()):
		return false
	if candidate.has_method(&"can_interact_now"):
		return bool(candidate.call(&"can_interact_now", player))
	return player == null or not player.is_hands_busy()


func _score(candidate: Interactable, forward: Vector3) -> float:
	var offset := candidate.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	# Underfoot beds should not jump between directions as the player crosses them.
	var facing_cost := 0.0 if distance < 0.35 else FACING_WEIGHT * (1.0 - forward.dot(offset / distance))
	return distance + facing_cost


func _refresh_selection() -> void:
	var nearest: Interactable = null
	var best := INF
	var current_score := INF
	var player := get_parent() as PlayerController
	var rig := player.get_node_or_null("CameraRig") as CameraRig if player else null
	var forward := Vector3.FORWARD.rotated(Vector3.UP, rig.get_yaw()) if rig else -global_basis.z
	for area in get_overlapping_areas():
		var candidate := area as Interactable
		if not _eligible(candidate, player):
			continue
		var score := _score(candidate, forward)
		if candidate == _current:
			current_score = score
		if score < best:
			best = score
			nearest = candidate
	# Keep the current eligible target through small camera/position jitter.
	if current_score < INF and current_score <= best + SWITCH_MARGIN:
		nearest = _current
	var prompt := nearest.get_prompt() if nearest else ""
	if nearest == null and player and player.is_hands_busy() and not player.is_input_locked():
		var carry := PlayerCarry.find(player)
		prompt = carry.get_free_prompt() if carry else ""
	if player and player.is_sitting():
		prompt = STAND_UP_PROMPT
	if nearest != _current or prompt != _prompt:
		_current = nearest
		_prompt = prompt
		GameManager.set_interaction_prompt(prompt)
	_focus_marker.visible = nearest != null and not prompt.is_empty()
	if nearest:
		_focus_marker.global_position = nearest.get_focus_position()


func is_focus_marker_visible() -> bool:
	return is_instance_valid(_focus_marker) and _focus_marker.visible


func get_current() -> Interactable:
	return _current if is_instance_valid(_current) else null


## The prompt shown right now ("" when there is none).
func get_prompt_text() -> String:
	return _prompt


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"interact") or event.is_action_pressed(&"give_gift") or event.is_action_pressed(&"focus_shop")):
		return
	var player := get_parent() as PlayerController
	if player and player.is_input_locked():
		return
	_refresh_selection()
	if event.is_action_pressed(&"interact") and player and player.is_sitting():
		get_viewport().set_input_as_handled()
		player.stand_up()
		return
	# F at a shop counter: the shop view (ShopFocus).
	if event.is_action_pressed(&"focus_shop") and _current and _current.has_method(&"focus_shop") and not (player and player.is_input_locked()):
		get_viewport().set_input_as_handled()
		_current.call(&"focus_shop", player)
		return
	if event.is_action_pressed(&"give_gift") and _current and _current.has_method(&"give_gift") and not (player and player.is_input_locked()):
		get_viewport().set_input_as_handled()
		_current.call(&"give_gift", player)
		return
	if event.is_action_pressed(&"interact") and _current:
		get_viewport().set_input_as_handled()
		_current.interact(get_parent())
		# An action can disable/free its target or lock the player for a window.
		_refresh_selection()
