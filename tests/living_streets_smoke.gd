extends SceneTree

const Game = preload("res://scenes/main.tscn")
const Routes = preload("res://scripts/pedestrian_routes.gd")
const Cert = preload("res://scripts/sidewalk_certification.gd")
const Wanted = preload("res://scripts/wanted_system.gd")
const ANCHOR = Vector3(-18.5, 1.18, -37.0)

var faults := 0

func _initialize() -> void:
	create_timer(70.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _expect(result: bool, reason: String) -> void:
	if not result:
		faults += 1
		push_error("LIVING_STREETS: " + reason)

func _ticks(count: int) -> void:
	for index in range(count):
		await physics_frame

func _verify() -> void:
	var game := Game.instantiate()
	root.add_child(game)
	await process_frame
	game.get_node("GameMenus").call("hide_for_game")
	var city: Node3D = game.get("city_details")
	var player: CharacterBody3D = game.get("player")
	var camera: Camera3D = game.get("camera")
	var clock: Node = game.get("day_night")
	game.set_process(false)
	game.set_process_input(false)
	clock.set("paused", true)
	clock.call("set_hour", 12.0)
	_expect(game.get("pedestrians") == null, "Legacy launch stays opt-out")
	if not game.call("enable_living_streets"):
		_expect(false, "Real four-model pool could not initialize")
		quit(1)
		return
	var director: Node3D = game.get("pedestrians")
	player.global_position = ANCHOR
	city.call("set_focus", ANCHOR)
	camera.global_position = ANCHOR + Vector3(0, 1.6, 0)
	camera.look_at(camera.global_position + Vector3.FORWARD * 30.0)
	await _ticks(245)
	var active: Dictionary = director.call("active_positions")
	var stats: Dictionary = director.call("stats")
	var stream: Dictionary = city.call("get_streaming_stats")
	print("LIVING_STREETS_ACTIVE ", JSON.stringify(stats), " ", active)
	_expect(not active.is_empty() and active.size() <= 12 and stats["logical"] == 128,
		"Seeded, capped actors must activate with real street collision")
	_expect(active.size() == int(stream["pedestrian_reservations"]), "Each actor must own exactly one retained parcel")
	if not active.is_empty():
		await _check_witness(director, camera, active)
	var interiors: Node3D = game.get("interiors")
	var venues: Node3D = game.get("venue_system")
	var cafe: Dictionary = venues.call("venue_by_id", "lantern_cup")
	var exterior := player.global_position
	if not cafe.is_empty():
		player.global_position = interiors.call("enter", cafe, "VENUE", exterior)
		var before_room: Dictionary = director.call("stats")
		await _ticks(36)
		var in_room: Dictionary = director.call("stats")
		_expect(interiors.call("is_inside") and before_room["activations"] == in_room["activations"] and
			before_room["releases"] == in_room["releases"], "Actual indoor entry suppresses exterior population changes")
		player.global_position = interiors.call("leave")
	var state: Dictionary = game.call("_capture_snapshot")
	var session := root.get_node("GameSession")
	var v1: Dictionary = session.call("make_snapshot", state)
	_expect(session.call("is_valid_snapshot", JSON.parse_string(JSON.stringify(v1))) and
		v1.get("sidewalk_population", {}).get("phases", {}).size() == 128, "v1 JSON keeps optional logical phases")
	var legacy := v1.duplicate(true)
	legacy.erase("sidewalk_population")
	_expect(session.call("is_valid_snapshot", legacy), "Older v1 saves still validate")
	director.call("shutdown")
	_expect(director.call("active_positions").is_empty() and city.call("get_streaming_stats")["pedestrian_reservations"] == 0,
		"Teardown releases all retained parcels")
	var doors := Cert.new()
	var certified := 0
	for link in Routes.retail_links():
		for attempt in range(22):
			await physics_frame
			var result := doors.evaluate(city, city.get_world_3d().direct_space_state, link)
			if result != Cert.PENDING:
				certified += int(result == Cert.CLEAR)
				break
	print("LIVING_STREETS_RETAIL_CERTIFIED ", certified)
	_expect(certified >= 1, "At least one documented real shop portal is walkable")
	game.queue_free()
	await process_frame
	var restored := Game.instantiate()
	root.add_child(restored)
	await process_frame
	restored.set_process(false)
	_expect(restored.call("enable_living_streets"), "Fresh world creates the same seeded pool for reload")
	restored.call("_apply_snapshot", v1)
	var restored_director: Node3D = restored.get("pedestrians")
	if is_instance_valid(restored_director):
		var phases: Dictionary = restored_director.call("snapshot")
		_expect(phases.get("phases", {}) == v1.get("sidewalk_population", {}).get("phases", {}),
			"Normal world save application restores the same IDs and phases")
	print("LIVING_STREETS_SMOKE ", "PASS" if faults == 0 else "FAIL")
	quit(0 if faults == 0 else 1)

func _check_witness(director: Node3D, camera: Camera3D, active: Dictionary) -> void:
	var at: Vector3 = active.get("0,0:0", active.values()[-1])
	camera.global_position = at + Vector3(0, 1.75, 5.0)
	camera.look_at(at + Vector3.UP)
	var target := at + Vector3(1.5, 1.5, 0)
	var candidates: Array[Dictionary] = director.call("witness_candidates", target, camera)
	_expect(not candidates.is_empty(), "Visible live rig supplies a concrete witness")
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["eye"] as Vector3).distance_squared_to(at) < (b["eye"] as Vector3).distance_squared_to(at))
	var specific: Array[Dictionary] = [candidates[0]]
	var eye: Vector3 = specific[0]["eye"]
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var panel := BoxShape3D.new()
	panel.size = Vector3(0.30, 2.0, 1.0)
	collider.shape = panel
	blocker.add_child(collider)
	blocker.position = eye.lerp(target, 0.5)
	var wanted := Wanted.new()
	var ignore: Array[RID] = []
	_expect(wanted.witnesses(director.get_world_3d().direct_space_state, target, specific, ignore)["any"],
		"Actual visible NPC can see a close unobstructed incident")
	director.call("react_to_incident", target, 4.0, ignore)
	await _ticks(4)
	var states: Dictionary = director.call("stats")["movement"]
	_expect("ALERT" in states.values(), "A nearby actor physically reacts to an unobstructed incident")
	director.add_child(blocker)
	await physics_frame
	await physics_frame
	_expect(not wanted.witnesses(director.get_world_3d().direct_space_state, target, specific, ignore)["any"],
		"Solid occlusion blocks the new witness through the existing wanted ray")
	blocker.queue_free()
	camera.look_at(camera.global_position + Vector3.BACK)
	var old_witness: RID = specific[0]["rid"]
	var offscreen: Array[Dictionary] = director.call("witness_candidates", target, camera)
	_expect(offscreen.all(func(entry: Dictionary) -> bool: return entry["rid"] != old_witness),
		"Offscreen actors do not generate witness records")
