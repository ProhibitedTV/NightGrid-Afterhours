extends Node3D
## NIGHTGRID: AFTERHOURS — a generated 3D city with an original courier/crime loop.

const PlayerScript = preload("res://scripts/player.gd")
const CarScript = preload("res://scripts/car.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityDetailsScript = preload("res://scripts/city_details.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const FloraScript = preload("res://scripts/flora.gd")
const Materials = preload("res://scripts/material_library.gd")
const NightLightingScript = preload("res://scripts/night_lighting.gd")
const WetStreetsScript = preload("res://scripts/wet_streets.gd")
const TrafficSignalsScript = preload("res://scripts/traffic_signals.gd")
const TrafficSystemScript = preload("res://scripts/traffic_system.gd")
const RailSystemScript = preload("res://scripts/rail_system.gd")
const VenueSystemScript = preload("res://scripts/venue_system.gd")
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
var flora: Node3D
var day_night: Node
var street_lights: Node3D
var wet_streets: Node3D
var signal_controller: Node3D
var traffic: Node3D
var rail: Node3D
var venue_system: Node3D
var venue_panel: PanelContainer
var venue_label: Label
var venue_selected_id := ""
var venue_job_active := ""
var venue_job_completed: Array[String] = []
var _venue_clock_tick := 0.0
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
	session = get_node("/root/GameSession")
	rng.seed = int(session.get("world_seed"))
	_build_environment()
	_build_city()
	_build_world_systems()
	_create_player()
	_spawn_traffic()
	_build_transport()
	_create_camera()
	_create_marker()
	_build_hud()
	var restore: Dictionary = session.call("take_pending_restore")
	if restore.is_empty():
		_set_mission_target(PICKUPS[0], false)
	else:
		_apply_snapshot(restore)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0032
		pitch = clampf(pitch + event.relative.y * 0.002, 0.20, 0.85)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if venue_panel != null and venue_panel.visible:
					_close_venue()
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_E:
				_toggle_car()
			KEY_F:
				_toggle_transit()
			KEY_G:
				_toggle_venue()
			KEY_1:
				_venue_action(1)
			KEY_2:
				_venue_action(2)
			KEY_F5:
				_save_game()
			KEY_F6:
				_new_game()
			KEY_F9:
				_load_game()
			KEY_T:
				day_night.call("advance_hour", 1.0)
			KEY_Y:
				day_night.call("toggle_pause")
			KEY_F3:
				performance_overlay = not performance_overlay
				performance_label.visible = performance_overlay
			KEY_F4:
				world_environment.environment.ssr_enabled = not world_environment.environment.ssr_enabled

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var actor := _actor()
	street_lights.call("set_focus", actor.global_position)
	venue_system.call("set_focus", actor.global_position)
	_venue_clock_tick += delta
	if _venue_clock_tick >= 0.5:
		_venue_clock_tick = 0.0
		venue_system.call("set_hour", float(day_night.get("hour")))
	if venue_panel.visible and (current_car != null or current_transit != null or
			venue_system.call("venue_position", venue_selected_id).distance_to(player.global_position) > 7.0):
		_close_venue()
	if current_car == null and current_transit == null:
		player.set("camera_yaw", yaw)
	var focus := actor.global_position + Vector3.UP * (1.65 if current_car != null or current_transit != null else 1.45)
	var camera_distance := 21.0 if transit_kind == "TRAIN" else (15.0 if transit_kind == "BUS" else (13.0 if current_car != null else 7.5))
	var camera_offset := Vector3(0.0, sin(pitch) * camera_distance, cos(pitch) * camera_distance).rotated(Vector3.UP, yaw)
	camera.global_position = camera.global_position.lerp(focus + camera_offset, minf(delta * 7.0, 1.0))
	camera.look_at(focus, Vector3.UP)
	if current_transit == null and actor.global_position.distance_to(mission_position) < 5.3:
		_advance_mission()
	if actor.global_position.y < -15.0 or absf(actor.global_position.x) > 390.0 or absf(actor.global_position.z) > 390.0:
		_respawn()
	heat = maxf(0.0, heat - delta * 0.008)
	police_cooldown -= delta
	if heat >= 0.8 and officers.size() < mini(ceili(heat), 3) and police_cooldown <= 0.0:
		_spawn_police()
		police_cooldown = 8.0
	if heat < 0.15 and not officers.is_empty():
		for officer in officers:
			if is_instance_valid(officer):
				officer.queue_free()
		officers.clear()
	for officer in officers:
		if is_instance_valid(officer):
			officer.set("police_target", actor)
			if officer.global_position.distance_to(actor.global_position) < 3.8:
				health -= delta * 7.0
	if health <= 0.0:
		_respawn()
	if notification_time > 0.0:
		notification_time -= delta
	_update_hud()

func _actor() -> Node3D:
	if current_transit != null:
		return current_transit
	return current_car if current_car != null else player

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
	# RTX 3060 baseline: Forward+ SSR on selected wet materials, bloom for emissive lights.
	# No SDFGI, volumetric fog, ray tracing, or shadow-casting local lights.
	environment.ssr_enabled = true
	environment.ssr_max_steps = 24
	environment.ssr_fade_out = 1.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.58
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	world_environment.environment = environment
	add_child(world_environment)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -27.0, 0.0)
	sun_light.light_color = Color("ffc39e")
	sun_light.light_energy = 0.7
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 170.0
	add_child(sun_light)
	_box(self, Vector3(0.0, -0.58, 0.0), Vector3(850.0, 1.0, 850.0), Color("34434a"), true, false, "CONCRETE")

