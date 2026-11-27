extends Node3D
## CENTRAL EXCHANGE -- measured urban street realism *at the playable origin*.
## Actual source glTFs from Poly Haven's CC0 Hidden Alley collection:
##  - metal_trash_can: original clean and rusted models incl. real lid/handles
##  - utility_box_01: single photographed high-voltage cabinet
## With collision shells confined to the perimeter sidewalks, never the
## transit carriageway/crossings. Four bounded Forward+ photo-PBR decals
## add asphalt oil/grime variety without covering the entire city in chrome.
## Original source hashes in each asset's SOURCE.json. Never downloads at runtime.
const TRASH_CAN = preload("res://assets/models/polyhaven/metal_trash_can/metal_trash_can.gltf")
const UTILITY_BOX = preload("res://assets/models/polyhaven/utility_box_01/utility_box_01.gltf")
const DECAL_ROOT = "res://assets/pbr/nightgrid/central_exchange/"
const SIDEWALK_LEVEL = 0.16

const SITES = [
	{"name": "SouthwestRustedBin", "kind": "TRASH", "rust": true,
		"position": Vector3(-15.5, SIDEWALK_LEVEL, -15.8)},
	{"name": "NortheastCleanBin", "kind": "TRASH", "rust": false,
		"position": Vector3(16.5, SIDEWALK_LEVEL, 12.2)},
	{"name": "SoutheastRustedBin", "kind": "TRASH", "rust": true,
		"position": Vector3(13.6, SIDEWALK_LEVEL, -16.6)},
	{"name": "NorthwestPowerCabinet", "kind": "UTILITY",
		"position": Vector3(-16.5, SIDEWALK_LEVEL, 12.2)},
	{"name": "SoutheastPowerCabinet", "kind": "UTILITY",
		"position": Vector3(16.7, SIDEWALK_LEVEL, -15.8)}
]
const ROAD_WEAR = [
	{"name": "NorthGutterOil", "kind": "OIL", "at": Vector3(-5.08, 0.08, 17.6),
		"rotation": 0.0},
	{"name": "SouthGutterOil", "kind": "OIL", "at": Vector3(5.12, 0.08, -17.8),
		"rotation": 0.0},
	{"name": "WestGutterGrime", "kind": "GRIT", "at": Vector3(-17.8, 0.08, 5.1),
		"rotation": PI * 0.5},
	{"name": "EastGutterGrime", "kind": "GRIT", "at": Vector3(17.8, 0.08, -5.2),
		"rotation": PI * 0.5}
]

var _stats := {
	"source_installs": 0, "visible_source_meshes": 0,
	"source_vertices": 0, "photo_material_surfaces": 0,
	"sidewalk_collision_bodies": 0, "road_decal_projections": 0,
	"road_decal_photo_maps": 0, "added_lights": 0
}
var _textures: Dictionary = {}

func _ready() -> void:
	name = "CentralExchangePhotoStreetKit"
	for site in SITES:
		_install_site(site)
	for stain in ROAD_WEAR:
		_add_decal(stain)

func get_street_stats() -> Dictionary:
	return _stats.duplicate(true)

func _walk_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_walk_meshes(child, result)

func _install_site(site: Dictionary) -> void:
	var at: Vector3 = site["position"]
	# All authored positions are outside the protected 14m road/crossings.
	assert(absf(at.x) > 12.5 and absf(at.z) > 11.5)
	var placed := Node3D.new()
	placed.name = str(site["name"])
	placed.position = at
	add_child(placed)
	var trash: bool = str(site["kind"]) == "TRASH"
	var rust: bool = trash and bool(site.get("rust", false))
	var imported := (TRASH_CAN if trash else UTILITY_BOX).instantiate() as Node3D
	assert(imported != null)
	imported.name = "OriginalPolyHavenPhotoGLTF"
	placed.add_child(imported)
	var original_meshes: Array[MeshInstance3D] = []
	_walk_meshes(imported, original_meshes)
	assert(original_meshes.size() == (8 if trash else 1))
	var visible_meshes := 0
	for mesh in original_meshes:
		if trash:
			# The official clean/rust source is two side-by-side complete
			# preview props at +/-0.5m; keep all four components (lid, handles,
			# barrel) for just ONE variant per real street placement.
			var is_rusted := str(mesh.name).to_lower().contains("rust")
			mesh.visible = is_rusted == rust
			mesh.position.x += 0.5 if rust else -0.5
		if not mesh.visible:
			continue
		visible_meshes += 1
		_stats["visible_source_meshes"] += 1
		assert(mesh.mesh != null)
		for surface in range(mesh.mesh.get_surface_count()):
			_stats["source_vertices"] += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var original_material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			assert(original_material != null and original_material.albedo_texture != null)
			assert(original_material.normal_enabled and original_material.normal_texture != null)
			_stats["photo_material_surfaces"] += 1
	assert(visible_meshes == (4 if trash else 1))
	# Unlike the old visually solid/no-physics roadside boxes these actually
	# stop the avatar clipping through them; collision is deliberately tighter
	# than the visible scanned silhouette. No road, intersection or door shell
	# geometry is changed and no save fields are added.
	var body := StaticBody3D.new()
	body.name = "RealStreetFurnitureCollider"
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.53, 0.83, 0.50) if trash else Vector3(0.48, 1.09, 0.40)
	var geometry := CollisionShape3D.new()
	geometry.name = "MeasuredStreetCollision"
	geometry.shape = shape
	geometry.position.y = shape.size.y * 0.5
	body.add_child(geometry)
	placed.add_child(body)
	_stats["sidewalk_collision_bodies"] += 1
	_stats["source_installs"] += 1

func _decal_texture(kind: String, channel: String) -> Texture2D:
	var canonical_kind := "grit" if channel == "normal" and kind.to_lower() in ["grit", "oil"] else kind.to_lower()
	var key := canonical_kind + "_" + channel
	if _textures.has(key):
		return _textures[key]
	var path := DECAL_ROOT + canonical_kind + "_" + channel + "_512.png"
	var texture := load(path) as Texture2D
	assert(texture != null)
	_textures[key] = texture
	_stats["road_decal_photo_maps"] += 1
	return texture

func _add_decal(info: Dictionary) -> void:
	var at: Vector3 = info["at"]
	# Defined directly on the existing asphalt *outside* pedestrian zebra
	# markings: no extra geometry/physics, no road stripe removal.
	assert(maxf(absf(at.x), absf(at.z)) > 15.5)
	assert(minf(absf(at.x), absf(at.z)) < 6.5)
	var kind: String = info["kind"]
	var decal := Decal.new()
	decal.name = str(info["name"])
	decal.position = at
	decal.rotation.y = float(info["rotation"])
	decal.size = Vector3(2.4, 0.19, 3.6)
	decal.texture_albedo = _decal_texture(kind, "albedo")
	decal.texture_normal = _decal_texture(kind, "normal")
	decal.texture_orm = _decal_texture(kind, "orm")
	decal.modulate = Color(0.88, 0.92, 0.95, 0.75)
	decal.albedo_mix = 0.72
	decal.normal_fade = 0.0
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 35.0
	decal.distance_fade_length = 14.0
	add_child(decal)
	_stats["road_decal_projections"] += 1
