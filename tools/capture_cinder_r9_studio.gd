extends SceneTree
## Authentic Godot Forward+ vehicle studio for CPU-Vulkan CI.
##
## Uses the same RoadCarVisual, glTF imports, materials, lights, steering rig and
## wheels as gameplay. This is a studio capture, NOT a city-driving screenshot,
## native GPU benchmark, or artistic-quality certification.

const R9_VISUAL = preload("res://scripts/road_car_visual.gd")
const VIEWS = [
    ["front-day", 13.4, Vector3(-3.5, 1.38, -5.1), Vector3(0, -.14, -.30), 0.0],
    ["headlight-day-detail", 13.4, Vector3(-1.92, .38, -3.00), Vector3(-.65, -.30, -2.15), 0.0],
    ["headlight-night-detail", 21.5, Vector3(-1.92, .38, -3.00), Vector3(-.65, -.30, -2.15), 0.0],
    ["wheel-steer-right-day-detail", 13.4, Vector3(-2.18, -.07, -2.18), Vector3(-.85, -.48, -1.43), .80],
    ["wheel-steer-left-day-detail", 13.4, Vector3(-2.18, -.07, -2.18), Vector3(-.85, -.48, -1.43), -.80],
]

func _initialize() -> void:
    create_timer(170.0, true, false, true).timeout.connect(func() -> void: quit(1))
    call_deferred("_capture")

func _fail(message: String) -> void:
    push_error("CINDER_R9_STUDIO_CAPTURE: " + message)
    quit(1)

func _capture() -> void:
    var directory := OS.get_environment("NIGHTGRID_CINDER_R9_DIR")
    if DisplayServer.get_name() == "headless":
        _fail("A real display/rendering device is required")
        return
    if RenderingServer.get_current_rendering_method() != "forward_plus":
        _fail("This fixture must use actual Godot Forward+ with Vulkan")
        return
    if not directory.is_absolute_path() or DirAccess.dir_exists_absolute(directory) \
            or DirAccess.make_dir_recursive_absolute(directory) != OK:
        _fail("Output must be a new absolute directory")
        return

    var stage := Node3D.new()
    stage.name = "CinderOriginalAssetStudio"
    root.add_child(stage)
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("181d26")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("8792a3")
    environment.ambient_light_energy = 0.85
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    # Godot owns the current Forward+ tone mapping; Environment has no
    # 'tone_mapper' property. Using it aborted the first studio run.
    world_environment.environment = environment
    stage.add_child(world_environment)

    var floor := MeshInstance3D.new()
    floor.name = "UntexturedStudioFloor"
    var plane := PlaneMesh.new()
    plane.size = Vector2(14., 14.)
    floor.mesh = plane
    floor.position.y = -.835
    var matte := StandardMaterial3D.new()
    matte.albedo_color = Color("555e6a")
    matte.roughness = .59
    floor.material_override = matte
    stage.add_child(floor)

    var key := DirectionalLight3D.new()
    key.name = "StudioLargeKey"
    key.light_color = Color("fff1e0")
    key.light_energy = 1.2
    key.shadow_enabled = true
    stage.add_child(key)
    key.position = Vector3(-3.5, 5., -4.)
    key.look_at(Vector3.ZERO, Vector3.UP)
    var fill := DirectionalLight3D.new()
    fill.name = "StudioSoftFill"
    fill.light_color = Color("a9c7eb")
    fill.light_energy = .43
    stage.add_child(fill)
    fill.position = Vector3(4.4, 4.0, 4.0)
    fill.look_at(Vector3.ZERO, Vector3.UP)

    var visual := R9_VISUAL.new() as Node3D
    visual.name = "ActualCinderR9Visual"
    visual.call("configure", Color("9c2338"))
    stage.add_child(visual)
    var camera := Camera3D.new()
    camera.name = "FixedReviewCamera"
    camera.near = .05
    camera.far = 150.
    stage.add_child(camera)
    camera.make_current()
    Engine.max_fps = 0
    RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), false)

    var captures: Array[Dictionary] = []
    for view in VIEWS:
        var label: String = view[0]
        var night := float(view[1]) >= 18.0
        environment.ambient_light_energy = .34 if night else .85
        key.light_energy = .18 if night else 1.2
        fill.light_energy = .18 if night else .43
        visual.call("set_lighting_hour", view[1])
        var steer_input: float = view[4]
        visual.call("update_motion", 0.0, steer_input, false, true, 0.0, 0.0, .5)
        var state: Dictionary = visual.call("get_motion_state")
        var left := float(state["steering_left"])
        var right := float(state["steering_right"])
        if steer_input > 0.0 and not (right < left and left < 0.0):
            _fail("Right turn does not match actual Ackermann steering")
            return
        if steer_input < 0.0 and not (left > right and right > 0.0):
            _fail("Left turn does not match actual Ackermann steering")
            return
        camera.position = view[2]
        camera.look_at(view[3], Vector3.UP)
        camera.fov = 37.0 if label.ends_with("detail") else 48.0
        await create_timer(.08).timeout
        for index in 3:
            await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        if image == null or image.is_empty():
            _fail("Godot returned an empty viewport image")
            return
        var file := directory.path_join(label + ".png")
        if image.save_png(file) != OK:
            _fail("Could not save rendered image: " + label)
            return
        var info: Dictionary = {
            "file": file.get_file(),
            "sha256": FileAccess.get_sha256(file),
            "hour": view[1],
            "camera": str(camera.global_position),
            "look": str(view[3]),
            "front_left_steer_radians": left,
            "front_right_steer_radians": right,
            "visual_steering_input": steer_input,
            "capture_type": "actual Godot Forward+ Cinder vehicle rig in isolated studio; NOT city gameplay",
            "performance_comparable_to_native_gpu": false
        }
        captures.append(info)
        print("CINDER_R9_FRAME ", file.get_file())

    var file := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
    if file == null:
        _fail("Unable to create provenance manifest")
        return
    file.store_string(JSON.stringify({
        "revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
        "engine": Engine.get_version_info()["string"],
        "renderer": RenderingServer.get_current_rendering_method(),
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "adapter": RenderingServer.get_video_adapter_name(),
        "resolution": [root.size.x, root.size.y],
        "capture_mode": "ci_mesa_software_vulkan",
        "quality_stage": "native Godot vehicle studio, original asset; not gameplay capture",
        "performance_comparable_to_native_gpu": false,
        "captures": captures
    }, "\t"))
    file.close()
    print("CINDER_R9_CAPTURE PASS")
    quit()
