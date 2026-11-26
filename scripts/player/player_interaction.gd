class_name PlayerInteraction
extends Area3D
## Finds the nearest Interactable in reach and triggers it when E is pressed.
## Lives on an Area3D child of the player.

var _current: Interactable = null
var _prompt: String = ""

const STAND_UP_PROMPT := "Stand up"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # interactables
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	var nearest: Interactable = null
	var best := INF
	var player := get_parent() as PlayerController
	var busy := player != null and player.is_input_locked()
	var hands_full := player != null and player.is_hands_busy()
	for area in ([] if busy else get_overlapping_areas()):
		var candidate := area as Interactable
		if candidate == null or not candidate.enabled:
			continue
		# Some things only answer at certain times (a crate needs free hands, the jetty a
		# crate in them). With a crate or the cart in your hands, nothing else answers.
		if candidate.has_method(&"can_interact_now"):
			if not candidate.call(&"can_interact_now", player):
				continue
		elif hands_full:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best:
			best = distance
			nearest = candidate
	# Prompts can change while you stand there (a garden bed after time passes, a
	# different seed chosen), so refresh when the text changes too.
	var prompt := nearest.get_prompt() if nearest else ""
	if nearest == null and hands_full:
		var carry := PlayerCarry.find(player)
		prompt = carry.get_free_prompt() if carry else ""
	if player and player.is_sitting():
		prompt = STAND_UP_PROMPT
	if nearest != _current or prompt != _prompt:
		_current = nearest
		_prompt = prompt
		GameManager.set_interaction_prompt(prompt)


func get_current() -> Interactable:
	return _current


## The prompt shown right now ("" when there is none).
func get_prompt_text() -> String:
	return _prompt


func _unhandled_input(event: InputEvent) -> void:
	var player := get_parent() as PlayerController
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
		# Prompt text may change after interacting (e.g. sleep time).
		_prompt = _current.get_prompt() if _current.enabled else ""
		GameManager.set_interaction_prompt(_prompt)
