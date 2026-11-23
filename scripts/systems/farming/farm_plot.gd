class_name FarmPlot
extends Interactable
## One garden bed on the farm. Press E on it to dig, plant, water or harvest.
##
## The bed only stores its state and draws itself; the player's FarmingController does
## the actions (animation, items, time). Growth comes from FarmField when the clock moves.
##
## States:  wild (overgrown) -> dug -> planted (seed .. ready) -> harvested -> dug again.

signal changed(plot: FarmPlot)

## Watering keeps the soil damp for this many in-game minutes (one day).
const DAMP_MINUTES := 24 * 60
## Bed size in metres (square).
const BED_SIZE := 2.3
const SAVE_VERSION := 1

## True once the soil has been dug over. Overgrown beds must be dug first.
var tilled: bool = false
## Crop growing here, or &"" for an empty bed.
var crop_id: StringName = &""
## Minutes of damp growing time the crop has had.
var growth_minutes: int = 0
## Minutes of dampness left from the last watering.
var damp_minutes: int = 0
## Fertilized crops grow twice as fast until harvested.
var fertilized: bool = false

const FERTILIZER_GROWTH := 2

var _visual_key: String = ""
var _soil: MeshInstance3D
var _border: MeshInstance3D
var _weeds: MeshInstance3D
var _ridges: Array[MeshInstance3D] = []
var _plants: Node3D
var _fertilizer: MeshInstance3D


func _ready() -> void:
	add_to_group(&"farm_plot")
	if interaction_id == &"":
		push_warning("FarmPlot '%s' has no interaction_id; its state can't be saved." % name)
	# Sit on the ground wherever the bed is placed.
	var ground := IslandShape.shared().get_height(global_position.x, global_position.z)
	global_position.y = ground
	_build()
	_refresh_visuals()


# ---- State --------------------------------------------------------------------

func get_crop() -> CropData:
	return CropCatalog.shared().get_crop(crop_id) if crop_id != &"" else null


func has_crop() -> bool:
	return crop_id != &""


func is_damp() -> bool:
	return damp_minutes > 0


func get_stage() -> int:
	var crop := get_crop()
	return crop.get_stage(growth_minutes) if crop else -1


func is_ready() -> bool:
	return get_stage() == CropData.Stage.READY


## Damp growing minutes still needed before harvest (0 when ready or empty).
func get_minutes_to_harvest() -> int:
	var crop := get_crop()
	return maxi(crop.get_grow_minutes() - growth_minutes, 0) if crop else 0


## The crop has been planted and still needs water to keep growing.
func needs_water() -> bool:
	return has_crop() and not is_ready() and not is_damp()


func can_dig() -> bool:
	return not tilled


func can_plant() -> bool:
	return tilled and not has_crop()


func can_fertilize() -> bool:
	return has_crop() and not is_ready() and not fertilized


func can_water() -> bool:
	return tilled and not is_damp() and not is_ready()


# ---- Actions (no items, no time: FarmingController handles those) ------------------

func dig() -> bool:
	if not can_dig():
		return false
	tilled = true
	_changed()
	return true


func plant(crop: CropData) -> bool:
	if crop == null or not can_plant():
		return false
	crop_id = crop.id
	growth_minutes = 0
	_changed()
	return true


func water() -> bool:
	if not can_water():
		return false
	damp_minutes = DAMP_MINUTES
	_changed()
	return true


func fertilize() -> bool:
	if not can_fertilize():
		return false
	fertilized = true
	_changed()
	return true


## Empties a ready bed and returns its crop (null if nothing was ready).
func harvest() -> CropData:
	if not is_ready():
		return null
	var crop := get_crop()
	crop_id = &""
	growth_minutes = 0
	fertilized = false
	_changed()
	return crop


## Rain soaks a dug bed (planted or not), the same as watering it.
func rain() -> void:
	if not tilled or damp_minutes == DAMP_MINUTES:
		return
	var was_damp := is_damp()
	damp_minutes = DAMP_MINUTES
	if not was_damp:
		_changed()


## Called by FarmField whenever in-game time moves on. The crop grows only for the
## part of that time the soil was damp; dry soil pauses growth (nothing ever dies).
func grow(minutes: int) -> void:
	if minutes <= 0:
		return
	var before := _state_key()
	if has_crop() and not is_ready():
		var crop := get_crop()
		var damp_time := mini(minutes, damp_minutes)
		growth_minutes = mini(growth_minutes + damp_time * (FERTILIZER_GROWTH if fertilized else 1), crop.get_grow_minutes())
	damp_minutes = maxi(damp_minutes - minutes, 0)
	if _state_key() != before:
		_changed()


# ---- Saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"v": SAVE_VERSION, "tilled": tilled, "crop": String(crop_id), "growth": growth_minutes, "damp": damp_minutes, "fert": fertilized}


