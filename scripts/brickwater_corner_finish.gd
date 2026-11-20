extends Node3D
## Brickwater's single permanent Central Exchange corner, NOT a generic city
## generator. Closing structural returns and solid parapet/coping are built
## once when this streamed block loads. No collisions or real-time lights.
## The scanned brick and steel materials come from the owning frontage.
const FRONT = -0.38
const AVENUE_START = 0.22

var building_width := 15.0
var building_height := 20.0
var building_depth := 23.0
var _quads: Dictionary = {}
var _stats := {
    "sealed_corner_returns": 0,
    "solid_roof_edges": 0,
    "coping_edges": 0,
    "foundation_runs": 0,
    "array_mesh_surfaces": 0,
    "new_collisions": 0,
    "new_lights": 0
}

func configure(width: float, height: float, depth: float) -> void:
    building_width = width
    building_height = height
    building_depth = depth

func get_finish_stats() -> Dictionary:
    return _stats.duplicate()

func _ready() -> void:
    _build()

func _quad(family: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale: float) -> void:
    if not _quads.has(family):
        _quads[family] = []
    (_quads[family] as Array).append([a, b, c, d, uv_scale])

func _closed_box(family: String, lower: Vector3, upper: Vector3, uv_scale: float = 0.35) -> void:
    # All SIX exterior faces are explicitly wound outward. Unlike the old
    # ribbon faces, these have thickness, no backface holes and no gaps at
    # oblique pedestrian/vehicle viewpoints.
    assert(lower.x < upper.x and lower.y < upper.y and lower.z < upper.z)
    var x0 := lower.x
    var y0 := lower.y
    var z0 := lower.z
    var x1 := upper.x
    var y1 := upper.y
    var z1 := upper.z
    _quad(family, Vector3(x0,y0,z0), Vector3(x0,y1,z0), Vector3(x1,y1,z0), Vector3(x1,y0,z0), uv_scale) # -Z
    _quad(family, Vector3(x0,y0,z1), Vector3(x1,y0,z1), Vector3(x1,y1,z1), Vector3(x0,y1,z1), uv_scale) # +Z
    _quad(family, Vector3(x1,y0,z0), Vector3(x1,y1,z0), Vector3(x1,y1,z1), Vector3(x1,y0,z1), uv_scale) # +X
    _quad(family, Vector3(x0,y0,z0), Vector3(x0,y0,z1), Vector3(x0,y1,z1), Vector3(x0,y1,z0), uv_scale) # -X
    _quad(family, Vector3(x0,y1,z0), Vector3(x0,y1,z1), Vector3(x1,y1,z1), Vector3(x1,y1,z0), uv_scale) # +Y
    _quad(family, Vector3(x0,y0,z0), Vector3(x1,y0,z0), Vector3(x1,y0,z1), Vector3(x0,y0,z1), uv_scale) # -Y

