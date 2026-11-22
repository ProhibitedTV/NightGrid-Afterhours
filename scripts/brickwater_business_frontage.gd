extends Node3D
## Original sheet-metal geometry and double-sided illuminated blade signs.
const WEST_ART = preload("res://assets/models/nightgrid/brickwater_alley/night_shift_repairs.svg")
const EAST_ART = preload("res://assets/models/nightgrid/brickwater_alley/jade_laundry.svg")
const METAL_COLOR = preload("res://assets/pbr/polyhaven/blue_metal_plate_diffuse_2k.jpg")
const METAL_NORMAL = preload("res://assets/pbr/polyhaven/blue_metal_plate_nor_gl_2k.png")
const METAL_ROUGH = preload("res://assets/pbr/polyhaven/blue_metal_plate_rough_2k.png")
var left_wall: float
var right_wall: float
static var _metal: StandardMaterial3D

func configure(left: float, right: float) -> void:
	left_wall = left
	right_wall = right

func _ready() -> void:
	_blade("RepairBlade", left_wall, -1.6, PI * 0.5, WEST_ART)
	_blade("LaundryBlade", right_wall, 2.8, -PI * 0.5, EAST_ART)
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

func _blade(label: String, wall: float, z: float, yaw: float, art: Texture2D) -> void:
	var body := _body(label, wall, 3.54, z, yaw)
	# Locally +Z points into alley; octagonal profile in YZ forms the
	# rounded corners of the enamel sign housing. Rear reaches masonry.
	var outline := [Vector2(-0.18,0.06), Vector2(-0.22,0.10), Vector2(-0.22,0.88),
		Vector2(-0.18,0.92), Vector2(0.18,0.92), Vector2(0.22,0.88),
		Vector2(0.22,0.10), Vector2(0.18,0.06)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		_quad(tool, Vector3(-0.055,a.x,a.y), Vector3(0.055,a.x,a.y), Vector3(0.055,b.x,b.y), Vector3(-0.055,b.x,b.y))
	# Mounting strap spans the wall-to-housing gap.
	for y in [-0.14,0.14]:
		_quad(tool, Vector3(-0.045,y-0.035,0.0), Vector3(0.045,y-0.035,0.0), Vector3(0.045,y+0.035,0.13), Vector3(-0.045,y+0.035,0.13))
	_view(body, "FoldedEnamelHousing", _finish(tool), _steel())
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = art
	face_mat.emission_enabled = true
	face_mat.emission_texture = art
	face_mat.emission = Color.WHITE
	face_mat.emission_energy_multiplier = 0.9
	face_mat.roughness = 0.55
	for side in [-1.0,1.0]:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.80,0.37)
		var face := _view(body,"PrintedBladeFace",quad,face_mat)
		face.position = Vector3(float(side)*0.056,0,0.49)
		face.rotation.y = float(side)*PI*0.5
	_collider(body, Vector3(0,0,0.46), Vector3(0.112,0.44,0.92))

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
	_collider(body,Vector3(0,-0.10,0.46),Vector3(1.94,0.25,0.92))
