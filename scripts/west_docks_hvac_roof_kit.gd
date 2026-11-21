extends Node3D
## Fixed, streamed rooftop plant above PIER STORAGE / NIGHT SERVICES.
## Two genuinely scanned CC0 HVAC models (clean/weathered) with their original
## 1K photo-PBR surfaces. Four custom UV-mapped I-profile roof saddles are
## original geometry, not BoxMeshes or fake textured rectangles.
const AIRCON_SCENE = preload("res://assets/models/polyhaven/exterior_aircon_unit/exterior_aircon_unit.gltf")
const PBR_ROOT = "res://assets/pbr/polyhaven/"
const EQUIPMENT_SCALE = 2.2

var building_height := 20.0
var building_depth := 23.0
var _metrics := {
	"units": 0, "visible_source_meshes": 0, "source_photo_surfaces": 0,
	"original_rail_profiles": 0, "original_rail_triangles": 0,
	"collision_bodies": 0, "added_lights": 0
}

func configure(height: float, depth: float) -> void:
	building_height = height
	building_depth = depth

func _ready() -> void:
	# Both PBR models sit on the closed photographed roof, beyond any public
	# shop door, with a deliberately varied industrial roof silhouette.
	_build_rail_mesh()
	_install_unit(-3.1, false)
	_install_unit(3.1, true)

func get_roof_stats() -> Dictionary:
	return _metrics.duplicate(true)

func _gather_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_meshes(child, output)

func _install_unit(x: float, weathered: bool) -> void:
	var source := AIRCON_SCENE.instantiate() as Node3D
	assert(source != null)
	source.name = "CC0RooftopHVAC_%s" % ("Weathered" if weathered else "Clean")
	add_child(source)
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(source, meshes)
	assert(meshes.size() == 2)
	for index in range(meshes.size()):
		var mesh := meshes[index]
		# The upstream glTF is a comparison pair offset +/-0.5m: use one
		# per scene instance and zero its preview layout displacement.
		mesh.visible = index == (1 if weathered else 0)
		mesh.position = Vector3.ZERO
		if not mesh.visible:
			continue
		_metrics["visible_source_meshes"] += 1
		assert(mesh.mesh != null)
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface_index) as StandardMaterial3D
			assert(material != null and material.albedo_texture != null)
			assert(material.normal_enabled and material.normal_texture != null)
			_metrics["source_photo_surfaces"] += 1
	# Upstream source models measure about 0.8m wide by 0.93m high.
	# The 2.2x rooftop units stand ~2.04m high; base sits on the
	# original UV-steel saddle directly above the existing roof plane.
	source.scale = Vector3.ONE * EQUIPMENT_SCALE
	source.position = Vector3(x, building_height + 0.98, -building_depth * 0.5 + 3.0)
	_metrics["units"] += 1

func _metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(PBR_ROOT + "blue_metal_plate_diffuse_2k.jpg") as Texture2D
	material.normal_texture = load(PBR_ROOT + "blue_metal_plate_nor_gl_2k.png") as Texture2D
	material.roughness_texture = load(PBR_ROOT + "blue_metal_plate_rough_2k.png") as Texture2D
	assert(material.albedo_texture != null and material.normal_texture != null)
	assert(material.roughness_texture != null)
	material.normal_enabled = true
	material.normal_scale = 0.62
	material.roughness = 1.0
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color = Color("929699")
	material.metallic = 0.66
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	for item in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		tool.set_uv(item[1])
		tool.add_vertex(item[0])
	_metrics["original_rail_triangles"] += 1

func _profile(tool: SurfaceTool, x: float, z: float) -> void:
	# Real open-flange I-section, dimensions 0.20m x 0.15m, 1.35m long.
	# Gapped flange/web cross-section creates credible shadowing and weighs
	# much less than a 3D scanned rail. No new collision in roof-only space.
	var outline := PackedVector2Array([
		Vector2(-0.10, -0.075), Vector2(0.10, -0.075),
		Vector2(0.10, -0.051), Vector2(0.018, -0.051),
		Vector2(0.018, 0.051), Vector2(0.10, 0.051),
		Vector2(0.10, 0.075), Vector2(-0.10, 0.075),
		Vector2(-0.10, 0.051), Vector2(-0.018, 0.051),
		Vector2(-0.018, -0.051), Vector2(-0.10, -0.051)
	])
	var cap_indices := Geometry2D.triangulate_polygon(outline)
	assert(cap_indices.size() >= 18)
	var y := building_height + 0.205
	var front := z - 0.675
	var back := z + 0.675
	for k in range(0, cap_indices.size(), 3):
		var a := outline[cap_indices[k]]
		var b := outline[cap_indices[k + 1]]
		var c := outline[cap_indices[k + 2]]
		var av := Vector3(x + a.x, y + a.y, front)
		var bv := Vector3(x + b.x, y + b.y, front)
		var cv := Vector3(x + c.x, y + c.y, front)
		var ua := a * 3.0
		var ub := b * 3.0
		var uc := c * 3.0
		_triangle(tool, av, cv, bv, ua, uc, ub)
		_triangle(tool, Vector3(av.x, av.y, back), Vector3(bv.x, bv.y, back),
			Vector3(cv.x, cv.y, back), ua, ub, uc)
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var av := Vector3(x + a.x, y + a.y, front)
		var bv := Vector3(x + b.x, y + b.y, front)
		var far_a := Vector3(av.x, av.y, back)
		var far_b := Vector3(bv.x, bv.y, back)
		var length := a.distance_to(b)
		_triangle(tool, av, bv, far_b,
			Vector2.ZERO, Vector2(length * 3.0, 0.0),
			Vector2(length * 3.0, 1.35 * 0.6))
		_triangle(tool, av, far_b, far_a,
			Vector2.ZERO, Vector2(length * 3.0, 1.35 * 0.6),
			Vector2(0.0, 1.35 * 0.6))
	_metrics["original_rail_profiles"] += 1

func _build_rail_mesh() -> void:
	var source := SurfaceTool.new()
	source.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -building_depth * 0.5 + 3.0
	for unit_x in [-3.1, 3.1]:
		for side in [-0.60, 0.60]:
			_profile(source, unit_x + side, z)
	source.generate_normals()
	source.generate_tangents()
	var rails := MeshInstance3D.new()
	rails.name = "OriginalUVSteelISectionRoofMounts"
	rails.mesh = source.commit()
	rails.material_override = _metal()
	add_child(rails)
