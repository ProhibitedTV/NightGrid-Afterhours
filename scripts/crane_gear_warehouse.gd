extends Node3D
## Permanent West Docks (-4,-2), lot 1: CRANE & GEAR.
## Genuine preauthored glTF production geometry with three scanned 1K CC0 PBR
## material families. This asset is NOT created in a per-frame city draw loop.
## A preserved invisible BoxShape3D remains the only parcel collider.
const CRANE_GEAR_SCENE = preload("res://assets/models/nightgrid/crane_gear/crane_gear_warehouse.gltf")
const MODEL_WIDTH = 16.1
const MODEL_HEIGHT = 20.0
const MODEL_DEPTH = 23.0

var building_width := MODEL_WIDTH
var building_height := MODEL_HEIGHT
var building_depth := MODEL_DEPTH
var _art_stats := {
	"source_meshes": 0, "source_surfaces": 0, "source_vertices": 0,
	"photographic_pbr_surfaces": 0, "source_material_variants": 0,
	"collision_bodies": 0, "added_lights": 0
}

func configure(width: float, height: float, depth: float) -> void:
	building_width = width
	building_height = height
	building_depth = depth

func _ready() -> void:
	assert(building_width > 10.0 and building_height > 10.0 and building_depth > 20.0)
	var source := CRANE_GEAR_SCENE.instantiate() as Node3D
	assert(source != null)
	source.name = "OriginalCraneGearAuthoredGLTF"
	# Source artist meters correspond to the standard 16.1 x 20 x 23m W2
	# frontage; scale from the *stored profile* for alternative saved seeds
	# without rerolling the lot/address or disturbing the existing collider.
	source.scale = Vector3(building_width / MODEL_WIDTH,
		building_height / MODEL_HEIGHT, building_depth / MODEL_DEPTH)
	add_child(source)
	_measure(source)
	assert(_art_stats["source_meshes"] == 1)
	assert(_art_stats["source_surfaces"] == 6)
	assert(_art_stats["source_vertices"] >= 6000)
	assert(_art_stats["photographic_pbr_surfaces"] >= 3)

func _measure(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			_art_stats["source_meshes"] += 1
			for s in range(mesh_node.mesh.get_surface_count()):
				_art_stats["source_surfaces"] += 1
				_art_stats["source_vertices"] += (mesh_node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var material := mesh_node.mesh.surface_get_material(s) as StandardMaterial3D
				if material == null:
					continue
				_art_stats["source_material_variants"] += 1
				if material.albedo_texture != null and material.normal_enabled and (
						material.normal_texture != null and material.roughness_texture != null):
					_art_stats["photographic_pbr_surfaces"] += 1
	for child in node.get_children():
		_measure(child)

func get_art_stats() -> Dictionary:
	return _art_stats.duplicate(true)
