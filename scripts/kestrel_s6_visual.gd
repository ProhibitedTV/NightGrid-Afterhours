extends Node3D
const AudioMix = preload("res://scripts/audio_mix.gd")
## KESTREL S6 — an original player-drivable, four-seat EV hero body.
## Authored rear coachwork shares one imported mesh set across the fleet.
## The parent CharacterBody3D owns all real movement, collision and saves.
const Materials = preload("res://scripts/material_library.gd")
const VehicleAudio = preload("res://scripts/kestrel_vehicle_audio.gd")
const RearAssembly = preload("res://assets/models/nightgrid/kestrel_s6_rear/rear_lod0.gltf")
const CoachworkNormal = preload("res://assets/models/nightgrid/kestrel_s6_front/crimson_micro_normal.png")
const BODY_LENGTH = 4.65
const WHEEL_RADIUS = 0.41
const BODY_COLOR = Color("afc6c5")
const STEEL = Color("b2b6b0")
const WINDOW_TINT = Color(0.27, 0.43, 0.49, 0.72)
const GLASS_DARK = Color(0.16, 0.28, 0.35, 0.68)
const AMBER = Color("efb778")
const CYAN = Color("65dacd")

var _paint := Color("6e9ea9")
var _police := false
var _built := false
var _materials: Dictionary = {}
var _wheel_rotors: Array[Node3D] = []
var _steering_pivots: Array[Node3D] = []
var _brake_lenses: Array[MeshInstance3D] = []
var _reverse_lenses: Array[MeshInstance3D] = []
var _police_lenses: Array[MeshInstance3D] = []
var _beams: Array[SpotLight3D] = []
var _motor: AudioStreamPlayer3D
var _motor_active := false
var _motor_load := 0.0
var _signal_clock := 0.0
var _wheel_angle := 0.0
var _brake_active := false
var _reversing := false
var _speed := 0.0
static var _front_shell: ArrayMesh
static var _brake_material: StandardMaterial3D
static var _reverse_material: StandardMaterial3D
var _visual_stats := {
	"wheels": 0, "cabins": 0, "transparent_glass": 0,
	"seats": 0, "headlamps": 0, "brake_lamps": 0,
	"door_reveals": 0, "body_panels": 0, "hero_components": 0
}

func configure(paint: Color, police: bool = false) -> void:
	assert(not _built)
	_paint = paint
	_police = police

func _ready() -> void:
	if _built:
		return
	_built = true
	_build_body()
	_build_cabin()
	_build_road_gear()
	_build_lights()
	_build_interior()
	_build_sound()
	if _police:
		_build_police_equipment()

func update_motion(speed: float, steer: float, braking: bool,
		occupied: bool, police: bool, delta: float) -> void:
	# Animation is driven by actual vehicle motion, not synthetic movement.
	var acceleration := (absf(speed) - absf(_speed)) / maxf(delta, 0.001)
	_motor_active = occupied or police
	_motor_load = move_toward(_motor_load, clampf(acceleration / 12.0, 0.0, 1.0), delta * 4.0)
	_speed = speed
	_wheel_angle = fposmod(_wheel_angle + speed * delta / WHEEL_RADIUS, TAU)
	for rotor in _wheel_rotors:
		rotor.rotation.x = -_wheel_angle
	for pivot in _steering_pivots:
		pivot.rotation.y = clampf(steer * 0.28, -0.28, 0.28)
	if braking != _brake_active:
		_brake_active = braking
		for lens in _brake_lenses:
			lens.material_override = _brake_material if braking else null
	var reversing := speed < -0.4
	if reversing != _reversing:
		_reversing = reversing
		for lens in _reverse_lenses:
			lens.material_override = _reverse_material if reversing else null
	for beam in _beams:
		# Keep unshadowed headlamps bounded to occupied and pursuing cars,
		# not the whole parked fleet.
		beam.visible = occupied or police
	if _police:
		_signal_clock = fposmod(_signal_clock + delta * 3.8, 2.0)
		var blue_on := _signal_clock < 1.0
		for idx in range(_police_lenses.size()):
			var is_blue := idx % 2 == 0
			_police_lenses[idx].material_override = _mat("LED",
				Color("438fff") if police and is_blue and blue_on else
				Color("ff4768") if police and (not is_blue) and (not blue_on) else Color("293c55"))

