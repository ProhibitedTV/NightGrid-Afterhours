extends CharacterBody3D
const Materials = preload("res://scripts/material_library.gd")
const BusCoachwork = preload("res://scripts/bus_coachwork.gd")
const CarCoachwork = preload("res://scripts/civilian_car_coachwork.gd")
const StreamProfile = preload("res://scripts/streaming_profile.gd")
## Lightweight NPC street vehicle. Follows lane centerlines, obeys stop bars,
## slows for vehicles ahead and dwells at marked bus stops.
var route: Array[Vector3] = []
var next_index := 0
var speed := 0.0
var cruise_speed := 10.0
var buses := false
var vehicle_id := ""
var signals: Node
var fleet: Node
var stop_points: Array[Vector3] = []
var dwell_remaining := 0.0
var last_served := -1
var laps := 0
var paint := Color("4c90a3")
var _leased := false
var _detour: Array[Vector3] = []
var _detour_cursor := 0
var _detour_rejoin := -1
var _detour_hold := false
const HANDOFF_TOLERANCE = 0.55
const DETOUR_MAX_POINTS = 81
static var _wheel_sets: Dictionary = {}
static var _body_shapes: Dictionary = {}

func setup(path: Array[Vector3], first_index: int, position_at: Vector3, bus: bool, identifier: String, tint: Color, signal_controller: Node, owner_fleet: Node) -> void:
	buses = bus
	signals = signal_controller
	fleet = owner_fleet
	_assign_route(path, first_index, position_at, identifier, tint)
	cruise_speed = 8.5 if buses else 11.1
	floor_snap_length = 0.1
	_build_body()

func _assign_route(path: Array[Vector3], first_index: int, position_at: Vector3, identifier: String, tint: Color) -> void:
	route = path
	next_index = first_index % path.size()
	global_position = position_at
	var initial_direction := path[next_index] - position_at
	initial_direction.y = 0.0
	if initial_direction.length_squared() > 0.01:
		rotation.y = atan2(-initial_direction.x, -initial_direction.z)
	vehicle_id = identifier
	paint = tint

func lease_ambient(path: Array[Vector3], entry: Dictionary) -> void:
	_assign_route(path, int(entry["next_index"]), entry["position"], entry["id"], Color(entry["paint"]))
	_reset_detour()
	_detour_hold = false
	cruise_speed = entry["speed"]
	speed = 0.0
	velocity = Vector3.ZERO
	dwell_remaining = 0.0
	last_served = -1
	laps = 0
	_leased = true
	($CivilianCarCoachwork as MeshInstance3D).mesh = CarCoachwork.mesh_for(paint)
	collision_layer = 1
	collision_mask = 1
	reset_physics_interpolation()
	show()
	set_physics_process(true)

func park_ambient() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	hide()
	speed = 0.0
	velocity = Vector3.ZERO
	vehicle_id = ""
	_leased = false

func can_recycle() -> bool:
	return not _detour_hold and not finite_detour_active()

func _on_loop_leg(at: Vector3, index: int) -> bool:
	if route.size()<2 or index<0 or index>=route.size():
		return false
	var a := route[posmod(index-1,route.size())]
	var b := route[index]
	var axis := b-a
	if axis.length_squared()<1.0:
		return false
	var t := clampf((at-a).dot(axis)/axis.length_squared(),0.0,1.0)
	return at.distance_to(a+axis*t)<=HANDOFF_TOLERANCE

func begin_finite_detour(path: Array[Vector3], rejoin_index: int, certify: Callable) -> bool:
	# An external director must certify the route, collision geometry,
	# registry revision, approach reservation and save policy first.
	if buses or _detour_hold or not _detour.is_empty() or not certify.is_valid() or path.size()<2 or path.size()>DETOUR_MAX_POINTS:
		return false
	if not is_finite(speed) or absf(speed)>1.0 or not global_position.is_finite():
		return false
	if not path[0].is_finite() or not path[-1].is_finite() or global_position.distance_to(path[0])>HANDOFF_TOLERANCE:
		return false
	if not _on_loop_leg(path[0],next_index) or not _on_loop_leg(path[-1],rejoin_index):
		return false
	var previous_direction := (route[next_index]-route[posmod(next_index-1,route.size())]).normalized()
	for i in range(1,path.size()):
		if not path[i].is_finite() or absf(path[i].y-path[0].y)>0.02:
			return false
		var leg := path[i]-path[i-1]
		if leg.length()<3.0 or (absf(leg.x)>0.02 and absf(leg.z)>0.02) or previous_direction.dot(leg.normalized())< -0.5:
			return false
		previous_direction = leg.normalized()
	# End on an outgoing loop lane, not beyond its endpoint or facing back.
	var exit_direction := (route[rejoin_index]-path[-1]).normalized()
	if path[-1].distance_to(route[rejoin_index])<3.0 or exit_direction.dot(previous_direction)<0.99:
		return false
	if not bool(certify.call(path.duplicate(),rejoin_index)):
		return false
	_detour = path.duplicate()
	_detour_cursor = 1
	_detour_rejoin = rejoin_index
	return true

func finite_detour_active() -> bool:
	return not _detour.is_empty()

func _reset_detour() -> void:
	_detour.clear()
	_detour_cursor = 0
	_detour_rejoin = -1

