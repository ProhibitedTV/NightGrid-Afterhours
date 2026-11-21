extends Node3D
## NIGHTGRID: AFTERHOURS — a generated 3D city with an original courier/crime loop.

const PlayerScript = preload("res://scripts/player.gd")
const HumanoidVisualScript = preload("res://scripts/humanoid_visual.gd")
const CarScript = preload("res://scripts/car.gd")
const KestrelVisual = preload("res://scripts/kestrel_s6_visual.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityDetailsScript = preload("res://scripts/city_details.gd")
const CityPerimeterScript = preload("res://scripts/city_perimeter.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const FloraScript = preload("res://scripts/flora.gd")
const Materials = preload("res://scripts/material_library.gd")
const NightLightingScript = preload("res://scripts/night_lighting.gd")
const WetStreetsScript = preload("res://scripts/wet_streets.gd")
const HeroIntersectionScript = preload("res://scripts/central_exchange_hero.gd")
const CentralRoadScanScript = preload("res://scripts/central_exchange_road_surface.gd")
const TrafficSignalsScript = preload("res://scripts/traffic_signals.gd")
const TrafficSystemScript = preload("res://scripts/traffic_system.gd")
const RailSystemScript = preload("res://scripts/rail_system.gd")
const VenueSystemScript = preload("res://scripts/venue_system.gd")
const CivicServicesScript = preload("res://scripts/civic_services.gd")
const InteriorSystemScript = preload("res://scripts/interior_system.gd")
const GameInput = preload("res://scripts/game_input.gd")
const GameMenuScript = preload("res://scripts/game_menu.gd")
const NightGridFMScript = preload("res://scripts/nightgrid_fm.gd")
const WorldAudioScript = preload("res://scripts/world_audio.gd")
const FrameTimeRecorder = preload("res://scripts/frame_time_recorder.gd")
const CELL = 58.0
const GRID_RADIUS = 4
const PLAYER_START = Vector3(0.0, 1.15, 6.0)
const VEHICLE_COLORS = [
	Color("f04e59"), Color("40b1ff"), Color("e9bf51"),
	Color("9b75e7"), Color("dedee0"), Color("58c99e")
]
const PICKUPS = [
	Vector3(-116.0, 0.0, 0.0), Vector3(58.0, 0.0, -116.0),
	Vector3(116.0, 0.0, 58.0), Vector3(-58.0, 0.0, 116.0)
]
const DROPOFFS = [
	Vector3(116.0, 0.0, 116.0), Vector3(-116.0, 0.0, 58.0),
	Vector3(0.0, 0.0, -116.0), Vector3(116.0, 0.0, -58.0)
]

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var current_car: CharacterBody3D
var cars: Array[CharacterBody3D] = []
var officers: Array[CharacterBody3D] = []
var camera: Camera3D
var marker: Node3D
var marker_light: OmniLight3D
var hud_label: Label
var performance_label: Label
var performance_overlay := false
var minimap: Control
var city_details: Node3D
var city_perimeter: Node3D
var flora: Node3D
var day_night: Node
var street_lights: Node3D
var wet_streets: Node3D
var hero_intersection: Node3D
var central_roadway: Node3D
var signal_controller: Node3D
var traffic: Node3D
var rail: Node3D
var venue_system: Node3D
var civic_services: Node3D
var interiors: Node3D
var game_menu: CanvasLayer
var nightgrid_fm: Node
var world_audio: Node
var frame_time_recorder = FrameTimeRecorder.new()
var gamepad_active := false
var mouse_sensitivity := 0.0032
var stick_sensitivity := 2.6
var invert_look_y := false
var civic_selected_id := ""
var civic_job_active := ""
var civic_job_completed: Array[String] = []
var civic_intel: Array[String] = []
var ration_packs := 0
var venue_panel: PanelContainer
var venue_label: Label
var venue_service_button: Button
var venue_job_button: Button
var venue_talk_button: Button
var venue_close_button: Button
var mara_dialogue_line := ""
var venue_selected_id := ""
var venue_job_active := ""
var venue_job_completed: Array[String] = []
var _venue_clock_tick := 0.0
# Stream/city lights and HUD need not update at the monitor's refresh rate.
var _focus_update_clock := 1.0
var _hud_update_clock := 1.0
var current_transit: Node3D
var transit_kind := ""
var session: Node
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var yaw := 0.0
var pitch := 0.42
var cash := 0
var health := 100.0
var heat := 0.0
var deliveries := 0
var carrying := false
var mission_position := Vector3.ZERO
var notification := "Welcome to the night shift. Find a car and pick up the package."
var notification_time := 8.0
var police_cooldown := 4.0

func _ready() -> void:
	GameInput.install()
	session = get_node("/root/GameSession")
	rng.seed = int(session.get("world_seed"))
	_build_environment()
	_build_city()
	_build_city_perimeter()
	_build_world_systems()
	_create_player()
	_spawn_traffic()
	_build_transport()
	_create_camera()
	_create_marker()
	_build_hud()
	_build_game_menu()
	_build_nightgrid_fm()
	_build_world_audio()
	var restore: Dictionary = session.call("take_pending_restore")
	if restore.is_empty():
		_set_mission_target(PICKUPS[0], false)
	else:
		_apply_snapshot(restore)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if DisplayServer.get_name() != "headless" and not bool(session.get("boot_menu_shown")):
		session.set("boot_menu_shown", true)
		game_menu.call("open_title")

func _build_game_menu() -> void:
	game_menu = GameMenuScript.new()
	game_menu.name = "GameMenus"
	add_child(game_menu)
	game_menu.call("set_world_node", self)
	game_menu.connect("action_requested", Callable(self, "_on_menu_action"))
	game_menu.connect("settings_changed", Callable(self, "_apply_game_settings"))
	game_menu.call("set_has_save", not (session.call("read_snapshot") as Dictionary).is_empty())
	_apply_game_settings(game_menu.call("get_settings"))

func _build_nightgrid_fm() -> void:
	nightgrid_fm = NightGridFMScript.new()
	nightgrid_fm.name = "NightGridFM"
	nightgrid_fm.set("venues", venue_system)
	nightgrid_fm.set("menu", game_menu)
	add_child(nightgrid_fm)
	var options: Dictionary = game_menu.call("get_settings")
	nightgrid_fm.call("set_preferences", float(options.get("music_volume", 0.65)), bool(options.get("radio_on", true)))

func _build_world_audio() -> void:
	world_audio = WorldAudioScript.new()
	world_audio.name = "WorldAudio"
	world_audio.set("menu", game_menu)
	add_child(world_audio)
	world_audio.call("set_traffic", traffic)
	var options: Dictionary = game_menu.call("get_settings")
	world_audio.call("set_preferences", float(options.get("ambience_volume", 0.65)),
		float(options.get("sfx_volume", 0.75)))

func _on_menu_action(action: String) -> void:
	match action:
		"save":
			_save_game()
		"load":
			_load_game()
		"new":
			_new_game()
		"journal":
			game_menu.call("open_journal", _journal_context())

func _journal_context() -> Dictionary:
	var outside: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position
	var district: String = city_details.call("get_district_at", outside)
	var landmark: String = city_details.call("get_nearby_landmark", outside)
	var objective := "Deliver package" if carrying else "Collect courier package"
	var remaining := roundi(outside.distance_to(mission_position))
	var loaded: Dictionary = city_details.call("get_streaming_stats")
	return {
		"district": district if landmark.is_empty() else "%s / %s" % [district, landmark],
		"clock": day_night.call("clock_string"),
		"seed": session.get("world_seed"),
		"main_objective": "%s  •  %dm" % [objective, remaining],
		"venue_job": _venue_job_text(),
		"civic_job": _civic_job_text(),
		"cash": cash, "health": health, "heat": heat,
		"supplies": ration_packs, "deliveries": deliveries,
		"venue_completed": venue_job_completed.size(),
		"civic_completed": civic_job_completed.size(),
		"archives": civic_intel.size(),
		"loaded_blocks": loaded.get("loaded_blocks", 0)
	}

func _apply_game_settings(options: Dictionary) -> void:
	mouse_sensitivity = clampf(float(options.get("mouse_sensitivity", 0.0032)), 0.001, 0.010)
	stick_sensitivity = clampf(float(options.get("stick_sensitivity", 2.6)), 0.5, 5.0)
	invert_look_y = bool(options.get("invert_look_y", false))
	if is_instance_valid(nightgrid_fm):
		nightgrid_fm.call("set_preferences", float(options.get("music_volume", 0.65)), bool(options.get("radio_on", true)))
	if is_instance_valid(world_audio):
		world_audio.call("set_preferences", float(options.get("ambience_volume", 0.65)), float(options.get("sfx_volume", 0.75)))
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(0.001, float(options.get("master_volume", 0.8)))))
	world_environment.environment.ssr_enabled = bool(options.get("ssr_enabled", true))
	world_environment.environment.glow_enabled = bool(options.get("glow_enabled", true))
	world_environment.environment.ssao_enabled = bool(options.get("ao_enabled", true))
	world_environment.environment.fog_enabled = bool(options.get("fog_enabled", true))
	performance_overlay = bool(options.get("show_fps", false))
	performance_label.visible = performance_overlay
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if bool(options.get("vsync_enabled", true)) else DisplayServer.VSYNC_DISABLED)

