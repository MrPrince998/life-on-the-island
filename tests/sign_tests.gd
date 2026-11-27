extends RefCounted

func run(t: Node) -> void:
	print("== Quest guidance with one village signpost ==")
	GameManager.reset_flags()
	ActivityClock.reset()
	var main := preload("res://scenes/main/main.tscn").instantiate()
	t.add_child(main)
	await t._frames(6)
	var signs := []
	var models := []
	for node in main.find_children("*", "Node", true, false):
		if node is WorldSign: signs.append(str(main.get_path_to(node)))
		for asset in ["signpost.glb", "welcome_sign.glb", "notice_board.glb"]:
			if node.scene_file_path.ends_with(asset): models.append(node.scene_file_path)
	t.check(signs == ["Island/Buildings/Signpost"] and models == ["res://source_assets/tripo/signpost.glb"], "only the village junction signboard is instantiated")
	t.check(not main.has_node("Island/StoryPlaces/Coast/BeachJetty/WelcomeSign"), "welcome board stays removed")
	var junction := main.get_node("Island/Buildings/Signpost") as WorldSign
	t.check(junction.model_style == 2 and junction.has_node("Vines") and junction._faces.size() == 6, "junction retains its three planks and 3D vines")
	t.check(junction.text == "East · Sunflower Fields\nWest · Fernwood Forest\nNortheast · Lighthouse" and junction.get_node("FrontText/CutHighlight") != null, "junction retains destination wording and carved lettering")
	var requests := main.get_node("Island/StoryPlaces/Village/Mailbox/Requests") as NoticeBoardSpot
	t.check(requests != null and requests.get_prompt().contains("village requests") and requests.interaction_id == &"village_notice_board", "village mailbox keeps the existing request interaction and save ID")
	var lake := main.get_node("Island/StoryPlaces/Lake/LakesideProject") as LakesideProject
	t.check(not lake.has_node("Signpost") and lake.find_children("*", "Label3D", true, false).is_empty(), "lakeside has no signboard or floating name labels")
	for flag in LakesideProject.CLEAR_FLAGS: GameManager.set_flag(flag)
	t.check(lake.get_node("LakeChoice").enabled and lake.get_node("SunsetChoice").enabled, "bench choices work without a sign")
	lake.place_bench(false)
	t.check(lake.get_node("Invite").enabled and lake.get_node("Bench").visible, "restored bench and invitation remain usable")
	var market := main.get_node("Island/StoryPlaces/Village/MarketRepairBase/Repair") as RestorationSite
	t.check(not market.get_node("RunDown").has_node("Sign"), "repair sites do not create replacement boards")
	t.check(main.has_node("HUD/QuestTracker") or not main.find_children("QuestTracker", "Control", true, false).is_empty(), "quest guidance remains available")
	main.queue_free()
	await t._frames(3)
	GameManager.reset_flags()
	ActivityClock.reset()
