class_name FarmingController
extends Node
## The player's farming: dig, plant, water and harvest the garden beds (FarmPlot).
## Lives on the player as "Farming". Beds call use_plot() when the player presses E.
##
## Controls: E on a bed does the next job; Q chooses which seeds to plant.
##
## Time rules (explicit, activity-based; walking between beds is free):
##   dig over an overgrown bed -> dig_minutes
##   plant a bed               -> plant_minutes
##   water a bed               -> water_minutes
##   harvest a bed             -> harvest_minutes
##   fertilize a planted bed   -> fertilize_minutes (it then grows twice as fast)
## Looking at a bed, choosing seeds and failed attempts cost no time.

signal action_finished(plot: FarmPlot, action: int)
signal selected_seed_changed(seed_item_id: StringName)

enum Action { DIG, PLANT, NEED_SEEDS, WATER, NEED_CAN, GROWING, HARVEST, FERTILIZE }

const WATERING_CAN := &"watering_can"
## How far the Copper Watering Can reaches to the next beds (metres, centre to centre).
const NEIGHBOUR_REACH := 4.0
const WATERING_CAN_MODEL := preload("res://scenes/props/watering_can_model.tscn")
const FERTILIZER := &"fertilizer"
const ACTION_CLIP := &"farm_swing"
## The farm_swing clip lasts 1.4 s; the job is done at its lowest point.
const ACTION_LENGTH := 1.4
const APPLY_AT := 0.8

@export_group("Time costs (minutes)")
@export var dig_minutes: int = 15
@export var plant_minutes: int = 5
@export var water_minutes: int = 5
@export var harvest_minutes: int = 10
@export var fertilize_minutes: int = 5

var _player: PlayerController
var _animator: CharacterAnimator
var _fishing: FishingController
var _skeleton: Skeleton3D
var _hand_bone: int = -1
var _selected_seed: StringName = &""
var _busy: bool = false
var _current_action: int = -1
var _action_time: float = 0.0
var _can: Node3D
var _water: CPUParticles3D


func _ready() -> void:
	add_to_group(&"farming_controller")
	_player = get_parent() as PlayerController
	_animator = _player.get_node("Visual/Character") as CharacterAnimator
	_fishing = _player.get_node_or_null("Fishing") as FishingController
	_skeleton = _animator.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton:
		_hand_bone = _skeleton.find_bone("mixamorig_RightHand")
	_build_can()


func is_busy() -> bool:
	return _busy


# ---- Seeds --------------------------------------------------------------------

## Seed items in the bag that grow a crop, in catalog order.
## Seeds in the bag that can be planted this season, in catalog order.
func get_available_seeds() -> Array[StringName]:
	var result: Array[StringName] = []
	var season := ActivityClock.get_season_id()
	for crop in CropCatalog.shared().crops:
		if InventoryManager.has_item(crop.seed_item_id) and crop.grows_in(season):
			result.append(crop.seed_item_id)
	return result


## True when the bag has seeds, but none that grow this season.
func has_only_out_of_season_seeds() -> bool:
	if not get_available_seeds().is_empty():
		return false
	for crop in CropCatalog.shared().crops:
		if InventoryManager.has_item(crop.seed_item_id):
			return true
	return false


## Crops that can be planted right now ("Turnips and Carrots").
static func in_season_crop_names() -> String:
	var names: Array[String] = []
	for crop in CropCatalog.shared().crops:
		if crop.grows_in(ActivityClock.get_season_id()):
			names.append(crop.display_name)
	return ", ".join(names) if not names.is_empty() else "nothing"


## The seeds the next bed will be planted with (&"" when the bag has none).
func get_selected_seed() -> StringName:
	var available := get_available_seeds()
	if available.is_empty():
		return &""
	return _selected_seed if _selected_seed in available else available[0]


## Q: switch to the next kind of seeds in the bag.
func cycle_seed() -> StringName:
	var available := get_available_seeds()
	if available.is_empty():
		GameManager.notify("You have no seeds. The General Store in the village sells them.")
		return &""
	var index := available.find(get_selected_seed())
	_selected_seed = available[(index + 1) % available.size()]
	GameManager.notify("Planting %s (%d in your bag)." % [ItemDB.get_display_name(_selected_seed), InventoryManager.get_count(_selected_seed)])
	selected_seed_changed.emit(_selected_seed)
	return _selected_seed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_seed") and not _player.is_input_locked():
		cycle_seed()
		get_viewport().set_input_as_handled()


# ---- What a bed needs ------------------------------------------------------------------

