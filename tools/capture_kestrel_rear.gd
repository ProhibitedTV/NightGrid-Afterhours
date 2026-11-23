extends SceneTree
## Repeatable parked rear orbit of the production vehicle at South Bus Works.
const MARK = Vector3(86.7, .84, 177.55)
const YAW = -PI * .5
const VIEWS = [
	["rear-day", 13.4, Vector3(-2.74, .84, 5.76), Vector3(0, .28, 1.20)],
	["rear-night", 21.5, Vector3(-2.74, .84, 5.76), Vector3(0, .28, 1.20)],
	["rear-high", 13.4, Vector3(2.85, 3.35, 5.46), Vector3(0, .18, 1.24)],
	["rear-low", 21.5, Vector3(.0, -.23, 5.37), Vector3(0, .21, 1.99)],
	["quarter-day", 13.4, Vector3(-5.49, .65, 1.38), Vector3(0, .21, .24)],
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
	var output := OS.get_environment("NIGHTGRID_KESTREL_REAR_DIR")
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" \
			or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) \
			or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Kestrel rear capture requires Forward+ and a new absolute output folder")
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
	var car: CharacterBody3D = cars[0]
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
		clock.call("set_weather", "clear")
		for node in ["venue_system", "civic_services"]:
			game.get(node).call("set_hour", view[1])
		camera.global_position = marker * view[2]
		var target: Vector3 = marker * view[3]
		camera.look_at(target, Vector3.UP)
		camera.fov = 49.0
		var brake_on: bool = view[0] == "rear-night"
		var reverse_on: bool = view[0] == "rear-low"
		hero.call("update_motion", -2.0 if reverse_on else 0.0, 0.0, brake_on, false, false, 0.0)
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
			"brake": brake_on, "reverse": reverse_on})
		records.append(measurement)
		print("KESTREL_REAR_FRAME ", path.get_file())
	var log := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify({"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"seed": root.get_node("GameSession").get("world_seed"), "engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
		"settings": {"ssr": true, "ssao": true, "glow": true, "fog": true, "vsync": false},
		"mark": str(MARK), "captures": records}, "\t"))
	log.close()
	print("KESTREL_REAR_CAPTURE PASS")
	quit()
