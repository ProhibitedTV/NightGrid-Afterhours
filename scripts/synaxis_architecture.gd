extends RefCounted
## Gen 2 finish assemblies use the existing wall face as their mounting datum.
const Breakroom = preload("res://scripts/synaxis_breakroom.gd")
const TYPE = preload("res://assets/art/synaxis/DejaVuSansCondensed-Bold.ttf")
const STONE = preload("res://assets/models/nightgrid/synaxis_architecture/stone_panel.glb")
const WALNUT = preload("res://assets/models/nightgrid/synaxis_architecture/walnut_panel.glb")
const FABRIC = preload("res://assets/models/nightgrid/synaxis_architecture/fabric_panel.glb")
const PLAQUE = preload("res://assets/models/nightgrid/synaxis_architecture/plaque.glb")
const NOTICE = preload("res://assets/models/nightgrid/synaxis_architecture/notice.glb")
const RECEPTION = preload("res://assets/models/nightgrid/synaxis_architecture/reception_brand.glb")
const MAPS = "res://assets/pbr/synaxis_architecture/"
const STONE_MAPS = [preload(MAPS+"marble_01_diff_1k.jpg"), preload(MAPS+"marble_01_nor_gl_1k.jpg"), preload(MAPS+"marble_01_arm_1k.jpg")]
const FABRIC_MAPS = [preload(MAPS+"poly_wool_herringbone_diff_1k.jpg"), preload(MAPS+"poly_wool_herringbone_nor_gl_1k.jpg"), preload(MAPS+"poly_wool_herringbone_arm_1k.jpg")]
const PLASTER_MAPS = [preload(MAPS+"wall_paint_diff_1k.jpg"), preload(MAPS+"white_plaster_02_nor_gl_1k.jpg"), preload(MAPS+"white_plaster_02_arm_1k.jpg")]

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

static func surface(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D
	match key:
		"Walnut":
			material = Breakroom.material_for("Walnut")
		"Stone":
			material = _photo(STONE_MAPS, Color("b8c2c5"), 0.12)
		"Fabric":
			material = _photo(FABRIC_MAPS, Color("8c9597"), 0.24)
		"Drywall":
			material = _photo(PLASTER_MAPS, Color("dedfdb"), 0.10)
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
		"Concrete", "Tile", "LiftSteel":
			var source: String = {"Concrete":"Counter", "Tile":"Tile", "LiftSteel":"Steel"}[key]
			material = Breakroom.material_for(source).duplicate()
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
			material.normal_scale *= .65
			if key == "LiftSteel":
				material.metallic = .47
				material.roughness = .74
		"Opal":
			material = StandardMaterial3D.new()
			material.albedo_color = Color("9debd6")
			material.emission_enabled = true
			material.emission = Color("a4f3e2")
			material.emission_energy_multiplier = .82
		"CabinMetal":
			material = Breakroom.material_for("Steel").duplicate()
			material.albedo_texture = preload(MAPS+"cabin_satin_metal_1k.jpg")
			material.albedo_color = Color("d3d8d9")
			material.metallic = .42
			material.normal_scale = .16
		"CabinDiffuser":
			material = Breakroom.material_for("Diffuser")
		"PartitionGlass", "EtchedBand":
			material = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(.57,.70,.72,.21) if key == "PartitionGlass" else Color(.77,.83,.81,.75)
			material.roughness = .18 if key == "PartitionGlass" else .71
		"Letter":
			material = StandardMaterial3D.new()
			material.albedo_color = Color("eef0dc")
			material.roughness = .28
			material.metallic = .32
	_materials[key] = material
	return material

static func _photo(maps: Array, tint: Color, normal_strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = maps[0]
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = maps[1]
	material.normal_scale = normal_strength
	material.roughness_texture = maps[2]
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func _parts(prototype: PackedScene) -> Dictionary:
	if not _meshes.has(prototype):
		var node := prototype.instantiate()
		var parts := {}
		for child: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			parts[child.name] = child.mesh
		node.free()
		_meshes[prototype] = parts
	return _meshes[prototype]

static func _finish(instance: MeshInstance3D, mesh: Mesh) -> void:
	for slot in mesh.get_surface_count():
		var authored := mesh.surface_get_material(slot)
		var replacement := surface(authored.resource_name) if authored != null else null
		if replacement != null:
			instance.set_surface_override_material(slot, replacement)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func strip(parent: Node3D, id: String, at: Vector3, yaw: float, width: float, panel: PackedScene) -> void:
	var root := Node3D.new()
	root.name = id
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var count := maxi(1, roundi(width / 1.18))
	var pitch := width / count
	for key in _parts(panel):
		var mesh: Mesh = _parts(panel)[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = count
		for i in count:
			var basis := Basis.from_scale(Vector3(pitch / 1.18, 1, 1))
			batch.set_instance_transform(i, Transform3D(basis, Vector3((i + .5) * pitch - width * .5, 0, 0)))
		var view := MultiMeshInstance3D.new()
		view.name = key
		view.multimesh = batch
		# MultiMeshes use the shared surface materials on their prototype mesh.
		if key == &"Face":
			view.material_override = surface(mesh.surface_get_material(0).resource_name)
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(view)

static func nameplate(parent: Node3D, id: String, words: String, at: Vector3, yaw: float, size: Vector2, ink := Color("e2eee9")) -> Node3D:
	var root := assembly(parent, id, PLAQUE, at, yaw, Vector3(size.x / 1.7, size.y / .30, 1))
	inscription(root, words, Vector3(0, 0, .028), size * Vector2(.84, .73), ink)
	return root

static func notice_frame(parent: Node3D, dimensions: Vector2) -> void:
	assembly(parent, "Frame", NOTICE, Vector3.ZERO, 0.0, Vector3(dimensions.x / 2.36, dimensions.y / 1.44, 1))

static func brand_wall(parent: Node3D, id: String, at: Vector3, scale_factor: float = 1.0) -> void:
	var root := assembly(parent, id, RECEPTION, at, PI, Vector3.ONE)
	root.scale = Vector3.ONE * scale_factor
	inscription(root, "O M N I S Y S T E M S", Vector3(.08, .045, .130), Vector2(2.09, .103))

static func assembly(parent: Node3D, id: String, packed: PackedScene, at: Vector3, yaw: float = 0.0, size: Vector3 = Vector3.ONE) -> Node3D:
	var root := Node3D.new()
	root.name = id
	root.position = at
	root.rotation.y = yaw
	for key in _parts(packed):
		var view := MeshInstance3D.new()
		view.name = key
		view.mesh = _parts(packed)[key]
		view.scale = size
		_finish(view, view.mesh)
		root.add_child(view)
	parent.add_child(root, true)
	return root

static func inscription(parent: Node3D, words: String, at: Vector3, area: Vector2, ink := Color("e2eee9")) -> Label3D:
	var label := Label3D.new()
	label.name = "Inscription"
	label.text = words
	label.font = TYPE
	label.font_size = 64
	label.outline_size = 0
	label.modulate = ink
	label.position = at
	var longest := 1.0
	var lines := words.split("\n")
	for line in lines:
		longest = maxf(longest, TYPE.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x)
	label.pixel_size = minf(area.x / longest, area.y / (TYPE.get_height(64) * lines.size()))
	parent.add_child(label)
	return label
