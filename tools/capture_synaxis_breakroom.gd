extends SceneTree
## Matched captures of the real Synaxis rooms after streaming their permanent parcel.
const HQ = preload("res://scripts/synaxis_office.gd")
const Executive = preload("res://scripts/synaxis_executive_floor.gd")
const SHOTS = [
	["entrance", Vector3(-4.2, 1.67, 5.28), Vector3(-4.2, 1.48, 8.45)],
	["table", Vector3(-7.27, 1.82, 6.66), Vector3(-3.58, 1.32, 8.58)],
	["counter", Vector3(-6.05, 1.54, 7.29), Vector3(-7.98, 1.30, 8.40)],
	["reverse", Vector3(-2.26, 1.68, 9.36), Vector3(-6.82, 1.39, 7.48)],
]
const EQUIPMENT = [
	["lobby", Vector3(-.62, 1.62, -9.48), Vector3(-2.79, 1.12, -8.70), 0],
	["it", Vector3(-1.23, -1.9, -7.11), Vector3(-3.8, -2.20, -4.45), -1],
	["workstation", Vector3(-4.86, 5.18, -6.75), Vector3(-5.82, 4.81, -5.58), 1],
	["copier", Vector3(-6.25, 5.29, .27), Vector3(-7.70, 4.87, -.40), 1],
]
const BOARDROOM = [
	["boardroom", Vector3(.28, Executive.BASE + 1.72, -2.6), Vector3(0, Executive.BASE + 1.02, -6.8), Executive.FLOOR],
	["boardroom_veneer", Vector3(1.48, Executive.BASE + 1.68, -4.22), Vector3(-.12, Executive.BASE + .93, -5.8), Executive.FLOOR],
]
func _initialize() -> void:
	call_deferred("_run")
func _fail(error: String) -> void:
	push_error(error)
	quit(1)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 3 or DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Use Forward+ and pass a new absolute evidence directory")
		return
	var out := args[0]
	if not out.is_absolute_path() or DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK:
		_fail("Could not create new evidence directory")
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get("player") as CharacterBody3D
	var city := world.get("city_details") as Node3D
	player.global_position = HQ.ENTRY
	city.call("set_focus", HQ.ENTRY)
	var office: Node3D
	for attempt in 120:
		office = city.call("synaxis_headquarters")
		if office != null:
			break
		await physics_frame
	if office == null:
		_fail("Synaxis did not stream")
		return
	world.get_node("GameMenus").call("hide_for_game")
	(world.get_node("HUD") as CanvasLayer).hide()
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.hide()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	Engine.max_fps = 0
	var clock := world.get("day_night") as Node
	clock.set("paused", true)
	clock.call("set_hour", 17.0)
	office.call("begin_prologue")
	var camera := world.get("camera") as Camera3D
	camera.make_current()
	camera.fov = 64.0
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var records := []
	var parked := "--parked" in args
	paused = parked
	var requested := EQUIPMENT if "--equipment" in args else SHOTS
	if "--boardroom" in args:
		requested = BOARDROOM
	for shot in requested:
		if shot.size() == 4:
			office.call("_select_floor", shot[3])
		camera.global_position = office.to_global(shot[1])
		camera.look_at(office.to_global(shot[2]))
		for frame in 90:
			await RenderingServer.frame_post_draw
		var frames: Array[float] = []
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var worst := {}
		var unfocused := 0
		var stamp := Time.get_ticks_usec()
		for frame in 180:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			var interval := float(now - stamp) / 1000.0
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			var focused := root.has_focus()
			frames.append(interval)
			gpu.append(gpu_ms)
			cpu.append(cpu_ms)
			if interval > float(worst.get("frame_ms", 0)):
				worst = {"frame_ms": interval, "gpu_ms": gpu_ms, "render_cpu_ms": cpu_ms, "focused": focused}
			unfocused += int(not focused)
			stamp = now
		frames.sort()
		gpu.sort()
		cpu.sort()
		var image := root.get_texture().get_image()
		var filename: String = out.path_join(shot[0] + ".png")
		if image.get_size() != Vector2i(1920,1080) or image.save_png(filename) != OK:
			_fail("Unexpected viewport dimensions or PNG write failure")
			return
		records.append({"name": shot[0], "sha256": FileAccess.get_sha256(filename),
			"frame_p95_ms": frames[170], "frame_p99_ms": frames[178], "gpu_p95_ms": gpu[170],
			"cpu_p95_ms": cpu[170], "worst_frame": worst, "unfocused": unfocused, "samples": frames.size()})
	var report := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	if report == null:
		_fail("Could not write capture metadata")
		return
	report.store_string(JSON.stringify({"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"resolution": [root.size.x, root.size.y], "vsync": DisplayServer.window_get_vsync_mode(),
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "simulation_paused": parked, "hour": 17.0, "fov": camera.fov, "views": records}, "\t"))
	report.close()
	print("SYNAXIS_BREAKROOM_CAPTURE PASS ", out)
	quit(0)
