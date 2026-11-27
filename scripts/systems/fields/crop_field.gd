@tool
class_name CropField
extends Node3D
## A field of a FieldCropData crop worked by hand, row by row. Grandpa's rice paddy is one.
##
## Each row goes:  EMPTY --plant seedlings--> GROWING --days pass--> RIPE
##                 --cut with a sickle--> CUT (the stalks lie in the row)
##                 --gather and tie--> EMPTY (stubble left until you plant again)
## Crops that need tilling (wheat) go EMPTY --hoe--> TILLED --sow--> GROWING instead.
## For rice the paddy must be flooded (the pump) for the rice to grow, and drained before
## it's cut. A scythe cuts faster than a sickle. Growth only ever pauses, never fails: nothing dies. Every action is an
## activity that advances the clock (D-001); walking about the field costs nothing.
##
## The field is built in code round its origin: rows run along local Z and sit side by
## side along local X. Saved through the "persistent" group (key field_<field_id>).

signal row_changed(index: int, state: int)
signal flood_changed(flooded: bool)
## One sickle/scythe stroke landed in a row (for sounds).
signal cut_stroke(index: int)
## One hoe stroke while tilling a row (for sounds).
signal till_stroke(index: int)

enum RowState { EMPTY, GROWING, RIPE, CUT, TILLED }

const SAVE_VERSION := 1
const FLOOD_MINUTES := 20
const DRAIN_MINUTES := 10
const WATER_HEIGHT := 0.14
const MUD := Color(0.33, 0.25, 0.18)
const BUND := Color(0.42, 0.5, 0.25)
## Dry fields: worn grassy earth, and the dark furrowed soil of a tilled row.
const FIELD_GROUND := Color(0.5, 0.48, 0.3)
const TILLED_SOIL := Color(0.36, 0.26, 0.17)
const FURROW := Color(0.28, 0.2, 0.13)
## Machines (a tractor's implements, see Tractor) work a row as they pass over it, a
## SEGMENT at a time; once MACHINE_DONE of the row has been covered the job is done.
const SEGMENT := 1.0
const MACHINE_DONE := 0.85
## In-game minutes per row with a machine (by hand: till 30, sow 15, cut + tie 50).
const MACHINE_MINUTES := {&"plough": 8, &"seed_drill": 6, &"harvester": 10}
## How much faster a scythe is than a sickle.
const SCYTHE_SWINGS := 0.5
const SCYTHE_MINUTES := 0.6

@export var field_id: StringName = &"grandpa_paddy"
@export var crop: FieldCropData
@export var rows: int = 5
@export var row_width: float = 2.0
@export var row_length: float = 18.0
## Lines of plants along each row, and the gap between plants (metres).
@export var lines_per_row: int = 3
@export var plant_spacing: float = 0.5

var flooded: bool = false
## Per row: {state, grown (days), sheaves, stubble}
var _rows: Array[Dictionary] = []
var _busy := false
var _water: MeshInstance3D
var _row_nodes: Array[Dictionary] = []  # {spot, plants, lying, stubble, soil, clumps: Array[Transform3D]}
var _rng := RandomNumberGenerator.new()
## Machine work in progress: row -> {tool, cells: PackedByteArray}. Not saved: a row
## half-ploughed when you leave is simply started afresh.
var _coverage: Dictionary = {}


func _ready() -> void:
	_rows.clear()
	for i in rows:
		_rows.append({"state": RowState.EMPTY, "grown": 0, "sheaves": 0, "stubble": false})
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	add_to_group(&"crop_fields")
	ActivityClock.day_started.connect(func(_day: int) -> void: _grow_overnight())
	_refresh_all()


# ---- Queries ------------------------------------------------------------------

func get_row_count() -> int:
	return _rows.size()


func get_row(index: int) -> Dictionary:
	return _rows[index].duplicate()


func get_row_state(index: int) -> int:
	return int(_rows[index].state)


func is_busy() -> bool:
	return _busy


func needs_water() -> bool:
	return crop != null and crop.needs_flooding


func needs_tilling() -> bool:
	return crop != null and crop.needs_tilling


## Sickle strokes and minutes to cut a row with the best blade you have (a scythe is
## quicker).
func cut_swings() -> int:
	return maxi(ceili(crop.cut_swings * SCYTHE_SWINGS), 2) if WoodcuttingController.has_scythe() else crop.cut_swings


