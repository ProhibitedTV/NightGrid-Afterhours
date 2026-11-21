extends Node3D
## WEST DOCKS / Dock Watch neighbor, permanent parcel (-4, -1), lot 1.
##
## An authored contiguous façade/side/roof envelope with true window and
## service-opening depth. An official CC0 Poly Haven glTF supplies the TWO
## individually textured shutter variants; original CityDetails retains the
## entire save-stable box collision envelope. This is a technical art pilot,
## not a certified finished AAA building.
const SHUTTER_SCENE = preload("res://assets/models/polyhaven/rollershutter_window_01/rollershutter_window_01.gltf")
const RoofHVAC = preload("res://scripts/west_docks_hvac_roof_kit.gd")
const PBR_ROOT = "res://assets/pbr/polyhaven/"
const FRONT_DEPTH = 0.0
const LEVEL = 3.5
const GROUND = 4.75

var building_width := 16.1
var building_height := 20.0
var building_depth := 23.0
var _buffers: Dictionary = {}
var _materials: Dictionary = {}
var _stats := {
	"mesh_surfaces": 0, "openings": 0, "service_bays": 0,
	"shutter_variants": 0, "source_meshes": 0, "cc0_photo_maps": 0,
	"reveal_faces": 0, "collision_bodies": 0, "additional_lights": 0,
	"rooftop_hvac_units": 0, "rooftop_hvac_photo_surfaces": 0,
	"original_mount_profiles": 0
}

func configure(width: float, height: float, depth: float) -> void:
	building_width = width
	building_height = height
	building_depth = depth

func _ready() -> void:
	_build()

func get_facade_stats() -> Dictionary:
	return _stats.duplicate(true)

func _material(family: String) -> StandardMaterial3D:
	if _materials.has(family):
		return _materials[family]
	var material := StandardMaterial3D.new()
	match family:
		"BRICK":
			_photo(material, "brick_wall_001", Color("a8a0a0"), 0.76)
		"METAL", "REVEAL":
			_photo(material, "blue_metal_plate", Color("929699"), 0.55)
			material.metallic = 0.65 if family == "METAL" else 0.38
		"ROOF":
			_photo(material, "bitumen", Color("999a9a"), 0.67)
		"GLASS":
			material.albedo_color = Color(0.19, 0.31, 0.39, 0.82)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.03
			material.roughness = 0.14
		"INTERIOR":
			material.albedo_color = Color("34383c")
			material.roughness = 0.89
		_:
			push_error("Unsupported West Docks material " + family)
	_materials[family] = material
	return material

func _photo(material: StandardMaterial3D, source: String,
		tint: Color, normal_strength: float) -> void:
	var base := PBR_ROOT + source + "_"
	var diffuse := load(base + "diffuse_2k.jpg") as Texture2D
	var normal := load(base + "nor_gl_2k.png") as Texture2D
	var rough := load(base + "rough_2k.png") as Texture2D
	assert(diffuse != null and normal != null and rough != null)
	material.albedo_texture = diffuse
	material.normal_texture = normal
	material.normal_enabled = true
	material.normal_scale = normal_strength
	material.roughness_texture = rough
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 1.0
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = false
	material.uv1_world_triplanar = false
	_stats["cc0_photo_maps"] += 3

