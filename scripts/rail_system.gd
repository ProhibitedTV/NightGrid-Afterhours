extends Node3D
## Fixed elevated transit corridor. Stations have street-level boarding/elevator
## markers, so boarding never requires climbing procedural geometry.
const STATIONS = [-232.0, -116.0, 0.0, 116.0, 232.0]
const TrainVisual = preload("res://scripts/m_line_train_visual.gd")
const Materials = preload("res://scripts/material_library.gd")
const STATION_NAMES = ["WEST QUAY GATE", "BRICKWATER CROSSING", "CENTRAL EXCHANGE", "HELIX TERMINAL", "EAST GARDENS"]
const TRACK_Z = -58.0
const TRAIN_LEVEL = 12.7
var train: Node3D
var train_visual: Node3D
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
	train_visual = TrainVisual.new()
	train_visual.name = "CicadaM8HeroVisual"
	train.add_child(train_visual)
	_sync_train_visual()

func _sync_train_visual() -> void:
	if train_visual != null:
		train_visual.call("set_operational_state", direction, speed, dwell_remaining > 0.1)

func _process(delta: float) -> void:
	if not _initialized:
		_initialized = true
	if dwell_remaining > 0.0:
		dwell_remaining = maxf(0.0, dwell_remaining - delta)
		speed = 0.0
		_sync_train_visual()
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
	_sync_train_visual()

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
	return STATION_NAMES[current_station]

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
	_sync_train_visual()

func get_map_stations() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(STATIONS.size()):
		var at := station_entrance(index)
		result.append(Vector2(at.x, at.z))
	return result

func get_counts() -> Dictionary:
	return {"trains": 1, "stations": STATIONS.size(), "elevated": true}

func get_train_visual_stats() -> Dictionary:
	return train_visual.call("get_visual_stats") if train_visual != null else {}

func get_station_visual_stats() -> Dictionary:
	return {"stations": STATIONS.size(), "sleeper_instances": 171, "platform_signs": STATIONS.size() * 2}

func _build_track_and_stations() -> void:
	# One rail corridor, fixed geographically in every save. Components outside
	# walking height are decorative to preserve traffic signal/road clearance.
	_box(Vector3(0.0, 11.48, TRACK_Z), Vector3(518.0, 0.44, 5.6), Color("344757"), false, null, "METAL")
	_box(Vector3(0.0, 11.77, TRACK_Z), Vector3(518.0, 0.19, 4.94), Color("232f3c"), false, null, "METAL")
	for offset in [-1.15, 1.15]:
		_box(Vector3(0.0, 11.97, TRACK_Z + float(offset)),
			Vector3(520.0, 0.18, 0.16), Color("b4b9b4"), false, null, "METAL")
		_box(Vector3(0.0, 11.86, TRACK_Z + float(offset)),
			Vector3(520.0, 0.11, 0.36), Color("46515d"), false, null, "METAL")
	_build_sleepers()
	for x in [-203.0, -145.0, -87.0, -29.0, 29.0, 87.0, 145.0, 203.0]:
		# Bridge structural load paths read as engineered steel/concrete,
		# while piers still avoid through lanes.
		_box(Vector3(x, 5.91, TRACK_Z + 5.25),
			Vector3(1.45, 11.75, 1.45), Color("63717c"), false, null, "CONCRETE")
		_box(Vector3(x, 11.25, TRACK_Z + 2.73),
			Vector3(6.65, 0.68, 6.35), Color("576b76"), false, null, "METAL")
		for foot in [-0.5, 0.5]:
			_box(Vector3(x + float(foot), 2.6, TRACK_Z + 5.25),
				Vector3(0.18, 5.1, 1.65), Color("3b4b57"), false, null, "METAL")
	for index in range(STATIONS.size()):
		_build_station(index)