func cut_minutes() -> int:
	return int(round(crop.cut_minutes * SCYTHE_MINUTES)) if WoodcuttingController.has_scythe() else crop.cut_minutes


## Whether a row's soil shows as tilled (dark furrows) right now.
func is_row_tilled(index: int) -> bool:
	return needs_tilling() and int(_rows[index].state) != RowState.EMPTY


## The middle of a row (world) and the point on its centre line nearest `from`.
func row_center(index: int) -> Vector3:
	return to_global(Vector3(_row_x(index), 0.0, 0.0))


func row_point_near(index: int, from: Vector3) -> Vector3:
	var local := to_local(from)
	return to_global(Vector3(_row_x(index), 0.0, clampf(local.z, -row_length * 0.5, row_length * 0.5)))


## The interaction spot of a row (FieldRow), for tests.
func get_row_spot(index: int) -> FieldRow:
	return _row_nodes[index].spot


## How many plants of a row are standing / lying (what you see), for tests.
func count_visible(index: int) -> Vector2i:
	var nodes: Dictionary = _row_nodes[index]
	return Vector2i(_visible_count(nodes.plants), _visible_count(nodes.lying))


# ---- Prompts ------------------------------------------------------------------

func row_prompt(index: int) -> String:
	if crop == null:
		return ""
	var row: Dictionary = _rows[index]
	match int(row.state):
		RowState.EMPTY when needs_tilling():
			if not WoodcuttingController.has_hoe():
				return "Till this row first: you need a hoe (Bram's forge)"
			return "Till the row with your hoe  (%d strokes · %d min)" % [crop.till_swings, crop.till_minutes]
		RowState.EMPTY, RowState.TILLED:
			if not crop.grows_in(ActivityClock.get_season_id()):
				return "%s only grows in %s" % [crop.display_name, crop.get_seasons_text()]
			if needs_water() and not flooded:
				return "Flood the paddy first (the pump at the corner)"
			var seedlings := InventoryManager.get_count(crop.planting_item)
			if seedlings <= 0:
				return "Plant %s here: you need %s (General Store)" % [crop.display_name.to_lower(), ItemDB.get_display_name(crop.planting_item)]
			if needs_tilling():
				return "Sow the row with %s  (%d min · %d sack%s left)" % [crop.display_name.to_lower(), crop.plant_minutes, seedlings, "" if seedlings == 1 else "s"]
			return "Plant a row of %s  (%d min · %d bundle%s left)" % [crop.display_name.to_lower(), crop.plant_minutes, seedlings, "" if seedlings == 1 else "s"]
		RowState.GROWING:
			var text := "%s growing: day %d of %d" % [crop.display_name, int(row.grown), crop.grow_days]
			if needs_water() and not flooded:
				text += "  ·  the paddy is dry: flood it so it can grow"
			return text
		RowState.RIPE:
			if needs_water() and flooded:
				return "Ripe! Drain the paddy before cutting (the pump at the corner)"
			if not WoodcuttingController.has_cutter():
				return "Ripe! You need a sickle or a scythe to cut it (Bram's forge)"
			return "Cut the %s with your %s  (%d swings · %d min)" % [crop.display_name.to_lower(), "scythe" if WoodcuttingController.has_scythe() else "sickle", cut_swings(), cut_minutes()]
		RowState.CUT:
			if crop.bundle_word == "sheaves":
				return "Gather and tie into %d sheaves  (%d min)" % [int(row.sheaves), crop.tie_minutes]
			return "Gather the %d %s  (%d min)" % [int(row.sheaves), crop.bundle_word, crop.tie_minutes]
	return ""


func pump_prompt() -> String:
	if flooded:
		return "Open the sluice and drain the paddy  (%d min)" % DRAIN_MINUTES
	return "Pump water into the paddy  (%d min)" % FLOOD_MINUTES


# ---- Doing things (with the animation) ----------------------------------------

