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
	var detail_stats: Dictionary = finish.call("get_detail_stats")
	if int(detail_stats["parts"]) < 500 or int(detail_stats["batches"]) > 75:
		_fail("Office detail must use bounded static material batches")
		return
	for batch in finish.get_children():
		if not batch is MultiMeshInstance3D or batch.multimesh.instance_count <= 0 or batch.material_override == null:
			_fail("Office finish requires populated shared geometry and materials")
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
	player.global_position=office.to_global(Vector3(0,1.15,0))
	world.call("_opening_interact")
	if menu.call("is_open") or int(office.call("objective_stage",0))!=-2:
		_fail("Cannot interact with office workstation remotely")
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
	for level in range(1,6):
		player.global_position=office.to_global(Vector3(-.9,(level-1)*3.65+1.15,5))
		world.call("_opening_interact")
		if int(office.get("_active_floor"))!=level or absf(office.to_local(player.global_position).y-(level*3.65+1.15))>.01:
			_fail("Lift travels to actual upper floor elevations")
			return
	var leadership_stats: Dictionary=office.call("executive_floor_stats")
	if int(leadership_stats.get("executives",0))!=7 or not bool(leadership_stats.get("occupied",false)) or int(leadership_stats.get("colliders",0))<10:
		_fail("Executive level must have seven distinct staff and physical luxury furniture")
		return
	var leadership: Node3D=office.get_node("ExecutiveFloor")
	var hr_line: String=leadership.call("staff_remark",leadership.to_global(Vector3(-5.6,1.15,3.65)),-2)
	if not hr_line.contains("Blaire Sterling") or not hr_line.contains("whole self") or leadership.call("staff_remark",leadership.to_global(Vector3(-5.6,1.15,3.65)),4)==hr_line:
		_fail("HR slogans vary with mission phase and actual proximity")
		return
	for level in range(5,0,-1):
		player.global_position=office.to_global(Vector3(.9,level*3.65+1.15,5))
		world.call("_opening_interact")
		if int(office.get("_active_floor"))!=level-1:
			_fail("Lift returns to the ground-floor tutorial")
			return
	if bool(office.call("executive_floor_stats")["occupied"]):
		_fail("Executive actors and local lamps deactivate away from their floor")
		return
	if int(office.call("objective_stage",0))!=-2 or menu.call("is_open") or world.get("cash")!=before_severance:
		_fail("Office exploration does not advance the mission or alter the wallet")
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
	for id in [rooms.MEN,rooms.WOMEN]:
		player.global_position=office.to_global(rooms.CENTERS[id])
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
	if office.call("errand_complete"):
		_fail("Folder cannot be handed over remotely")
		return
	player.global_position=office.call("point",-1)
	world.call("_opening_interact")
	if not office.call("errand_complete") or not office.get("_folder_desk").visible or world.get("cash")!=before_severance:
		_fail("Actual IT handoff must precede alert without changing wages")
		return
	world.call("_opening_interact")
	menu.call("_choice","opening_inspect")
	menu.call("_choice","opening_brief")
	if menu.call("is_open"):
		_fail("Executive briefing requires walking to office")
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
	player.global_position = office.call("point",5)
	world.call("_opening_interact")
	if menu.get("_opening_exit")!="opening_exit_decline":
		_fail("Declining exit interview has distinct response")
		return
	if not (menu.call("get_buttons") as Dictionary).has("opening_accept"):
		_fail("Final notice must expose QuotaDrop acceptance")
		return
	menu.call("_choice","opening_accept")
	world.call("_accept_opening")
	var headquarters = preload("res://scripts/synaxis_office.gd")
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
	world.get("courier_mission").gig_economy = false
	world.call("_apply_snapshot",opening_save)
	if not world.get("courier_mission").gig_economy or world.get("cash") != before_severance+75:
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
	print("MENU_GAMEPAD_SMOKE PASS: action_count=", input_spec.ACTIONS.size(),
		" / settings saved / pause & focus / controller context / title confirmation")
	quit(0)
