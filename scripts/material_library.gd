extends RefCounted
## Shared, deterministic PBR textures for the entire city. No external asset dependencies.
## Albedo, tangent-space normals and roughness retain the original offline bake.
const BAKED_MAPS = preload("res://assets/pbr/nightgrid/city_material_maps.res")
const StreamProfile = preload("res://scripts/streaming_profile.gd")
static var _maps: Dictionary = {}
static var _normals: Dictionary = {}
static var _roughness_maps: Dictionary = {}
static var _surfaces: Dictionary = {}
const Weather = preload("res://scripts/city_surface_weather.gd")
static var _photo_ground: Dictionary = {}
static var _ground_film := 0.0
const PHOTO_CONCRETE_ROOT = "res:" + "//assets/models/nightgrid/central_exchange_curb/textures/concrete_"

static func surface(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + "|" + tint.to_html(false)
	if _surfaces.has(key):
		return _surfaces[key]
	if kind == "PHOTO_SIDEWALK" or kind == "PHOTO_CURB":
		return _photo_concrete(kind,tint,key)
	_ensure_maps(kind)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = _maps[kind]
	material.normal_enabled = true
	material.normal_texture = _normals[kind]
	material.normal_scale = 0.62 if kind == "GLASS" else 0.90
	material.roughness_texture = _roughness_maps[kind]
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 1.0
	# Continuous world-space mapping means neighboring facades and large ground boxes
	# don't stretch a tiny tile over their entire dimensions.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.21, 0.21, 0.21)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"METAL":
			material.metallic = 0.78
		"GLASS":
			# Opaque tinted windows for distant buildings; physically plausible
			# low metalness and smoother specular response than painted concrete.
			material.metallic = 0.03
			material.uv1_scale = Vector3(0.14, 0.14, 0.14)
		"WET":
			material.metallic = 0.02
			material.uv1_scale = Vector3(0.30, 0.30, 0.30)
		_:
			material.metallic = 0.0
	_surfaces[key] = material
	return material

static func _photo_concrete(kind: String,tint: Color,key: String) -> StandardMaterial3D:
	# Reuse the actual CC0 concrete_floor_01 maps already imported with
	# the Central Exchange curb kit; green is the packed roughness channel.
	var material := StandardMaterial3D.new()
	var started := StreamProfile.begin()
	material.albedo_texture = load(PHOTO_CONCRETE_ROOT+"base_1k.jpg") as Texture2D
	material.normal_texture = load(PHOTO_CONCRETE_ROOT+"normal_1k.jpg") as Texture2D
	material.roughness_texture = load(PHOTO_CONCRETE_ROOT+"arm_1k.png") as Texture2D
	StreamProfile.end(started, "photo_texture_resource_load", kind)
	if material.albedo_texture==null or material.normal_texture==null or material.roughness_texture==null:
		push_error("Photo concrete maps unavailable")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_scale = 0.72
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.roughness = 1.0
	material.metallic = 0.0
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.5,0.5,0.5)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.clearcoat_enabled = true
	material.clearcoat = 0.0
	material.clearcoat_roughness = .22
	_photo_ground[key] = {"material": material, "tint": tint, "drainage": .42 if kind == "PHOTO_SIDEWALK" else .32}
	Weather.apply(material, _ground_film, tint, 1.0, .72, _photo_ground[key]["drainage"])
	_surfaces[key] = material
	return material

static func set_surface_film(film: float) -> void:
	var value := clampf(film, 0.0, 1.0)
	if is_equal_approx(value, _ground_film):
		return
	_ground_film = value
	for entry in _photo_ground.values():
		Weather.apply(entry["material"], value, entry["tint"], 1.0, .72, entry["drainage"])

static func _ensure_maps(kind: String) -> void:
	if _maps.has(kind):
		return
	# The old generator's default branch matches WOOD for unknown kinds.
	var images: Dictionary = BAKED_MAPS.get_meta("images")
	var channels: Array = images.get(kind, images["WOOD"])
	var started := StreamProfile.begin()
	_maps[kind] = ImageTexture.create_from_image(channels[0])
	_normals[kind] = ImageTexture.create_from_image(channels[1])
	_roughness_maps[kind] = ImageTexture.create_from_image(channels[2])
	StreamProfile.end(started, "texture_submission", kind)

static func material_count() -> int:
	return _surfaces.size()

static func texture_count() -> int:
	return _maps.size()

static func normal_count() -> int:
	return _normals.size()

static func roughness_count() -> int:
	return _roughness_maps.size()
