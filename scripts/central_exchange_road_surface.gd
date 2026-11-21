extends Node3D
## Central Exchange photographed roadway PBR pilot.
## Restores texture scale and actual micro-surface response on ONE measured
## junction; not a speculative procedural city-wide upgrade.
##
## Exactly two material-sorted ArrayMesh drawables. These sit a few
## millimetres above existing road visuals and BELOW zebra/stop-line paint.
## No collisions, roadside props, road centerline, save schema or new lights.
const ROOT = "res:" + "//assets/pbr/polyhaven/bitumen_"
const SURFACE_Y = 0.016
const CENTER_HALF = 7.0
const ROAD_HALF = 6.94
const SHOULDER_START = 5.70
const NEAR_CROSSING = 14.15
const OUTER_LIMIT = 42.0
const METRES_PER_TILE = 3.5

var _stats := {
	"mesh_instances": 0, "dry_quads": 0, "damp_quads": 0,
	"normal_map_surfaces": 0, "photographed_maps": 0,
	"collision_bodies": 0, "lights": 0
}
var _materials: Dictionary = {}

func _ready() -> void:
	name = "CentralExchangeScannedRoadway"
	_build()

func get_surface_stats() -> Dictionary:
	return _stats.duplicate(true)

func get_surface_material(wet: bool) -> StandardMaterial3D:
	return _materials.get("DAMP" if wet else "DRY")

func _build() -> void:
	var paths := [ROOT + "diffuse_2k.jpg", ROOT + "nor_gl_2k.png",
		ROOT + "rough_2k.png"]
	# This is a source-owned, imported CC0 photo scan: refuse to fake the
	# art pass using the old 128px procedural map if it is unavailable.
	for path in paths:
		if not ResourceLoader.exists(path):
			push_error("Scanned Central Exchange roadway requires bundled CC0 bitumen map: " + path)
			return
	var albedo := load(paths[0]) as Texture2D
	var normal := load(paths[1]) as Texture2D
	var roughness := load(paths[2]) as Texture2D
	if albedo == null or normal == null or roughness == null:
		push_error("Central Exchange photographic road maps failed to import")
		return
	_stats["photographed_maps"] = 3
	for kind in ["DRY", "DAMP"]:
		var material := StandardMaterial3D.new()
		material.albedo_texture = albedo
		material.normal_enabled = true
		material.normal_texture = normal
		material.normal_scale = 0.55 if kind == "DAMP" else 0.75
		material.roughness_texture = roughness
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.roughness = 0.52 if kind == "DAMP" else 1.0
		material.albedo_color = Color("707a84") if kind == "DAMP" else Color("92979a")
		material.metallic = 0.0
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3.ONE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.cull_mode = BaseMaterial3D.CULL_BACK
		# Motivated drain-side dampness, without mirror-finish pavement.
		if kind == "DAMP":
			material.clearcoat_enabled = true
			material.clearcoat = 0.25
			material.clearcoat_roughness = 0.22
		_materials[kind] = material

	var dry: Array[PackedVector3Array] = []
	var damp: Array[PackedVector3Array] = []
	# Center of the actual car/tram intersection. Four-way road foundation
	# spans ±7m; crossing paint is OUTSIDE this square at ±10.3m.
	dry.append(_rectangle(-CENTER_HALF, CENTER_HALF, -CENTER_HALF, CENTER_HALF))
	for direction in range(4):
		# East/west and north/south approach lanes use the same road widths,
		# but no new road geometry, traffic physics or pavement collision.
		if direction == 0:
			_append_approach(dry, damp, -OUTER_LIMIT, -NEAR_CROSSING, true)
		elif direction == 1:
			_append_approach(dry, damp, NEAR_CROSSING, OUTER_LIMIT, true)
		elif direction == 2:
			_append_approach(dry, damp, -OUTER_LIMIT, -NEAR_CROSSING, false)
		else:
			_append_approach(dry, damp, NEAR_CROSSING, OUTER_LIMIT, false)
	_make_surface("ScannedBitumenRunningLanes", dry, _materials["DRY"])
	_make_surface("ScannedBitumenDampGutters", damp, _materials["DAMP"])

func _append_approach(dry: Array[PackedVector3Array],
		damp: Array[PackedVector3Array], lo: float, hi: float,
		east_west: bool) -> void:
	# A dry two-way travel surface with narrow, roughness-varied shoulders
	# follows the real 14m road, not the adjoining 42m sidewalk parcels.
	if east_west:
		dry.append(_rectangle(lo, hi, -SHOULDER_START, SHOULDER_START))
		damp.append(_rectangle(lo, hi, -ROAD_HALF, -SHOULDER_START))
		damp.append(_rectangle(lo, hi, SHOULDER_START, ROAD_HALF))
	else:
		dry.append(_rectangle(-SHOULDER_START, SHOULDER_START, lo, hi))
		damp.append(_rectangle(-ROAD_HALF, -SHOULDER_START, lo, hi))
		damp.append(_rectangle(SHOULDER_START, ROAD_HALF, lo, hi))

func _rectangle(left: float, right: float, back: float, front: float) -> PackedVector3Array:
	assert(left < right and back < front)
	# With up-facing normals, these two triangles have CCW outward winding.
	var a := Vector3(left, SURFACE_Y, back)
	var b := Vector3(right, SURFACE_Y, back)
	var c := Vector3(right, SURFACE_Y, front)
	var d := Vector3(left, SURFACE_Y, front)
	return PackedVector3Array([a, c, b, a, d, c])

func _make_surface(name: String, quads: Array[PackedVector3Array],
		material: StandardMaterial3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var tangent := PackedFloat32Array()
	for quad in quads:
		for point in quad:
			vertices.append(point)
			normals.append(Vector3.UP)
			# World-anchored 3.5m photo tile independent of parcel length.
			uv.append(Vector2(point.x, point.z) / METRES_PER_TILE)
			# T=+X; UV V=+Z, so sign=-1 for B=+Z with N=+Y.
			tangent.append_array(PackedFloat32Array([1.0, 0.0, 0.0, -1.0]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TANGENT] = tangent
	var actual_mesh := ArrayMesh.new()
	actual_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = actual_mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["mesh_instances"] += 1
	_stats["normal_map_surfaces"] += 1
	if name == "ScannedBitumenDampGutters":
		_stats["damp_quads"] = quads.size()
	else:
		_stats["dry_quads"] = quads.size()
