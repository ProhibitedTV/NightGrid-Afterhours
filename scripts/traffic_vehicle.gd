extends CharacterBody3D
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

func setup(path: Array[Vector3], first_index: int, position_at: Vector3, bus: bool, identifier: String, tint: Color, signal_controller: Node, owner_fleet: Node) -> void:
	route = path
	next_index = first_index % path.size()
	global_position = position_at
	buses = bus
	vehicle_id = identifier
	paint = tint
	signals = signal_controller
	fleet = owner_fleet
	cruise_speed = 8.5 if buses else 11.1
	floor_snap_length = 0.1
	_build_body()

func _physics_process(delta: float) -> void:
	if route.is_empty() or signals == null or fleet == null:
		return
	if dwell_remaining > 0.0:
		dwell_remaining = maxf(0.0, dwell_remaining - delta)
		speed = 0.0
		velocity = Vector3.ZERO
		return
	var waypoint := route[next_index]
	var toward := waypoint - global_position
	toward.y = 0.0
	if toward.length() < 1.1:
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
	cap = float(fleet.call("headway_speed_cap", self, direction, cap))
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
	move_and_slide()

func is_boardable() -> bool:
	return buses and dwell_remaining > 0.05

func alight_position() -> Vector3:
	return global_position + global_transform.basis.x * 6.5 + Vector3(0.0, -0.4, 0.0)

func snapshot() -> Dictionary:
	return {"id": vehicle_id, "position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "next_index": next_index, "speed": speed,
		"dwell": dwell_remaining, "last_served": last_served, "laps": laps}

func apply_snapshot(data: Dictionary) -> void:
	if str(data.get("id", "")) != vehicle_id:
		return
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
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.7, 2.85, 8.3) if buses else Vector3(2.25, 1.55, 4.55)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	add_child(hitbox)
	_box(Vector3(0.0, 0.0, 0.0), Vector3(2.6, 2.2, 8.1) if buses else Vector3(2.12, 0.78, 4.35), paint)
	_box(Vector3(0.0, 0.67, -0.15), Vector3(2.3, 0.75, 5.3) if buses else Vector3(1.72, 0.72, 2.20), Color("203849"))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.86, -0.08, -3.99 if buses else -2.15), Vector3(0.42, 0.19, 0.08), Color("ffdab5"), true)
		_box(Vector3(side * 0.86, -0.08, 3.99 if buses else 2.15), Vector3(0.42, 0.19, 0.08), Color("ff5276"), true)
		for axle in [-2.55, 2.55] if buses else [-1.4, 1.4]:
			_box(Vector3(side * 1.30, -0.88 if buses else -0.47, axle), Vector3(0.30, 0.62, 0.78), Color("131c25"))
	if buses:
		_box(Vector3(0.0, 1.34, -3.0), Vector3(2.34, 0.43, 0.18), Color("66dce6"), true)
		_box(Vector3(1.34, -0.15, 0.90), Vector3(0.07, 1.52, 1.48), Color("89a8ba"))

func _box(at: Vector3, dimensions: Vector3, color: Color, glow: bool = false) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.2
	material.roughness = 0.5
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	node.material_override = material
	add_child(node)
