extends RefCounted
## Imported original meshes; no runtime geometry generation.
const ROOT = "res://assets/models/nightgrid/botanical/"
const SPECIES = ["date_palm", "fan_palm", "coast_oak", "cypress", "shrub", "agave", "grass"]
static var _cache: Dictionary = {}

static func mesh_for(species: String, lod: int) -> Mesh:
	var key := "%s_lod%d" % [species, lod]
	if _cache.has(key):
		return _cache[key] as Mesh
	var path := ROOT + key + ".glb"
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	var part := instance as MeshInstance3D
	if part == null:
		var parts := instance.find_children("*", "MeshInstance3D", true, false)
		if parts.size() == 1:
			part = parts[0] as MeshInstance3D
	var mesh: Mesh = part.mesh if part != null else null
	instance.free()
	if mesh != null:
		_cache[key] = mesh
	return mesh
