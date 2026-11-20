extends SceneTree
## Headless UI/input contract test. Verifies action registration, menu state,
## controller-safe action context, settings and focusable shop actions.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("MENU_GAMEPAD_SMOKE: " + message)
	paused = false
	quit(1)

func _has_pad_button(action: String, index: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == index:
			return true
	return false

func _has_pad_axis(action: String, index: JoyAxis, value: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == index and is_equal_approx(event.axis_value, value):
			return true
	return false

func _verify() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Cannot load game scene")
		return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var menu := world.get_node_or_null("GameMenus")
	var player: CharacterBody3D = world.get("player")
	if menu == null or player == null:
		_fail("Menu and player must be created with the game world")
		return
	var input_spec = load("res://scripts/game_input.gd")
	for action in input_spec.ACTIONS:
		if not InputMap.has_action(action):
			_fail("Missing shared action: " + action)
			return
	for required in [
		["move_forward", JOY_BUTTON_INVALID],
		["interact", JOY_BUTTON_X],
		["car_toggle", JOY_BUTTON_Y],
		["interior_toggle", JOY_BUTTON_LEFT_SHOULDER],
		["transit_toggle", JOY_BUTTON_RIGHT_SHOULDER],
		["jump", JOY_BUTTON_A],
		["service_one", JOY_BUTTON_A],
		["service_two", JOY_BUTTON_X],
		["game_back", JOY_BUTTON_B],
		["map_open", JOY_BUTTON_BACK],
		["game_pause", JOY_BUTTON_START]
	]:
		if required[1] != JOY_BUTTON_INVALID and not _has_pad_button(str(required[0]), required[1]):
			_fail("Missing expected gamepad action " + str(required[0]))
			return
	if not _has_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0):
		_fail("Movement must use the left stick")
		return
	if not _has_pad_axis("look_right", JOY_AXIS_RIGHT_X, 1.0):
		_fail("Camera look must use the right stick")
		return
	if not _has_pad_axis("drive_accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0):
		_fail("Vehicle acceleration must use RT")
		return
	if not _has_pad_axis("drive_reverse", JOY_AXIS_TRIGGER_LEFT, 1.0):
		_fail("Vehicle reverse must use LT")
		return
	Input.action_press("move_forward", 1.0)
	var walk: Vector2 = input_spec.walk_vector()
	Input.action_release("move_forward")
	if walk.y > -0.95:
		_fail("Shared input axes do not translate to actual walking motion")
		return
	player.set("input_blocked", true)
	Input.action_press("move_forward", 1.0)
	player.call("_physics_process", 0.05)
	Input.action_release("move_forward")
	if player.velocity.length() > 0.01:
		_fail("Player continues moving while reading a business dialogue")
		return
	player.set("input_blocked", false)
	var saved_settings: Dictionary = menu.call("get_settings")
	menu.call("set_has_save", false)
	menu.call("open_title")
	if not paused or not menu.call("is_open") or str(menu.get("screen")) != "title":
		_fail("Title screen must pause the world and remain interactive")
		return
	if not (menu.call("get_buttons") as Dictionary).has("continue"):
		_fail("Continue/Start/New World navigation missing from title")
		return
	if not (menu.call("get_buttons") as Dictionary)["continue"].disabled:
		_fail("Continue should be unavailable when no save slot exists")
		return
	menu.call("_choice", "new")
	if str(menu.get("screen")) != "confirm_new":
		_fail("New World must be a confirmed destructive transition")
		return
	menu.call("_choice", "cancel_new")
	if str(menu.get("screen")) != "title":
		_fail("Cancel did not return to original title screen")
		return
	menu.call("open_settings")
	if str(menu.get("screen")) != "settings":
		_fail("Graphics/audio/accessibility settings missing")
		return
	menu.call("update_setting", "ssr_enabled", false)
	menu.call("update_setting", "glow_enabled", false)
	menu.call("update_setting", "mouse_sensitivity", 0.0060)
	menu.call("update_setting", "stick_sensitivity", 3.4)
	menu.call("update_setting", "show_fps", true)
	if world.get("world_environment").environment.ssr_enabled or world.get("world_environment").environment.glow_enabled:
		_fail("Performance controls did not update the actual render environment")
		return
	if not bool(world.get("performance_overlay")) or absf(float(world.get("stick_sensitivity")) - 3.4) > 0.05:
		_fail("Gameplay did not receive changed accessibility settings")
		return
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK or not is_equal_approx(float(config.get_value("player", "mouse_sensitivity", 0.0)), 0.0060):
		_fail("Mouse/controller settings were not saved persistently")
		return
	for key in saved_settings:
		menu.call("update_setting", key, saved_settings[key])
	menu.call("open_controls")
	if str(menu.get("screen")) != "controls" or (menu.call("get_buttons") as Dictionary).is_empty():
		_fail("Discoverable keyboard/controller controls menu missing")
		return
	menu.call("_choice", "back")
	if str(menu.get("screen")) != "title":
		_fail("Back navigation is not consistent")
		return
	menu.call("open_pause")
	var journal_context: Dictionary = world.call("_journal_context")
	if journal_context.get("district", "") == "" or not journal_context.has("seed"):
		_fail("Objective journal lacks grounded district and saved world seed")
		return
	menu.call("_choice", "map")
	if str(menu.get("screen")) != "map" or menu.find_child("WorldMapView", true, false) == null:
		_fail("The full-city map is missing or inaccessible from pause")
		return
	menu.call("_choice", "back")
	if str(menu.get("screen")) != "pause":
		_fail("Map Back navigation did not return to pause")
		return
	menu.call("_choice", "journal")
	if str(menu.get("screen")) != "journal" or not (menu.get("_journal_data") as Dictionary).has("main_objective"):
		_fail("Live journal did not present player objective and inventory")
		return
	menu.call("_choice", "back")
	if str(menu.get("screen")) != "pause":
		_fail("Journal Back did not return to pause")
		return
	var resume: Button = (menu.call("get_buttons") as Dictionary)["resume"]
	if not resume.focus_mode == Control.FOCUS_ALL:
		_fail("Pause buttons must support standard controller focus navigation")
		return
	resume.pressed.emit()
	if paused or menu.call("is_open"):
		_fail("Resume button did not restore live player controls")
		return
	var b_event := InputEventJoypadButton.new()
	b_event.pressed = true
	b_event.button_index = JOY_BUTTON_B
	# Back must NOT pause while driving: B is the car's handbrake.
	var parked: Array = world.get("cars")
	world.set("current_car", parked[0])
	world.call("_unhandled_input", b_event)
	if paused or menu.call("is_open"):
		_fail("Gamepad B incorrectly opens pause instead of braking")
		return
	world.set("current_car", null)
	# Menu interaction should enable cursor, stop movement, and have three
	# focusable buttons suitable for both controller and mouse.
	var venues := world.get_node_or_null("SocialVenues")
	player.global_position = venues.call("venue_position", "moon_noodles")
	world.call("_toggle_venue")
	var panel: PanelContainer = world.get("venue_panel")
	if not panel.visible or not bool(player.get("input_blocked")):
		_fail("Business UI did not show or block gameplay movement")
		return
	for field in ["venue_service_button", "venue_job_button", "venue_close_button"]:
		var button: Button = world.get(field)
		if button == null or button.focus_mode != Control.FOCUS_ALL:
			_fail("Mouse/controller dialogue button missing: " + field)
			return
	world.call("_unhandled_input", b_event)
	if panel.visible or bool(player.get("input_blocked")):
		_fail("B back did not close the dialogue and release controls")
		return
	var start := InputEventJoypadButton.new()
	start.pressed = true
	start.button_index = JOY_BUTTON_START
	world.call("_unhandled_input", start)
	if not paused or str(menu.get("screen")) != "pause":
		_fail("Start did not open controller pause menu")
		return
	menu.call("hide_for_game")
	if paused or menu.call("is_open"):
		_fail("Game cannot resume from controller pause")
		return
	print("MENU_GAMEPAD_SMOKE PASS: action_count=", input_spec.ACTIONS.size(),
		" / settings saved / pause & focus / controller context / title confirmation")
	quit(0)
