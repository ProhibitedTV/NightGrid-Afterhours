extends Node3D
## Articulated visual rig. The existing car owns motion and collision.

const Cars = preload("res://scripts/road_car_catalog.gd")
const Drivetrain = preload("res://scripts/road_car_audio.gd")
const Paint = preload("res://shaders/vehicle_paint.gdshader")
const Glazing = preload("res://shaders/vehicle_glazing.gdshader")
const RAIN_BEADS = preload("res://assets/models/nightgrid/road_cars/rain_beads.png")
const MODEL = preload("res://assets/models/nightgrid/road_cars/cinder_r9.gltf")
const Wheel = preload("res://assets/models/nightgrid/road_cars/wheel.gltf")
const STEEL_NORMAL = preload("res://assets/models/nightgrid/central_exchange_curb/textures/steel_normal_1k.jpg")
const WHEEL_MODEL_RADIUS = 0.359
const GROUND = -0.825
const TAIL_RED = Color("ff2635")
const REVERSE_WHITE = Color("ffdcb8")
const SILL_CYAN = Color("16d9f4")
static var _shared: Dictionary = {}
static var _wheel_mesh: ArrayMesh
static var _brake_left_mesh: ArrayMesh
static var _brake_right_mesh: ArrayMesh

var _night := true
var _color: Color
var _spec: Dictionary
var _shell: Node3D
var _body_sections: Array[MeshInstance3D] = []
var _head: MeshInstance3D
var _projectors: MeshInstance3D
var _tail: MeshInstance3D
var _reverse: MeshInstance3D
var _sill: MeshInstance3D
var _wheels: Array[Node3D] = []
var _brake_calipers: Array[MeshInstance3D] = []
var _steering: Array[Node3D] = []
var _beams: Array[SpotLight3D] = []
var _tail_throw: SpotLight3D
var _sill_lights: Array[OmniLight3D] = []
var _doors: Array[Dictionary] = []
var _wheel_phase := 0.0
var _drivetrain := Drivetrain.new()
var _velocity := 0.0
var _braking := false
var _occupied := false
var _damage := Vector4.ZERO

func configure(paint_color: Color) -> void:
	_color = paint_color
	_spec = Cars.DATA[Cars.R9]

func _ready() -> void:
	if _shared.is_empty():
		_create_materials()
	_shell = MODEL.instantiate() as Node3D
	_shell.name = "Coachwork"
	_shell.position.y = GROUND
	add_child(_shell)
	for child in _shell.get_children():
		var part := child as MeshInstance3D
		if part == null:
			continue
		_finish(part)
		if part.name.begins_with("Door"):
			part.set_instance_shader_parameter("panel_origin_y", part.position.y)
			var side := -1.0 if part.name.begins_with("DoorL") else 1.0
			var reach := part.mesh.get_aabb().end.z
			_doors.append({"part": part, "side": side, "reach": reach, "motion": 0.0, "target": 0.0, "hold": -1.0})
	_body_sections = [_shell.get_node("FrontClip"), _shell.get_node("RearClip"), _shell.get_node("Cabin")]
	_head = _shell.get_node("HeadLenses")
	_projectors = _shell.get_node("HeadProjectors")
	_tail = _shell.get_node("TailLenses")
	_reverse = _shell.get_node("ReverseLenses")
	_sill = _shell.get_node("SillLenses")
	_build_wheels()
	_build_lights()
	_drivetrain.mount(self)
	apply_damage(Vector4.ZERO)

