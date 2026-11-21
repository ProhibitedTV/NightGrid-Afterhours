extends Node3D
## A small, bounded, lane-following fleet; no free-roaming physics pathfinding.
## Road geometry and bus stops are fixed; traffic coloration/spacing is seeded.
const TrafficVehicle = preload("res://scripts/traffic_vehicle.gd")
const CELL = 58.0
var signals: Node
var fleet: Array[CharacterBody3D] = []
var buses: Array[CharacterBody3D] = []
var _rng := RandomNumberGenerator.new()
var _stops: Array[Vector3] = []

func initialize(world_seed: int, controller: Node) -> void:
	signals = controller
	_rng.seed = int(world_seed) ^ 928377
	var perimeter := loop_route(-232.0, 232.0, -232.0, 232.0, 1.0)
	var outer := loop_route(-174.0, 174.0, -174.0, 174.0, 1.0)
	var inner := loop_route(-116.0, 116.0, -116.0, 116.0, 1.0)
	var core := loop_route(-58.0, 58.0, -58.0, 58.0, 1.0)
	_spawn_loop("perimeter", perimeter, 8)
	_spawn_loop("outer", outer, 7)
	_spawn_loop("inner", inner, 6)
	_spawn_loop("core", core, 4)
	_stops = [
		Vector3(-41.0, 1.75, -112.75), Vector3(75.0, 1.75, -112.75),
		Vector3(112.75, 1.75, -41.0), Vector3(112.75, 1.75, 75.0),
		Vector3(41.0, 1.75, 112.75), Vector3(-75.0, 1.75, 112.75),
		Vector3(-112.75, 1.75, 41.0), Vector3(-112.75, 1.75, -75.0),
		# Outer connector, stopping after controlled junctions and near edge services.
		Vector3(-157.0, 1.75, -170.75), Vector3(75.0, 1.75, -170.75),
		Vector3(170.75, 1.75, -157.0), Vector3(170.75, 1.75, 75.0),
		Vector3(157.0, 1.75, 170.75), Vector3(-75.0, 1.75, 170.75),
		Vector3(-170.75, 1.75, 157.0), Vector3(-170.75, 1.75, -75.0)
	]
	var center_route := loop_route(-116.0, 116.0, -116.0, 116.0, 1.75)
	var connector_route := loop_route(-174.0, 174.0, -174.0, 174.0, 1.75)
	for bus_index in range(4):
		var bus := TrafficVehicle.new()
		bus.name = "CityBus_%d" % bus_index
		add_child(bus)
		var outside := bus_index >= 2
		var start_index := 0 if bus_index % 2 == 0 else 4
		var stop_offset := 8 if outside else 0
		var initial: Vector3 = _stops[stop_offset + start_index]
		bus.setup(connector_route if outside else center_route, 1 if bus_index % 2 == 0 else 3,
			initial, true, "bus-%d" % bus_index,
			Color("d6a276") if outside else Color("5aaebd"), signals, self)
		bus.stop_points = _stops.slice(8, 16) if outside else _stops.slice(0, 8)
		bus.dwell_remaining = 7.0
		bus.last_served = start_index
		fleet.append(bus)
		buses.append(bus)
	_build_bus_stops()

func loop_route(left: float, right: float, north: float, south: float, level: float) -> Array[Vector3]:
	# Right-side driving along a clockwise rectangular circulation route.
	return [
		Vector3(left + 3.25, level, north + 3.25),
		Vector3(right - 3.25, level, north + 3.25),
		Vector3(right - 3.25, level, south - 3.25),
		Vector3(left + 3.25, level, south - 3.25)
	]

func _spawn_loop(route_id: String, path: Array[Vector3], count: int) -> void:
	var palette := [Color("ce7777"), Color("5d8db4"), Color("9a7fbc"),
		Color("d7bd84"), Color("7cb79e"), Color("c6cdd3")]
	for i in range(count):
		var fraction := (float(i) + _rng.randf_range(-0.14, 0.14)) / float(count)
		var sample := sample_route(path, fposmod(fraction, 1.0))
		var car := TrafficVehicle.new()
		car.name = "AmbientCar_%s_%d" % [route_id, i]
		add_child(car)
		car.setup(path, int(sample["next_index"]), sample["position"], false,
			"%s-%02d" % [route_id, i], palette[_rng.randi_range(0, palette.size() - 1)], signals, self)
		car.cruise_speed = 9.4 + _rng.randf_range(0.0, 2.4)
		fleet.append(car)

