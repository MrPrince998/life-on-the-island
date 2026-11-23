class_name Villager
extends Node3D
## A villager (Oliver, Mia, …): plays their Mixamo animations, follows a daily
## schedule driven by the ActivityClock, waves when you come close and talks when
## you press E. Who they are lives in an NPCData resource (data/npcs/*.tres).
##
## Schedule positions are island coordinates: the villager's parent (Villagers) sits
## exactly where the Island node is, so they line up with the terrain and props.
##
## Walking around and talking never change the in-game time. The villager only moves
## on to the next part of their day when the clock moves (because the player did an
## activity); they then walk there in real time.

signal line_shown(npc_name: String, text: String)
signal conversation_ended(npc_id: StringName)

const GREET_DISTANCE := 6.0
const GREET_COOLDOWN := 40.0
const TALK_END_DISTANCE := 6.5
const ARRIVE_DISTANCE := 0.12
const TURN_SHARPNESS := 7.0
const BLEND := 0.3
const TALK_CLIPS: Array[StringName] = [&"talk_a", &"talk_b", &"talk_c"]
const ONE_SHOTS: Array[StringName] = [&"wave", &"nod", &"happy", &"look_around", &"sit_down", &"stand_up"]
## Friendship lines join the conversation from this many hearts.
const FRIEND_LINES_HEARTS := 3
## How long a gift reaction stays up (seconds) when you're not chatting.
const REACTION_TIME := 4.0
const HEART_FULL := preload("res://assets/ui/icons/heart.svg")
const HEART_EMPTY := preload("res://assets/ui/icons/heart_empty.svg")

enum Mode { ACTIVITY, WALKING, TALKING }

@export var data: NPCData

## "Already met" memory when GameManager has no story flags.
static var _met_fallback: Dictionary = {}

var _model: Node3D
var _anim: AnimationPlayer
var _mode: int = Mode.ACTIVITY
var _entry: NPCScheduleEntry
var _path: Array[Vector3] = []
var _target_yaw := 0.0
var _activity_clip: StringName = &"idle"
var _talk_clip: StringName = &"talk_a"
var _sitting := false
var _leaving_seat := false
var _resume_walk := false
var _greet_cooldown := 0.0
var _player_was_near := false
var _fidget_timer := 8.0
var _lines: PackedStringArray = PackedStringArray()
var _line_index := -1
var _in_intro := false
var _later_index := 0
var _partner: Node3D
var _height_tween: Tween
var _hearts: Node3D
## "!" above the head when they have a request for you, "?" when you can hand
## something over.
var _marker: Label3D
var _marker_timer: float = 0.0
## Story conversations already heard this session (flag -> true).
var _story_heard: Dictionary = {}
var _story_flag: StringName = &""
var _reaction_timer: float = 0.0

@onready var _bubble: Label3D = $Bubble
@onready var _name_label: Label3D = $NameLabel
@onready var _talk_spot: TalkSpot = $TalkSpot


func _ready() -> void:
	add_to_group(&"villagers")
	if data == null:
		push_warning("Villager %s has no NPCData" % name)
		return
	_talk_spot.interaction_id = StringName("talk_" + str(data.id))
	_talk_spot.prompt_text = "Talk to " + data.display_name
	_build_model()
	_style_labels()
	_build_hearts()
	_build_marker()
	_bubble.hide()
	_name_label.hide()
	Friendship.friendship_changed.connect(func(npc_id: StringName, _p: int) -> void:
		if data and npc_id == data.id:
			_refresh_hearts())
	Friendship.heart_gained.connect(func(npc_id: StringName, hearts: int) -> void:
		if data and npc_id == data.id:
			GameManager.notify("You and %s are becoming good friends! (%d %s)" % [data.display_name, hearts, "heart" if hearts == 1 else "hearts"]))
	_fidget_timer = randf_range(6.0, 12.0)
	ActivityClock.time_changed.connect(_on_time_changed)
	# A story flag can switch the whole day plan (see NPCData.schedule_flag).
	GameManager.flag_changed.connect(func(flag: StringName, _value: bool) -> void:
		if data and flag == data.schedule_flag and flag != &"":
			_on_time_changed(ActivityClock.get_day(), 0))
	_entry = data.entry_for_hour(ActivityClock.get_hour())
	if _entry:
		_arrive(true)