func _create_materials() -> void:
	_shared["Graphite"] = _finish_material(Color("252830"), 0.80)
	_shared["Seat"] = _finish_material(Color("353c46"), 0.82)
	_shared["DoorCard"] = _finish_material(Color("252a2d"), 0.78)
	_shared["Tire"] = _finish_material(Color("181a1d"), 0.86)
	var alloy := _finish_material(Color("989ca3"), 0.31, 0.82)
	alloy.normal_enabled = true
	alloy.normal_texture = STEEL_NORMAL
	alloy.normal_scale = 0.27
	_shared["MachinedAlloy"] = alloy
	_shared["BrakeCaliper"] = _finish_material(Color("bb4230"), 0.32, 0.34)
	var glass := ShaderMaterial.new()
	glass.shader = Glazing
	glass.set_shader_parameter("rain_beads", RAIN_BEADS)
	_shared["Glazing"] = glass
	var optic := _finish_material(Color(0.24, 0.28, 0.32, 0.115), 0.105)
	optic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	optic.clearcoat_enabled = true
	optic.clearcoat = 0.74
	optic.clearcoat_roughness = 0.09
	_shared["OpticCover"] = optic
	var titanium := _finish_material(Color("817268"), 0.29, 0.88)
	titanium.normal_enabled = true
	titanium.normal_texture = STEEL_NORMAL
	titanium.normal_scale = 0.22
	titanium.uv1_scale = Vector3(3.5, 1.2, 1)
	_shared["Titanium"] = titanium
	# Satin stamped reflector tray now sits directly below the bonded lenses.
	# The real headlights and projector bulbs still own their light states.
	_shared["HeadlampReflectorHousing"] = _finish_material(Color("43545e"), 0.31, 0.67)
	_shared["HeadlampPerimeterSeal"] = _finish_material(Color("131719"), 0.86, 0.0)
	_shared["Instrument"] = _lamp(Color("81c3c8"), 0.57)
	_shared["Headlamp"] = _lamp(Color("cbdff4"), 1.62)
	_shared["HeadIdle"] = _finish_material(Color("757e8e"), 0.36, 0.30)
	_shared["ProjectorOn"] = _lamp(Color("eef4ff"), 3.18)
	_shared["ProjectorOptic"] = _finish_material(Color("697d96"), 0.18, 0.64)
	_shared["Taillamp"] = _lamp(Color("b62332"), 0.41)
	_shared["TailIdle"] = _finish_material(Color("681c2c"), 0.25)
	_shared["Braking"] = _lamp(Color("f34744"), 2.64)
	_shared["ReverseLamp"] = _finish_material(Color("3a444b"), 0.30)
	_shared["Reversing"] = _lamp(Color("e6e8d4"), 1.44)
	_shared["BrokenLamp"] = _finish_material(Color("191c21"), 0.72)
	_shared["SillOn"] = _lamp(SILL_CYAN, 1.55)
	_shared["SillOff"] = _finish_material(Color("1e434a"), 0.42)

