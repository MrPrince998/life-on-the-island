extends RefCounted

func run(t: Node) -> void:
	print("== Lakeside restoration and company ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	Friendship.reset()
	var main := preload("res://scenes/main/main.tscn").instantiate()
	t.add_child(main)
	await t._frames(6)
	var project := main.get_node("Island/StoryPlaces/Lake/LakesideProject") as LakesideProject
	var player := main.get_node("Player") as PlayerController
	var fishing := player.get_node("Fishing") as FishingController
	var oliver := main.get_node("Villagers/Oliver") as Villager
	t.check(not project.place_bench(false) and not project.get_node("Bench").visible, "bench requires every debris pile to be cleared")
	var start := ActivityClock.total_minutes
	for i in 3:
		var work := project.get_node("Debris%d/Clear" % i) as StoryActivity
		t.check(work.finish_now() and not work.finish_now(), "debris %d clears once" % i)
	t.check(ActivityClock.total_minutes == start + 45 and project.get_node("LakeChoice").enabled, "clearing costs 45 minutes and opens the orientation choice")
	t.check(project.place_bench(true) and not project.place_bench(false), "choose sunset once without spending materials")
	t.check(is_equal_approx(project.get_node("Bench").rotation.y, -PI * 0.5) and project.get_node("Bench").visible, "chosen bench orientation is visible")
	t.check(not project.invite(player), "invitation explains missing rod")
	fishing.grant_rod()
	player.teleport_to(Vector3(10, 4, 62), PI)
	t.check(project.invite(player), "Oliver accepts a lakeside invitation")
	await t._frames(120)
	# Schedule changes must not pull Oliver away while sharing an activity.
	ActivityClock.advance_minutes(ActivityClock.minutes_until(12), &"test")
	t.check(oliver.get_entry().position == Vector3(11, 0, 61.5), "Oliver stays at the dock across his noon schedule change")
	var points := Friendship.get_points(&"oliver")
	player.teleport_to(Vector3(60, 4, 80), PI)
	fishing.catch_finished.emit(preload("res://data/fish/silver_minnow.tres"), 10.0, {})
	t.check(Friendship.get_points(&"oliver") == points, "distant catches do not earn shared friendship")
	player.teleport_to(Vector3(10, 4, 62), PI)
	fishing.catch_finished.emit(preload("res://data/fish/silver_minnow.tres"), 10.0, {})
	fishing.catch_finished.emit(preload("res://data/fish/silver_minnow.tres"), 10.0, {})
	t.check(Friendship.get_points(&"oliver") == points + 20, "nearby catches award friendship only once per day")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.collect_state()))
	project.end_visit()
	t.check(not project.is_visiting() and oliver.get_entry().activity == &"sit", "ending the invitation restores Oliver's noon schedule")
	project.load_state(saved.world.lakeside_project)
	t.check(project.reward_day == ActivityClock.get_day() and not project.get_node("Birds").visible, "reward cooldown and pending birds survive a save round trip")
	ActivityClock.advance_minutes(ActivityClock.minutes_until(6), &"sleep")
	t.check(GameManager.has_flag(LakesideProject.BIRDS_FLAG) and project.get_node("Birds").visible, "birds return at the next morning")
	player.teleport_to(Vector3(10, 4, 62), PI)
	t.check(project.invite(player), "a new day allows another visit")
	await t._frames(120)
	points = Friendship.get_points(&"oliver")
	fishing.catch_finished.emit(preload("res://data/fish/silver_minnow.tres"), 10.0, {})
	t.check(Friendship.get_points(&"oliver") == points + 20, "friendship reward is available again next day")
	player.teleport_to(Vector3(80, 4, 120), PI)
	await t._frames(3)
	t.check(not project.is_visiting(), "walking away ends the visit without penalty")
	main.queue_free()
	await t._frames(3)
	# Recreate the world with saved flags and pending due time, like Continue.
	GameManager.flags_from_dict(saved.flags)
	var restored := preload("res://scenes/world/lakeside_project.tscn").instantiate() as LakesideProject
	t.add_child(restored)
	restored.load_state(saved.world.lakeside_project)
	t.check(restored.get_node("Bench").visible and is_equal_approx(restored.get_node("Bench").rotation.y, -PI * 0.5), "new scene restores the selected bench")
	t.check(restored.get_node("Birds").visible, "loading an overdue wildlife change applies it immediately")
	restored.queue_free()
	await t._frames(2)
	GameManager.reset_flags()
	Friendship.reset()
	ActivityClock.reset()