func get_action(plot: FarmPlot) -> Action:
	if plot.can_dig():
		return Action.DIG
	if plot.is_ready():
		return Action.HARVEST
	if not plot.has_crop():
		return Action.PLANT if get_selected_seed() != &"" else Action.NEED_SEEDS
	if plot.needs_water() and InventoryManager.has_item(WATERING_CAN):
		return Action.WATER
	if not plot.fertilized and InventoryManager.has_item(FERTILIZER):
		return Action.FERTILIZE
	if plot.needs_water():
		return Action.NEED_CAN
	return Action.GROWING


func get_prompt(plot: FarmPlot) -> String:
	var crop := plot.get_crop()
	match get_action(plot):
		Action.DIG:
			return "Dig over the overgrown bed · %d min" % dig_minutes
		Action.PLANT:
			var seed_id := get_selected_seed()
			var text := "Plant %s (%d) · %d min" % [ItemDB.get_display_name(seed_id), InventoryManager.get_count(seed_id), plant_minutes]
			if get_available_seeds().size() > 1:
				text += "  ·  Q: other seeds"
			return text
		Action.NEED_SEEDS:
			if has_only_out_of_season_seeds():
				return "None of your seeds grow in %s · try %s" % [ActivityClock.get_season_name(), in_season_crop_names()]
			return "Empty bed · seeds are sold at the General Store"
		Action.WATER:
			return "Water the %s · %d min" % [crop.get_lower_name(), water_minutes]
		Action.NEED_CAN:
			return "The %s are thirsty · watering can: garden shed by the farm gate" % crop.get_lower_name()
		Action.GROWING:
			return "%s growing · about %s to go" % [crop.display_name, _hours_text(plot.get_minutes_to_harvest())]
		Action.HARVEST:
			return "Harvest %d %s · %d min" % [crop.harvest_amount, crop.get_lower_name(), harvest_minutes]
		Action.FERTILIZE:
			return "Add fertilizer (%d) · grows twice as fast · %d min" % [InventoryManager.get_count(FERTILIZER), fertilize_minutes]
	return ""


# ---- Doing the job ----------------------------------------------------------------------

## Does the bed's next job. With animate = false it happens at once (tests).
## Returns false (and explains why) when nothing can be done right now.
func use_plot(plot: FarmPlot, animate: bool = true) -> bool:
	if _busy or plot == null:
		return false
	if _fishing and _fishing.is_busy():
		return false
	var action := get_action(plot)
	var crop := plot.get_crop()
	match action:
		Action.NEED_SEEDS:
			if has_only_out_of_season_seeds():
				GameManager.notify("Those seeds won't sprout in %s. Keep them for their season; this time of year, plant %s." % [ActivityClock.get_season_name(), in_season_crop_names()])
			else:
				GameManager.notify("You have no seeds. The General Store in the village sells them.")
			return false
		Action.NEED_CAN:
			GameManager.notify("You need a watering can. Grandpa kept his in the garden shed by the gate.")
			return false
		Action.GROWING:
			var text := "The %s are growing nicely%s. About %s to go." % [crop.get_lower_name(), " (fertilized)" if plot.fertilized else "", _hours_text(plot.get_minutes_to_harvest())]
			if plot.get_minutes_to_harvest() > plot.damp_minutes:
				text += " They'll need watering again before they're ready."
			GameManager.notify(text)
			return false
		Action.HARVEST:
			if InventoryManager.get_room_for(crop.harvest_item_id) < crop.harvest_amount:
				GameManager.notify("Your bag is full. Sell or drop something first; the %s will wait." % crop.get_lower_name())
				return false
	if _fishing and _fishing.state == FishingController.State.READY:
		_fishing.stow()
	if not animate:
		_apply(plot, action)
		return true
	_perform(plot, action)
	return true


func _perform(plot: FarmPlot, action: int) -> void:
	_busy = true
	_current_action = action
	_action_time = 0.0
	_player.set_input_locked(true)
	var to_plot := plot.global_position - _player.global_position
	if Vector2(to_plot.x, to_plot.z).length() > 0.05:
		_player.face_yaw(atan2(-to_plot.x, -to_plot.z))
	_animator.play_action(ACTION_CLIP)
	_can.visible = action == Action.WATER
	await get_tree().create_timer(APPLY_AT).timeout
	_apply(plot, action)
	await get_tree().create_timer(ACTION_LENGTH - APPLY_AT).timeout
	_can.visible = false
	_water.emitting = false
	_current_action = -1
	_player.set_input_locked(false)
	_busy = false