## What pressing E at a row does. Await it.
func act_on_row(index: int, player: PlayerController) -> void:
	if _busy or crop == null:
		return
	var row: Dictionary = _rows[index]
	match int(row.state):
		RowState.EMPTY when needs_tilling():
			if not WoodcuttingController.has_hoe():
				GameManager.notify("You'll need a hoe to break up this ground. Bram can make you one.")
				return
			_busy = true
			var hoer := _cutter_for(player)
			var spot := row_point_near(index, player.global_position) if player else row_center(index)
			if hoer:
				await hoer.swing(crop.till_swings, spot, func(_i: int) -> void: till_stroke.emit(index), WoodcuttingController.HOE)
			till_now(index)
			_busy = false
		RowState.EMPTY, RowState.TILLED:
			if _plant_refusal() != "":
				GameManager.notify(_plant_refusal())
				return
			_busy = true
			await _bend(player, row_point_near(index, player.global_position if player else row_center(index)), 2)
			plant_now(index)
			_busy = false
		RowState.GROWING:
			GameManager.notify(row_prompt(index))
		RowState.RIPE:
			if _cut_refusal() != "":
				GameManager.notify(_cut_refusal())
				return
			_busy = true
			var cutter := _cutter_for(player)
			var at := row_point_near(index, player.global_position) if player else row_center(index)
			var strokes := cut_swings()
			if cutter:
				await cutter.swing(strokes, at, func(i: int) -> void:
					_show_cut_progress(index, float(i + 1) / strokes)
					cut_stroke.emit(index), WoodcuttingController.SCYTHE if WoodcuttingController.has_scythe() else WoodcuttingController.SICKLE)
			cut_now(index)
			_busy = false
		RowState.CUT:
			_busy = true
			await _bend(player, row_point_near(index, player.global_position if player else row_center(index)), 1)
			tie_now(index)
			_busy = false


## The pump at the corner: floods a dry paddy, drains a wet one. Await it.
func use_pump(player: PlayerController) -> void:
	if _busy:
		return
	_busy = true
	if player:
		player.set_input_locked(true)
		var animator := player.get_node_or_null(^"Visual/Character") as CharacterAnimator
		for i in (2 if not flooded else 1):
			if animator:
				animator.play_action(&"farm_swing")
			await player.get_tree().create_timer(1.25).timeout
		player.set_input_locked(false)
	set_flooded(not flooded, true)
	_busy = false


# ---- Doing things (at once; these charge the time) -----------------------------

## Breaks up a row with the hoe so it can be sown (crops that need tilling).
func till_now(index: int) -> bool:
	var row: Dictionary = _rows[index]
	if not needs_tilling() or int(row.state) != RowState.EMPTY or not WoodcuttingController.has_hoe():
		return false
	row.state = RowState.TILLED
	row.stubble = false
	ActivityClock.advance_minutes(crop.till_minutes, &"tilling")
	QuestLog.record_event(StringName("till_" + String(crop.id)))
	_changed(index)
	return true


func plant_now(index: int) -> bool:
	var row: Dictionary = _rows[index]
	var ready_state := RowState.TILLED if needs_tilling() else RowState.EMPTY
	if int(row.state) != ready_state or _plant_refusal() != "":
		return false
	InventoryManager.remove_item(crop.planting_item, 1)
	row.state = RowState.GROWING
	row.grown = 0
	row.stubble = false
	ActivityClock.advance_minutes(crop.plant_minutes, &"planting")
	QuestLog.record_event(StringName("plant_" + String(crop.id)))
	_changed(index)
	return true


func cut_now(index: int) -> bool:
	var row: Dictionary = _rows[index]
	if int(row.state) != RowState.RIPE or _cut_refusal() != "":
		return false
	_rng.seed = hash([field_id, index, ActivityClock.get_day()])
	row.state = RowState.CUT
	row.sheaves = _rng.randi_range(crop.sheaves_per_row.x, crop.sheaves_per_row.y)
	row.stubble = true
	ActivityClock.advance_minutes(cut_minutes(), &"harvesting")
	QuestLog.record_event(StringName("cut_" + String(crop.id)))
	# Remembered per crop (Marlow's shipping orders start asking for it).
	GameManager.set_flag(StringName("field_cut_" + String(crop.id)))
	if not GameManager.has_flag(&"first_field_cut"):
		GameManager.set_flag(&"first_field_cut")
		GameManager.notify("The cut %s lies in the row. Gather it up and tie it into sheaves (E)." % crop.display_name.to_lower())
	_changed(index)
	return true


