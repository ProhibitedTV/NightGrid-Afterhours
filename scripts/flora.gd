extends Node3D
## Morrow Bay's planted city: low-poly graphic botanical silhouettes.
## Street trees, protected plazas and courtyards are authored placements; only
## species, canopy variation, small shrubs and flower groups are seeded.
const WorldPlan = preload("res://scripts/world_plan.gd")
const SEED = 4201337
const GRID_RADIUS = 3
const CELL = 58.0
const PINE = "PINE"
const GINKGO = "GINKGO"
const PLUM = "PLUM"
const FICUS = "FICUS"

var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _stats := {"street_trees": 0, "landmark_trees": 0, "shrubs": 0, "flowers": 0, "planter_pots": 0, "vegetation_instances": 0}
var _initialized := false

func generate() -> void:
	if _initialized:
		return
	_initialized = true
	_rng.seed = SEED
	_prepare_resources()
	for ix in range(-GRID_RADIUS, GRID_RADIUS):
		for iz in range(-GRID_RADIUS, GRID_RADIUS):
			var center := Vector3((float(ix) + 0.5) * CELL, 0.0, (float(iz) + 0.5) * CELL)
			var district: String = WorldPlan.district_at(center)
			# Road-facing curbs with deliberate free space for driving and missions.
			for side in [-1.0, 1.0]:
				var tree_point := center + Vector3(side * 19.65, 0.15, 12.50)
				_tree(tree_point, _street_species(district), 0.76 + _rng.randf_range(0.0, 0.27), true)
			if district == "GLASSLINE":
				_potted_group(center + Vector3(-14.1, 0.17, -18.5), "AQUA")
				_potted_group(center + Vector3(14.1, 0.17, -18.5), "AQUA")
			elif district == "BRICKWATER":
				_wildflower_patch(center + Vector3(-17.5, 0.15, -14.6), 5)
				_wildflower_patch(center + Vector3(17.5, 0.15, -14.6), 5)
			elif district == "AFTERHOURS":
				_potted_group(center + Vector3(-14.3, 0.15, -18.4), "PURPLE")
			else:
				_potted_group(center + Vector3(14.3, 0.15, -18.4), "GOLD")
			var landmark: String = WorldPlan.landmark_for_block(ix, iz)
			if not landmark.is_empty():
				_landmark_garden(center, landmark)
	_flush()

func get_stats() -> Dictionary:
	return _stats.duplicate()

func _street_species(district: String) -> String:
	match district:
		"VESPER MARKET":
			return GINKGO
		"GLASSLINE":
			return FICUS
		"BRICKWATER":
			return PINE
		_:
			return PLUM

func _prepare_resources() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.48
	trunk.height = 1.0
	trunk.radial_segments = 6
	_meshes["TRUNK"] = trunk
	var canopy := SphereMesh.new()
	canopy.radius = 0.5
	canopy.height = 1.0
	canopy.radial_segments = 8
	canopy.rings = 4
	_meshes["CANOPY"] = canopy
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 8
	_meshes["CONE"] = cone
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_meshes["BOX"] = box
	var colors := {
		"BARK": Color("443f4b"),
		"GINKGO_1": Color("dfb66d"),
		"GINKGO_2": Color("eecc86"),
		"FICUS_1": Color("447e75"),
		"FICUS_2": Color("76b29a"),
		"PLUM_1": Color("a95c8b"),
		"PLUM_2": Color("df8cad"),
		"PINE_1": Color("2e525c"),
		"PINE_2": Color("497a72"),
		"SHRUB": Color("417268"),
		"SHRUB_LIGHT": Color("65a38b"),
		"FLOWER_GOLD": Color("ebbf6d"),
		"FLOWER_PINK": Color("e28ca8"),
		"FLOWER_CYAN": Color("65b7bc"),
		"POT": Color("303c4d"),
		"SOIL": Color("403b39"),
		"GRATE": Color("6c7d7c")
	}
	for name in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[name]
		material.roughness = 0.9
		_materials[name] = material

func _push(mesh_kind: String, tint: String, at: Vector3, scale: Vector3, yaw: float = 0.0) -> void:
	var key := mesh_kind + ":" + tint
	if not _batches.has(key):
		_batches[key] = []
	var poses: Array = _batches[key]
	poses.append(Transform3D(Basis(Vector3.UP, yaw).scaled(scale), at))
	_stats["vegetation_instances"] += 1

