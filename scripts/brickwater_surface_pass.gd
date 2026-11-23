extends Node3D
## Local material pass. No global materials mutated, no collision changes.
const Maps = preload("res://scripts/material_library.gd")
const WallArt = preload("res://scripts/brickwater_wall_art.gd")
const WET_SHADER = preload("res://scripts/shaders/brickwater_wet_concrete.gdshader")
const WET_MASK = preload("res://assets/models/nightgrid/brickwater_alley/wetness_mask.svg")
const GRIME = preload("res://assets/models/nightgrid/brickwater_alley/alley_weathering.svg")
const SEEP = preload("res://assets/models/nightgrid/brickwater_alley/wall_seepage.svg")
const TAG_SMALL = preload("res://assets/models/nightgrid/brickwater_alley/graffiti_chalk.svg")
const REPAIR_EMITTER = preload("res://assets/models/nightgrid/brickwater_alley/repair_neon_blade_emitter.png")
const LAUNDRY_EMITTER = preload("res://assets/models/nightgrid/brickwater_alley/laundry_neon_blade_emitter.png")
static var _pavement: ShaderMaterial
var left_wall: float
var right_wall: float

func configure(left: float, right: float) -> void:
	left_wall = left
	right_wall = right

static func pavement_material() -> ShaderMaterial:
	if _pavement == null:
		_pavement = ShaderMaterial.new()
		_pavement.shader = WET_SHADER
		_pavement.set_shader_parameter("concrete_color", load(Maps.PHOTO_CONCRETE_ROOT + "base_1k.jpg"))
		_pavement.set_shader_parameter("concrete_normal", load(Maps.PHOTO_CONCRETE_ROOT + "normal_1k.jpg"))
		_pavement.set_shader_parameter("concrete_arm", load(Maps.PHOTO_CONCRETE_ROOT + "arm_1k.png"))
		_pavement.set_shader_parameter("wetness_atlas", WET_MASK)
		_pavement.set_shader_parameter("grime_atlas", GRIME)
		_pavement.set_shader_parameter("repair_emitter", REPAIR_EMITTER)
		_pavement.set_shader_parameter("laundry_emitter", LAUNDRY_EMITTER)
	return _pavement

func _ready() -> void:
	# Keep runoff on solid masonry and away from the transparent workroom.
	_overlay("WestWallRunoff", SEEP, Vector2(4.5, 4.6), Vector3(left_wall + 0.009, 2.45, -9.6), PI * 0.5)
	_overlay("EastWallRunoff", SEEP, Vector2(18.0, 4.6), Vector3(right_wall - 0.013, 2.45, -3.0), -PI * 0.5)
	_overlay("FadedChalkTag", TAG_SMALL, Vector2(1.45, 0.725), Vector3(left_wall + 0.019, 1.05, 3.45), PI * 0.5)
	var art := WallArt.new()
	art.name = "WallStorytelling"
	add_child(art)
	art.install(left_wall, right_wall)

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