# ---------------------------------------------------------------- public

func get_mode() -> int:
	return _mode


func get_current_clip() -> StringName:
	return _anim.current_animation if _anim else &""


func get_entry() -> NPCScheduleEntry:
	return _entry


## The ground points still ahead on the current walk (empty when not walking).
func get_walk_path() -> Array[Vector3]:
	return _path.duplicate()


func is_sitting() -> bool:
	return _sitting


func get_talk_prompt() -> String:
	if _mode != Mode.TALKING:
		if data == null:
			return ""
		var text := "Talk to " + data.display_name
		if has_met():
			text += "  ·  G: gift given today" if Friendship.gifted_today(data.id) else "  ·  G: give a gift"
		return text
	return "Say goodbye" if _line_index >= _lines.size() - 1 else "Next"


## G near the villager: opens the gift screen (after you've said hello once).
func request_gift(interactor: Node) -> void:
	if data == null:
		return
	if not has_met():
		GameManager.notify("Say hello to %s first (E)." % data.display_name)
		return
	var panel := get_tree().get_first_node_in_group(&"gift_panel")
	if panel and panel.has_method(&"open_for"):
		panel.call(&"open_for", self, interactor)


## Shows the villager's reaction to a gift in their speech bubble.
func react_to_gift(result: Dictionary) -> void:
	if data == null or not result.get("ok", false):
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and not _sitting and _mode != Mode.WALKING:
		_target_yaw = _yaw_to(player.global_position)
	_name_label.text = data.display_name
	_name_label.show()
	_refresh_hearts()
	_hearts.show()
	_bubble.text = String(result.get("line", ""))
	_bubble.show()
	line_shown.emit(data.display_name, _bubble.text)
	if _mode != Mode.TALKING:
		_reaction_timer = REACTION_TIME
	if not _sitting and _mode != Mode.WALKING:
		var taste := int(result.get("taste", Friendship.Taste.NEUTRAL))
		_play_once(&"happy" if taste <= Friendship.Taste.LIKED else &"nod")


func get_bubble_text() -> String:
	return _bubble.text if _bubble.visible else ""


## E on the villager: starts a conversation, or shows the next line.
func talk(interactor: Node) -> void:
	if data == null:
		return
	if _mode != Mode.TALKING:
		_start_conversation(interactor as Node3D)
	else:
		_next_line()


func end_conversation() -> void:
	if _mode != Mode.TALKING:
		return
	_bubble.hide()
	_name_label.hide()
	_hearts.hide()
	if _in_intro:
		_mark_met()
	_mode = Mode.ACTIVITY
	_partner = null
	conversation_ended.emit(data.id)
	var away_from_spot := _entry != null and _flat(position).distance_to(_flat(_entry.position)) > 0.5
	if _resume_walk or away_from_spot:
		_resume_walk = false
		_begin_walk()
		return
	_target_yaw = deg_to_rad(_entry.facing_degrees) if _entry else rotation.y
	if not _sitting:
		_play_once(&"wave")


## A happy little bounce when the player plays a melody nearby. Ignored while sitting,
## talking or walking.
func cheer() -> void:
	if _mode == Mode.ACTIVITY and not _sitting and not _is_one_shot_playing():
		_play_once(&"happy")


## Turns towards a point and waves once (the opening scene uses this). Ignored while
## sitting, talking or walking.
func wave_towards(point: Vector3) -> void:
	if _mode != Mode.ACTIVITY or _sitting:
		return
	_target_yaw = _yaw_to(point)
	_play_once(&"wave")


