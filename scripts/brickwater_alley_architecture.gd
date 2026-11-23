extends Node3D
## Curated upper-storey kit assembly for the existing Brickwater service lane.
## The original solid parcel remains collision. BrickwaterEnvelope supplies
## opaque backing behind these real apertures.
const FACADE = preload("res://assets/models/polyhaven/modular_urban_apartments_facade/modular_urban_apartments_facade.gltf")
const ESCAPE = preload("res://assets/models/polyhaven/modular_fire_escape/modular_fire_escape.gltf")
const CABLE = preload("res://assets/models/polyhaven/modular_electric_cables/modular_electric_cables.gltf")
const HVAC = preload("res://assets/models/polyhaven/exterior_aircon_unit/exterior_aircon_unit.gltf")
const PIPE = preload("res://assets/models/polyhaven/modular_pipes/modular_pipes.gltf")
const Masonry = preload("res://scripts/photo_masonry.gd")
const NEIGHBOR_BLOCK = Vector2i(-1, 1)
const SERVICE_DEPTH = 0.27
const BAY_WIDTH = 3.0
const FIRST_LEVEL = 4.8
const LEVELS = 2
const MIN_Z = -12.0
const WORKROOM_START_Z = -7.2
static var _meshes: Dictionary = {}
static var _window_materials: Dictionary = {}
static var _night_factor: float = 0.0
var left_wall: float
var right_wall: float
var residential_only: bool = false

func configure(left: float, right: float, neighbor: bool = false) -> void:
	left_wall = left
	right_wall = right
	residential_only = neighbor

static func bay_count(neighbor: bool) -> int:
	return 4 if neighbor else 5

static func alley_masonry(west: bool) -> Material:
	return Masonry.surface(Color("aaa096") if west else Color("918b83"))

func _ready() -> void:
	# Local kit X spans -3..0, Y spans 0..3, and +Z faces the alley.
	for side in [-1, 1]:
		var wall := left_wall if side == -1 else right_wall
		var yaw := PI * 0.5 if side == -1 else -PI * 0.5
		var facade := Node3D.new()
		facade.name = "WestApartmentFront" if side == -1 else "EastApartmentFront"
		facade.position.x = wall
		add_child(facade)
		for level in range(LEVELS):
			for bay in range(bay_count(residential_only)):
				var z := MIN_Z + BAY_WIDTH * float(bay)
				if side == 1:
					z += BAY_WIDTH
				var y := FIRST_LEVEL + float(level) * 3.0
				var variant: String = ["centered_large_02", "centered_double_02", "centered_small_03", "centered_large_03", "offset_small_03"][(bay + level * 2 + (1 if side == 1 else 0) + (2 if residential_only else 0)) % 5]
				var at := Vector3(0, y, z)
				_place(facade, "PlasterBay", FACADE, "wall_window_" + variant, at, Basis(Vector3.UP, yaw))
				var window := _place(facade, "RecessedWindow", FACADE, "window_" + variant, at, Basis(Vector3.UP, yaw))
				_apply_occupancy(window, variant, int(side), level, bay)
				_place(facade, "Cornice", FACADE, "cornice_standard_standard_01", at + Vector3.UP * 2.8, Basis(Vector3.UP, yaw))
		# Cable trunks below the facade, along the original wall, with
		# source junction boxes and clips rather than floating wires.
		if not residential_only:
			_cable_run(wall, side)
	_escape_landing()
	_residential_ventilation()
	if residential_only:
		return
	_workroom()
	_service_entrance("EastServiceEntrance", right_wall, 6.85, -PI * 0.5, "centered_small_02")
	_overhead_spans()

func _workroom() -> void:
	# Retain the imported three-metre reveal and glazing at the original
	# address. The full workshop now continues behind it.
	var room := Node3D.new()
	room.name = "NightShiftWorkroom"
	room.position = Vector3(left_wall, 0.15, WORKROOM_START_Z)
	room.rotation.y = PI * 0.5
	add_child(room)
	var reveal := _place(room, "WindowReveal", FACADE, "wall_window_centered_large_03", Vector3.ZERO, Basis.IDENTITY)
	reveal.material_override = alley_masonry(true)
	var window := _place(room, "WorkroomGlass", FACADE, "window_centered_large_03", Vector3.ZERO, Basis.IDENTITY)
	for i in range(window.mesh.get_surface_count()):
		var source := window.mesh.surface_get_material(i) as StandardMaterial3D
		if source != null and source.resource_name.to_lower().contains("glass"):
			var glass := source.duplicate() as StandardMaterial3D
			glass.albedo_color = Color(0.74, 0.84, 0.81, 0.25)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.30
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			window.set_surface_override_material(i, glass)

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
	group.position = Vector3(left_wall, 0, -6.0)
	group.rotation.y = PI * 0.5
	add_child(group)
	var axes := Basis.IDENTITY
	# Align the back edge of the platform to the new face. Its source
	# bounds are Z=-0.85..0.514. Rail front aligns with the platform lip.
	for level in range(2):
		var y := 5.0 + 3.0 * float(level)
		_escape_piece(group, "Landing", "modular_fire_escape_platform_middle", Vector3(0, y, 0.85), axes)
		_escape_piece(group, "Guardrail", "modular_fire_escape_railing_middle", Vector3(0, y + 0.707, 1.09), axes)
	# Stair rises parallel to the wall from one landing level to the
	# next. Native review must confirm the stair tread/landing join.
	var stairs_basis := Basis.IDENTITY.scaled(Vector3(1.0, 0.749, 1.0))
	_escape_piece(group, "StairFlight", "modular_fire_escape_stairs", Vector3(0, 6.87, 1.14), stairs_basis)

