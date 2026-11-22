extends SceneTree
## Native or headless integration using real permanently addressed city fixtures.
const Rail = preload("res://scripts/rail_system.gd")
var world: Node3D
var city: Node3D
var rail: Node3D
var player: CharacterBody3D
var car: CharacterBody3D
var failures: Array[String] = []
var measurements: Dictionary = {}
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("PHYSICAL_COHERENCE: " + message)

func _run() -> void:
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	# Leave the actual vehicle, player, camera, collision and transit simulators
	# enabled. Keep the lane clear of variable ambient traffic for this replay.
	world.get_node("SurfaceTraffic").process_mode = Node.PROCESS_MODE_DISABLED
	city = world.get("city_details")
	rail = world.get_node("MorrowLine")
	player = world.get("player")
	car = world.get("cars")[0]
	car.set_meta("claimed", true)
	capture_dir = OS.get_environment("NIGHTGRID_PHYSICAL_PLAYTEST_DIR")
	if not capture_dir.is_empty() and (DisplayServer.get_name() == "headless" or
			not capture_dir.is_absolute_path() or DirAccess.dir_exists_absolute(capture_dir) or
			DirAccess.make_dir_recursive_absolute(capture_dir) != OK):
		_expect(false, "Gameplay evidence requires a new absolute directory and native renderer")
		quit(1)
		return
	await _check_rail_corridor()
	await _check_horizon_camera()
	await _check_market()
	await _check_station()
	await _check_envelope()
	print("PHYSICAL_COHERENCE_MEASUREMENTS ", JSON.stringify(measurements))
	print("PHYSICAL_COHERENCE_SMOKE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _wait_ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _capture(name: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	_expect(not frame.is_empty() and frame.save_png(path) == OK, "Capture " + name)

func _ray(origin: Vector3, finish: Vector3) -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(origin, finish, 1, [player.get_rid(), car.get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(query).get("collider")

func _set_driving(at: Vector3, heading: float, speed: float) -> void:
	city.call("set_focus", at)
	car.global_position = at
	car.rotation.y = heading
	car.velocity = Vector3.ZERO
	car.call("repair")
	car.set("speed", speed)
	if world.get("current_car") == null:
		player.global_position = at + Vector3(2.6, 0.0, 0.0)
		world.call("_toggle_car")

func _exit_car() -> void:
	car.set("speed", 0.0)
	car.velocity = Vector3.ZERO
	if world.get("current_car") == car:
		world.call("_toggle_car")

func _check_rail_corridor() -> void:
	_set_driving(Vector3(175, 0.65, Rail.TRACK_Z + 5.25), -PI * 0.5, 30.0)
	Input.action_press("drive_accelerate")
	var peak := 0
	for i in range(69):
		await physics_frame
		peak = maxi(peak, int(car.call("speed_kph")))
	Input.action_release("drive_accelerate")
	measurements["rail_road"] = {"peak_kph": peak, "end_x": car.global_position.x, "condition": car.get("condition")}
	_expect(world.get("current_car") == car and peak >= 125 and car.global_position.x > 211.0
		and float(car.get("condition")) == 100.0, "The car must clear the former pier line at speed")
	var pier := _ray(Vector3(203.0, 1.0, Rail.TRACK_Z + 7.4), Vector3(203.0, 1.0, Rail.TRACK_Z + 13.0))
	_expect(pier != null and pier.name == &"MLinePier_203", "The re-set curb pier must be a permanent solid")
	var signals := world.get_node("TrafficSignals")
	var mast := signals.get_node_or_null("SignalMast_4_-1_-1") as StaticBody3D
	if mast == null:
		_expect(false, "Missing East Gardens signal mast")
	else:
		var ns := mast.get_node("NS") as Node3D
		var ew := mast.get_node("EW") as Node3D
		_expect(ns.global_basis.z.dot(Vector3.BACK) > 0.99 and ew.global_basis.z.dot(Vector3.RIGHT) > 0.99,
			"East Gardens heads must face the correct orthogonal approaches")
		var base := mast.global_position
		_expect(_ray(base + Vector3(-0.8, 1.0, 0), base + Vector3(0.8, 1.0, 0)) == mast,
			"The signal mast should meet the ground with a real solid post")

func _check_horizon_camera() -> void:
	_set_driving(Vector3(203.0, 0.65, 38.0), 0.0, 0.0)
	world.set("yaw", 0.0)
	world.set("pitch", 0.88)
	await _wait_ticks(5)
	world.call("_snap_camera")
	var camera: Camera3D = world.get("camera")
	var roof := _ray(Vector3(203, 3.0, 42), Vector3(203, 6.0, 42))
	_expect(roof is StaticBody3D, "The Horizon Commons roof must have its visible collision")
	var focus := Vector3(214.12, 2.60, 38.0)
	var goal := Vector3(214.12, 8.0, 47.5)
	var swept: Vector3 = world.call("_camera_clearance", focus, goal)
	measurements["canopy"] = {"vehicle_camera_y": camera.global_position.y, "edge_sweep_y": swept.y}
	_expect(_ray(focus, goal) == null and swept.y < 5.0 and camera.global_position.y < 5.0,
		"The actual chase camera and an off-edge sweep must stay below the visible canopy")
	await _capture("horizon-chase-camera")
	_exit_car()
	player.global_position = Vector3(200.0, 1.12, 46.0)
	world.set("yaw", 0.0)
	player.set("camera_yaw", 0.0)
	Input.action_press("move_forward")
	await _wait_ticks(95)
	Input.action_release("move_forward")
	_expect(player.global_position.z < 36.0 and player.global_position.y > 0.7,
		"The pavilion must stay walkable beneath the new roof collision")

func _check_market() -> void:
	_set_driving(Vector3(-35.0, 0.65, -228.0), PI, 9.0)
	# Explicit destination entry must prime the same collision as normal streaming.
	await _wait_ticks(2)
	var carton := _ray(Vector3(-35, 0.42, -216), Vector3(-35, 0.42, -213))
	_expect(carton != null and carton.has_method("knock_loose"), "The North Quay delivery carton must match its source bounds")
	Input.action_press("drive_accelerate")
	var retained_speed := 0.0
	for i in range(92):
		await physics_frame
		if is_instance_valid(carton) and carton.has_node("CartonDebris") and retained_speed == 0.0:
			retained_speed = absf(float(car.get("speed")))
			_expect(float(car.get("condition")) == 100.0, "A cardboard impact must not inflict structural vehicle damage")
	Input.action_release("drive_accelerate")
	var counter := _ray(Vector3(-32, 3.5, -209.0), Vector3(-32, 0.5, -209.0))
	_expect(counter is StaticBody3D, "The actual North Quay counter must be solid")
	measurements["north_quay_impacts"] = {"after_carton_mps": retained_speed, "final_z": car.global_position.z,
		"condition": car.get("condition"), "final_kph": car.call("speed_kph")}
	_expect(retained_speed > 7.0 and float(car.get("condition")) < 100.0 and int(car.call("speed_kph")) < 4
		and car.global_position.z < -210.0, "Loose carton and structural counter must impart distinct momentum changes")
	world.set("yaw", PI)
	world.set("pitch", 0.44)
	world.call("_snap_camera")
	await _capture("north-quay-after-impact")
	_exit_car()

func _check_station() -> void:
	var lift := rail.get_node_or_null("MLineStation_04/AccessibleLift")
	if lift == null:
		_expect(false, "East Gardens lift is missing")
		return
	var lower: Vector3 = lift.call("landing_position", false)
	var upper: Vector3 = lift.call("landing_position", true)
	player.global_position = Vector3(lower.x, 0.90, lower.z - 3.54)
	player.velocity = Vector3.ZERO
	city.call("set_focus", lower)
	world.set("yaw", PI)
	player.set("camera_yaw", PI)
	Input.action_press("move_forward")
	await _wait_ticks(36)
	Input.action_release("move_forward")
	await _wait_ticks(3)
	_expect(player.is_on_floor() and player.global_position.distance_to(lower) < 1.2
		and player.global_position.y > 1.02, "Walk from the curb up the accessible East Gardens approach")
	var door_test := lower + Vector3.RIGHT * 0.2
	_expect(_ray(door_test, door_test + Vector3.BACK * 1.4) is StaticBody3D,
		"The East Gardens door must block walking into the lift shaft")
	world.call("_toggle_transit")
	var in_lift: Dictionary = world.call("_capture_snapshot")
	var saved_at: Array = in_lift.get("player_position", [])
	_expect(world.get("transit_kind") == "LIFT" and in_lift.get("transit_kind") == ""
		and saved_at.size() == 3 and absf(float(saved_at[1]) - upper.y) < 0.05,
		"Calling the lift should ride it and save a safe landing for v1")
	await _wait_ticks(205)
	_expect(world.get("current_transit") == null and player.global_position.distance_to(upper) < 0.16
		and player.is_on_floor(), "The lift must deliver the player to a solid upper landing")
	world.set("yaw", 0.0)
	player.set("camera_yaw", 0.0)
	Input.action_press("move_forward")
	await _wait_ticks(53)
	Input.action_release("move_forward")
	_expect(rail.call("on_platform", player.global_position, 4),
		"Walk continuously from the actual East Gardens lift to the boardable platform")
	rail.call("restore", {"x": 232.0, "current_station": 4, "next_station": 3, "direction": -1, "dwell": 7.0})
	_expect(not rail.call("boardable_from", player.global_position), "Platform boarding must be aligned with real train doors")
	Input.action_press("move_left")
	await _wait_ticks(56)
	Input.action_release("move_left")
	_expect(rail.call("boardable_from", player.global_position), "Walk to the marked door of the stopped train")
	await _capture("east-gardens-platform")
	world.call("_toggle_transit")
	var aboard: Dictionary = world.call("_capture_snapshot")
	_expect(world.get("transit_kind") == "TRAIN" and aboard.get("rail_platform_rider") == true,
		"Board the dwell train from the walked-to platform and preserve the alight type")
	var session := root.get_node("GameSession")
	var save := "user://morrow-bay-physical-coherence-%d.json" % OS.get_process_id()
	var wrote: bool = session.call("save_snapshot_to", aboard, save)
	if wrote:
		var decoded: Dictionary = session.call("read_snapshot_from", save)
		_expect(decoded.get("version") == 1 and decoded.get("rail_platform_rider") == true and
			decoded.get("seed") == session.get("world_seed"), "The platform state should round-trip in the v1 save")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	else:
		_expect(false, "Could not write the isolated platform-rider save test")
	rail.call("restore", {"x": 120.0, "current_station": 4, "next_station": 3, "direction": -1, "speed": 6.0})
	world.call("_toggle_transit")
	_expect(world.get("transit_kind") == "TRAIN", "Do not alight while the train is moving")
	await _wait_ticks(120)
	world.call("_toggle_transit")
	await _wait_ticks(4)
	_expect(world.get("current_transit") == null and rail.call("on_platform", player.global_position, 3)
		and player.is_on_floor(), "Alight on the actual Helix platform once the train stops")
	measurements["rail_visit"] = {"east_gardens_landing_y": upper.y, "exit": str(player.global_position)}
	var destination_lift := rail.get_node("MLineStation_03/AccessibleLift")
	player.global_position = destination_lift.call("landing_position", true)
	world.call("_toggle_transit")
	await _wait_ticks(410)
	var street: Vector3 = destination_lift.call("landing_position", false)
	measurements["rail_visit"]["helix_street"] = str(player.global_position)
	_expect(player.global_position.distance_to(street) < 0.2 and world.get("current_transit") == null,
		"An upstairs call must dispatch the empty lift and return the rider to the street")
	_expect(not is_instance_valid(carton_at_market()), "Streamed market debris should disappear away from the market")

func carton_at_market() -> Node:
	return city.find_child("CartonDebris", true, false)

func _check_envelope() -> void:
	player.global_position = Vector3(-193.5, 1.12, -48.0)
	player.velocity = Vector3.ZERO
	city.call("set_focus", player.global_position)
	await _wait_ticks(4)
	var facade := city.find_child("WestDocksServiceFrontage", true, false)
	_expect(facade != null, "The actual Pier Storage warehouse must stream in")
	if facade == null:
		return
	var roof := facade.get_node("MeasuredArchitecture_ROOF") as MeshInstance3D
	var brick := facade.get_node("MeasuredArchitecture_BRICK") as MeshInstance3D
	var normals: PackedVector3Array = roof.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var walls: PackedVector3Array = brick.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	measurements["warehouse_normals"] = [str(normals[0]), str(walls[0])]
	_expect(normals[0].dot(Vector3.UP) > 0.999 and walls[0].dot(Vector3.FORWARD) > 0.999,
		"Pier Storage's roof and front must be outward-facing")
	var dumpster := facade.get_parent().get_node_or_null("StreetPropCollision/AlleyDumpster") as StaticBody3D
	if dumpster == null:
		_expect(false, "Missing the West Docks alley dumpster")
		return
	var center := dumpster.global_position + Vector3.UP * 0.50
	_expect(_ray(center - Vector3.BACK * 2.0, center + Vector3.BACK * 2.0) == dumpster,
		"The West Docks alley dumpster must be solid")
	var passage := center + Vector3.RIGHT * 1.95
	_expect(_ray(passage - Vector3.BACK * 2.0, passage + Vector3.BACK * 2.0) == null,
		"The solid dumpster must leave a clear passage next to the building")
