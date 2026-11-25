extends Node3D
## Fixed elevated transit corridor with accessible lifts and solid platforms.
const STATIONS = [-232.0, -116.0, 0.0, 116.0, 232.0]
const TrainVisual = preload("res://scripts/m_line_train_visual.gd")
const Materials = preload("res://scripts/material_library.gd")
const StationLift = preload("res://scripts/m_line_station_lift.gd")
const STATION_NAMES = ["WEST QUAY GATE", "BRICKWATER CROSSING", "CENTRAL EXCHANGE", "HELIX TERMINAL", "EAST GARDENS"]
const TRACK_Z = -58.0
const TRAIN_LEVEL = 12.7
const PLATFORM_FLOOR = 12.2825
const PIER_SETBACK = 11.1
const LIFT_X = 11.25
const LIFT_Z = 12.02
const DOOR_BOARD_WIDTH = 1.65
const DOOR_CLOSE_CUTOFF = 0.1
var train: Node3D
var train_visual: Node3D
var speed := 0.0
var next_station := 1
var current_station := 0
var direction := 1
var dwell_remaining := 8.0
var _initialized := false
var _lifts: Array[Node3D] = []
var _arrival_boards: Array[Label3D] = []
var _board_clock := 0.0
# Godot 4.3 lacks built-in 3D physics interpolation; only the visual child
# is smoothed between fixed-tick simulation positions.
var _previous_train_x := STATIONS[0]
var _current_train_x := STATIONS[0]

func _ready() -> void:
	_build_track_and_stations()
	train = Node3D.new()
	train.name = "MorrowLineTrain"
	add_child(train)
	train.position = Vector3(STATIONS[0], TRAIN_LEVEL, TRACK_Z)
	_previous_train_x = train.position.x
	_current_train_x = train.position.x
	train_visual = TrainVisual.new()
	train_visual.name = "CicadaM8HeroVisual"
	train.add_child(train_visual)
	_sync_train_visual()
	_refresh_arrival_boards()

func _sync_train_visual() -> void:
	if train_visual != null:
		train_visual.call("set_operational_state", direction, speed, doors_open())
		train_visual.call("set_destination", STATION_NAMES[next_station])

func _physics_process(delta: float) -> void:
	_board_clock += delta
	if _board_clock >= 0.25:
		_board_clock = 0.0
		_refresh_arrival_boards()
	# The timetable, position and saves advance ONLY on fixed physics ticks.
	_previous_train_x = train.position.x if absf(train.position.x - _current_train_x) > 0.5 else _current_train_x
	if not _initialized:
		_initialized = true
	if dwell_remaining > 0.0:
		dwell_remaining = maxf(0.0, dwell_remaining - delta)
		speed = 0.0
		_current_train_x = train.position.x
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
	_current_train_x = train.position.x
	_sync_train_visual()

func _process(_delta: float) -> void:
	if train == null or train_visual == null:
		return
	# Detect restore, scene staging and direct teleports without flythrough.
	if absf(train.position.x - _current_train_x) > 0.5:
		_reset_render_history()
		return
	var fraction := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	train_visual.position.x = lerpf(_previous_train_x, _current_train_x, fraction) - train.position.x

func _reset_render_history() -> void:
	_previous_train_x = train.position.x
	_current_train_x = train.position.x
	if train_visual != null:
		train_visual.position.x = 0.0

func doors_open() -> bool:
	return dwell_remaining > DOOR_CLOSE_CUTOFF

func station_board_text(index: int) -> String:
	if index < 0 or index >= STATIONS.size():
		return ""
	var terminal: String = STATION_NAMES[-1] if direction > 0 else STATION_NAMES[0]
	if index == current_station and doors_open():
		return "BOARD NOW / %ds\nTO %s" % [ceili(dwell_remaining), terminal]
	if index == current_station and dwell_remaining > 0.0:
		return "DOORS CLOSING\nTO %s" % terminal
	if index == next_station:
		return "NEXT STOP / WAIT\nTO %s" % terminal
	return "WAIT ON PLATFORM\nNEXT STOP: %s" % STATION_NAMES[next_station]

func _refresh_arrival_boards() -> void:
	for i in range(_arrival_boards.size()):
		var board := _arrival_boards[i]
		var message := station_board_text(i)
		if board.text != message:
			board.text = message

func boardable_from(at: Vector3) -> bool:
	if not doors_open():
		return false
	if on_platform(at, current_station):
		if at.z > TRACK_Z + 5.2:
			return false
		for center in TrainVisual.CAR_CENTERS:
			if absf(at.x - train.position.x - float(center)) < DOOR_BOARD_WIDTH:
				return true
		return false
	# Retain the legacy curb shortcut at the four original pickup markers.
	if current_station == STATIONS.size() - 1 or at.y < 0.3 or at.y > 2.5:
		return false
	var entrance := station_entrance(current_station)
	return Vector2(at.x - entrance.x, at.z - entrance.z).length() < 9.0

