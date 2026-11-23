extends Node3D
## Original sheet-metal geometry and double-sided illuminated blade signs.
const WEST_BLADE = preload("res://assets/models/nightgrid/brickwater_alley/repair_neon_blade.gltf")
const EAST_BLADE = preload("res://assets/models/nightgrid/brickwater_alley/laundry_neon_blade.gltf")
# Footprint and practical-light anchors shared with the staged alley.
const BLADE_HEIGHT = 3.82
const REPAIR_Z = -2.95
const LAUNDRY_Z = 2.80
const METAL_COLOR = preload("res://assets/pbr/polyhaven/blue_metal_plate_diffuse_2k.jpg")
const METAL_NORMAL = preload("res://assets/pbr/polyhaven/blue_metal_plate_nor_gl_2k.png")
const METAL_ROUGH = preload("res://assets/pbr/polyhaven/blue_metal_plate_rough_2k.png")
var left_wall: float
var right_wall: float
static var _metal: StandardMaterial3D
static var _neon_materials: Dictionary = {}
static var _neon_power: Dictionary = {}
static var _night := 0.0

static func set_night_factor(value: float) -> void:
	_night = smoothstep(0.3, 0.85, value)
	for key in _neon_materials:
		var material: StandardMaterial3D = _neon_materials[key]
		material.emission_energy_multiplier = float(_neon_power[key]) * _night

func configure(left: float, right: float) -> void:
	left_wall = left
	right_wall = right

func _ready() -> void:
	_blade("RepairBlade", left_wall, REPAIR_Z, PI * 0.5, WEST_BLADE)
	_blade("LaundryBlade", right_wall, LAUNDRY_Z, -PI * 0.5, EAST_BLADE)
	_canopy("RepairRainShelter", left_wall, 0.9, PI * 0.5)
	_canopy("LaundryRainShelter", right_wall, 5.35, -PI * 0.5)

static func _steel() -> StandardMaterial3D:
	if _metal == null:
		_metal = StandardMaterial3D.new()
		_metal.albedo_color = Color("767470")
		_metal.albedo_texture = METAL_COLOR
		_metal.normal_enabled = true
		_metal.normal_texture = METAL_NORMAL
		_metal.roughness_texture = METAL_ROUGH
		_metal.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		_metal.metallic = 0.65
		_metal.roughness = 0.85
		_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _metal

func _body(label: String, wall: float, y: float, z: float, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = Vector3(wall, y, z)
	body.rotation.y = yaw
	add_child(body)
	return body

func _view(body: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.material_override = material
	body.add_child(view)
	return view

func _collider(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.name = "MeasuredEnvelope"
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = at
	body.add_child(collider)

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var points := [a,b,c,a,c,d]
	var uvs := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]
	for i in range(6):
		tool.set_uv(uvs[i])
		tool.add_vertex(points[i])

func _finish(tool: SurfaceTool) -> ArrayMesh:
	tool.generate_normals()
	tool.generate_tangents()
	return tool.commit()

func _blade(label: String, wall: float, z: float, yaw: float, source: PackedScene) -> void:
	var body := _body(label, wall, BLADE_HEIGHT, z, yaw)
	var assembly := source.instantiate() as Node3D
	assembly.name = "AuthoredNeon"
	body.add_child(assembly)
	for view: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
		var bounds := view.mesh.get_aabb()
		_collider(body, bounds.get_center(), bounds.size)
		for surface in range(view.mesh.get_surface_count()):
			var original := view.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null or not original.emission_enabled:
				continue
			var key := source.resource_path + "#" + str(surface)
			if not _neon_materials.has(key):
				var material := original.duplicate() as StandardMaterial3D
				var power := 2.85 if source == WEST_BLADE else 2.2
				material.emission_energy_multiplier = power * _night
				_neon_materials[key] = material
				_neon_power[key] = power
			view.set_surface_override_material(surface, _neon_materials[key])

func _canopy(label: String, wall: float, z: float, yaw: float) -> void:
	var body := _body(label, wall, 3.40, z, yaw)
	# One continuous corrugated folded sheet. Corrugation along width,
	# ribs run down slope toward a rolled front drip edge.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 48
	for i in range(steps):
		var x0 := -0.97 + 1.94 * float(i) / float(steps)
		var x1 := -0.97 + 1.94 * float(i+1) / float(steps)
		var rib0 := 0.018 * cos(TAU * float(i)/4.0)
		var rib1 := 0.018 * cos(TAU * float(i+1)/4.0)
		_quad(tool, Vector3(x0,rib0,0.01), Vector3(x1,rib1,0.01), Vector3(x1,rib1-0.18,0.91), Vector3(x0,rib0-0.18,0.91))
		_quad(tool, Vector3(x0,rib0-0.18,0.91), Vector3(x1,rib1-0.18,0.91), Vector3(x1,rib1-0.23,0.91), Vector3(x0,rib0-0.23,0.91))
	_view(body,"CorrugatedWeatheredSheet",_finish(tool),_steel())
	# Folded triangular steel gussets meet both masonry and canopy edge.
	var braces := SurfaceTool.new()
	braces.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in [-0.78,0.78]:
		for p in [Vector3(x,-0.31,0.0),Vector3(x,-0.025,0.0),Vector3(x,-0.16,0.84)]:
			braces.set_uv(Vector2(p.z,p.y+0.32))
			braces.add_vertex(p)
	_view(body,"WallMountedGussets",_finish(braces),_steel())
	_collider(body,Vector3(0,-0.14,0.46),Vector3(1.94,0.35,0.92))
