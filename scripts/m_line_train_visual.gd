extends Node3D
## M-LINE / CICADA M8 — original, procedural hero rolling stock.
## Art direction: real transit engineering beneath an optimistic neon-noir skin.
## Static meshes/materials are built once, never randomized or serialized.
const Materials = preload("res://scripts/material_library.gd")
const CAR_CENTERS = [-5.1, 5.1]
const CAR_HALF_LENGTH = 4.75
const CAB_END = 9.85
const WINDOW_X = [-3.40, -2.27, 2.27, 3.40]
const BODY_COLOR = Color("a9bfc0")
const TRIM_COLOR = Color("223849")
const COPPER = Color("c29b77")
const TEAL = Color("5ee7d8")
const PASSENGER_LIGHT = Color("c5e9e7")
const GLASS_TINT = Color(0.29, 0.54, 0.62, 0.69)

var _materials: Dictionary = {}
var _doors: Array[Dictionary] = []
var _cab_lights: Array[Dictionary] = []
var _headlight_spots: Array[SpotLight3D] = []
var _last_direction := 1
var _speed := 0.0
var _stopped := true
var _door_fraction := 0.0
var _visual_stats := {
	"cars": 0, "glass_windows": 0, "door_panels": 0,
	"bogies": 0, "wheels": 0, "headlamps": 0,
	"stationary_components": 0
}

func _ready() -> void:
	for center in CAR_CENTERS:
		_build_car(float(center))
	_build_connection()
	_build_cabs()
	set_operational_state(1, 0.0, true)

func set_operational_state(travel_direction: int, velocity: float, stopped_at_station: bool) -> void:
	_last_direction = 1 if travel_direction >= 0 else -1
	_speed = maxf(0.0, velocity)
	_stopped = stopped_at_station
	# Only the leading cab emits white light; the trailing end shows red markers.
	for lamp in _cab_lights:
		var leading: bool = int(lamp["end"]) == _last_direction
		var light_node: MeshInstance3D = lamp["mesh"]
		light_node.material_override = _surface("EMISSION", Color("e2ffeb") if leading else Color("ff5269"))
	for spot in _headlight_spots:
		spot.visible = _speed > 0.5 and int(spot.get_meta("end")) == _last_direction

func _process(delta: float) -> void:
	# Purely cosmetic doors. Movement, platform boarding and save-state remain
	# owned by rail_system.gd; visual animation must never block travel.
	var target := 1.0 if _stopped else 0.0
	_door_fraction = move_toward(_door_fraction, target, delta * 2.4)
	for door in _doors:
		var panel: Node3D = door["node"]
		panel.position.x = float(door["center"]) + float(door["half"]) * 0.66 * _door_fraction

func door_open_fraction() -> float:
	return _door_fraction

func get_visual_stats() -> Dictionary:
	return _visual_stats.duplicate()

