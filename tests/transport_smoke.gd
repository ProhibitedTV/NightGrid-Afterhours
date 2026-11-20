extends SceneTree
## Headless integration of roads, signals, boardable transit and save serialization.
func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error("TRANSPORT_SMOKE: " + message)
	quit(1)

func _check() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Main scene not found")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var signals := world.get_node_or_null("TrafficSignals")
	var traffic := world.get_node_or_null("SurfaceTraffic")
	var rail := world.get_node_or_null("MorrowLine")
	var city := world.get_node_or_null("CityDetails")
	var flora := world.get_node_or_null("CityFlora")
	var session := root.get_node_or_null("GameSession")
	if signals == null or traffic == null or rail == null or session == null or city == null or flora == null:
		_fail("Transport, seed or scenery nodes are missing")
		return
	var seed_value: int = session.get("world_seed")
	if int(city.get("world_seed")) != seed_value or int(flora.get("world_seed")) != seed_value:
		_fail("City and planted flora must use the same immutable save seed")
		return
	var fleet: Dictionary = traffic.call("get_counts")
	var trains: Dictionary = rail.call("get_counts")
	if fleet.get("ambient_cars") != 25 or fleet.get("buses") != 4 or fleet.get("stops") != 16:
		_fail("Expected 25 NPC cars, four buses and sixteen curb stops: %s" % fleet)
		return
	if trains.get("stations") != 5 or trains.get("trains") != 1:
		_fail("Expected one five-station elevated line")
		return
	# The hero transit model must be attached to the actual moving train, not
	# displayed as separate scenery. All geometry is generated deterministically.
	var hero := rail.get_node_or_null("MorrowLineTrain/CicadaM8HeroVisual")
	if hero == null:
		_fail("Missing CICADA M8 playable rolling-stock visuals")
		return
	var visual_stats: Dictionary = rail.call("get_train_visual_stats")
	var audio = load("res://scripts/m_line_train_audio.gd")
	if audio.cache_count() != 2 or hero.get_node_or_null("OriginalRailRollingLoop") == null or hero.get_node_or_null("OriginalStationArrivalChime") == null:
		_fail("Real train must have cached original rolling ambience and arrival chime")
		return
	if str(hero.call("displayed_destination")) != "BRICKWATER CROSSING":
		_fail("Cab destination displays must follow the actual next station")
		return
	if int(visual_stats.get("cars", -1)) != 2 or int(visual_stats.get("glass_windows", -1)) != 16:
		_fail("Two detailed cabins with 16 windows must be present: %s" % visual_stats)
		return
	if int(visual_stats.get("door_panels", -1)) != 8 or int(visual_stats.get("bogies", -1)) != 4:
		_fail("Missing animated doors or rail running gear: %s" % visual_stats)
		return
	if int(visual_stats.get("wheels", -1)) != 16 or int(visual_stats.get("headlamps", -1)) != 4:
		_fail("Missing train wheels or bidirectional marker lamps: %s" % visual_stats)
		return
	if int(visual_stats.get("stationary_components", 0)) > 420:
		_fail("Train detail count exceeded bounded procedural scene budget")
		return
	var shell := hero.get_node_or_null("CicadaCar_West/BevelledAlloyMonocoque") as MeshInstance3D
	if shell == null or not shell.mesh is ArrayMesh:
		_fail("Cicada M8 must have a bespoke bevelled hull mesh")
		return
	var triangles: PackedVector3Array = shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if triangles.size() < 200:
		_fail("Train hull lacks detailed lofted geometry")
		return
	var sleepers := rail.get_node_or_null("RailSleepers171") as MultiMeshInstance3D
	if sleepers == null or sleepers.multimesh.instance_count != 171:
		_fail("Engineered guideway must use one batched 171-sleeper mesh")
		return
	for platform_index in range(5):
		if rail.get_node_or_null("MLineStation_%02d" % platform_index) == null:
			_fail("Missing one of the five fully detailed platforms")
			return
	hero.call("set_operational_state", 1, 0.0, true)
	hero.call("_process", 0.50)
	if float(hero.call("door_open_fraction")) < 0.90:
		_fail("Train doors must visually open during the station dwell")
		return
	hero.call("set_operational_state", -1, 2.0, false)
	hero.call("_process", 0.50)
	if float(hero.call("door_open_fraction")) > 0.1:
		_fail("Train doors must visually close for departure")
		return
	rail.call("_sync_train_visual")
	for step in range(72):
		signals.set("elapsed", float(step))
		var ns: String = signals.call("phase_at", -3, -3, "NS")
		var ew: String = signals.call("phase_at", -3, -3, "EW")
		if ns == "GREEN" and ew == "GREEN":
			_fail("Unsafe concurrent perpendicular green at t=%d" % step)
			return
	signals.set("elapsed", 30.0)
	if signals.call("phase_at", -3, -3, "NS") != "YELLOW":
		_fail("Signal must show yellow change at 30 seconds")
		return
	signals.set("elapsed", 34.5)
	if signals.call("phase_at", -3, -3, "NS") != "RED" or signals.call("phase_at", -3, -3, "EW") != "RED":
		_fail("Signal lacks all-red clearance")
		return
	signals.set("elapsed", 36.0)
	if signals.call("phase_at", -3, -3, "EW") != "GREEN":
		_fail("East-west through phase did not open after clearance")
		return
	signals.set("elapsed", 0.0)
	var vehicle_route: Array[Vector3] = traffic.call("loop_route", -116.0, 116.0, -116.0, 116.0, 1.0)
	var a: Dictionary = traffic.call("sample_route", vehicle_route, 0.35)
	var b: Dictionary = traffic.call("sample_route", vehicle_route, 0.35)
	if a["position"] != b["position"] or a["next_index"] != b["next_index"]:
		_fail("Fixed network route sampling is not repeatable")
		return
	var world_plan = load("res://scripts/world_plan.gd")
	var changed_profiles := 0
	for key in world_plan.VARIANT_PARCELS:
		var coordinates: PackedStringArray = str(key).split(",")
		var bx := int(coordinates[0])
		var bz := int(coordinates[1])
		for side in range(2):
			if world_plan.lot_profile(bx, bz, side, 1001) != world_plan.lot_profile(bx, bz, side, 1002):
				changed_profiles += 1
	if changed_profiles < 8:
		_fail("New-game seed did not select curated alternate building profiles")
		return
	for key in world_plan.LANDMARK_BLOCKS:
		var coordinates: PackedStringArray = str(key).split(",")
		var bx := int(coordinates[0])
		var bz := int(coordinates[1])
		if world_plan.lot_variant_index(bx, bz, 1002) != 0:
			_fail("Story landmark geometry must not vary by seed")
			return
	var player: CharacterBody3D = world.get("player")
	player.global_position = rail.call("station_entrance", 0)
	if not rail.call("boardable_from", player.global_position):
		_fail("M-Line station should support street-level boarding")
		return
	world.call("_toggle_transit")
	if world.get("transit_kind") != "TRAIN":
		_fail("Player did not board the train")
		return
	world.call("_toggle_transit")
	if world.get("transit_kind") != "":
		_fail("Player could not alight at the M-Line platform")
		return
	player.global_position = Vector3(-41.0, 1.15, -104.75)
	if traffic.call("get_boardable_bus", player.global_position) == null:
		_fail("City Loop bus at the far-side stop was not reachable")
		return
	world.call("_toggle_transit")
	if world.get("transit_kind") != "BUS":
		_fail("Player did not board the bus")
		return
	var capture: Dictionary = world.call("_capture_snapshot")
	var encoded: Dictionary = session.call("make_snapshot", capture)
	if int(encoded.get("seed", -1)) != seed_value or not session.call("is_valid_snapshot", encoded):
		_fail("Invalid or unseeded world snapshot")
		return
	var temp_path := "user://tests/mobility_smoke_slot.json"
	if not session.call("save_snapshot_to", capture, temp_path):
		_fail("Could not write isolated save test slot")
		return
	var restored: Dictionary = session.call("read_snapshot_from", temp_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	if restored.is_empty() or int(restored.get("seed", -1)) != seed_value:
		_fail("Seed was not preserved through on-disk JSON save/load")
		return
	world.call("_apply_snapshot", restored)
	if world.get("transit_kind") != "BUS":
		_fail("Bus passenger state did not survive save/load")
		return
	if int(world.get("cash")) != int(restored.get("cash", -1)):
		_fail("Player state did not survive save/load")
		return
	world.call("_toggle_transit")
	if world.get("transit_kind") != "":
		_fail("Bus rider could not alight at a marked stop")
		return
	var bus_stop_position: Vector3 = traffic.call("get_boardable_bus", player.global_position).global_position if traffic.call("get_boardable_bus", player.global_position) != null else Vector3(-41.0, 1.75, -112.75)
	if Vector2(player.global_position.x - bus_stop_position.x, player.global_position.z - bus_stop_position.z).length() < 5.5:
		_fail("Bus alighting did not move the rider to the sidewalk")
		return
	# Explicitly exercise moving transport, not just static boarding states.
	var train_body: Node3D = rail.get_node("MorrowLineTrain")
	var old_train_x: float = train_body.position.x
	rail.set("dwell_remaining", 0.0)
	var vehicle_nodes: Array = traffic.get("fleet")
	var road_sample: Node3D = vehicle_nodes[0]
	var old_car_position: Vector3 = road_sample.global_position
	for physics_tick in range(120):
		await physics_frame
	if train_body.position.x <= old_train_x + 0.5:
		_fail("Elevated train never departed its station")
		return
	if road_sample.global_position.distance_to(old_car_position) < 0.4:
		_fail("NPC car did not move on a scheduled road lane")
		return
	session.call("start_new_game")
	if int(session.get("world_seed")) == seed_value:
		_fail("New Game did not issue a fresh seed")
		return
	print("TRANSPORT_SMOKE PASS: ", fleet, " / ", trains,
		" / saved_seed=", seed_value, " / new_seed=", session.get("world_seed"))
	quit(0)