## Ties the cut stalks into sheaves and puts them in the bag (as many as fit; the rest
## stay lying in the row for later).
func tie_now(index: int) -> int:
	var row: Dictionary = _rows[index]
	if int(row.state) != RowState.CUT:
		return 0
	var added := InventoryManager.add_item(crop.sheaf_item, int(row.sheaves))
	if added <= 0:
		GameManager.notify("Your bag is full. Make some room first (Grandpa's chest is in the cottage).")
		return 0
	row.sheaves = int(row.sheaves) - added
	ActivityClock.advance_minutes(crop.tie_minutes, &"harvesting")
	QuestLog.record_event(StringName("tie_" + String(crop.id)), added)
	GameManager.notify("+%d %s" % [added, ItemDB.get_display_name(crop.sheaf_item)])
	if int(row.sheaves) <= 0:
		row.state = RowState.EMPTY
		row.sheaves = 0
	_changed(index)
	return added


func set_flooded(value: bool, charge_time: bool = false) -> void:
	if value == flooded:
		return
	flooded = value
	if charge_time:
		ActivityClock.advance_minutes(FLOOD_MINUTES if value else DRAIN_MINUTES, &"irrigation")
		QuestLog.record_event(&"flood_paddy" if value else &"drain_paddy")
	_show_water(true)
	flood_changed.emit(flooded)


func _plant_refusal() -> String:
	if not crop.grows_in(ActivityClock.get_season_id()):
		return "%s won't take now: it only grows in %s." % [crop.display_name, crop.get_seasons_text()]
	if needs_water() and not flooded:
		return "Rice seedlings go into a flooded paddy. Use the pump at the corner first."
	if not InventoryManager.has_item(crop.planting_item):
		return "You need %s to plant a row (General Store)." % ItemDB.get_display_name(crop.planting_item)
	return ""


func _cut_refusal() -> String:
	if needs_water() and flooded:
		return "Drain the paddy first, so the ground firms up for cutting (the pump at the corner)."
	if not WoodcuttingController.has_cutter():
		return "You'll need a sickle or a scythe to cut it. Bram can make you one."
	return ""


## Each new morning, rows grow a day if the paddy held water overnight.
func _grow_overnight() -> void:
	if crop == null:
		return
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if int(row.state) != RowState.GROWING:
			continue
		if needs_water() and not flooded:
			continue
		row.grown = int(row.grown) + 1
		if int(row.grown) >= crop.grow_days:
			row.state = RowState.RIPE
		_changed(i)


func _changed(index: int) -> void:
	_coverage.erase(index)
	_refresh_row(index)
	row_changed.emit(index, int(_rows[index].state))


func _cutter_for(player: PlayerController) -> WoodcuttingController:
	if player == null:
		return null
	var cutter := WoodcuttingController.find(player)
	if cutter == null:
		cutter = WoodcuttingController.new()
		cutter.name = "Woodcutting"
		player.add_child(cutter)
	return cutter


## Bends down to the row (planting, tying): `times` farm swings.
func _bend(player: PlayerController, at: Vector3, times: int) -> void:
	if player == null:
		return
	player.set_input_locked(true)
	var to_spot := at - player.global_position
	if Vector2(to_spot.x, to_spot.z).length() > 0.05:
		player.face_yaw(atan2(-to_spot.x, -to_spot.z))
	var animator := player.get_node_or_null(^"Visual/Character") as CharacterAnimator
	for i in times:
		if animator:
			animator.play_action(&"farm_swing")
		await player.get_tree().create_timer(1.25).timeout
	player.set_input_locked(false)


# ---- Machines (tractor implements) -------------------------------------------

## What `tool` (&"plough", &"seed_drill", &"harvester") would do to the row it's over, or
## why not: {index, ok, verb, reason}. {} when `world_pos` isn't over this field.
func machine_check(tool: StringName, world_pos: Vector3) -> Dictionary:
	var index := row_at(world_pos)
	if index < 0 or crop == null:
		return {}
	var state := int(_rows[index].state)
	var result := {"index": index, "ok": false, "verb": "", "reason": ""}
	match tool:
		&"plough":
			result.verb = "Ploughing"
			if not needs_tilling():
				result.reason = "A paddy isn't ploughed"
			elif state != RowState.EMPTY:
				result.reason = "Row %d is already worked" % (index + 1)
			else:
				result.ok = true
		&"seed_drill":
			result.verb = "Sowing"
			if not needs_tilling():
				result.reason = "Rice is planted by hand"
			elif state != RowState.TILLED:
				result.reason = "Row %d needs ploughing first" % (index + 1) if state == RowState.EMPTY else "Row %d is already sown" % (index + 1)
			elif not crop.grows_in(ActivityClock.get_season_id()):
				result.reason = "%s only grows in %s" % [crop.display_name, crop.get_seasons_text()]
			elif not InventoryManager.has_item(crop.planting_item):
				result.reason = "No %s in your bag" % ItemDB.get_display_name(crop.planting_item)
			else:
				result.ok = true
		&"harvester":
			result.verb = "Harvesting"
			if state != RowState.RIPE:
				result.reason = "Row %d isn't ripe" % (index + 1)
			elif needs_water() and flooded:
				result.reason = "Drain the paddy first"
			elif InventoryManager.get_room_for(crop.grain_item) <= 0:
				result.reason = "Your bag is full"
			else:
				result.ok = true
		_:
			return {}
	return result