func _process(delta: float) -> void:
	if _motor == null:
		return
	var target := -80.0
	if _motor_active:
		if not _motor.playing:
			_motor.play()
		target = lerpf(-35.0, -17.0, clampf(absf(_speed) / 32.0, 0.0, 1.0))
		target += _motor_load * 5.0
	_motor.volume_db = move_toward(_motor.volume_db, target, delta * 120.0)
	_motor.pitch_scale = lerpf(_motor.pitch_scale,
		clampf(0.82 + absf(_speed) * 0.016 + _motor_load * 0.11, 0.82, 1.49),
		1.0 - exp(-8.0 * delta))
	if not _motor_active and _motor.volume_db < -75.0:
		_motor.stop()

func get_visual_stats() -> Dictionary:
	return _visual_stats.duplicate()

func get_motion_state() -> Dictionary:
	return {
		"wheel_rotation": _wheel_angle,
		"steering": _steering_pivots[0].rotation.y if not _steering_pivots.is_empty() else 0.0,
		"braking": _brake_active, "speed": _speed,
		"live_beams": _active_light_count()
	}

func _active_light_count() -> int:
	var count := 0
	for beam in _beams:
		if beam.visible:
			count += 1
	return count

func _mat(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + "/" + tint.to_html(true)
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D
	if kind == "METAL" or kind == "ASPHALT" or kind == "CONCRETE":
		material = Materials.surface(kind, tint)
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = tint
		match kind:
			"PAINT":
				material.metallic = 0.28
				material.roughness = 0.32
				material.clearcoat_enabled = true
				material.clearcoat = 0.38
				material.clearcoat_roughness = 0.23
			"REAR_PAINT":
				material.metallic = 0.43
				material.roughness = 0.235
				material.normal_enabled = true
				material.normal_texture = CoachworkNormal
				material.normal_scale = 0.10
				material.clearcoat_enabled = true
				material.clearcoat = 0.84
				material.clearcoat_roughness = 0.12
			"RUBBER":
				material.roughness = 0.94
			"GLAZING":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.metallic = 0.035
				material.roughness = 0.12
			"LED":
				material.albedo_color = tint.darkened(0.66)
				material.emission_enabled = true
				material.emission = tint
				material.emission_energy_multiplier = 1.8
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			"SEAT":
				material.roughness = 0.81
			_:
				material.metallic = 0.10
				material.roughness = 0.68
	_materials[key] = material
	return material

func _box(parent: Node3D, label_name: String, at: Vector3,
		dimensions: Vector3, kind: String, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = dimensions
	node.mesh = box_mesh
	node.position = at
	node.material_override = _mat(kind, tint)
	parent.add_child(node)
	_visual_stats["hero_components"] += 1
	return node

func _cylinder(parent: Node3D, label_name: String, at: Vector3,
		radius: float, height: float, axis: String,
		kind: String, tint: Color, segments: int = 16) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label_name
	var part := CylinderMesh.new()
	part.top_radius = radius
	part.bottom_radius = radius
	part.height = height
	part.radial_segments = segments
	node.mesh = part
	node.position = at
	if axis == "X":
		node.rotation.z = PI * 0.5
	elif axis == "Z":
		node.rotation.x = PI * 0.5
	node.material_override = _mat(kind, tint)
	parent.add_child(node)
	_visual_stats["hero_components"] += 1
	return node

func _triangle(tool: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	for vert in [first, second, third]:
		tool.set_uv(Vector2(vert.x * 0.25 + vert.z * 0.11, vert.y * 0.30))
		tool.add_vertex(vert)

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(tool, a, b, c)
	_triangle(tool, a, c, d)

func _lofted_body_mesh() -> ArrayMesh:
	# The retained front and passenger floor end at the authored quarter joint.
	var ring := [
		Vector2(-1.02, -0.33), Vector2(-1.17, -0.08),
		Vector2(-1.15, 0.25), Vector2(-0.98, 0.48),
		Vector2(0.98, 0.48), Vector2(1.15, 0.25),
		Vector2(1.17, -0.08), Vector2(1.02, -0.33)
	]
	var sections := [
		{"z": -2.31, "scale": 0.80, "raise": -0.10},
		{"z": -2.16, "scale": 0.97, "raise": -0.03},
		{"z": -1.50, "scale": 1.0, "raise": 0.06},
		{"z": -0.70, "scale": 1.0, "raise": 0.0},
		{"z": 0.77, "scale": 1.0, "raise": 0.0},
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(sections.size() - 1):
		var left: Dictionary = sections[n]
		var right: Dictionary = sections[n + 1]
		for side in range(ring.size()):
			var next := (side + 1) % ring.size()
			var a := Vector3(ring[side].x * float(left["scale"]),
				ring[side].y + float(left["raise"]), float(left["z"]))
			var b := Vector3(ring[next].x * float(left["scale"]),
				ring[next].y + float(left["raise"]), float(left["z"]))
			var c := Vector3(ring[next].x * float(right["scale"]),
				ring[next].y + float(right["raise"]), float(right["z"]))
			var d := Vector3(ring[side].x * float(right["scale"]),
				ring[side].y + float(right["raise"]), float(right["z"]))
			# Section winding must face OUT, so SSR and PBR work as expected.
			# Godot 4.3 treats clockwise-wound triangles as front-facing;
			# the old order exposed the inward face from exterior cameras.
			_quad(st, a, b, c, d)
	for end in [0, sections.size() - 1]:
		var item: Dictionary = sections[end]
		var z: float = item["z"]
		for side in range(ring.size()):
			var next := (side + 1) % ring.size()
			var point := Vector3(ring[side].x * float(item["scale"]),
				ring[side].y + float(item["raise"]), z)
			var other := Vector3(ring[next].x * float(item["scale"]),
				ring[next].y + float(item["raise"]), z)
			var center := Vector3(0.0, 0.07, z)
			if end == 0:
				_triangle(st, center, other, point)
			else:
				_triangle(st, center, point, other)
	st.generate_normals()
	return st.commit()

func _build_rear_assembly() -> void:
	var rear := RearAssembly.instantiate() as Node3D
	rear.name = "RearAssembly"
	add_child(rear)
	var paint := _mat("REAR_PAINT", _paint)
	var shell := rear.get_node("RearHatchSolid") as MeshInstance3D
	shell.material_override = paint
	var frame := rear.get_node("HatchFrame") as MeshInstance3D
	for index in frame.mesh.get_surface_count():
		if frame.mesh.surface_get_material(index).resource_name.contains("Crimson"):
			frame.set_surface_override_material(index, paint)
	for side in ["L", "R"]:
		_brake_lenses.append(rear.get_node("BrakeLens" + side))
		_reverse_lenses.append(rear.get_node("ReverseLens" + side))
	if _brake_material == null:
		_brake_material = _powered_lens(_brake_lenses[0], Color("ff294c"), 2.55)
		_reverse_material = _powered_lens(_reverse_lenses[0], Color("def0f6"), 2.05)
	_visual_stats["body_panels"] += 1
	_visual_stats["transparent_glass"] += 1
	_visual_stats["brake_lamps"] += _brake_lenses.size()
	_visual_stats["seats"] += 2
	_visual_stats["hero_components"] += 12

func _powered_lens(mesh: MeshInstance3D, tint: Color, intensity: float) -> StandardMaterial3D:
	var material := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = intensity
	return material


func _build_body() -> void:
	var shell := MeshInstance3D.new()
	shell.name = "KestrelMonocoque"
	if _front_shell == null:
		_front_shell = _lofted_body_mesh()
	shell.mesh = _front_shell
	shell.material_override = _mat("PAINT", _paint)
	add_child(shell)
	_visual_stats["body_panels"] += 1
	_build_rear_assembly()
	# A continuous rib, actual undertray, recessed splitter and roof luggage/spine
	# define a functional vehicle silhouette instead of a floating colored cube.
	_box(self, "CarbonUndertray", Vector3(0.0, -0.35, 0.02),
		Vector3(1.88, 0.12, 4.43), "RUBBER", Color("1b2730"))
	_box(self, "FrontSplitter", Vector3(0.0, -0.26, -2.34),
		Vector3(1.97, 0.08, 0.25), "METAL", Color("303f48"))
	for side in [-1.0, 1.0]:
		_box(self, "RockerBeam", Vector3(side * 1.09, -0.25, -.325),
			Vector3(0.14, 0.13, 2.17), "METAL", Color("30414d"))
		_box(self, "CopperPinstripe", Vector3(side * 1.155, 0.22, -.635),
			Vector3(0.027, 0.045, 2.81), "METAL", Color("cba279"))
		_box(self, "WheelArchSill", Vector3(side * 1.15, 0.04, -1.48),
			Vector3(0.13, 0.10, 1.12), "RUBBER", Color("2d3640"))
		for handle_z in [-0.55, 0.75]:
			_box(self, "FlushDoorHandle", Vector3(side * 1.176, 0.31, float(handle_z)),
				Vector3(0.026, 0.045, 0.25), "METAL", STEEL)
			_visual_stats["door_reveals"] += 1
		_box(self, "LowerDoorSplit", Vector3(side * 1.174, -0.03, 0.12),
			Vector3(0.021, 0.47, 0.022), "RUBBER", Color("243642"))
		_box(self, "SideSkirtMarker", Vector3(side * 1.161, -0.20, -.30),
			Vector3(0.035, 0.035, 2.04), "LED", CYAN)
	# Dashboard and split hood panel telltales are grounded in actual hardware.
	for rib in [-0.88, 0.88]:
		_box(self, "HoodCrease", Vector3(float(rib), 0.51, -1.75),
			Vector3(0.035, 0.022, 0.83), "METAL", _paint.lightened(0.13))
	_box(self, "ServicePanel", Vector3(0.0, 0.49, -1.81),
		Vector3(0.69, 0.025, 0.55), "METAL", _paint.darkened(0.22))

func _mesh_quad(parent: Node3D, name: String, vertices: Array[Vector3],
		kind: String, tint: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, vertices[0], vertices[1], vertices[2], vertices[3])
	st.generate_normals()
	var pane := MeshInstance3D.new()
	pane.name = name
	pane.mesh = st.commit()
	pane.material_override = _mat(kind, tint)
	parent.add_child(pane)
	_visual_stats["hero_components"] += 1

func _build_cabin() -> void:
	_visual_stats["cabins"] += 1
	# Sloped structural windshield and rear hatch. Roof meets the side windows
	# at a narrower shoulder, like a real four-seat fastback.
	_box(self, "CanopyRoof", Vector3(0.0, 1.19, -0.14),
		Vector3(1.61, 0.11, 1.42), "PAINT", _paint.darkened(0.25))
	_mesh_quad(self, "PanoramicWindshield", [
		Vector3(-0.90, 0.49, -1.30), Vector3(0.90, 0.49, -1.30),
		Vector3(0.76, 1.13, -0.82), Vector3(-0.76, 1.13, -0.82)],
		"GLAZING", GLASS_DARK)
	_visual_stats["transparent_glass"] += 1
	for side in [-1.0, 1.0]:
		_mesh_quad(self, "CabinSideGlass", [
			Vector3(side * 0.94, 0.51, -1.16),
			Vector3(side * 0.78, 1.13, -0.77),
			Vector3(side * 0.78, 1.13, 0.52),
			Vector3(side * 0.94, 0.51, 1.35)],
			"GLAZING", WINDOW_TINT)
		_visual_stats["transparent_glass"] += 1
		# A/B/C pillars, door split and moulded gasket.
		for pillar_z in [-1.11, 0.02]:
			var pillar_height := 0.59 if absf(float(pillar_z)) > 0.8 else 0.68
			_box(self, "WindowMullion", Vector3(side * 0.90, 0.81, float(pillar_z)),
				Vector3(0.075, pillar_height, 0.095), "METAL", Color("293b46"))
		_box(self, "GlazingLowerReveal", Vector3(side * 0.95, 0.50, 0.08),
			Vector3(0.045, 0.055, 2.56), "METAL", STEEL)
		_box(self, "RoofDripRail", Vector3(side * 0.79, 1.16, -0.12),
			Vector3(0.09, 0.07, 1.55), "METAL", Color("344953"))
		# Practical camera/mirror hardware and amber repeater.
		_box(self, "MirrorArm", Vector3(side * 1.02, 0.69, -1.01),
			Vector3(0.30, 0.07, 0.08), "METAL", Color("485c68"))
		_box(self, "CameraMirrorPod", Vector3(side * 1.25, 0.73, -1.01),
			Vector3(0.22, 0.16, 0.24), "PAINT", _paint.darkened(0.3))
		_box(self, "TurningRepeater", Vector3(side * 1.37, 0.72, -1.10),
			Vector3(0.025, 0.05, 0.12), "LED", AMBER)
	# Solar/aero roof module and antenna integrated into a believable roofline.
	_box(self, "RoofGlassPanel", Vector3(0.0, 1.258, -0.11),
		Vector3(1.29, 0.024, 0.84), "GLAZING", GLASS_DARK)
	_visual_stats["transparent_glass"] += 1
	_box(self, "CommsAntenna", Vector3(0.0, 1.33, 0.43),
		Vector3(0.12, 0.11, 0.30), "RUBBER", Color("273740"))

func _build_road_gear() -> void:
	for front in [true, false]:
		var z := -1.48 if front else 1.49
		for side in [-1.0, 1.0]:
			var hub := Node3D.new()
			hub.name = ("Steering" if front else "Rear") + ("Left" if side < 0.0 else "Right")
			hub.position = Vector3(side * 1.10, -0.43, z)
			add_child(hub)
			if front:
				_steering_pivots.append(hub)
			var rotor := Node3D.new()
			rotor.name = "WheelSpin"
			hub.add_child(rotor)
			_wheel_rotors.append(rotor)
			_cylinder(rotor, "RoadTire", Vector3.ZERO, WHEEL_RADIUS, 0.27,
				"X", "RUBBER", Color("151d23"), 20)
			_cylinder(rotor, "AlloyWheel", Vector3(side * 0.008, 0.0, 0.0),
				WHEEL_RADIUS * 0.59, 0.289, "X", "METAL", Color("98a8ac"), 18)
			for spoke in range(6):
				var angle := TAU * float(spoke) / 6.0
				_box(rotor, "SixSpokeAlloy", Vector3(side * 0.156,
					cos(angle) * 0.195, sin(angle) * 0.195),
					Vector3(0.025, 0.075, 0.26),
					"METAL", Color("c1bab0"))
			_cylinder(rotor, "CenterNut", Vector3(side * .158, 0.0, 0.0),
				.060, .035, "X", "METAL", Color("566778"), 12)
			_visual_stats["wheels"] += 1
			_box(self, "SuspensionLowerArm", Vector3(side * 0.86, -0.31, z),
				Vector3(0.53, 0.11, 0.12), "METAL", Color("495b61"))
	# Flat EV battery belly and structural shield.
	_box(self, "BatteryShield", Vector3(0.0, -0.45, 0.03),
		Vector3(1.52, 0.13, 2.51), "METAL", Color("354952"))
	for rib in [-0.9, 0.0, 0.9]:
		_box(self, "UnderbodyRib", Vector3(0.0, -0.527, float(rib)),
			Vector3(1.58, 0.045, 0.10), "METAL", Color("748184"))

func _build_lights() -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.82
		_box(self, "HeadlampHousing", Vector3(x, 0.19, -2.315),
			Vector3(0.50, 0.19, 0.07), "RUBBER", Color("1b323f"))
		_box(self, "SegmentedDRL", Vector3(x, 0.29, -2.362),
			Vector3(0.48, 0.050, 0.032), "LED", Color("c5f4e8"))
		_box(self, "ProjectorLens", Vector3(x, 0.18, -2.365),
			Vector3(0.18, 0.085, 0.046), "LED", Color("d6eee5"))
		_visual_stats["headlamps"] += 1
		# Active white headlight projected only while driving or in pursuit.
		var beam := SpotLight3D.new()
		beam.name = "LiveHeadlamp"
		beam.position = Vector3(x, 0.13, -2.39)
		beam.spot_range = 23.0
		beam.spot_angle = 34.0
		beam.light_energy = 0.63
		beam.light_color = Color("d8eeeb")
		# SpotLight3D defaults to local -Z, the car's forward direction.
		beam.shadow_enabled = false
		beam.visible = false
		add_child(beam)
		_beams.append(beam)
	_box(self, "ForwardServiceSensor", Vector3(0.0, 0.06, -2.385),
		Vector3(0.45, 0.07, 0.045), "GLAZING", GLASS_DARK)

func _build_interior() -> void:
	# Through-window seats, center console, structural dashboard and accent.
	_box(self, "CabinFloor", Vector3(0.0, 0.24, -0.03),
		Vector3(1.83, 0.08, 2.40), "SEAT", Color("263641"))
	_box(self, "Dashboard", Vector3(0.0, 0.53, -0.96),
		Vector3(1.75, 0.21, 0.38), "SEAT", Color("26343d"))
	_box(self, "InstrumentBlade", Vector3(-0.32, 0.62, -0.95),
		Vector3(0.45, 0.14, 0.04), "LED", Color("64c9c4"))
	_box(self, "CenterConsole", Vector3(0.0, 0.44, -0.13),
		Vector3(0.23, 0.14, 1.60), "METAL", Color("617175"))
	for side in [-0.49, 0.49]:
		var pos := Vector3(float(side), 0.32, -.43)
		_box(self, "SeatCushion", pos, Vector3(0.66, 0.17, 0.62),
			"SEAT", Color("5f6263"))
		_box(self, "SeatBack", pos + Vector3(0.0, 0.37, 0.24),
			Vector3(0.62, 0.77, 0.16), "SEAT", Color("415661"))
		_box(self, "SeatHeadrest", pos + Vector3(0.0, 0.79, 0.25),
			Vector3(0.43, 0.19, 0.19), "SEAT", Color("8e988e"))
		_visual_stats["seats"] += 1
	# Driver wheel is fitted to a believable column in the forward cabin.
	_cylinder(self, "SteeringWheelRim", Vector3(-0.49, 0.62, -0.83),
		0.17, 0.055, "Z", "METAL", Color("9ea7a2"), 16)
	_cylinder(self, "SteeringColumn", Vector3(-0.49, 0.61, -0.71),
		0.049, 0.28, "Z", "RUBBER", Color("29343b"), 10)
	for side in [-0.8, 0.8]:
		_box(self, "PassengerMoodStrip", Vector3(float(side), 0.78, -0.1),
			Vector3(0.023, 0.024, 1.54), "LED", Color("4da5a1"))

func _build_sound() -> void:
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "OriginalElectricDrivetrain"
	AudioMix.ensure()
	_motor.bus = AudioMix.EFFECTS
	_motor.stream = VehicleAudio.sound()
	_motor.volume_db = -80.0
	_motor.max_distance = 32.0
	add_child(_motor)

func _build_police_equipment() -> void:
	_box(self, "PursuitRoofBase", Vector3(0.0, 1.30, -0.20),
		Vector3(0.88, 0.11, 0.35), "METAL", Color("243544"))
	for side in [-1.0, 1.0]:
		var source := Color("4d9cff") if side < 0.0 else Color("ff4968")
		_police_lenses.append(_box(self, "PursuitLightEmitter",
			Vector3(side * 0.27, 1.38, -0.20),
			Vector3(0.35, 0.12, 0.28), "LED", source))
	for side in [-1.0, 1.0]:
		_box(self, "PushbarPost", Vector3(side * 0.69, -0.03, -2.43),
			Vector3(0.11, 0.38, 0.18), "METAL", Color("555e66"))
	_box(self, "ReinforcedPushbar", Vector3(0.0, 0.09, -2.48),
		Vector3(1.61, 0.11, 0.15), "METAL", Color("747d84"))