func _input(event: InputEvent) -> void:
	if GameInput.is_gamepad_event(event):
		gamepad_active = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		gamepad_active = false
	if game_menu != null and game_menu.call("is_open"):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch + event.relative.y * mouse_sensitivity * (-1.0 if invert_look_y else 1.0) * 0.625, 0.20, 0.85)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not venue_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if game_menu != null and game_menu.call("is_open"):
		return
	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("game_pause"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_pause")
	elif event.is_action_pressed("game_back"):
		if venue_panel.visible:
			_close_venue()
		else:
			# The B button doubles as the car's handbrake. Only Start/Esc
			# opens the pause menu in free gameplay.
			return
	elif event.is_action_pressed("map_open"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_map")
	elif event.is_action_pressed("journal_open"):
		if venue_panel.visible:
			_close_venue()
		game_menu.call("open_journal", _journal_context())
	elif event.is_action_pressed("radio_toggle") and current_car != null:
		var prefs: Dictionary = game_menu.call("get_settings")
		var enabled := not bool(prefs.get("radio_on", true))
		game_menu.call("update_setting", "radio_on", enabled)
		_notify("NightGrid FM tuned in. B toggle / N next." if enabled else "NightGrid FM switched off.")
	elif event.is_action_pressed("radio_next") and current_car != null:
		if nightgrid_fm.call("next_car_track"):
			_notify(str(nightgrid_fm.call("get_now_playing")))
	elif venue_panel.visible:
		if event.is_action_pressed("service_one"):
			_venue_action(1)
		elif event.is_action_pressed("service_two"):
			_venue_action(2)
		elif event.is_action_pressed("service_three"):
			_venue_action(3)
		elif event.is_action_pressed("interact"):
			_close_venue()
	elif event.is_action_pressed("car_toggle"):
		_toggle_car()
	elif event.is_action_pressed("transit_toggle"):
		_toggle_transit()
	elif event.is_action_pressed("interior_toggle"):
		_toggle_interior()
	elif event.is_action_pressed("interact"):
		_toggle_interaction()
	elif event.is_action_pressed("use_supply"):
		_consume_ration()
	elif event.is_action_pressed("game_save"):
		_save_game()
	elif event.is_action_pressed("game_load"):
		_load_game()
	elif event.is_action_pressed("game_new"):
		game_menu.call("confirm_new_game")
	elif event.is_action_pressed("advance_clock"):
		day_night.call("advance_hour", 1.0)
	elif event.is_action_pressed("pause_clock"):
		day_night.call("toggle_pause")
	elif event.is_action_pressed("toggle_fps"):
		performance_overlay = not performance_overlay
		performance_label.visible = performance_overlay
	elif event.is_action_pressed("record_frame_trace"):
		if frame_time_recorder.recording or frame_time_recorder.capture_full:
			frame_time_recorder.end_capture()
			var exported: String = frame_time_recorder.export_csv()
			_notify("Drive trace saved: " + exported if not exported.is_empty() else "Drive trace export failed.")
		else:
			var stream_start: Dictionary = city_details.call("get_streaming_stats")
			frame_time_recorder.begin_capture(int(stream_start["loads"]),
				int(stream_start.get("stage_steps", 0)), int(stream_start.get("total_build_usec", 0)))
			_notify("Drive trace recording. Press F8 again to save a CSV.")
	elif event.is_action_pressed("toggle_ssr"):
		world_environment.environment.ssr_enabled = not world_environment.environment.ssr_enabled
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var actor := _actor()
	frame_time_recorder.sample_frame(delta, city_details.call("get_streaming_stats"), actor.global_position, current_car != null)
	var indoors: bool = interiors.call("is_inside")
	if is_instance_valid(nightgrid_fm):
		var interior_id := str(interiors.call("active_site_id")) if indoors else ""
		var interior_kind := ""
		if indoors and str(interiors.call("active_site_group")) == "VENUE":
			interior_kind = str((venue_system.call("venue_by_id", interior_id) as Dictionary).get("kind", ""))
		nightgrid_fm.call("update_listener", actor.global_position, current_car != null, interior_id, interior_kind)
	if is_instance_valid(world_audio):
		var street_position: Vector3 = interiors.get("exterior_position") if indoors else actor.global_position
		var district: String = city_details.call("get_district_at", street_position)
		var foot_speed := Vector2(player.velocity.x, player.velocity.z).length()
		world_audio.call("update_context", actor.global_position, player.global_position,
			current_car == null and current_transit == null, player.is_on_floor(),
			indoors, district, float(day_night.get("hour")), foot_speed)
	if indoors and str(interiors.call("active_site_id")) == "lantern_cup":
		interiors.call("set_mara_focus", player.global_position)
	if not venue_panel.visible:
		# Right stick or mouse may orbit the camera on foot, in vehicles or in transit.
		var right_look: Vector2 = GameInput.look_vector()
		yaw -= right_look.x * stick_sensitivity * delta
		pitch = clampf(pitch + right_look.y * stick_sensitivity * delta * (-1.0 if invert_look_y else 1.0), 0.20, 0.85)
	_focus_update_clock += delta
	if _focus_update_clock >= 0.1:
		_focus_update_clock = 0.0
		if not indoors:
			var traversal_velocity := Vector3.ZERO
			if actor is CharacterBody3D:
				traversal_velocity = (actor as CharacterBody3D).velocity
			city_details.call("request_focus", actor.global_position, traversal_velocity)
		street_lights.call("set_focus", interiors.get("exterior_position") if indoors else actor.global_position)
		venue_system.call("set_focus", actor.global_position)
		civic_services.call("set_focus", actor.global_position)
	_venue_clock_tick += delta
	if _venue_clock_tick >= 0.5:
		_venue_clock_tick = 0.0
		venue_system.call("set_hour", float(day_night.get("hour")))
		civic_services.call("set_hour", float(day_night.get("hour")))
	if venue_panel.visible:
		var menu_position: Vector3 = interiors.call("get_counter_point") if indoors else (
			civic_services.call("position_for", civic_selected_id) if not civic_selected_id.is_empty() else
			venue_system.call("venue_position", venue_selected_id))
		if current_car != null or current_transit != null or menu_position.distance_to(player.global_position) > 7.0:
			_close_venue()
	if current_car == null and current_transit == null:
		player.set("camera_yaw", yaw)
	_update_camera(delta, false)
	_hud_update_clock += delta
	if _hud_update_clock >= 0.1:
		_hud_update_clock = 0.0
		_update_hud()

func _physics_process(delta: float) -> void:
	# Gameplay mission/heat/damage timers are fixed-tick, not render-tick.
	if not is_instance_valid(player):
		return
	var actor := _actor()
	var indoors: bool = interiors.call("is_inside")
	if not indoors and current_transit == null and actor.global_position.distance_to(mission_position) < 5.3:
		_advance_mission()
	if (actor.global_position.y < -15.0 or not indoors and
			(absf(actor.global_position.x) > 390.0 or absf(actor.global_position.z) > 390.0)):
		_respawn()
	heat = maxf(0.0, heat - delta * 0.008)
	police_cooldown -= delta
	if not indoors and heat >= 0.8 and officers.size() < mini(ceili(heat), 3) and police_cooldown <= 0.0:
		_spawn_police()
		police_cooldown = 8.0
	if heat < 0.15 and not officers.is_empty():
		for officer in officers:
			if is_instance_valid(officer):
				officer.queue_free()
		officers.clear()
	for officer in officers:
		if is_instance_valid(officer) and not indoors:
			officer.set("police_target", actor)
			if officer.global_position.distance_to(actor.global_position) < 3.8:
				health -= delta * 7.0
	if health <= 0.0:
		_respawn()
	if notification_time > 0.0:
		notification_time -= delta

func _actor() -> Node3D:
	if current_transit != null:
		return current_transit
	return current_car if current_car != null else player

# The former chase camera always interpolated over the full world distance.
# Interiors are in a dedicated scene at (950, 950); on H exit this exposed the
# empty space between it and the city for many frames. A spatial discontinuity
# now snaps the camera, while regular following is collision-constrained.
func _camera_focus() -> Vector3:
	var actor := _actor()
	return actor.global_position + Vector3.UP * (
		1.65 if current_car != null or current_transit != null else 1.45)

func _camera_goal() -> Vector3:
	var distance := (3.0 if interiors.call("is_inside") else
		(21.0 if transit_kind == "TRAIN" else
		(15.0 if transit_kind == "BUS" else
		(13.0 if current_car != null else 7.5))))
	return _camera_focus() + Vector3(0.0, sin(pitch) * distance,
		cos(pitch) * distance).rotated(Vector3.UP, yaw)

func _camera_clearance(focus: Vector3, target: Vector3) -> Vector3:
	# Physics-backed camera arm. The camera never goes THROUGH a collidable
	# building or a venue wall, even when the player rotates next to it.
	var distance := focus.distance_to(target)
	if distance < 0.001:
		return target
	var ignored: Array[RID] = [player.get_rid()]
	if current_car != null:
		ignored.append(current_car.get_rid())
	if current_transit is CollisionObject3D:
		ignored.append((current_transit as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(focus, target)
	query.exclude = ignored
	query.collision_mask = 1
	query.collide_with_areas = false
	var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if obstruction.is_empty():
		return target
	# Keep the camera in front of the wall; minimum 0.65m from focus.
	var hit: Vector3 = obstruction["position"]
	var safe_distance := maxf(0.65, focus.distance_to(hit) - 0.38)
	return focus + (target - focus).normalized() * minf(distance, safe_distance)

func _update_camera(delta: float, teleport: bool = false) -> void:
	if camera == null or not is_instance_valid(player):
		return
	var focus := _camera_focus()
	var goal := _camera_clearance(focus, _camera_goal())
	var distance_to_goal := camera.global_position.distance_to(goal)
	# Suppress stale camera positions after a save-load or streaming jump
	# even when teleport was triggered through another system.
	if teleport or distance_to_goal > 35.0:
		camera.global_position = goal
	else:
		var smoothed := camera.global_position.lerp(goal, minf(delta * 7.0, 1.0))
		camera.global_position = _camera_clearance(focus, smoothed)
	camera.look_at(focus, Vector3.UP)

func _snap_camera() -> void:
	_update_camera(0.0, true)

func _toggle_car() -> void:
	if venue_panel != null and venue_panel.visible:
		_close_venue()
	if current_transit != null:
		_notify("You're a passenger. Press F to leave at the next stop.")
		return
	if current_car != null:
		if int(current_car.call("speed_kph")) > 15:
			_notify("Slow down before exiting.")
			return
		var exit_position := current_car.global_position + current_car.global_transform.basis.x * 3.3
		exit_position.y = 1.15
		player.global_position = exit_position
		player.velocity = Vector3.ZERO
		player.collision_layer = 1
		player.collision_mask = 1
		player.visible = true
		player.set("driving", false)
		current_car.set("occupied", false)
		current_car = null
		_notify("Back on foot. Find your next pickup.")
		return
	var nearest: CharacterBody3D
	var nearest_distance := 5.0
	for car in cars:
		if not is_instance_valid(car):
			continue
		var dist := player.global_position.distance_to(car.global_position)
		if dist < nearest_distance:
			nearest = car
			nearest_distance = dist
	if nearest == null:
		_notify("No vehicle nearby. Stand beside a parked car and press E.")
		return
	current_car = nearest
	current_car.set("occupied", true)
	player.set("driving", true)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	if not current_car.has_meta("claimed"):
		current_car.set_meta("claimed", true)
		heat = maxf(heat, 1.0)
		_notify("Vehicle acquired. Police dispatch alerted!")
	else:
		_notify("Drive with WASD. Space is the handbrake.")

func _advance_mission() -> void:
	if not carrying:
		carrying = true
		_set_mission_target(DROPOFFS[deliveries % DROPOFFS.size()], true)
		_notify("Package secured! Follow the cyan beacon.")
	else:
		carrying = false
		deliveries += 1
		var payout := 250 + 50 * mini(deliveries - 1, 8)
		cash += payout
		heat += 0.25
		_set_mission_target(PICKUPS[deliveries % PICKUPS.size()], false)
		_notify("Delivery done! +$%d. Next pickup marked in amber." % payout)

func _set_mission_target(pos: Vector3, has_package: bool) -> void:
	mission_position = pos + Vector3.UP * 0.2
	if marker == null:
		return
	marker.global_position = mission_position
	var color := Color("38e5e4") if has_package else Color("ffba56")
	for child in marker.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			if material != null:
				material.albedo_color = Color(color.r, color.g, color.b, 0.45)
				material.emission = color
	marker_light.light_color = color

func _spawn_police() -> void:
	var actor := _actor()
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var away := Vector3(side * CELL, 0.0, CELL * (1.0 if rng.randf() < 0.5 else -1.0))
	var spawn := actor.global_position + away
	spawn.x = roundf(spawn.x / CELL) * CELL
	spawn.z = roundf(spawn.z / CELL) * CELL
	spawn.y = 1.1
	spawn.x = clampf(spawn.x, -CELL * GRID_RADIUS, CELL * GRID_RADIUS)
	spawn.z = clampf(spawn.z, -CELL * GRID_RADIUS, CELL * GRID_RADIUS)
	var officer := _create_car(spawn, Color("192943"), true)
	officer.set("police_target", actor)
	officers.append(officer)
	_notify("POLICE ALERT: A patrol unit is approaching.")

func _respawn() -> void:
	_close_venue()
	if interiors.call("is_inside"):
		interiors.call("leave")
	current_transit = null
	transit_kind = ""
	if current_car != null:
		current_car.set("occupied", false)
		current_car = null
	player.set("driving", false)
	player.collision_layer = 1
	player.collision_mask = 1
	player.visible = true
	player.global_position = PLAYER_START
	player.velocity = Vector3.ZERO
	health = 100.0
	heat = 0.0
	cash = maxi(0, cash - 100)
	for officer in officers:
		if is_instance_valid(officer):
			officer.queue_free()
	officers.clear()
	city_details.call("set_focus", player.global_position)
	_snap_camera()
	_notify("Back at the safehouse. Medical and towing fee: up to $100.")

func _notify(message: String) -> void:
	notification = message
	notification_time = 6.0

func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.77
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.7
	return material

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, collider: bool = false, glow: bool = false, surface_kind: String = "") -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.position = at
	visual.material_override = Materials.surface(surface_kind, color) if not surface_kind.is_empty() else _make_material(color, glow)
	parent.add_child(visual)
	if collider:
		var static_body := StaticBody3D.new()
		static_body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		static_body.add_child(shape)
		parent.add_child(static_body)
	return visual

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101627")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8194c4")
	environment.ambient_light_energy = 0.65
	# Forward+ baseline: physically inspired PBR, contact occlusion, atmospheric depth.
	# Keep SDFGI, volumetric fog and shadow-casting local lights OFF for performance.
	environment.ssr_enabled = true
	environment.ssr_max_steps = 24
	environment.ssr_fade_out = 1.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.46
	environment.glow_hdr_threshold = 1.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.85
	environment.ssao_intensity = 0.95
	environment.ssao_power = 1.25
	environment.ssil_enabled = false
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0085
	environment.fog_light_color = Color("2b354b")
	environment.fog_sky_affect = 0.35
	world_environment.environment = environment
	add_child(world_environment)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -27.0, 0.0)
	sun_light.light_color = Color("ffc39e")
	sun_light.light_energy = 0.7
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 170.0
	add_child(sun_light)
	# The playable foundation stops at the authored perimeter. Beyond this
	# point the quay/water, wooded ridges and industrial yard own the skyline.
	_box(self, Vector3(0.0, -0.58, 0.0), Vector3(490.0, 1.0, 490.0), Color("34434a"), true, false, "CONCRETE")

func _build_city() -> void:
	# The road foundation stays simple; populated streets live in city_details.gd.
	var road := Color("252b35")
	var sidewalk := Color("4d5565")
	for index in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var axis := float(index) * CELL
		_box(self, Vector3(axis, -0.055, 0.0), Vector3(14.0, 0.12, 490.0), road, false, false, "ASPHALT")
		_box(self, Vector3(0.0, -0.05, axis), Vector3(490.0, 0.12, 14.0), road, false, false, "ASPHALT")
	for block_x in range(-GRID_RADIUS, GRID_RADIUS):
		for block_z in range(-GRID_RADIUS, GRID_RADIUS):
			var center := Vector3((float(block_x) + 0.5) * CELL, 0.07, (float(block_z) + 0.5) * CELL)
			_box(self, center, Vector3(42.0, 0.14, 42.0), sidewalk, false, false, "PAVERS")
	city_details = CityDetailsScript.new()
	city_details.name = "CityDetails"
	add_child(city_details)
	city_details.call("set_world_seed", rng.seed)
	city_details.call("set_world_manifest", session.call("get_world_manifest"))
	city_details.call("generate")

func _build_city_perimeter() -> void:
	# Permanent geography is independent of streamed lots and saved seeds.
	city_perimeter = CityPerimeterScript.new()
	city_perimeter.name = "MorrowBayPerimeter"
	add_child(city_perimeter)

func _build_world_systems() -> void:
	# Geography and story anchors are authored; botanical infill is seeded.
	flora = FloraScript.new()
	flora.name = "CityFlora"
	add_child(flora)
	flora.call("set_world_seed", rng.seed)
	flora.call("generate")
	street_lights = NightLightingScript.new()
	street_lights.name = "NightLighting"
	add_child(street_lights)
	wet_streets = WetStreetsScript.new()
	wet_streets.name = "WetStreets"
	add_child(wet_streets)
	hero_intersection = HeroIntersectionScript.new()
	hero_intersection.name = "CentralExchangeHero"
	add_child(hero_intersection)
	# Two photo-scanned material-sorted road meshes at the protected hero junction.
	# Flat visual-only geometry; traffic, original crossing paint and saves stay put.
	central_roadway = CentralRoadScanScript.new()
	central_roadway.name = "CentralExchangeScannedRoadway"
	add_child(central_roadway)
	day_night = DayNightScript.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.call("configure", world_environment, sun_light, city_details, street_lights, hero_intersection)
	venue_system = VenueSystemScript.new()
	venue_system.name = "SocialVenues"
	add_child(venue_system)
	venue_system.call("set_hour", float(day_night.get("hour")))
	civic_services = CivicServicesScript.new()
	civic_services.name = "CivicServices"
	add_child(civic_services)
	civic_services.call("set_hour", float(day_night.get("hour")))
	interiors = InteriorSystemScript.new()
	interiors.name = "Interiors"
	add_child(interiors)

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = PLAYER_START
	var capsule := CollisionShape3D.new()
	var collision := CapsuleShape3D.new()
	collision.radius = 0.45
	collision.height = 1.9
	capsule.shape = collision
	player.add_child(capsule)
	var visual := HumanoidVisualScript.new()
	visual.name = "Visual"
	visual.configure(0, "PLAYER")
	# The avatar's boots meet the physical 1.9-metre capsule footprint.
	visual.position.y = -0.90
	player.add_child(visual)
	add_child(player)

func _create_car(where: Vector3, color: Color, police: bool = false) -> CharacterBody3D:
	var car := CharacterBody3D.new()
	car.name = "PoliceCruiser" if police else "StreetVehicle"
	car.set_script(CarScript)
	car.position = where
	car.set("is_police", police)
	var hitbox := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.35, 1.65, 4.7)
	hitbox.shape = shape
	car.add_child(hitbox)
	# Hero body remains a visual child of the original, save-compatible car.
	# Physics, position, rotation, condition and player ownership do not change.
	var hero := KestrelVisual.new()
	hero.name = "KestrelS6HeroVisual"
	hero.configure(color, police)
	car.add_child(hero)
	add_child(car)
	return car

