extends RefCounted
## Pure data population for future streamed civilian cars. No Node, mesh,
## physics, witness, audio, or bus creation. Existing live traffic stays intact.
const MAX_CARS = 128
const MAX_ACTIVE = 16
const MAX_CHANGES = 2
const SPAWN_MIN = 70.0
const SPAWN_MAX = 160.0
const RECYCLE_MIN = 190.0
const CLEARANCE = 9.0
const PALETTE = ["ce7777", "5d8db4", "9a7fbc", "d7bd84", "7cb79e", "c6cdd3"]
var _routes: Dictionary = {}
var _cars: Dictionary = {}

func configure(seed_value: int, specs: Array[Dictionary]) -> void:
	_routes.clear()
	_cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 928377
	for spec in specs:
		var id := str(spec.get("id", ""))
		var path: Variant = spec.get("path", [])
		var count := clampi(int(spec.get("count", 0)), 0, MAX_CARS - _cars.size())
		if id.is_empty() or _routes.has(id) or not path is Array or path.size() < 2 or count == 0:
			continue
		var points: Array[Vector3] = []
		var valid := true
		for point in path:
			if not point is Vector3 or not point.is_finite():
				valid = false
				break
			points.append(point)
		if not valid:
			continue
		var length := 0.0
		for i in range(points.size()):
			var span := points[i].distance_to(points[(i+1) % points.size()])
			if span <= 0.01:
				valid = false
			length += span
		if not valid or not is_finite(length):
			continue
		_routes[id] = {"path":points,"length":length}
		for i in range(count):
			var vehicle_id := "%s-%02d" % [id,i]
			if _cars.has(vehicle_id):
				continue
			var fraction := fposmod((float(i) + rng.randf_range(-0.14,0.14)) / float(count), 1.0)
			var tint: String = PALETTE[rng.randi_range(0,PALETTE.size()-1)]
			var speed := 9.4 + rng.randf_range(0.0,2.4)
			_cars[vehicle_id] = {"id":vehicle_id,"route":id,"phase":fraction,"speed":speed,"paint":tint}

func sample(id: String) -> Dictionary:
	if not _cars.has(id):
		return {}
	var car: Dictionary = _cars[id]
	var route: Dictionary = _routes[car["route"]]
	var path: Array[Vector3] = route["path"]
	var distance := float(car["phase"]) * float(route["length"])
	for i in range(path.size()):
		var next := (i+1) % path.size()
		var span := path[i].distance_to(path[next])
		if distance < span or i == path.size()-1:
			return {"id":id,"position":path[i].lerp(path[next],clampf(distance/span,0.0,1.0)),
				"heading":(path[next]-path[i]).normalized(),"next_index":next,
				"speed":car["speed"],"paint":car["paint"],"route":car["route"]}
		distance -= span
	return {}

func ids() -> Array:
	return _cars.keys()

func advance(seconds: float, active_ids: Array) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	var active := {}
	for id in active_ids:
		active[id] = true
	for id in _cars:
		if active.has(id):
			continue
		var car: Dictionary = _cars[id]
		var length: float = _routes[car["route"]]["length"]
		car["phase"] = fposmod(float(car["phase"]) + fposmod(seconds, length / float(car["speed"])) * float(car["speed"]) / length, 1.0)

func capture_live(id: String, position: Vector3, next_index: int) -> bool:
	# Called by a future pool on release; project actual position onto its
	# current segment rather than advancing the same vehicle twice.
	if not _cars.has(id) or not position.is_finite():
		return false
	var car: Dictionary = _cars[id]
	var route: Dictionary = _routes[car["route"]]
	var path: Array[Vector3] = route["path"]
	if next_index < 0 or next_index >= path.size():
		return false
	var previous := posmod(next_index-1,path.size())
	var axis := path[next_index]-path[previous]
	var fraction := clampf((position-path[previous]).dot(axis)/axis.length_squared(),0.0,1.0)
	if position.distance_to(path[previous]+axis*fraction) > 5.0:
		return false
	var distance := 0.0
	for i in range(previous):
		distance += path[i].distance_to(path[(i+1)%path.size()])
	car["phase"] = fposmod((distance+axis.length()*fraction)/float(route["length"]),1.0)
	return true

func snapshot() -> Dictionary:
	var phases := {}
	for id in _cars:
		phases[id] = _cars[id]["phase"]
	return {"phases":phases}

func restore(value: Variant) -> void:
	if not value is Dictionary or not value.get("phases") is Dictionary:
		return
	var phases: Dictionary = value["phases"]
	for id in _cars:
		var phase: Variant = phases.get(id)
		if (phase is float or phase is int) and is_finite(float(phase)) and float(phase) >= 0.0 and float(phase) < 1.0:
			_cars[id]["phase"] = float(phase)

func plan_changes(focus: Vector3, camera: Vector3, speed: float, indoors: bool,
		active_positions: Dictionary, occupied: Array[Vector3], can_spawn: Callable, can_hide: Callable) -> Dictionary:
	# Callers must supply real loaded-collision, frustum and clearance checks.
	# No callback means no changes. Active IDs map to LIVE vehicle positions;
	# the logical phase of an active vehicle is not its physical position.
	var result := {"activate":[],"recycle":[]}
	if indoors or not focus.is_finite() or not camera.is_finite() or not is_finite(speed) or not can_spawn.is_valid() or not can_hide.is_valid():
		return result
	var guard := SPAWN_MIN + clampf(absf(speed)*1.5,0.0,50.0)
	for id in active_positions:
		if not _cars.has(id):
			continue
		var at: Variant = active_positions[id]
		if not at is Vector3 or not at.is_finite():
			continue
		if at.distance_to(focus) >= RECYCLE_MIN and at.distance_to(camera) >= RECYCLE_MIN and bool(can_hide.call(at)):
			result["recycle"].append(id)
			if result["recycle"].size() >= MAX_CHANGES:
				return result
	var remaining := maxi(0,MAX_ACTIVE-active_positions.size()+result["recycle"].size())
	var candidates: Array[Dictionary] = []
	for id in _cars:
		if active_positions.has(id):
			continue
		var entry := sample(id)
		var at: Vector3 = entry["position"]
		var distance := at.distance_to(focus)
		if distance < guard or distance > SPAWN_MAX or at.distance_to(camera) < guard:
			continue
		entry["distance"] = distance
		candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]),float(b["distance"])):
			return str(a["id"]) < str(b["id"])
		return float(a["distance"]) < float(b["distance"]))
	var reserved := occupied.duplicate()
	for at in active_positions.values():
		if at is Vector3 and at.is_finite():
			reserved.append(at)
	for entry in candidates:
		if remaining <= 0 or result["activate"].size()+result["recycle"].size() >= MAX_CHANGES:
			break
		var at: Vector3 = entry["position"]
		var clear := true
		for other in reserved:
			var gap := Vector2(at.x-other.x,at.z-other.z)
			if gap.length() < CLEARANCE:
				clear = false
				break
		if not clear or not bool(can_spawn.call(at)):
			continue
		result["activate"].append(entry)
		reserved.append(at)
		remaining -= 1
	return result
