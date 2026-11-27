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
const LIFT_VIEWS = [
	["suspended_directions", Vector3(2.15,1.68,-.95), Vector3(2.15,2.48,3.66), 0],
	["lift_landing", Vector3(-.52,1.70,2.85), Vector3(0,1.98,6.14), 0],
	["executive_glazing", Vector3(.15,Executive.BASE+1.65,-3.61), Vector3(4.55,Executive.BASE+1.38,-6.20), Executive.FLOOR],
	["car_02_in_transit", Vector3(-.52,1.70,2.85), Vector3(0,1.98,6.14), 0],
]
const ARCHITECTURE = [
	["hq_approach", Vector3(-2.1,1.73,-14.6), Vector3(.05,2.4,-9.90), 0],
	["visitor_lobby", Vector3(1.02,1.69,-9.23), Vector3(-2.60,2.05,-9.87), 0],
	["reception", Vector3(4.35,1.68,4.82), Vector3(5.2,2.06,9.84), 0],
	["reception_detail", Vector3(6.61,2.18,8.44), Vector3(5.25,2.55,9.79), 0],
	["lift_landing", Vector3(-.52,1.70,2.85), Vector3(0,1.98,6.14), 0],
	["breakroom", Vector3(-4.2, 1.67, 5.28), Vector3(-4.2, 1.63, 8.45), 0],
	["restrooms", Vector3(-5.75,2.0,-5.72), Vector3(-5.80,2.36,-3.27), 0],
	["department", Vector3(4.25,5.22,5.65), Vector3(4.90,5.60,9.82), 1],
	["it_service", Vector3(4.38,-1.9,5.27), Vector3(4.88,-1.24,9.84), -1],
	["executive_landing", Vector3(-4.25,Executive.BASE+1.68,5.53), Vector3(-4.9,Executive.BASE+1.98,9.81), Executive.FLOOR],
	["boardroom", Vector3(.28, Executive.BASE + 1.72, -2.6), Vector3(0, Executive.BASE + 1.02, -6.8), Executive.FLOOR],
	["founder_suite", Vector3(3.07,Executive.BASE+1.68,-4.02), Vector3(5.12,Executive.BASE+2.28,-9.88), Executive.FLOOR],
]
const LOBBY_ROUTE = [
	Vector3(.2,1.63,-9.45), Vector3(.2,1.63,-7.12), Vector3(2.1,1.63,-6.42),
	Vector3(2.1,1.63,-2.9), Vector3(2.1,1.63,1.0), Vector3(2.7,1.63,4.85),
	Vector3(4.25,1.63,5.36),
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
	var architecture := "--architecture" in args or "--reception" in args
	if architecture or "--lift" in args:
		for overlay in world.find_children("*", "CanvasLayer", true, false):
			overlay.hide()
	var camera := world.get("camera") as Camera3D
	camera.make_current()
	camera.fov = 64.0
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	if "--lobby-route" in args:
		office.call("_set_gate_open", true)
		await _lobby_route(out, office, camera, viewport)
		return
	var records := []
	var parked := "--parked" in args
	paused = parked
	var requested := EQUIPMENT if "--equipment" in args else SHOTS
	if architecture:
		requested = ARCHITECTURE.slice(0, 4) if "--reception" in args else ARCHITECTURE
	if "--boardroom" in args:
		requested = BOARDROOM
	if "--lift" in args:
		requested = LIFT_VIEWS
	for shot in requested:
		if shot.size() == 4:
			office.call("_select_floor", shot[3])
		camera.global_position = office.to_global(shot[1])
		camera.look_at(office.to_global(shot[2]))
		if shot[0] == "car_02_in_transit":
			player.global_position = office.to_global(Vector3(.90,1.15,5))
			if not office.call("try_lift", player) or not office.call("tick_lift", .75, player):
				_fail("Ground-to-B1 staged transfer did not reach its closed phase")
				return
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

func _lobby_route(out: String, office: Node3D, camera: Camera3D, viewport: RID) -> void:
	# Measure the same moving camera path twice in one process so the repeat
	# reuses the renderer and room resources first encountered on the cold pass.
	var rows := []
	for name in ["cold", "warm"]:
		var frames: Array[float] = []
		var gpu: Array[float] = []
		var cpu: Array[float] = []
		var unfocused := 0
		var start := Time.get_ticks_usec()
		var stamp := start
		while true:
			var distance := clampf((stamp - start) / 8_000_000.0, 0.0, 1.0) * (LOBBY_ROUTE.size() - 1)
			var leg := mini(floori(distance), LOBBY_ROUTE.size() - 2)
			var from: Vector3 = LOBBY_ROUTE[leg]
			var to: Vector3 = LOBBY_ROUTE[leg + 1]
			var at := from.lerp(to, distance - leg)
			camera.global_position = office.to_global(at)
			camera.look_at(office.to_global(at + (to - from).normalized().lerp(Vector3.FORWARD * -1, .72)))
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			frames.append(float(now - stamp) / 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
			unfocused += int(not root.has_focus())
			stamp = now
			if stamp - start >= 8_000_000:
				break
		frames.sort()
		gpu.sort()
		cpu.sort()
		var n := frames.size()
		var p95 := ceili(n * .95) - 1
		rows.append({"name":name, "samples":n, "unfocused":unfocused, "frame_p50_ms":frames[floori(n * .5)],
			"frame_p95_ms":frames[p95], "frame_p99_ms":frames[ceili(n * .99) - 1],
			"frame_worst_ms":frames[-1], "gpu_p95_ms":gpu[p95], "render_cpu_p95_ms":cpu[p95],
			"video_memory_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)})
	var report := FileAccess.open(out.path_join("route.json"), FileAccess.WRITE)
	if report == null:
		_fail("Could not write lobby route report")
		return
	report.store_string(JSON.stringify({"revision":OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"renderer":RenderingServer.get_current_rendering_method(), "driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(), "resolution":[root.size.x, root.size.y], "runs":rows}, "\t"))
	report.close()
	print("SYNAXIS_LOBBY_ROUTE PASS ", out)
	quit(0)