func _build_sleepers() -> void:
	# 171 ties in one MultiMesh draw call rather than 171 scene nodes.
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var ties := MultiMesh.new()
	ties.transform_format = MultiMesh.TRANSFORM_3D
	ties.mesh = mesh
	ties.instance_count = 171
	for i in range(171):
		var x := -255.0 + float(i) * 3.0
		ties.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.25, 0.14, 4.4)),
			Vector3(x, 11.84, TRACK_Z)))
	var view := MultiMeshInstance3D.new()
	view.name = "RailSleepers171"
	view.multimesh = ties
	view.material_override = Materials.surface("METAL", Color("4a515b"))
	add_child(view)

func _build_station(index: int) -> void:
	var x: float = STATIONS[index]
	var platform := Node3D.new()
	platform.name = "MLineStation_%02d" % index
	platform.position = Vector3(x, 0.0, TRACK_Z)
	add_child(platform)
	# Door thresholds and platform top are at approximately the same level.
	_station_box(platform, Vector3(0.0, 12.04, 4.1),
		Vector3(29.5, 0.36, 4.5), "CONCRETE", Color("8498a1"))
	_station_box(platform, Vector3(0.0, 12.25, 4.1),
		Vector3(28.2, 0.065, 4.04), "PAVERS", Color("6d8490"))
	_station_box(platform, Vector3(0.0, 12.30, 2.18),
		Vector3(27.5, 0.032, 0.23), "EMISSION", Color("f6b66b"))
	_station_box(platform, Vector3(0.0, 12.29, 2.48),
		Vector3(27.5, 0.036, 0.20), "RUBBER", Color("302c2f"))
	# Safety edge: repeated tactile tiles, not an uncued open platform.
	for tile in range(22):
		_station_box(platform, Vector3(-13.1 + float(tile) * 1.24, 12.30, 2.67),
			Vector3(0.77, 0.033, 0.13), "METAL", Color("c4aa76"))
	# Structural canopy is high enough above the M8 roof hardware.
	_station_box(platform, Vector3(0.0, 15.88, 4.62),
		Vector3(29.1, 0.25, 5.05), "METAL", Color("253d50"))
	_station_box(platform, Vector3(0.0, 16.04, 4.62),
		Vector3(28.4, 0.06, 4.81), "METAL", Color("758c98"))
	for dx in [-12.8, -6.4, 0.0, 6.4, 12.8]:
		_station_box(platform, Vector3(dx, 15.68, 4.62),
			Vector3(0.18, 0.16, 4.79), "METAL", Color("697d8c"))
		for side in [3.07, 6.22]:
			_station_box(platform, Vector3(dx, 14.05, side),
				Vector3(0.25, 3.68, 0.25), "METAL", Color("7c8c91"))
	for dx in [-10.5, -3.5, 3.5, 10.5]:
		_station_box(platform, Vector3(dx, 15.70, 4.05),
			Vector3(3.6, 0.08, 0.21), "EMISSION", Color("c5e7df"))
	# Glazing, wayfinding and floating display panels give each stop an identity.
	for dx in [-12.6, 12.6]:
		_station_box(platform, Vector3(dx, 13.40, 6.21),
			Vector3(0.12, 2.0, 2.75), "TRANSPARENT_GLASS", Color(0.34, 0.54, 0.60, 0.48))
		_station_box(platform, Vector3(dx, 14.45, 6.21),
			Vector3(0.17, 0.10, 2.92), "METAL", Color("a7aca5"))
	_station_box(platform, Vector3(0.0, 14.75, 6.13),
		Vector3(12.2, 0.72, 0.16), "METAL", Color("1a2a39"))
	_station_box(platform, Vector3(0.0, 14.76, 6.23),
		Vector3(11.6, 0.067, 0.048), "EMISSION", Color("5ee7d8"))
	_station_label(platform, "M-LINE  /  " + STATION_NAMES[index],
		Vector3(0.0, 14.78, 6.31), Color("e0eee5"), 36)
	_station_label(platform, "%02d   ALL NIGHT  //  MORROW BAY" % [index + 1],
		Vector3(0.0, 13.44, 6.31), Color("8fd3d1"), 24)
	# Visible elevated pedestrian bridge ties the lift shaft to the platform;
	# the original street-level instant boarding contract is unchanged.
	_station_box(platform, Vector3(9.0, 12.10, 7.7),
		Vector3(2.5, 0.24, 5.4), "METAL", Color("647d86"))
	for walkway_side in [-1.0, 1.0]:
		_station_box(platform, Vector3(9.0 + walkway_side * 1.24, 13.03, 7.7),
			Vector3(0.075, 1.76, 5.38), "TRANSPARENT_GLASS", Color(0.30, 0.50, 0.57, 0.42))
		_station_box(platform, Vector3(9.0 + walkway_side * 1.24, 13.87, 7.7),
			Vector3(0.12, 0.10, 5.40), "METAL", Color("a2b0a7"))
	# Street-level entrance remains exactly where boarding/saving expects it.
	var entrance := station_entrance(index)
	_box(Vector3(entrance.x, 6.13, entrance.z), Vector3(3.15, 12.15, 3.15),
		Color("405766"), false, null, "METAL")
	for side in [-1.0, 1.0]:
		_box(Vector3(entrance.x + side * 1.57, 6.10, entrance.z + 0.01),
			Vector3(0.11, 11.7, 2.9), Color("a4aaa1"), false, null, "METAL")
	_box(Vector3(entrance.x, 2.02, entrance.z - 1.64),
		Vector3(2.1, 3.3, 0.12), Color("5d929b"), false, null, "GLASS")
	_box(Vector3(entrance.x, 3.82, entrance.z - 1.70),
		Vector3(2.38, 0.19, 0.16), Color("70e0d5"), true)
	_box(Vector3(entrance.x, 4.68, entrance.z - 1.66),
		Vector3(2.5, 0.43, 0.15), Color("263847"), false, null, "METAL")
	var entrance_label := Label3D.new()
	entrance_label.name = "MLineStreetWayfinding"
	entrance_label.text = "M  /  " + STATION_NAMES[index]
	entrance_label.font_size = 34
	entrance_label.pixel_size = 0.007
	entrance_label.modulate = Color("b8f1e9")
	entrance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	entrance_label.position = entrance + Vector3.UP * 4.62
	add_child(entrance_label)

