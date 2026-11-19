extends Node3D
## Seeded city dressing. Static shell collisions + batched decorative geometry.
## The four neighborhoods deliberately share road geometry but not street character.

const CELL = 58.0
const GRID_RADIUS = 3
const SEED = 834726
const DISTRICTS = ["VESPER MARKET", "GLASSLINE", "BRICKWATER", "AFTERHOURS"]
const SHOPS = {
	"VESPER MARKET": ["MOON NOODLES", "VESPER MART", "SILK ROAD", "PAPER TIGER", "NOVA DELI", "INK & TONIC"],
	"GLASSLINE": ["HELIX DATA", "ASTER FINANCE", "NEON EXCHANGE", "VECTOR SYSTEMS", "MONO TOWER"],
	"BRICKWATER": ["RUSTWORKS", "LOADING BAY", "DOCK 9", "HARBOR RADIO", "BOLT SUPPLY", "LAST SHIFT"],
	"AFTERHOURS": ["BLUE HOUR", "SABLE CLUB", "24H ARCADE", "STATIC ROOM", "GHOST FM", "VOLT RAMEN"]
}
const ACCENT = {
	"VESPER MARKET": Color("ffc46b"),
	"GLASSLINE": Color("61cbff"),
	"BRICKWATER": Color("f68b59"),
	"AFTERHOURS": Color("ef68ce")
}
const BRICK = Color("713e48")
const METAL = Color("38465a")
const CONCRETE = Color("505865")
const ROAD_PAINT = Color("b9b8aa")
const DARK_GLASS = Color("1d3449")

var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _palette: Dictionary = {}
var _statistics := {"buildings": 0, "storefronts": 0, "street_props": 0, "batched_details": 0, "districts": 4}
var _initialized := false

func _ready() -> void:
	# Called from world.gd after attaching this node; never regenerate on reload.
	pass

func generate() -> void:
	if _initialized:
		return
	_initialized = true
	_rng.seed = SEED
	_build_road_language()
	for block_x in range(-GRID_RADIUS, GRID_RADIUS):
		for block_z in range(-GRID_RADIUS, GRID_RADIUS):
			_build_block(block_x, block_z)
	_build_intersections()
	_build_far_skyline()
	_flush_instances()

func get_city_stats() -> Dictionary:
	return _statistics.duplicate()

