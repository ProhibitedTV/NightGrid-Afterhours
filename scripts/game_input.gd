extends RefCounted
## Installs one shared action map for keyboard and standard Xbox/XInput-style
## gamepads. The rest of gameplay never reads hard-coded hardware input.
const ACTIONS = [
	"move_left", "move_right", "move_forward", "move_backward",
	"look_left", "look_right", "look_up", "look_down",
	"sprint", "jump", "drive_accelerate", "drive_reverse", "drive_brake",
	"interact", "car_toggle", "transit_toggle", "interior_toggle",
	"use_supply", "service_one", "service_two",
	"game_pause", "game_back", "game_save", "game_load", "game_new",
	"advance_clock", "pause_clock", "toggle_fps", "toggle_ssr"
]

static func install() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.18)
		else:
			InputMap.action_erase_events(action)
			InputMap.action_set_deadzone(action, 0.18)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_W)
	_key("move_backward", KEY_S)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_key("sprint", KEY_SHIFT)
	_button("sprint", JOY_BUTTON_LEFT_STICK)
	_key("jump", KEY_SPACE)
	_button("jump", JOY_BUTTON_A)
	_key("drive_accelerate", KEY_W)
	_axis("drive_accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key("drive_reverse", KEY_S)
	_axis("drive_reverse", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key("drive_brake", KEY_SPACE)
	_button("drive_brake", JOY_BUTTON_B)
	_key("interact", KEY_G)
	_button("interact", JOY_BUTTON_X)
	_key("car_toggle", KEY_E)
	_button("car_toggle", JOY_BUTTON_Y)
	_key("transit_toggle", KEY_F)
	_button("transit_toggle", JOY_BUTTON_RIGHT_SHOULDER)
	_key("interior_toggle", KEY_H)
	_button("interior_toggle", JOY_BUTTON_LEFT_SHOULDER)
	_key("use_supply", KEY_R)
	_button("use_supply", JOY_BUTTON_DPAD_DOWN)
	_key("service_one", KEY_1)
	_button("service_one", JOY_BUTTON_A)
	_key("service_two", KEY_2)
	_button("service_two", JOY_BUTTON_X)
	_key("game_pause", KEY_ESCAPE)
	_button("game_pause", JOY_BUTTON_START)
	_button("game_back", JOY_BUTTON_B)
	_key("game_save", KEY_F5)
	_key("game_new", KEY_F6)
	_key("game_load", KEY_F9)
	_key("advance_clock", KEY_T)
	_key("pause_clock", KEY_Y)
	_key("toggle_fps", KEY_F3)
	_key("toggle_ssr", KEY_F4)
	# Explicit UI navigation on typical controllers; native focusable buttons,
	# sliders and checkboxes then support the same D-pad and accept controls.
	_ensure_ui_key("ui_accept", KEY_ENTER)
	_ensure_ui_button("ui_accept", JOY_BUTTON_A)
	_ensure_ui_button("ui_cancel", JOY_BUTTON_B)
	_ensure_ui_button("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_ui_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_ui_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_ui_button("ui_right", JOY_BUTTON_DPAD_RIGHT)

static func walk_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

static func look_vector() -> Vector2:
	return Input.get_vector("look_left", "look_right", "look_up", "look_down")

static func is_gamepad_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return true
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.32
	return false

static func _key(action: String, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)

static func _button(action: String, index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	InputMap.action_add_event(action, event)

static func _axis(action: String, index: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = direction
	InputMap.action_add_event(action, event)

static func _ensure_ui_key(action: String, code: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = code
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == code:
			return
	InputMap.action_add_event(action, event)

static func _ensure_ui_button(action: String, index: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = index
	InputMap.action_add_event(action, event)
