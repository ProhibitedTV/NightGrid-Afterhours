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
	if fleet.get("ambient_cars") != 17 or fleet.get("buses") != 2 or fleet.get("stops") != 8:
		_fail("Expected 17 NPC cars, two buses and eight curb stops: %s" % fleet)
		return
	if trains.get("stations") != 3 or trains.get("trains") != 1:
		_fail("Expected one three-station elevated line")
		return
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
	session.call("start_new_game")
	if int(session.get("world_seed")) == seed_value:
		_fail("New Game did not issue a fresh seed")
		return
	print("TRANSPORT_SMOKE PASS: ", fleet, " / ", trains,
		" / saved_seed=", seed_value, " / new_seed=", session.get("world_seed"))
	quit(0)
