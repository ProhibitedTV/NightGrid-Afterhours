extends Node3D
## Local material pass. No global materials mutated, no collision changes.
const Maps = preload("res://scripts/material_library.gd")
const BRICK_COLOR = preload("res://assets/pbr/polyhaven/brick_wall_001_diffuse_2k.jpg")
const BRICK_NORMAL = preload("res://assets/pbr/polyhaven/brick_wall_001_nor_gl_2k.png")
const BRICK_ROUGH = preload("res://assets/pbr/polyhaven/brick_wall_001_rough_2k.png")
const SIGN_WEST = preload("res://assets/models/nightgrid/brickwater_alley/night_shift_repairs.svg")
const SIGN_EAST = preload("res://assets/models/nightgrid/brickwater_alley/jade_laundry.svg")
static var _damp: StandardMaterial3D
static var _water: StandardMaterial3D
static var _brick: StandardMaterial3D
var left_wall: float
var right_wall: float
var floor_y: float

func configure(left: float, right: float, y: float) -> void:
	left_wall = left
	right_wall = right
	floor_y = y

static func damp_concrete() -> StandardMaterial3D:
	if _damp == null:
		_damp = Maps.surface("PHOTO_SIDEWALK", Color("797870")).duplicate() as StandardMaterial3D
		_damp.albedo_color = Color("64645e")
		_damp.roughness = 0.67
		_damp.clearcoat_enabled = true
		_damp.clearcoat = 0.25
		_damp.clearcoat_roughness = 0.32
	return _damp

static func puddle_material() -> StandardMaterial3D:
	if _water == null:
		_water = damp_concrete().duplicate() as StandardMaterial3D
		_water.albedo_color = Color("454946")
		_water.roughness_texture = null
		_water.roughness = 0.13
		_water.normal_scale = 0.12
		_water.clearcoat = 0.72
		_water.clearcoat_roughness = 0.10
	return _water

static func brick_material() -> StandardMaterial3D:
	if _brick == null:
		_brick = StandardMaterial3D.new()
		_brick.albedo_texture = BRICK_COLOR
		_brick.albedo_color = Color("a29a8f")
		_brick.normal_enabled = true
		_brick.normal_texture = BRICK_NORMAL
		_brick.normal_scale = 0.8
		_brick.roughness_texture = BRICK_ROUGH
		_brick.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		_brick.roughness = 0.83
		_brick.uv1_triplanar = true
		_brick.uv1_world_triplanar = true
		_brick.uv1_scale = Vector3.ONE * 0.5
		_brick.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _brick

func _ready() -> void:
	# Refinish the lower west wall only. The actual parcel shell stays
	# solid and upper apartment panels begin above this finish.
	_quad("LowerWestMasonry", Vector2(18.0, 4.6), Vector3(left_wall + 0.008, 2.45, -3.0), PI * 0.5, brick_material())
	var middle := (left_wall + right_wall) * 0.5
	_puddle("DrainRunoff", middle + 0.55, -2.6, 0.45, 1.15, 0.7)
	_puddle("LowPointPuddle", middle - 0.15, 2.1, 0.74, 1.55, 2.3)
	_puddle("EntryRunoff", middle - 0.40, -10.0, 0.40, 0.75, 4.1)
	# Signs are flush wall plates, not hovering billboards or new lights.
	_sign("NightShiftRepairs", SIGN_WEST, left_wall + 0.033, -1.6, PI * 0.5)
	_sign("JadeLaundry", SIGN_EAST, right_wall - 0.033, 2.8, -PI * 0.5)

func _quad(label: String, size: Vector2, at: Vector3, yaw: float, material: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = q
	view.position = at
	view.rotation.y = yaw
	view.material_override = material
	add_child(view)
	return view

func _sign(label: String, texture: Texture2D, x: float, z: float, yaw: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.85
	m.roughness = 0.60
	var sign := _quad(label, Vector2(1.44, 0.56), Vector3(x, 2.46, z), yaw, m)
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _puddle(label: String, x: float, z: float, rx: float, rz: float, phase: float) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var tangents := PackedFloat32Array()
	for segment in range(24):
		var a := _edge(TAU * float(segment) / 24.0, rx, rz, phase)
		var b := _edge(TAU * float(segment + 1) / 24.0, rx, rz, phase)
		for p in [Vector3.ZERO, a, b]:
			vertices.append(p)
			normals.append(Vector3.UP)
			uv.append(Vector2(p.x / (rx * 2.0) + 0.5, p.z / (rz * 2.0) + 0.5))
			tangents.append_array(PackedFloat32Array([1, 0, 0, 1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.position = Vector3(x, floor_y + 0.009, z)
	view.material_override = puddle_material()
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)

func _edge(angle: float, rx: float, rz: float, phase: float) -> Vector3:
	var wave := 0.88 + 0.07 * sin(3.0 * angle + phase) + 0.04 * cos(7.0 * angle - phase)
	return Vector3(cos(angle) * rx * wave, 0, sin(angle) * rz * wave)
