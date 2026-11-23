extends RefCounted
## Checks for the opening scene ("A Letter from Grandpa"). Called from test_runner.gd:
##   await preload("res://tests/opening_tests.gd").new().run(self)

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func run(t: Node) -> void:
	print("== Opening scene ==")
	ActivityClock.reset()
	GameManager.reset_flags()
	OpeningScene.request()
	t.check(OpeningScene.consume_request() and not OpeningScene.consume_request(), "New game asks for the opening once (Continue never does)")

	# A new game: the opening plays.
	OpeningScene.request()
	var main := MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(5)
	var opening := main.get_node_or_null("OpeningScene") as OpeningScene
	var player := main.get_node("Player") as PlayerController
	var hud := main.get_node("HUD") as CanvasLayer
	var minutes := ActivityClock.total_minutes
	t.check(opening != null and opening.is_running(), "after New game the opening plays")
	t.check(opening != null and player.is_input_locked() and not player.visible and not hud.visible, "while it plays the player can't move and the HUD is hidden")
	t.check(not SaveManager.is_session_running(), "nothing is saved until it's over")
	if opening == null:
		main.queue_free()
		await t._frames(3)
		return
	var arrival := opening.get_arrival()
	var boat := opening.get_boat()
	var to_village := Vector3(0, 0, 115) - arrival.origin
	t.check(arrival.origin.distance_to(Vector3(-95, arrival.origin.y, 180)) < 25.0, "it ends at the beach jetty in the south-west (%s)" % arrival.origin)
	t.check((-arrival.basis.z).dot(to_village.normalized()) > 0.5, "the player will face up the path towards the village")
	t.check(boat != null and boat.global_position.distance_to(arrival.origin) > 100.0, "the mail boat starts far out at sea")

	t.get_viewport().push_input(_esc())
	await t._frames(2)
	t.check(not t.get_tree().paused, "Esc doesn't open the pause menu during the opening")

	# Play it through quickly, reading the letter as it goes.
	opening.speed = 14.0
	var lines := {}
	var saw_glow := false
	var waited := 0
	while is_instance_valid(opening) and opening.is_running() and waited < 1200:
		var text := opening.get_letter_text()
		if text != "":
			lines[text] = true
		var glow := opening.get_node_or_null("LakeGlow") as Node3D
		saw_glow = saw_glow or (glow != null and glow.visible)
		await t._frames(1)
		waited += 1
	t.check(not is_instance_valid(opening) or not opening.is_running(), "the opening finishes (%d frames at 14x)" % waited)
	t.check(lines.size() >= 7 and lines.has("With love,\nGrandpa Elias"), "Grandpa's letter is shown line by line, signed Elias (%d lines seen)" % lines.size())
	t.check(saw_glow, "the light in the lake pulses once")
	await t._frames(20)
	t.check(GameManager.has_flag(OpeningScene.FLAG), "it is remembered as seen (story flag)")
	t.check(player.visible and not player.is_input_locked() and hud.visible, "afterwards the player can move and the HUD is back")
	t.check(player.global_position.distance_to(arrival.origin) < 1.5, "the player stands on the jetty")
	var cam := main.get_viewport().get_camera_3d()
	t.check(cam != null and player.is_ancestor_of(cam), "the normal over-the-shoulder camera takes over")
	t.check(is_instance_valid(boat) and boat.global_position.distance_to(arrival.origin) < 30.0, "the mail boat is moored beside the jetty")
	t.check(ActivityClock.total_minutes == minutes, "no in-game time passed")
	t.check(SaveManager.is_session_running(), "autosave starts once the opening is over")
	main.queue_free()
	await t._frames(3)

	# Holding a key for a second skips it.
	SaveManager.delete_save()
	GameManager.reset_flags()
	OpeningScene.request()
	main = MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(5)
	opening = main.get_node_or_null("OpeningScene") as OpeningScene
	player = main.get_node("Player") as PlayerController
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.keycode = KEY_SPACE
	key.pressed = true
	t.get_viewport().push_input(key)
	await t._frames(20)
	t.check(opening != null and opening.is_running() and player.is_input_locked(), "a quick tap doesn't skip")
	var held := 0
	while opening != null and player.is_input_locked() and held < 400:
		await t._frames(5)
		held += 5
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	t.get_viewport().push_input(release)
	t.check(not player.is_input_locked() and GameManager.has_flag(OpeningScene.FLAG), "holding a key skips to the end (%d frames)" % held)
	t.check(player.visible and player.global_position.distance_to(arrival.origin) < 1.5, "after a skip the player stands on the jetty")
	t.check((main.get_node("HUD") as CanvasLayer).visible, "and the HUD is back straight away")
	main.queue_free()
	await t._frames(3)

	# Seen already (for example, a later New game in a test): it doesn't play again.
	OpeningScene.request()
	main = MAIN_SCENE.instantiate()
	t.add_child(main)
	await t._frames(3)
	t.check(main.get_node_or_null("OpeningScene") == null, "once seen, it doesn't play again in the same run")
	main.queue_free()
	await t._frames(3)
	SaveManager.end_session()
	SaveManager.delete_save()
	GameManager.reset_flags()
	ActivityClock.reset()


func _esc() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"toggle_mouse"
	e.pressed = true
	return e