func has_met() -> bool:
	var flag := StringName("met_" + str(data.id))
	if GameManager.has_method(&"has_flag"):
		return GameManager.call(&"has_flag", flag)
	return _met_fallback.get(data.id, false)


# ---------------------------------------------------------------- schedule

func _on_time_changed(_day: int, _minute_of_day: int) -> void:
	var wanted := data.entry_for_hour(ActivityClock.get_hour())
	if wanted == null or wanted == _entry:
		return
	_entry = wanted
	if _mode == Mode.TALKING:
		_resume_walk = true  # finish the chat first
		return
	_begin_walk()


func _begin_walk() -> void:
	if _sitting:
		# Stand up first; the walk starts when stand_up finishes.
		_sitting = false
		_leaving_seat = true
		_ease_height(_ground(position.x, position.z), &"stand_up", 0.15, 0.55)
		_play_once(&"stand_up")
		return
	_path.clear()
	var stops: Array[Vector3] = []
	for p in _entry.via:
		stops.append(p)
	stops.append(_entry.position)
	# Willow Creek can't be waded: any leg that would cross it goes over the bridge.
	var shape := IslandShape.shared()
	var here := position
	for stop in stops:
		if shape.crosses_creek(_flat(here), _flat(stop)):
			var ends := shape.get_bridge_ends()
			if ends[1].distance_to(_flat(here)) < ends[0].distance_to(_flat(here)):
				ends.reverse()
			for end in ends:
				_path.append(Vector3(end.x, 0.0, end.y))
		_path.append(stop)
		here = stop
	_mode = Mode.WALKING
	_play(&"walk")


func _arrive(instant: bool) -> void:
	var p := _entry.position
	position = Vector3(p.x, _ground(p.x, p.z) + _entry.height_offset, p.z)
	_target_yaw = deg_to_rad(_entry.facing_degrees)
	if instant:
		rotation.y = _target_yaw
	_mode = Mode.ACTIVITY
	match _entry.activity:
		NPCScheduleEntry.SIT:
			_sitting = true
			_activity_clip = &"sit_idle"
			if instant:
				_play(&"sit_idle")
			else:
				# Start at ground level and settle onto the seat while sitting down.
				position.y = _ground(p.x, p.z)
				_ease_height(_ground(p.x, p.z) + _entry.height_offset, &"sit_down", 0.25, 0.6)
				_play_once(&"sit_down")
		NPCScheduleEntry.PLANT:
			_activity_clip = &"plant"
			_play(_activity_clip)
		NPCScheduleEntry.WATER:
			_activity_clip = &"water"
			_play(_activity_clip)
		_:
			_activity_clip = &"idle"
			_play(_activity_clip)


func _physics_process(delta: float) -> void:
	if data == null or _anim == null:
		return
	_greet_cooldown -= delta
	_update_marker(delta)
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		if _reaction_timer <= 0.0 and _mode != Mode.TALKING:
			_bubble.hide()
			_name_label.hide()
			_hearts.hide()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	match _mode:
		Mode.WALKING:
			_walk_step(delta)
		Mode.ACTIVITY:
			_activity_step(delta, player)
		Mode.TALKING:
			if _partner and is_instance_valid(_partner):
				if not _sitting:
					_target_yaw = _yaw_to(_partner.global_position)
				if _flat(_partner.global_position).distance_to(_flat(global_position)) > TALK_END_DISTANCE:
					end_conversation()
			else:
				end_conversation()
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-TURN_SHARPNESS * delta))


func _walk_step(delta: float) -> void:
	if _path.is_empty():
		_arrive(false)
		return
	var target := _path[0]
	var here := _flat(position)
	var to := _flat(target) - here
	var distance := to.length()
	if distance <= ARRIVE_DISTANCE:
		_path.pop_front()
		if _path.is_empty():
			_arrive(false)
		return
	var step := minf(distance, data.walk_speed * delta)
	var next := here + to / distance * step
	position = Vector3(next.x, _ground(next.x, next.y), next.y)
	_target_yaw = atan2(to.x, to.y)


