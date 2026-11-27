class_name LakesideProject
extends Node3D
## Optional restoration and shared fishing. Permanent progress is saved; visits
## are transient so loading never traps a villager outside their daily schedule.
const BENCH_FLAG := &"lakeside_bench"
const SUNSET_FLAG := &"lakeside_sunset"
const BIRDS_FLAG := &"lakeside_birds"
const SHARED_FLAG := &"lakeside_shared_fish"
const CLEAR_FLAGS: Array[StringName] = [&"lakeside_clear_0", &"lakeside_clear_1", &"lakeside_clear_2"]
const FRIENDSHIP_POINTS := 20
var birds_due: int = -1
var reward_day: int = -1
var _oliver: Villager
var _player: PlayerController
var _fishing: FishingController

func _enter_tree() -> void:
	global_position.y = IslandShape.shared().get_height(global_position.x, global_position.z)

func _ready() -> void:
	add_to_group(&"persistent")
	GameManager.flag_changed.connect(_flag_changed)
	ActivityClock.time_changed.connect(_time_changed)
	_refresh()

func all_clear() -> bool:
	for flag in CLEAR_FLAGS:
		if not GameManager.has_flag(flag):
			return false
	return true

func place_bench(sunset: bool) -> bool:
	if not all_clear() or GameManager.has_flag(BENCH_FLAG):
		return false
	GameManager.set_flag(SUNSET_FLAG, sunset)
	birds_due = ActivityClock.total_minutes + ActivityClock.minutes_until(6)
	GameManager.set_flag(BENCH_FLAG)
	ActivityClock.advance_minutes(15, &"lakeside_bench")
	GameManager.notify("A place to linger. Invite Oliver beside the bench, or sit and enjoy the view. Look for birds tomorrow morning!")
	return true

func _flag_changed(_flag: StringName, _value: bool) -> void:
	_refresh()

func _refresh() -> void:
	var built := GameManager.has_flag(BENCH_FLAG)
	for i in CLEAR_FLAGS.size():
		var pile := get_node("Debris%d" % i) as Node3D
		pile.visible = not GameManager.has_flag(CLEAR_FLAGS[i])
		pile.process_mode = Node.PROCESS_MODE_INHERIT if pile.visible else Node.PROCESS_MODE_DISABLED
	for path in ["LakeChoice", "SunsetChoice"]:
		var action := get_node(path) as LakesideAction
		action.enabled = all_clear() and not built
		action.visible = action.enabled
	var bench := $Bench as Node3D
	bench.visible = built
	bench.process_mode = Node.PROCESS_MODE_INHERIT if built else Node.PROCESS_MODE_DISABLED
	bench.rotation.y = -PI * 0.5 if GameManager.has_flag(SUNSET_FLAG) else PI
	($Invite as LakesideAction).enabled = built
	$Invite.visible = built
	$Flowers.visible = built
	$Birds.visible = GameManager.has_flag(BIRDS_FLAG)
	$Birds.process_mode = Node.PROCESS_MODE_INHERIT if $Birds.visible else Node.PROCESS_MODE_DISABLED

func _time_changed(_day: int, _minute: int) -> void:
	if birds_due >= 0 and ActivityClock.total_minutes >= birds_due and GameManager.has_flag(BENCH_FLAG) and not GameManager.has_flag(BIRDS_FLAG):
		GameManager.set_flag(BIRDS_FLAG)
		GameManager.notify("Birds have returned to your quiet corner at Moonlit Lake.")

func is_visiting() -> bool:
	return is_instance_valid(_oliver)

func invite(player: PlayerController) -> bool:
	if is_visiting() or not GameManager.has_flag(BENCH_FLAG) or player == null:
		return false
	var fishing := player.get_node_or_null("Fishing") as FishingController
	if fishing == null or not fishing.has_rod():
		GameManager.notify("Meet Oliver by the lake first. He has a spare fishing rod for you.")
		return false
	for node in get_tree().get_nodes_in_group(&"villagers"):
		var villager := node as Villager
		if villager and villager.data.id == &"oliver":
			_oliver = villager
			break
	if not is_visiting():
		return false
	_player = player
	_fishing = fishing
	var entry := NPCScheduleEntry.new()
	entry.position = Vector3(11, 0, 61.5)
	entry.facing_degrees = 180.0
	_oliver.begin_shared_activity(entry)
	_fishing.catch_finished.connect(_caught)
	GameManager.notify("Oliver: I'll meet you at the fishing dock. Cast beside me when I arrive. We have all the time in the world.")
	return true

func _process(_delta: float) -> void:
	if is_visiting() and (not is_instance_valid(_player) or _player.global_position.distance_to(global_position) > 55.0):
		end_visit()

func _caught(_fish: FishData, _size: float, _info: Dictionary) -> void:
	if not is_visiting() or not is_instance_valid(_player):
		return
	# A catch elsewhere or while Oliver is still walking is not a shared activity.
	if _oliver.get_mode() != Villager.Mode.ACTIVITY or _player.global_position.distance_to(_oliver.global_position) > 9.0:
		return
	if reward_day != ActivityClock.get_day():
		reward_day = ActivityClock.get_day()
		Friendship.add_points(&"oliver", FRIENDSHIP_POINTS)
		GameManager.set_flag(SHARED_FLAG)
		GameManager.notify("Oliver: Your grandpa always said the best catch was good company. Thank you for bringing this place back. (+20 friendship)")
	else:
		GameManager.notify("Oliver: Another lovely catch. I'm glad we spent today together.")
	_oliver.cheer()

func end_visit() -> void:
	if is_instance_valid(_fishing) and _fishing.catch_finished.is_connected(_caught):
		_fishing.catch_finished.disconnect(_caught)
	if is_instance_valid(_oliver):
		_oliver.end_shared_activity()
	_oliver = null
	_player = null
	_fishing = null

func _exit_tree() -> void:
	end_visit()

func get_save_key() -> String:
	return "lakeside_project"

func save_state() -> Dictionary:
	return {"birds_due": birds_due, "reward_day": reward_day}

func load_state(data: Dictionary) -> void:
	end_visit()
	birds_due = int(data.get("birds_due", -1))
	reward_day = int(data.get("reward_day", -1))
	_time_changed(0, 0)
	_refresh()