func _spawn_traffic() -> void:
	var parked := [
		Vector3(5.0, 1.0, 18.0), Vector3(-63.0, 1.0, -28.0),
		Vector3(63.0, 1.0, 33.0), Vector3(121.0, 1.0, 88.0),
		Vector3(-121.0, 1.0, -80.0), Vector3(-5.0, 1.0, 125.0),
		Vector3(63.0, 1.0, -143.0), Vector3(-63.0, 1.0, 139.0),
		Vector3(-237.0, 1.0, -202.0), Vector3(237.0, 1.0, -146.0),
		Vector3(203.0, 1.0, 237.0), Vector3(-146.0, 1.0, 237.0)
	]
	for i in range(parked.size()):
		var car := _create_car(parked[i], VEHICLE_COLORS[i % VEHICLE_COLORS.size()])
		car.rotation.y = PI if i % 2 == 1 else 0.0
		cars.append(car)

func _build_transport() -> void:
	signal_controller = TrafficSignalsScript.new()
	signal_controller.name = "TrafficSignals"
	add_child(signal_controller)
	traffic = TrafficSystemScript.new()
	traffic.name = "SurfaceTraffic"
	add_child(traffic)
	traffic.call("initialize", rng.seed, signal_controller)
	rail = RailSystemScript.new()
	rail.name = "MorrowLine"
	add_child(rail)