func _activity_step(delta: float, player: Node3D) -> void:
	var near := player != null and _flat(player.global_position).distance_to(_flat(global_position)) < GREET_DISTANCE
	if near and not _player_was_near and _greet_cooldown <= 0.0 and not _sitting and not _is_one_shot_playing():
		_greet_cooldown = GREET_COOLDOWN
		_target_yaw = _yaw_to(player.global_position)
		_play_once(&"wave")
	_player_was_near = near
	if _activity_clip == &"idle" and not _is_one_shot_playing():
		_fidget_timer -= delta
		if _fidget_timer <= 0.0:
			_fidget_timer = randf_range(9.0, 16.0)
			_play_once(&"look_around")


# ---------------------------------------------------------------- talking

func _start_conversation(partner: Node3D) -> void:
	_resume_walk = _mode == Mode.WALKING
	_mode = Mode.TALKING
	_partner = partner
	_greet_cooldown = GREET_COOLDOWN
	_player_was_near = true
	_in_intro = _wants_intro()
	# Meeting someone because the story sent you to them ("Ask Mr. Ambrose about the
	# ledger", "Meet Luna"): the story conversation is the first meeting, so it plays
	# instead of the everyday hello and the step ticks off at once (not on a second chat).
	if _in_intro and data.intro_action == &"":
		var waiting := QuestLog.get_turn_in_for(data.id)
		if waiting and QuestLog.get_current_step(waiting.id).kind == QuestStep.Kind.TALK:
			_in_intro = false
			_mark_met()
	_reaction_timer = 0.0
	# The first chat each day brings you a little closer.
	Friendship.record_talk(data.id)
	var pool := data.later_lines
	if Friendship.get_hearts(data.id) >= FRIEND_LINES_HEARTS and not data.friend_lines.is_empty():
		pool = data.friend_lines if _later_index % 2 == 1 or data.later_lines.is_empty() else data.later_lines
	# Quests come first: handing something over, then a new request.
	var quest_lines := PackedStringArray()
	if not _in_intro:
		var turn_in := QuestLog.get_turn_in_for(data.id)
		if turn_in:
			quest_lines = QuestLog.turn_in(turn_in.id)
		else:
			var offer := QuestLog.get_offer_for(data.id)
			if offer:
				quest_lines = offer.offer_lines if not offer.offer_lines.is_empty() else PackedStringArray(["Could you help me with something?"])
				QuestLog.accept_offer(offer.id)
	var story := _story_lines()
	# Each story conversation plays once, the first chat after its flag turns on; then
	# the villager goes back to everyday (and friendly) chat.
	var story_due: bool = not story.is_empty() and not bool(_story_heard.get(_story_flag, false))
	if _in_intro:
		_lines = data.intro_lines
	elif not quest_lines.is_empty():
		_lines = quest_lines
	elif story_due:
		_lines = story
		_story_heard[_story_flag] = true
	elif not pool.is_empty():
		_lines = PackedStringArray([pool[_later_index % pool.size()]])
		_later_index += 1
	else:
		_lines = PackedStringArray(["…"])
	_line_index = -1
	if not _sitting:
		_talk_clip = TALK_CLIPS[randi() % TALK_CLIPS.size()]
		_play(_talk_clip)
	_name_label.text = data.display_name
	_name_label.show()
	_refresh_hearts()
	_hearts.visible = has_met() or not _in_intro
	_next_line()


func _next_line() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		end_conversation()
		return
	var text := _lines[_line_index]
	_bubble.text = text
	_bubble.show()
	line_shown.emit(data.display_name, text)
	if _in_intro and _line_index == data.intro_action_line:
		_run_action(data.intro_action)
	if not _sitting and _line_index > 0 and _line_index % 2 == 0:
		_play_once(&"nod")