func _physics_process(delta: float) -> void:
	if route.is_empty() or signals == null or fleet == null:
		return
	if dwell_remaining > 0.0:
		dwell_remaining = maxf(0.0, dwell_remaining - delta)
		speed = 0.0
		velocity = Vector3.ZERO
		return
	if _detour_hold:
		speed = 0.0
		velocity = Vector3.ZERO
		return
	var driving_started := StreamProfile.begin()
	var waypoint := _detour[_detour_cursor] if finite_detour_active() else route[next_index]
	var toward := waypoint - global_position
	toward.y = 0.0
	if finite_detour_active():
		if toward.length()<HANDOFF_TOLERANCE:
			if _detour_cursor+1<_detour.size():
				_detour_cursor += 1
				waypoint = _detour[_detour_cursor]
			else:
				# Re-enter the original route without modifying world position.
				next_index = _detour_rejoin
				_reset_detour()
				waypoint = route[next_index]
			toward = waypoint-global_position
			toward.y = 0.0
	elif toward.length() < 1.1:
		next_index = (next_index + 1) % route.size()
		if next_index == 0:
			laps += 1
		toward = route[next_index] - global_position
		toward.y = 0.0
	var direction := toward.normalized()
	if direction.length_squared() < 0.001:
		return
	var cap := cruise_speed
	cap = float(signals.call("approach_speed_cap", global_position, direction, cap))
	if _leased:
		cap = float(fleet.call("pooled_speed_cap", global_position, direction, cap))
	var headway_started := StreamProfile.begin()
	cap = float(fleet.call("headway_speed_cap", self, direction, cap))
	StreamProfile.accumulate(headway_started, "traffic_headway")
	# Reduce turning speed at the end of each block; no abrupt full-speed cornering.
	if toward.length() < 10.0:
		cap = minf(cap, 3.6 + toward.length() * 0.22)
	if buses:
		for stop_id in range(stop_points.size()):
			var stop := stop_points[stop_id]
			var gap := stop - global_position
			gap.y = 0.0
			var ahead := gap.dot(direction)
			var side_gap := (gap - direction * ahead).length()
			if stop_id == last_served and ahead < -13.0:
				last_served = -1
			if stop_id != last_served and ahead >= 0.0 and ahead < 21.0 and side_gap < 1.9:
				cap = minf(cap, maxf(0.0, (ahead - 0.65) * 0.92))
				if ahead < 1.7 and speed < 2.2:
					dwell_remaining = 7.0
					last_served = stop_id
					speed = 0.0
					velocity = Vector3.ZERO
					return
	speed = move_toward(speed, cap, (3.0 if speed < cap else 9.0) * delta)
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(delta * 5.5, 1.0))
	velocity = direction * speed
	StreamProfile.accumulate(driving_started, "traffic_control_including_headway")
	var collision_started := StreamProfile.begin()
	move_and_slide()
	StreamProfile.accumulate(collision_started, "traffic_move_and_slide")

func is_boardable() -> bool:
	return buses and dwell_remaining > 0.05

func alight_position() -> Vector3:
	return global_position + global_transform.basis.x * 6.5 + Vector3(0.0, -0.4, 0.0)

func snapshot() -> Dictionary:
	return {"id": vehicle_id, "position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "next_index": next_index, "speed": speed,
		"dwell": dwell_remaining, "last_served": last_served, "laps": laps,
		"detour_interrupted": finite_detour_active() or _detour_hold}

func apply_snapshot(data: Dictionary) -> void:
	if str(data.get("id", "")) != vehicle_id:
		return
	_reset_detour()
	# Never drive from a stale temporary route into an unrestricted loop.
	# A future director must implement certified restoration/recovery before
	# exposing live detours. Existing saves without this field stay unchanged.
	_detour_hold = data.get("detour_interrupted",false) == true
	var p: Array = data.get("position", [])
	if p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(data.get("yaw", rotation.y))
	next_index = clampi(int(data.get("next_index", next_index)), 0, route.size() - 1)
	speed = clampf(float(data.get("speed", 0.0)), 0.0, cruise_speed)
	dwell_remaining = clampf(float(data.get("dwell", 0.0)), 0.0, 8.0)
	last_served = clampi(int(data.get("last_served", -1)), -1, stop_points.size() - 1)
	laps = maxi(0, int(data.get("laps", 0)))

func _build_body() -> void:
	if not _body_shapes.has(buses):
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.7, 2.85, 8.3) if buses else Vector3(2.25, 1.55, 4.55)
		_body_shapes[buses] = shape
	var hitbox := CollisionShape3D.new()
	hitbox.shape = _body_shapes[buses]
	add_child(hitbox)
	var coach := BusCoachwork.build(paint) if buses else CarCoachwork.build(paint)
	coach.name = "CityBusCoachwork" if buses else "CivilianCarCoachwork"
	add_child(coach)
	if not _wheel_sets.has(buses):
		var radius := 0.44 if buses else CarCoachwork.TIRE_RADIUS
		_wheel_sets[buses] = [
			_wheel_batch(radius, 0.28, 14),
			_wheel_batch(radius * 0.47, 0.295, 12),
		]
	var tires := MultiMeshInstance3D.new()
	tires.name = "Tires"
	tires.multimesh = _wheel_sets[buses][0]
	tires.material_override = Materials.surface("ASPHALT", Color("171a20"))
	add_child(tires)
	var hubs := MultiMeshInstance3D.new()
	hubs.name = "Hubs"
	hubs.multimesh = _wheel_sets[buses][1]
	hubs.material_override = Materials.surface("METAL", Color("89939c"))
	add_child(hubs)

func _wheel_batch(radius: float, thickness: float, segments: int) -> MultiMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = thickness
	mesh.radial_segments = segments
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 4
	var axes := Basis(Vector3.BACK, PI * 0.5)
	var x := 1.18 if buses else 0.94
	var y := BusCoachwork.AXLE_Y if buses else CarCoachwork.AXLE_Y
	var axles: Array = BusCoachwork.AXLES if buses else CarCoachwork.AXLES
	var index := 0
	for side in [-1.0, 1.0]:
		for axle in axles:
			batch.set_instance_transform(index, Transform3D(axes, Vector3(side * x, y, axle)))
			index += 1
	return batch

