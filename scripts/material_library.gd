extends RefCounted
## Tiny authored set of tileable, cached material maps for Morrow Bay.
## Pixels are generated once on CPU; no per-fragment procedural noise shaders.
const SIZE = 128
static var _maps: Dictionary = {}
static var _surfaces: Dictionary = {}

static func surface(kind: String, tint: Color) -> StandardMaterial3D:
	var key := kind + "|" + tint.to_html(false)
	if _surfaces.has(key):
		return _surfaces[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = _texture(kind)
	# Avoid BoxMesh UV stretching on both large walls and thin street surfaces.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.21, 0.21, 0.21)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"BRICK":
			material.roughness = 0.88
		"ASPHALT":
			material.roughness = 0.85
		"CONCRETE":
			material.roughness = 0.91
		"PAVERS":
			material.roughness = 0.81
		"METAL":
			material.metallic = 0.65
			material.roughness = 0.46
		"GLASS":
			material.metallic = 0.36
			material.roughness = 0.17
		"WET":
			material.metallic = 0.20
			material.roughness = 0.17
			material.uv1_scale = Vector3(0.30, 0.30, 0.30)
		_:
			material.roughness = 0.85
	_surfaces[key] = material
	return material

static func _texture(kind: String) -> ImageTexture:
	if _maps.has(kind):
		return _maps[kind]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			# Pixel-stable flecks, no imported art or noisy GPU shader loops.
			var speck := float((x * 47 + y * 83 + x * y * 11 + 2017) % 97) / 96.0
			var value := 0.73 + (speck - 0.5) * 0.18
			match kind:
				"BRICK":
					var course := int(y / 16)
					var shift := 16 if course % 2 == 0 else 0
					if y % 16 < 2 or (x + shift) % 32 < 2:
						value = 0.28
					else:
						value = 0.68 + (speck - 0.5) * 0.19
				"CONCRETE":
					value = 0.75 + (speck - 0.5) * 0.15
					if (x + y * 2) % 67 < 2:
						value *= 0.75
				"ASPHALT":
					value = 0.58 + (speck - 0.5) * 0.26
					if speck > 0.93:
						value = 0.80
				"PAVERS":
					if x % 32 < 2 or y % 32 < 2:
						value = 0.44
					else:
						value = 0.81 + (speck - 0.5) * 0.10
				"METAL":
					value = 0.71 + (speck - 0.5) * 0.10
					if y % 25 == 0:
						value = 0.38
				"GLASS":
					value = 0.92 if x % 32 < 2 else 0.83 + (speck - 0.5) * 0.04
				"WET":
					value = 0.72 + (speck - 0.5) * 0.14
			img.set_pixel(x, y, Color(value, value, value, 1.0))
	img.generate_mipmaps()
	var texture := ImageTexture.create_from_image(img)
	_maps[kind] = texture
	return texture

static func material_count() -> int:
	return _surfaces.size()

static func texture_count() -> int:
	return _maps.size()