## The conversation for the latest story flag that is on (NPCData.story_lines), or
## an empty list when none applies. Remembers which flag it was in _story_flag.
func _story_lines() -> PackedStringArray:
	var chosen := PackedStringArray()
	for flag in data.story_lines:
		if GameManager.has_flag(StringName(str(flag))):
			_story_flag = StringName(str(flag))
			var lines: Variant = data.story_lines[flag]
			if lines is PackedStringArray:
				chosen = lines
			elif lines is Array:
				chosen = PackedStringArray(lines)
	return chosen


func _wants_intro() -> bool:
	if data.intro_lines.is_empty():
		return false
	if data.intro_needs == &"no_rod":
		var fc := get_tree().get_first_node_in_group(&"fishing_controller")
		if fc and fc.has_method(&"has_rod"):
			return not fc.call(&"has_rod")
	return not has_met()


func _mark_met() -> void:
	var flag := StringName("met_" + str(data.id))
	if GameManager.has_method(&"set_flag"):
		GameManager.call(&"set_flag", flag)
	_met_fallback[data.id] = true


func _run_action(action: StringName) -> void:
	match action:
		&"grant_rod":
			var fc := get_tree().get_first_node_in_group(&"fishing_controller")
			if fc and fc.has_method(&"grant_rod"):
				fc.call(&"grant_rod")
			if not _sitting:
				_play_once(&"happy")


# ---------------------------------------------------------------- animation

func _build_model() -> void:
	_model = data.model.instantiate() as Node3D
	_model.name = "Model"
	_model.scale = Vector3.ONE * data.model_scale
	add_child(_model)
	_anim = AnimationPlayer.new()
	_anim.name = "AnimationPlayer"
	_model.add_child(_anim)
	if data.animations:
		_anim.add_animation_library(&"", data.animations)
	_anim.animation_finished.connect(_on_animation_finished)
	# Their steps, heard nearby (quieter than the player's own).
	var steps := Footsteps.new()
	steps.positional = true
	steps.base_db = -10.0
	add_child(steps)
	var height := 1.0 * data.model_scale
	_name_label.position.y = height + 0.25
	_bubble.position.y = height + 0.62


## Moves the villager up or down (onto or off a seat) during part of a clip:
## from `start` to `start + span` (fractions of the clip's length).
func _ease_height(to_y: float, clip: StringName, start: float, span: float) -> void:
	var length := _anim.get_animation(clip).length if _anim and _anim.has_animation(clip) else 1.0
	if _height_tween:
		_height_tween.kill()
	_height_tween = create_tween()
	_height_tween.tween_interval(length * start)
	_height_tween.tween_property(self, "position:y", to_y, length * span).set_trans(Tween.TRANS_SINE)


func _play(clip: StringName) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip, BLEND)


func _play_once(clip: StringName) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip, BLEND)


func _is_one_shot_playing() -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation in ONE_SHOTS


func _on_animation_finished(clip: StringName) -> void:
	match clip:
		&"sit_down":
			_play(&"sit_idle")
		&"stand_up":
			if _leaving_seat:
				_leaving_seat = false
				if _mode != Mode.TALKING:
					_begin_walk()
		_:
			if _mode == Mode.TALKING:
				_play(_talk_clip if not _sitting else &"sit_idle")
			elif _mode == Mode.ACTIVITY:
				if clip == &"wave" and _entry:
					_target_yaw = deg_to_rad(_entry.facing_degrees)
				_play(_activity_clip)


# ---------------------------------------------------------------- quest marker