func _build_city() -> void:
	# The road foundation stays simple; populated streets live in city_details.gd.
	var road := Color("252b35")
	var sidewalk := Color("4d5565")
	for index in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var axis := float(index) * CELL
		_box(self, Vector3(axis, -0.055, 0.0), Vector3(14.0, 0.12, 520.0), road, false, false, "ASPHALT")
		_box(self, Vector3(0.0, -0.05, axis), Vector3(520.0, 0.12, 14.0), road, false, false, "ASPHALT")
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
	day_night = DayNightScript.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.call("configure", world_environment, sun_light, city_details, street_lights)
	venue_system = VenueSystemScript.new()
	venue_system.name = "SocialVenues"
	add_child(venue_system)
	venue_system.call("set_hour", float(day_night.get("hour")))

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
	var visual := Node3D.new()
	visual.name = "Visual"
	player.add_child(visual)
	_box(visual, Vector3(0.0, -0.05, 0.0), Vector3(0.85, 1.28, 0.5), Color("293544"))
	_box(visual, Vector3(0.0, 0.8, -0.05), Vector3(0.62, 0.56, 0.58), Color("dfae8d"))
	_box(visual, Vector3(0.0, 0.13, -0.32), Vector3(0.6, 0.18, 0.1), Color("38e5e4"), false, true)
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
	_box(car, Vector3.ZERO, Vector3(2.25, 0.85, 4.65), color)
	_box(car, Vector3(0.0, 0.7, -0.32), Vector3(1.76, 0.76, 2.4), Color("152230"))
	for lamp_x in [-0.7, 0.7]:
		_box(car, Vector3(lamp_x, -0.06, -2.35), Vector3(0.42, 0.24, 0.14), Color("ffedbc"), false, true)
		_box(car, Vector3(lamp_x, -0.04, 2.36), Vector3(0.48, 0.22, 0.14), Color("ec375b"), false, true)
	for axle_z in [-1.45, 1.45]:
		for wheel_x in [-1.19, 1.19]:
			_box(car, Vector3(wheel_x, -0.41, axle_z), Vector3(0.29, 0.66, 0.85), Color("12151c"))
	if police:
		_box(car, Vector3(-0.45, 1.14, -0.25), Vector3(0.7, 0.2, 0.3), Color("e93663"), false, true)
		_box(car, Vector3(0.45, 1.14, -0.25), Vector3(0.7, 0.2, 0.3), Color("3d7dff"), false, true)
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
		_notify("Saved slot 1. City seed: %d" % int(session.get("world_seed")))
	else:
		_notify("Save failed. Check user data folder or permissions.")

func _load_game() -> void:
	if not bool(session.call("prepare_load")):
		_notify("No valid saved game in slot 1.")
		return
	get_tree().call_deferred("reload_current_scene")

func _new_game() -> void:
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
		"venue_job_active": venue_job_active, "venue_job_completed": venue_job_completed.duplicate()
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
	_set_mission_target(DROPOFFS[deliveries % DROPOFFS.size()] if carrying else PICKUPS[deliveries % PICKUPS.size()], carrying)
	_notify("Save loaded. Seed %d; Morrow Bay restored." % int(session.get("world_seed")))

func _toggle_venue() -> void:
	if current_car != null or current_transit != null:
		_notify("Get out of the vehicle before visiting a venue.")
		return
	if venue_panel.visible:
		_close_venue()
		return
	var venue: Dictionary = venue_system.call("nearest_venue", player.global_position)
	if venue.is_empty():
		_notify("Find a glowing venue frontage, then press G to visit.")
		return
	venue_selected_id = str(venue["id"])
	venue_panel.visible = true
	_update_venue_panel()

func _close_venue() -> void:
	venue_selected_id = ""
	if venue_panel != null:
		venue_panel.visible = false

