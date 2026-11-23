extends Node3D
## Fixed-capacity pilot. Only live leases enter the traffic registries.
const Logic = preload("res://scripts/logical_traffic.gd")
const Safety = preload("res://scripts/streaming_safety.gd")
const Vehicle = preload("res://scripts/traffic_vehicle.gd")
const Coachwork = preload("res://scripts/civilian_car_coachwork.gd")
const Profile = preload("res://scripts/streaming_profile.gd")
const PERIOD = 0.20
const CELL = 58.0
const LANE_OFFSET = 3.25
const MAX_CLEARANCE_TESTS = 4
var model := Logic.new()
var _safety := Safety.new()
var _paths: Dictionary = {}
var _live: Dictionary = {}
var _available: Array[Vehicle] = []
var _clock := 0.0
var _traffic: Node3D
var _city: Node3D
var _road_rules: RefCounted
var _admitted := 0
var _retired := 0
var _peak := 0
var _clearance_denials := 0

func configure(owner: Node3D, signal_controller: Node, city_seed: int, specs: Array[Dictionary]) -> void:
	_traffic = owner
	model.configure(city_seed, specs)
	for spec in specs:
		_paths[spec["id"]] = spec["path"]
	for paint in Logic.PALETTE:
		Coachwork.mesh_for(Color(paint))
	var default_path: Array[Vector3] = specs[0]["path"]
	for slot in range(Logic.MAX_ACTIVE):
		var car := Vehicle.new()
		car.name = "AmbientSlot_%02d" % slot
		add_child(car)
		car.setup(default_path, 1, default_path[0], false, "", Color(Logic.PALETTE[0]), signal_controller, _traffic)
		car.park_ambient()
		_available.append(car)

func tick(delta: float, at: Vector3, speed: float, camera: Camera3D, city: Node3D,
		indoors: bool, occupied: Array[Vector3], road_rules: RefCounted) -> void:
	_city = city
	_road_rules = road_rules
	var started := Profile.begin()
	_safety.observe(camera, delta)
	_clock += delta
	if _clock < PERIOD:
		return
	model.advance(_clock, _live.keys())
	_clock = 0.0
	if indoors or not is_instance_valid(camera) or not camera.current:
		return
	var positions := {}
	for id in _live:
		positions[id] = _live[id].global_position
	var space := get_world_3d().direct_space_state
	var checks := [0]
	var can_spawn := func(candidate: Vector3) -> bool:
		if checks[0] >= MAX_CLEARANCE_TESTS or not legal_lane(candidate, road_rules):
			return false
		if not _safety.hidden(camera, candidate, Safety.VEHICLE_RADIUS):
			return false
		checks[0] += 1
		var clear := Safety.clear_grounded_volume(city, space, candidate, Safety.VEHICLE_RADIUS, 2.0, candidate.y - 1.0)
		_clearance_denials += int(not clear)
		return clear
	var can_hide := func(candidate: Vector3) -> bool:
		return _safety.hidden(camera, candidate, Safety.VEHICLE_RADIUS)
	var plan := model.plan_changes(at, camera.global_position, speed, false, positions, occupied, can_spawn, can_hide)
	var registry: Array[CharacterBody3D] = _traffic.get("fleet")
	for id in plan["recycle"]:
		var car: Vehicle = _live[id]
		if car.can_recycle() and model.capture_live(id, car.global_position, car.next_index):
			if Profile.enabled:
				_record_transition("ambient_traffic_recycle", id, car.global_position, at, camera)
			_release(id, car, registry)
			_retired += 1
	for entry in plan["activate"]:
		if _available.is_empty():
			break
		var car: Vehicle = _available.pop_back()
		car.lease_ambient(_paths[entry["route"]], entry)
		_live[entry["id"]] = car
		registry.append(car)
		_admitted += 1
		if Profile.enabled:
			_record_transition("ambient_traffic_admit", entry["id"], car.global_position, at, camera)
	_peak = maxi(_peak, _live.size())
	Profile.accumulate(started, "ambient_traffic_leases")