func _toggle_transit() -> void:
	if current_car != null:
		_notify("Park and exit your car before boarding transit.")
		return
	if current_transit != null:
		var exit_pos := Vector3.ZERO
		if transit_kind == "BUS":
			if not bool(current_transit.call("is_boardable")):
				_notify("Wait for the bus to stop before alighting.")
				return
			exit_pos = current_transit.call("alight_position")
		else:
			if not bool(rail.call("can_alight")):
				_notify("M-Line is moving. Wait for the next station.")
				return
			exit_pos = rail.call("alight_position")
		_leave_transit(exit_pos)
		return
	if bool(rail.call("boardable_from", player.global_position)):
		_board_transit(rail.get_node("MorrowLineTrain"), "TRAIN")
		_notify("M-Line boarded. F to leave at a station.")
		return
	var bus: CharacterBody3D = traffic.call("get_boardable_bus", player.global_position)
	if bus != null:
		_board_transit(bus, "BUS")
		_notify("City Loop boarded. F to leave at the next stop.")
		return
	_notify("Board with F at a marked bus stop or M-Line elevator when a vehicle is stopped.")

func _board_transit(vehicle: Node3D, kind: String) -> void:
	current_transit = vehicle
	transit_kind = kind
	player.set("driving", true)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO

func _leave_transit(at: Vector3) -> void:
	current_transit = null
	transit_kind = ""
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.collision_layer = 1
	player.collision_mask = 1
	player.visible = true
	player.set("driving", false)
	_notify("Back on the street.")

func _save_game() -> void:
	if bool(session.call("save_snapshot", _capture_snapshot())):
		if game_menu != null:
			game_menu.call("set_has_save", true)
		_notify("Saved slot 1. City seed: %d" % int(session.get("world_seed")))
	else:
		_notify("Save failed. Check user data folder or permissions.")

func _load_game() -> void:
	if game_menu != null and game_menu.call("is_open"):
		game_menu.call("hide_for_game")
	if not bool(session.call("prepare_load")):
		_notify("No valid saved game in slot 1.")
		return
	get_tree().call_deferred("reload_current_scene")

func _new_game() -> void:
	if game_menu != null and game_menu.call("is_open"):
		game_menu.call("hide_for_game")
	session.call("start_new_game")
	get_tree().call_deferred("reload_current_scene")

func _capture_snapshot() -> Dictionary:
	var stored_cars := []
	for car in cars:
		stored_cars.append({
			"position": [car.global_position.x, car.global_position.y, car.global_position.z],
			"yaw": car.rotation.y, "claimed": car.has_meta("claimed"),
			"condition": car.get("condition")
		})
	var aboard_id := ""
	if transit_kind == "BUS" and current_transit != null:
		aboard_id = str(current_transit.get("vehicle_id"))
	return {
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"camera_yaw": yaw, "cash": cash, "health": health, "heat": heat,
		"deliveries": deliveries, "carrying": carrying,
		"hour": day_night.get("hour"), "cars": stored_cars,
		"occupied_car": cars.find(current_car),
		"traffic": traffic.call("snapshot"), "rail": rail.call("snapshot"),
		"signal_elapsed": signal_controller.get("elapsed"),
		"transit_kind": transit_kind, "transit_id": aboard_id,
		"venue_job_active": venue_job_active, "venue_job_completed": venue_job_completed.duplicate(),
		"civic_job_active": civic_job_active, "civic_job_completed": civic_job_completed.duplicate(),
		"civic_intel": civic_intel.duplicate(), "ration_packs": ration_packs,
		"interior": interiors.call("snapshot")
	}