func _update_venue_panel() -> void:
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
	if open_now:
		body += "[1] %s  $%d   " % [str(venue["item"]), int(venue["price"])]
		if venue_job_active.is_empty():
			var offer: Dictionary = venue_system.call("job_from", venue_selected_id)
			if not offer.is_empty() and not venue_job_completed.has(str(offer["id"])):
				body += "\n[2] SIDE JOB: %s (+$%d)" % [str(offer["title"]), int(offer["reward"])]
		else:
			var active: Dictionary = venue_system.call("job_by_id", venue_job_active)
			if not active.is_empty() and str(active["to"]) == venue_selected_id:
				body += "\n[2] DELIVER: %s (+$%d)" % [str(active["title"]), int(active["reward"])]
	else:
		body += "Come back during business hours."
	body += "\n[G] Close   |   CASH $%d" % cash
	venue_label.text = body

func _venue_action(option: int) -> void:
	if venue_panel == null or not venue_panel.visible or venue_selected_id.is_empty():
		return
	var venue: Dictionary = venue_system.call("venue_by_id", venue_selected_id)
	if venue.is_empty():
		_close_venue()
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
	var dist := roundi(_actor().global_position.distance_to(venue_system.call("venue_position", str(job["to"]))))
	return "SIDE JOB: %s / %s (%dm)" % [str(job["title"]), str(venue["name"]), dist]

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.current = true
	camera.fov = 76.0
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
	performance_label.offset_right = 420.0
	performance_label.offset_top = -48.0
	performance_label.offset_bottom = -18.0
	performance_label.add_theme_font_size_override("font_size", 18)
	performance_label.add_theme_color_override("font_color", Color("b5eae4"))
	ui.add_child(performance_label)
	venue_panel = PanelContainer.new()
	venue_panel.name = "VenueDialogue"
	venue_panel.position = Vector2(18.0, 262.0)
	venue_panel.custom_minimum_size = Vector2(550.0, 162.0)
	venue_panel.visible = false
	ui.add_child(venue_panel)
	venue_label = Label.new()
	venue_label.add_theme_font_size_override("font_size", 18)
	venue_label.add_theme_color_override("font_color", Color("eadcc9"))
	venue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	venue_panel.add_child(venue_label)

func _update_hud() -> void:
	var district: String = city_details.call("get_district_at", _actor().global_position)
	var landmark: String = city_details.call("get_nearby_landmark", _actor().global_position)
	var local_name := district if landmark.is_empty() else "%s / %s" % [district, landmark]
	var clock: String = day_night.call("clock_string")
	var vehicle_text := "ON FOOT"
	if current_car != null:
		vehicle_text = "DRIVING • %d km/h" % int(current_car.call("speed_kph"))
	elif current_transit != null:
		vehicle_text = "M-LINE RIDER" if transit_kind == "TRAIN" else "CITY LOOP RIDER"
	var wanted_text := "-" if heat < 0.15 else "★".repeat(maxi(1, ceili(heat)))
	var mission := "DELIVER PACKAGE" if carrying else "PICK UP PACKAGE"
	var distance := roundi(_actor().global_position.distance_to(mission_position))
	var message := notification if notification_time > 0.0 else ""
	if performance_overlay:
		var fps := maxi(Engine.get_frames_per_second(), 1)
		performance_label.text = "RTX 3060 target: 60 FPS @1080p | Actual: %d FPS | %.1f ms" % [fps, 1000.0 / float(fps)]
	hud_label.text = "NIGHTGRID / AFTERHOURS    MORROW BAY\n%s | %s\n$%d | HEALTH %d | HEAT %s\n%s | DELIVERIES %d\nOBJECTIVE: %s (%dm)\n%s\n\nWASD Move/Drive | E Car | Shift Sprint | Space Jump/Brake\nE Car | F Board/Exit Transit | F5 Save | F6 New Game | F9 Load\nT Time | Y Pause | F3 FPS | F4 SSR | G Visit Venue | Esc Cursor" % [local_name, clock, cash, ceili(health), wanted_text, vehicle_text, deliveries, mission, distance, message]
	hud_label.text += "\n" + _venue_job_text()
	if current_car == null and current_transit == null:
		var near: Dictionary = venue_system.call("nearest_venue", player.global_position)
		if not near.is_empty():
			var accessible := "OPEN" if venue_system.call("is_open", str(near["id"])) else "CLOSED"
			hud_label.text += "\n[G] %s (%s)" % [str(near["name"]), accessible]
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
	var quest: Vector3 = _venue_job_target()
	return {
		"player": Vector2(actor.global_position.x, actor.global_position.z),
		"mission": Vector2(mission_position.x, mission_position.z),
		"officers": car_positions,
		"carrying": carrying,
		"side_quest": Vector2(quest.x, quest.z),
		"side_quest_active": not venue_job_active.is_empty(),
		"venues": venue_system.call("get_map_pins")
	}
