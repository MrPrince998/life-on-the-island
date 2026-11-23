extends SceneTree
## Dev tool: (re)writes the project's input actions into project.godot.
## Run: Godot --headless --path . --script res://tools/setup_input_map.gd

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.device = -1
	return e

func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e

func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.device = -1
	e.axis_value = value
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.device = -1
	return e

func _bind(action: String, events: Array, deadzone: float = 0.2) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": deadzone, "events": events})

func _init() -> void:
	_bind("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("jump", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)], 0.5)
	_bind("sprint", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_STICK), _joy_button(JOY_BUTTON_B)], 0.5)
	_bind("interact", [_key(KEY_E), _joy_button(JOY_BUTTON_X)], 0.5)
	_bind("toggle_mouse", [_key(KEY_ESCAPE)], 0.5)
	# The controls list now lives in Settings, so the old F1/H help toggle is gone.
	ProjectSettings.set_setting("input/toggle_help", null)
	_bind("look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)], 0.15)
	_bind("look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)], 0.15)
	_bind("look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)], 0.15)
	_bind("look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)], 0.15)
	_bind("use_tool", [_mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)], 0.5)
	_bind("cancel_tool", [_mouse(MOUSE_BUTTON_RIGHT), _joy_button(JOY_BUTTON_LEFT_SHOULDER)], 0.5)
	_bind("toggle_rod", [_key(KEY_R), _joy_button(JOY_BUTTON_Y)], 0.5)
	_bind("toggle_bag", [_key(KEY_TAB), _key(KEY_I), _joy_button(JOY_BUTTON_START)], 0.5)
	_bind("cycle_seed", [_key(KEY_Q), _joy_button(JOY_BUTTON_DPAD_RIGHT)], 0.5)
	_bind("give_gift", [_key(KEY_G), _joy_button(JOY_BUTTON_BACK)], 0.5)
	_bind("toggle_ukulele", [_key(KEY_U), _joy_button(JOY_BUTTON_DPAD_LEFT)], 0.5)
	_bind("toggle_journal", [_key(KEY_J), _joy_button(JOY_BUTTON_DPAD_UP)], 0.5)
	var number_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	var keypad_keys := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8]
	for n in 8:
		_bind("uke_note_%d" % (n + 1), [_key(number_keys[n]), _key(keypad_keys[n])], 0.5)
	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit(0 if err == OK else 1)
