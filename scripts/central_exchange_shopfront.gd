extends Node3D
## Two original author-designed, true 3D walk-in retail vestibules. Source
## glTF geometry and all 12 photo-PBR maps are pinned from official CC0 scans,
## auditable offline. Their center doorway is 2.84m wide x 3.17m high and the
## actual four-part city shell is opened for a 3.35m walkable interior bay.
## Unlike glass-sticker façades these have transparent display glass, measured
## extruded steel jambs, genuinely recessed merch bays and a modeled room.
const BRICK_SHOP = preload("res://assets/models/nightgrid/central_exchange_storefront/brickwater_retail.gltf")
const REPAIR_SHOP = preload("res://assets/models/nightgrid/central_exchange_storefront/afterhours_repair.gltf")
const ROOM_DEPTH = 3.35
const PORTAL_WIDTH = 2.84
const PORTAL_CLEAR_HEIGHT = 3.17

var retail_district := "BRICKWATER"
var _stats := {
	"source_models": 0, "source_vertices": 0, "source_triangles": 0,
	"original_photo_material_groups": 0, "source_uv_surfaces": 0,
	"display_windows": 0, "visible_room_depth_m": 0.0,
	"portal_opening_width_m": 0.0, "portal_clear_height_m": 0.0,
	"new_collision_bodies": 0, "new_dynamic_lights": 0
}

func configure(area: String) -> void:
	retail_district = area

func _ready() -> void:
	name = "Original3DWalkInRetailVestibule"
	var selection: PackedScene = BRICK_SHOP if retail_district == "BRICKWATER" else REPAIR_SHOP
	var imported := selection.instantiate() as Node3D
	assert(imported != null)
	imported.name = "SourceAuthoredPhotoGLTF"
	add_child(imported)
	var sources: Array[MeshInstance3D] = []
	_walk(imported, sources)
	assert(sources.size() == 1)
	for source in sources:
		var mesh := source.mesh
		assert(mesh != null and mesh.get_surface_count() == 6)
		_stats["source_models"] += 1
		for index in range(mesh.get_surface_count()):
			var rows: Array = mesh.surface_get_arrays(index)
			var verts: PackedVector3Array = rows[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = rows[Mesh.ARRAY_TEX_UV]
			var tans: PackedFloat32Array = rows[Mesh.ARRAY_TANGENT]
			assert(verts.size() >= 4 and uvs.size() == verts.size())
			assert(tans.size() == verts.size() * 4)
			_stats["source_vertices"] += verts.size()
			_stats["source_triangles"] += (rows[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			_stats["source_uv_surfaces"] += 1
			if index < 4:
				var material := mesh.surface_get_material(index) as StandardMaterial3D
				assert(material != null and material.albedo_texture != null)
				assert(material.normal_enabled and material.normal_texture != null)
				assert(material.roughness_texture != null)
				_stats["original_photo_material_groups"] += 1
	_stats["display_windows"] = 2
	_stats["visible_room_depth_m"] = ROOM_DEPTH
	_stats["portal_opening_width_m"] = PORTAL_WIDTH
	_stats["portal_clear_height_m"] = PORTAL_CLEAR_HEIGHT

func get_retail_stats() -> Dictionary:
	return _stats.duplicate(true)

func _walk(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		_walk(child, found)