func on_platform(at: Vector3, index: int) -> bool:
	if index < 0 or index >= STATIONS.size() or not at.is_finite():
		return false
	var across := at.z - TRACK_Z
	return absf(at.x - STATIONS[index]) < 13.6 and across > 2.55 and across < 5.95 and (
		at.y > PLATFORM_FLOOR + 0.55 and at.y < PLATFORM_FLOOR + 2.0)

func lift_at(at: Vector3) -> Node3D:
	for lift in _lifts:
		if lift.call("can_request", at):
			return lift
	return null

func can_alight() -> bool:
	return doors_open()

func station_entrance(index: int) -> Vector3:
	return Vector3(STATIONS[clampi(index, 0, STATIONS.size() - 1)] + 9.0, 1.15, -48.0)

func alight_position(platform: bool = false) -> Vector3:
	if platform:
		return Vector3(STATIONS[current_station] + float(TrainVisual.CAR_CENTERS[1]),
			PLATFORM_FLOOR + 0.97, TRACK_Z + 3.75)
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
	_reset_render_history()
	_sync_train_visual()
	_refresh_arrival_boards()

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
	# The 14 m carriageway stays open under the deck.
	# A steel transfer girder brings the load back to the curbside pier.
	_station_box(self, Vector3(0.0, 11.48, TRACK_Z), Vector3(518.0, 0.44, 5.6),
		"METAL", Color("344757"), "MLineGuideway")
	for side in [-1.0, 1.0]:
		_station_box(self, Vector3(0.0, 10.64, TRACK_Z + side * 1.77),
			Vector3(518.0, 1.28, 0.73), "METAL", Color("344653"), "MLineStringer_%d" % int(side))
	_box(Vector3(0.0, 11.77, TRACK_Z), Vector3(518.0, 0.19, 4.94), Color("232f3c"), false, null, "METAL")
	for offset in [-1.15, 1.15]:
		_box(Vector3(0.0, 11.97, TRACK_Z + float(offset)),
			Vector3(520.0, 0.18, 0.16), Color("b4b9b4"), false, null, "METAL")
		_box(Vector3(0.0, 11.86, TRACK_Z + float(offset)),
			Vector3(520.0, 0.11, 0.36), Color("46515d"), false, null, "METAL")
	_build_sleepers()
	for x in [-203.0, -145.0, -87.0, -29.0, 29.0, 87.0, 145.0, 203.0]:
		_station_box(self, Vector3(x, 5.20, TRACK_Z + PIER_SETBACK),
			Vector3(1.48, 10.4, 1.58), "CONCRETE", Color("63717c"), "MLinePier_%d" % int(x))
		_station_box(self, Vector3(x, 0.22, TRACK_Z + PIER_SETBACK),
			Vector3(1.74, 0.44, 1.94), "CONCRETE", Color("737e84"), "PierFooting_%d" % int(x))
		_station_box(self, Vector3(x, 10.72, TRACK_Z + 5.0),
			Vector3(1.62, 1.08, 14.0), "METAL", Color("576b76"), "PierGirder_%d" % int(x))
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
		Vector3(29.5, 0.36, 4.5), "CONCRETE", Color("8498a1"), "PlatformDeck")
	_station_box(platform, Vector3(0.0, 12.25, 4.1),
		Vector3(28.2, 0.065, 4.04), "PAVERS", Color("6d8490"), "PlatformWalkingSurface")
	for dx in [-10.0, 0.0, 10.0]:
		_station_box(platform, Vector3(dx, 11.49, 3.65),
			Vector3(0.65, 0.74, 5.55), "METAL", Color("526875"), "PlatformCrossbeam_%d" % int(dx))
	_station_box(platform, Vector3(0.0, 12.30, 2.18),
		Vector3(27.5, 0.032, 0.23), "EMISSION", Color("f6b66b"))
	_station_box(platform, Vector3(0.0, 12.29, 2.48),
		Vector3(27.5, 0.036, 0.20), "RUBBER", Color("302c2f"))
	# Safety edge: repeated tactile tiles, not an uncued open platform.
	for tile in range(22):
		_station_box(platform, Vector3(-13.1 + float(tile) * 1.24, 12.30, 2.67),
			Vector3(0.77, 0.033, 0.13), "METAL", Color("c4aa76"))
	for door_x in TrainVisual.CAR_CENTERS:
		_station_box(platform, Vector3(door_x, PLATFORM_FLOOR + 0.006, 3.45),
			Vector3(1.62, 0.012, 0.26), "EMISSION", Color("64b8ac"))
	# Structural canopy is high enough above the M8 roof hardware.
	_station_box(platform, Vector3(0.0, 15.88, 4.62),
		Vector3(29.1, 0.25, 5.05), "METAL", Color("253d50"), "PlatformCanopy")
	_station_box(platform, Vector3(0.0, 16.04, 4.62),
		Vector3(28.4, 0.06, 4.81), "METAL", Color("758c98"))
	for dx in [-12.8, -6.4, 0.0, 6.4, 12.8]:
		_station_box(platform, Vector3(dx, 15.68, 4.62),
			Vector3(0.18, 0.16, 4.79), "METAL", Color("697d8c"))
		for side in [3.07, 6.22]:
			_station_box(platform, Vector3(dx, 14.05, side),
				Vector3(0.25, 3.68, 0.25), "METAL", Color("7c8c91"), "CanopyPost_%d_%d" % [int(dx * 10.0), int(side)])
	for dx in [-10.5, -3.5, 3.5, 10.5]:
		_station_box(platform, Vector3(dx, 15.70, 4.05),
			Vector3(3.6, 0.08, 0.21), "EMISSION", Color("c5e7df"))
	# Glazing, wayfinding and floating display panels give each stop an identity.
	for dx in [-12.6, 12.6]:
		_station_box(platform, Vector3(dx, 13.40, 6.21),
			Vector3(0.12, 2.0, 2.75), "TRANSPARENT_GLASS", Color(0.34, 0.54, 0.60, 0.48), "WindScreen_%d" % int(dx))
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
	# Mounted passenger information faces the waiting platform, not the road.
	_station_box(platform, Vector3(-9.4, 14.44, 6.13),
		Vector3(5.6, 0.83, 0.18), "METAL", Color("1a2a39"))
	var arrival := Label3D.new()
	arrival.name = "LiveArrivalBoard"
	arrival.position = Vector3(-9.4, 14.44, 6.025)
	arrival.rotation.y = PI
	arrival.font_size = 25
	arrival.pixel_size = 0.007
	arrival.modulate = Color("a9ffe2")
	arrival.outline_size = 4
	arrival.double_sided = false
	platform.add_child(arrival)
	_arrival_boards.append(arrival)
	# Bridge clear width is 2.2 m. A real guardrail leaves a gap at the landing.
	_station_box(platform, Vector3(LIFT_X, PLATFORM_FLOOR - 0.12, 8.50),
		Vector3(2.43, 0.24, 4.73), "METAL", Color("647d86"), "LiftWalkway")
	_station_box(platform, Vector3(-2.27, 12.83, 6.30),
		Vector3(24.55, 1.10, 0.065), "TRANSPARENT_GLASS", Color(0.41, 0.58, 0.63, 0.45), "StreetGuardrail")
	_station_box(platform, Vector3(-2.27, 13.39, 6.30),
		Vector3(24.55, 0.10, 0.12), "METAL", Color("a2b0a7"), "StreetGuardrailCap")
	for side in [-1.0, 1.0]:
		_station_box(platform, Vector3(side * 14.67, 12.83, 4.16),
			Vector3(0.065, 1.10, 4.30), "TRANSPARENT_GLASS", Color(0.41, 0.58, 0.63, 0.45), "EndGuardrail_%d" % int(side))
	_station_box(platform, Vector3(13.57, 12.83, 6.30),
		Vector3(2.25, 1.10, 0.065), "TRANSPARENT_GLASS", Color(0.41, 0.58, 0.63, 0.45), "EastGuardrail")
	for walkway_side in [-1.0, 1.0]:
		_station_box(platform, Vector3(LIFT_X + walkway_side * 1.18, 12.86, 8.50),
			Vector3(0.075, 1.15, 4.72), "TRANSPARENT_GLASS", Color(0.30, 0.50, 0.57, 0.42), "WalkwayGuardrail_%d" % int(walkway_side))
		_station_box(platform, Vector3(LIFT_X + walkway_side * 1.18, 13.46, 8.50),
			Vector3(0.12, 0.10, 4.72), "METAL", Color("a2b0a7"), "WalkwayHandrail_%d" % int(walkway_side))
	var lift := StationLift.new()
	lift.name = "AccessibleLift"
	lift.position = Vector3(LIFT_X, 0.0, LIFT_Z)
	lift.platform_floor = PLATFORM_FLOOR
	lift.station_name = STATION_NAMES[index]
	platform.add_child(lift)
	_lifts.append(lift)

func _station_box(parent: Node3D, at: Vector3, dimensions: Vector3, kind: String,
		tint: Color, solid_name: String = "") -> void:
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
	if solid_name.is_empty():
		parent.add_child(obj)
		return
	var body := StaticBody3D.new()
	body.name = solid_name
	body.position = at
	obj.position = Vector3.ZERO
	body.add_child(obj)
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

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