func _flush() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split(":")
		var poses: Array = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _meshes[parts[0]]
		multimesh.instance_count = poses.size()
		for i in range(poses.size()):
			multimesh.set_instance_transform(i, poses[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Flora_%s" % key
		node.multimesh = multimesh
		node.material_override = _materials[parts[1]]
		add_child(node)
	_batches.clear()

func _trunk_collision(at: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = at + Vector3.UP * (height * 0.5)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.30
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _tree(at: Vector3, species: String, size_factor: float, street: bool = false) -> void:
	var trunk_height := 3.2 * size_factor
	_push("TRUNK", "BARK", at + Vector3.UP * trunk_height * 0.5, Vector3(size_factor, trunk_height, size_factor))
	if street:
		_trunk_collision(at, trunk_height)
		_push("BOX", "GRATE", at + Vector3.UP * 0.06, Vector3(2.0, 0.12, 2.0))
		_push("BOX", "SOIL", at + Vector3.UP * 0.13, Vector3(1.35, 0.04, 1.35))
		_stats["street_trees"] += 1
	else:
		_stats["landmark_trees"] += 1
	if species == PINE:
		for level in range(3):
			var width := (3.8 - float(level) * 0.74) * size_factor
			var height := (2.4 + float(level) * 0.25) * size_factor
			_push("CONE", "PINE_1" if level % 2 == 0 else "PINE_2",
				at + Vector3.UP * (trunk_height + float(level) * 1.0 * size_factor),
				Vector3(width, height, width))
	else:
		var palette := species + "_"
		var canopy_y := trunk_height + 0.8 * size_factor
		_push("CANOPY", palette + "1", at + Vector3.UP * canopy_y,
			Vector3(3.7, 2.9, 3.5) * size_factor, _rng.randf_range(-0.4, 0.4))
		_push("CANOPY", palette + "2", at + Vector3(-0.8, canopy_y + 0.6, 0.4) * size_factor,
			Vector3(2.45, 2.0, 2.55) * size_factor, 0.4)
		_push("CANOPY", palette + "1", at + Vector3(0.7, canopy_y + 0.3, -0.6) * size_factor,
			Vector3(2.5, 2.2, 2.4) * size_factor, -0.35)

func _shrub(at: Vector3, size_factor: float = 1.0) -> void:
	var spread := 1.0 * size_factor
	_push("CANOPY", "SHRUB", at + Vector3.UP * (spread * 0.56),
		Vector3(spread * 1.5, spread, spread * 1.2), _rng.randf_range(-0.3, 0.3))
	_push("CANOPY", "SHRUB_LIGHT", at + Vector3(0.32, spread * 0.7, -0.2),
		Vector3(spread * 0.95, spread * 0.75, spread * 0.94))
	_stats["shrubs"] += 1

func _potted_group(at: Vector3, palette: String) -> void:
	for index in range(3):
		var p := at + Vector3((float(index) - 1.0) * 2.0, 0.0, _rng.randf_range(-0.35, 0.35))
		_push("BOX", "POT", p + Vector3.UP * 0.36, Vector3(1.18, 0.72, 1.18))
		_push("BOX", "SOIL", p + Vector3.UP * 0.74, Vector3(1.1, 0.06, 1.1))
		_shrub(p + Vector3.UP * 0.80, 0.64)
		_stats["planter_pots"] += 1
		if palette != "AQUA":
			_push("CANOPY", "FLOWER_PINK" if palette == "PURPLE" else "FLOWER_GOLD",
				p + Vector3.UP * 1.50, Vector3(0.40, 0.34, 0.40))
			_stats["flowers"] += 1

func _wildflower_patch(center: Vector3, count: int) -> void:
	for i in range(count):
		var point := center + Vector3(_rng.randf_range(-1.3, 1.3), 0.0, _rng.randf_range(-1.2, 1.2))
		_push("CONE", "SHRUB", point + Vector3.UP * 0.30, Vector3(0.2, 0.65, 0.2))
		var flower := "FLOWER_CYAN" if i % 3 == 0 else ("FLOWER_GOLD" if i % 3 == 1 else "FLOWER_PINK")
		_push("CANOPY", flower, point + Vector3.UP * 0.66, Vector3(0.30, 0.30, 0.30))
		_stats["flowers"] += 1

func _landmark_garden(center: Vector3, landmark: String) -> void:
	match landmark:
		"LANTERN COURT":
			for x in [-13.0, 13.0]:
				for z in [-11.0, 11.0]:
					_tree(center + Vector3(x, 0.20, z), GINKGO, 0.87)
			for x in [-7.5, 7.5]:
				_potted_group(center + Vector3(x, 0.20, 3.5), "GOLD")
		"HELIX TERMINAL":
			for x in [-14.0, 14.0]:
				for z in [-13.0, 13.0]:
					_tree(center + Vector3(x, 0.20, z), FICUS, 0.90)
			for x in [-7.5, 7.5]:
				_potted_group(center + Vector3(x, 0.20, 10.0), "AQUA")
		"FOUNDRY COMMONS":
			for x in [-13.0, -5.0, 5.0, 13.0]:
				for z in [-12.0, 12.0]:
					_tree(center + Vector3(x, 0.20, z), PINE if x < 0.0 else GINKGO, 0.80)
			for x in [-14.0, -7.0, 0.0, 7.0, 14.0]:
				_wildflower_patch(center + Vector3(x, 0.20, 3.0), 6)
		"SABLE SQUARE":
			for x in [-14.0, 14.0]:
				for z in [-13.0, 13.0]:
					_tree(center + Vector3(x, 0.20, z), PLUM, 0.92)
			for x in [-10.0, 10.0]:
				_potted_group(center + Vector3(x, 0.20, 8.0), "PURPLE")
