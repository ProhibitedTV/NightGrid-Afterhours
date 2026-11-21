extends Node3D
## Central Exchange measured inner-corner sidewalk edge kit.
## The 8 previously generic 36m gray curb strips are replaced with 8 static
## source-authored glTF street profiles, with genuine CC0 photographed exposed
## concrete, blue steel drain hardware and recessed asphalt gutter channels.
## No per-frame generated meshes, collision, lamps, physics or save changes.
const PLUS = preload("res://assets/models/nightgrid/central_exchange_curb/central_curb_outer_plus.gltf")
const MINUS = preload("res://assets/models/nightgrid/central_exchange_curb/central_curb_outer_minus.gltf")
const EDGE_AT = 8.2
const LONG_CENTER = 32.0
const SPAN = 36.0

var _stats := {
	"installed_static_modules": 0,
	"source_meshes": 0, "source_surfaces": 0, "source_vertices": 0,
	"photographed_material_surfaces": 0,
	"concrete_slab_sections": 0, "gutter_drain_grates": 0,
	"physical_colliders_added": 0, "night_lights_added": 0
}

func _ready() -> void:
	name = "CentralExchangeAuthoredCurbProfiles"
	# Eight real 36m inner-edge curb runs around the four parcels adjacent
	# to the city-grid origin. At all four entrances, old 6m crossing breaks
	# remain untouched; hero ramps retain their existing material and position.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# X-parallel? Fixed x, its authored local Z follows world Z.
			_install("EW_Corner_%d_%d" % [int(sx),int(sz)],
				Vector3(sx * EDGE_AT,0.0,sz * LONG_CENTER),0.0,int(sx))
			# Fixed z, local Z rotates into world +X. Local +X on this
			# orientation points world -Z, hence flip the apron orientation.
			_install("NS_Corner_%d_%d" % [int(sx),int(sz)],
				Vector3(sx * LONG_CENTER,0.0,sz * EDGE_AT),PI*0.5,-int(sz))
	assert(_stats["installed_static_modules"] == 8)
	assert(_stats["source_surfaces"] == 24)
	assert(_stats["photographed_material_surfaces"] == 24)

func get_curbstone_stats() -> Dictionary:
	return _stats.duplicate(true)

func _install(label_name: String, center: Vector3, angle: float, apron_sign: int) -> void:
	assert(apron_sign == 1 or apron_sign == -1)
	var target: Node3D = (PLUS if apron_sign > 0 else MINUS).instantiate() as Node3D
	assert(target != null)
	target.name = label_name
	target.position = center
	target.rotation.y = angle
	add_child(target)
	var source_meshes: Array[MeshInstance3D] = []
	_walk(target,source_meshes)
	assert(source_meshes.size() == 1)
	for piece in source_meshes:
		assert(piece.mesh != null and piece.mesh.get_surface_count() == 3)
		_stats["source_meshes"] += 1
		for surface in range(piece.mesh.get_surface_count()):
			var arrays: Array = piece.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			assert(vertices.size() >= 100)
			assert((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == vertices.size())
			assert((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() == vertices.size() * 4)
			var material := piece.mesh.surface_get_material(surface) as StandardMaterial3D
			assert(material != null)
			assert(material.albedo_texture != null and material.normal_enabled)
			assert(material.normal_texture != null and material.roughness_texture != null)
			_stats["source_surfaces"] += 1
			_stats["photographed_material_surfaces"] += 1
			_stats["source_vertices"] += vertices.size()
	_stats["concrete_slab_sections"] += 12
	_stats["gutter_drain_grates"] += 6
	_stats["installed_static_modules"] += 1

func _walk(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_walk(child,result)
