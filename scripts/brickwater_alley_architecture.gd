extends Node3D
## Curated upper-storey kit assembly for the existing Brickwater service lane.
## The original solid parcel remains the collision/backing, not an interior.
const FACADE = preload("res://assets/models/polyhaven/modular_urban_apartments_facade/modular_urban_apartments_facade.gltf")
const ESCAPE = preload("res://assets/models/polyhaven/modular_fire_escape/modular_fire_escape.gltf")
const CABLE = preload("res://assets/models/polyhaven/modular_electric_cables/modular_electric_cables.gltf")
const FACE_OFFSET := 0.27
const BAY_WIDTH := 3.0
const FIRST_LEVEL := 4.8
const LEVELS := 2
const MIN_Z := -12.0
const MAX_Z := 3.0
static var _meshes: Dictionary = {}
var left_wall: float
var right_wall: float

func configure(left: float, right: float) -> void:
	left_wall = left
	right_wall = right

func _ready() -> void:
	# Local kit X spans -3..0, Y spans 0..3, and +Z faces the alley.
	# The nearest glazing is at -0.214; 0.27m offset keeps it ahead of
	# the original box backing instead of buried inside the solid parcel.
	for side in [-1, 1]:
		var wall := left_wall if side == -1 else right_wall
		var yaw := PI * 0.5 if side == -1 else -PI * 0.5
		var face_x := wall + FACE_OFFSET * -float(side)
		var facade := Node3D.new()
		facade.name = "WestApartmentFront" if side == -1 else "EastApartmentFront"
		facade.position.x = face_x
		add_child(facade)
		for level in range(LEVELS):
			for bay in range(5):
				var z := MIN_Z + BAY_WIDTH * float(bay)
				if side == 1:
					z += BAY_WIDTH
				var y := FIRST_LEVEL + float(level) * 3.0
				var variant: String = ["centered_large_02", "centered_double_02", "centered_small_03", "centered_large_03", "offset_small_03"][(bay + level * 2 + (1 if side == 1 else 0)) % 5]
				var at := Vector3(0, y, z)
				_place(facade, "PlasterBay", FACADE, "wall_window_" + variant, at, Basis(Vector3.UP, yaw))
				_place(facade, "RecessedWindow", FACADE, "window_" + variant, at, Basis(Vector3.UP, yaw))
				_place(facade, "Cornice", FACADE, "cornice_standard_standard_01", at + Vector3.UP * 2.8, Basis(Vector3.UP, yaw))
		# Cable trunks below the facade, along the original wall, with
		# source junction boxes and clips rather than floating wires.
		_cable_run(wall, side)
	_escape_landing()

func _collect(node: Node, cache: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		cache[str(node.name)] = node.mesh
	for child in node.get_children():
		_collect(child, cache)

func _mesh(source: PackedScene, component: String) -> Mesh:
	var path := source.resource_path
	if not _meshes.has(path):
		var root := source.instantiate()
		var cache: Dictionary = {}
		_collect(root, cache)
		root.free()
		_meshes[path] = cache
	var result: Mesh = _meshes[path].get(component)
	if result == null:
		push_error("Missing Brickwater architecture component: " + component)
	return result

func _place(parent: Node3D, label: String, source: PackedScene, component: String, at: Vector3, axes: Basis) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = _mesh(source, component)
	view.transform = Transform3D(axes, at)
	view.set_meta("source_component", component)
	parent.add_child(view, true)
	return view

func _cable_run(wall: float, side: int) -> void:
	var group := Node3D.new()
	group.name = "WestElectricalTrunk" if side == -1 else "EastElectricalTrunk"
	add_child(group)
	# Source cable local X is outward, local Y is the route axis, local
	# Z is lateral. Discard showroom rotation; keep a right-handed basis.
	var outward := Vector3(-float(side), 0, 0)
	var along := Vector3(0, 0, float(side))
	var axes := Basis(outward, along, Vector3.UP)
	var start := Vector3(wall + outward.x * 0.006, 4.30, -0.6 if side == 1 else 3.0)
	_place(group, "FeedBox", CABLE, "cable_box_double", start, axes)
	for i in range(6):
		var at := start + along * (0.2 + 0.6 * float(i))
		_place(group, "TwinCable", CABLE, "cable_double_alt_long", at, axes)
		_place(group, "CableClip", CABLE, "cable_double_mount", at + along * 0.3, axes)
	_place(group, "EndBox", CABLE, "cable_box_double", start + along * 3.8, axes)

func _escape_landing() -> void:
	# Authored landing, rail and stair modules on the west wall. These
	# are above the vehicle/pedestrian route, not a climbable shortcut.
	var group := Node3D.new()
	group.name = "WestEmergencyEscape"
	group.position = Vector3(left_wall + FACE_OFFSET, 0, -6.0)
	group.rotation.y = PI * 0.5
	add_child(group)
	var axes := Basis.IDENTITY
	# Align the back edge of the platform to the new face. Its source
	# bounds are Z=-0.85..0.514. Rail front aligns with the platform lip.
	for level in range(2):
		var y := 5.0 + 3.0 * float(level)
		_place(group, "Landing", ESCAPE, "modular_fire_escape_platform_middle", Vector3(0, y, 0.85), axes)
		_place(group, "Guardrail", ESCAPE, "modular_fire_escape_railing_middle", Vector3(0, y + 0.707, 1.09), axes)
	# Stair rises parallel to the wall from one landing level to the
	# next. Native review must confirm the stair tread/landing join.
	var stairs_basis := Basis.IDENTITY.scaled(Vector3(1.0, 0.749, 1.0))
	_place(group, "StairFlight", ESCAPE, "modular_fire_escape_stairs", Vector3(0, 6.87, 1.14), stairs_basis)