func _apply_snapshot(data: Dictionary) -> void:
	# Geometry is already reconstructed from the saved immutable seed.
	traffic.call("restore", data["traffic"])
	rail.call("restore", data["rail"])
	signal_controller.set("elapsed", fposmod(float(data.get("signal_elapsed", 0.0)), 72.0))
	cash = maxi(0, int(data.get("cash", 0)))
	health = clampf(float(data.get("health", 100.0)), 1.0, 100.0)
	heat = clampf(float(data.get("heat", 0.0)), 0.0, 5.0)
	deliveries = maxi(0, int(data.get("deliveries", 0)))
	carrying = bool(data.get("carrying", false))
	yaw = float(data.get("camera_yaw", 0.0))
	var position_data: Array = data["player_position"]
	player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	var saved_cars: Array = data.get("cars", [])
	for i in range(mini(saved_cars.size(), cars.size())):
		var info: Dictionary = saved_cars[i]
		var c: CharacterBody3D = cars[i]
		var pos: Array = info.get("position", [])
		if pos.size() == 3:
			c.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		c.rotation.y = float(info.get("yaw", c.rotation.y))
		c.set("condition", clampf(float(info.get("condition", 100.0)), 18.0, 100.0))
		if bool(info.get("claimed", false)):
			c.set_meta("claimed", true)
	var selected := int(data.get("occupied_car", -1))
	if selected >= 0 and selected < cars.size():
		current_car = cars[selected]
		current_car.set("occupied", true)
		player.set("driving", true)
		player.visible = false
		player.collision_layer = 0
		player.collision_mask = 0
	else:
		var saved_transit := str(data.get("transit_kind", ""))
		if saved_transit == "BUS":
			var bus: CharacterBody3D = traffic.call("bus_by_id", str(data.get("transit_id", "")))
			if bus != null:
				_board_transit(bus, "BUS")
		elif saved_transit == "TRAIN":
			_board_transit(rail.get_node("MorrowLineTrain"), "TRAIN")
	day_night.call("set_hour", float(data.get("hour", 19.25)))
	venue_system.call("set_hour", float(day_night.get("hour")))
	civic_services.call("set_hour", float(day_night.get("hour")))
	venue_job_active = str(data.get("venue_job_active", ""))
	if not venue_job_active.is_empty() and venue_system.call("job_by_id", venue_job_active).is_empty():
		venue_job_active = ""
	venue_job_completed.clear()
	var saved_jobs = data.get("venue_job_completed", [])
	if saved_jobs is Array:
		for job_id in saved_jobs:
			var valid_id := str(job_id)
			if not venue_system.call("job_by_id", valid_id).is_empty() and not venue_job_completed.has(valid_id):
				venue_job_completed.append(valid_id)
	ration_packs = clampi(int(data.get("ration_packs", 0)), 0, 99)
	civic_job_active = str(data.get("civic_job_active", ""))
	if civic_services.call("order_by_id", civic_job_active).is_empty():
		civic_job_active = ""
	civic_job_completed.clear()
	var saved_civic = data.get("civic_job_completed", [])
	if saved_civic is Array:
		for job_id in saved_civic:
			var checked := str(job_id)
			if not civic_services.call("order_by_id", checked).is_empty() and not civic_job_completed.has(checked):
				civic_job_completed.append(checked)
	civic_intel.clear()
	var saved_intel = data.get("civic_intel", [])
	if saved_intel is Array:
		for site_id in saved_intel:
			var confirmed := str(site_id)
			# Keep civic site intel validated and explicitly allow Mara's
			# original authored venue note (no arbitrary user-provided IDs).
			var is_valid_note: bool = confirmed == "lantern_cup_shift_notes"
			var is_civic_site: bool = not civic_services.call("site_by_id", confirmed).is_empty()
			if (is_civic_site or is_valid_note) and not civic_intel.has(confirmed):
				civic_intel.append(confirmed)
	# Old save slots have no indoor field and continue to open outdoors.
	var restored_room: Dictionary = data.get("interior", {})
	if not restored_room.is_empty() and current_car == null and current_transit == null:
		var group := str(restored_room.get("group", ""))
		var room_id := str(restored_room.get("id", ""))
		var room_site: Dictionary = civic_services.call("site_by_id", room_id) if group == "CIVIC" else venue_system.call("venue_by_id", room_id)
		if interiors.call("restore", restored_room, room_site):
			player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
			if player.global_position.distance_to(interiors.call("get_entry_point")) > 13.0:
				player.global_position = interiors.call("get_entry_point")
			player.velocity = Vector3.ZERO
			city_details.call("set_focus", interiors.get("exterior_position"))
	if not interiors.call("is_inside"):
		city_details.call("set_focus", player.global_position)
	_set_mission_target(DROPOFFS[deliveries % DROPOFFS.size()] if carrying else PICKUPS[deliveries % PICKUPS.size()], carrying)
	_snap_camera()
	_notify("Save loaded. Seed %d; Morrow Bay restored." % int(session.get("world_seed")))

func _toggle_interior() -> void:
	if interiors.call("is_inside"):
		if not interiors.call("exit_reachable", player.global_position):
			_notify("Return to the glowing doorway, then press H to leave.")
			return
		_close_venue()
		var return_position: Vector3 = interiors.call("leave")
		# Rebuild the actual collision district BEFORE returning the player.
		city_details.call("set_focus", return_position)
		player.global_position = return_position
		player.velocity = Vector3.ZERO
		_snap_camera()
		_notify("Back on the street. Your saved city is exactly where you left it.")
		return
	if current_car != null or current_transit != null:
		_notify("Exit your vehicle before entering a building.")
		return
	var venue: Dictionary = venue_system.call("nearest_venue", player.global_position)
	var civic: Dictionary = civic_services.call("nearest_site", player.global_position)
	if venue.is_empty() and civic.is_empty():
		_notify("Approach a marked storefront and press H to enter.")
		return
	var group := "VENUE"
	var site: Dictionary = venue
	var distance := 9999.0
	if not venue.is_empty():
		distance = player.global_position.distance_to(venue_system.call("venue_position", str(venue["id"])))
	if not civic.is_empty():
		var civic_distance: float = player.global_position.distance_to(civic_services.call("position_for", str(civic["id"])))
		if civic_distance < distance:
			group = "CIVIC"
			site = civic
	var old_position := player.global_position
	_close_venue()
	player.global_position = interiors.call("enter", site, group, old_position)
	player.velocity = Vector3.ZERO
	_snap_camera()
	_notify("Inside %s. Approach the service counter with G; H exits at the doorway." % str(site["name"]))

func _toggle_interaction() -> void:
	if venue_panel.visible:
		_close_venue()
		return
	if interiors.call("is_inside"):
		# Mara's collectible, one-time shift note is a real world interaction,
		# available only beside the flagship café booth. Reuse the already
		# persisted civic-intel list; old saves and quest schemas are unchanged.
		var room_detail: Dictionary = interiors.call("inspect_hero_rumor", player.global_position)
		if not room_detail.is_empty():
			var clue_id := str(room_detail["id"])
			if not civic_intel.has(clue_id):
				civic_intel.append(clue_id)
				interiors.call("mara_discovery_reaction")
				_notify("MARA'S SHIFT NOTES: " + str(room_detail["text"]))
			else:
				_notify("You already copied Mara's shift notes to your journal.")
			return
		# Free, authored ambient conversation when standing beside a regular.
		# This occurs after Mara's clue interaction and before generic counters.
		var regular: Dictionary = interiors.call("talk_to_patron", player.global_position, {
			"hour": float(day_night.get("hour")),
			"shift_notes": civic_intel.has("lantern_cup_shift_notes")
		})
		if not regular.is_empty():
			_notify("%s / %s: %s" % [
				str(regular["name"]), str(regular["role"]), str(regular["line"])])
			return
		if not interiors.call("counter_reachable", player.global_position):
			_notify("Walk toward the staffed service counter to interact.")
			return
		if str(interiors.call("active_site_group")) == "CIVIC":
			_toggle_civic()
		else:
			_toggle_venue()
		return
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle before interacting with neighborhood businesses.")
		return
	var shop: Dictionary = venue_system.call("nearest_venue", player.global_position)
	var service: Dictionary = civic_services.call("nearest_site", player.global_position)
	if not service.is_empty():
		var civic_distance: float = civic_services.call("position_for", str(service["id"])).distance_to(player.global_position)
		var shop_distance: float = 9999.0 if shop.is_empty() else venue_system.call("venue_position", str(shop["id"])).distance_to(player.global_position)
		if civic_distance <= shop_distance:
			_toggle_civic()
			return
	_toggle_venue()

func _toggle_civic() -> void:
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle to visit public services.")
		return
	if venue_panel.visible:
		_close_venue()
		return
	var site: Dictionary = civic_services.call("site_by_id", str(interiors.call("active_site_id"))) if interiors.call("is_inside") else civic_services.call("nearest_site", player.global_position)
	if site.is_empty():
		_notify("No public service counter within reach.")
		return
	civic_selected_id = str(site["id"])
	_show_venue_dialogue()
	_update_civic_panel()