func get_district_at(position: Vector3) -> String:
	if position.x < 0.0:
		return "VESPER MARKET" if position.z < 0.0 else "BRICKWATER"
	return "GLASSLINE" if position.z < 0.0 else "AFTERHOURS"

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key := color.to_html(false) + ("_glow" if emissive else "_matte")
	if _palette.has(key):
		return _palette[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.13
	material.roughness = 0.74
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.65
	_palette[key] = material
	return material

func _detail(at: Vector3, size: Vector3, color: Color, glow: bool = false) -> void:
	# MultiMesh keeps tens of thousands of architectural parts to a few draw calls.
	var key := color.to_html(false) + ("_glow" if glow else "_matte")
	if not _batches.has(key):
		_batches[key] = []
		_material(color, glow)
	var transforms: Array = _batches[key]
	transforms.append(Transform3D(Basis().scaled(size), at))
	_statistics["batched_details"] += 1

func _solid(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	add_child(body)

func _flush_instances() -> void:
	var unit_mesh := BoxMesh.new()
	unit_mesh.size = Vector3.ONE
	for key in _batches:
		var transforms: Array = _batches[key]
		if transforms.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = unit_mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
		var node := MultiMeshInstance3D.new()
		node.name = "Detail_%s" % key
		node.multimesh = multimesh
		node.material_override = _palette[key]
		add_child(node)
	_batches.clear()

func _build_road_language() -> void:
	for road_index in range(-GRID_RADIUS, GRID_RADIUS + 1):
		var axis := float(road_index) * CELL
		# Dash lines only between intersections, with narrow shoulder paint.
		for segment in range(-GRID_RADIUS, GRID_RADIUS):
			var middle := (float(segment) + 0.5) * CELL
			for lane_mark in range(-3, 4):
				var along := middle + float(lane_mark) * 6.2
				_detail(Vector3(axis, 0.018, along), Vector3(0.16, 0.026, 2.3), ROAD_PAINT)
				_detail(Vector3(along, 0.018, axis), Vector3(2.3, 0.026, 0.16), ROAD_PAINT)
			# Cracked asphalt repairs, not an identical repeating texture.
			if _rng.randf() > 0.30:
				var patch := middle + _rng.randf_range(-14.0, 14.0)
				_detail(Vector3(axis + 3.4, 0.011, patch), Vector3(1.6, 0.015, 3.8), Color("2d313b"))
		# Solid edge markings give the player a reliable read on lanes.
		for side in [-1.0, 1.0]:
			_detail(Vector3(axis + side * 6.65, 0.016, 0.0), Vector3(0.10, 0.025, 405.0), Color("707b88"))
			_detail(Vector3(0.0, 0.016, axis + side * 6.65), Vector3(405.0, 0.025, 0.10), Color("707b88"))

func _build_intersections() -> void:
	for ix in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for iz in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var x := float(ix) * CELL
			var z := float(iz) * CELL
			# Four clear zebra crossings and stop bars per intersection.
			for stripe in range(-4, 5):
				var offset := float(stripe) * 1.30
				for side in [-1.0, 1.0]:
					_detail(Vector3(x + offset, 0.030, z + side * 10.3), Vector3(0.80, 0.026, 3.15), ROAD_PAINT)
					_detail(Vector3(x + side * 10.3, 0.030, z + offset), Vector3(3.15, 0.026, 0.80), ROAD_PAINT)
			for side in [-1.0, 1.0]:
				_detail(Vector3(x, 0.028, z + side * 13.0), Vector3(12.5, 0.025, 0.23), Color("e9dfd2"))
				_detail(Vector3(x + side * 13.0, 0.028, z), Vector3(0.23, 0.025, 12.5), Color("e9dfd2"))
			# Signal units sit beyond the asphalt, on the sidewalk corner.
			_signal(Vector3(x + 8.9, 0.0, z + 8.9), ix + iz)
			if (ix + iz) % 2 == 0:
				_lamp(Vector3(x - 8.4, 0.0, z - 8.6))
			if ix % 2 == 0 and iz % 2 == 0:
				_hydrant(Vector3(x + 9.3, 0.0, z - 9.2))

func _build_block(ix: int, iz: int) -> void:
	var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
	var district := get_district_at(center)
	var accent: Color = ACCENT[district]
	# Sidewalk slabs, tactile strips, curbs and grates around the perimeter.
	for side in [-1.0, 1.0]:
		_detail(center + Vector3(side * 20.8, 0.18, 0.0), Vector3(0.48, 0.24, 42.0), Color("85888b"))
		_detail(center + Vector3(0.0, 0.18, side * 20.8), Vector3(42.0, 0.24, 0.48), Color("85888b"))
		for slab in range(-4, 5):
			var offset := float(slab) * 4.2
			_detail(center + Vector3(side * 19.3, 0.151, offset), Vector3(0.065, 0.018, 3.3), Color("747c81"))
			_detail(center + Vector3(offset, 0.151, side * 19.3), Vector3(3.3, 0.018, 0.065), Color("747c81"))
	for building in range(2):
		var x := center.x + (-10.5 if building == 0 else 10.5)
		var depth := _rng.randf_range(19.0, 25.5)
		var width := _rng.randf_range(14.0, 17.5)
		var z := center.z + _rng.randf_range(-2.9, 0.7)
		_build_building(Vector3(x, 0.0, z), width, depth, district, ix, iz, building)
	# The gap between the two buildings reads as a service alley.
	_detail(center + Vector3(0.0, 0.155, 3.0), Vector3(3.8, 0.035, 25.0), Color("353e48"))
	for mark in range(4):
		_detail(center + Vector3(0.0, 0.175, -6.0 + float(mark) * 6.0), Vector3(3.4, 0.02, 0.10), Color("62686e"))
	_dumpster(center + Vector3(0.0, 0.3, 10.0))
	_furniture(center, district)
	_statistics["street_props"] += 1

func _build_building(center: Vector3, width: float, depth: float, district: String, ix: int, iz: int, which: int) -> void:
	var height := 15.0
	var wall := Color("4b5262")
	match district:
		"VESPER MARKET":
			height = _rng.randf_range(13.0, 26.0)
			wall = Color("61556d") if which == 0 else Color("706354")
		"GLASSLINE":
			height = _rng.randf_range(33.0, 72.0)
			wall = Color("283d50") if which == 0 else Color("32495d")
		"BRICKWATER":
			height = _rng.randf_range(12.0, 31.0)
			wall = BRICK if which == 0 else Color("656059")
		"AFTERHOURS":
			height = _rng.randf_range(20.0, 48.0)
			wall = Color("333450") if which == 0 else Color("53445a")
	var front := center.z - depth / 2.0
	var back := center.z + depth / 2.0
	var left := center.x - width / 2.0
	var right := center.x + width / 2.0
	_solid(Vector3(center.x, height / 2.0 + 0.15, center.z), Vector3(width, height, depth), wall)
	_statistics["buildings"] += 1

	# Foundation plinth, cast shadow line, parapet, mechanical penthouse.
	_detail(Vector3(center.x, 0.47, front - 0.15), Vector3(width + 0.20, 0.80, 0.22), Color("313743"))
	_detail(Vector3(center.x, height + 0.30, center.z), Vector3(width + 0.72, 0.54, depth + 0.72), Color("1b2634"))
	_detail(Vector3(center.x, height + 1.26, center.z + 1.4), Vector3(width * 0.34, 1.65, depth * 0.31), Color("36404b"))
	for vent in range(3):
		var vx := center.x + (float(vent) - 1.0) * width * 0.25
		_detail(Vector3(vx, height + 2.35, center.z + depth * 0.17), Vector3(1.35, 0.65, 1.1), METAL)
		_detail(Vector3(vx, height + 2.72, center.z + depth * 0.17), Vector3(1.52, 0.10, 1.25), Color("9cabb2"))
	if district == "BRICKWATER":
		# Rooftop water tank and a vertical fire escape.
		_detail(Vector3(center.x + 3.8, height + 3.2, center.z), Vector3(3.6, 4.4, 3.6), Color("4f6570"))
		_detail(Vector3(center.x + 3.8, height + 5.5, center.z), Vector3(4.0, 0.22, 4.0), Color("a0a2a0"))
		for floor_step in range(2, int(height / 3.4)):
			var step_y := float(floor_step) * 3.4
			_detail(Vector3(right + 0.28, step_y, center.z + 0.5), Vector3(0.65, 0.17, 5.4), Color("65757c"))
			_detail(Vector3(right + 0.54, step_y + 0.9, center.z + 0.5), Vector3(0.09, 1.70, 5.3), Color("819198"))
	if district == "GLASSLINE":
		# Facade fins, lit corner spines and tall skyline silhouettes.
		for edge in [left + 0.40, right - 0.40]:
			_detail(Vector3(edge, height * 0.52, front - 0.12), Vector3(0.20, height * 0.90, 0.18), Color("68badd"), true)
		_detail(Vector3(center.x, height + 3.1, center.z), Vector3(0.23, 4.0, 0.23), Color("dce7fa"))
	if district == "AFTERHOURS":
		for band in range(1, int(height / 7.0)):
			var y := float(band) * 7.0
			_detail(Vector3(center.x, y, front - 0.17), Vector3(width * 0.97, 0.12, 0.19), ACCENT[district], true)
	# Carefully varied windows. Lit and dark windows avoid checkerboard monotony.
	for floor_index in range(2, int(height / 3.3)):
		var fy := float(floor_index) * 3.3 + 0.10
		for window_index in range(4):
			var wx := center.x + (float(window_index) - 1.5) * width * 0.205
			var lit := _rng.randf() > (0.52 if district == "BRICKWATER" else 0.30)
			var glass := Color("b7d7cf") if lit else DARK_GLASS
			_detail(Vector3(wx, fy, front - 0.095), Vector3(width * 0.135, 1.48, 0.09), glass, lit and _rng.randf() > 0.72)
			_detail(Vector3(wx, fy, back + 0.095), Vector3(width * 0.135, 1.48, 0.09), glass)
			_detail(Vector3(wx, fy - 0.81, front - 0.12), Vector3(width * 0.145, 0.12, 0.13), Color("101e2b"))
		# Floor banding gives each building a perceived internal structure.
		_detail(Vector3(center.x, fy - 1.55, front - 0.055), Vector3(width, 0.11, 0.13), Color("252d3d"))
		for side in [-1.0, 1.0]:
			for side_window in range(2):
				var wz := center.z + (float(side_window) - 0.5) * depth * 0.38
				_detail(Vector3(center.x + side * (width / 2.0 + 0.07), fy, wz), Vector3(0.11, 1.45, 2.0), Color("426178"))

	# Street-level retail facade. Entry is visual-only until interiors exist.
	var sign_color: Color = ACCENT[district]
	_detail(Vector3(center.x, 2.0, front - 0.12), Vector3(width * 0.84, 2.75, 0.14), Color("182637"))
	_detail(Vector3(center.x, 2.0, front - 0.22), Vector3(2.10, 2.55, 0.08), Color("647e8d"))
	_detail(Vector3(center.x + 1.0, 2.0, front - 0.24), Vector3(0.07, 2.55, 0.12), Color("121b28"))
	_detail(Vector3(center.x, 4.0, front - 0.24), Vector3(width * 0.86, 0.75, 0.22), Color("1b2636"))
	_detail(Vector3(center.x, 4.45, front - 0.27), Vector3(width * 0.88, 0.12, 0.19), sign_color, true)
	_detail(Vector3(center.x, 3.70, front - 0.27), Vector3(width * 0.88, 0.11, 0.19), sign_color, true)
	var names: Array = SHOPS[district]
	var label_text: String = names[abs(ix * 11 + iz * 17 + which * 3) % names.size()]
	_label(label_text, Vector3(center.x, 4.08, front - 0.42), sign_color, 54)
	_statistics["storefronts"] += 1
	for awning in range(4):
		var awning_x := center.x + (float(awning) - 1.5) * width * 0.19
		var color := sign_color if awning % 2 == 0 else Color("232c3c")
		_detail(Vector3(awning_x, 3.15, front - 1.08), Vector3(width * 0.19, 0.12, 1.75), color)
	# Corner rain pipes and electric conduit remain visible up close.
	_detail(Vector3(left + 0.35, height * 0.48, front - 0.20), Vector3(0.16, height * 0.90, 0.20), Color("87949d"))
	_detail(Vector3(right - 0.35, height * 0.48, front - 0.20), Vector3(0.16, height * 0.90, 0.20), Color("87949d"))
	_detail(Vector3(right - 0.6, 1.25, front - 0.30), Vector3(0.77, 1.05, 0.32), Color("89929d"))

func _label(value: String, at: Vector3, color: Color, point_size: int = 48) -> void:
	var sign := Label3D.new()
	sign.text = value
	sign.font_size = point_size
	sign.pixel_size = 0.011
	sign.modulate = color
	sign.outline_modulate = Color("070e1b")
	sign.outline_size = 8
	sign.position = at
	sign.rotation.y = PI
	sign.double_sided = true
	add_child(sign)

func _furniture(center: Vector3, district: String) -> void:
	var color: Color = ACCENT[district]
	# Furnishing faces the road, stays on the sidewalks, not in traffic lanes.
	for side in [-1.0, 1.0]:
		_tree(center + Vector3(side * 19.8, 0.0, 12.5))
		_bin(center + Vector3(side * 19.5, 0.0, -12.8))
		_detail(center + Vector3(side * 19.8, 0.17, -3.5), Vector3(0.54, 0.035, 1.22), Color("232d39"))
	if district == "VESPER MARKET":
		_vendor(center + Vector3(-5.0, 0.0, -18.6), color)
		_vendor(center + Vector3(5.0, 0.0, -18.6), Color("e48f8a"))
	elif district == "BRICKWATER":
		_crates(center + Vector3(-2.0, 0.0, -18.5))
		_crates(center + Vector3(6.0, 0.0, -18.5))
	elif district == "GLASSLINE":
		_planter(center + Vector3(-4.0, 0.0, -18.4))
		_planter(center + Vector3(4.0, 0.0, -18.4))
	else:
		_vending(center + Vector3(-3.4, 0.0, -18.2), color)
		_bench(center + Vector3(5.4, 0.0, -18.2))
	# Repeated elements in all four districts: alley grime and street repair.
	for patch in range(3):
		var x := center.x + _rng.randf_range(-1.25, 1.25)
		var z := center.z + _rng.randf_range(-9.0, 12.0)
		_detail(Vector3(x, 0.195, z), Vector3(_rng.randf_range(0.7, 2.0), 0.025, _rng.randf_range(0.8, 2.1)), Color("1c2736"))

func _tree(at: Vector3) -> void:
	_detail(at + Vector3.UP * 1.8, Vector3(0.42, 3.50, 0.42), Color("584b43"))
	var canopy := Color("30555a") if at.z < 0.0 else Color("415750")
	_detail(at + Vector3.UP * 4.1, Vector3(2.3, 2.0, 2.3), canopy)
	_detail(at + Vector3.UP * 5.1, Vector3(1.55, 1.1, 1.55), Color("477569"))
	_statistics["street_props"] += 1

func _bin(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.45, Vector3(0.8, 0.9, 0.8), Color("253e48"))
	_detail(at + Vector3.UP * 0.94, Vector3(0.92, 0.10, 0.92), Color("728088"))
	_statistics["street_props"] += 1

func _dumpster(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.6, Vector3(2.35, 1.3, 1.8), Color("28666a"))
	_detail(at + Vector3.UP * 1.32, Vector3(2.48, 0.14, 1.9), Color("1b353d"))
	_detail(at + Vector3(-0.70, 0.5, -0.94), Vector3(0.5, 0.25, 0.1), Color("e7c56e"))

func _vendor(at: Vector3, color: Color) -> void:
	_detail(at + Vector3.UP * 1.0, Vector3(3.1, 0.8, 1.65), Color("48515b"))
	_detail(at + Vector3.UP * 2.7, Vector3(3.7, 0.18, 2.05), color)
	for dx in [-1.6, 1.6]:
		_detail(at + Vector3(dx, 1.65, -0.70), Vector3(0.12, 3.3, 0.12), Color("99a1a5"))
	for item in range(5):
		_detail(at + Vector3((float(item) - 2.0) * 0.46, 1.51, -0.52), Vector3(0.35, 0.24, 0.38), Color("e5ba74"))
	_statistics["street_props"] += 1

func _planter(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.42, Vector3(1.9, 0.84, 1.1), Color("7a8a91"))
	for stem in [-0.50, 0.0, 0.50]:
		_detail(at + Vector3(stem, 1.23, 0.0), Vector3(0.50, 1.10, 0.62), Color("42816e"))
	_statistics["street_props"] += 1

func _crates(at: Vector3) -> void:
	for index in range(3):
		var ix := float(index % 2)
		var iy := float(index / 2)
		_detail(at + Vector3(ix * 1.2, 0.52 + iy * 1.02, 0.0), Vector3(1.0, 1.0, 1.0), Color("8e7759"))
		_detail(at + Vector3(ix * 1.2, 0.52 + iy * 1.02, -0.55), Vector3(0.76, 0.13, 0.07), Color("dac4a4"))
	_statistics["street_props"] += 1

func _vending(at: Vector3, accent: Color) -> void:
	_detail(at + Vector3.UP * 1.20, Vector3(1.6, 2.4, 1.0), Color("283543"))
	_detail(at + Vector3(0.0, 1.50, -0.54), Vector3(1.3, 1.35, 0.07), accent, true)
	_detail(at + Vector3(0.45, 0.45, -0.58), Vector3(0.3, 0.3, 0.10), Color("d8e8ea"), true)
	_statistics["street_props"] += 1

func _bench(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.65, Vector3(3.1, 0.17, 0.72), Color("866e5a"))
	_detail(at + Vector3(0.0, 1.15, 0.32), Vector3(3.1, 0.9, 0.16), Color("866e5a"))
	for dx in [-1.25, 1.25]:
		_detail(at + Vector3(dx, 0.32, 0.0), Vector3(0.19, 0.61, 0.7), Color("384953"))
	_statistics["street_props"] += 1

func _signal(at: Vector3, variant: int) -> void:
	_detail(at + Vector3.UP * 3.0, Vector3(0.25, 6.0, 0.25), Color("738395"))
	_detail(at + Vector3(-1.55, 5.95, 0.0), Vector3(3.0, 0.22, 0.23), Color("738395"))
	_detail(at + Vector3(-3.05, 5.4, 0.0), Vector3(0.60, 1.75, 0.68), Color("152435"))
	var green := variant % 2 == 0
	_detail(at + Vector3(-3.05, 5.9, -0.38), Vector3(0.36, 0.36, 0.06), Color("f0445e") if not green else Color("422b40"), not green)
	_detail(at + Vector3(-3.05, 5.4, -0.38), Vector3(0.36, 0.36, 0.06), Color("66573a"))
	_detail(at + Vector3(-3.05, 4.9, -0.38), Vector3(0.36, 0.36, 0.06), Color("48e1bc") if green else Color("25433e"), green)
	_statistics["street_props"] += 1

func _lamp(at: Vector3) -> void:
	_detail(at + Vector3.UP * 3.5, Vector3(0.23, 7.0, 0.23), Color("627480"))
	_detail(at + Vector3(-0.8, 7.0, 0.0), Vector3(1.65, 0.20, 0.20), Color("627480"))
	_detail(at + Vector3(-1.58, 6.76, 0.0), Vector3(0.85, 0.24, 0.60), Color("ffcd8d"), true)
	_statistics["street_props"] += 1

func _hydrant(at: Vector3) -> void:
	_detail(at + Vector3.UP * 0.48, Vector3(0.52, 0.95, 0.55), Color("ce5b60"))
	_detail(at + Vector3.UP * 0.98, Vector3(0.66, 0.18, 0.66), Color("dfab79"))
	_detail(at + Vector3.UP * 0.52, Vector3(0.92, 0.19, 0.25), Color("dca077"))
	_statistics["street_props"] += 1

func _build_far_skyline() -> void:
	# Cheap silhouette rings mask the hard play-area edge without more collision.
	for index in range(64):
		var angle := TAU * float(index) / 64.0
		var radius := _rng.randf_range(239.0, 279.0)
		var height := _rng.randf_range(18.0, 85.0)
		var at := Vector3(cos(angle) * radius, height / 2.0, sin(angle) * radius)
		_detail(at, Vector3(_rng.randf_range(12.0, 23.0), height, _rng.randf_range(12.0, 23.0)), Color("172434"))
		if index % 3 == 0:
			_detail(at + Vector3(0.0, height / 2.0 + 0.25, 0.0), Vector3(13.0, 0.16, 12.0), Color("447d90"), true)