func _quad(family: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	if not _buffers.has(family):
		_buffers[family] = []
	(_buffers[family] as Array).append([a, b, c, d])

func _front(family: String, x0: float, x1: float,
		y0: float, y1: float, inset: float = 0.0) -> void:
	if x1 <= x0 or y1 <= y0:
		return
	var z := -building_depth * 0.5 + inset
	_quad(family, Vector3(x0, y0, z), Vector3(x0, y1, z),
		Vector3(x1, y1, z), Vector3(x1, y0, z))

func _back(family: String, x0: float, x1: float, y0: float, y1: float) -> void:
	var z := building_depth * 0.5
	_quad(family, Vector3(x1, y0, z), Vector3(x1, y1, z),
		Vector3(x0, y1, z), Vector3(x0, y0, z))

func _side(family: String, positive: bool, z0: float, z1: float,
		y0: float, y1: float, inset: float = 0.0) -> void:
	if z1 <= z0 or y1 <= y0:
		return
	var x := (building_width * 0.5 - inset) * (1.0 if positive else -1.0)
	if positive:
		_quad(family, Vector3(x, y0, z0), Vector3(x, y1, z0),
			Vector3(x, y1, z1), Vector3(x, y0, z1))
	else:
		_quad(family, Vector3(x, y0, z1), Vector3(x, y1, z1),
			Vector3(x, y1, z0), Vector3(x, y0, z0))

func _roof() -> void:
	var half := building_width * 0.5
	var d := building_depth * 0.5
	var h := building_height + 0.12
	_quad("ROOF", Vector3(-half, h, -d), Vector3(-half, h, d),
		Vector3(half, h, d), Vector3(half, h, -d))
	# Structural fascia is part of the closed envelope, not floating strips
	# of decorative block meshes. Preserve the building collision untouched.
	_front("METAL", -half - 0.16, half + 0.16, h - 0.5, h + 0.06, -0.14)
	_back("METAL", -half - 0.16, half + 0.16, h - 0.5, h + 0.06)
	for positive in [false, true]:
		_side("METAL", positive, -d - 0.16, d + 0.16, h - 0.5, h + 0.06, -0.16)

func _recessed_front_window(x0: float, x1: float, bottom: float, top: float) -> void:
	_front("GLASS", x0 + 0.10, x1 - 0.10, bottom + 0.09, top - 0.09, 0.19)
	_front("INTERIOR", x0 + 0.10, x1 - 0.10, bottom + 0.09, top - 0.09, 0.83)
	var plane := -building_depth * 0.5
	var deep := plane + 0.19
	for x in [x0, x1]:
		_quad("REVEAL", Vector3(x, bottom, plane), Vector3(x, top, plane),
			Vector3(x, top, deep), Vector3(x, bottom, deep))
	for y in [bottom, top]:
		_quad("REVEAL", Vector3(x0, y, plane), Vector3(x0, y, deep),
			Vector3(x1, y, deep), Vector3(x1, y, plane))
	_front("METAL", x0 + 0.09, x1 - 0.09,
		lerpf(bottom, top, 0.56) - 0.045, lerpf(bottom, top, 0.56) + 0.045, 0.16)
	_stats["openings"] += 1
	_stats["reveal_faces"] += 4

func _build_front() -> void:
	var half := building_width * 0.5
	_front("BRICK", -half, half, 0.13, 0.53)
	_front("BRICK", -half, half, 3.56, GROUND)
	# Two real shutter models cover *actual open bays*: the architectural
	# mesh is not drawn behind their visible louvers.
	var bays := [-3.50, 3.50]
	var previous := -half
	for center in bays:
		var lo := float(center) - 1.55
		var hi := float(center) + 1.55
		_front("BRICK", previous, lo, 0.53, 3.56)
		_front("METAL", lo - 0.18, lo, 0.53, 3.56, -0.08)
		_front("METAL", hi, hi + 0.18, 0.53, 3.56, -0.08)
		_front("METAL", lo - 0.18, hi + 0.18, 3.45, 3.56, -0.10)
		_front("INTERIOR", lo, hi, 0.53, 3.45, 0.64)
		_stats["service_bays"] += 1
		previous = hi
	_front("BRICK", previous, half, 0.53, 3.56)
	# Vertical shop identity fascia is an architectural metal reveal, not
	# another glowing cuboid with fake painted windows.
	_front("METAL", -half + 0.3, half - 0.3, GROUND - 0.16, GROUND + 0.15, -0.10)
	var level := GROUND
	while level < building_height - 0.50:
		var top := minf(building_height - 0.35, level + LEVEL)
		var bottom := level + 0.50
		var lintel := top - 0.52
		if lintel - bottom < 0.8:
			_front("BRICK", -half, half, level, top)
			break
		_front("BRICK", -half, half, level, bottom)
		_front("BRICK", -half, half, lintel, top)
		var previous_bay := -half
		for i in range(4):
			var x0 := -half + 0.88 + float(i) * (building_width - 1.76) / 4.0
			var x1 := -half + 0.88 + float(i + 1) * (building_width - 1.76) / 4.0 - 0.62
			_front("BRICK", previous_bay, x0, bottom, lintel)
			_recessed_front_window(x0, x1, bottom, lintel)
			previous_bay = x1
		_front("BRICK", previous_bay, half, bottom, lintel)
		level += LEVEL

func _build_sides_and_back() -> void:
	var d := building_depth * 0.5
	var half := building_width * 0.5
	_back("METAL", -half, half, 0.13, building_height)
	for positive in [false, true]:
		_side("METAL", positive, -d, d, 0.13, GROUND)
		var level := GROUND
		while level < building_height - 0.50:
			var top := minf(building_height, level + LEVEL)
			var bottom := level + 0.52
			var lintel := top - 0.55
			if lintel <= bottom + 0.5:
				_side("METAL", positive, -d, d, level, top)
				break
			_side("METAL", positive, -d, d, level, bottom)
			_side("METAL", positive, -d, d, lintel, top)
			var previous := -d
			for i in range(3):
				var z0 := -d + 1.40 + float(i) * (building_depth - 2.8) / 3.0
				var z1 := -d + 1.40 + float(i + 1) * (building_depth - 2.8) / 3.0 - 1.1
				_side("METAL", positive, previous, z0, bottom, lintel)
				_side("GLASS", positive, z0 + 0.10, z1 - 0.10,
					bottom + 0.10, lintel - 0.10, 0.19)
				_side("INTERIOR", positive, z0 + 0.10, z1 - 0.10,
					bottom + 0.10, lintel - 0.10, 0.9)
				# Thin top/bottom/side reveals point into the recessed side.
				_side("REVEAL", positive, z0, z1, bottom, bottom + 0.10, 0.08)
				_side("REVEAL", positive, z0, z1, lintel - 0.10, lintel, 0.08)
				_stats["openings"] += 1
				previous = z1
			_side("METAL", positive, previous, d, bottom, lintel)
			level += LEVEL

func _assemble_surfaces() -> void:
	for family in _buffers:
		var quads: Array = _buffers[family]
		if quads.is_empty():
			continue
		var mesh_tool := SurfaceTool.new()
		mesh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for quad in quads:
			var a: Vector3 = quad[0]
			var b: Vector3 = quad[1]
			var c: Vector3 = quad[2]
			var d: Vector3 = quad[3]
			var face_normal := (b - a).cross(c - a).normalized()
			for vertex in [a, b, c, a, c, d]:
				# Each physical plane gets independent nondegenerate UV axes;
				# roofs use X/Z, front/back use X/Y, sidewalls use Z/Y.
				var projected := Vector2(vertex.x, vertex.y)
				if absf(face_normal.y) > 0.5:
					projected = Vector2(vertex.x, vertex.z)
				elif absf(face_normal.x) > 0.5:
					projected = Vector2(vertex.z, vertex.y)
				mesh_tool.set_uv(projected * 0.35)
				mesh_tool.add_vertex(vertex)
		mesh_tool.generate_normals()
		mesh_tool.generate_tangents()
		var node := MeshInstance3D.new()
		node.name = "MeasuredArchitecture_%s" % family
		node.mesh = mesh_tool.commit()
		node.material_override = _material(str(family))
		node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if str(family) == "GLASS" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		add_child(node)
		_stats["mesh_surfaces"] += 1
	_buffers.clear()

func _gather_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_meshes(child, result)

func _source_shutter(center_x: float, graffiti: bool) -> void:
	var source := SHUTTER_SCENE.instantiate() as Node3D
	assert(source != null)
	source.name = "CC0WeatheredRollerShutter_%s" % ("Graffiti" if graffiti else "Clean")
	add_child(source)
	var visuals: Array[MeshInstance3D] = []
	_gather_meshes(source, visuals)
	assert(visuals.size() == 2)
	for i in range(visuals.size()):
		var mesh := visuals[i]
		# The official scan contains side-by-side clean/graffiti examples:
		# expose exactly one, resetting the upstream +3m separation.
		mesh.visible = i == (1 if graffiti else 0)
		mesh.position = Vector3.ZERO
		if mesh.visible:
			_stats["source_meshes"] += 1
	# Official source mesh = 2.10m x 1.85m, genuinely modelled PBR louvers.
	# Scale uniformly, retain physical door proportions, no shader spoofing.
	source.scale = Vector3.ONE * 1.36
	source.position = Vector3(center_x, 0.66, -building_depth * 0.5 - 0.22)
	_stats["shutter_variants"] += 1

func _build() -> void:
	_build_front()
	_build_sides_and_back()
	_roof()
	_assemble_surfaces()
	_source_shutter(-3.50, false)
	_source_shutter(3.50, true)
	# A genuine open-source two-variant condenser asset and our own high-detail
	# UV steel saddles mount on the *closed* service roof, inside the parcel
	# footprint; no traffic corridor or entry/exit geometry is modified.
	var rooftop := RoofHVAC.new()
	rooftop.name = "OriginalWestDocksRoofPlant"
	rooftop.configure(building_height, building_depth)
	add_child(rooftop)
	var rooftop_stats: Dictionary = rooftop.get_roof_stats()
	_stats["rooftop_hvac_units"] = rooftop_stats["units"]
	_stats["rooftop_hvac_photo_surfaces"] = rooftop_stats["source_photo_surfaces"]
	_stats["original_mount_profiles"] = rooftop_stats["original_rail_profiles"]
	# A source-anchored 3D text identity, rather than a repeated fake neon
	# window card. These are service roll-downs, not usable scene entrances.
	var identity := Label3D.new()
	identity.name = "DockNineServiceIdentity"
	identity.text = "PIER STORAGE / NIGHT SERVICES"
	identity.font_size = 50
	identity.pixel_size = 0.009
	identity.position = Vector3(0.0, 4.33, -building_depth * 0.5 - 0.20)
	identity.rotation.y = PI
	identity.modulate = Color("d9cbc0")
	identity.outline_size = 4
	add_child(identity)