func _record_transition(kind: String, id: String, position: Vector3, actor: Vector3, camera: Camera3D) -> void:
	var started := Profile.begin()
	Profile.end(started, kind, {
		"id":id, "position":[position.x, position.y, position.z],
		"actor_distance": actor.distance_to(position), "camera_distance": camera.global_position.distance_to(position),
		"in_expanded_frustum": not Safety.outside_expanded_view(camera, position, Safety.VEHICLE_RADIUS),
	})

func safe_speed_cap(at: Vector3, heading: Vector3, cap: float) -> float:
	if not is_instance_valid(_city):
		return 0.0
	var lead := at + heading * 14.0
	if not _city.call("is_spawn_area_ready", lead, Safety.VEHICLE_RADIUS):
		return 0.0
	var along_x := absf(heading.x) > absf(heading.z)
	var street := Vector2i(roundi(lead.x / CELL), roundi(lead.z / CELL))
	var end: Vector2i
	if along_x:
		street.x = floori(lead.x / CELL)
		end = street + Vector2i.RIGHT
	else:
		street.y = floori(lead.z / CELL)
		end = street + Vector2i.DOWN
	return 0.0 if _road_rules.call("is_closed", street, end) else cap

func _release(id: String, car: Vehicle, registry: Array[CharacterBody3D]) -> void:
	registry.erase(car)
	_live.erase(id)
	car.park_ambient()
	_available.append(car)

static func legal_lane(at: Vector3, road_rules: RefCounted) -> bool:
	var junction := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	var dx := absf(at.x - junction.x * CELL)
	var dz := absf(at.z - junction.y * CELL)
	var span := Vector2i.ZERO
	var start := junction
	if absf(dx - LANE_OFFSET) < 0.06 and dz >= 12.0:
		start.y = floori(at.z / CELL)
		span = Vector2i.DOWN
	elif absf(dz - LANE_OFFSET) < 0.06 and dx >= 12.0:
		start.x = floori(at.x / CELL)
		span = Vector2i.RIGHT
	return span != Vector2i.ZERO and not road_rules.call("is_closed", start, start + span)

func restore(data: Dictionary) -> void:
	var registry: Array[CharacterBody3D] = _traffic.get("fleet")
	for id in _live.keys():
		_release(id, _live[id], registry)
	_clock = 0.0
	var phases: Variant = data.get("logical", {})
	model.restore(phases)
	if phases is Dictionary and phases.get("phases") is Dictionary:
		return
	for entry in data.get("vehicles", []):
		if not entry is Dictionary:
			continue
		var point: Variant = entry.get("position")
		if point is Array and point.size() == 3:
			model.capture_live(str(entry.get("id", "")), Vector3(float(point[0]), float(point[1]), float(point[2])),
				int(entry.get("next_index", -1)))

func append_snapshot(snapshot: Dictionary) -> void:
	if _clock > 0.0:
		model.advance(_clock, _live.keys())
		_clock = 0.0
	for id in model.ids():
		if _live.has(id):
			var car: Vehicle = _live[id]
			model.capture_live(id, car.global_position, car.next_index)
			continue
		var sample := model.sample(id)
		var at: Vector3 = sample["position"]
		var heading: Vector3 = sample["heading"]
		snapshot["vehicles"].append({"id": id, "position": [at.x, at.y, at.z],
			"next_index": sample["next_index"], "yaw": atan2(-heading.x, -heading.z), "speed": sample["speed"]})
	snapshot["logical"] = model.snapshot()

func stats() -> Dictionary:
	return {"logical_cars":model.ids().size(), "leased_cars":_live.size(), "lease_capacity":Logic.MAX_ACTIVE,
		"peak_leases":_peak, "activated":_admitted, "recycled":_retired, "clearance_denials":_clearance_denials}