func from_dict(data: Dictionary) -> void:
	tilled = bool(data.get("tilled", false))
	crop_id = StringName(str(data.get("crop", "")))
	if crop_id != &"" and get_crop() == null:
		push_warning("FarmPlot %s: unknown crop '%s' in save, bed left empty." % [interaction_id, crop_id])
		crop_id = &""
	growth_minutes = maxi(int(data.get("growth", 0)), 0)
	damp_minutes = clampi(int(data.get("damp", 0)), 0, DAMP_MINUTES)
	fertilized = bool(data.get("fert", false)) and crop_id != &""
	_changed()


## Back to an untouched, overgrown bed.
func reset() -> void:
	tilled = false
	crop_id = &""
	growth_minutes = 0
	damp_minutes = 0
	fertilized = false
	_changed()


# ---- Interaction ------------------------------------------------------------------------

func get_prompt() -> String:
	var farming := _farming()
	return farming.get_prompt(self) if farming else prompt_text


func _on_interact(interactor: Node) -> void:
	var farming := interactor.get_node_or_null(^"Farming") as FarmingController if interactor else null
	if farming:
		farming.use_plot(self)


func _farming() -> FarmingController:
	return get_tree().get_first_node_in_group(&"farming_controller") as FarmingController if is_inside_tree() else null


# ---- Visuals ----------------------------------------------------------------------------

func _changed() -> void:
	_refresh_visuals()
	changed.emit(self)


## Visual state only changes when stage, soil or crop changes (not every minute).
func _state_key() -> String:
	return "%s|%s|%d|%s|%s" % [tilled, crop_id, get_stage(), is_damp(), fertilized]


func _build() -> void:
	_border = MeshInstance3D.new()
	_border.name = "Border"
	_border.mesh = CropVisuals.bed_border_mesh(BED_SIZE)
	add_child(_border)
	_soil = MeshInstance3D.new()
	_soil.name = "Soil"
	var soil_box := BoxMesh.new()
	soil_box.size = Vector3(BED_SIZE - 0.1, 0.1, BED_SIZE - 0.1)
	_soil.mesh = soil_box
	_soil.position.y = 0.03
	add_child(_soil)
	for i in 3:
		var ridge := MeshInstance3D.new()
		ridge.name = "Ridge%d" % i
		ridge.mesh = CropVisuals.ridge_mesh()
		ridge.position = Vector3((i - 1) * BED_SIZE * 0.29, 0.08, 0.0)
		ridge.scale = Vector3(1.0, 1.0, BED_SIZE - 0.35)
		add_child(ridge)
		_ridges.append(ridge)
	_weeds = MeshInstance3D.new()
	_weeds.name = "Weeds"
	_weeds.mesh = CropVisuals.weeds_mesh(BED_SIZE, absi(hash(interaction_id)))
	_weeds.position.y = 0.08
	add_child(_weeds)
	_plants = Node3D.new()
	_plants.name = "Plants"
	add_child(_plants)
	_fertilizer = MeshInstance3D.new()
	_fertilizer.name = "Fertilizer"
	_fertilizer.mesh = CropVisuals.fertilizer_mesh(BED_SIZE)
	_fertilizer.position.y = 0.09
	add_child(_fertilizer)


func _refresh_visuals() -> void:
	if _soil == null:
		return
	var key := _state_key()
	if key == _visual_key:
		return
	_visual_key = key
	var soil_kind := &"wild"
	if tilled:
		soil_kind = &"damp" if is_damp() else &"dry"
	var material := CropVisuals.soil_material(soil_kind)
	_soil.material_override = material
	for ridge in _ridges:
		ridge.visible = tilled
		ridge.material_override = material
	_weeds.visible = not tilled
	_fertilizer.visible = fertilized
	_rebuild_plants()


func _rebuild_plants() -> void:
	for child in _plants.get_children():
		_plants.remove_child(child)
		child.queue_free()
	var crop := get_crop()
	if crop == null:
		return
	var stage := get_stage()
	var model: PackedScene = crop.stage_models[stage] if stage < crop.stage_models.size() else null
	var mesh := CropVisuals.crop_mesh(crop.look, stage) if model == null else null
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(interaction_id)) + 7
	var count := maxi(crop.plants_per_row, 1)
	var spacing := BED_SIZE * (0.29 if count >= 3 else 0.42)
	for row in count:
		for col in count:
			var offset := (count - 1) * 0.5
			var pos := Vector3((col - offset) * spacing, 0.13, (row - offset) * spacing)
			pos += Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			var plant: Node3D
			if model:
				plant = model.instantiate() as Node3D
			else:
				var instance := MeshInstance3D.new()
				instance.mesh = mesh
				plant = instance
			plant.position = pos
			# Sunflowers all face the same way (towards the morning sun); others vary.
			var yaw := rng.randf_range(-0.35, 0.35) if crop.look == &"sunflower" else rng.randf() * TAU
			plant.rotation.y = yaw
			var s := rng.randf_range(0.88, 1.12) * crop.plant_scale
			plant.scale = Vector3(s, s, s)
			_plants.add_child(plant)


## Number of plant models shown (for tests).
func get_plant_count() -> int:
	return _plants.get_child_count() if _plants else 0
