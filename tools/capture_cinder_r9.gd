extends SceneTree
## Repeatable live Forward+ view of the actual Cinder R9 at Jade Wash.
const MARK = Vector3(-86.5, .825, 83.05)
const YAW = 0.0
const VIEWS = [
	["front-day", 13.4, Vector3(-2.24, .94, -5.48), Vector3(0, -.05, -.53), false, false, false],
	["front-night-dark", 21.5, Vector3(-1.63, .63, -5.78), Vector3(0, -.15, -.64), false, false, false],
	["front-night-live", 21.5, Vector3(-1.63, .63, -5.78), Vector3(0, -.15, -.64), true, false, false],
	["rear-night-live", 21.5, Vector3(1.30, .43, 5.42), Vector3(0, -.27, 1.01), true, true, false],
	["rear-night-reverse", 21.5, Vector3(1.30, .43, 5.42), Vector3(0, -.27, 1.01), true, false, true],
	["side-day-door", 13.4, Vector3(-2.10, 1.18, -3.20), Vector3(0, .01, .02), false, false, false],
]

func _initialize() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_review")

func _frames(count: int) -> void:
	for step in count:
		await RenderingServer.frame_post_draw

func _percentiles(samples: Array[float]) -> Dictionary:
	samples.sort()
	var last := samples.size() - 1
	return {"median": samples[roundi(last * .50)], "p95": samples[roundi(last * .95)],
		"p99": samples[roundi(last * .99)], "max": samples[last]}

func _sample() -> Dictionary:
	var frame: Array[float] = []
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var lost := 0
	var long_frames := 0
	var hitches := 0
	var rid := root.get_viewport_rid()
	var last := Time.get_ticks_usec()
	for index in 180:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var spacing := (now - last) / 1000.0
		last = now
		frame.append(spacing)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		lost += int(not root.has_focus())
		long_frames += int(spacing > 16.67)
		hitches += int(spacing > 33.3)
	return {"ms": _percentiles(frame), "gpu_ms": _percentiles(gpu), "render_cpu_ms": _percentiles(cpu),
		"unfocused": lost, "over_16_67": long_frames, "over_33_3": hitches, "samples": frame.size(),
		"draw_calls": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}

func _review() -> void:
	var output := OS.get_environment("NIGHTGRID_CINDER_R9_DIR")
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" \
			or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) \
			or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cinder R9 capture requires Forward+ and a new absolute output folder")
		quit(1)
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
	var environment: Environment = (game.get("world_environment") as WorldEnvironment).environment
	environment.ssr_enabled = true
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.fog_enabled = true
	var cars: Array = game.get("cars")
	var car: CharacterBody3D = cars[2]
	car.set_physics_process(false)
	car.global_position = MARK
	car.rotation.y = YAW
	var marker := Transform3D(Basis(Vector3.UP, YAW), MARK)
	for director in ["city_details", "street_lights", "venue_system", "civic_services"]:
		game.get(director).call("set_focus", MARK)
	var hero: Node3D = car.get("hero_visual")
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var records: Array[Dictionary] = []
	for view in VIEWS:
		clock.call("set_hour", view[1])
		clock.call("set_weather", "overcast")
		for node in ["venue_system", "civic_services"]:
			game.get(node).call("set_hour", view[1])
		camera.global_position = marker * view[2]
		var target: Vector3 = marker * view[3]
		camera.look_at(target, Vector3.UP)
		camera.fov = 49.0
		var brake_on: bool = view[5]
		var reverse_on: bool = view[6]
		hero.call("set_lighting_hour", view[1])
		RenderingServer.global_shader_parameter_set(&"cinder_surface_film", 0.0 if view[1] < 18.0 else 0.87)
		hero.call("update_motion", -2.0 if reverse_on else 0.0, 0.0, brake_on, view[4], 0.0, 0.87, 0.0)
		if view[0] == "side-day-door":
			if not car.call("toggle_near_door", car.to_global(Vector3(-1.6, .05, -.4)), player.get_rid()):
				push_error("Jade Wash driver's door could not open at the capture mark")
				quit(1)
				return
			hero.call("update_motion", 0.0, 0.0, false, false, 0.0, 0.0, .75)
		await create_timer(.9).timeout
		await _frames(30)
		var path := output.path_join(str(view[0]) + ".png")
		if root.get_texture().get_image().save_png(path) != OK:
			quit(1)
			return
		await _frames(20)
		var measurement := await _sample()
		measurement.merge({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "hour": view[1],
			"camera": str(camera.global_position), "look": str(target), "fov": camera.fov,
			"occupied": view[4], "brake": brake_on, "reverse": reverse_on})
		records.append(measurement)
		print("CINDER_R9_FRAME ", path.get_file())
	var log := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify({"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"seed": root.get_node("GameSession").get("world_seed"), "engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
		"settings": {"ssr": true, "ssao": true, "glow": true, "fog": true, "vsync": false},
		"mark": str(MARK), "captures": records}, "\t"))
	log.close()
	print("CINDER_R9_CAPTURE PASS")
	quit()