## A machine passing over the field at `world_pos`: marks that stretch of the row done and
## finishes the row once it's mostly covered. Returns machine_check() plus "progress"
## (0..1 of the row) and "finished" (true on the pass that completes it).
func machine_work(tool: StringName, world_pos: Vector3) -> Dictionary:
	var result := machine_check(tool, world_pos)
	if result.is_empty() or not result.ok:
		return result
	var index: int = result.index
	var cells := _coverage_cells(index, tool)
	var local := to_local(world_pos)
	var segment := clampi(int(floor((local.z + row_length * 0.5) / SEGMENT)), 0, cells.size() - 1)
	var changed := cells[segment] == 0
	cells[segment] = 1
	var progress := _coverage_progress(index)
	result.progress = progress
	result.finished = false
	if changed:
		_show_machine_progress(index, tool, cells)
	if progress >= MACHINE_DONE:
		_finish_machine(index, tool)
		result.finished = true
		result.progress = 1.0
	return result


## The row under a world point (-1 if it's off the field).
func row_at(world_pos: Vector3) -> int:
	var local := to_local(world_pos)
	if absf(local.z) > row_length * 0.5 + 0.2:
		return -1
	var index := int(round(local.x / row_width + (rows - 1) * 0.5))
	if index < 0 or index >= rows:
		return -1
	if absf(local.x - _row_x(index)) > row_width * 0.5:
		return -1
	return index


func get_machine_progress(index: int) -> float:
	return _coverage_progress(index) if _coverage.has(index) else 0.0


func _coverage_cells(index: int, tool: StringName) -> PackedByteArray:
	var entry: Dictionary = _coverage.get(index, {})
	if entry.is_empty() or entry.tool != tool:
		var cells := PackedByteArray()
		cells.resize(int(ceil(row_length / SEGMENT)))
		cells.fill(0)
		entry = {"tool": tool, "cells": cells}
		_coverage[index] = entry
	return entry.cells


func _coverage_progress(index: int) -> float:
	var cells: PackedByteArray = _coverage[index].cells
	var done := 0
	for c in cells:
		done += c
	return float(done) / maxi(cells.size(), 1)


func _finish_machine(index: int, tool: StringName) -> void:
	_coverage.erase(index)
	var row: Dictionary = _rows[index]
	match tool:
		&"plough":
			row.state = RowState.TILLED
			row.stubble = false
			QuestLog.record_event(StringName("till_" + String(crop.id)))
		&"seed_drill":
			InventoryManager.remove_item(crop.planting_item, 1)
			row.state = RowState.GROWING
			row.grown = 0
			QuestLog.record_event(StringName("plant_" + String(crop.id)))
		&"harvester":
			# Cut and threshed in one pass: the grain goes straight into the bag, and the
			# straw is left lying in the field.
			_rng.seed = hash([field_id, index, ActivityClock.get_day()])
			var sheaves := _rng.randi_range(crop.sheaves_per_row.x, crop.sheaves_per_row.y)
			var grain := InventoryManager.add_item(crop.grain_item, sheaves * crop.grain_per_sheaf)
			row.state = RowState.EMPTY
			row.sheaves = 0
			row.stubble = true
			QuestLog.record_event(StringName("cut_" + String(crop.id)))
			QuestLog.record_event(StringName("harvest_machine_" + String(crop.id)), grain)
			GameManager.set_flag(StringName("field_cut_" + String(crop.id)))
			GameManager.set_flag(&"first_field_cut")
			GameManager.notify("+%d %s" % [grain, BlacksmithService.item_name(crop.grain_item, grain)])
	ActivityClock.advance_minutes(int(MACHINE_MINUTES.get(tool, 10)), StringName("machine_" + String(tool)))
	_changed(index)


