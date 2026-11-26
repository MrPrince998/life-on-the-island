extends RefCounted
## Checks for woodcutting (ForestService), Bram's forge (BlacksmithService, ForgePanel)
## and the shop view (F at a counter: ShopFocus). Called from test_runner.gd:
##   await preload("res://tests/forestry_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Woodcutting, the forge and the shop view ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	InventoryManager.reset()
	Friendship.reset()
	QuestLog.reset()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(6)
	var player := main.get_node("Player") as PlayerController
	var service := ForestService.find(t.get_tree())
	var scatter := main.get_node("Island/Vegetation") as VegetationScatter
	t.check(service != null and scatter.get_choppable_layers().has(&"tree_broadleaf") and not scatter.get_choppable_layers().has(&"bush"), "the island's trees can be felled (bushes and rocks can't)")

	# Stand by a tree in the woods.
	var stand := _spot_by_a_tree(scatter)
	player.teleport_to(stand)
	await t._frames(3)
	var spot := service.get_chop_spot()
	t.check(not spot.enabled, "without an axe there's no \"Fell the tree\"")

	# ---- Bram's forge ----
	var forge_panel := main.get_node("ForgePanel") as ForgePanel
	t.check(BlacksmithService.can_forge(&"axe") == BlacksmithService.Result.MISSING_MATERIALS, "Bram needs wood before he can forge an axe")
	InventoryManager.add_item(&"wood", 4)
	InventoryManager.add_money(200 - InventoryManager.get_money())
	var clock := ActivityClock.total_minutes
	var forged := forge_panel.forge(&"axe")
	t.check(forged.result == BlacksmithService.Result.OK and InventoryManager.has_item(&"axe") and InventoryManager.get_count(&"wood") == 0 and InventoryManager.get_money() == 160, "forging an axe: 4 wood + 40 coins")
	t.check(ActivityClock.total_minutes == clock + 60, "you wait an hour while Bram works (the clock moves on)")
	t.check(BlacksmithService.can_buy(&"axe") == BlacksmithService.Result.ALREADY_OWNED and BlacksmithService.can_buy(&"steel_axe") == BlacksmithService.Result.NOT_ENOUGH_MONEY, "you only need one axe, and the steel one costs more than you have")

	# ---- Felling ----
	await t._frames(3)
	t.check(spot.enabled and spot.get_prompt().begins_with("Fell the tree"), "with an axe, standing by a tree: \"%s\"" % spot.get_prompt())
	var tree: Dictionary = spot.tree.duplicate()
	var layer := service.get_layer(tree.layer_id)
	var placed: Transform3D = tree.transform
	var base := placed.origin
	var shapes: Array = scatter._choppable[tree.layer_id].shapes
	clock = ActivityClock.total_minutes
	Engine.time_scale = 8.0
	var hits := [0]
	service.chop_hit.connect(func(_at: Vector3) -> void: hits[0] += 1)
	var felled_ok: bool = await service.fell(tree, player)
	t.check(felled_ok and hits[0] == layer.chop_hits, "it takes %d swings with the iron axe" % layer.chop_hits)
	var key := ForestService.tree_key(tree.layer_id, base)
	var felled := service.get_felled_node(key)
	t.check(service.is_felled(tree.layer_id, tree.index) and (shapes[tree.index] as CollisionShape3D).disabled and felled != null and felled.stage == FelledTree.Stage.TRUNK, "the tree comes down: it's no longer standing and no longer blocks the way")
	var away := base - player.global_position
	away.y = 0.0
	t.check(felled.fall_dir.dot(away.normalized()) > 0.95, "it falls away from you")
	t.check(service.has_stump(key), "a stump is left behind")
	t.check(ActivityClock.total_minutes == clock + ForestService.FELL_MINUTES, "felling a tree takes %d minutes" % ForestService.FELL_MINUTES)
	await t.get_tree().create_timer(FelledTree.FALL_SECONDS + 0.6).timeout
	t.check(not felled.is_falling(), "the trunk lands and lies on the ground")
	await t._frames(2)
	t.check(not spot.enabled or spot.tree.index != tree.index or spot.tree.layer_id != tree.layer_id, "a felled tree can't be felled again")

	# ---- Cutting it up ----
	t.check(felled.get_prompt().begins_with("Cut the trunk into logs"), "the fallen trunk: \"%s\"" % felled.get_prompt())
	clock = ActivityClock.total_minutes
	await service.cut_into_logs(felled, player)
	var logs := felled.logs
	t.check(felled.stage == FelledTree.Stage.LOGS and logs >= layer.log_yield.x and logs <= layer.log_yield.y and ActivityClock.total_minutes == clock + ForestService.BUCK_MINUTES, "cutting the trunk gives a row of %d logs (%d minutes)" % [logs, ForestService.BUCK_MINUTES])
	t.check(felled.get_node("Logs").get_child_count() == logs, "the logs lie on the ground")
	clock = ActivityClock.total_minutes
	var picked := service.collect_logs(felled)
	await t._frames(2)
	t.check(picked == logs and InventoryManager.get_count(&"log") == logs and not is_instance_valid(felled), "picking them up puts %d logs in the bag" % logs)
	t.check(ActivityClock.total_minutes == clock, "picking up logs costs no time")
	Engine.time_scale = 1.0

	# ---- Growing back ----
	t.check(service.get_growth(key) == 0.0, "at first there's just the stump")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6) + 24 * 60 * 2, &"test")
	await t._frames(2)
	t.check(service.get_growth(key) > 0.0 and service.get_growth(key) < 1.0 and not service.has_stump(key) and (shapes[tree.index] as CollisionShape3D).disabled, "a few days later a young tree sprouts where it stood")
	ActivityClock.advance_minutes(24 * 60 * 5, &"test")
	await t._frames(2)
	t.check(not service.is_felled(tree.layer_id, tree.index) and not (shapes[tree.index] as CollisionShape3D).disabled and service.get_felled(key).is_empty(), "about a week later it's a full tree again")

	# ---- Save and load ----
	Engine.time_scale = 8.0
	await t._frames(2)
	var second: Dictionary = service.find_standing_tree(player.global_position, 4.0)
	await service.fell(second, player)
	Engine.time_scale = 1.0
	var second_key := ForestService.tree_key(second.layer_id, (second.transform as Transform3D).origin)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(service.save_state()))
	service.load_state({})
	t.check(not service.is_felled(second.layer_id, second.index), "(loading an empty save stands every tree back up)")
	service.load_state(saved)
	await t._frames(2)
	var restored := service.get_felled_node(second_key)
	t.check(service.is_felled(second.layer_id, second.index) and restored != null and restored.stage == FelledTree.Stage.TRUNK and service.has_stump(second_key), "a felled tree survives save and load, still lying where it fell")

	# ---- Steel axe ----
	InventoryManager.add_money(1000)
	var bought := forge_panel.buy(&"steel_axe")
	t.check(bought.result == BlacksmithService.Result.OK and WoodcuttingController.best_axe() == &"steel_axe", "you can buy the steel axe outright")
	t.check(WoodcuttingController.swings_for(6) == 3 and service.fell_minutes() == ForestService.STEEL_FELL_MINUTES, "the steel axe fells a tree in half the swings, and quicker")
	t.check(BlacksmithService.materials_text(BlacksmithService.get_recipe(&"steel_axe")) == "6 Logs" and BlacksmithService.materials_text(BlacksmithService.get_recipe(&"axe")) == "4 Wood", "the forge lists what to bring (\"4 Wood\", \"6 Logs\")")

	# ---- Bram ----
	var bram := _villager(main, &"bram")
	t.check(bram != null and bram.data.role == "Blacksmith", "Bram the blacksmith lives in the village")

	# ---- Shop view (F) ----
	var rig := player.get_node("CameraRig") as CameraRig
	var store_counter := main.get_node("Island/Buildings/GeneralStore/ShopCounter") as ShopCounter
	var shop_panel := main.get_node("ShopPanel") as ShopPanel
	t.check(store_counter.get_prompt().contains("F: shop view"), "the store counter offers the shop view (F)")
	var follow_camera := rig.get_camera()
	store_counter.focus_shop(player)
	await t._frames(2)
	t.check(shop_panel.is_open() and not shop_panel._dim.visible and rig.is_focused() and rig.get_active_camera() != follow_camera, "F at the store: the camera moves to frame the shop and the window opens at the side")
	await t.get_tree().create_timer(1.0).timeout
	var cam := rig.get_active_camera()
	var to_shop := (store_counter.global_position - cam.global_position).normalized()
	t.check(-cam.global_basis.z.dot(to_shop) > 0.6 and cam.global_position.distance_to(store_counter.global_position) < 12.0, "the shot looks at the shop front from a few metres away")
	t.check(not (player.get_node("Visual") as Node3D).visible, "you step out of the picture so you don't stand in front of the shop")
	shop_panel.close()
	await t.get_tree().create_timer(0.9).timeout
	t.check(not rig.is_focused() and follow_camera.current and not player.is_input_locked() and (player.get_node("Visual") as Node3D).visible, "closing it glides the camera back behind you")

	var forge_counter := main.get_node("Island/Buildings/Forge/ForgeCounter") as ForgeCounter
	forge_counter.focus_shop(player)
	await t._frames(2)
	t.check(forge_panel.is_open() and forge_panel.is_docked() and rig.is_focused() and forge_panel.get_card_ids().size() == BlacksmithService.get_recipes().size(), "F at the forge works too: the forge and Bram, with his tools at the side")
	forge_panel.close()
	await t.get_tree().create_timer(0.9).timeout
	t.check(not rig.is_focused() and not player.is_input_locked(), "and closing it hands the view back")

	Engine.time_scale = 1.0
	GameManager.reset_flags()
	QuestLog.reset()
	Friendship.reset()
	InventoryManager.reset()
	ActivityClock.reset()
	main.queue_free()
	await t._frames(3)


## A spot on open, fairly flat ground about 1.6 m from a forest tree.
func _spot_by_a_tree(scatter: VegetationScatter) -> Vector3:
	var shape := IslandShape.shared()
	for t: Transform3D in scatter.get_placements(&"tree_broadleaf"):
		if Vector2(t.origin.x, t.origin.z).distance_to(IslandShape.FOREST_CENTER) > 60.0:
			continue
		for i in 8:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
			var p := t.origin + dir * 1.6
			p.y = shape.get_height(p.x, p.z)
			if absf(p.y - t.origin.y) < 0.4 and scatter.find_tree_near(p, 3.5).get("index", -1) == scatter.find_tree_near(t.origin, 0.3).get("index", -2):
				return p + Vector3.UP * 0.1
	return Vector3.ZERO


func _villager(main: Node, npc_id: StringName) -> Villager:
	for child in main.get_node("Villagers").get_children():
		if child is Villager and (child as Villager).data and (child as Villager).data.id == npc_id:
			return child
	return null
