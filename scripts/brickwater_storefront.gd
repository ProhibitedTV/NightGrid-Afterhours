extends Node3D
## Night Shift Repairs keeps the original two openings in its west alley parcel.
const SwingDoor = preload("res://scripts/storefront_door.gd")
const Foley = preload("res://scripts/city_foley.gd")
const Mix = preload("res://scripts/audio_mix.gd")
const WORKSHOP = preload("res://assets/models/nightgrid/night_shift_repairs/workshop.gltf")
const LEAF = preload("res://assets/models/nightgrid/night_shift_repairs/hinged_leaf.gltf")
const SITE_ID = "night_shift_repairs"
const DOOR_Z = 0.9
const FLOOR_Y = 0.14
const BACK = -5.78
const Z_MIN = -8.10
const Z_MAX = 1.50
const CEILING = 3.26
const COUNTER = Vector3(-3.13, 0.94, -0.79)
const PRICE = 24

var door: SwingDoor
var _colliders: StaticBody3D
var _bench: AudioStreamPlayer3D

func _ready() -> void:
	_colliders = StaticBody3D.new()
	_colliders.name = "WorkshopEnclosure"
	add_child(_colliders)
	_solid("Slab", Vector3(BACK, -0.15, Z_MIN), Vector3(0.28, 0, Z_MAX))
	_solid("RearMasonry", Vector3(BACK, 0, Z_MIN), Vector3(-5.57, 3.10, Z_MAX))
	_solid("SouthReturn", Vector3(-5.57, 0, Z_MIN), Vector3(-0.26, 3.10, -7.90))
	_solid("NorthReturn", Vector3(-5.57, 0, 1.31), Vector3(-0.26, 3.10, Z_MAX))
	_solid("Ceiling", Vector3(BACK, 3.10, Z_MIN), Vector3(0.0, CEILING, Z_MAX))
	# The retained window kit occupies this wall section. Its solid glazing
	# stays in the reveal while the walkable doorway is a separate opening.
	_solid("DisplayBay", Vector3(-0.26, 0, Z_MIN), Vector3(0.09, 3.10, -5.10))
	_solid("FrontWall", Vector3(-0.27, 0, -5.10), Vector3(0.0, 3.10, -1.50))
	_solid("SouthJamb", Vector3(-0.26, 0, -1.50), Vector3(0.28, 3.10, -0.55))
	_solid("NorthJamb", Vector3(-0.26, 0, 0.55), Vector3(0.28, 3.10, 1.50))
	_solid("DoorHeader", Vector3(-0.26, 2.29, -0.55), Vector3(0.28, 3.10, 0.55))
	_solid("Counter", Vector3(-4.73, 0.08, -1.94), Vector3(-3.82, 1.046, 0.34))
	_solid("Register", Vector3(-4.54, 1.046, -0.30), Vector3(-4.12, 1.36, 0.04))
	_solid("Bench", Vector3(-5.56, 0.06, -6.64), Vector3(-4.81, 1.04, -2.47))
	_solid("Vice", Vector3(-5.23, 1.04, -5.95), Vector3(-4.91, 1.35, -5.65))
	_solid("SparePartsRack", Vector3(-3.41, 0.04, -7.83), Vector3(-2.79, 2.14, -5.69))
	_solid("RetailRack", Vector3(-1.02, 0.04, -4.88), Vector3(-0.49, 2.10, -2.94))
	_solid("DisplayTable", Vector3(-1.52, 0.02, -7.58), Vector3(-0.42, 0.85, -5.60))
	door = SwingDoor.new()
	door.name = "ShopDoor"
	door.position = Vector3(0.196, 0, 0.552)
	door.configure(Vector3(0.073, 2.24, 1.10), Vector3(0, 1.15, -0.55))
	add_child(door)