func _station_box(parent: Node3D, at: Vector3, dimensions: Vector3, kind: String,
		tint: Color) -> void:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	obj.mesh = mesh
	obj.position = at
	if kind == "EMISSION":
		var glow := StandardMaterial3D.new()
		glow.albedo_color = tint.darkened(0.7)
		glow.emission_enabled = true
		glow.emission = tint
		glow.emission_energy_multiplier = 1.55
		obj.material_override = glow
	elif kind == "RUBBER":
		var matte := StandardMaterial3D.new()
		matte.albedo_color = tint
		matte.roughness = 0.95
		obj.material_override = matte
	elif kind == "TRANSPARENT_GLASS":
		var glass := StandardMaterial3D.new()
		glass.albedo_color = tint
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.15
		glass.metallic = 0.04
		obj.material_override = glass
	else:
		obj.material_override = Materials.surface(kind, tint)
	parent.add_child(obj)

func _station_label(parent: Node3D, message: String, at: Vector3, tint: Color, size: int) -> void:
	var sign := Label3D.new()
	sign.text = message
	sign.font_size = size
	sign.pixel_size = 0.006
	sign.position = at
	sign.modulate = tint
	sign.outline_modulate = Color("111b26")
	sign.outline_size = 8
	parent.add_child(sign)

func _box(at: Vector3, size: Vector3, color: Color, glow: bool = false,
		target: Node3D = null, surface_kind: String = "") -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	if not surface_kind.is_empty():
		node.material_override = Materials.surface(surface_kind, color)
	else:
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