func sample_route(path: Array[Vector3], fraction: float) -> Dictionary:
	var perimeter := 0.0
	for i in range(path.size()):
		perimeter += path[i].distance_to(path[(i + 1) % path.size()])
	var remaining := fposmod(fraction, 1.0) * perimeter
	for i in range(path.size()):
		var next := (i + 1) % path.size()
		var span := path[i].distance_to(path[next])
		if remaining <= span:
			return {"position": path[i].lerp(path[next], remaining / span), "next_index": next}
		remaining -= span
	return {"position": path[0], "next_index": 1}

func headway_speed_cap(candidate: CharacterBody3D, heading: Vector3, cap: float) -> float:
	# Approximate following distance using a longitudinal gap on the same lane.
	for other in fleet:
		if other == candidate or not is_instance_valid(other):
			continue
		var gap := other.global_position - candidate.global_position
		gap.y = 0.0
		var forward_distance := gap.dot(heading)
		if forward_distance < 0.0 or forward_distance >= 23.0:
			continue
		var lateral := (gap - heading * forward_distance).length()
		if lateral < 2.7:
			cap = minf(cap, maxf(0.0, (forward_distance - (10.0 if candidate.get("buses") else 7.0)) * 1.25))
	return cap

func get_boardable_bus(at: Vector3) -> CharacterBody3D:
	var nearest: CharacterBody3D
	var min_distance := 10.0
	for bus in buses:
		if not bus.call("is_boardable"):
			continue
		var dist := Vector2(at.x - bus.global_position.x, at.z - bus.global_position.z).length()
		if dist < min_distance:
			min_distance = dist
			nearest = bus
	return nearest

func snapshot() -> Dictionary:
	var vehicles := []
	for car in fleet:
		vehicles.append(car.call("snapshot"))
	return {"vehicles": vehicles}

func restore(data: Dictionary) -> void:
	var by_id := {}
	for entry in data.get("vehicles", []):
		if entry is Dictionary:
			by_id[str(entry.get("id", ""))] = entry
	for car in fleet:
		var identifier: String = car.get("vehicle_id")
		if by_id.has(identifier):
			car.call("apply_snapshot", by_id[identifier])

func bus_by_id(identifier: String) -> CharacterBody3D:
	for bus in buses:
		if str(bus.get("vehicle_id")) == identifier:
			return bus
	return null

func witness_candidates(target: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for car in fleet:
		if is_instance_valid(car) and car.global_position.distance_squared_to(target) <= 30.0 * 30.0:
			result.append({"eye": car.global_position + Vector3.UP * (1.05 if bool(car.get("buses")) else 0.65), "facing": -car.global_basis.z, "police": false, "rid": car.get_rid()})
	return result

func get_map_stops() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for stop in _stops:
		result.append(Vector2(stop.x, stop.z))
	return result

func get_counts() -> Dictionary:
	return {"ambient_cars": fleet.size() - buses.size(), "buses": buses.size(),
		"stops": _stops.size(), "signals": 81}

func _build_bus_stops() -> void:
	var directions := [Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.BACK,
		Vector3.LEFT, Vector3.LEFT, Vector3.FORWARD, Vector3.FORWARD,
		Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.BACK,
		Vector3.LEFT, Vector3.LEFT, Vector3.FORWARD, Vector3.FORWARD]
	for i in range(_stops.size()):
		# A bus runs clockwise: right hand door faces the nearest sidewalk.
		var right_side := Vector3(-directions[i].z, 0.0, directions[i].x)
		var base := _stops[i] + right_side * 8.0
		base.y = 0.24
		_stop_box(base + Vector3.UP * 1.45, Vector3(0.17, 2.9, 0.17), Color("b4b8b8"))
		_stop_box(base + Vector3.UP * 2.7, Vector3(1.55, 0.54, 0.19), Color("d5a959"), true)
		var name := Label3D.new()
		name.text = "B / OUTER CONNECTOR" if i >= 8 else "B / CITY LOOP"
		name.font_size = 35
		name.pixel_size = 0.008
		name.modulate = Color("fff2c5")
		name.position = base + Vector3.UP * 3.12
		name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(name)

func _stop_box(at: Vector3, dimensions: Vector3, color: Color, emissive: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
	instance.material_override = material
	add_child(instance)
