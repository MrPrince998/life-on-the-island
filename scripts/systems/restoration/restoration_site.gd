class_name RestorationSite
extends Interactable
## The spot in front of a run-down building where you press E to restore it.
##
## While run-down, the building's model gets a weathered grime-and-moss overlay, broken
## planks and weeds lie around it (or a
## dedicated ruined model is shown when BuildingData.ruined_model_path exists).
## Restoring costs the coins and materials in BuildingData, takes work_minutes of in-game
## time, and sets the story flag "restored_<id>". The flag is saved with the game, and the
## building's look follows it, so a loaded game shows the right state.

signal restored(site: RestorationSite)

const OVERLAY_SHADER := preload("res://shaders/weathered_overlay.gdshader")
const WORK_SWINGS := 3
const SWING_LENGTH := 1.4

@export var building: BuildingData
## The building's restored model (gets the weathered overlay while run-down).
@export var model_path: NodePath = ^"../Model"
## Nodes shown only once restored (lights, seedling trays...).
@export var restored_nodes: Array[NodePath] = []
## Building footprint (width x depth, metres) for placing the debris.
@export var footprint: Vector2 = Vector2(5.0, 4.0)
## Optional story step that must come first (a story flag); "" = always open.
@export var requires_flag: StringName = &""
## Shown when you try before `requires_flag` is set.
@export_multiline var locked_message: String = ""
## Shown when materials or coins are missing (where to get them).
@export var shopping_hint: String = "Wooden planks are sold at the General Store."

var _ruin: Node3D
var _ruined_model: Node3D
var _overlay: ShaderMaterial
var _working: bool = false


func _ready() -> void:
	add_to_group(&"restoration_site")
	GameManager.flag_changed.connect(_on_flag_changed)
	_build_ruin()
	_apply_state()


func is_restored() -> bool:
	return building != null and GameManager.has_flag(building.get_flag())


## What's still needed, as readable lines ("5 more Wooden Planks", "40 more coins").
func get_missing() -> Array[String]:
	var missing: Array[String] = []
	if building == null:
		return missing
	for item_id in building.materials:
		var need := int(building.materials[item_id])
		var have := InventoryManager.get_count(StringName(str(item_id)))
		if have < need:
			missing.append("%d more %s" % [need - have, ItemDB.get_display_name(StringName(str(item_id)))])
	var coins_short := building.cost_coins - InventoryManager.get_money()
	if coins_short > 0:
		missing.append("%d more coins" % coins_short)
	return missing


func can_restore() -> bool:
	return building != null and not is_restored() and is_unlocked() and get_missing().is_empty()


func is_unlocked() -> bool:
	return requires_flag == &"" or GameManager.has_flag(requires_flag)


func get_prompt() -> String:
	if building == null:
		return prompt_text
	if not is_unlocked():
		return "Look at the %s" % building.display_name
	var parts: Array[String] = []
	for item_id in building.materials:
		var id := StringName(str(item_id))
		parts.append("%s %d/%d" % [ItemDB.get_display_name(id), mini(InventoryManager.get_count(id), int(building.materials[item_id])), int(building.materials[item_id])])
	if building.cost_coins > 0:
		parts.append("%d coins" % building.cost_coins)
	return "Repair the %s · %s · %s" % [building.display_name, ", ".join(parts), _hours(building.work_minutes)]


func _on_interact(interactor: Node) -> void:
	if _working or is_restored():
		return
	if not is_unlocked():
		GameManager.notify(locked_message if not locked_message.is_empty() else "Not yet. Maybe someone on the island knows how to fix this.")
		return
	if not can_restore():
		GameManager.notify("To repair the %s you still need %s. %s" % [building.display_name, " and ".join(get_missing()), shopping_hint])
		return
	_work(interactor as PlayerController)


## Pays and restores at once (no animation). Used by the work animation and by tests.
func restore_now() -> bool:
	if not can_restore():
		return false
	for item_id in building.materials:
		InventoryManager.remove_item(StringName(str(item_id)), int(building.materials[item_id]))
	if building.cost_coins > 0:
		InventoryManager.spend_money(building.cost_coins)
	GameManager.set_flag(building.get_flag(), true)
	ActivityClock.advance_minutes(building.work_minutes, &"restoration")
	if not building.restored_message.is_empty():
		GameManager.notify(building.restored_message)
	restored.emit(self)
	return true


func _work(player: PlayerController) -> void:
	_working = true
	var animator: CharacterAnimator = null
	if player:
		player.set_input_locked(true)
		var to_site := global_position - player.global_position
		player.face_yaw(atan2(-to_site.x, -to_site.z))
		animator = player.get_node_or_null(^"Visual/Character") as CharacterAnimator
	_puff_dust()
	for i in WORK_SWINGS:
		if animator:
			animator.play_action(&"farm_swing")
		await get_tree().create_timer(SWING_LENGTH).timeout
	restore_now()
	_puff_dust()
	if player:
		player.set_input_locked(false)
	_working = false