func _consume_ration() -> void:
	if current_car != null or current_transit != null:
		_notify("Use a ration pack when safely on foot.")
	elif ration_packs <= 0:
		_notify("No provisions. Visit a grocery store in an outer district.")
	elif health >= 99.9:
		_notify("You're at full health; save your provisions.")
	else:
		ration_packs -= 1
		health = minf(100.0, health + 25.0)
		_notify("Used a supply pack. +25 health (%d remaining)." % ration_packs)

func _civic_service_text(site: Dictionary) -> String:
	match str(site["kind"]):
		"GROCERY":
			return "2 take-away ration packs"
		"CLINIC":
			return "Walk-in medical care (+55 health)"
		"FIRE":
			return "Emergency first aid (+35 health)"
		"CIVIC":
			return "Pay municipal citations (-1.75 heat)"
		"GARAGE":
			return "Restore condition of a parked nearby vehicle"
		"LIBRARY":
			return "Read the community archive (free intel)"
		"UTILITY":
			return "Inspect grid ownership records (free intel)"
		"WAREHOUSE":
			return "Read today's shipping workboard (free)"
	return "Visit"

func _update_civic_panel() -> void:
	if civic_selected_id.is_empty() or venue_label == null:
		return
	# This fourth menu action must never leak into another venue or service.
	if venue_talk_button != null:
		venue_talk_button.visible = false
	var site: Dictionary = civic_services.call("site_by_id", civic_selected_id)
	if site.is_empty():
		_close_venue()
		return
	var opened: bool = civic_services.call("is_open", civic_selected_id)
	var title := "%s | %s | %s\n%s: %s\n" % [
		str(site["name"]), str(site["kind"]), "OPEN" if opened else "CLOSED",
		str(site["host"]), str(site["flavor"])]
	if opened:
		var item := _civic_service_text(site)
		title += "[1 / A] %s ($%d)\n" % [item, int(site["price"])]
		if civic_job_active.is_empty():
			var offer: Dictionary = civic_services.call("order_from", civic_selected_id)
			if not offer.is_empty() and not civic_job_completed.has(str(offer["id"])):
				title += "[2 / X] WORK ORDER: %s (+$%d)\n" % [str(offer["title"]), int(offer["reward"])]
		else:
			var job: Dictionary = civic_services.call("order_by_id", civic_job_active)
			if not job.is_empty() and str(job["to"]) == civic_selected_id:
				title += "[2 / X] DELIVER: %s (+$%d)\n" % [str(job["title"]), int(job["reward"])]
	else:
		title += "Return during staffed hours.\n"
	title += "[G / B] Close  |  CASH $%d  |  PROVISIONS %d" % [cash, ration_packs]
	venue_label.text = title
	if venue_service_button != null:
		venue_service_button.disabled = not opened
		venue_service_button.text = "1 / A  •  SERVICE"
	if venue_job_button != null:
		var offered: Dictionary = civic_services.call("order_from", civic_selected_id) if civic_job_active.is_empty() else civic_services.call("order_by_id", civic_job_active)
		var available := not offered.is_empty() and (
			(not civic_job_active.is_empty() and str(offered["to"]) == civic_selected_id) or
			(civic_job_active.is_empty() and not civic_job_completed.has(str(offered["id"]))))
		venue_job_button.disabled = not opened or not available
		venue_job_button.text = "2 / X  •  WORK ORDER"

func _civic_action(option: int) -> void:
	if not venue_panel.visible or civic_selected_id.is_empty():
		return
	var site: Dictionary = civic_services.call("site_by_id", civic_selected_id)
	if site.is_empty() or not civic_services.call("is_open", civic_selected_id):
		_notify("This public service is not open right now.")
		return
	var kind: String = site["kind"]
	if option == 1:
		var price := int(site["price"])
		var purchase := true
		var selected_car: CharacterBody3D
		match kind:
			"GROCERY":
				if ration_packs > 97:
					_notify("Supply pack inventory is full.")
					return
			"CLINIC", "FIRE":
				if health >= 99.9:
					_notify("No first aid needed. Save your money.")
					return
			"CIVIC":
				if heat <= 0.01:
					_notify("No citations are currently outstanding.")
					return
			"GARAGE":
				var nearest := 18.0
				for car in cars:
					var distance := car.global_position.distance_to(player.global_position)
					if distance < nearest and float(car.get("condition")) < 99.9:
						selected_car = car
						nearest = distance
				if selected_car == null:
					_notify("Park a damaged vehicle near the garage counter.")
					return
			"LIBRARY", "UTILITY":
				purchase = false
			"WAREHOUSE":
				_notify("The warehouse shift board lists work under option [2].")
				return
		if purchase:
			if cash < price:
				_notify("Not enough cash; visit a courier pickup or complete a work order.")
				return
			cash -= price
		match kind:
			"GROCERY":
				ration_packs += 2
				_notify("Bought two provisions. Press R on foot to use one.")
			"CLINIC":
				health = minf(100.0, health + 55.0)
				_notify("Clinic treatment complete. +55 health.")
			"FIRE":
				health = minf(100.0, health + 35.0)
				_notify("Emergency first aid complete. +35 health.")
			"CIVIC":
				heat = maxf(0.0, heat - 1.75)
				_notify("Municipal citation settled. Police heat reduced.")
			"GARAGE":
				selected_car.call("repair")
				_notify("Vehicle repaired. Roadworthiness restored.")
			"LIBRARY", "UTILITY":
				if not civic_intel.has(civic_selected_id):
					civic_intel.append(civic_selected_id)
					_notify("ARCHIVE DISCOVERY: %s" % str(site["flavor"]))
				else:
					_notify("Already examined this local archive.")
	elif option == 2:
		if civic_job_active.is_empty():
			var order: Dictionary = civic_services.call("order_from", civic_selected_id)
			if order.is_empty() or civic_job_completed.has(str(order.get("id", ""))):
				_notify("No new delivery contract here.")
				return
			civic_job_active = str(order["id"])
			_notify("WORK ORDER: %s — %s" % [str(order["title"]), str(order["brief"])])
		else:
			var active: Dictionary = civic_services.call("order_by_id", civic_job_active)
			if active.is_empty():
				civic_job_active = ""
				return
			if str(active["to"]) != civic_selected_id:
				var destination: Dictionary = civic_services.call("site_by_id", str(active["to"]))
				_notify("Work in progress. Destination: %s" % str(destination["name"]))
				return
			cash += int(active["reward"])
			civic_job_completed.append(civic_job_active)
			civic_job_active = ""
			_notify("WORK ORDER COMPLETE +$%d: %s" % [int(active["reward"]), str(active["ending"])])
	_update_civic_panel()

func _civic_job_text() -> String:
	if civic_job_active.is_empty():
		return "CITY SERVICES: %d provisions | %d archive clues" % [ration_packs, civic_intel.size()]
	var order: Dictionary = civic_services.call("order_by_id", civic_job_active)
	if order.is_empty():
		return ""
	var point: Vector3 = civic_services.call("position_for", str(order["to"]))
	var place: Dictionary = civic_services.call("site_by_id", str(order["to"]))
	return "WORK ORDER: %s / %s (%dm)" % [str(order["title"]), str(place["name"]), roundi((interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position).distance_to(point))]

func _civic_job_target() -> Vector3:
	var order: Dictionary = civic_services.call("order_by_id", civic_job_active)
	return civic_services.call("position_for", str(order["to"])) if not order.is_empty() else Vector3.ZERO

func _toggle_venue() -> void:
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle before visiting a venue.")
		return
	if venue_panel.visible:
		_close_venue()
		return
	var venue: Dictionary = venue_system.call("venue_by_id", str(interiors.call("active_site_id"))) if interiors.call("is_inside") else venue_system.call("nearest_venue", player.global_position)
	if venue.is_empty():
		_notify("Find a glowing venue frontage, then press G to visit.")
		return
	venue_selected_id = str(venue["id"])
	mara_dialogue_line = ""
	_show_venue_dialogue()
	_update_venue_panel()

