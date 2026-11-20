extends "res://scripts/brickwater_corner_finish.gd"
## Single permanent Afterhours Central Exchange building (0,0 lot 0).
## Purpose: replace floating corner/roof panels with closed, UV-mapped
## architectural solids. Inherits the finite six-faced mesh builder only.
## This does not affect the Brickwater lot or any procedural city buildings.
const GROUND = 4.55

func _build() -> void:
    var half := building_width * 0.5
    var roof_y := building_height
    var rear_z := building_depth + 0.08
    # This building's avenue wall looks WEST (-X). It begins at
    # x=-half-0.32, z=0.22 while its SOUTH wall ends at x=-half, z=-0.38.
    # A physically solid pilaster seals the L-shaped transition.
    _closed_box("CLADDING",
        Vector3(-half - 0.355, -0.14, FRONT - 0.035),
        Vector3(-half + 0.075, roof_y + 0.175, AVENUE_START + 0.035), 0.28)
    # The road-side cladding must also join the rear (+Z) elevation.
    _closed_box("CLADDING",
        Vector3(-half - 0.355, -0.14, building_depth - 0.235),
        Vector3(-half + 0.075, roof_y + 0.175, rear_z + 0.035), 0.28)
    # The east service-alley side meets a south-facing glazing assembly.
    _closed_box("CLADDING",
        Vector3(half - 0.075, -0.14, FRONT - 0.035),
        Vector3(half + 0.075, roof_y + 0.175, -0.135), 0.28)
    _closed_box("CLADDING",
        Vector3(half - 0.075, -0.14, rear_z - 0.075),
        Vector3(half + 0.075, roof_y + 0.175, rear_z + 0.035), 0.28)
    _stats["sealed_corner_returns"] = 4

    # Opaque water-table/plinth covers the old 15cm start below windows,
    # then continues down the avenue so no light leaks under the walls.
    _closed_box("CLADDING",
        Vector3(-half - 0.34, -0.14, FRONT - 0.08),
        Vector3(half + 0.07, 0.23, FRONT - 0.03), 0.25)
    _closed_box("CLADDING",
        Vector3(-half - 0.365, -0.14, AVENUE_START),
        Vector3(-half - 0.31, 0.23, building_depth - 0.205), 0.25)
    _stats["foundation_runs"] = 2

    # Continuous scanned-bitumen flat roofing membrane and real solid
    # parapet walls. Four metal caps have separate UV/normal response.
    _closed_box("ROOF",
        Vector3(-half - 0.38, roof_y + 0.165, FRONT - 0.50),
        Vector3(half + 0.09, roof_y + 0.205, rear_z + 0.065), 0.055)
    var edges := [
        [Vector3(-half - 0.385, roof_y + 0.19, FRONT - 0.52),
            Vector3(half + 0.105, roof_y + 0.74, FRONT - 0.12)],
        [Vector3(-half - 0.385, roof_y + 0.19, rear_z - 0.27),
            Vector3(half + 0.105, roof_y + 0.74, rear_z + 0.075)],
        [Vector3(-half - 0.385, roof_y + 0.19, FRONT - 0.12),
            Vector3(-half - 0.045, roof_y + 0.74, rear_z - 0.27)],
        [Vector3(half - 0.245, roof_y + 0.19, FRONT - 0.12),
            Vector3(half + 0.105, roof_y + 0.74, rear_z - 0.27)]
    ]
    for segment in edges:
        var a: Vector3 = segment[0]
        var b: Vector3 = segment[1]
        _closed_box("CLADDING", a, b, 0.24)
        _closed_box("CLADDING",
            Vector3(a.x - 0.025, roof_y + 0.73, a.z - 0.025),
            Vector3(b.x + 0.025, roof_y + 0.81, b.z + 0.025), 0.32)
        _stats["solid_roof_edges"] += 1
        _stats["coping_edges"] += 1

    # Distinctive original rooftop plant: solid metal housing with
    # opposing louver openings facing away from the pedestrian approach.
    # This is purely visual and not accessible or collidable.
    var vent_z := building_depth * 0.56
    _closed_box("CLADDING",
        Vector3(-1.40, roof_y + 0.205, vent_z),
        Vector3(1.40, roof_y + 1.68, vent_z + 2.0), 0.35)
    for slot in range(6):
        var y0 := roof_y + 0.42 + float(slot) * 0.18
        _closed_box("STEEL",
            Vector3(-1.42, y0, vent_z + 0.17),
            Vector3(-1.40, y0 + 0.07, vent_z + 1.83), 0.6)
    _stats["roof_service_grilles"] = 6

    # Give the existing long road-side canopy an engineered edge. It
    # continues under the existing swept sheet and avoids the sidewalk.
    var outer_x := -half - 0.32
    var canopy_tip := outer_x - 1.10
    _closed_box("CLADDING",
        Vector3(canopy_tip - 0.04, GROUND - 0.17, AVENUE_START + 0.24),
        Vector3(canopy_tip + 0.05, GROUND - 0.05, building_depth - 0.44), 0.31)
    _closed_box("CLADDING",
        Vector3(canopy_tip - 0.04, GROUND - 0.17, AVENUE_START + 0.24),
        Vector3(outer_x + 0.01, GROUND - 0.05, AVENUE_START + 0.32), 0.31)
    _closed_box("CLADDING",
        Vector3(canopy_tip - 0.04, GROUND - 0.17, building_depth - 0.52),
        Vector3(outer_x + 0.01, GROUND - 0.05, building_depth - 0.44), 0.31)
    _stats["canopy_edge_seals"] = 3

    # Four brushed-metal fascia corners, two continuous footing runs,
    # one roof family and one vent family: material-sorted, tangent-correct,
    # no texture/mesh generation in _process and no new dynamic lights.
    _flush()
