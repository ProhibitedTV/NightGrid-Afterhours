extends SceneTree
## Actual game framebuffer from the new cockpit camera in the original city.
## Frozen review poses, not a live-driving benchmark or external render.
const MARK = Vector3(-86.5, .825, 83.05)
const VIEWS = [
	["01-cockpit-day.png", 13.4, "clear", 0.0, Vector2.ZERO],
	["02-cockpit-night.png", 21.5, "clear", .75, Vector2(0.12, .06)],
	["03-cockpit-rain.png", 21.5, "rain", -.75, Vector2(-.12, .06)]
]

func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_capture")

func _fail(message: String) -> void:
	push_error("COCKPIT_CAPTURE: " + message)
	quit(1)

func _capture() -> void:
	var output := OS.get_environment("NIGHTGRID_COCKPIT_DIR")
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" \
			or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) \
			or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Requires real Forward+ framebuffer and new absolute directory")
		return
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	game.get_node("GameMenus").call("hide_for_game")
	game.get_node("HUD").hide()
	game.set_process(false)
	game.set_physics_process(false)
	var player: CharacterBody3D = game.get("player")
	player.set_physics_process(false)
	player.hide()
	var clock: Node = game.get("day_night")
	clock.set_process(false)
	var camera: Camera3D = game.get("camera")
	var cars: Array = game.get("cars")
	var car: CharacterBody3D = cars[2]
	car.set_physics_process(false)
	car.global_position = MARK
	car.rotation.y = 0.0
	for director in ["city_details", "street_lights", "venue_system", "civic_services"]:
		game.get(director).call("set_focus", MARK)
	player.global_position = car.to_global(Vector3(-1.6, .1, -.4))
	player.set("driving", true)
	player.collision_layer = 0
	player.collision_mask = 0
	player.call("show_vehicle_rider", car, false)
	car.set("occupied", true)
	game.set("current_car", car)
	game.call("_toggle_cinder_view")
	var hero: Node3D = car.get("hero_visual")
	if hero.get_node_or_null("Coachwork/SteeringWheel") == null or hero.get_node_or_null("Coachwork/LiveInstrumentCluster") == null:
		_fail("Missing articulated steering or instrument geometry")
		return
	var cluster := hero.get_node("Coachwork/LiveInstrumentCluster")
	var shots: Array[Dictionary] = []
	for view in VIEWS:
		var hour: float = view[1]
		var steer: float = view[3]
		clock.call("set_hour", hour)
		clock.call("set_weather", view[2])
		for director in ["venue_system", "civic_services"]:
			game.get(director).call("set_hour", hour)
		RenderingServer.global_shader_parameter_set(&"cinder_surface_film", .8 if view[2] == "rain" else 0.0)
		hero.call("close_doors_immediate")
		hero.call("set_lighting_hour", hour)
		hero.call("update_motion", 0.0, steer, false, true, 0.0, .8 if view[2] == "rain" else 0.0, .6)
		game.set("_cockpit_look", view[4])
		game.call("_update_camera", 0.0, true)
		if not is_equal_approx(camera.fov, 78.0) or not cluster.call("get_display_state")["active"]:
			_fail("Actual gameplay camera or live dashboard inactive")
			return
		await create_timer(.1).timeout
		for frame in 4:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := output.path_join(view[0])
		if image == null or image.is_empty() or image.save_png(path) != OK:
			_fail("Unable to save real framebuffer")
			return
		shots.append({"file": view[0], "sha256": FileAccess.get_sha256(path),
			"hour": hour, "weather": view[2], "steering_input": steer,
			"camera_position": str(camera.global_position), "camera_basis": str(camera.global_basis),
			"fov": camera.fov, "dashboard": cluster.call("get_display_state")})
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		_fail("Missing manifest")
		return
	manifest.store_string(JSON.stringify({"source_revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"engine": Engine.get_version_info()["string"], "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
		"capture_type": "actual gameplay scene, parked review poses; software Vulkan, not GPU benchmark",
		"shots": shots}, "\t"))
	manifest.close()
	print("COCKPIT_CAPTURE PASS: 3")
	quit()
