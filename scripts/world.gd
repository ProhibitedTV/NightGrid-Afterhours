extends Node3D
## NIGHTGRID: AFTERHOURS — a generated 3D city with an original courier/crime loop.

const PlayerScript = preload("res://scripts/player.gd")
const CarScript = preload("res://scripts/car.gd")
const MinimapScript = preload("res://scripts/minimap.gd")
const CityDetailsScript = preload("res://scripts/city_details.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const FloraScript = preload("res://scripts/flora.gd")
const CELL = 58.0
const GRID_RADIUS = 3
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
	rng.seed = 834726
	_build_environment()
	_build_city()
	_build_world_systems()
	_create_player()
	_spawn_traffic()
	_create_camera()
	_create_marker()
	_build_hud()
	_set_mission_target(PICKUPS[0], false)
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
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_E:
				_toggle_car()
			KEY_T:
				day_night.call("advance_hour", 1.0)
			KEY_Y:
				day_night.call("toggle_pause")
			KEY_F3:
				performance_overlay = not performance_overlay
				performance_label.visible = performance_overlay

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var actor := _actor()
	if current_car == null:
		player.set("camera_yaw", yaw)
	var focus := actor.global_position + Vector3.UP * (1.65 if current_car != null else 1.45)
	var camera_distance := 13.0 if current_car != null else 7.5
	var camera_offset := Vector3(0.0, sin(pitch) * camera_distance, cos(pitch) * camera_distance).rotated(Vector3.UP, yaw)
	camera.global_position = camera.global_position.lerp(focus + camera_offset, minf(delta * 7.0, 1.0))
	camera.look_at(focus, Vector3.UP)
	if actor.global_position.distance_to(mission_position) < 5.3:
		_advance_mission()
	if actor.global_position.y < -15.0 or absf(actor.global_position.x) > 280.0 or absf(actor.global_position.z) > 280.0:
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
	return current_car if current_car != null else player

func _toggle_car() -> void:
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

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, collider: bool = false, glow: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.position = at
	visual.material_override = _make_material(color, glow)
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
	world_environment.environment = environment
	add_child(world_environment)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -27.0, 0.0)
	sun_light.light_color = Color("ffc39e")
	sun_light.light_energy = 0.7
	sun_light.shadow_enabled = true
	add_child(sun_light)
	_box(self, Vector3(0.0, -0.58, 0.0), Vector3(600.0, 1.0, 600.0), Color("18242e"), true)

func _build_city() -> void:
	# The road foundation stays simple; populated streets live in city_details.gd.
	var road := Color("252b35")
	var sidewalk := Color("4d5565")
	for index in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var axis := float(index) * CELL
		_box(self, Vector3(axis, -0.055, 0.0), Vector3(14.0, 0.12, 405.0), road)
		_box(self, Vector3(0.0, -0.05, axis), Vector3(405.0, 0.12, 14.0), road)
	for block_x in range(-GRID_RADIUS, GRID_RADIUS):
		for block_z in range(-GRID_RADIUS, GRID_RADIUS):
			var center := Vector3((float(block_x) + 0.5) * CELL, 0.07, (float(block_z) + 0.5) * CELL)
			_box(self, center, Vector3(42.0, 0.14, 42.0), sidewalk)
	city_details = CityDetailsScript.new()
	city_details.name = "CityDetails"
	add_child(city_details)
	city_details.call("generate")

func _build_world_systems() -> void:
	# Geography and story anchors are authored; botanical infill is seeded.
	flora = FloraScript.new()
	flora.name = "CityFlora"
	add_child(flora)
	flora.call("generate")
	day_night = DayNightScript.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.call("configure", world_environment, sun_light, city_details)

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
		Vector3(63.0, 1.0, -143.0), Vector3(-63.0, 1.0, 139.0)
	]
	for i in range(parked.size()):
		var car := _create_car(parked[i], VEHICLE_COLORS[i % VEHICLE_COLORS.size()])
		car.rotation.y = PI if i % 2 == 1 else 0.0
		cars.append(car)

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

func _update_hud() -> void:
	var district: String = city_details.call("get_district_at", _actor().global_position)
	var landmark: String = city_details.call("get_nearby_landmark", _actor().global_position)
	var local_name := district if landmark.is_empty() else "%s / %s" % [district, landmark]
	var clock: String = day_night.call("clock_string")
	var vehicle_text := "ON FOOT" if current_car == null else "DRIVING • %d km/h" % int(current_car.call("speed_kph"))
	var wanted_text := "-" if heat < 0.15 else "★".repeat(maxi(1, ceili(heat)))
	var mission := "DELIVER PACKAGE" if carrying else "PICK UP PACKAGE"
	var distance := roundi(_actor().global_position.distance_to(mission_position))
	var message := notification if notification_time > 0.0 else ""
	if performance_overlay:
		var fps := maxi(Engine.get_frames_per_second(), 1)
		performance_label.text = "RTX 3060 target: 60 FPS @1080p | Actual: %d FPS | %.1f ms" % [fps, 1000.0 / float(fps)]
	hud_label.text = "NIGHTGRID / AFTERHOURS    MORROW BAY\n%s | %s\n$%d | HEALTH %d | HEAT %s\n%s | DELIVERIES %d\nOBJECTIVE: %s (%dm)\n%s\n\nWASD Move/Drive | E Car | Shift Sprint | Space Jump/Brake\nT Advance Time | Y Pause Clock | Esc Cursor" % [local_name, clock, cash, ceili(health), wanted_text, vehicle_text, deliveries, mission, distance, message]

func get_map_state() -> Dictionary:
	var car_positions: Array[Vector2] = []
	for officer in officers:
		if is_instance_valid(officer):
			car_positions.append(Vector2(officer.global_position.x, officer.global_position.z))
	var actor := _actor()
	return {
		"player": Vector2(actor.global_position.x, actor.global_position.z),
		"mission": Vector2(mission_position.x, mission_position.z),
		"officers": car_positions,
		"carrying": carrying
	}