func _escape_piece(group: Node3D, label: String, component: String, at: Vector3, axes: Basis) -> void:
	var view := _place(group, label, ESCAPE, component, at, axes)
	# Treads and guards occupy their actual shape, with no invisible box
	# across the gaps. Bake the tread fit into the triangle vertices.
	var faces := view.mesh.get_faces()
	for i in range(faces.size()):
		faces[i] = axes * faces[i]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "EscapeCollision"
	body.position = at
	group.add_child(body, true)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

func _service_entrance(label: String, wall: float, z: float, yaw: float, variant: String) -> void:
	# A closed door set into a real authored opening. Retain the original
	# parcel backing; do not advertise an enterable building yet.
	var body := StaticBody3D.new()
	body.name = label
	body.position = Vector3(wall, 0.14, z)
	body.rotation.y = yaw
	add_child(body)
	var at := Vector3(0, 0, SERVICE_DEPTH)
	_place(body, "AuthoredMasonryReveal", FACADE, "wall_door_" + variant, at, Basis.IDENTITY)
	_place(body, "ClosedServiceDoor", FACADE, "door_" + variant, at, Basis.IDENTITY)
	_place(body, "Header", FACADE, "cornice_standard_standard_01", at + Vector3.UP * 2.8, Basis.IDENTITY)
	# Approximate the thin extension only; the original building collider
	# still blocks the bulk of the parcel. No collision across the passage.
	var collision := CollisionShape3D.new()
	collision.name = "ServiceFrontCollider"
	var shape := BoxShape3D.new()
	var depth := 0.47 if variant == "centered_small_01" else 0.31
	shape.size = Vector3(3.0, 3.0, depth)
	collision.shape = shape
	collision.position = Vector3(-1.5, 1.5, depth * 0.5)
	body.add_child(collision)

func _overhead_spans() -> void:
	var group := Node3D.new()
	group.name = "OverheadUtilitySpans"
	add_child(group)
	var jacket := StandardMaterial3D.new()
	jacket.albedo_color = Color("29292a")
	jacket.roughness = 0.79
	jacket.metallic = 0.0
	# West feed/end are Z=3.0/-0.8; east feed/end are -0.6/3.2.
	# Each pair terminates at the existing mounted junction boxes,
	# rather than disappearing into the air or cutting through windows.
	for row in range(2):
		var west_z := -0.8 if row == 0 else 3.0
		var east_z := -0.6 if row == 0 else 3.2
		for strand in range(2):
			var offset := -0.018 + float(strand) * 0.035
			var a := Vector3(left_wall + 0.038, 4.30, west_z + offset)
			var b := Vector3(right_wall - 0.038, 4.30, east_z + offset)
			var sag := 0.30 + float(row) * 0.08 + float(strand) * 0.10
			var view := MeshInstance3D.new()
			view.name = "UtilityCable_%d_%d" % [row, strand]
			view.mesh = _cable_mesh(a, b, sag)
			view.material_override = jacket
			view.set_meta("west_anchor", a)
			view.set_meta("east_anchor", b)
			group.add_child(view)