## While a machine works a row, the stretches it has done change: ploughed soil appears,
## seedlings come up, ripe plants vanish into the harvester (stubble left behind).
func _show_machine_progress(index: int, tool: StringName, cells: PackedByteArray) -> void:
	if index >= _row_nodes.size():
		return
	var nodes: Dictionary = _row_nodes[index]
	var clumps: Array[Transform3D] = nodes.clumps
	var plants: MultiMeshInstance3D = nodes.plants
	match tool:
		&"plough":
			var tiles := _soil_tiles(index)
			tiles.visible = true
			for i in cells.size():
				var z := -row_length * 0.5 + (i + 0.5) * SEGMENT
				var at := Vector3(_row_x(index), 0.045, z)
				tiles.multimesh.set_instance_transform(i, Transform3D(Basis() if cells[i] else Basis().scaled(Vector3.ONE * 0.0001), at))
		&"seed_drill", &"harvester":
			var sowing := tool == &"seed_drill"
			plants.visible = true
			if sowing:
				plants.multimesh.mesh = FieldCropMeshes.get_mesh(crop, FieldCropMeshes.Stage.SEEDLING)
			else:
				(nodes.stubble as MultiMeshInstance3D).visible = true
			var shown := 0
			for i in clumps.size():
				var segment := clampi(int(floor((clumps[i].origin.z + row_length * 0.5) / SEGMENT)), 0, cells.size() - 1)
				var show := cells[segment] == 1 if sowing else cells[segment] == 0
				plants.multimesh.set_instance_transform(i, clumps[i] if show else Transform3D(Basis().scaled(Vector3.ONE * 0.0001), clumps[i].origin))
				shown += 1 if show else 0
			plants.set_meta(&"shown", shown)


## A row's strip of ploughed-soil tiles (one per SEGMENT), made the first time it's needed.
func _soil_tiles(index: int) -> MultiMeshInstance3D:
	var nodes: Dictionary = _row_nodes[index]
	if nodes.has("tiles"):
		return nodes.tiles
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(row_width * 0.94, 0.05, SEGMENT + 0.02)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = TILLED_SOIL
	soil.roughness = 1.0
	box.material = soil
	mm.mesh = box
	mm.instance_count = int(ceil(row_length / SEGMENT))
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), Vector3(_row_x(index), 0.045, 0)))
	var tiles := MultiMeshInstance3D.new()
	tiles.name = "SoilTiles%d" % index
	tiles.set_meta(&"built", true)
	tiles.multimesh = mm
	add_child(tiles)
	nodes.tiles = tiles
	return tiles


# ---- Look ---------------------------------------------------------------------

func _row_x(index: int) -> float:
	return (index - (rows - 1) * 0.5) * row_width


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"built"):
			child.free()
	_row_nodes.clear()
	var width := rows * row_width
	if crop and not crop.needs_flooding:
		# A dry field: worn earth (no bank, no water). Each row gets its own strip of
		# tilled soil (_build_row), shown once it's been hoed.
		var ground := StandardMaterial3D.new()
		ground.albedo_color = FIELD_GROUND
		ground.roughness = 1.0
		_box("Ground", Vector3(width + 0.6, 0.3, row_length + 0.6), Vector3(0, -0.11, 0), ground)
		for i in rows:
			_row_nodes.append(_build_row(i))
		return
	# The muddy floor and the low earth bank (bund) round it. Walk-through: no collision.
	var mud := StandardMaterial3D.new()
	mud.albedo_color = MUD
	mud.roughness = 0.95
	_box("Mud", Vector3(width + 0.3, 0.06, row_length + 0.3), Vector3(0, 0.02, 0), mud)
	var bund := StandardMaterial3D.new()
	bund.albedo_color = BUND
	bund.roughness = 1.0
	for side in [-1.0, 1.0]:
		_box("BundZ%d" % int(side), Vector3(width + 1.3, 0.26, 0.5), Vector3(0, 0.1, side * (row_length * 0.5 + 0.4)), bund)
		_box("BundX%d" % int(side), Vector3(0.5, 0.26, row_length + 1.3), Vector3(side * (width * 0.5 + 0.4), 0.1, 0), bund)
	# The water (shown while flooded).
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.set_meta(&"built", true)
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + 0.3, row_length + 0.3)
	_water.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.5, 0.52, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic = 0.2
	_water.material_override = water
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position = Vector3(0, WATER_HEIGHT, 0)
	add_child(_water)
	_show_water(false)
	if crop == null:
		return
	for i in rows:
		_row_nodes.append(_build_row(i))


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.set_meta(&"built", true)
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	add_child(mesh)
	return mesh