func _show_venue_dialogue() -> void:
	if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
		interiors.call("set_mara_attention", true)
	venue_panel.visible = true
	player.set("input_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if venue_service_button != null:
		venue_service_button.call_deferred("grab_focus")

func _close_venue() -> void:
	if interiors != null:
		interiors.call("set_mara_attention", false)
	mara_dialogue_line = ""
	if venue_talk_button != null:
		venue_talk_button.visible = false
	venue_selected_id = ""
	civic_selected_id = ""
	if venue_panel != null:
		venue_panel.visible = false
	if is_instance_valid(player):
		player.set("input_blocked", false)
	if game_menu == null or not game_menu.call("is_open"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _update_venue_panel() -> void:
	if not civic_selected_id.is_empty():
		_update_civic_panel()
		return
	if venue_label == null or venue_selected_id.is_empty():
		return
	var venue: Dictionary = venue_system.call("venue_by_id", venue_selected_id)
	if venue.is_empty():
		_close_venue()
		return
	var open_now: bool = venue_system.call("is_open", venue_selected_id)
	var status := "OPEN" if open_now else "CLOSED"
	var hours_text := "%02d:00-%02d:00" % [int(venue["opens"]), int(venue["closes"])]
	var body := "%s | %s | %s (%s)\n%s: %s\n" % [
		str(venue["name"]), str(venue["kind"]), status, hours_text,
		str(venue["host"]), str(venue["flavor"])]
	var is_mara := venue_selected_id == "lantern_cup" and bool(interiors.call("is_inside"))
	if is_mara:
		var introduction := str(interiors.call("mara_greeting", _mara_context()))
		body += "\n" + (mara_dialogue_line if not mara_dialogue_line.is_empty() else introduction)
		body += "\n[3 / Y] TALK TO MARA"
	if open_now:
		body += "[1 / A] %s  $%d   " % [str(venue["item"]), int(venue["price"])]
		if venue_job_active.is_empty():
			var offer: Dictionary = venue_system.call("job_from", venue_selected_id)
			if not offer.is_empty() and not venue_job_completed.has(str(offer["id"])):
				body += "\n[2 / X] SIDE JOB: %s (+$%d)" % [str(offer["title"]), int(offer["reward"])]
		else:
			var active: Dictionary = venue_system.call("job_by_id", venue_job_active)
			if not active.is_empty() and str(active["to"]) == venue_selected_id:
				body += "\n[2 / X] DELIVER: %s (+$%d)" % [str(active["title"]), int(active["reward"])]
	else:
		body += "Come back during business hours."
	body += "\n[G / B] Close   |   CASH $%d" % cash
	venue_label.text = body
	if venue_service_button != null:
		venue_service_button.disabled = not open_now
		venue_service_button.text = "1 / A  •  SERVICE"
	if venue_job_button != null:
		var offered: Dictionary = venue_system.call("job_from", venue_selected_id) if venue_job_active.is_empty() else venue_system.call("job_by_id", venue_job_active)
		var available := not offered.is_empty() and (
			(not venue_job_active.is_empty() and str(offered["to"]) == venue_selected_id) or
			(venue_job_active.is_empty() and not venue_job_completed.has(str(offered["id"]))))
		venue_job_button.disabled = not open_now or not available
		venue_job_button.text = "2 / X  •  SIDE JOB"
	if venue_talk_button != null:
		venue_talk_button.visible = is_mara
		venue_talk_button.disabled = not is_mara

func _mara_context() -> Dictionary:
	return {
		"hour": float(day_night.get("hour")),
		"health": health, "heat": heat,
		"shift_notes": civic_intel.has("lantern_cup_shift_notes"),
		"job": venue_job_active
	}

func _venue_action(option: int) -> void:
	if not civic_selected_id.is_empty():
		_civic_action(option)
		return
	if venue_panel == null or not venue_panel.visible or venue_selected_id.is_empty():
		return
	var venue: Dictionary = venue_system.call("venue_by_id", venue_selected_id)
	if venue.is_empty():
		_close_venue()
		return
	# Dialogue is no-cost and remains accessible even near closing time.
	if option == 3:
		if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
			var response: Dictionary = interiors.call("mara_talk", _mara_context())
			if not response.is_empty():
				mara_dialogue_line = str(response["line"])
				_notify("MARA / " + str(response["topic"]))
			_update_venue_panel()
		return
	if not bool(venue_system.call("is_open", venue_selected_id)):
		_notify("%s is closed until %02d:00." % [str(venue["name"]), int(venue["opens"])])
		_update_venue_panel()
		return
	if option == 1:
		var price := int(venue["price"])
		var service: Dictionary = venue_system.call("service_effect", str(venue["kind"]))
		var healing := float(service.get("heal", 0.0))
		var cover := float(service.get("heat", 0.0))
		if healing > 0.0 and health >= 99.9:
			_notify("You're already feeling rested. Save your cash.")
			return
		if cover > 0.0 and heat < 0.01:
			_notify("No police attention to shake. Enjoy the atmosphere.")
			return
		if cash < price:
			_notify("Not enough cash for %s. Try a courier or side job." % str(venue["item"]))
			return
		cash -= price
		health = minf(100.0, health + healing)
		heat = maxf(0.0, heat - cover)
		if venue_selected_id == "lantern_cup" and interiors.call("is_inside"):
			interiors.call("mara_purchase_reaction")
			mara_dialogue_line = "Mara: That's freshly pulled. Stay a while; the city's not going anywhere."
		_notify("%s: %s. %s" % [str(venue["name"]), str(venue["item"]),
			"Recovered strength." if healing > 0.0 else "You blend into the crowd."])
	elif option == 2:
		if venue_job_active.is_empty():
			var job: Dictionary = venue_system.call("job_from", venue_selected_id)
			if job.is_empty() or venue_job_completed.has(str(job.get("id", ""))):
				_notify("No new work from this contact.")
				return
			venue_job_active = str(job["id"])
			_notify("NEW SIDE JOB: %s — %s" % [str(job["title"]), str(job["brief"])])
		else:
			var contract: Dictionary = venue_system.call("job_by_id", venue_job_active)
			if contract.is_empty():
				venue_job_active = ""
				return
			if str(contract["to"]) != venue_selected_id:
				_notify("Job active: %s. Destination: %s." % [
					str(contract["title"]),
					str(venue_system.call("venue_by_id", str(contract["to"]))["name"])])
				return
			cash += int(contract["reward"])
			venue_job_completed.append(venue_job_active)
			venue_job_active = ""
			_notify("SIDE JOB COMPLETE +$%d: %s" % [int(contract["reward"]), str(contract["ending"])])
	_update_venue_panel()

func _venue_job_text() -> String:
	if venue_job_active.is_empty():
		return "SIDE JOB: Explore social hubs for local work."
	var job: Dictionary = venue_system.call("job_by_id", venue_job_active)
	if job.is_empty():
		return ""
	var venue: Dictionary = venue_system.call("venue_by_id", str(job["to"]))
	var dist := roundi((interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position).distance_to(venue_system.call("venue_position", str(job["to"]))))
	return "SIDE JOB: %s / %s (%dm)" % [str(job["title"]), str(venue["name"]), dist]

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 68.0
	camera.near = 0.08
	camera.far = 720.0
	camera.position = PLAYER_START + Vector3(0.0, 5.0, 8.0)
	add_child(camera)

func _create_marker() -> void:
	marker = Node3D.new()
	marker.name = "DeliveryBeacon"
	var disk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.7
	cylinder.bottom_radius = 2.7
	cylinder.height = 0.13
	disk.mesh = cylinder
	disk.position.y = 0.10
	var disk_material := _make_material(Color("ffba56"), true)
	disk_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disk_material.albedo_color.a = 0.47
	disk.material_override = disk_material
	marker.add_child(disk)
	var pillar := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.3
	beam.bottom_radius = 0.3
	beam.height = 15.0
	pillar.mesh = beam
	pillar.position.y = 7.5
	var pillar_material := _make_material(Color("ffba56"), true)
	pillar_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_material.albedo_color.a = 0.42
	pillar.material_override = pillar_material
	marker.add_child(pillar)
	marker_light = OmniLight3D.new()
	marker_light.position.y = 3.0
	marker_light.light_energy = 1.8
	marker_light.omni_range = 10.0
	marker.add_child(marker_light)
	add_child(marker)

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "HUD"
	add_child(ui)
	var backing := PanelContainer.new()
	backing.position = Vector2(18.0, 18.0)
	backing.custom_minimum_size = Vector2(480.0, 205.0)
	ui.add_child(backing)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 17)
	hud_label.add_theme_color_override("font_color", Color("d7eaf6"))
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	backing.add_child(hud_label)
	minimap = Control.new()
	minimap.name = "Minimap"
	minimap.set_script(MinimapScript)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -205.0
	minimap.offset_right = -18.0
	minimap.offset_top = 18.0
	minimap.offset_bottom = 205.0
	minimap.set("world_node", self)
	ui.add_child(minimap)
	performance_label = Label.new()
	performance_label.name = "PerformanceOverlay"
	performance_label.visible = false
	performance_label.anchor_top = 1.0
	performance_label.anchor_bottom = 1.0
	performance_label.offset_left = 18.0
	performance_label.offset_right = 1160.0
	performance_label.offset_top = -68.0
	performance_label.offset_bottom = -18.0
	performance_label.add_theme_font_size_override("font_size", 15)
	performance_label.add_theme_color_override("font_color", Color("b5eae4"))
	ui.add_child(performance_label)
	venue_panel = PanelContainer.new()
	venue_panel.name = "VenueDialogue"
	venue_panel.position = Vector2(18.0, 262.0)
	venue_panel.custom_minimum_size = Vector2(630.0, 218.0)
	venue_panel.visible = false
	ui.add_child(venue_panel)
	venue_label = Label.new()
	venue_label.add_theme_font_size_override("font_size", 18)
	venue_label.add_theme_color_override("font_color", Color("eadcc9"))
	venue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dialogue_layout := VBoxContainer.new()
	dialogue_layout.add_theme_constant_override("separation", 7)
	venue_panel.add_child(dialogue_layout)
	dialogue_layout.add_child(venue_label)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 7)
	dialogue_layout.add_child(action_row)
	venue_service_button = Button.new()
	venue_service_button.name = "ServiceAction"
	venue_service_button.text = "1 / A  •  SERVICE"
	venue_service_button.focus_mode = Control.FOCUS_ALL
	venue_service_button.pressed.connect(func() -> void: _venue_action(1))
	action_row.add_child(venue_service_button)
	venue_job_button = Button.new()
	venue_job_button.name = "JobAction"
	venue_job_button.text = "2 / X  •  CONTRACT"
	venue_job_button.focus_mode = Control.FOCUS_ALL
	venue_job_button.pressed.connect(func() -> void: _venue_action(2))
	action_row.add_child(venue_job_button)
	venue_talk_button = Button.new()
	venue_talk_button.name = "TalkToMara"
	venue_talk_button.text = "3 / Y  •  TALK"
	venue_talk_button.focus_mode = Control.FOCUS_ALL
	venue_talk_button.visible = false
	venue_talk_button.pressed.connect(func() -> void: _venue_action(3))
	action_row.add_child(venue_talk_button)
	venue_close_button = Button.new()
	venue_close_button.name = "CloseDialogue"
	venue_close_button.text = "G / B  •  BACK"
	venue_close_button.focus_mode = Control.FOCUS_ALL
	venue_close_button.pressed.connect(func() -> void: _close_venue())
	action_row.add_child(venue_close_button)

