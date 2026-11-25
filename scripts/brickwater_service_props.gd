extends Node3D
## Selected authored meshes, never the full source-kit display layout.
const BAG = preload("res://assets/models/polyhaven/trashbag/trashbag.gltf")
const BOX = preload("res://assets/models/polyhaven/cardboard_box_01/cardboard_box_01.gltf")
const CRATE = preload("res://assets/models/polyhaven/plastic_crate_01/plastic_crate_01.gltf")
const TRUCK = preload("res://assets/models/polyhaven/hand_truck/hand_truck.gltf")
const SCONCE = preload("res://assets/models/polyhaven/industrial_caged_sconce/industrial_caged_sconce.gltf")
const PIPES = preload("res://assets/models/polyhaven/modular_pipes/modular_pipes.gltf")
static var _mesh_cache: Dictionary = {}
var left_wall: float
var right_wall: float
var floor_y: float
var _practicals: Array[OmniLight3D] = []

func set_night_factor(value: float) -> void:
	for lamp in _practicals:
		lamp.light_energy = 1.15 * smoothstep(0.25, 0.72, value)

func configure(left: float, right: float, floor_height: float) -> void:
	left_wall = left
	right_wall = right
	floor_y = floor_height

func _ready() -> void:
	# Distinct fixed sites, deliberately away from the dumpster, existing
	# power cabinet, HVAC and waste can. Keep the central corridor empty.
	_ground("DeliveryCart", TRUCK, left_wall + 0.47, -9.3, PI * 0.5)
	_ground("DeliveryCrate", CRATE, left_wall + 0.27, -8.4, 0.18)
	_ground("DeliveryCarton", BOX, left_wall + 0.34, -7.75, -0.16)
	_ground("RefuseBagA", BAG, left_wall + 0.37, 3.95, 0.5)
	_ground("RefuseBagB", BAG, left_wall + 0.38, 7.35, -0.64)
	_ground("ReturnCrate", CRATE, right_wall - 0.29, -5.15, -0.25)
	_ground("ReturnCarton", BOX, right_wall - 0.37, -4.45, 0.25)
	var crate_height := _selected(CRATE).get_aabb().size.y
	for row in range(3):
		_ground("StackedReturns%d" % row, CRATE, right_wall - 0.34, -7.85, -0.07, row * crate_height)
	_ground("SealedReturnsCarton", BOX, right_wall - 0.34, -8.45, 0.14)
	_fixture("WestServiceLamp", left_wall + 0.012, -6.68, PI * 0.5)
	_fixture("EastServiceLamp", right_wall - 0.012, 4.0, -PI * 0.5)
	# Replacement for the two procedural risers and shared horizontal run.
	for z in [-7.0, 1.0]:
		_part("RiserLower", PIPES, "pipe_200cm_metal", Vector3(right_wall - 0.105, 0.65, z), Vector3.ZERO)
		_part("RiserUpper", PIPES, "pipe_100cm_metal", Vector3(right_wall - 0.105, 2.65, z), Vector3.ZERO)
		for y in [0.85, 2.2, 3.35]:
			_part("PipeWallSupport", PIPES, "pipe_support_metal", Vector3(right_wall - 0.008, y, z), Vector3(0, -PI * 0.5, 0))
	for i in range(4):
		_part("ServiceMain", PIPES, "pipe_200cm_metal", Vector3(right_wall - 0.105, 3.65, -7.0 + 2.0 * i), Vector3(PI * 0.5, 0, 0))
	_service_feeds()

func _service_feeds() -> void:
	# Two narrow supplies beside the existing meter cabinet. The horizontal
	# sleeves continue into masonry, and collars keep the shafts off the wall.
	var body := StaticBody3D.new()
	body.name = "CabinetFeedCollision"
	add_child(body)
	for z in [-10.50, -10.70]:
		var pipe_x := right_wall - 0.104
		_part("CabinetFeedLower", PIPES, "pipe_200cm_metal", Vector3(pipe_x, floor_y, z), Vector3.ZERO)
		_part("CabinetFeedUpper", PIPES, "pipe_100cm_metal", Vector3(pipe_x, floor_y + 2.0, z), Vector3.ZERO)
		for y in [0.84, 2.48]:
			_part("CabinetFeedClip", PIPES, "pipe_support_metal", Vector3(right_wall - 0.006, y, z), Vector3(0, -PI * 0.5, 0))
		var sleeve := _part("CabinetFeedWallSleeve", PIPES, "pipe_100cm_metal",
			Vector3(pipe_x, floor_y + 3.0, z), Vector3(0, 0, -PI * 0.5))
		sleeve.scale.y = 0.19
		var shape := CylinderShape3D.new()
		shape.radius = 0.05
		shape.height = 3.0
		var collider := CollisionShape3D.new()
		collider.position = Vector3(pipe_x, floor_y + 1.5, z)
		collider.shape = shape
		body.add_child(collider)

func _gather(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_gather(child, out)

func _selected(source: PackedScene, component: String = "") -> Mesh:
	var key := source.resource_path + "#" + component
	if _mesh_cache.has(key):
		return _mesh_cache[key] as Mesh
	var root := source.instantiate()
	var views: Array[MeshInstance3D] = []
	_gather(root, views)
	var mesh: Mesh
	for view in views:
		if (component.is_empty() and views.size() == 1) or str(view.name) == component:
			mesh = view.mesh
			break
	root.free()
	if mesh == null:
		push_error("Missing authored mesh: " + key)
		return null
	_mesh_cache[key] = mesh
	return mesh

func _part(label: String, source: PackedScene, component: String, at: Vector3, euler: Vector3) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = _selected(source, component)
	view.position = at
	view.rotation = euler
	view.set_meta("source_component", component)
	add_child(view, true)
	return view

func _ground(label: String, source: PackedScene, x: float, z: float, yaw: float, rise: float = 0.0) -> void:
	var mesh := _selected(source)
	if mesh == null:
		return
	var bounds := mesh.get_aabb()
	var center := bounds.get_center()
	var body := StaticBody3D.new()
	body.name = label
	body.position = Vector3(x, floor_y + rise, z)
	body.rotation.y = yaw
	add_child(body)
	var view := MeshInstance3D.new()
	view.name = "AuthoredMesh"
	view.mesh = mesh
	# Recenter the original single mesh, including source pivot offsets.
	# The visible bottom touches pavement and the collision follows yaw.
	view.position = Vector3(-center.x, -bounds.position.y, -center.z)
	body.add_child(view)
	var collider := CollisionShape3D.new()
	collider.name = "BoundsCollider"
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	collider.shape = shape
	collider.position.y = bounds.size.y * 0.5
	body.add_child(collider)

func _fixture(label: String, x: float, z: float, yaw: float) -> void:
	var fixture := Node3D.new()
	fixture.name = label
	fixture.position = Vector3(x, 3.05, z)
	fixture.rotation.y = yaw
	add_child(fixture)
	var view := MeshInstance3D.new()
	view.name = "CagedFixture"
	view.mesh = _selected(SCONCE, "industrial_caged_sconce_a")
	fixture.add_child(view)
	var lamp := OmniLight3D.new()
	lamp.name = "PracticalLight"
	lamp.position = Vector3(0, 0.12, 0.26)
	lamp.light_color = Color("ffc58a")
	lamp.light_energy = 1.15
	lamp.omni_range = 4.6
	lamp.omni_attenuation = 1.5
	# Two modest local fill sources only; native comparison will tune them.
	lamp.shadow_enabled = false
	fixture.add_child(lamp)
	_practicals.append(lamp)