func _surface(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + "/" + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var result: StandardMaterial3D
	if kind == "METAL" or kind == "GLASS" or kind == "CONCRETE":
		result = Materials.surface(kind, tint)
	else:
		result = StandardMaterial3D.new()
		result.albedo_color = tint
		if kind == "EMISSION":
			result.albedo_color = tint.darkened(0.65)
			result.emission_enabled = true
			result.emission = tint
			result.emission_energy_multiplier = 2.15
			result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		elif kind == "RUBBER":
			result.metallic = 0.0
			result.roughness = 0.90
		elif kind == "PAINT":
			result.metallic = 0.30
			result.roughness = 0.38
		elif kind == "INTERIOR":
			result.metallic = 0.08
			result.roughness = 0.66
		elif kind == "TRANSPARENT_GLASS":
			result.albedo_color = tint
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			result.metallic = 0.05
			result.roughness = 0.11
			result.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			result.metallic = 0.12
			result.roughness = 0.55
	_materials[key] = result
	return result

func _box(parent: Node3D, label_name: String, at: Vector3, size: Vector3, kind: String, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _surface(kind, tint)
	parent.add_child(node)
	_visual_stats["stationary_components"] += 1
	return node

func _cylinder(parent: Node3D, label_name: String, at: Vector3, radius: float,
		length: float, kind: String, tint: Color, axis: String = "Y", segments: int = 14) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = at
	if axis == "X":
		node.rotation.z = PI * 0.5
	elif axis == "Z":
		node.rotation.x = PI * 0.5
	node.material_override = _surface(kind, tint)
	parent.add_child(node)
	_visual_stats["stationary_components"] += 1
	return node

func _label(parent: Node3D, message: String, at: Vector3,
		tint: Color, size: int, rotation_y: float = 0.0) -> void:
	var sign := Label3D.new()
	sign.text = message
	sign.position = at
	sign.rotation.y = rotation_y
	sign.font_size = size
	sign.pixel_size = 0.0032
	sign.modulate = tint
	sign.outline_modulate = Color("07121b")
	sign.outline_size = 6
	sign.no_depth_test = false
	parent.add_child(sign)

func _hull_mesh() -> ArrayMesh:
	# An extruded bevelled side profile, not a stack of rectangular boxes.
	# The two long side-window bands are deliberately open, exposing a
	# furnished cabin behind transparent glazing and real structural posts.
	var section := [
		Vector2(-1.25, -0.63), Vector2(-1.51, -0.39),
		Vector2(-1.51, 0.82), Vector2(-1.36, 1.22),
		Vector2(-1.04, 1.51), Vector2(0.0, 1.57),
		Vector2(1.04, 1.51), Vector2(1.36, 1.22),
		Vector2(1.51, 0.82), Vector2(1.51, -0.39),
		Vector2(1.25, -0.63)
	]
	var spans := [-CAR_HALF_LENGTH, -4.34, 4.34, CAR_HALF_LENGTH]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(spans.size() - 1):
		var x0: float = spans[i]
		var x1: float = spans[i + 1]
		for edge in range(section.size()):
			# Skip the window-height panels on the left and right sides.
			if edge == 1 or edge == 8:
				continue
			var next: int = (edge + 1) % section.size()
			var a := _hull_vertex(x0, section[edge])
			var b := _hull_vertex(x1, section[edge])
			var c := _hull_vertex(x1, section[next])
			var d := _hull_vertex(x0, section[next])
			_add_triangle(tool, a, c, b)
			_add_triangle(tool, a, d, c)
	# Solid end bulkheads bookend each open passenger cabin.
	for end in [-CAR_HALF_LENGTH, CAR_HALF_LENGTH]:
		for edge in range(section.size()):
			var next: int = (edge + 1) % section.size()
			var first := _hull_vertex(float(end), section[edge])
			var second := _hull_vertex(float(end), section[next])
			var core := Vector3(float(end), 0.38, 0.0)
			if end < 0.0:
				_add_triangle(tool, core, first, second)
			else:
				_add_triangle(tool, core, second, first)
	tool.generate_normals()
	return tool.commit()

func _hull_vertex(x: float, profile: Vector2) -> Vector3:
	var nose := 0.91 if absf(x) > 4.5 else 1.0
	return Vector3(x, profile.y, profile.x * nose)

func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a, b, c]:
		tool.set_uv(Vector2(vertex.x * 0.16, vertex.y * 0.22))
		tool.add_vertex(vertex)

func _build_car(center: float) -> void:
	var car := Node3D.new()
	car.name = "CicadaCar_%s" % ("West" if center < 0.0 else "East")
	car.position.x = center
	add_child(car)
	_visual_stats["cars"] += 1
	var hull := MeshInstance3D.new()
	hull.name = "BevelledAlloyMonocoque"
	hull.mesh = _hull_mesh()
	hull.material_override = _surface("PAINT", BODY_COLOR)
	car.add_child(hull)
	# Inner floor, kick-plate, seam and roof architecture have real thickness.
	_box(car, "NonSlipCabinFloor", Vector3(0.0, -0.45, 0.0),
		Vector3(9.0, 0.15, 2.65), "INTERIOR", Color("30404c"))
	_box(car, "GraphiteUndertray", Vector3(0.0, -0.64, 0.0),
		Vector3(9.20, 0.23, 2.67), "RUBBER", Color("1a2631"))
	_box(car, "RoofServiceSpine", Vector3(0.0, 1.66, 0.0),
		Vector3(8.55, 0.14, 1.08), "METAL", Color("415962"))
	for side in [-1.0, 1.0]:
		# The continuous copper reveals and cyan running strips visually align
		# adjacent cars, while the daylight paint remains neutral.
		_box(car, "LowerCopperReveal", Vector3(0.0, -0.42, side * 1.505),
			Vector3(9.17, 0.073, 0.07), "METAL", COPPER)
		_box(car, "NightLine", Vector3(0.0, -0.55, side * 1.52),
			Vector3(8.90, 0.035, 0.045), "EMISSION", TEAL)
		_box(car, "UpperWindowHeader", Vector3(0.0, 0.95, side * 1.48),
			Vector3(9.20, 0.12, 0.12), "PAINT", TRIM_COLOR)
		# Real cabin cutout covered by tinted, semi-transparent glazing.
		for wx in WINDOW_X:
			_build_window(car, float(wx), side)
		_build_doors(car, side)
		# Mullions, emergency strips and roof fasteners are carefully scaled,
		# unlike repetitive 1m-width prototype blockouts.
		for rib in [-4.45, -3.95, -2.82, -1.75, -0.96, 0.96, 1.75, 2.82, 3.95, 4.45]:
			_box(car, "WindowMullion", Vector3(float(rib), 0.23, side * 1.505),
				Vector3(0.10, 1.35, 0.10), "METAL", TRIM_COLOR)
		for grille_x in [-3.5, 2.75]:
			for slot in range(6):
				_box(car, "VentCut", Vector3(float(grille_x) + float(slot) * 0.14,
					-0.23, side * 1.515), Vector3(0.075, 0.10, 0.028),
					"RUBBER", Color("111e2b"))
		_label(car, "M  /  MORROW LINE", Vector3(-3.30, -0.13, side * 1.57),
			Color("e4d4b6"), 34, PI if side < 0.0 else 0.0)
		_label(car, "CICADA M8  •  08", Vector3(2.82, -0.13, side * 1.57),
			Color("91b9c2"), 28, PI if side < 0.0 else 0.0)
	# Furnish the actual see-through cabin (seats, poles and light troughs).
	_build_interior(car)
	for bogie_x in [-2.98, 2.98]:
		_build_bogie(car, float(bogie_x))
	for roof_x in [-3.2, 3.0]:
		_box(car, "HVAC", Vector3(float(roof_x), 1.81, 0.0),
			Vector3(2.05, 0.23, 0.94), "METAL", Color("6c858b"))
		for slot in range(5):
			_box(car, "HVACLouvre", Vector3(float(roof_x) - 0.79 + float(slot) * 0.38,
				1.94, 0.0), Vector3(0.10, 0.025, 0.78),
				"RUBBER", Color("253b43"))
	_cylinder(car, "CableConduit", Vector3(0.0, 1.80, -0.79),
		0.045, 8.2, "METAL", COPPER, "X", 10)
	_cylinder(car, "CableConduit", Vector3(0.0, 1.80, 0.79),
		0.045, 8.2, "METAL", COPPER, "X", 10)

func _build_window(car: Node3D, x: float, side: float) -> void:
	_box(car, "WindowGasket", Vector3(x, 0.24, side * 1.515),
		Vector3(1.035, 1.11, 0.065), "RUBBER", Color("142935"))
	_box(car, "CabinGlazing", Vector3(x, 0.24, side * 1.557),
		Vector3(0.87, 0.96, 0.028), "TRANSPARENT_GLASS", GLASS_TINT)
	_box(car, "WindowSafetyStripe", Vector3(x, -0.10, side * 1.584),
		Vector3(0.80, 0.023, 0.010), "METAL", Color("afc9c4"))
	_visual_stats["glass_windows"] += 1

func _build_doors(car: Node3D, side: float) -> void:
	_box(car, "DoorPocket", Vector3(0.0, 0.20, side * 1.515),
		Vector3(2.02, 1.71, 0.055), "RUBBER", Color("142431"))
	for half in [-1.0, 1.0]:
		var panel := Node3D.new()
		panel.name = "SlidingDoor_%s" % ("L" if half < 0.0 else "R")
		panel.position = Vector3(half * 0.44, 0.0, side * 1.57)
		car.add_child(panel)
		_box(panel, "BrushedAlloyPanel", Vector3(0.0, 0.20, 0.0),
			Vector3(0.83, 1.68, 0.08), "METAL", BODY_COLOR)
		_box(panel, "DoorVisionLite", Vector3(0.0, 0.37, side * 0.049),
			Vector3(0.53, 0.92, 0.016), "TRANSPARENT_GLASS", GLASS_TINT)
		_box(panel, "SafetyChevron", Vector3(-half * 0.32, -0.18, side * 0.065),
			Vector3(0.055, 0.30, 0.018), "EMISSION", Color("ffbd80"))
		_box(panel, "DoorGrab", Vector3(-half * 0.26, -0.34, side * 0.072),
			Vector3(0.035, 0.25, 0.027), "METAL", Color("edf2d5"))
		_doors.append({"node": panel, "center": panel.position.x, "half": half})
		_visual_stats["door_panels"] += 1
	_box(car, "OverdoorStatus", Vector3(0.0, 1.14, side * 1.55),
		Vector3(1.67, 0.06, 0.05), "EMISSION", TEAL)
	for marker in [-0.80, 0.80]:
		_box(car, "DoorPost", Vector3(float(marker), 0.22, side * 1.61),
			Vector3(0.075, 1.72, 0.055), "METAL", Color("d2c2a6"))

func _build_interior(car: Node3D) -> void:
	_box(car, "LitInteriorCeiling", Vector3(0.0, 1.27, 0.0),
		Vector3(8.65, 0.06, 2.4), "INTERIOR", Color("c5d5cf"))
	for side in [-1.0, 1.0]:
		_box(car, "SoftCeilingLight", Vector3(0.0, 1.19, side * 0.95),
			Vector3(8.1, 0.05, 0.10), "EMISSION", PASSENGER_LIGHT)
	for seat_x in [-3.38, -2.2, 2.2, 3.38]:
		for side in [-1.0, 1.0]:
			_box(car, "FloatingSeatBase", Vector3(float(seat_x), -0.12, side * 1.03),
				Vector3(0.82, 0.12, 0.67), "INTERIOR", Color("435c65"))
			_box(car, "CushionedBack", Vector3(float(seat_x), 0.18, side * 1.35),
				Vector3(0.78, 0.65, 0.10), "INTERIOR", Color("47666c"))
			_box(car, "SeatHeadrest", Vector3(float(seat_x), 0.48, side * 1.33),
				Vector3(0.70, 0.14, 0.13), "PAINT", Color("baac96"))
	for post_x in [-1.69, 1.69]:
		_cylinder(car, "Handrail", Vector3(float(post_x), 0.44, 0.0),
			0.032, 1.63, "METAL", Color("cbb68a"), "Y", 10)

func _build_bogie(car: Node3D, bogie_x: float) -> void:
	_box(car, "BogieFrame", Vector3(bogie_x, -0.80, 0.0),
		Vector3(1.85, 0.28, 2.05), "METAL", Color("293842"))
	_box(car, "PrimarySuspension", Vector3(bogie_x, -0.76, 0.0),
		Vector3(0.49, 0.34, 1.38), "RUBBER", Color("1d2931"))
	_visual_stats["bogies"] += 1
	for axle in [-0.51, 0.51]:
		for side in [-1.0, 1.0]:
			var pos := Vector3(bogie_x + float(axle), -0.88, side * 1.05)
			_cylinder(car, "FlangedRailWheel", pos, 0.32, 0.15,
				"METAL", Color("566b75"), "Z", 16)
			_cylinder(car, "WheelBoss", pos + Vector3(0.0, 0.0, side * 0.097),
				0.16, 0.175, "METAL", Color("b8b2a0"), "Z", 12)
			_visual_stats["wheels"] += 1

func _build_connection() -> void:
	# Two cars remain independent, with a visible sealed gangway, bellows,
	# flexing joint shields and link hardware. Geometry does not alter movement.
	_box(self, "GangwayRubberSleeve", Vector3(0.0, 0.29, 0.0),
		Vector3(0.72, 2.07, 2.58), "RUBBER", Color("1b2b34"))
	for fold in [-0.27, -0.09, 0.09, 0.27]:
		_box(self, "AccordionRib", Vector3(float(fold), 0.31, 0.0),
			Vector3(0.042, 2.15, 2.66), "METAL", Color("4e6268"))
	_box(self, "GangwayCoupler", Vector3(0.0, -0.77, 0.0),
		Vector3(1.0, 0.24, 0.73), "METAL", Color("505962"))
	_box(self, "ArticulationRoof", Vector3(0.0, 1.55, 0.0),
		Vector3(0.65, 0.18, 2.61), "RUBBER", Color("293b42"))

func _build_cabs() -> void:
	for end in [-1, 1]:
		var x := float(end) * CAB_END
		var cab := Node3D.new()
		cab.name = "WestCab" if end < 0 else "EastCab"
		cab.position.x = x
		add_child(cab)
		# Driver windscreen has a real frame with a dark anti-glare ceramic edge.
		_box(cab, "CabGlassFrame", Vector3(0.0, 0.56, 0.0),
			Vector3(0.12, 1.36, 2.18), "RUBBER", Color("142b38"))
		_box(cab, "CabWindshield", Vector3(float(end) * 0.073, 0.58, 0.0),
			Vector3(0.027, 1.19, 1.96), "TRANSPARENT_GLASS", GLASS_TINT)
		_box(cab, "FrontCrumpleSkirt", Vector3(float(end) * 0.04, -0.56, 0.0),
			Vector3(0.30, 0.24, 2.69), "METAL", TRIM_COLOR)
		_box(cab, "DestinationLightbox", Vector3(float(end) * 0.14, 1.33, 0.0),
			Vector3(0.15, 0.20, 1.70), "EMISSION", Color("68dcd4"))
		for side in [-1.0, 1.0]:
			var lamp := _box(cab, "ReversibleMarkerLamp",
				Vector3(float(end) * 0.205, -0.27, side * 0.97),
				Vector3(0.075, 0.15, 0.40), "EMISSION", Color("e2ffeb"))
			_cab_lights.append({"end": end, "mesh": lamp})
			_visual_stats["headlamps"] += 1
		var beam := SpotLight3D.new()
		beam.name = "DirectionalHeadlamp"
		beam.position = Vector3(float(end) * 0.23, -0.21, 0.0)
		beam.rotation.y = -PI * 0.5 if end > 0 else PI * 0.5
		beam.spot_range = 29.0
		beam.spot_angle = 38.0
		beam.light_energy = 0.8
		beam.light_color = Color("cdece9")
		beam.shadow_enabled = false
		beam.set_meta("end", end)
		beam.visible = false
		cab.add_child(beam)
		_headlight_spots.append(beam)
		_label(cab, "M8  //  NIGHT SERVICE",
			Vector3(float(end) * 0.20, 1.30, 0.0),
			Color("0c202a"), 24, PI * 0.5 if end > 0 else -PI * 0.5)