func _update_hud() -> void:
	var outdoors: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else _actor().global_position
	var district: String = city_details.call("get_district_at", outdoors)
	var landmark: String = city_details.call("get_nearby_landmark", outdoors)
	var local_name := district if landmark.is_empty() else "%s / %s" % [district, landmark]
	var clock: String = day_night.call("clock_string")
	var vehicle_text := "ON FOOT"
	if current_car != null:
		vehicle_text = "DRIVING • %d km/h" % int(current_car.call("speed_kph"))
	elif current_transit != null:
		vehicle_text = "M-LINE RIDER" if transit_kind == "TRAIN" else "CITY LOOP RIDER"
	var wanted_text := "-" if heat < 0.15 else "★".repeat(maxi(1, ceili(heat)))
	var mission := "DELIVER PACKAGE" if carrying else "PICK UP PACKAGE"
	var distance := roundi(outdoors.distance_to(mission_position))
	var message := notification if notification_time > 0.0 else ""
	if performance_overlay:
		var fps := maxi(Engine.get_frames_per_second(), 1)
		var stream: Dictionary = city_details.call("get_streaming_stats")
		var indoor_count := 1 if interiors.call("is_inside") else 0
		var metrics: Dictionary = frame_time_recorder.get_frame_metrics()
		var capture_status := "REC %d" % frame_time_recorder.captured_frames() if frame_time_recorder.recording else "F8 RECORD"
		performance_label.text = "RTX 3060 target 1080p/60 | %d FPS | %.1f ms avg | p95 %.1f | p99 %.1f | 1%% low %.0f FPS | >33ms %d" % [
			fps, float(metrics["avg_ms"]), float(metrics["p95_ms"]), float(metrics["p99_ms"]),
			float(metrics["low_1pct_fps"]), int(metrics["hitches"])]
		performance_label.text += "\n%d/%d blocks | %d shells | room %d | queue %d | last build %.1f ms | peak %.1f ms | %s" % [
			int(stream["loaded_blocks"]), int(stream["total_blocks"]), int(stream["loaded_buildings"]), indoor_count,
			int(stream.get("pending_blocks", 0)), float(stream.get("last_build_usec", 0)) / 1000.0,
			float(stream.get("peak_build_usec", 0)) / 1000.0, capture_status]
	var control_help := "WASD Move | Mouse Look | E Car | F Transit | H Enter | G Interact | Esc Pause | M Map | Tab Journal"
	if gamepad_active:
		control_help = "PAD: LS Move / Steer • RS Look • A Jump/Service • X Interact/Contract • Y Car • LB Door • RB Transit • Start Pause • View Map"
	hud_label.text = "NIGHTGRID / AFTERHOURS    MORROW BAY\n%s | %s\n$%d | HEALTH %d | HEAT %s\n%s | DELIVERIES %d\nOBJECTIVE: %s (%dm)\n%s\n\n%s" % [local_name, clock, cash, ceili(health), wanted_text, vehicle_text, deliveries, mission, distance, message, control_help]
	hud_label.text += "\n" + _venue_job_text() + "\n" + _civic_job_text()
	if current_car != null and is_instance_valid(nightgrid_fm):
		hud_label.text += "\n" + str(nightgrid_fm.call("get_now_playing")) + "  [B] ON/OFF  [N] NEXT"
	if interiors.call("is_inside"):
		var site_id := str(interiors.call("active_site_id"))
		var room_site: Dictionary = civic_services.call("site_by_id", site_id) if str(interiors.call("active_site_group")) == "CIVIC" else venue_system.call("venue_by_id", site_id)
		hud_label.text += "\nINSIDE: %s | %s" % [str(room_site.get("name", site_id)), "H EXIT" if interiors.call("exit_reachable", player.global_position) else "Return to front door"]
		if interiors.call("counter_reachable", player.global_position):
			hud_label.text += "\n[G] Service counter"
		if site_id == "lantern_cup":
			hud_label.text += "\nMARA: counter [G], talk [3/Y] in dialogue"
			var local_regular: Dictionary = interiors.call("patron_near", player.global_position)
			if not local_regular.is_empty():
				hud_label.text += "\n[G] Chat with %s (%s)" % [
					str(local_regular["name"]), str(local_regular["role"])]
		_update_venue_panel()
		return
	if current_car == null and current_transit == null:
		var near: Dictionary = venue_system.call("nearest_venue", player.global_position)
		if not near.is_empty():
			var accessible := "OPEN" if venue_system.call("is_open", str(near["id"])) else "CLOSED"
			hud_label.text += "\n[G] %s (%s)" % [str(near["name"]), accessible]
			hud_label.text += "\n[H] Enter %s" % str(near["name"])
		var nearby_service: Dictionary = civic_services.call("nearest_site", player.global_position)
		if not nearby_service.is_empty():
			var availability := "OPEN" if civic_services.call("is_open", str(nearby_service["id"])) else "CLOSED"
			hud_label.text += "\n[G] %s (%s)" % [str(nearby_service["name"]), availability]
			hud_label.text += "\n[H] Enter %s" % str(nearby_service["name"])
	if venue_panel.visible:
		_update_venue_panel()

func _venue_job_target() -> Vector3:
	if venue_job_active.is_empty():
		return Vector3.ZERO
	var job: Dictionary = venue_system.call("job_by_id", venue_job_active)
	if job.is_empty():
		return Vector3.ZERO
	return venue_system.call("venue_position", str(job["to"]))

func get_map_state() -> Dictionary:
	var car_positions: Array[Vector2] = []
	for officer in officers:
		if is_instance_valid(officer):
			car_positions.append(Vector2(officer.global_position.x, officer.global_position.z))
	var actor := _actor()
	var map_actor: Vector3 = interiors.get("exterior_position") if interiors.call("is_inside") else actor.global_position
	var quest: Vector3 = _venue_job_target()
	return {
		"player": Vector2(map_actor.x, map_actor.z),
		"mission": Vector2(mission_position.x, mission_position.z),
		"officers": car_positions,
		"carrying": carrying,
		"side_quest": Vector2(quest.x, quest.z),
		"side_quest_active": not venue_job_active.is_empty(),
		"venues": venue_system.call("get_map_pins"),
		"services": civic_services.call("get_map_pins"),
		"bus_stops": traffic.call("get_map_stops"),
		"rail_stations": rail.call("get_map_stations"),
		"indoors": interiors.call("is_inside"),
		"civic_quest_active": not civic_job_active.is_empty(),
		"civic_quest": Vector2(_civic_job_target().x, _civic_job_target().z)
	}