func _cable_mesh(a: Vector3, b: Vector3, sag: float) -> ArrayMesh:
	# A continuous UV-mapped round cable, not disconnected rods. Fixed
	# quadratic sag and radial normals; 24 segments x 8 sides x 2 tris.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var segments := 24
	var sides := 8
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var center := a.lerp(b, t) - Vector3.UP * (4.0 * sag * t * (1.0 - t))
		var tangent := (b - a - Vector3.UP * (4.0 * sag * (1.0 - 2.0 * t))).normalized()
		var lateral := tangent.cross(Vector3.UP).normalized()
		var vertical := lateral.cross(tangent).normalized()
		for j in range(sides + 1):
			var angle := TAU * float(j) / float(sides)
			var normal := vertical * cos(angle) + lateral * sin(angle)
			vertices.append(center + normal * 0.013)
			normals.append(normal)
			uv.append(Vector2(t * a.distance_to(b), float(j) / float(sides)))
	for i in range(segments):
		for j in range(sides):
			var p := i * (sides + 1) + j
			var q := p + sides + 1
			indices.append_array(PackedInt32Array([p, q, q + 1, p, q + 1, p + 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func set_window_night_factor(value: float) -> void:
	# City clock drives shared surface-only copies. No per-window process
	# callbacks, dynamic lights or changes to the imported source material.
	_night_factor = clampf(value, 0.0, 1.0)
	for key in _window_materials:
		var material: StandardMaterial3D = _window_materials[key]
		var state: int = int(material.get_meta("occupancy_state"))
		material.emission_energy_multiplier = _occupancy_energy(state)

static func _occupancy_energy(state: int) -> float:
	var intensity := smoothstep(0.30, 0.85, _night_factor)
	return (0.65 if state == 1 else 0.35) * intensity

func _apply_occupancy(view: MeshInstance3D, variant: String, side: int, level: int, bay: int) -> void:
	# The pinned source glTF contains separate glass primitives: index 2
	# on centered_small_03 and index 1 on the other four selected variants.
	# Source frame/trim materials remain unchanged.
	var surface := 2 if variant == "centered_small_03" else 1
	var original := view.mesh.surface_get_material(surface) as StandardMaterial3D
	if original == null or not original.resource_name.to_lower().contains("glass"):
		push_error("Unexpected Brickwater glazing material: " + variant)
		return
	# Fixed asymmetric composition; no runtime randomness or save mutation.
	var selector := posmod(bay * 7 + level * 3 + (2 if side == 1 else 0) + (3 if residential_only else 0), 7)
	# Avoid a regular alternating pattern: the bay term must vary modulo 7.
	selector = posmod(selector + bay * bay + bay * 2, 7)
	var state := 1 if selector in [0, 3] else (2 if selector == 5 else 0)
	view.set_meta("occupancy_state", state)
	view.set_meta("glazing_surface", surface)
	if state == 0:
		return
	var key := "%s:%d" % [str(original.get_instance_id()), state]
	if not _window_materials.has(key):
		var glass := original.duplicate() as StandardMaterial3D
		glass.resource_name = "BrickwaterWarmOccupiedGlass" if state == 1 else "BrickwaterCoolOccupiedGlass"
		glass.set_meta("occupancy_state", state)
		glass.emission_enabled = true
		glass.emission = Color("e7b987") if state == 1 else Color("91b8ba")
		glass.emission_energy_multiplier = _occupancy_energy(state)
		# Keep the imported albedo/normal/roughness and glass alpha behavior.
		# This is an illuminated surface, not a modeled room or a light source.
		_window_materials[key] = glass
	view.set_surface_override_material(surface, _window_materials[key])

func _residential_ventilation() -> void:
	# Handpicked narrow-window bays: unit remains to the left of the
	# glazing, clear of cornices and the west emergency stair flight.
	# [side, level, bay, weathered variant]. These are fixed parcel sites,
	# not random decorations. The existing glTF contains the support legs.
	var sites := [[-1,1,0,true],[1,0,1,false],[1,0,3,true]]
	if residential_only:
		sites = [[-1,0,0,false],[1,0,1,true],[1,1,2,false]]
	var group := Node3D.new()
	group.name = "ResidentialVentilation"
	add_child(group)
	for i in range(sites.size()):
		var site: Array = sites[i]
		var side: int = site[0]
		var level: int = site[1]
		var bay: int = site[2]
		var worn: bool = site[3]
		var wall := left_wall if side == -1 else right_wall
		var yaw := PI * 0.5 if side == -1 else -PI * 0.5
		var z := MIN_Z + BAY_WIDTH * float(bay) + (BAY_WIDTH if side == 1 else 0.0)
		var y := FIRST_LEVEL + float(level) * 3.0
		var fixture := Node3D.new()
		fixture.name = "VentilationBay_%d" % i
		fixture.position = Vector3(wall, y, z)
		fixture.rotation.y = yaw
		fixture.set_meta("bay", Vector3i(side, level, bay))
		group.add_child(fixture)
		# Source AABB rear Z=-0.216: offset by the exact depth so the
		# support/back meets the facade at local Z=0, not a floating gap.
		var component := "exterior_aircon_unit_rusted" if worn else "exterior_aircon_unit"
		var unit := _place(fixture, "ScannedCondenser", HVAC, component, Vector3(-2.43,0.82,0.216), Basis.IDENTITY)
		unit.set_meta("authored_ventilation", true)
		# Thin metal service line descends behind the unit, then connects
		# into the wall. The original pipe axis is +X; rotate it downward.
		var line_axes := Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.62,1.0,1.0))
		_place(fixture, "CondensateLine", PIPE, "pipe_thin_100cm_metal", Vector3(-2.76,0.67,0.055), line_axes)
		# A short section of the same source pipe into the facade.
		var return_axes := Basis(Vector3.UP, -PI * 0.5) * Basis.from_scale(Vector3(0.055,1.0,1.0))
		_place(fixture, "WallReturn", PIPE, "pipe_thin_100cm_metal", Vector3(-2.76,0.05,0.0), return_axes)
		# The pipe support source is oriented along +Z from masonry.
		var clamp_axes := Basis.IDENTITY * Basis.from_scale(Vector3(1.0,1.0,0.55))
		_place(fixture, "MountedPipeClamp", PIPE, "pipe_thin_support_metal", Vector3(-2.76,0.34,0.0), clamp_axes)