func _build_marker() -> void:
	_marker = Label3D.new()
	_marker.name = "QuestMarker"
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.render_priority = 10
	_marker.outline_render_priority = 9
	_marker.font_size = 96
	_marker.outline_size = 22
	_marker.pixel_size = 0.0045
	_marker.modulate = UIPalette.HONEY
	_marker.outline_modulate = UIPalette.WOOD_DARK
	var font := FontVariation.new()
	font.base_font = load("res://assets/ui/fonts/Fredoka.ttf")
	_marker.font = font
	_marker.visible = false
	add_child(_marker)


## What the marker shows now: "!" (a request), "?" (ready to hand over) or "".
func get_quest_marker() -> String:
	if data == null or not has_met():
		return ""
	if QuestLog.get_turn_in_for(data.id):
		return "?"
	if QuestLog.get_offer_for(data.id):
		return "!"
	return ""


func _update_marker(delta: float) -> void:
	if _marker == null:
		return
	_marker_timer -= delta
	if _marker_timer <= 0.0:
		_marker_timer = 0.5
		var text := get_quest_marker()
		_marker.text = text
		_marker.visible = text != "" and _mode != Mode.TALKING
	if _marker.visible:
		_marker.position.y = _name_label.position.y + 0.15 + sin(Time.get_ticks_msec() * 0.004) * 0.06


# ---------------------------------------------------------------- friendship hearts

## A row of hearts between the name and the speech bubble, shown while chatting.
func _build_hearts() -> void:
	_hearts = Node3D.new()
	_hearts.name = "Hearts"
	add_child(_hearts)
	_hearts.hide()
	for i in Friendship.MAX_HEARTS:
		var heart := Sprite3D.new()
		heart.name = "Heart%d" % (i + 1)
		heart.texture = HEART_EMPTY
		heart.pixel_size = 0.0034
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		heart.no_depth_test = true
		heart.render_priority = 10
		heart.position = Vector3(0, 0, 0)
		_hearts.add_child(heart)


func _refresh_hearts() -> void:
	if _hearts == null or data == null:
		return
	var full := Friendship.get_hearts(data.id)
	_hearts.position.y = _name_label.position.y + 0.2
	for i in _hearts.get_child_count():
		var heart := _hearts.get_child(i) as Sprite3D
		heart.texture = HEART_FULL if i < full else HEART_EMPTY
		# Billboarded sprites are laid out along the camera's right by offsetting in
		# screen space.
		heart.offset = Vector2((i - (Friendship.MAX_HEARTS - 1) * 0.5) * 70.0, 0)


## Filled hearts shown above the villager (for tests).
func get_shown_hearts() -> int:
	var count := 0
	for heart in _hearts.get_children():
		if (heart as Sprite3D).texture == HEART_FULL:
			count += 1
	return count


func are_hearts_visible() -> bool:
	return _hearts != null and _hearts.visible


# ---------------------------------------------------------------- helpers

func _style_labels() -> void:
	var body := FontVariation.new()
	body.base_font = load("res://assets/ui/fonts/Nunito.ttf")
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 750}
	var heading := FontVariation.new()
	heading.base_font = load("res://assets/ui/fonts/Fredoka.ttf")
	heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_bubble.font = body
	_name_label.font = heading
	_bubble.modulate = UIPalette.CREAM
	_bubble.outline_modulate = UIPalette.WOOD_DARK
	_name_label.modulate = UIPalette.HONEY
	_name_label.outline_modulate = UIPalette.WOOD_DARK


func _ground(x: float, z: float) -> float:
	var shape := IslandShape.shared()
	var h := shape.get_height(x, z)
	# Over the creek (crossing the bridge): stand on the bridge deck, not the creek bed.
	if shape.is_in_creek(Vector2(x, z), IslandShape.CREEK_BANK) and is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, h + 6.0, z), Vector3(x, h - 0.5, z), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			h = maxf(h, (hit.position as Vector3).y)
	return h


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _yaw_to(point: Vector3) -> float:
	var d := _flat(point) - _flat(global_position)
	return atan2(d.x, d.y) if d.length_squared() > 0.0001 else rotation.y