func _on_flag_changed(flag: StringName, _value: bool) -> void:
	if building and flag == building.get_flag():
		_apply_state()


func _apply_state() -> void:
	var done := is_restored()
	enabled = not done
	var model := get_node_or_null(model_path) as Node3D
	if _ruined_model and model:
		model.visible = done
		_ruined_model.visible = not done
	elif model:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null if done else _get_overlay()
	if _ruin:
		_ruin.visible = not done
	for path in restored_nodes:
		var node := get_node_or_null(path) as Node3D
		if node:
			node.visible = done


func _get_overlay() -> ShaderMaterial:
	if _overlay == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.04
		noise.fractal_octaves = 4
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.noise = noise
		_overlay = ShaderMaterial.new()
		_overlay.shader = OVERLAY_SHADER
		_overlay.set_shader_parameter(&"noise_tex", texture)
		var base := get_node_or_null(model_path) as Node3D
		_overlay.set_shader_parameter(&"base_y", base.global_position.y if base else global_position.y)
	return _overlay


# ---- Run-down dressing --------------------------------------------------------------------

func _build_ruin() -> void:
	var model := get_node_or_null(model_path) as Node3D
	if building and not building.ruined_model_path.is_empty() and ResourceLoader.exists(building.ruined_model_path):
		var scene := load(building.ruined_model_path) as PackedScene
		if scene and model:
			_ruined_model = scene.instantiate() as Node3D
			_ruined_model.name = "RuinedModel"
			model.get_parent().add_child.call_deferred(_ruined_model)
			_ruined_model.transform = model.transform
	_ruin = Node3D.new()
	_ruin.name = "RunDown"
	add_child(_ruin)
	# Positions below are relative to the building's base (this node sits by the door).
	var base := -position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(building.id if building else &"site")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.33, 0.22)
	wood.roughness = 1.0
	var wood_dark := StandardMaterial3D.new()
	wood_dark.albedo_color = Color(0.33, 0.25, 0.18)
	wood_dark.roughness = 1.0
	var half := footprint * 0.5
	# Loose and broken planks lying around and leaning on the walls.
	for i in 9:
		var plank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.04, rng.randf_range(0.7, 1.5))
		box.material = wood if i % 2 == 0 else wood_dark
		plank.mesh = box
		var side := i % 4
		var along := rng.randf_range(-0.8, 0.8)
		var spot := Vector3.ZERO
		match side:
			0: spot = Vector3(along * half.x, 0, half.y + 0.25)
			1: spot = Vector3(along * half.x, 0, -half.y - 0.25)
			2: spot = Vector3(half.x + 0.25, 0, along * half.y)
			_: spot = Vector3(-half.x - 0.25, 0, along * half.y)
		if i < 4:
			# Leaning against the wall.
			plank.rotation = Vector3(deg_to_rad(rng.randf_range(55.0, 70.0)), rng.randf_range(-0.4, 0.4), 0)
			spot.y = box.size.z * 0.4
		else:
			plank.rotation = Vector3(0, rng.randf() * TAU, deg_to_rad(rng.randf_range(-6.0, 6.0)))
			spot.y = 0.02
		plank.position = base + spot
		_ruin.add_child(plank)
	# Weeds growing up around the walls.
	for i in 8:
		var weeds := MeshInstance3D.new()
		weeds.mesh = CropVisuals.weeds_mesh(1.4, i)
		var angle := TAU * i / 8.0 + rng.randf_range(-0.2, 0.2)
		weeds.position = base + Vector3(cos(angle) * (half.x + 0.3), 0.0, sin(angle) * (half.y + 0.3))
		weeds.scale = Vector3(1.6, 1.8, 1.6)
		_ruin.add_child(weeds)


func _puff_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.4
	dust.explosiveness = 0.85
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(footprint.x * 0.5, 0.5, 0.4)
	dust.direction = Vector3.UP
	dust.spread = 50.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.1
	dust.gravity = Vector3(0, 0.15, 0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	puff.radial_segments = 8
	puff.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.78, 0.66, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = material
	dust.mesh = puff
	dust.position = Vector3(0, 0.2, -0.6)
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(2.0).timeout.connect(dust.queue_free)


static func _hours(minutes: int) -> String:
	if minutes % 60 == 0:
		return "1 hour" if minutes == 60 else "%d hours" % (minutes / 60)
	return "%d min" % minutes
