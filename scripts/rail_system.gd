extends Node3D
## Fixed elevated transit corridor. Stations have street-level boarding/elevator
## markers, so boarding never requires climbing procedural geometry.
const STATIONS = [-116.0, 0.0, 116.0]
const TRACK_Z = -58.0
const TRAIN_LEVEL = 12.7
var train: Node3D
var speed := 0.0
var next_station := 1
var current_station := 0
var direction := 1
var dwell_remaining := 8.0
var _initialized := false

func _ready() -> void:
	_build_track_and_stations()
	train = Node3D.new()
	train.name = "MorrowLineTrain"
	add_child(train)
	train.position = Vector3(STATIONS[0], TRAIN_LEVEL, TRACK_Z)
	_build_train()

func _process(delta: float) -> void:
	if not _initialized:
		_initialized = true
	if dwell_remaining > 0.0:
		dwell_remaining = maxf(0.0, dwell_remaining - delta)
		speed = 0.0
		return
	var destination: float = STATIONS[next_station]
	var distance := absf(destination - train.position.x)
	var braking_speed := sqrt(2.0 * 2.5 * maxf(distance - 0.3, 0.0))
	var target_speed := minf(17.0, braking_speed)
	speed = move_toward(speed, target_speed, 2.8 * delta)
	var travel := signf(destination - train.position.x)
	train.position.x += travel * minf(speed * delta, distance)
	if distance < 0.55 or absf(train.position.x - destination) <= 0.30:
		train.position.x = destination
		current_station = next_station
		dwell_remaining = 8.0
		speed = 0.0
		if current_station == STATIONS.size() - 1:
			direction = -1
		elif current_station == 0:
			direction = 1
		next_station = current_station + direction

func boardable_from(at: Vector3) -> bool:
	if dwell_remaining <= 0.1:
		return false
	var entrance := station_entrance(current_station)
	return Vector2(at.x - entrance.x, at.z - entrance.z).length() < 9.0

func can_alight() -> bool:
	return dwell_remaining > 0.05

func station_entrance(index: int) -> Vector3:
	return Vector3(STATIONS[clampi(index, 0, STATIONS.size() - 1)] + 9.0, 1.15, -48.0)

func alight_position() -> Vector3:
	return station_entrance(current_station)

func station_name() -> String:
	return ["BRICKWATER CROSSING", "CENTRAL EXCHANGE", "HELIX TERMINAL"][current_station]

func snapshot() -> Dictionary:
	return {"x": train.position.x, "next_station": next_station,
		"current_station": current_station, "direction": direction,
		"speed": speed, "dwell": dwell_remaining}

func restore(data: Dictionary) -> void:
	train.position.x = clampf(float(data.get("x", STATIONS[0])), STATIONS[0], STATIONS[STATIONS.size() - 1])
	current_station = clampi(int(data.get("current_station", 0)), 0, STATIONS.size() - 1)
	next_station = clampi(int(data.get("next_station", 1)), 0, STATIONS.size() - 1)
	direction = -1 if int(data.get("direction", 1)) < 0 else 1
	speed = clampf(float(data.get("speed", 0.0)), 0.0, 17.0)
	dwell_remaining = clampf(float(data.get("dwell", 0.0)), 0.0, 8.0)

func get_counts() -> Dictionary:
	return {"trains": 1, "stations": STATIONS.size(), "elevated": true}

func _build_track_and_stations() -> void:
	for offset in [-1.15, 1.15]:
		_box(Vector3(0.0, 11.9, TRACK_Z + offset), Vector3(380.0, 0.24, 0.28), Color("b2a79c"))
	_box(Vector3(0.0, 11.45, TRACK_Z), Vector3(378.0, 0.43, 5.6), Color("3c4c60"))
	for x in [-145.0, -87.0, -29.0, 29.0, 87.0, 145.0]:
		# Off-center piers leave the through lanes and intersection boxes clear.
		_box(Vector3(x, 5.9, TRACK_Z + 5.3), Vector3(1.4, 11.7, 1.4), Color("5c6772"))
		_box(Vector3(x, 11.5, TRACK_Z + 2.6), Vector3(5.4, 0.56, 5.8), Color("57687c"))
	for index in range(STATIONS.size()):
		var x: float = STATIONS[index]
		_box(Vector3(x, 11.3, TRACK_Z + 4.4), Vector3(28.0, 0.35, 3.8), Color("8397a0"))
		_box(Vector3(x, 15.3, TRACK_Z + 4.4), Vector3(28.0, 0.36, 4.4), Color("273e57"))
		for dx in [-11.0, 11.0]:
			_box(Vector3(x + dx, 13.4, TRACK_Z + 5.95), Vector3(0.36, 4.0, 0.36), Color("87949d"))
		# Lift shaft at a fixed pedestrian entrance on the corner sidewalk.
		var entrance := station_entrance(index)
		_box(Vector3(entrance.x, 5.3, entrance.z), Vector3(2.9, 10.4, 2.9), Color("354d60"))
		_box(Vector3(entrance.x, 2.0, entrance.z - 1.56), Vector3(1.8, 3.2, 0.12), Color("69c5d4"), true)
		var label := Label3D.new()
		label.text = "M-LINE / " + ["BRICKWATER", "CENTRAL", "HELIX"][index]
		label.pixel_size = 0.008
		label.font_size = 35
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("c0f4ee")
		label.position = entrance + Vector3.UP * 4.4
		add_child(label)

func _build_train() -> void:
	for carriage in [-5.1, 5.1]:
		_box(Vector3(carriage, 0.0, 0.0), Vector3(9.6, 2.9, 3.25), Color("c4d7d4"), false, train)
		_box(Vector3(carriage, -0.15, -1.67), Vector3(8.4, 1.0, 0.11), Color("284e65"), false, train)
		_box(Vector3(carriage, -0.98, -1.72), Vector3(9.1, 0.22, 0.12), Color("52c7c9"), true, train)
		for window in range(4):
			var x := carriage - 3.2 + float(window) * 2.05
			_box(Vector3(x, 0.28, -1.73), Vector3(1.24, 0.83, 0.07), Color("77b5c4"), false, train)
	_box(Vector3(10.1, 0.25, 0.0), Vector3(0.22, 0.75, 2.15), Color("c5e8a9"), true, train)

func _box(at: Vector3, size: Vector3, color: Color, glow: bool = false, target: Node3D = null) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.40
	material.roughness = 0.47
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	node.material_override = material
	(target if target != null else self).add_child(node)
