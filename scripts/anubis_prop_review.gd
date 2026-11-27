extends RefCounted
## Local in-game review of hash-pinned, unpublished Anubis candidate props.
const ROOT_ENV = "NIGHTGRID_ANUBIS_REVIEW_PROPS"
static var _meshes: Dictionary = {}

static func fitted(target: MeshInstance3D, file: String, digest: String, orientation: Basis, size: Vector3, bottom: Vector3) -> bool:
	var library := OS.get_environment(ROOT_ENV)
	if not OS.is_debug_build() or not library.is_absolute_path():
		return false
	var path := library.path_join(file)
	if not _meshes.has(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if FileAccess.get_sha256(path) != digest or document.append_from_file(path, state) != OK:
			push_error("Anubis review asset does not match the selected GLB: " + file)
			return false
		var asset := document.generate_scene(state)
		if asset == null:
			return false
		var views := asset.find_children("*", "MeshInstance3D", true, false)
		if views.size() != 1:
			asset.free()
			return false
		var imported := views[0] as MeshInstance3D
		var transform := imported.transform
		var parent := imported.get_parent() as Node3D
		while parent != null:
			transform = parent.transform * transform
			parent = parent.get_parent() as Node3D
		_meshes[path] = {"mesh": imported.mesh, "transform": transform}
		asset.free()
	var source: Dictionary = _meshes[path]
	var mesh := source["mesh"] as Mesh
	if mesh == null:
		return false
	var asset_transform := Transform3D(orientation, Vector3.ZERO) * (source["transform"] as Transform3D)
	# Use actual oriented vertices. Transforming the imported AABB can add empty space.
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := asset_transform * vertex
			lo = lo.min(point)
			hi = hi.max(point)
	var span := hi - lo
	if not span.is_finite() or span[span.min_axis_index()] <= 0.00001:
		return false
	var fit := size / span
	var origin := Vector3((hi.x + lo.x) * 0.5, lo.y, (hi.z + lo.z) * 0.5)
	target.mesh = mesh
	target.material_override = null
	target.transform = Transform3D(Basis.from_scale(fit), bottom - origin * fit) * asset_transform
	return true