func _build_row(index: int) -> Dictionary:
	var x := _row_x(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([field_id, index])
	var clumps: Array[Transform3D] = []
	var lying: Array[Transform3D] = []
	var per_line := int(floor(row_length / plant_spacing))
	for k in per_line:
		for line in lines_per_row:
			var p := Vector3(x + (line - (lines_per_row - 1) * 0.5) * (row_width / lines_per_row) + rng.randf_range(-0.06, 0.06),
					0.04, -row_length * 0.5 + plant_spacing * (k + 0.5) + rng.randf_range(-0.06, 0.06))
			var s := rng.randf_range(0.85, 1.1)
			clumps.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
			# Cut: laid flat along the row, heads all one way, a little untidy.
			# (The tuft is squashed front-to-back first so, lying down, it's a low flat bundle.)
			var flat := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35)) * Basis(Vector3.RIGHT, -PI * 0.47)
			lying.append(Transform3D(flat * Basis().scaled(Vector3(s * 1.5, s, s * 0.45)), p + Vector3(0, 0.12, 0)))
	var nodes := {"clumps": clumps, "lying_xforms": lying}
	if needs_tilling():
		nodes.soil = _build_soil(index, x)
	nodes.plants = _multimesh("Plants%d" % index, crop, FieldCropMeshes.Stage.SEEDLING, clumps)
	nodes.lying = _multimesh("Lying%d" % index, crop, FieldCropMeshes.Stage.RIPE, lying)
	nodes.stubble = _multimesh("Stubble%d" % index, crop, FieldCropMeshes.Stage.STUBBLE, clumps)
	# The E spot: a box over the whole row.
	var spot := FieldRow.new()
	spot.name = "Row%d" % index
	spot.set_meta(&"built", true)
	spot.field = self
	spot.index = index
	spot.interaction_id = StringName("%s_row_%d" % [field_id, index])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(row_width * 0.98, 1.6, row_length)
	shape.shape = box
	spot.add_child(shape)
	spot.position = Vector3(x, 0.8, 0)
	add_child(spot)
	nodes.spot = spot
	return nodes


## A row's tilled soil: a dark strip with raised furrow ridges along it.
func _build_soil(index: int, x: float) -> Node3D:
	var soil := Node3D.new()
	soil.name = "Soil%d" % index
	soil.set_meta(&"built", true)
	soil.visible = false
	add_child(soil)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = TILLED_SOIL
	dark.roughness = 1.0
	var ridge := StandardMaterial3D.new()
	ridge.albedo_color = FURROW.lerp(TILLED_SOIL, 0.5)
	ridge.roughness = 1.0
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(row_width * 0.94, 0.05, row_length)
	strip.mesh = strip_mesh
	strip.material_override = dark
	strip.position = Vector3(x, 0.04, 0)
	soil.add_child(strip)
	var ridge_mesh := BoxMesh.new()
	ridge_mesh.size = Vector3(0.18, 0.08, row_length - 0.2)
	for line in lines_per_row:
		var r := MeshInstance3D.new()
		r.mesh = ridge_mesh
		r.material_override = ridge
		r.position = Vector3(x + (line - (lines_per_row - 1) * 0.5) * (row_width / lines_per_row), 0.08, 0)
		soil.add_child(r)
	return soil


