extends RefCounted
## Shared, deterministic PBR textures for the entire city. No external asset dependencies.
## Albedo, tangent-space normals and roughness are baked on demand, once per surface type.
const SIZE = 128
const StreamProfile = preload("res://scripts/streaming_profile.gd")
static var _maps: Dictionary = {}
static var _normals: Dictionary = {}
static var _roughness_maps: Dictionary = {}
static var _surfaces: Dictionary = {}
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
	_surfaces[key] = material
	return material

static func _noise(x: int, y: int) -> float:
	# Tile seamlessly at SIZE in both directions. All callers are deterministic.
	var xx := posmod(x, SIZE)
	var yy := posmod(y, SIZE)
	var hash_value := (xx * 47 + yy * 83 + xx * yy * 11 + 2017) % 97
	return float(hash_value) / 96.0

static func _height_at(kind: String, x: int, y: int) -> float:
	var xx := posmod(x, SIZE)
	var yy := posmod(y, SIZE)
	var fleck := _noise(xx, yy)
	match kind:
		"BRICK":
			var course := int(yy / 16)
			var shift := 16 if course % 2 == 0 else 0
			if yy % 16 < 2 or (xx + shift) % 32 < 2:
				return 0.16 + fleck * 0.025
			return 0.68 + fleck * 0.10
		"CONCRETE":
			var joint := xx % 64 < 2 or yy % 64 < 2
			return 0.39 if joint else 0.68 + fleck * 0.08
		"ASPHALT":
			return 0.42 + fleck * 0.22
		"PAVERS":
			if xx % 32 < 2 or yy % 32 < 2:
				return 0.25 + fleck * 0.03
			return 0.72 + fleck * 0.07
		"METAL":
			return 0.33 if yy % 32 < 2 else 0.70 + fleck * 0.04
		"GLASS":
			return 0.56 if xx % 32 < 2 else 0.74 + fleck * 0.007
		"WET":
			# Shallow micro-ripples, not a noisy mirror.
			return 0.55 + sin(float(xx) * TAU / 32.0) * 0.015 + fleck * 0.022
	return 0.65 + fleck * 0.08

static func _roughness_at(kind: String, x: int, y: int) -> float:
	var variation := (_noise(x + 17, y - 29) - 0.5) * 0.12
	match kind:
		"BRICK":
			return clampf(0.87 + variation, 0.1, 1.0)
		"ASPHALT":
			return clampf(0.82 + variation, 0.1, 1.0)
		"CONCRETE":
			return clampf(0.91 + variation * 0.55, 0.1, 1.0)
		"PAVERS":
			return clampf(0.81 + variation, 0.1, 1.0)
		"METAL":
			return clampf(0.43 + variation * 1.2, 0.1, 1.0)
		"GLASS":
			return clampf(0.17 + variation * 0.25, 0.1, 1.0)
		"WET":
			return clampf(0.18 + variation * 0.45, 0.1, 1.0)
	return clampf(0.8 + variation, 0.1, 1.0)

static func _ensure_maps(kind: String) -> void:
	if _maps.has(kind):
		return
	var started := StreamProfile.begin()
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rough := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var height := _height_at(kind, x, y)
			var value := 0.68 + (height - 0.5) * 0.24
			match kind:
				"BRICK":
					value = 0.29 if height < 0.3 else 0.69 + (height - 0.7) * 0.45
				"CONCRETE":
					value = 0.48 if height < 0.4 else 0.77 + (height - 0.7) * 0.20
				"ASPHALT":
					value = 0.54 + (height - 0.5) * 0.72
				"PAVERS":
					value = 0.44 if height < 0.3 else 0.80 + (height - 0.7) * 0.24
				"METAL":
					value = 0.41 if height < 0.4 else 0.76 + (height - 0.7) * 0.15
				"GLASS":
					value = 0.72 if height < 0.6 else 0.94
				"WET":
					value = 0.82 + (height - 0.56) * 0.20
			value = clampf(value, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(value, value, value, 1.0))
			var dx := _height_at(kind, x - 1, y) - _height_at(kind, x + 1, y)
			var dy := _height_at(kind, x, y - 1) - _height_at(kind, x, y + 1)
			var bump := Vector3(dx * 0.85, dy * 0.85, 1.0).normalized()
			normal.set_pixel(x, y, Color(bump.x * 0.5 + 0.5, bump.y * 0.5 + 0.5, bump.z * 0.5 + 0.5, 1.0))
			var r := _roughness_at(kind, x, y)
			rough.set_pixel(x, y, Color(r, r, r, 1.0))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	rough.generate_mipmaps()
	StreamProfile.end(started, "material_image_bake", kind)
	started = StreamProfile.begin()
	_maps[kind] = ImageTexture.create_from_image(albedo)
	_normals[kind] = ImageTexture.create_from_image(normal)
	_roughness_maps[kind] = ImageTexture.create_from_image(rough)
	StreamProfile.end(started, "texture_submission", kind)

static func material_count() -> int:
	return _surfaces.size()

static func texture_count() -> int:
	return _maps.size()

static func normal_count() -> int:
	return _normals.size()

static func roughness_count() -> int:
	return _roughness_maps.size()
