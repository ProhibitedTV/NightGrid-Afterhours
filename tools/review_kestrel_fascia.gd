extends SceneTree
## Review-only visual swap on one actual Kestrel. The default game stays stock.

const Candidate = preload("res://assets/models/nightgrid/kestrel_s6_front/fascia_lod0.gltf")
const Finish = preload("res://assets/models/nightgrid/kestrel_s6_front/crimson_finish.tres")
const MARK = Vector3(-86.54, .84, 83.4)
const VIEWS = [
	["day-3q", 13.4, "overcast", Vector3(-1.72, .95, -5.65), Vector3(.06, .23, -.25), 50.0],
	["night-3q", 22.1, "clear", Vector3(-1.72, .95, -5.65), Vector3(.06, .23, -.25), 50.0],
	["night-nose", 22.1, "clear", Vector3(-.32, .41, -4.55), Vector3(.0, .14, -1.64), 53.0],
]

func _initialize() -> void:
	create_timer(160.0, true, false, true).timeout.connect(func() -> void: quit(1))
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

func _without_front_cap(source: ArrayMesh) -> ArrayMesh:
	# Omit only the old planar nose fan in the review camera. Keep the rest
	# of the shell, including rear closure, so this is an interface check.
	var data := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	var source_indices: Variant = data[Mesh.ARRAY_INDEX]
	var indexed: bool = source_indices is PackedInt32Array and not source_indices.is_empty()
	var count: int = source_indices.size() if indexed else vertices.size()
	for i in range(0, count, 3):
		var a: int = source_indices[i] if indexed else i
		var b: int = source_indices[i + 1] if indexed else i + 1
		var c: int = source_indices[i + 2] if indexed else i + 2
		if is_equal_approx(vertices[a].z, -2.31) and is_equal_approx(vertices[b].z, -2.31) \
				and is_equal_approx(vertices[c].z, -2.31):
			continue
		indices.append_array(PackedInt32Array([a, b, c]))
	assert(count - indices.size() == 24)
	data[Mesh.ARRAY_INDEX] = indices
	var clipped := ArrayMesh.new()
	clipped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return clipped

func _review() -> void:
	var output := OS.get_environment("NIGHTGRID_KESTREL_REVIEW_DIR")
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" \
			or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) \
			or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Kestrel review requires Forward+ and a new absolute output folder")
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
	car.rotation.y = 0.0
	for director in ["city_details", "street_lights", "venue_system", "civic_services"]:
		game.get(director).call("set_focus", MARK)
	var hero := car.get_node("KestrelS6HeroVisual") as Node3D
	var old_shell := hero.get_node("KestrelMonocoque") as MeshInstance3D
	var original := old_shell.mesh as ArrayMesh
	var fitted := _without_front_cap(original)
	var candidate := Candidate.instantiate() as Node3D
	hero.add_child(candidate)
	var cover := candidate.get_node("BumperCover") as MeshInstance3D
	var paint_surface := -1
	for index in cover.mesh.get_surface_count():
		if cover.mesh.surface_get_material(index).resource_name.contains("Crimson"):
			paint_surface = index
	if paint_surface < 0 or not Finish.clearcoat_enabled or not Finish.normal_enabled:
		push_error("The imported cover must provide its mapped basecoat")
		quit(1)
		return
	cover.set_surface_override_material(paint_surface, Finish)
	for part in hero.find_children("*", "MeshInstance3D", true, false):
		var material := (part as MeshInstance3D).material_override as StandardMaterial3D
		if material != null and material.clearcoat_enabled:
			material.albedo_color = Finish.albedo_color
	var splitter := hero.get_node("FrontSplitter") as MeshInstance3D
	var sensor := hero.get_node("ForwardServiceSensor") as MeshInstance3D
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var results: Array[Dictionary] = []
	for view in VIEWS:
		clock.call("set_hour", view[1])
		clock.call("set_weather", view[2])
		for system in ["venue_system", "civic_services"]:
			game.get(system).call("set_hour", view[1])
		camera.global_position = MARK + view[3]
		camera.look_at(MARK + view[4], Vector3.UP)
		camera.fov = view[5]
		for mode in ["stock", "candidate"]:
			var active: bool = mode == "candidate"
			candidate.visible = active
			splitter.visible = not active
			sensor.visible = not active
			old_shell.mesh = fitted if active else original
			await create_timer(.8).timeout
			await _frames(36)
			var path := output.path_join("%s-%s.png" % [view[0], mode])
			if root.get_texture().get_image().save_png(path) != OK:
				quit(1)
				return
			await _frames(20)
			var measurement := await _sample()
			measurement.merge({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "hour": view[1],
				"sky": clock.call("active_sky_preset"), "camera": str(camera.global_position), "look": str(MARK + view[4]),
				"weather_preset": view[2], "fov": camera.fov, "component": mode})
			results.append(measurement)
			print("KESTREL_FASCIA_FRAME ", path.get_file())
	var log := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify({"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"seed": root.get_node("GameSession").get("world_seed"), "engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y],
		"settings": {"ssr": true, "ssao": true, "glow": true, "fog": true, "vsync": false},
		"car_position": str(MARK), "captures": results}, "\t"))
	log.close()
	print("KESTREL_FASCIA_NATIVE PASS")
	quit()
