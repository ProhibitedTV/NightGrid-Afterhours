extends SceneTree
## Engine-level QA for ONE source-authored 2K scanned fern at Horizon Commons.
## Real Vulkan visuals/performance still require player hardware inspection.
func _initialize() -> void:
    call_deferred("_check")

func _fail(message: String) -> void:
    push_error("HORIZON_FERN_SMOKE: " + message)
    quit(1)

func _check() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("Cannot load playable world")
        return
    var world := scene.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    var flora := world.get_node_or_null("CityFlora") as Node3D
    if flora == null:
        _fail("Existing city flora node missing")
        return
    var pilot := flora.get_node_or_null("HorizonCommonsHeroFern") as Node3D
    if pilot == null:
        _fail("No scanned fern appears at the protected Horizon Commons location")
        return
    if pilot.position.distance_to(Vector3(187.5, 0.20, 29.0)) > 0.02:
        _fail("Scanned fern was detached from the fixed park bed")
        return
    var flora_stats: Dictionary = flora.call("get_stats")
    if int(flora_stats.get("scanned_hero_ferns", 0)) != 1 or int(flora_stats["street_trees"]) != 128:
        _fail("Hero fern duplicated or replaced the seeded street tree network: %s" % flora_stats)
        return
    var stats: Dictionary = pilot.call("get_fern_stats")
    if int(stats["plant_instances"]) != 1 or int(stats["mesh_parts"]) != 4:
        _fail("The four scanned frond meshes were dropped: %s" % stats)
        return
    if int(stats["mesh_triangles"]) < 3000 or int(stats["mesh_triangles"]) > 8000:
        _fail("Triangle budget or scanned leaf topology incorrect: %s" % stats)
        return
    for k in ["uv_meshes", "tangent_meshes", "alpha_scissor_surfaces",
            "double_sided_surfaces", "normal_map_surfaces"]:
        if int(stats[k]) != 4:
            _fail("Missing photo-real leaf PBR/alpha/tangent feature %s: %s" % [k, stats])
            return
    if int(stats["new_collisions"]) != 0 or int(stats["new_lights"]) != 0 or int(stats["per_frame_updates"]) != 0:
        _fail("Art-only plant changed collisions, dynamic lights or frame loop")
        return
    for child in pilot.find_children("*", "MeshInstance3D", true, false):
        var leaf := child as MeshInstance3D
        if leaf == null or leaf.mesh == null:
            _fail("Scanned fern leaf is not a drawable mesh")
            return
        var mat := leaf.get_active_material(0) as BaseMaterial3D
        if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
            _fail("Photo cutout was not used to hide square background cards")
            return
        if mat.cull_mode != BaseMaterial3D.CULL_DISABLED or leaf.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED:
            _fail("Thin fronds need two-sided shadows and visibility")
            return
    var source_root := "res:" + "//assets/models/polyhaven/fern_02/"
    for file in ["fern_02_2k.gltf", "fern_02.bin",
        "textures/fern_02_diff_alpha_2k.png",
        "textures/fern_02_nor_gl_2k.jpg",
        "textures/fern_02_arm_2k.jpg", "SOURCE.json"]:
        if not FileAccess.file_exists(source_root + file):
            _fail("Original CC0 fern or audit/source texture absent: " + file)
            return
    var session := root.get_node_or_null("GameSession")
    if session == null:
        _fail("Save system was dropped by flora upgrade")
        return
    var seed := int(session.get("world_seed"))
    var signature := str(load("res://scripts/world_plan.gd").manifest_signature(session.call("get_world_manifest")))
    flora.call("generate")
    if flora.get_node_or_null("HorizonCommonsHeroFern") != pilot:
        _fail("Repeated generation moved or duplicated the original plant")
        return
    if int(session.get("world_seed")) != seed or str(load("res://scripts/world_plan.gd").manifest_signature(session.call("get_world_manifest"))) != signature:
        _fail("Visual fern changed world seed or save manifest")
        return
    print("HORIZON_FERN_SMOKE PASS: ", stats, " fixed seed=", seed)
    quit(0)