func _apply(plot: FarmPlot, action: int) -> void:
	var done := false
	match action:
		Action.DIG:
			done = plot.dig()
			if done:
				ActivityClock.advance_minutes(dig_minutes, &"farming")
		Action.PLANT:
			var seed_id := get_selected_seed()
			var crop := CropCatalog.shared().get_crop_for_seed(seed_id)
			if crop and plot.can_plant() and InventoryManager.remove_item(seed_id, 1) == 1:
				done = plot.plant(crop)
				ActivityClock.advance_minutes(plant_minutes, &"farming")
		Action.WATER:
			done = plot.water()
			if done:
				# The Copper Watering Can soaks the neighbouring beds too, in the same
				# few minutes (one watering, so time and quest counts go up once).
				if UpgradeService.has_big_can():
					water_neighbours(plot)
				ActivityClock.advance_minutes(water_minutes, &"farming")
		Action.FERTILIZE:
			if plot.can_fertilize() and InventoryManager.remove_item(FERTILIZER, 1) == 1:
				done = plot.fertilize()
				ActivityClock.advance_minutes(fertilize_minutes, &"farming")
		Action.HARVEST:
			var ready_crop := plot.get_crop()
			if ready_crop and InventoryManager.get_room_for(ready_crop.harvest_item_id) >= ready_crop.harvest_amount:
				var crop := plot.harvest()
				if crop:
					InventoryManager.add_item(crop.harvest_item_id, crop.harvest_amount)
					Journal.record_harvest(crop.id, crop.harvest_amount)
					ActivityClock.advance_minutes(harvest_minutes, &"farming")
					GameManager.notify("You harvested %d %s!" % [crop.harvest_amount, crop.get_lower_name()])
					done = true
	if done:
		var events := {Action.DIG: &"dig", Action.PLANT: &"plant", Action.WATER: &"water", Action.HARVEST: &"harvest", Action.FERTILIZE: &"fertilize"}
		if events.has(action):
			QuestLog.record_event(events[action])
		action_finished.emit(plot, action)


## Waters the beds right next to `plot` that need it (the Copper Watering Can).
## Returns how many it watered.
static func water_neighbours(plot: FarmPlot) -> int:
	var watered := 0
	for other in plot.get_tree().get_nodes_in_group(&"farm_plot"):
		var bed := other as FarmPlot
		if bed == null or bed == plot or not bed.is_visible_in_tree():
			continue
		var gap := Vector2(bed.global_position.x - plot.global_position.x, bed.global_position.z - plot.global_position.z)
		# Beds sit 3.6 m apart in rows: the ones in front, behind and to each side.
		if gap.length() < NEIGHBOUR_REACH and bed.can_water() and bed.water():
			watered += 1
	return watered


static func _hours_text(minutes: int) -> String:
	if minutes < 60:
		return "%d minutes" % maxi(minutes, 1)
	var hours := ceili(minutes / 60.0)
	return "1 hour" if hours == 1 else "%d hours" % hours


# ---- Watering can in the hand ---------------------------------------------------------------

func _build_can() -> void:
	_can = Node3D.new()
	_can.name = "WateringCan"
	_can.top_level = true
	_can.visible = false
	_player.add_child.call_deferred(_can)
	# Grandpa's can (the Tripo model), held by its handle; the scene's origin is the grip.
	var model := WATERING_CAN_MODEL.instantiate() as Node3D
	model.name = "Mesh"
	_can.add_child(model)
	_water = CPUParticles3D.new()
	_water.name = "Water"
	_water.position = (model.get_node("SpoutTip") as Node3D).position
	_water.emitting = false
	_water.amount = 40
	_water.lifetime = 0.45
	_water.local_coords = false
	_water.direction = Vector3(0, -0.3, -1)
	_water.spread = 10.0
	_water.initial_velocity_min = 0.7
	_water.initial_velocity_max = 1.0
	_water.gravity = Vector3(0, -9.8, 0)
	_water.scale_amount_min = 0.6
	_water.scale_amount_max = 1.0
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.03
	drop.radial_segments = 6
	drop.rings = 3
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.62, 0.82, 0.95, 0.75)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.roughness = 0.1
	drop.material = drop_material
	_water.mesh = drop
	_can.add_child(_water)


func _process(delta: float) -> void:
	if _can == null or not _can.visible:
		return
	_action_time += delta
	# Tip the can forward to pour, hold, then lift it back.
	var pour := smoothstep(0.35, 0.6, _action_time) * (1.0 - smoothstep(1.05, 1.3, _action_time))
	_water.emitting = pour > 0.6
	var visual := _player.get_node("Visual") as Node3D
	var facing := Basis(Vector3.UP, visual.global_rotation.y)
	var hand := _player.global_position + Vector3.UP * 0.9 + facing * Vector3(0.25, 0, -0.35)
	if _skeleton and _hand_bone >= 0:
		hand = _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_bone).origin
	_can.global_transform = Transform3D(facing * Basis(Vector3.RIGHT, -0.75 * pour), hand)
