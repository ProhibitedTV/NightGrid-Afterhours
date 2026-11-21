extends SceneTree
## Headless UI/input contract test. Verifies action registration, menu state,
## controller-safe action context, settings and focusable shop actions.
func _initialize() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void: _fail("Timed out before completing menu checks"))
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
	if menu.get("_first_focus") != (menu.call("get_buttons") as Dictionary)["cancel"]:
		_fail("Destructive new-world confirmation must default to Keep Current Session")
		return
	menu.call("_choice", "cancel_new")
	if str(menu.get("screen")) != "title":
		_fail("Cancel did not return to original title screen")
		return
	menu.call("open_settings")
	if str(menu.get("screen")) != "settings":
		_fail("Graphics/audio/accessibility settings missing")
		return
	var scroll := menu.find_child("MenuScroll", true, false) as ScrollContainer
	if scroll == null or not scroll.follow_focus:
		_fail("Long settings must scroll with controller focus")
		return
	var values := menu.find_child("Value_master_volume", true, false) as Label
	if values == null or not values.text.ends_with("%"):
		_fail("Audio setting has no readable numerical percentage")
		return
	var focus: Array = menu.get("_focus_order")
	if focus.size() < 15 or focus[0].focus_neighbor_bottom.is_empty():
		_fail("Settings do not expose explicit vertical controller order")
		return
	menu.call("update_setting", "ssr_enabled", false)
	menu.call("update_setting", "glow_enabled", false)
	menu.call("update_setting", "ao_enabled", false)
	menu.call("update_setting", "fog_enabled", false)
	menu.call("update_setting", "mouse_sensitivity", 0.0060)
	menu.call("update_setting", "stick_sensitivity", 3.4)
	menu.call("update_setting", "show_fps", true)
	if world.get("world_environment").environment.ssr_enabled or world.get("world_environment").environment.glow_enabled:
		_fail("Performance controls did not update the actual render environment")
		return
	if world.get("world_environment").environment.ssao_enabled or world.get("world_environment").environment.fog_enabled:
		_fail("Contact shadow and distance haze toggles did not update the renderer")
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
	var route_map: Dictionary = world.call("get_map_state")
	if (route_map.get("bus_stops", []) as Array).size() != 16 or (route_map.get("rail_stations", []) as Array).size() != 5:
		_fail("Full city map omitted the existing bus stops and M-Line stations")
		return
	if str(menu.get("screen")) != "map" or menu.find_child("WorldMapView", true, false) == null:
		_fail("The full-city map is missing or inaccessible from pause")
		return
	print("MENU_GAMEPAD_SMOKE: opening atlas")
	var atlas := menu.find_child("WorldMapView", true, false) as Control
	var old_mission: Vector3 = world.get("mission_position")
	if not bool(atlas.get("interactive")) or atlas.focus_mode != Control.FOCUS_ALL:
		_fail("City atlas must be keyboard/controller interactive")
		return
	# Real controller movement and A press, routed to the atlas GUI.
	atlas.set("cursor", Vector2.ZERO)
	print("MENU_GAMEPAD_SMOKE: testing D-pad")
	var right := InputEventJoypadButton.new()
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	atlas.call("_gui_input", right)
	if atlas.get("cursor") != Vector2(8, 0):
		_fail("D-pad did not move the real atlas targeting cursor")
		return
	print("MENU_GAMEPAD_SMOKE: testing placement")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	atlas.call("_gui_input", accept)
	var selected: Dictionary = world.call("get_map_state")
	if not bool(selected["waypoint_active"]) or selected["waypoint"] != Vector2(8, 0):
		_fail("A did not set a real world-space map destination")
		return
	var first_route: Dictionary = selected["street_route"]
	if first_route.is_empty() or (first_route["points"] as Array).is_empty():
		_fail("The live atlas must receive actual road centreline points")
		return
	var old_pos := player.global_position
	player.global_position = Vector3(-116, old_pos.y, 0)
	var moved: Dictionary = world.call("get_map_state")
	var moved_route: Dictionary = moved["street_route"]
	if moved_route["entry"] != Vector2(-116, 0) or not is_equal_approx(float(moved_route["road_m"]), 124.0):
		_fail("Live route did not recalculate after player movement")
		return
	var route_again: Dictionary = world.call("get_map_state")
	if route_again["street_route"] != moved_route:
		_fail("Stationary player should receive the same navigation route")
		return
	player.global_position = old_pos
	if world.get("mission_position") != old_mission:
		_fail("Personal waypoint must never change courier objective")
		return
	print("MENU_GAMEPAD_SMOKE: testing save")
	var save: Dictionary = world.call("_capture_snapshot")
	if save["navigation_waypoint"] != [8.0, 0.0]:
		_fail("Waypoint not present in backward-compatible save payload")
		return
	var nav = load("res://scripts/navigation_waypoint.gd")
	if nav.decode(save["navigation_waypoint"]) != Vector2(8, 0) or nav.decode([999, 0]) != null or nav.decode(["8", 0]) != null or nav.decode([]) != null:
		_fail("Waypoint save decoder accepts malformed/old/outside coordinates")
		return
	if nav.bearing(Vector2.ZERO, Vector2(0, -20)) != "N" or nav.bearing(Vector2.ZERO, Vector2(20, 0)) != "E":
		_fail("World X/Z navigation bearings are reversed")
		return
	print("MENU_GAMEPAD_SMOKE: testing snap")
	var venues_node := world.get_node("SocialVenues")
	var cafe: Vector3 = venues_node.call("venue_position", "lantern_cup")
	var snapped: Vector2 = world.call("set_navigation_waypoint", Vector2(cafe.x + 2, cafe.z))
	if not snapped.is_equal_approx(Vector2(cafe.x, cafe.z)) or not str(world.call("navigation_text")).contains("LANTERN CUP"):
		_fail("Named destination did not snap to canonical café interaction point")
		return
	print("MENU_GAMEPAD_SMOKE: testing HUD")
	world.call("_update_hud")
	if not (world.get("hud_navigation") as Label).visible or not (world.get("hud_navigation") as Label).text.contains("m by street"):
		_fail("Active waypoint did not appear in the live HUD")
		return
	var cancel_pin := InputEventJoypadButton.new()
	cancel_pin.button_index = JOY_BUTTON_X
	cancel_pin.pressed = true
	atlas.call("_gui_input", cancel_pin)
	if bool((world.call("get_map_state") as Dictionary)["waypoint_active"]):
		_fail("X did not clear the waypoint")
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
	world.call("_update_hud")
	var status := world.get_node_or_null("HUD/PlayerStatus")
	var objective: Label = world.get("hud_objective")
	var prompt: Label = world.get("hud_prompt")
	var health_bar: ProgressBar = world.get("hud_health")
	if status == null or objective == null or prompt == null or health_bar == null:
		_fail("Status, objective, context help and health meter must be independently readable")
		return
	if not objective.text.contains("PACKAGE") or not prompt.text.contains("M Map") or not is_equal_approx(health_bar.value, float(world.get("health"))):
		_fail("New HUD did not reflect actual mission, input mode and player health")
		return
	world.set("gamepad_active", true)
	world.call("_update_hud")
	if not prompt.text.contains("View Map") or prompt.text.contains("M Map"):
		_fail("Gamepad HUD retained stale keyboard instructions")
		return
	world.set("gamepad_active", false)
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