func _solid(label: String, low: Vector3, high: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = label
	var shape := BoxShape3D.new()
	shape.size = high - low
	collision.shape = shape
	collision.position = (low + high) * 0.5
	_colliders.add_child(collision)

func install_art() -> void:
	var view := WORKSHOP.instantiate() as Node3D
	view.name = "AuthoredWorkshop"
	add_child(view)
	door.install_art(LEAF)
	_sign("NamePlate", "NIGHT SHIFT REPAIRS", Vector3(0.297, 2.695, 0), 0.0041, Color("eddfbc"))
	_sign("HoursPlate", "SERVICE  /  24 HOURS", Vector3(0.297, 2.594, 0), 0.00245, Color("e8c58f"))
	_sign("CounterPlate", "SERVICE DESK", Vector3(-3.814, 0.70, -0.84), 0.0038, Color("f0dfb2"))
	for z in [-6.55, -3.55, -0.61]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(-2.72, 2.82, z)
		lamp.rotation.x = -PI * 0.5
		lamp.light_color = Color("f9d9ab") if z == -0.61 else Color("e6edda")
		lamp.light_energy = 4.2 if z == -0.61 else 3.6
		lamp.spot_range = 4.65
		lamp.spot_angle = 59.0
		lamp.spot_angle_attenuation = 0.62
		lamp.shadow_enabled = true
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 19.0
		lamp.distance_fade_length = 5.0
		add_child(lamp)
	var display := OmniLight3D.new()
	display.position = Vector3(-1.03, 2.21, -6.72)
	display.light_color = Color("ffce8d")
	display.light_energy = 0.95
	display.omni_range = 2.1
	add_child(display)
	_bench = AudioStreamPlayer3D.new()
	_bench.name = "WorkbenchVent"
	_bench.bus = Mix.ROOM_EFFECTS
	_bench.stream = Foley.sound("VENT")
	_bench.position = Vector3(-5.25, 2.75, -5.4)
	_bench.max_distance = 8.5
	_bench.unit_size = 2.0
	_bench.volume_db = -24.0
	add_child(_bench)

func _sign(label: String, text: String, at: Vector3, pixel: float, ink: Color) -> void:
	var plaque := Label3D.new()
	plaque.name = label
	plaque.text = text
	plaque.position = at
	plaque.rotation.y = PI * 0.5
	plaque.font_size = 42
	plaque.outline_size = 0
	plaque.pixel_size = pixel
	plaque.modulate = ink
	plaque.shaded = true
	add_child(plaque)

func contains(at: Vector3) -> bool:
	var local := to_local(at)
	return (local.x > BACK and local.x < 0.11 and local.y > -0.10 and local.y < 3.15
		and local.z > Z_MIN and local.z < Z_MAX)

func door_reachable(at: Vector3) -> bool:
	var local := to_local(at)
	# Leave enough reach inside to stand beyond the entire inward sweep.
	return local.x >= -1.53 and local.x <= 1.55 and absf(local.z) < 0.82 and local.y < 2.30

func overlaps_threshold(at: Vector3) -> bool:
	var local := to_local(at)
	return absf(local.x - 0.19) < 0.45 and absf(local.z) < 0.60 and local.y < 2.5

func doorway_leak(at: Vector3) -> float:
	var distance := to_local(at).distance_to(Vector3(0.20, 1.0, 0.0))
	return clampf(1.0 - distance / 4.0, 0.0, 1.0) * door.openness()

func counter_reachable(at: Vector3) -> bool:
	return contains(at) and to_local(at).distance_squared_to(COUNTER) <= 1.17 * 1.17

func counter_position() -> Vector3:
	return to_global(COUNTER)

func set_listener(at: Vector3, inside: bool) -> void:
	if _bench == null:
		return
	var close := global_position.distance_squared_to(at) < 13.0 * 13.0
	if close and not _bench.playing:
		_bench.play()
	elif not close and _bench.playing:
		_bench.stop()
	_bench.volume_db = -24.0 if inside else lerpf(-51.0, -33.0, door.openness())
