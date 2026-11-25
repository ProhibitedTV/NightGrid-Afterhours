extends SceneTree
const Dispatch = preload("res://scripts/police_dispatch.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: _fail("timeout"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("DISPATCH_SMOKE: " + message)
	paused = false
	quit(1)

func _verify() -> void:
	var d = Dispatch.new()
	if not d.register_station("a", "Alpha", "A", Vector3(0,1,0), Vector3(0,1,3.25), 2, true):
		_fail("Registration failed")
		return
	if d.register_station("a", "Duplicate", "B", Vector3.ZERO, Vector3.ZERO, 1):
		_fail("Duplicate station accepted")
		return
	d.register_station("b", "Beta", "B", Vector3(116,1,0), Vector3(116,1,3.25), 2)
	d.register_station("new_zone", "New district", "Expansion", Vector3(-116,1,0), Vector3(-116,1,3.25), 1)
	if str(d.ranked(Vector3(-110,1,0), {})[0]["id"]) != "new_zone" or str(d.ranked(Vector3(-110,1,0), {"new_zone":1})[0]["id"]) != "a":
		_fail("Extensible registry must route to nearest available station")
		return
	d.report("THEFT", Vector3.ZERO, 1)
	d.report("SHOT", Vector3.ONE, 3)
	if int(d.active["reports"]) != 2 or d.assign("a") == d.assign("a"):
		_fail("Case consolidation and unique unit assignment")
		return
	d.update_case(Vector3.INF, 0)
	if not d.active.is_empty():
		_fail("Incident closure")
		return
	var scene: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	world.set_physics_process(false)
	var live = world.get("dispatch")
	var civic := world.get_node("CivicServices")
	if live.stations.size() != 2 or not live.stations.has("central") or not live.stations.has("west"):
		_fail("Actual city's registered stations missing")
		return
	var hq: Dictionary = civic.call("site_by_id", "police_hq")
	var address: Vector3 = civic.call("position_for", "police_hq")
	if hq.is_empty() or not bool(hq["headquarters"]) or live.stations["central"]["address"] != address or civic.get_node_or_null("police_hq") == null:
		_fail("HQ must have a physical address and exterior node")
		return
	var data: Dictionary = world.call("get_map_state")
	if (data["police_stations"] as Array).size() != 2:
		_fail("Station atlas missing")
		return
	world.call("_report_incident", "THEFT", Vector3(0,1,0), true)
	world.call("_spawn_police")
	var units: Array = world.get("officers")
	if units.size() != 1:
		_fail("No station dispatched a cruiser")
		return
	var officer: CharacterBody3D = units[0]
	var home: Dictionary = live.stations[str(officer.get_meta("station_id"))]
	if officer.global_position.distance_to(home["launch"]) > 0.1 or str(officer.get_meta("unit_id", "")).is_empty():
		_fail("Unit must originate at a real station with assignment")
		return
	world.set("heat", 0.0)
	world.call("_update_wanted", 0.01)
	if not (world.get("officers") as Array).is_empty() or (world.get("returning_units") as Array).size() != 1 or officer.get("police_destination") != home["launch"]:
		# A unit already at home may complete its return on the same tick.
		if not (world.get("officers") as Array).is_empty() or not officer.is_queued_for_deletion():
			_fail("Case closure must release cruiser back to its station")
			return
	# Reloading must not inherit deployed units or queued theft from the
	# abandoned timeline. Exercise the actual world save/apply path.
	var clean: Dictionary = world.call("_capture_snapshot")
	var report_point := Vector3(0, 1, 18)
	world.call("_report_incident", "THEFT", report_point, true)
	world.call("_spawn_police")
	var spawned: Array = world.get("officers")
	if spawned.size() != 1:
		_fail("Save fixture failed to spawn a response unit")
		return
	var stale: CharacterBody3D = spawned[0]
	var pursued: Dictionary = world.call("_capture_snapshot")
	world.set("_pending_theft", {"position": report_point})
	world.call("_apply_snapshot", clean)
	if float(world.get("heat")) != 0.0 or not live.active.is_empty() or not (world.get("officers") as Array).is_empty() or not (world.get("returning_units") as Array).is_empty() or world.get("_pending_theft") != null or not stale.is_queued_for_deletion() or stale.collision_layer != 0:
		_fail("Clean save retained pursuit units, collision or pending crime")
		return
	world.call("_apply_snapshot", pursued)
	if float(world.get("heat")) <= 0.0 or live.active.get("point") != report_point or not (world.get("officers") as Array).is_empty() or int(live.active.get("reports", 0)) != 1:
		_fail("Wanted save did not reconstruct the saved dispatch case")
		return
	world.call("_apply_snapshot", clean)
	if not live.active.is_empty() or live.stations.size() != 2 or (world.get("routine_patrols") as Array).size() != 2:
		_fail("Repeated load must preserve permanent station and patrol registry")
		return
	var player: CharacterBody3D = world.get("player")
	player.global_position = address
	world.call("_toggle_interior")
	var rooms := world.get_node("Interiors")
	if str(rooms.call("active_site_id")) != "police_hq" or rooms.get_node_or_null("Interior_police_hq") == null:
		_fail("Player cannot visit dispatch headquarters")
		return
	print("DISPATCH_SMOKE PASS: station registry, expansion registration, capacity, incident history, actual station launch, return and enterable HQ")
	quit(0)