func _multimesh(node_name: String, the_crop: FieldCropData, stage: int, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = FieldCropMeshes.get_mesh(the_crop, stage)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.set_meta(&"built", true)
	instance.multimesh = mm
	# Big fields: past this distance the plants aren't drawn (the soil still is).
	instance.visibility_range_end = 160.0
	instance.visibility_range_end_margin = 10.0
	instance.set_meta(&"shown", xforms.size())
	instance.visible = false
	add_child(instance)
	return instance


func _refresh_all() -> void:
	for i in _rows.size():
		_refresh_row(i)
	_show_water(false)


func _refresh_row(index: int) -> void:
	if index >= _row_nodes.size():
		return
	var row: Dictionary = _rows[index]
	var nodes: Dictionary = _row_nodes[index]
	var plants: MultiMeshInstance3D = nodes.plants
	var state := int(row.state)
	plants.visible = state == RowState.GROWING or state == RowState.RIPE
	if plants.visible:
		plants.multimesh.mesh = FieldCropMeshes.get_mesh(crop, _stage_for(row))
		_show_first(plants, nodes.clumps, nodes.clumps.size())
	var lying: MultiMeshInstance3D = nodes.lying
	lying.visible = state == RowState.CUT
	if lying.visible:
		# Fewer bundles lie there once some sheaves are tied and taken.
		var total := maxi(crop.sheaves_per_row.y, 1)
		var keep := int(ceil(nodes.lying_xforms.size() * clampf(float(row.sheaves) / total, 0.25, 1.0)))
		_show_first(lying, nodes.lying_xforms, keep)
	(nodes.stubble as MultiMeshInstance3D).visible = bool(row.stubble)
	if nodes.has("soil"):
		(nodes.soil as Node3D).visible = is_row_tilled(index)
	if nodes.has("tiles"):
		(nodes.tiles as Node3D).visible = false


## While the sickle works: the first part of the row lies cut, the rest still stands.
func _show_cut_progress(index: int, fraction: float) -> void:
	var nodes: Dictionary = _row_nodes[index]
	var clumps: Array[Transform3D] = nodes.clumps
	var cut := int(round(clumps.size() * clampf(fraction, 0.0, 1.0)))
	var plants: MultiMeshInstance3D = nodes.plants
	var lying: MultiMeshInstance3D = nodes.lying
	lying.visible = true
	(nodes.stubble as MultiMeshInstance3D).visible = true
	# Clumps run along the row in order, so "the first `cut`" is the cut stretch.
	for i in clumps.size():
		plants.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), clumps[i].origin) if i < cut else clumps[i])
		lying.multimesh.set_instance_transform(i, nodes.lying_xforms[i] if i < cut else Transform3D(Basis().scaled(Vector3.ONE * 0.0001), clumps[i].origin))
	plants.set_meta(&"shown", clumps.size() - cut)
	lying.set_meta(&"shown", cut)


func _show_first(instance: MultiMeshInstance3D, xforms: Array, count: int) -> void:
	for i in xforms.size():
		instance.multimesh.set_instance_transform(i, xforms[i] if i < count else Transform3D(Basis().scaled(Vector3.ONE * 0.0001), (xforms[i] as Transform3D).origin))
	instance.set_meta(&"shown", count)


func _visible_count(instance: MultiMeshInstance3D) -> int:
	return int(instance.get_meta(&"shown", 0)) if instance.visible else 0


func _stage_for(row: Dictionary) -> int:
	if int(row.state) == RowState.RIPE:
		return FieldCropMeshes.Stage.RIPE
	var grown := int(row.grown)
	if grown <= 0:
		return FieldCropMeshes.Stage.SEEDLING
	if grown >= crop.grow_days - 1:
		return FieldCropMeshes.Stage.HEADING
	return FieldCropMeshes.Stage.GROWING


func _show_water(animate: bool) -> void:
	if _water == null:
		return
	if not animate or not is_inside_tree():
		_water.visible = flooded
		_water.position.y = WATER_HEIGHT
		return
	_water.visible = true
	var tween := create_tween()
	if flooded:
		_water.position.y = 0.0
		tween.tween_property(_water, ^"position:y", WATER_HEIGHT, 1.2).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_property(_water, ^"position:y", -0.02, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func() -> void:
			_water.visible = flooded
			_water.position.y = WATER_HEIGHT)


# ---- SaveManager hook ---------------------------------------------------------

func get_save_key() -> String:
	return "field_%s" % field_id


func save_state() -> Dictionary:
	var saved_rows: Array = []
	for row in _rows:
		saved_rows.append(row.duplicate())
	return {"version": SAVE_VERSION, "flooded": flooded, "rows": saved_rows}


func load_state(data: Dictionary) -> void:
	flooded = bool(data.get("flooded", false))
	var saved: Array = data.get("rows", [])
	for i in mini(saved.size(), _rows.size()):
		var raw: Variant = saved[i]
		if raw is Dictionary:
			var r: Dictionary = raw
			_rows[i] = {"state": clampi(int(r.get("state", 0)), 0, RowState.TILLED), "grown": int(r.get("grown", 0)),
					"sheaves": int(r.get("sheaves", 0)), "stubble": bool(r.get("stubble", false))}
	_refresh_all()
