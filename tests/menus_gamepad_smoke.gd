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
	if not (menu.call("get_buttons") as Dictionary).has("inventory"):
		_fail("Journal must link to dedicated player inventory")
		return
	var previous_items: Dictionary = world.get("consumable_inventory").duplicate()
	world.set("consumable_inventory", {"water": 2, "protein": 1})
	menu.call("_choice", "inventory")
	var player_data: Dictionary = menu.get("_journal_data")
	var inventory_buttons: Dictionary = menu.call("get_buttons")
	if not paused or str(menu.get("screen")) != "inventory" or player_data.get("consumables") != {"water": 2, "protein": 1} or not is_equal_approx(float(player_data["stamina"]), float(player.get("stamina"))):
		_fail("Player inventory must read actual carried items and stamina")
		return
	var inventory_content := menu.find_child("MenuContent", true, false)
	if inventory_content.find_children("*", "TextureRect", true, false).size() != 2 or inventory_content.find_children("*", "ProgressBar", true, false).size() != 2:
		_fail("Player inventory must show owned item icons and independent vitals")
		return
	if not inventory_buttons.has("save_waypoint") or not inventory_buttons.has("journal") or inventory_buttons["journal"].focus_mode != Control.FOCUS_ALL:
		_fail("Inventory navigation and property actions must support controller")
		return
	menu.call("_choice", "journal")
	if str(menu.get("screen")) != "journal" or not (menu.call("get_buttons") as Dictionary).has("restart_courier"):
		_fail("Returning to journal must retain mission actions")
		return
	if world.get("consumable_inventory") != {"water": 2, "protein": 1}:
		_fail("Inventory browsing must not consume or change items")
		return
	world.set("consumable_inventory", previous_items)
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
	menu.call("update_setting", "show_control_hints", true)
	menu.call("update_setting", "show_hud_inventory", true)
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
	menu.call("update_setting", "show_control_hints", false)
	menu.call("update_setting", "show_hud_inventory", false)
	world.call("_update_hud")
	var vitals: Label = world.get("hud_label")
	if prompt.text.contains("M Map") or vitals.text.contains("snacks") or not objective.visible or not health_bar.visible:
		_fail("Reduced HUD must keep objectives and vitals without generic reminders or inventory clutter")
		return
	var reduced_settings := ConfigFile.new()
	if reduced_settings.load("user://settings.cfg") != OK or bool(reduced_settings.get_value("player", "show_control_hints", true)) or bool(reduced_settings.get_value("player", "show_hud_inventory", true)):
		_fail("Reduced HUD preferences must persist")
		return
	var b_event := InputEventJoypadButton.new()
	b_event.pressed = true
	b_event.button_index = JOY_BUTTON_B
	# Back must NOT pause while driving: B is the car's handbrake.
	var parked: Array = world.get("cars")
	var old_position: Vector3 = player.global_position
	player.global_position = parked[0].global_position + Vector3(2.0,0.0,0.0)
	world.call("_update_hud")
	if not prompt.text.contains("E Enter vehicle"):
		_fail("Reduced HUD hid a reachable vehicle action")
		return
	player.global_position = old_position
	world.set("current_car", parked[0])
	world.call("_update_hud")
	var drive_card: PanelContainer = world.get("hud_drive_card")
	var speed_label: Label = world.get("hud_drive_speed")
	if not drive_card.visible or not speed_label.text.ends_with("km/h") or not prompt.text.contains("E Exit vehicle") or (world.get("_weapon_card") as Control).visible:
		_fail("Driving HUD must show measured speed and exit action in the exclusive lower-right slot")
		return
	world.call("_unhandled_input", b_event)
	if paused or menu.call("is_open"):
		_fail("Gamepad B incorrectly opens pause instead of braking")
		return
	world.set("current_car", null)
	world.call("_update_hud")
	if drive_card.visible:
		_fail("Driving HUD remains visible on foot")
		return
	menu.call("update_setting", "show_control_hints", saved_settings["show_control_hints"])
	menu.call("update_setting", "show_hud_inventory", saved_settings["show_hud_inventory"])
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
	# The fresh opening contact is discoverable without knowing the city.
	menu.call("open_pause")
	menu.call("open_journal", world.call("_journal_context"))
	var contact: Button = menu.call("get_buttons").get("story_waypoint")
	if contact == null or contact.disabled or contact.focus_mode != Control.FOCUS_ALL:
		_fail("Opening contact waypoint is unavailable to controller")
		return
	menu.call("_choice","story_waypoint")
	if not str(world.call("navigation_text")).contains("LANTERN CUP"):
		_fail("Contact waypoint does not resolve to Mara’s real entrance")
		return
	menu.call("hide_for_game")
	# Exercise the actual world courier adapter and journal action.
	var director = world.get("courier_mission")
	var initial_cash: int = world.get("cash")
	var initial_runs: int = world.get("deliveries")
	player.global_position = director.target()
	world.call("_advance_mission")
	if not bool(world.get("carrying")):
		_fail("Real world pickup did not advance mission director")
		return
	var mid_route: Dictionary = world.call("_capture_snapshot")
	var dropoff: Vector3 = director.target()
	menu.call("open_pause")
	menu.call("open_journal", world.call("_journal_context"))
	var restart_button: Button = menu.call("get_buttons").get("restart_courier")
	if restart_button == null or restart_button.disabled:
		_fail("Journal did not expose controller-focusable restart")
		return
	menu.call("_choice", "restart_courier")
	if bool(world.get("carrying")) or int(world.get("cash")) != initial_cash or int(world.get("deliveries")) != initial_runs:
		_fail("Restart mutated wallet or run count")
		return
	world.call("_apply_snapshot", mid_route)
	if not bool(world.get("carrying")) or director.target() != dropoff:
		_fail("Mid-mission world restore did not restore objective")
		return
	player.global_position = dropoff
	world.call("_advance_mission")
	world.call("_advance_mission")
	if int(world.get("deliveries")) != initial_runs + 1 or int(world.get("cash")) != initial_cash + 250 + 50 * mini(initial_runs,8):
		_fail("Real mission reward was not paid exactly once")
		return
	var conditioned: Dictionary = world.call("_capture_snapshot")
	conditioned["deliveries"] = 10
	conditioned["carrying"] = false
	world.call("_apply_snapshot",conditioned)
	player.call("restore_stamina",100.0)
	player.call("tick_stamina",1.0,true,true,false)
	if not is_equal_approx(float(player.get("stamina")),88.1) or not str(world.call("_journal_context")["conditioning"]).contains("MAX RANK"):
		_fail("Restored courier milestones must apply real bounded sprint benefit and journal state")
		return
	menu.call("open_opening")
	var before_severance: int = world.get("cash")
	if not menu.call("is_open") or not (menu.call("get_buttons") as Dictionary).has("opening_inspect"):
		_fail("Opening ticket must be controller accessible")
		return
	menu.call("_choice","opening_accept")
	if not menu.call("is_open") or world.get("cash")!=before_severance:
		_fail("Cannot skip corporate investigation and collect severance early")
		return
	menu.call("_choice","opening_inspect")
	menu.call("_choice","opening_brief")
	menu.call("_choice","opening_phone")
	menu.call("_choice","opening_hangup")
	var opening = preload("res://scripts/opening_story.gd")
	if not opening.CALL_MANDARIN.contains("解放军") or not opening.CALL_SUBTITLES.contains("People's Liberation Army"):
		_fail("Mandarin phone call and English subtitles must identify the fictional military contact")
		return
	if not (menu.call("get_buttons") as Dictionary).has("opening_security") or not (menu.call("get_buttons") as Dictionary).has("opening_legal"):
		_fail("Executive confrontation must present both report choices")
		return
	menu.call("_choice","opening_legal")
	if menu.get("_opening_report")!="opening_legal" or not (menu.call("get_buttons") as Dictionary).has("opening_read_notice"):
		_fail("Legal escalation has its own response")
		return
	world.call("_start_opening_office")
	var office: Node3D = world.get("_opening_office")
	if not is_instance_valid(office) or office.find_children("*","CollisionShape3D",true,false).size()<10:
		_fail("Physical office must have real enclosed collision geometry")
		return
	var opening_visual: Node3D=player.get("visual")
	var opening_rig: Skeleton3D=opening_visual.get("skeleton")
	var opening_source=preload("res://scripts/opening_story.gd")
	if opening_source.ROLE!="Corporate IP Security Analyst" or not opening_source.AUDIT.contains("not proof of an affair"):
		_fail("Insider case must be based on unauthorized access, with the affair implied")
		return
	var suit_available := ResourceLoader.exists(opening_visual.call("corporate_model_path"),"PackedScene")
	if suit_available and not opening_visual.get("corporate_attire"):
		_fail("Generated formalwear must equip on the existing player rig")
		return
	if OS.get_environment("NIGHTGRID_REQUIRE_CORPORATE_SUIT")=="1" and not suit_available:
		_fail("Suit asset workflow must provide a real imported skinned suit")
		return
	var finish: Node3D = office.get_node_or_null("ArchitecturalFinish")
	if not is_instance_valid(finish) or finish.is_processing():
		_fail("Office finish must be a static authored environment")
		return
	var stone:=office.get_node("Floor") as MeshInstance3D
	var stone_mat:=stone.material_override as StandardMaterial3D
	if stone_mat.albedo_texture==null or not stone_mat.normal_enabled or stone_mat.normal_texture==null or not stone_mat.uv1_triplanar:
		_fail("Ground floor must retain mapped stone finish at world scale")
		return
	var downlights:=0
	var shadows:=0
	for child in office.get_children():
		if child is SpotLight3D:
			downlights+=1
			if child.shadow_enabled:
				shadows+=1
	if downlights!=8 or shadows!=4:
		_fail("Office light pools must preserve the bounded eight-fixture/four-shadow budget")
		return
	var detail_stats: Dictionary = finish.call("get_detail_stats")
	if int(detail_stats["parts"]) < 500 or int(detail_stats["batches"]) > 75:
		_fail("Office detail must use bounded static material batches")
		return
	for batch in finish.get_children():
		if not batch is MultiMeshInstance3D or batch.multimesh.instance_count <= 0:
			_fail("Office finish requires populated shared geometry")
			return
		if batch.name=="AuthoredTaskChairs":
			if batch.multimesh.mesh.get_surface_count()!=4 or batch.multimesh.instance_count!=3 or batch.material_override!=null:
				_fail("Ground floor must use the original multi-material chair mesh")
				return
			for surface in range(batch.multimesh.mesh.get_surface_count()):
				if batch.multimesh.mesh.surface_get_material(surface)==null:
					_fail("Chair mesh requires imported PBR materials")
					return
		elif batch.material_override==null:
			_fail("Primitive finish batch needs its shared material")
			return
	if finish.get_node_or_null("AuthoredTaskChairs")==null:
		_fail("Missing authored task chairs")
		return
	for id in ["WorkstationCollision","ExecutiveDeskCollision","HRDeskCollision","ReceptionDeskCollision","BreakroomTableCollision"]:
		if not is_instance_valid(office.get_node_or_null(id)):
			_fail("Furniture art replacement must preserve physical occupancy: "+id)
			return
	var propaganda: Node3D=office.get_node_or_null("CorporatePropaganda")
	if not is_instance_valid(propaganda) or propaganda.get_child_count()!=16:
		_fail("Sixteen physical corporate propaganda boards must be present")
		return
	for id in ["OfficeAttendance","Calibration","AIPledge","PTOFreeze","Meetings","SpeakUp","Equity","Water","Recruiting","LobbySurveillance"]:
		if not is_instance_valid(propaganda.get_node_or_null(id+"/Headline")):
			_fail("Missing environmental workplace satire: "+id)
			return
	for id in ["RecognitionAward","DeskTimeTracker","ExecutiveCoffeeMachine","CartonPriceCard"]:
		if not is_instance_valid(office.get_node_or_null(id)):
			_fail("Missing physical workplace storytelling prop: "+id)
			return
	for board in propaganda.get_children():
		var logo:=board.get_node_or_null("BrandLockup") as MeshInstance3D
		if logo==null or logo.material_override.albedo_texture==null:
			_fail("Every physical poster uses the shared original Synaxis logo texture")
			return
	if not is_instance_valid(office.get_node_or_null("TowerBrandFront")) or not is_instance_valid(office.get_node_or_null("EntranceBrand")):
		_fail("Permanent corporate facade uses the original brand")
		return
	if not str(propaganda.get_node("QuarterlyRecord/Headline").text).contains("$14.8 BILLION") or not str(propaganda.get_node("HealthRenewal/Headline").text).contains("24%") or not str(propaganda.get_node("HealthRenewal/FinePrint").text).contains("$231"):
		_fail("Profit celebration and increased health premium must be actual in-world text")
		return
	var arrival_script=preload("res://scripts/synaxis_arrival.gd")
	var shots: Array=arrival_script.SHOTS
	for i in range(shots.size()):
		var shot: Dictionary=shots[i]
		if float(shot["duration"])<=0.0 or (i>0 and shot["from"]!=shots[i-1]["to"]):
			_fail("Arrival camera cuts must not teleport the player")
			return
		var shot_start: Vector3=shot["from"]
		var shot_end: Vector3=shot["to"]
		# Sample each route leg against the executive partition expanded by capsule clearance.
		for step in range(21):
			var route_sample := shot_start.lerp(shot_end,float(step)/20.0)
			if absf(route_sample.x)<.45 and route_sample.z>arrival_script.PARTITION_NEAR_Z-.36 and route_sample.z<arrival_script.PARTITION_FAR_Z+.36:
				_fail("Arrival must turn around the partition rather than walk through it")
				return
	var partition: MeshInstance3D=office.get_node("ExecutivePartition")
	var partition_mesh: BoxMesh=partition.mesh
	if not is_equal_approx(partition.position.z-partition_mesh.size.z*.5,arrival_script.PARTITION_NEAR_Z) or shots[-1]["to"]!=preload("res://scripts/synaxis_office.gd").CUBICLE_POINT:
		_fail("Arrival route must match the actual partition and playable cubicle")
		return
	var montage=arrival_script.new()
	if not montage.advance(4.8) or not bool(montage.sample()["gate_open"]) or montage.advance(30.0) or not montage.sample().is_empty():
		_fail("Arrival timeline opens the gate during crossing and terminates on a large frame delta")
		return
	if not office.call("arrival_active") or not player.get("input_blocked"):
		_fail("New game begins with a controlled arrival cinematic")
		return
	world.call("_opening_interact") # skip uses the same completion path
	if office.call("arrival_active") or player.get("input_blocked") or int(office.call("objective_stage",0))!=-2:
		_fail("Skipping arrival restores player movement at the cubicle")
		return
	var bounds=preload("res://scripts/synaxis_office.gd")
	for level in [-1,0,1,2,3,4,13]:
		var height:float=level*3.65+1.15
		if not bounds.within_chapter_bounds(Vector3(0,height,5),level,true,false):
			_fail("Valid lift landing rejected by chapter bounds")
			return
		for invalid in [Vector3(80,height,0),Vector3(0,height,-30),Vector3(0,height,40),Vector3(0,height-5,5),Vector3(0,height+5,5)]:
			if bounds.within_chapter_bounds(invalid,level,true,false):
				_fail("Chapter escaped active floor envelope: %s" % invalid)
				return
	if not bounds.within_chapter_bounds(Vector3(-9.14,1.15,5),0,true,false) or not bounds.within_chapter_bounds(Vector3(-6.55,1.15,18.55),0,true,false):
		_fail("Optional parking visit must remain available")
		return
	if bounds.within_chapter_bounds(Vector3(-6.55,1.15,18.55),0,false,false):
		_fail("Closed staff door must revoke parking access")
		return
	if bounds.within_chapter_bounds(Vector3(0,1.15,-12.32),0,true,false) or not bounds.within_chapter_bounds(Vector3(0,1.15,-12.32),0,false,true):
		_fail("Street exit is authorized only after final offboarding")
		return
	if not bounds.within_chapter_bounds(Vector3(10,13*3.65+1.15,-4),13,true,false) or bounds.within_chapter_bounds(Vector3(12,13*3.65+1.15,-4),13,true,false):
		_fail("Terrace must be accessible but bounded")
		return
	player.global_position=office.to_global(Vector3(-30,1.15,12))
	player.velocity=Vector3(4,0,3)
	world.call("_physics_process",0.016)
	if player.global_position.distance_to(office.to_global(bounds.CUBICLE_POINT))>.01 or player.velocity!=Vector3.ZERO or int(office.call("objective_stage",0))!=-2:
		_fail("Escaped player must recover without changing chapter progress")
		return
	player.global_position=office.to_global(Vector3(0,1.15,0))
	world.call("_opening_interact")
	if menu.call("is_open") or int(office.call("objective_stage",0))!=-2:
		_fail("Cannot interact with office workstation remotely")
		return
	var ground_chairs:=finish.get_node("AuthoredTaskChairs") as MultiMeshInstance3D
	for deck in office.get("_workfloors"):
		var chairs:=deck.get_node_or_null("AuthoredTaskChairs") as MultiMeshInstance3D
		if chairs==null or chairs.multimesh.mesh!=ground_chairs.multimesh.mesh or chairs.multimesh.instance_count<28 or chairs.visible:
			_fail("Upper-floor chair batches must share one imported mesh and stay hidden outside the occupied floor")
			return
	var office_decks: Array=office.call("workfloor_stats")
	var desk_total:=0
	if office_decks.size()!=4:
		_fail("Four real upper workplace floors exist")
		return
	for deck_stats in office_decks:
		desk_total+=int(deck_stats["desks"])
		if int(deck_stats["desks"])!=28 or int(deck_stats["chairs"])<28 or int(deck_stats["plants"])<5 or int(deck_stats["colliders"])<10 or int(deck_stats["batches"])>40:
			_fail("Every workfloor must be fully furnished, collision backed and batched")
			return
	if desk_total<100:
		_fail("HQ needs at least 100 dedicated workstations")
		return
	for level in [1,2,3,4,13]:
		var previous:int=office.get("_active_floor")
		player.global_position=office.to_global(Vector3(-.9,previous*3.65+1.15,5))
		world.call("_opening_interact")
		if not office.call("lift_active") or not player.get("input_blocked") or int(office.get("_active_floor"))!=previous:
			_fail("Lift closes before moving and locks input during travel")
			return
		world.call("_opening_interact")
		office.call("tick_lift",.20,player)
		if int(office.get("_active_floor"))!=previous:
			_fail("Lift cannot relocate before the doors close")
			return
		office.call("tick_lift",3.0,player)
		if office.call("lift_active") or player.get("input_blocked"):
			_fail("Lift opens and releases input at destination")
			return
		if int(office.get("_active_floor"))!=level or absf(office.to_local(player.global_position).y-(level*3.65+1.15))>.01:
			_fail("Lift travels to actual upper floor elevations")
			return
		if level<=4:
			var chair_batch:MultiMeshInstance3D=office.get("_workfloors")[level-1].get_node("AuthoredTaskChairs")
			if not chair_batch.visible:
				_fail("Occupied workfloor must display its chair batch")
				return
			var lift_arrival:Vector3=player.global_position
			var before_stage:int=menu.get("_opening_stage")
			player.global_position=office.to_global(Vector3(-6,level*3.65+1.15,-7.25))
			var interview:Dictionary=office.call("interview_at",player.global_position,-2)
			if interview.get("id","")!="worker_%d_0" % level or (interview["topics"] as Array).size()!=2:
				_fail("Each workfloor has a reachable named interview before the main errand")
				return
			var later:Dictionary=office.call("interview_at",player.global_position,2)
			if later["topics"][0]["reply"]==interview["topics"][0]["reply"]:
				_fail("Interview responses should change with story stage")
				return
			world.call("_opening_interact")
			if menu.get("screen")!="staff_interview" or not menu.call("get_buttons").has("interview_0"):
				_fail("Physical employee interaction opens topic choices")
				return
			menu.call("_choice","interview_0")
			if not menu.call("get_buttons").has("interview_back"):
				_fail("Employee reply and return option missing")
				return
			menu.call("_choice","interview_back")
			menu.call("_choice","interview_0")
			if (menu.get("_investigation_notes") as Dictionary).size()!=level:
				_fail("Repeated interviews must not duplicate private notes")
				return
			menu.call("_choice","notes_open")
			if menu.get("screen")!="investigation_notes" or not menu.call("get_buttons").has("notes_back"):
				_fail("Interview notes can be reviewed from the conversation")
				return
			menu.call("_choice","notes_back")
			if menu.get("screen")!="staff_interview":
				_fail("Notebook returns to the originating conversation")
				return
			menu.call("_choice","interview_leave")
			if menu.call("is_open") or int(menu.get("_opening_stage"))!=before_stage or int(office.call("objective_stage",0))!=-2:
				_fail("Optional interviews cannot advance the mission or strand gameplay")
				return
			player.global_position=lift_arrival
	var ambient_count:=0
	for index in range(1,5):
		var floor_people:Node3D=office.get_node("Workfloor%d/DepartmentStaff" % index)
		var people_stats:Dictionary=floor_people.call("stats")
		ambient_count+=int(people_stats["people"])
		if int(people_stats["animated"])!=0 or int(people_stats["seated"])!=6:
			_fail("Off-floor office NPCs must be paused and have authored seat anchors")
			return
	if ambient_count!=32:
		_fail("Four departments have 32 additional background employees")
		return
	var engineering_deck:Node3D=office.get_node("Workfloor1")
	var robotics_lab:Node3D=engineering_deck.get_node("RoboticsLab")
	engineering_deck.call("set_occupied",true)
	var engineering_people:Node3D=engineering_deck.get_node("DepartmentStaff")
	if int(engineering_people.call("stats")["animated"])!=8 or not str(engineering_deck.call("observe_worker",engineering_deck.to_global(Vector3(-5.3,1.15,5.65)))).contains("Faye"):
		_fail("Occupied floor animates staff and provides incidental coworker conversation")
		return
	var trace_key:=InputEventAction.new()
	trace_key.action=&"record_frame_trace"
	trace_key.pressed=true
	var recorder=world.get("frame_time_recorder")
	world.call("_unhandled_input",trace_key)
	if not recorder.recording:
		_fail("Office prologue accepts the same F8 diagnostic action as street gameplay")
		return
	world.call("_process",.016)
	if recorder.captured_frames()<1:
		_fail("Office gameplay contributes render interval samples")
		return
	recorder.end_capture()
	var context:Dictionary=world.call("_opening_diagnostic_context")
	if context.get("site")!="synaxis_hq" or not context.has("floor") or not context.has("stage"):
		_fail("Chapter evidence includes floor and stage context")
		return
	var walker:Node3D=engineering_people.get("_people")[7]
	var start_walk:Vector3=walker.position
	engineering_people.call("observe",Vector3.INF)
	for tick in range(100):
		engineering_people.call("_process",.1)
	if float(engineering_people.call("stats")["walk_distance"])<.5 or walker.position.distance_to(start_walk)<.1 or walker.get("_walk_rig").size()!=2:
		_fail("Standing coworker follows a bounded route with articulated legs")
		return
	engineering_people.call("observe",walker.global_position+Vector3.UP*1.15)
	var paused_at:=walker.position
	for tick in range(10):
		engineering_people.call("_process",.1)
	if walker.position.distance_to(paused_at)>.001 or bool(engineering_people.call("stats")["walking"]):
		_fail("Walking coworker yields to a nearby visitor")
		return
	engineering_people.call("observe",Vector3.INF)
	var services:Node3D=engineering_deck.get_node("OfficeServices")
	for tick in range(850):
		engineering_people.call("_process",.1)
		services.call("_process",.1)
	var npc_cycles:Dictionary=engineering_people.call("stats")
	# A full round has a bounded stand-up, alternating speakers and cleanup.
	var meeting_model=preload("res://scripts/synaxis_department_meeting.gd").new()
	meeting_model.begin()
	if meeting_model.speaker()!=6 or not meeting_model.line(1).contains("safety review"):
		_fail("Stand-up begins with the department-specific agenda")
		return
	meeting_model.tick(3.1)
	if meeting_model.speaker()!=7 or not meeting_model.line(1).contains("human override"):
		_fail("Stand-up alternates speakers")
		return
	meeting_model.tick(6.0)
	if meeting_model.active or meeting_model.completed!=1:
		_fail("Stand-up ends without leaving a conversation active")
		return
	if int(npc_cycles["print_visits"])<1 or int(npc_cycles["coffee_visits"])<1:
		_fail("Employee completes shared printer and coffee cycles")
		return
	for tick in range(500):
		engineering_people.call("_process",.1)
		services.call("_process",.1)
	if int(engineering_people.call("stats")["meetings_completed"])<1:
		_fail("Completed appliance round leads to a coordinated department stand-up")
		return
	meeting_model.begin(true)
	if not meeting_model.line(1).contains("access notice") or meeting_model.line(1).contains("safety review"):
		_fail("Late-shift stand-up reflects only public department notices")
		return
	meeting_model.reset()
	engineering_people.call("set_story_stage",4)
	var late_line:=str(engineering_people.call("observe",engineering_deck.to_global(Vector3(-5.3,1.15,5.65))))
	if not late_line.contains("internal matters") or not bool(engineering_people.call("stats")["offboarding"]):
		_fail("Employee remarks change when offboarding begins")
		return
	engineering_people.call("set_story_stage",-2)
	# Reset circulation before testing player-owned cycles independently.
	engineering_people.call("set_active",false)
	services.call("set_active",false)
	services.call("set_active",true)
	var counts:Dictionary=services.call("stats")
	var service_spec=preload("res://scripts/synaxis_office_services.gd")
	var print_at:Vector3=services.to_global(service_spec.PRINTER_USE)
	var coffee_at:Vector3=services.to_global(service_spec.COFFEE_USE)
	if not services.call("interact",print_at) or not services.call("interact",print_at):
		_fail("Office printer accepts local interaction and handles repeated input")
		return
	services.call("_process",3.1)
	if int(services.call("stats")["printed"])!=int(counts["printed"])+1 or not services.call("interact",coffee_at):
		_fail("Printer completes exactly one cycle; coffee station accepts local interaction")
		return
	services.call("_process",2.7)
	if int(services.call("stats")["brewed"])!=int(counts["brewed"])+1 or bool(services.call("stats")["stream"]):
		_fail("Coffee cycle finishes and stops the visible stream")
		return
	engineering_people.call("set_active",true)
	var routine:Dictionary=engineering_people.call("stats")
	if int(routine["board_visits"])<1 or int(routine["chat_visits"])<1 or walker.get("_clipboard")==null:
		_fail("Department routine visits the task board and coworker with authored props")
		return
	var lab_stats:Dictionary=robotics_lab.call("lab_stats")
	if int(lab_stats["prototypes"])!=2 or int(lab_stats["barriers"])!=4 or not bool(lab_stats["active"]):
		_fail("Robotics lab has two articulated display prototypes and a closed collision bay")
		return
	var engineer_line:String=engineering_deck.call("observe_worker",engineering_deck.to_global(Vector3(3.8,1.15,4.45)))
	if not engineer_line.contains("Imani"):
		_fail("Robotics engineer has unmarked proximity dialogue")
		return
	engineering_deck.call("set_occupied",false)
	if bool(robotics_lab.call("lab_stats")["active"]):
		_fail("Robot demonstration stops when its floor is unoccupied")
		return
	var comic_deck:Node3D=office.get_node("Workfloor2")
	var cal:Node3D=comic_deck.get("_rage")
	comic_deck.call("set_occupied",true)
	cal.call("observe",comic_deck.to_global(Vector3(4,1.15,4)))
	cal.call("_process",1.8)
	var gag:Dictionary=cal.call("get_gag_state")
	if not gag["standing"] or not gag["keyboard"]:
		_fail("Office worker stands up and picks up keyboard")
		return
	cal.call("_process",.95)
	gag=cal.call("get_gag_state")
	if not gag["impact"] or absf(float(gag["monitor_tilt"]))<.2:
		_fail("Keyboard rage must visibly displace its own monitor")
		return
	cal.call("_process",3.0)
	cal.call("observe",comic_deck.to_global(Vector3(4,1.15,4)))
	if cal.call("get_gag_state")["performing"]:
		_fail("Office comedy is one-shot, not an endlessly looping distraction")
		return
	comic_deck.call("set_occupied",false)
	var procurement:Node3D=office.get_node("Workfloor4")
	var egg:Node3D=procurement.get_node("OfficeEasterEggs")
	procurement.call("set_occupied",true)
	var arthur_line:String=procurement.call("observe_worker",procurement.to_global(Vector3(-4,1.15,3.7)))
	if not arthur_line.contains("Arthur") or int(egg.call("get_egg_state")["prop_parts"])<6:
		_fail("Red stapler is a physical prop with nearby coworker dialogue")
		return
	procurement.call("observe_worker",procurement.to_global(Vector3(0,1.15,5)))
	var second_line:String=procurement.call("observe_worker",procurement.to_global(Vector3(-4,1.15,3.7)))
	if second_line==arthur_line or int(egg.call("get_egg_state")["visits"])!=2:
		_fail("Stapler dialogue changes on revisits, not every frame")
		return
	procurement.call("set_occupied",false)
	var leadership_stats: Dictionary=office.call("executive_floor_stats")
	if int(leadership_stats.get("executives",0))!=7 or not bool(leadership_stats.get("occupied",false)) or int(leadership_stats.get("colliders",0))<10:
		_fail("Executive level must have seven distinct staff and physical luxury furniture")
		return
	var leadership: Node3D=office.get_node("ExecutiveFloor")
	if float(leadership_stats["ceo_suite_area"])<=float(leadership_stats["other_office_area"]) or float(leadership_stats["balcony_area"])<19.0 or leadership.position.y<47.0 or office.get_node_or_null("CrownTerraceSlab")==null:
		_fail("Founder has largest private suite and collision-backed terrace at the tower crown")
		return
	var hr_line: String=leadership.call("staff_remark",leadership.to_global(Vector3(-5.6,1.15,3.65)),-2)
	if not hr_line.contains("Blaire Sterling") or not hr_line.contains("whole self") or leadership.call("staff_remark",leadership.to_global(Vector3(-5.6,1.15,3.65)),4)==hr_line:
		_fail("HR slogans vary with mission phase and actual proximity")
		return
	for level in [4,3,2,1,0]:
		var previous:int=office.get("_active_floor")
		player.global_position=office.to_global(Vector3(.9,previous*3.65+1.15,5))
		world.call("_opening_interact")
		office.call("tick_lift",3.0,player)
		if int(office.get("_active_floor"))!=level:
			_fail("Lift returns to the ground-floor tutorial")
			return
	if bool(office.call("executive_floor_stats")["occupied"]):
		_fail("Executive actors and local lamps deactivate away from their floor")
		return
	if int(office.call("objective_stage",0))!=-2 or menu.call("is_open") or world.get("cash")!=before_severance:
		_fail("Office exploration does not advance the mission or alter the wallet")
		return
	var reserved:Node3D=office.get_node("FounderParking")
	var reserved_stats:Dictionary=reserved.call("stats")
	if not bool(reserved_stats["founder"]) or not bool(reserved_stats["static"]) or reserved_stats["plate"]!="SYNX1" or reserved.get_node_or_null("JetsonFounderR9/Coachwork/FrontClip")==null or reserved.get_node_or_null("FounderR9Collision")==null or world.get("cars").size()!=12:
		_fail("Founder R9 uses the authored vehicle and a physical bay without modifying save fleet indices")
		return
	if int(reserved_stats["staff_bays"])!=4 or int(reserved_stats["other_parked"])!=5 or not bool(reserved_stats["covered"]):
		_fail("Parking has covered leadership reserve and separate staff row without changing the active fleet")
		return
	for display in reserved.get("_parked"):
		if display.is_processing() or display.get_node_or_null("KestrelMonocoque")==null:
			_fail("Parked commuter displays must use authored models without runtime processing")
			return
	if not bool(office.get("_staff_exit_open")) or office.get_node("StaffExitDoor").visible or office.get_node_or_null("WorkfloorCapCollision")==null:
		_fail("Prologue opens a physical staff exit to the parking area and seals the fourth floor ceiling")
		return
	var guard_data=preload("res://scripts/synaxis_parking_dialogue.gd")
	var guard_position:Vector3=reserved.to_global(guard_data.ANCHOR+Vector3.UP*1.15)
	if not bool(reserved_stats["guard"]) or not bool(reserved_stats["booth"]) or office.call("parking_guard_reachable",office.to_global(Vector3(0,1.15,0))):
		_fail("Parking guard has local proximity and remains separate from lobby security")
		return
	player.global_position=guard_position
	world.call("_opening_interact")
	if not (menu.call("get_buttons") as Dictionary).has("guard_r9") or (menu.call("get_buttons") as Dictionary).has("guard_layoff"):
		_fail("Parking guard offers pre-dismissal topics without premature layoff dialogue")
		return
	menu.call("_choice","guard_r9")
	if menu.get("_guard_topic")!="guard_r9" or not (menu.call("get_buttons") as Dictionary).has("guard_back"):
		_fail("Guard answers selected question and supports returning to topic list")
		return
	menu.call("_choice","guard_back")
	menu.call("_choice","guard_shift")
	if world.get("progression").synaxis_contact!=1 or menu.get("_guard_contact")!=1:
		_fail("Talking about Marcus's history establishes a real persistent contact")
		return
	menu.call("_choice","guard_back")
	if (menu.call("get_buttons") as Dictionary).has("guard_followup"):
		_fail("Post-dismissal check-in must remain locked during employment")
		return
	menu.call("_choice","guard_leave")
	if menu.call("is_open") or menu.get("_opening_stage")!=0 or world.get("cash")!=before_severance:
		_fail("Guard dialogue is optional and cannot advance the opening or change cash")
		return
	var staff: Dictionary=office.get("_staff")
	if staff.size()!=8 or not staff.has("reception"):
		_fail("HQ has eight authored staff plus the executive assistant")
		return
	for staff_id in staff:
		var employee: Node3D=staff[staff_id]
		if employee.get_node_or_null("BreathingTorso/SynaxisEmployeeBadge")==null or str(employee.get("display_name")).is_empty():
			_fail("Each employee has physical department attire and an identity")
			return
	var founder: Node3D=staff["jetson_wang"]
	var jacket: MeshInstance3D=founder.get_node_or_null("BreathingTorso/JacketSilhouette")
	if founder.get("outfit")!="executive_leather" or jacket==null or not jacket.material_override.normal_enabled or founder.get_node_or_null("BreathingTorso/MainZipperTrack")==null or founder.get_node_or_null("BreathingTorso/TieBlade")!=null:
		_fail("Jetson has signature textured leather outerwear, zipper details and no tie")
		return
	var mika: Node3D=staff["mika"]
	var imported_pilot:bool=mika.call("imported_staff_ready")
	if ResourceLoader.exists(preload("res://scripts/synaxis_staff.gd").pilot_model_path(),"PackedScene") or OS.get_environment("NIGHTGRID_REQUIRE_STAFF_PILOT")=="1":
		if not imported_pilot or mika.get_node("BreathingTorso").visible:
			_fail("Mika must render the validated imported weighted humanoid instead of the primitive fallback")
			return
		var visual:=mika.get_node("ImportedStaffVisual")
		if visual.find_children("*","Skeleton3D",true,false).is_empty() or visual.find_children("*","AnimationPlayer",true,false).is_empty():
			_fail("Imported staff pilot requires an actual skeleton and clips")
			return
	var guard:Node3D=staff["security"]
	if ResourceLoader.exists(preload("res://scripts/synaxis_staff.gd").pilot_model_path("security"),"PackedScene") or OS.get_environment("NIGHTGRID_REQUIRE_STAFF_GUARD")=="1":
		if not guard.call("imported_staff_ready") or guard.get_node("BreathingTorso").visible:
			_fail("Owen must use his own imported humanoid and hide the primitive fallback")
			return
		var guard_visual:=guard.get_node("ImportedStaffVisual")
		var supervisor_visual:=mika.get_node_or_null("ImportedStaffVisual")
		if supervisor_visual==null or guard_visual.get("_model")==supervisor_visual.get("_model"):
			_fail("Named supervisor and guard require distinct imported models")
			return
	var staff_line: String=office.call("update_staff_attention",-2,mika.global_position+Vector3.UP*1.15)
	if not staff_line.contains("Mika Torres") or not mika.call("get_staff_state")["attention"]:
		_fail("Nearby supervisor reacts without a modal menu")
		return
	if office.call("update_staff_attention",-2,office.to_global(Vector3(0,1.15,0)))!="" or mika.call("get_staff_state")["attention"]:
		_fail("Staff attention clears out of range")
		return
	var rooms=preload("res://scripts/synaxis_restrooms.gd")
	var washrooms=office.get_node_or_null("Restrooms")
	if not is_instance_valid(washrooms) or washrooms.find_children("*","CollisionShape3D",true,false).size()<10:
		_fail("Both washrooms must have physical walls and closed stalls")
		return
	if not str(office.call("restroom_encounter",office.to_global(Vector3(0,1.15,5.0)))).is_empty():
		_fail("Restroom encounters require crossing the entrance")
		return
	if washrooms.position!=rooms.OFFSET or washrooms.get_node("ExtractorHaze").emitting:
		_fail("Restrooms must be perimeter rooms and haze must not leak into lift corridor")
		return
	var ground_lift:=office.get_node_or_null("LiftFrontage")
	if ground_lift==null or ground_lift.find_children("*","CollisionShape3D",true,false).size()!=3:
		_fail("Ground lift must have a recognizable collision-backed shaft frontage")
		return
	if office.call("lift_direction",office.to_global(Vector3(.65,1.15,4.35)))!=-1 or office.call("lift_direction",office.to_global(Vector3(-.65,1.15,4.35)))!=1:
		_fail("Visible elevator call area must be usable on approach")
		return
	for id in [rooms.MEN,rooms.WOMEN]:
		player.global_position=washrooms.to_global(rooms.CENTERS[id])
		world.call("_process",0.0)
		if not (menu.call("get_buttons") as Dictionary).has("restroom_leave") or menu.get("_restroom_id")!=id:
			_fail("Entering each actual restroom triggers its distinct scene")
			return
		menu.call("_choice","restroom_leave")
		world.call("_process",0.0)
		if menu.call("is_open") or int(office.call("objective_stage",0))!=-2 or world.get("cash")!=before_severance:
			_fail("Restroom scene is optional, once per visit and cannot affect mission or wallet")
			return
	var breakroom_hq=preload("res://scripts/synaxis_office.gd")
	player.global_position=office.to_global(breakroom_hq.BREAKROOM_POINT)
	world.call("_opening_interact")
	if not (menu.call("get_buttons") as Dictionary).has("breakroom_photo") or not is_instance_valid(office.get_node_or_null("PartyBannerBacking")):
		_fail("Optional breakroom party requires actual in-world proximity and branded decor")
		return
	menu.call("_choice","breakroom_decline")
	menu.call("_choice","breakroom_leave")
	if menu.call("is_open") or not office.get("_breakroom_seen") or menu.get("_opening_stage")!=0 or world.get("cash")!=before_severance:
		_fail("Optional party cannot alter mission stage or wallet")
		return
	world.call("_opening_interact")
	if menu.call("is_open"):
		_fail("Party cannot be replayed repeatedly in the same prologue")
		return
	player.global_position = office.call("point",0)
	world.call("_opening_interact")
	if menu.call("is_open") or office.call("errand_complete"):
		_fail("IT alert cannot be opened before collecting the folder")
		return
	player.global_position=office.call("point",-2)
	world.call("_opening_interact")
	if int(office.call("objective_stage",0))!=-1 or office.get("_folder_desk").visible:
		_fail("Folder pickup updates objective and removes desk prop")
		return
	world.call("_opening_interact")
	if office.call("errand_complete") or menu.get("screen")!="workstation":
		_fail("Desk terminal must be optional and cannot hand over folder remotely")
		return
	var terminal_data=preload("res://scripts/synaxis_workstation.gd")
	menu.call("_choice","terminal_access")
	if menu.get("_terminal_tab")!="access" or terminal_data.page("access",false).has("rows"):
		_fail("Unverified workstation must not expose restricted access records")
		return
	menu.call("_choice","terminal_ticket")
	menu.call("_choice","terminal_leave")
	if menu.call("is_open") or int(office.call("objective_stage",0))!=-1:
		_fail("Leaving cubicle terminal returns to unchanged errand")
		return
	player.global_position=office.to_global(Vector3(.9,1.15,5))
	world.call("_opening_interact")
	office.call("tick_lift",3.0,player)
	var basement:Node3D=office.get_node("BasementIT")
	var bstats:Dictionary=basement.call("basement_stats")
	if int(office.get("_active_floor"))!=-1 or int(bstats["racks"])!=20 or not bool(bstats["hum"]):
		_fail("IT handoff requires real basement lift travel, twenty racks and local ambient hum")
		return
	world.call("_physics_process",0.0)
	if int(office.get("_active_floor"))!=-1 or office.to_local(player.global_position).y>0.0:
		_fail("Basement must not activate the ground-level fall recovery")
		return
	player.global_position=office.call("point",-1)
	world.call("_opening_interact")
	if not office.call("errand_complete") or not office.get("_folder_desk").visible or world.get("cash")!=before_severance:
		_fail("Actual IT handoff must precede alert without changing wages")
		return
	world.call("_opening_interact")
	menu.call("_choice","opening_inspect")
	menu.call("_choice","terminal_open")
	if menu.get("screen")!="workstation" or menu.get("_terminal_tab")!="access" or terminal_data.page("access",true)["rows"].size()!=5:
		_fail("Verified IT review exposes the three exports and executive exception")
		return
	menu.call("_choice","terminal_leave")
	if menu.get("screen")!="opening" or int(menu.get("_opening_stage"))!=1:
		_fail("Closing IT terminal preserves review stage")
		return
	menu.call("_choice","opening_brief")
	if menu.call("is_open"):
		_fail("Executive briefing requires walking to office")
		return
	player.global_position=office.to_global(Vector3(-.9,1.15-3.65,5))
	world.call("_opening_interact")
	office.call("tick_lift",3.0,player)
	if int(office.get("_active_floor"))!=0 or bool(basement.call("basement_stats")["hum"]):
		_fail("Returning to ground floor stops server-room ambient audio")
		return
	for next_floor in [1,2,3,4,13]:
		player.global_position=office.to_global(Vector3(-.9,int(office.get("_active_floor"))*3.65+1.15,5))
		world.call("_opening_interact")
		office.call("tick_lift",3.0,player)
		if int(office.get("_active_floor"))!=next_floor:
			_fail("Executive briefing requires travelling to the crown")
			return
	player.global_position = office.call("point",2)
	world.call("_opening_interact")
	menu.call("_choice","opening_phone")
	var assistant: Node3D = office.get("_assistant")
	if staff["jetson_wang"].call("get_staff_state")["beat"]!=1:
		_fail("CEO performance follows the staged executive briefing")
		return
	if not is_instance_valid(assistant) or not assistant.get("_on_call") or not assistant.get("_phone").visible:
		_fail("Visible assistant speakerphone performance during Mandarin beat")
		return
	menu.call("_choice","opening_hangup")
	if assistant.get("_on_call") or assistant.get("_phone").visible:
		_fail("Hanging up clears the prop and phone pose")
		return
	if not (menu.call("get_buttons") as Dictionary).has("notes_open"):
		_fail("Executive report choice should allow review of actual interview notes")
		return
	menu.call("_choice","notes_open")
	menu.call("_choice","notes_back")
	if menu.get("screen")!="opening" or int(menu.get("_opening_stage"))!=2 or int(menu.get("_briefing_beat"))!=2:
		_fail("Reviewing interview notes cannot replay or advance the briefing")
		return
	menu.call("_choice","opening_security")
	if menu.get("_opening_report")!="opening_security":
		_fail("Security escalation has its own response")
		return
	menu.call("_choice","opening_read_notice")
	player.global_position = office.call("point",4)
	world.call("_opening_interact")
	if not (menu.call("get_buttons") as Dictionary).has("opening_exit_accept") or not (menu.call("get_buttons") as Dictionary).has("opening_exit_decline"):
		_fail("Exit interview presents both feedback choices")
		return
	menu.call("_choice","opening_accept")
	if not menu.call("is_open") or world.get("cash")!=before_severance:
		_fail("Cannot collect severance before offboarding")
		return
	menu.call("_choice","opening_exit_decline")
	for next_floor in [4,3,2,1,0]:
		player.global_position=office.to_global(Vector3(.9,int(office.get("_active_floor"))*3.65+1.15,5))
		world.call("_opening_interact")
		office.call("tick_lift",3.0,player)
		if int(office.get("_active_floor"))!=next_floor:
			_fail("Offboarding returns through the lift to reception")
			return
	player.global_position = office.call("point",5)
	world.call("_opening_interact")
	if menu.get("_opening_exit")!="opening_exit_decline":
		_fail("Declining exit interview has distinct response")
		return
	if not (menu.call("get_buttons") as Dictionary).has("opening_accept"):
		_fail("Final notice must expose QuotaDrop acceptance")
		return
	menu.call("_choice","opening_accept")
	var headquarters = preload("res://scripts/synaxis_office.gd")
	if not office.call("exit_active") or office.call("objective_stage",5)!=6 or world.get("cash")!=before_severance:
		_fail("Final notice starts physical property return without crediting severance")
		return
	world.call("_accept_opening")
	if world.get("cash")!=before_severance:
		_fail("Cannot bypass equipment return")
		return
	world.call("_opening_interact")
	if office.call("objective_stage",5)!=7 or not office.get("_returned_kit").visible or not office.get("_personal_bag").visible:
		_fail("Equipment return visibly deposits company property and makes personal belongings available")
		return
	player.global_position=office.call("point",7)
	world.call("_opening_interact")
	if office.call("objective_stage",5)!=8 or opening_visual.get("corporate_attire") or not bool(office.get("_gate_open")):
		_fail("Collecting belongings restores clothing and opens the public exit")
		return
	world.call("_accept_opening")
	if world.get("cash")!=before_severance:
		_fail("Severance remains pending until the player walks outside")
		return
	player.global_position=office.call("point",8)
	world.call("_accept_opening")
	world.call("_accept_opening")
	if world.get("_opening_office")!=null or player.global_position.distance_to(headquarters.ENTRY)>.01 or world.get("city_details").call("synaxis_headquarters")!=office:
		_fail("Office exit retains the real headquarters and places player at public entrance")
		return
	if opening_visual.get("corporate_attire") or opening_visual.get("skeleton")!=opening_rig:
		_fail("Offboarding restores personal clothing without replacing the rig")
		return
	if world.get("cash") != before_severance+75 or not world.get("courier_mission").gig_economy or menu.call("is_open"):
		_fail("Opening credits severance once and enables real QuotaDrop work")
		return
	if office.get_node_or_null("CorporatePropaganda")!=propaganda:
		_fail("Propaganda is permanent headquarters dressing, not a tutorial overlay")
		return
	world.call("_toggle_interior")
	if not str(world.get("notification")).contains("Public lobby open") or world.get("_opening_office")!=null:
		_fail("HQ has a public lobby, not a second prologue")
		return
	player.global_position=office.to_global(headquarters.LOBBY_CHECKPOINT)
	world.call("_toggle_interaction")
	if not str(world.get("notification")).contains("Badge access revoked") or not is_instance_valid(office.get_node_or_null("SecurityGateCollision")):
		_fail("Restricted office remains physically secured at the public checkpoint")
		return
	if bool(office.get("_staff_exit_open")) or not office.get_node("StaffExitDoor").visible:
		_fail("Offboarding revokes the parking-side staff entrance")
		return
	player.global_position=guard_position
	world.call("_toggle_interaction")
	if not menu.get("_guard_former") or not (menu.call("get_buttons") as Dictionary).has("guard_access") or not (menu.call("get_buttons") as Dictionary).has("guard_layoff"):
		_fail("Permanent guard recognizes revoked badge after offboarding")
		return
	menu.call("_choice","guard_layoff")
	if menu.get("_guard_topic")!="guard_layoff" or not guard_data.reply("guard_layoff",true).contains("access-revocation"):
		_fail("Former employee can ask about dismissal without restoring access")
		return
	menu.call("_choice","guard_back")
	if not (menu.call("get_buttons") as Dictionary).has("guard_followup") or not str(world.call("_journal_context")["synaxis_contact"]).contains("A FAMILIAR FACE"):
		_fail("Former employee with introduction receives optional check-in")
		return
	menu.call("_choice","guard_followup")
	if world.get("progression").synaxis_contact!=2 or world.get("cash")!=before_severance+75:
		_fail("Check-in completes without granting money or access")
		return
	menu.call("_choice","guard_back")
	menu.call("_choice","guard_followup")
	if world.get("progression").synaxis_contact!=2:
		_fail("Repeated check-in is idempotent")
		return
	menu.call("_choice","guard_leave")
	world.call("_update_hud")
	if not str(world.get("hud_prompt").text).contains("Talk to Marcus Vale"):
		_fail("Local guard interaction has discoverable contextual prompt after prologue")
		return
	menu.call("open_journal",world.call("_journal_context"))
	if not (menu.call("get_buttons") as Dictionary).has("synaxis_waypoint"):
		_fail("Synaxis has a persistent return waypoint")
		return
	menu.call("hide_for_game")
	var order = world.get("courier_mission")
	var restaurants: Node = world.get("venue_system")
	restaurants.call("set_hour",5.0)
	player.global_position = order.target()
	world.call("_toggle_interaction")
	if order.has_package():
		_fail("Closed kitchen cannot hand over a new order")
		return
	restaurants.call("set_hour",19.25)
	world.call("_toggle_interaction")
	if not order.has_package():
		_fail("Explicit on-foot pickup at actual restaurant")
		return
	var courier_visual: Node3D = player.get("visual")
	var bag: Node3D = courier_visual.get("_meal_bag")
	if not is_instance_valid(bag) or not bag.visible:
		_fail("Collected meal must appear as the actual reusable held bag")
		return
	var opening_save: Dictionary = world.call("_capture_snapshot")
	if int(opening_save["progression"].get("synaxis_contact",0))!=2:
		_fail("Contact completion must serialize")
		return
	var contact_ledger=preload("res://scripts/progression_ledger.gd")
	var legacy_contact:Dictionary=opening_save["progression"].duplicate(true)
	legacy_contact.erase("synaxis_contact")
	var restored_contact=contact_ledger.new()
	if not restored_contact.restore(opening_save["cash"],legacy_contact) or restored_contact.synaxis_contact!=0:
		_fail("Old progression saves restore with no prior introduction")
		return
	legacy_contact["synaxis_contact"]=3
	if contact_ledger.valid_snapshot(legacy_contact):
		_fail("Out-of-range contact state must be rejected")
		return
	legacy_contact["synaxis_contact"]=2
	legacy_contact["receipts"].erase(opening.RECEIPT)
	if contact_ledger.valid_snapshot(legacy_contact):
		_fail("Check-in completion requires actual severance receipt")
		return
	world.get("progression").synaxis_contact=0
	world.get("courier_mission").gig_economy = false
	world.call("_apply_snapshot",opening_save)
	if not world.get("courier_mission").gig_economy or world.get("cash") != before_severance+75 or world.get("progression").synaxis_contact!=2:
		_fail("Opening economy survives save restore")
		return
	if not bag.visible or courier_visual.get("_meal_bag")!=bag:
		_fail("Restored meal must reuse the same held bag")
		return
	player.global_position = order.target()
	var order_pay: int = order.payout()
	world.call("_toggle_interaction")
	if order.has_package() or bag.visible or world.get("cash")!=before_severance+75+order_pay:
		_fail("Physical handoff removes bag and pays actual order exactly once")
		return
	menu.call("hide_for_game")
	menu.call("open_sampler_practice",1)
	var rehearsal=menu.get("_rhythm")
	var feedback:Label=menu.get("_rhythm_status")
	if not feedback.text.contains("GET READY") or not feedback.text.contains("0 / 6 needed"):
		_fail("Rhythm HUD must show ready state and pass target")
		return
	rehearsal.advance(rehearsal.target_time()-rehearsal.elapsed)
	rehearsal.strike((int(rehearsal.pattern[rehearsal.index])+1)%3)
	menu.call("_refresh_rhythm")
	if not feedback.text.contains("WRONG PAD"):
		_fail("Incorrect pad feedback missing")
		return
	rehearsal.advance(rehearsal.target_time()-rehearsal.elapsed+rehearsal.hit_window+.01)
	menu.call("_refresh_rhythm")
	if not feedback.text.contains("MISSED"):
		_fail("Missed beat feedback missing")
		return
	rehearsal.advance(rehearsal.target_time()-rehearsal.elapsed)
	rehearsal.strike(rehearsal.pattern[rehearsal.index])
	menu.call("_refresh_rhythm")
	if not feedback.text.contains("ON BEAT") or not feedback.text.contains("1 / 6 needed"):
		_fail("Successful hit feedback missing")
		return
	rehearsal.advance(60.0)
	menu.call("_refresh_rhythm")
	if not feedback.text.contains("TRY ANOTHER SET") or not feedback.text.contains("need 6") or not menu.get("_rhythm_claim").disabled:
		_fail("Failed set must expose target and keep claim disabled")
		return
	menu.call("hide_for_game")
	print("MENU_GAMEPAD_SMOKE PASS: action_count=", input_spec.ACTIONS.size(),
		" / settings saved / pause & focus / controller context / title confirmation")
	quit(0)
