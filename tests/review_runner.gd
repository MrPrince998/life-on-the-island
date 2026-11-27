extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.use_test_slot()
	get_tree().create_timer(90.0).timeout.connect(func() -> void: get_tree().quit(2))
	await preload("res://tests/review_cheats_tests.gd").new().run(self)
	print("REVIEW FAILURES: ", failures)
	get_tree().quit(1 if failures else 0)
