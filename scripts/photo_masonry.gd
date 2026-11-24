extends RefCounted
## Existing provenance-verified CC0 brick scan; no new binary assets.
## Shared across ordinary masonry shell visuals without mutating their
## collision, saved profiles, window layout or hero architecture.
const ROOT = "res:" + "//assets/pbr/polyhaven/brick_wall_001_"
const TILE_METRES = 2.5
static var _materials: Dictionary = {}
static var _dry_tints: Dictionary = {}
static var _film := 0.0
static var _albedo: Texture2D
static var _normal: Texture2D
static var _rough: Texture2D

static func surface(tint: Color) -> StandardMaterial3D:
	var key := tint.to_html(false)
	if _materials.has(key):
		return _materials[key]
	if _albedo == null or _normal == null or _rough == null:
		_albedo = load(ROOT+"diffuse_2k.jpg") as Texture2D
		_normal = load(ROOT+"nor_gl_2k.png") as Texture2D
		_rough = load(ROOT+"rough_2k.png") as Texture2D
	if _albedo == null or _normal == null or _rough == null:
		push_error("Ordinary masonry requires bundled CC0 brick_wall_001 maps")
	var m := StandardMaterial3D.new()
	# The photo supplies the real brick and mortar colors. Retain the
	# authored neighborhood tint as a subtle multiplier, not a dark paint.
	m.albedo_color = Color.WHITE.lerp(tint,0.38)
	m.albedo_texture = _albedo
	m.normal_enabled = true
	m.normal_texture = _normal
	m.normal_scale = 0.75
	m.roughness_texture = _rough
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.metallic = 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / TILE_METRES
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	_dry_tints[key] = m.albedo_color
	_apply_moisture(m, _dry_tints[key])
	return m

static func set_surface_film(film: float) -> void:
	var bounded := clampf(film, 0.0, 1.0)
	if is_equal_approx(bounded, _film):
		return
	_film = bounded
	for key in _materials:
		_apply_moisture(_materials[key], _dry_tints[key])

static func _apply_moisture(m: StandardMaterial3D, dry: Color) -> void:
	# Porous vertical brick absorbs rainfall instead of pooling. Keep the
	# photographed mortar/aggregate normal and roughness textures attached.
	var damp := smoothstep(0.0, 1.0, _film)
	m.albedo_color = dry.lerp(Color(dry.r * .70, dry.g * .73, dry.b * .76, dry.a), damp)
	m.roughness = lerpf(1.0, .76, damp)
	m.normal_scale = lerpf(.75, .66, damp)