func _build() -> void:
    var half := building_width * 0.5
    var h := building_height
    var back := building_depth + 0.08
    # The existing south elevation ends at x=+half, z=-0.38. The avenue
    # elevation begins at x=half+0.32, z=0.22. Real opaque returns bridge
    # both planes instead of exposing the sky/background between them.
    # Small overlaps are deliberate: no coplanar, z-fighting seams.
    _closed_box("MASONRY", Vector3(half - 0.07, -0.13, FRONT - 0.022),
        Vector3(half + 0.345, h + 0.15, AVENUE_START + 0.025))
    _closed_box("MASONRY", Vector3(half - 0.055, -0.13, building_depth - 0.225),
        Vector3(half + 0.345, h + 0.15, back + 0.028))
    # Service-alley side uses a different exterior X plane (-half-0.04).
    _closed_box("MASONRY", Vector3(-half - 0.065, -0.13, FRONT - 0.022),
        Vector3(-half + 0.065, h + 0.15, -0.135))
    _closed_box("MASONRY", Vector3(-half - 0.065, -0.13, back - 0.065),
        Vector3(-half + 0.065, h + 0.15, back + 0.028))
    _stats["sealed_corner_returns"] = 4

    # A continuous footing prevents seeing underneath wall faces where the
    # existing facade visually begins 0.15m above its local origin.
    _closed_box("MASONRY", Vector3(-half - 0.045, -0.15, FRONT - 0.065),
        Vector3(half + 0.33, 0.22, FRONT - 0.026))
    _closed_box("MASONRY", Vector3(half + 0.305, -0.15, AVENUE_START),
        Vector3(half + 0.35, 0.22, building_depth - 0.195))
    _stats["foundation_runs"] = 2

    # Continuous roof membrane over the old structural roof plane, with a
    # complete solid parapet instead of a floating front-facing rectangle.
    _closed_box("PARAPET", Vector3(-half - 0.06, h + 0.165, FRONT - 0.49),
        Vector3(half + 0.36, h + 0.205, back + 0.045), 0.27)
    var edges := [
        [Vector3(-half - 0.075, h + 0.19, FRONT - 0.505),
            Vector3(half + 0.375, h + 0.67, FRONT - 0.115)],
        [Vector3(-half - 0.075, h + 0.19, back - 0.285),
            Vector3(half + 0.375, h + 0.67, back + 0.065)],
        [Vector3(-half - 0.075, h + 0.19, FRONT - 0.115),
            Vector3(-half + 0.265, h + 0.67, back - 0.285)],
        [Vector3(half + 0.035, h + 0.19, FRONT - 0.115),
            Vector3(half + 0.375, h + 0.67, back - 0.285)]
    ]
    for segment in edges:
        var a: Vector3 = segment[0]
        var b: Vector3 = segment[1]
        _closed_box("MASONRY", a, b)
        _stats["solid_roof_edges"] += 1
        # Separate painted steel counterflashing: scanned normal + roughness.
        _closed_box("CLADDING", Vector3(a.x - 0.035, h + 0.665, a.z - 0.035),
            Vector3(b.x + 0.035, h + 0.755, b.z + 0.035), 0.40)
        _stats["coping_edges"] += 1
    # Roof access housing is inset from the edge and never intersects a
    # skylight, street, existing collision or the train silhouette.
    _closed_box("CLADDING", Vector3(-1.0, h + 0.205, building_depth * 0.51),
        Vector3(0.65, h + 0.70, building_depth * 0.51 + 2.25), 0.40)
    _flush()

func _flush() -> void:
    for family in _quads:
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        for quad in _quads[family]:
            var a: Vector3 = quad[0]
            var b: Vector3 = quad[1]
            var c: Vector3 = quad[2]
            var d: Vector3 = quad[3]
            var scale: float = quad[4]
            var normal: Vector3 = (b - a).cross(c - a).normalized()
            for p in [a, b, c, a, c, d]:
                var uv: Vector2
                if absf(normal.x) > 0.5:
                    uv = Vector2(p.z, p.y) * scale
                elif absf(normal.y) > 0.5:
                    uv = Vector2(p.x, p.z) * scale
                else:
                    uv = Vector2(p.x, p.y) * scale
                surface.set_uv(uv)
                surface.add_vertex(p)
        surface.generate_normals()
        surface.generate_tangents()
        var node := MeshInstance3D.new()
        node.name = "SolidFinish_%s" % family
        node.mesh = surface.commit()
        # Clone only so this properly closed finish can use back-face
        # culling even while legacy inset reveals remain double-sided.
        var pbr := get_parent().call("_surface_material", str(family)) as StandardMaterial3D
        var instance := pbr.duplicate() as StandardMaterial3D
        instance.cull_mode = BaseMaterial3D.CULL_BACK
        node.material_override = instance
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        add_child(node)
        _stats["array_mesh_surfaces"] += 1
    _quads.clear()