func _finish_material(tint: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = metallic
	return material

func _lamp(tint: Color, energy: float) -> StandardMaterial3D:
	var material := _finish_material(tint, 0.27)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = energy
	return material

func _finish(part: MeshInstance3D) -> void:
	var key := _color.to_html(false)
	if not _shared.has(key):
		var body := ShaderMaterial.new()
		body.shader = Paint
		body.set_shader_parameter("enamel", _color)
		body.set_shader_parameter("rain_beads", RAIN_BEADS)
		body.set_shader_parameter("flake_content", 0.42)
		_shared[key] = body
	for index in part.mesh.get_surface_count():
		var imported := part.mesh.surface_get_material(index)
		var label := imported.resource_name
		if label == "CarbonComposite" and not _shared.has(label):
			var carbon := imported.duplicate() as StandardMaterial3D
			carbon.uv1_scale = Vector3(48, 48, 1)
			carbon.clearcoat_enabled = true
			carbon.clearcoat = 0.52
			carbon.clearcoat_roughness = 0.27
			_shared[label] = carbon
		var material: Material = _shared.get(key if label == "Paint" else label)
		if material != null:
			part.set_surface_override_material(index, material)
	if part.name.ends_with("Lenses") or part.name == &"HeadProjectors":
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_wheels() -> void:
	if _wheel_mesh == null:
		var source := Wheel.instantiate()
		_wheel_mesh = (source.get_node("Wheel") as MeshInstance3D).mesh as ArrayMesh
		_brake_left_mesh = (source.get_node("BrakeCaliperL") as MeshInstance3D).mesh as ArrayMesh
		_brake_right_mesh = (source.get_node("BrakeCaliperR") as MeshInstance3D).mesh as ArrayMesh
		source.free()
	var axles: Vector2 = _spec["axles"]
	var tyre := float(_spec["tire"])
	for axle in 2:
		for side in [-1.0, 1.0]:
			var steering := Node3D.new()
			steering.position = Vector3(float(_spec["track"]) * side, tyre, axles[axle])
			_shell.add_child(steering)
			var detail := MeshInstance3D.new()
			detail.mesh = _wheel_mesh
			detail.scale = Vector3(.92, tyre / WHEEL_MODEL_RADIUS, tyre / WHEEL_MODEL_RADIUS)
			_finish(detail)
			steering.add_child(detail)
			# Calipers share the steering knuckle's orientation but never inherit
			# tire spin. A spinning caliper would make braking look physically wrong.
			var caliper := MeshInstance3D.new()
			caliper.name = "FixedBrakeCaliper"
			caliper.mesh = _brake_left_mesh if side < 0.0 else _brake_right_mesh
			caliper.scale = detail.scale
			_finish(caliper)
			steering.add_child(caliper)
			_brake_calipers.append(caliper)
			_wheels.append(detail)
			if axle == 0:
				_steering.append(steering)

func _build_lights() -> void:
	for socket in [&"KeyLeft", &"KeyRight"]:
		var beam := SpotLight3D.new()
		beam.name = str(socket) + "Beam"
		beam.position = (_shell.get_node(NodePath(socket)) as Node3D).position
		beam.rotation = Vector3(-.102, -signf(beam.position.x) * .051, 0)
		beam.light_color = Color("e7eeff")
		beam.light_energy = 3.15
		beam.light_specular = .39
		beam.spot_range = 32.0
		beam.spot_angle = 35.0
		beam.spot_attenuation = 1.60
		beam.visible = false
		_shell.add_child(beam)
		_beams.append(beam)
	_tail_throw = SpotLight3D.new()
	_tail_throw.name = "RearBeam"
	_tail_throw.position = (_shell.get_node("TailThrow") as Node3D).position
	_tail_throw.rotation = Vector3(-.29, PI, 0)
	_tail_throw.spot_range = 5.8
	_tail_throw.spot_angle = 53.0
	_tail_throw.spot_attenuation = 0.77
	_tail_throw.light_specular = .46
	_shell.add_child(_tail_throw)
	for socket in [&"SillLightLeft", &"SillLightRight"]:
		var lamp := OmniLight3D.new()
		lamp.name = str(socket) + "Bounce"
		lamp.position = (_shell.get_node(NodePath(socket)) as Node3D).position
		lamp.light_color = SILL_CYAN
		lamp.light_energy = 1.12
		lamp.omni_range = 1.95
		lamp.omni_attenuation = 1.6
		_shell.add_child(lamp)
		_sill_lights.append(lamp)

func _steering_targets(input: float) -> Vector2:
	# The car controller turns yaw NEGATIVE for positive input (rightwards in
	# local +X while travelling -Z). The previous visual rotated both front
	# wheels positively, making them visibly point against the actual turn.
	# Ackermann geometry requires the inside front wheel to turn more.
	var control := clampf(input, -1.0, 1.0)
	var mean_angle := absf(control) * 0.37
	if mean_angle <= 0.00001:
		return Vector2.ZERO
	var axles: Vector2 = _spec["axles"]
	var wheelbase := absf(axles.y - axles.x)
	var half_track := float(_spec["track"])
	var turn_radius := wheelbase / tan(mean_angle)
	var inside := atan(wheelbase / maxf(turn_radius - half_track, 0.25))
	var outside := atan(wheelbase / (turn_radius + half_track))
	# Order is front-left (-X), front-right (+X). Positive road input turns
	# towards +X; the right tire is inside that turn.
	return Vector2(-outside, -inside) if control > 0.0 else Vector2(inside, outside)


func update_motion(speed: float, steer: float, braking: bool, occupied: bool,
		throttle: float, wetness: float, delta: float) -> void:
	if absf(speed) > 0.01:
		_wheel_phase = fposmod(_wheel_phase + speed * delta / float(_spec["tire"]), TAU)
		for wheel in _wheels:
			wheel.rotation.x = -_wheel_phase
	# Steer the non-spinning knuckle and its fixed caliper as a unit.
	# Slew rate is bounded so the rims never teleport between lock positions;
	# unoccupied cars return their wheels to straight ahead.
	var targets := _steering_targets(steer if occupied else 0.0)
	for index in _steering.size():
		var wanted: float = targets.x if index == 0 else targets.y
		var knuckle := _steering[index]
		knuckle.rotation.y = move_toward(knuckle.rotation.y, wanted, maxf(delta, 0.0) * 1.55)
	if occupied or _occupied:
		if braking != _braking or (speed < -0.35) != (_velocity < -0.35) or occupied != _occupied:
			_update_lights(occupied, braking, speed < -0.35)
	_velocity = speed
	_occupied = occupied
	_braking = braking
	_move_doors(delta, absf(speed) > 2.5)
	_drivetrain.update(speed, steer, braking, occupied, throttle, wetness, delta)

func set_lighting_hour(hour: float) -> void:
	var night := hour >= 18.75 or hour < 6.4
	if night != _night:
		_night = night
		_update_lights(_occupied, _braking, _velocity < -0.35)

func _update_lights(occupied: bool, braking: bool, reverse: bool) -> void:
	var night_running := occupied and _night
	var head_on := night_running and _damage.x <= 0.71
	var tail_ok := _damage.y <= 0.75
	var stop_on := occupied and braking and tail_ok
	var reverse_on := occupied and reverse and tail_ok
	_head.material_override = _shared["BrokenLamp" if _damage.x > 0.71 else ("Headlamp" if head_on else "HeadIdle")]
	_projectors.material_override = _shared["BrokenLamp" if _damage.x > 0.71 else ("ProjectorOn" if head_on else "ProjectorOptic")]
	_tail.material_override = _shared["BrokenLamp" if not tail_ok else (
		"Braking" if stop_on else ("Taillamp" if night_running else "TailIdle"))]
	_reverse.material_override = _shared["BrokenLamp" if not tail_ok else ("Reversing" if reverse_on else "ReverseLamp")]
	_sill.material_override = _shared["SillOn" if night_running else "SillOff"]
	for beam in _beams:
		beam.visible = head_on
	_tail_throw.visible = occupied and tail_ok and (night_running or stop_on or reverse_on)
	_tail_throw.light_color = REVERSE_WHITE if reverse_on else TAIL_RED
	_tail_throw.light_energy = 2.13 if reverse_on else (1.66 if stop_on else 0.42)
	for index in _sill_lights.size():
		_sill_lights[index].visible = night_running and _damage[index + 2] < 0.84

func apply_damage(zones: Vector4) -> void:
	_damage = zones
	var front := Vector3(0, -0.095, 0.175) * zones.x
	var rear := Vector3(0, -0.071, -0.143) * zones.y
	_body_sections[0].position = front
	_body_sections[1].position = rear
	_head.position = front
	_projectors.position = front
	_tail.position = rear
	_reverse.position = rear
	_tail_throw.position = (_shell.get_node("TailThrow") as Node3D).position + rear
	for index in _beams.size():
		var socket := "KeyLeft" if index == 0 else "KeyRight"
		_beams[index].position = (_shell.get_node(socket) as Node3D).position + front
	_body_sections[0].rotation.x = -zones.x * 0.047
	_body_sections[1].rotation.x = zones.y * 0.039
	_body_sections[0].set_instance_shader_parameter("impact", zones.x)
	_body_sections[1].set_instance_shader_parameter("impact", zones.y)
	for door in _doors:
		var panel: MeshInstance3D = door["part"]
		var wear := zones.z if float(door["side"]) < 0.0 else zones.w
		panel.set_instance_shader_parameter("impact", wear)
		panel.scale.x = 1.0 - wear * 0.21
	_update_lights(_occupied, _braking, _velocity < -0.35)

func _angle(door: Dictionary, value: float) -> Vector3:
	var outward := float(door["side"])
	return Vector3(-1.06 * value, outward * 0.20 * value, outward * 0.025 * value)

func _door_index(point: Vector3, front_only: bool) -> int:
	var nearest := INF
	var selected := -1
	for i in _doors.size():
		var panel: MeshInstance3D = _doors[i]["part"]
		if front_only and not panel.name.ends_with("0"):
			continue
		var center := panel.global_position + global_basis.z * float(_doors[i]["reach"]) * 0.50
		var distance := point.distance_squared_to(center)
		if distance < nearest:
			nearest = distance
			selected = i
	return selected

func _can_swing(door: Dictionary, ignore: RID) -> bool:
	var panel: MeshInstance3D = door["part"]
	var space := get_world_3d().direct_space_state
	var car := get_parent() as CollisionObject3D
	var excluded: Array[RID] = [car.get_rid()]
	if ignore.is_valid():
		excluded.append(ignore)
	var probe := SphereShape3D.new()
	probe.radius = 0.17
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.exclude = excluded
	var reach := float(door["reach"])
	var height := panel.mesh.get_aabb().end.y * 0.72
	for fraction in [0.28, 0.59, 0.91]:
		var pose := global_basis * Basis.from_euler(_angle(door, fraction))
		for length in [0.53, 0.91]:
			var tip := panel.global_position + pose * Vector3(0, height, length * reach)
			query.transform = Transform3D(Basis.IDENTITY, tip)
			if not space.intersect_shape(query, 1).is_empty():
				return false
	return true

func toggle_near_door(point: Vector3, ignore: RID) -> bool:
	var index := _door_index(point, false)
	if index < 0:
		return false
	var door := _doors[index]
	var panel: MeshInstance3D = door["part"]
	if panel.global_position.distance_to(point) > 2.65:
		return false
	if float(door["target"]) < 0.5 and not _can_swing(door, ignore):
		return false
	door["target"] = 1.0 - float(door["target"])
	door["hold"] = -1.0
	return true

func cycle_access_door(point: Vector3, leaving: bool, ignore: RID) -> void:
	var index := _door_index(point, true)
	if index < 0 or not _can_swing(_doors[index], ignore):
		return
	_doors[index]["target"] = 1.0
	_doors[index]["hold"] = 1.05 if leaving else 1.27

func close_doors_immediate() -> void:
	for door in _doors:
		door["target"] = 0.0
		door["hold"] = -1.0
		door["motion"] = 0.0
		(door["part"] as MeshInstance3D).rotation = Vector3.ZERO

func _move_doors(delta: float, moving: bool) -> void:
	for door in _doors:
		if moving:
			door["target"] = 0.0
			door["hold"] = -1.0
		elif float(door["hold"]) >= 0.0:
			door["hold"] = float(door["hold"]) - delta
			if float(door["hold"]) <= 0.0:
				door["target"] = 0.0
		var motion := float(door["motion"])
		var next := move_toward(motion, float(door["target"]), delta / (0.40 if moving else 0.62))
		if next != motion:
			door["motion"] = next
			var panel: MeshInstance3D = door["part"]
			panel.rotation = _angle(door, smoothstep(0.0, 1.0, next))
			if (motion == 0.0 and next > 0.0) or (next == 0.0 and motion > 0.0):
				var latch_point := _shell.position + panel.position + Vector3(0, 0, float(door["reach"]) * .8)
				_drivetrain.door_moved(latch_point, next > motion)

func get_motion_state() -> Dictionary:
	return {"wheel_rotation": _wheel_phase, "steering": _steering[0].rotation.y,
		"steering_left": _steering[0].rotation.y, "steering_right": _steering[1].rotation.y,
		"fixed_calipers": _brake_calipers.size(), "braking": _braking,
		"speed": _velocity, "live_beams": 2 if _beams[0].visible else 0}
