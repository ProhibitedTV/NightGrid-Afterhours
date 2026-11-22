extends Node3D
## Enclosed two-stop lift. The interaction transfers passengers through the
## landing doors while the visible cabin travels on a fixed physics schedule.
const Materials = preload("res://scripts/material_library.gd")
const LOWER_FLOOR = 0.15
const CAR_SPEED = 3.8
const DOOR_Z = -1.17
const LANDING_Z = -1.99

var station_name: String
var platform_floor: float
var carrier: Node3D
var travelling := false
var going_up := false
var _cabin: Node3D
var _from := LOWER_FLOOR
var _target := LOWER_FLOOR
var _travel_seconds := 0.0
var _cycle_seconds := 0.0
var _steel: StandardMaterial3D
var _glass: StandardMaterial3D

func _ready() -> void:
	_steel = Materials.surface("METAL", Color("536775"))
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.25, 0.43, 0.51, 0.50)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.22
	var shaft_top := platform_floor + 3.0
	var shaft_height := shaft_top - LOWER_FLOOR
	var middle := LOWER_FLOOR + shaft_height * 0.5
	for side in [-1.0, 1.0]:
		_member(self, Vector3(side * 1.14, middle, 0.0), Vector3(0.14, shaft_height, 2.48), _glass, true)
		for depth in [-1.15, 1.15]:
			_member(self, Vector3(side * 1.13, middle, depth), Vector3(0.18, shaft_height, 0.18), _steel)
	_member(self, Vector3(0.0, middle, 1.17), Vector3(2.28, shaft_height, 0.14), _steel, true)
	_member(self, Vector3(0.0, shaft_top, 0.0), Vector3(2.50, 0.22, 2.50), _steel, true)
	_member(self, Vector3(0.0, LOWER_FLOOR - 0.055, 0.0), Vector3(2.50, 0.19, 2.50), _steel, true)
	_build_forecourt()
	_member(self, Vector3(0.0, (2.51 + platform_floor) * 0.5, DOOR_Z),
		Vector3(2.28, platform_floor - 2.51, 0.14), _glass, true)
	for level in [LOWER_FLOOR, platform_floor]:
		_build_landing(level)
	_cabin = Node3D.new()
	_cabin.name = "LiftCabin"
	add_child(_cabin)
	_member(_cabin, Vector3(0.0, 0.10, 0.0), Vector3(2.06, 0.20, 2.04), _steel)
	_member(_cabin, Vector3(0.0, 2.20, 0.0), Vector3(2.06, 0.20, 2.04), _steel)
	_member(_cabin, Vector3(0.0, 1.20, 0.93), Vector3(2.06, 2.05, 0.12), _glass)
	carrier = Node3D.new()
	carrier.name = "PassengerCameraAnchor"
	carrier.position.z = LANDING_Z
	add_child(carrier)
	_set_car_height(LOWER_FLOOR)
	set_physics_process(false)

func _build_forecourt() -> void:
	var concrete := Materials.surface("CONCRETE", Color("84918e"))
	_member(self, Vector3(0.0, 0.035, -1.90), Vector3(2.76, 0.23, 1.52), concrete, true)
	# The approach meets the existing street foundation and the lift sill.
	# Its grade is 1:12 with a level, unobstructed landing at the top.
	var incline := atan2(0.23, 2.76)
	_member(self, Vector3(0.0, -0.047, -4.04), Vector3(2.76, 0.16, 2.78), concrete, true, -incline)

func _build_landing(level: float) -> void:
	for side in [-1.0, 1.0]:
		_member(self, Vector3(side * 0.96, level + 1.18, DOOR_Z), Vector3(0.46, 2.36, 0.18), _steel, true)
		_member(self, Vector3(side * 0.363, level + 1.10, DOOR_Z), Vector3(0.71, 2.20, 0.12), _steel, true)
	_member(self, Vector3(0.0, level + 2.32, DOOR_Z), Vector3(2.28, 0.32, 0.17), _steel, true)
	_landing_sign(level, Vector3(0.0, 0.0, DOOR_Z - 0.11), PI)
	if is_equal_approx(level, LOWER_FLOOR):
		_landing_sign(level, Vector3(-1.235, 0.0, 0.0), -PI * 0.5)

func _landing_sign(level: float, side: Vector3, turn: float) -> void:
	var sign := Label3D.new()
	sign.name = "LiftLandingSign"
	sign.text = "M  /  " + station_name + "\nPLATFORM LIFT"
	sign.font_size = 35
	sign.pixel_size = 0.006
	sign.modulate = Color("cef3e6")
	sign.position = side + Vector3.UP * (level + 2.66)
	sign.rotation.y = turn
	sign.double_sided = false
	add_child(sign, true)

func landing_position(upper: bool) -> Vector3:
	return to_global(Vector3(0.0, (platform_floor if upper else LOWER_FLOOR) + 0.97, LANDING_Z))

func can_request(at: Vector3) -> bool:
	return not travelling and (at.distance_to(landing_position(false)) < 1.38 or
		at.distance_to(landing_position(true)) < 1.38)

func start(at: Vector3) -> void:
	going_up = at.y < platform_floor
	var departure := LOWER_FLOOR if going_up else platform_floor
	# Dispatch an empty car to the calling landing if it is left upstairs.
	_from = _cabin.position.y
	_target = departure
	_travel_seconds = 0.0
	_cycle_seconds = absf(_target - _from) / CAR_SPEED
	travelling = true
	carrier.position.y = departure
	if _cycle_seconds < 0.01:
		_start_ride()
	set_physics_process(true)

func _start_ride() -> void:
	_from = LOWER_FLOOR if going_up else platform_floor
	_target = platform_floor if going_up else LOWER_FLOOR
	_travel_seconds = 0.0
	_cycle_seconds = absf(_target - _from) / CAR_SPEED
	carrier.position.y = _from

func _physics_process(delta: float) -> void:
	_travel_seconds += delta
	var fraction := clampf(_travel_seconds / _cycle_seconds, 0.0, 1.0)
	_cabin.position.y = lerpf(_from, _target, smoothstep(0.0, 1.0, fraction))
	var destination := platform_floor if going_up else LOWER_FLOOR
	if is_equal_approx(_target, destination):
		carrier.position.y = _cabin.position.y
		if fraction >= 1.0:
			travelling = false
			set_physics_process(false)
	elif fraction >= 1.0:
		_start_ride()

func destination() -> Vector3:
	return landing_position(going_up)

func _set_car_height(height: float) -> void:
	_cabin.position.y = height
	carrier.position.y = height

func _member(parent: Node3D, at: Vector3, size: Vector3, material: StandardMaterial3D,
		solid: bool = false, slope: float = 0.0) -> void:
	var object := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	object.mesh = mesh
	object.material_override = material
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		body.rotation.x = slope
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		body.add_child(object)
		parent.add_child(body)
	else:
		object.position = at
		parent.add_child(object)
