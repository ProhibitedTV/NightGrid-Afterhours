extends SceneTree
## Rebuilds the checked-in lossless RGBA8 city texture data with its original mipmaps.
## Run as a headless SceneTree script. Pass --verify to compare the stored image bytes.
const TARGET = "res://assets/pbr/nightgrid/city_material_maps.res"
const SIZE = 128
const KINDS = ["ASPHALT", "BRICK", "CONCRETE", "GLASS", "METAL", "PAVERS", "WET", "WOOD"]

func _initialize() -> void:
	var maps := Resource.new()
	maps.resource_name = "Procedural city texture images with original mipmaps"
	var images := {}
	for kind in KINDS:
		images[kind] = _bake_images(kind)
	maps.set_meta("images", images)
	if "--verify" in OS.get_cmdline_user_args():
		var saved := load(TARGET) as Resource
		var saved_images: Dictionary = saved.get_meta("images")
		for kind in KINDS:
			for index in range(3):
				if saved_images[kind][index].get_data() != images[kind][index].get_data():
					push_error("Baked city image mismatch: %s / %d" % [kind, index])
					quit(1)
					return
		print("CITY_MATERIAL_MAPS PASS: original RGBA8 bytes and all mipmaps")
		quit(0)
		return
	var result := ResourceSaver.save(maps, TARGET, ResourceSaver.FLAG_COMPRESS)
	quit(0 if result == OK else 1)

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

static func _bake_images(kind: String) -> Array[Image]:
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
	return [albedo, normal, rough]
