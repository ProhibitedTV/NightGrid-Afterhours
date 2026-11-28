extends Node3D
## One node per city chunk instead of one MultiMeshInstance3D per material
## bucket. Static, non-interactive drawing is managed by RenderingServer.
## Physics/interaction/labels remain in the SceneTree. Batches are spatially
## separated upstream in city_details.gd, preserving their culling granularity.
##
## IMPORTANT: a server RID is not owned by the SceneTree. This node alone
## retains each backing MultiMesh and material, and frees all instance RIDs
## during chunk cancellation, teleport unload and world teardown.
var _instances: Array[RID] = []
var _meshes: Array[MultiMesh] = []
var _materials: Array[Material] = []
var _detail_count := 0

func add_batch(batch: MultiMesh, material: Material, visibility_end: float = 0.0) -> void:
	assert(is_inside_tree(), "RenderingServer batches need a live World3D scenario")
	assert(batch != null and batch.mesh != null and batch.instance_count > 0)
	# The upstream MultiMesh stores world-space transforms in the base mesh,
	# because the procedural chunk roots are intentionally all at origin.
	# Do not apply the parent transform again or move parcel collisions.
	var visual := RenderingServer.instance_create()
	RenderingServer.instance_set_base(visual, batch.get_rid())
	RenderingServer.instance_set_scenario(visual, get_world_3d().scenario)
	if material != null:
		RenderingServer.instance_geometry_set_material_override(visual, material.get_rid())
	if visibility_end > 0.0:
		RenderingServer.instance_geometry_set_visibility_range(visual, 0.0, visibility_end, 0.0, 0.0, RenderingServer.VISIBILITY_RANGE_FADE_DISABLED)
	RenderingServer.instance_set_transform(visual, Transform3D.IDENTITY)
	_instances.append(visual)
	_meshes.append(batch)
	_materials.append(material)
	_detail_count += batch.instance_count

func get_batch_stats() -> Dictionary:
	return {
		"batches": _instances.size(),
		"instances": _detail_count,
		"retained_meshes": _meshes.size(),
		"retained_materials": _materials.size()
	}

func _exit_tree() -> void:
	for instance in _instances:
		if instance.is_valid():
			RenderingServer.free_rid(instance)
	_instances.clear()
	_meshes.clear()
	_materials.clear()
	_detail_count = 0
