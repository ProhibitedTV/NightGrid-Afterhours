extends Node3D
## ONE licensed scanned botanical at Horizon Commons. The source has four
## photographed, UV-mapped fern clumps (not generated spheres/boxes).
## This node is visual-only: no collision, no physics or render-frame callbacks.
const FernScene = preload("res://assets/models/polyhaven/fern_02/fern_02_2k.gltf")
const ALPHA_THRESHOLD = 0.43
const VISIBILITY_LIMIT = 85.0
const TRIANGLE_LIMIT = 8000

var _model: Node3D
var _stats := {
    "plant_instances": 0,
    "mesh_parts": 0,
    "mesh_triangles": 0,
    "uv_meshes": 0,
    "tangent_meshes": 0,
    "alpha_scissor_surfaces": 0,
    "double_sided_surfaces": 0,
    "normal_map_surfaces": 0,
    "new_collisions": 0,
    "new_lights": 0,
    "per_frame_updates": 0
}

func _ready() -> void:
    _model = FernScene.instantiate() as Node3D
    assert(_model != null, "Photographed fern glTF failed to import")
    _model.name = "PolyHavenFern02_Scanned2K"
    # Source already has one correct authored 2m garden cluster. No yaw,
    # random scale, low-poly placeholder, or gameplay geometry changes.
    _model.position = Vector3.ZERO
    _model.scale = Vector3.ONE
    add_child(_model)
    _stats["plant_instances"] = 1
    for part in _model.find_children("*", "MeshInstance3D", true, false):
        if not (part is MeshInstance3D):
            continue
        _prepare_leaf_mesh(part)
    assert(int(_stats["mesh_parts"]) >= 4)
    assert(int(_stats["mesh_triangles"]) <= TRIANGLE_LIMIT)

func get_fern_stats() -> Dictionary:
    return _stats.duplicate()

func _prepare_leaf_mesh(part: MeshInstance3D) -> void:
    assert(part.mesh != null)
    var mesh := part.mesh
    _stats["mesh_parts"] += 1
    # The source glTF has UVs and normals but no explicit tangent attribute.
    # Generate a true tangent basis ONCE on load if Godot did not do so
    # during import. Normal-mapped leaves must not use guessed tangents.
    if mesh.get_surface_count() == 1:
        var arrays: Array = mesh.surface_get_arrays(0)
        if (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty():
            var geometry := SurfaceTool.new()
            geometry.create_from(mesh, 0)
            geometry.generate_tangents()
            var rebuilt := geometry.commit()
            var previous_material := mesh.surface_get_material(0)
            if previous_material != null:
                rebuilt.surface_set_material(0, previous_material)
            part.mesh = rebuilt
            mesh = rebuilt
    for surface in range(mesh.get_surface_count()):
        var arrays: Array = mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
        var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        assert(uvs.size() == vertices.size() and not vertices.is_empty())
        assert(tangents.size() == vertices.size() * 4)
        _stats["uv_meshes"] += 1
        _stats["tangent_meshes"] += 1
        _stats["mesh_triangles"] += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
        var imported := mesh.surface_get_material(surface) as BaseMaterial3D
        assert(imported != null, "Godot lost the source fern PBR material")
        # Preserve original photograph, GL tangent normal, ORM and authored
        # leaf UVs. Alpha-scissor cutouts eliminate the atlas-card rectangles
        # while avoiding expensive alpha-blended foliage sorting.
        var pbr := imported.duplicate() as BaseMaterial3D
        pbr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        pbr.alpha_scissor_threshold = ALPHA_THRESHOLD
        pbr.cull_mode = BaseMaterial3D.CULL_DISABLED
        pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        pbr.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
        part.set_surface_override_material(surface, pbr)
        _stats["alpha_scissor_surfaces"] += 1
        _stats["double_sided_surfaces"] += 1
        if pbr.normal_enabled and pbr.normal_texture != null:
            _stats["normal_map_surfaces"] += 1
    # Foliage casts real masked directional sunlight shadows from both
    # sides but receives no local dynamic lights or shadow casters of its own.
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
    part.visibility_range_end = VISIBILITY_LIMIT
    part.visibility_range_end_margin = 12.0
