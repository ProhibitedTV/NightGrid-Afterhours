extends Node3D
## Local material pass. No global materials mutated, no collision changes.
const Maps = preload("res://scripts/material_library.gd")
const BRICK_COLOR = preload("res://assets/pbr/polyhaven/brick_wall_001_diffuse_2k.jpg")
const BRICK_NORMAL = preload("res://assets/pbr/polyhaven/brick_wall_001_nor_gl_2k.png")
const BRICK_ROUGH = preload("res://assets/pbr/polyhaven/brick_wall_001_rough_2k.png")
const SIGN_WEST = preload("res://assets/models/nightgrid/brickwater_alley/night_shift_repairs.svg")
const SIGN_EAST = preload("res://assets/models/nightgrid/brickwater_alley/jade_laundry.svg")
const WET_SHADER = preload("res://scripts/shaders/brickwater_wet_concrete.gdshader")
const WET_MASK = preload("res://assets/models/nightgrid/brickwater_alley/wetness_mask.svg")
const GRIME = preload("res://assets/models/nightgrid/brickwater_alley/alley_weathering.svg")
const SEEP = preload("res://assets/models/nightgrid/brickwater_alley/wall_seepage.svg")
const TAG_WEST = preload("res://assets/models/nightgrid/brickwater_alley/graffiti_switchyard.svg")
const TAG_EAST = preload("res://assets/models/nightgrid/brickwater_alley/graffiti_lowline.svg")
const TAG_SMALL = preload("res://assets/models/nightgrid/brickwater_alley/graffiti_chalk.svg")
static var _pavement: ShaderMaterial
static var _brick: StandardMaterial3D
var left_wall: float
var right_wall: float
var floor_y: float

func configure(left: float, right: float, y: float) -> void:
	left_wall = left
	right_wall = right
	floor_y = y

static func pavement_material() -> ShaderMaterial:
	if _pavement == null:
		_pavement = ShaderMaterial.new()
		_pavement.shader = WET_SHADER
		_pavement.set_shader_parameter("concrete_color", load(Maps.PHOTO_CONCRETE_ROOT + "base_1k.jpg"))
		_pavement.set_shader_parameter("concrete_normal", load(Maps.PHOTO_CONCRETE_ROOT + "normal_1k.jpg"))
		_pavement.set_shader_parameter("concrete_arm", load(Maps.PHOTO_CONCRETE_ROOT + "arm_1k.png"))
		_pavement.set_shader_parameter("wetness_atlas", WET_MASK)
		_pavement.set_shader_parameter("grime_atlas", GRIME)
	return _pavement

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
	# Separate paint/runoff layers preserve the photographed masonry normals.
	_overlay("WestWallRunoff", SEEP, Vector2(18.0, 4.6), Vector3(left_wall + 0.013, 2.45, -3.0), PI * 0.5)
	_overlay("EastWallRunoff", SEEP, Vector2(18.0, 4.6), Vector3(right_wall - 0.013, 2.45, -3.0), -PI * 0.5)
	_overlay("SwitchyardPaint", TAG_WEST, Vector2(2.8, 1.4), Vector3(left_wall + 0.019, 1.85, -6.7), PI * 0.5)
	_overlay("LowlinePaint", TAG_EAST, Vector2(2.65, 1.325), Vector3(right_wall - 0.019, 1.70, -3.0), -PI * 0.5)
	_overlay("FadedChalkTag", TAG_SMALL, Vector2(1.45, 0.725), Vector3(left_wall + 0.019, 1.05, 3.45), PI * 0.5)
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

func _overlay(label: String, texture: Texture2D, size: Vector2, at: Vector3, yaw: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.92
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var view := _quad(label, size, at, yaw, m)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.set_meta("surface_art", true)
