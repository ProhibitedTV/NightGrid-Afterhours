extends SceneTree
## Real, unmodified framebuffer captures from the actual playable city.
const BLOCK = Vector2i(-2, 1)
const StreamProfile = preload("res://scripts/streaming_profile.gd")
var output: String
var world: Node3D
var camera: Camera3D
var records: Array[Dictionary] = []
var measure_native: bool = false
var walk_records: Array[Dictionary] = []
var profile_pass := ""
var profile_frames: Array[Dictionary] = []
var previous_draw_us := 0
var _traffic_reset: Dictionary = {}
var _signal_reset := 0.0

func _initialize() -> void:
	call_deferred("_capture")

func _fail(reason: String) -> void:
	push_error("BRICKWATER_CAPTURE: " + reason)
	quit(1)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Requires a graphical renderer, not headless")
		return
	output = OS.get_environment("NIGHTGRID_ALLEY_CAPTURE_DIR")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		_fail("Set NIGHTGRID_ALLEY_CAPTURE_DIR to a new absolute path")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Could not create capture directory")
		return
	create_timer(300.0, true, false, true).timeout.connect(func() -> void: _fail("Capture timed out"))
	measure_native = "--measure" in OS.get_cmdline_user_args()
	if measure_native:
		if RenderingServer.get_current_rendering_method() != "forward_plus":
			_fail("Frame timing mode requires Forward+; do not benchmark software compatibility captures")
			return
	StreamProfile.enabled = "--profile" in OS.get_cmdline_user_args()
	if StreamProfile.enabled:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		RenderingServer.frame_post_draw.connect(_profile_frame)
	var started := StreamProfile.begin()
	var scene := load("res://scenes/main.tscn") as PackedScene
	StreamProfile.end(started, "main_scene_resource_load")
	started = StreamProfile.begin()
	world = scene.instantiate()
	StreamProfile.end(started, "main_scene_instantiation")
	started = StreamProfile.begin()
	root.add_child(world)
	StreamProfile.end(started, "main_scene_activation")
	var live_traffic := "--live-traffic" in OS.get_cmdline_user_args()
	if live_traffic:
		_traffic_reset = world.get("traffic").call("snapshot")
		_signal_reset = float(world.get("signal_controller").get("elapsed"))
	await process_frame
	camera = world.get("camera")
	var hud := world.get_node_or_null("HUD") as CanvasLayer
	var menus := world.get_node_or_null("GameMenus")
	if camera == null or hud == null or menus == null:
		_fail("Actual gameplay camera/UI missing")
		return
	menus.call("hide_for_game")
	if measure_native:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_move_to_foreground()
	hud.visible = false
	var player := world.get("player") as CharacterBody3D
	var clock: Node = world.get("day_night")
	clock.set("paused",true)
	var block := BLOCK
	var origin := Vector3((float(block.x)+0.5)*58.0,0.0,(float(block.y)+0.5)*58.0)
	var city: Node3D = world.get("city_details")
	var scene_options := (world.get("world_environment") as WorldEnvironment).environment
	if "--ssr-off" in OS.get_cmdline_user_args():
		scene_options.ssr_enabled = false
	var settings := {"ssr": scene_options.ssr_enabled, "ambient_occlusion": scene_options.ssao_enabled,
		"fog": scene_options.fog_enabled, "glow": scene_options.glow_enabled,
		"vsync": DisplayServer.window_get_vsync_mode(), "physics_hz": Engine.physics_ticks_per_second}
	var arguments := OS.get_cmdline_user_args()
	if "--settled" in arguments:
		# Sample traversal after 60 rendered frames at the spawn camera.
		# The immediate-start run includes first-visible-frame costs.
		for frame in range(60):
			await RenderingServer.frame_post_draw
	if "--walk" in OS.get_cmdline_user_args():
		clock.call("set_hour", 22.1)
		for pass_name in ["first", "repeat"]:
			if not await _walk(city, player, origin, pass_name):
				return
	if "--drive-night" in arguments or "--drive-noon" in arguments:
		clock.call("set_hour", 21.5 if "--drive-night" in arguments else 12.0)
		# Keep the real roadway and vehicle/collision controllers. Disable the
		# ambient traffic process only for this reproducible lane-clear fixture.
		if not live_traffic:
			(world.get("traffic") as Node).process_mode = Node.PROCESS_MODE_DISABLED
		for pass_name in ["first", "repeat"]:
			if not await _drive(city, player, pass_name):
				return
	if StreamProfile.enabled:
		var profile := FileAccess.open(output.path_join("stream-profile.json"), FileAccess.WRITE)
		if profile == null:
			_fail("Could not save profiler evidence")
			return
		var session := root.get_node("GameSession")
		profile.store_string(JSON.stringify({"frames": profile_frames, "spans": StreamProfile.events,
			"runs": walk_records, "seed": session.get("world_seed"), "arguments": arguments,
			"resolution": [root.size.x, root.size.y], "settings": settings,
			"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
			"adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_driver_name()}))
		profile.close()
	if "--trace-only" in arguments:
		if "--drive-evidence" in arguments:
			if not await _snapshot_drive():
				return
		quit(0)
		return
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = origin + Vector3(0, 1.15, -9.5)
	player.velocity = Vector3.ZERO
	city.call("set_focus",origin)
	world.get("street_lights").call("set_focus",origin)
	world.get("venue_system").call("set_focus",origin)
	world.get("civic_services").call("set_focus",origin)
	await physics_frame
	await physics_frame
	# Use the same world coordinates on beta.7 and on the candidate.
	var left := -2.63
	var right := 3.05
	var middle := 0.20
	paused = true
	# Retain actual game render settings. Set only capture camera, clock,
	# and player visibility for a clean architecture inspection.
	player.hide()
	camera.make_current()
	camera.fov = 70.0

	var shots := [
		["01-alley-night-north.png",22.1,Vector3(middle,1.75,-10.6),Vector3(middle+0.15,2.6,6.5)],
		["02-alley-daylight-matched.png",12.0,Vector3(middle,1.75,-10.6),Vector3(middle+0.15,2.6,6.5)],
		["03-alley-night-south.png",22.1,Vector3(middle,1.75,7.2),Vector3(middle-0.2,2.6,-9.0)],
		["04-wet-ground-and-drain.png",22.1,Vector3(middle-0.45,0.85,-0.1),Vector3(right-0.32,0.21,-3.1)],
		["05-graffiti-and-service-front.png",22.1,Vector3(right-0.65,1.8,-5.5),Vector3(left+0.14,2.15,-3.6)],
		["06-overhead-infrastructure.png",22.1,Vector3(middle,1.85,-3.8),Vector3(middle,5.4,3.0)],
		["07-driving-height-approach.png",22.1,Vector3(middle,1.32,-12.3),Vector3(middle,1.7,7.0)],
		["08-workroom-detail.png",22.1,Vector3(right-0.50,1.7,-6.7),Vector3(left,1.55,-5.65)],
		["09-alley-dusk.png",19.15,Vector3(middle,1.75,-10.6),Vector3(middle+0.15,2.6,6.5)]
	]
	for shot in shots:
		var name: String = shot[0]
		var hour: float = shot[1]
		var at: Vector3 = shot[2]
		var look: Vector3 = shot[3]
		clock.call("set_hour",hour)
		world.get("venue_system").call("set_hour",hour)
		world.get("civic_services").call("set_hour",hour)
		camera.global_position = origin + at
		camera.look_at(origin + look, Vector3.UP)
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		if not _save(name, hour, origin + at, origin + look):
			return
		if measure_native and name.begins_with("01-"):
			var timing: Dictionary = await _measure_frames()
			records[records.size() - 1]["stationary_frame_timing"] = timing
	var manifest := FileAccess.open(output.path_join("camera-manifest.json"), FileAccess.WRITE)
	if manifest == null:
		_fail("Cannot write manifest")
		return
	manifest.store_string(JSON.stringify({
		"block": [block.x, block.y], "origin": [origin.x, origin.y, origin.z],
		"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter_api": RenderingServer.get_video_adapter_api_version(),
		"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"), "engine": Engine.get_version_info().get("string"),
		"settings": settings,
		"render_video_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"shots": records, "walk_traces": walk_records,
		"timing_note": "Viewport frame intervals, including CPU and GPU work. Walk traces use the same recorder as F8."
	}, "\t"))
	manifest.close()
	print("BRICKWATER_CAPTURE PASS: ", records.size(), " actual framebuffer images")
	quit(0)

func _walk(city: Node3D, player: CharacterBody3D, origin: Vector3, label: String) -> bool:
	# Drive the actual input action and keep gameplay physics, camera and
	# streaming active. A single position reset starts each matched pass.
	var start := origin + Vector3(0.20, 0.85, -13.5)
	var finish_z := origin.z + 31.0
	player.global_position = start
	player.velocity = Vector3.ZERO
	world.set("yaw", PI)
	world.set("pitch", 0.27)
	world.call("_update_camera", 0.0, true)
	for frame in range(4):
		await physics_frame
	var initial: Dictionary = city.call("get_streaming_stats")
	var recorder: RefCounted = world.get("frame_time_recorder")
	recorder.call("begin_capture", int(initial.get("loads", 0)), int(initial.get("stage_steps", 0)), int(initial.get("total_build_usec", 0)))
	profile_pass = "walk-" + label
	Input.action_press("move_forward")
	var deadline := Time.get_ticks_msec() + 40000
	while player.global_position.z < finish_z and Time.get_ticks_msec() < deadline:
		await process_frame
	Input.action_release("move_forward")
	profile_pass = ""
	recorder.call("end_capture")
	var filename := "walk-%s.csv" % label
	if str(recorder.call("export_csv", output.path_join(filename))).is_empty():
		_fail("Could not save live trace")
		return false
	walk_records.append({"file": filename, "frames": recorder.call("captured_frames"),
		"distance_z_m": player.global_position.z - start.z, "reached_end": player.global_position.z >= finish_z})
	return true

func _drive(city: Node3D, player: CharacterBody3D, label: String) -> bool:
	var car: CharacterBody3D = world.get("cars")[0]
	var start := Vector3(3.35, 0.65, 203.0)
	car.global_position = start
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	car.set("speed", 0.0)
	car.call("repair")
	if world.get("current_car") == null:
		player.global_position = start + Vector3.RIGHT * 2.8
		car.set_meta("claimed", true)
		world.call("_toggle_car")
	if world.get("current_car") != car:
		_fail("Could not enter the benchmark car")
		return false
	world.set("yaw", 0.0)
	world.call("_snap_camera")
	if not _traffic_reset.is_empty():
		world.get("traffic").call("restore", _traffic_reset)
		world.get("signal_controller").set("elapsed", _signal_reset)
	for frame in range(4):
		await physics_frame
	var initial: Dictionary = city.call("get_streaming_stats")
	var recorder: RefCounted = world.get("frame_time_recorder")
	recorder.call("begin_capture", int(initial["loads"]), int(initial["stage_steps"]), int(initial["total_build_usec"]))
	profile_pass = "drive-" + label
	Input.action_press("drive_accelerate")
	var road_speed := "--road-speed" in OS.get_cmdline_user_args()
	var accelerating := true
	var peak_kph := 0
	var districts: Array[String] = []
	var deadline := Time.get_ticks_msec() + (36000 if road_speed else 23000)
	while car.global_position.z > -24.0 and Time.get_ticks_msec() < deadline:
		await process_frame
		var z := car.global_position.z
		# Rotate through a full turn across the same 45 m on both revisions.
		world.set("yaw", TAU * clampf((155.0 - z) / 45.0, 0.0, 1.0))
		var speed := int(car.call("speed_kph"))
		peak_kph = maxi(peak_kph, speed)
		if road_speed and accelerating and speed >= 51:
			Input.action_release("drive_accelerate")
			accelerating = false
		elif road_speed and not accelerating and speed <= 46:
			Input.action_press("drive_accelerate")
			accelerating = true
		var district: String = city.call("get_district_at", car.global_position)
		if district not in districts:
			districts.append(district)
	Input.action_release("drive_accelerate")
	profile_pass = ""
	recorder.call("end_capture")
	var filename := "drive-%s.csv" % label
	if str(recorder.call("export_csv", output.path_join(filename))).is_empty():
		_fail("Could not save drive trace")
		return false
	walk_records.append({"file": filename, "frames": recorder.call("captured_frames"),
		"distance_z_m": start.z - car.global_position.z, "reached_end": car.global_position.z <= -24.0,
		"peak_kph": peak_kph, "districts": districts, "condition": car.get("condition"),
		"traffic":world.get("traffic").call("get_counts"),
		"pedestrians":world.get("pedestrians").call("stats") if is_instance_valid(world.get("pedestrians")) else {}})
	if car.global_position.z > -24.0 or peak_kph < (46 if road_speed else 125) or districts.size() < 3:
		_fail("Drive did not qualify: " + str(walk_records.back()))
		return false
	return true

func _snapshot_drive() -> bool:
	# Use the same native chase camera after the timed route, with no F8
	# readback work in the measured interval.
	var car := world.get("current_car") as CharacterBody3D
	car.set_physics_process(false)
	car.global_position = Vector3(3.35, 0.65, 134.0)
	car.rotation = Vector3.ZERO
	world.set("yaw", 0.0)
	world.set("pitch", 0.23)
	world.get("city_details").call("set_focus", car.global_position)
	var signals: Node = world.get("signal_controller")
	signals.set_process(false)
	signals.set("elapsed", 12.0)
	signals.call("_refresh")
	world.call("_snap_camera")
	world.set_process(false)
	for frame in range(16):
		await RenderingServer.frame_post_draw
	var at := camera.global_position
	var hour: float = world.get("day_night").get("hour")
	return _save("southworks-driver-view.png", hour, at, at - camera.global_basis.z * 20.0)

func _profile_frame() -> void:
	var now := Time.get_ticks_usec()
	var traced := StreamProfile.take_frame_totals()
	if not profile_pass.is_empty() and previous_draw_us > 0 and profile_frames.size() < StreamProfile.MAX_EVENTS:
		var viewport := root.get_viewport_rid()
		profile_frames.append({
			"pass": profile_pass, "frame": Engine.get_process_frames(), "end_us": now,
			"frame_ms": (now - previous_draw_us) / 1000.0,
			"focused": root.has_focus(),
			"render_setup_ms": RenderingServer.get_frame_setup_time_cpu(),
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport),
			"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport),
			"physics_process_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			"render_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"layers_usec": traced,
			"texture_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
			"mesh_pipelines": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
			"surface_pipelines": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
			"draw_pipelines": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			"specializations": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)
		})
	previous_draw_us = now

func _save(name: String, hour: float, at: Vector3, look: Vector3) -> bool:
	var pixels: Image = root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.get_width() < 1100 or pixels.get_height() < 600:
		_fail("Empty or small framebuffer: " + name)
		return false
	var colors := {}
	for ix in range(16):
		for iy in range(10):
			var color := pixels.get_pixel(int(float(ix)*(pixels.get_width()-1)/15.0),int(float(iy)*(pixels.get_height()-1)/9.0))
			colors[color.to_html(false)] = true
	if colors.size() < 12:
		_fail("Near-uniform framebuffer: " + name)
		return false
	var path := output.path_join(name)
	if pixels.save_png(path) != OK or FileAccess.get_file_as_bytes(path).size() < 16000:
		_fail("PNG write failed or suspiciously small: " + name)
		return false
	records.append({"file":name,"hour":hour,"camera":[at.x,at.y,at.z],"look":[look.x,look.y,look.z],"fov":camera.fov,"sha256":FileAccess.get_sha256(path),"resolution":[pixels.get_width(),pixels.get_height()]})
	print("ACTUAL_BRICKWATER_FRAME: ",path)
	return true

func _measure_frames() -> Dictionary:
	# Warm up before a separate interval sample. Do not include PNG encoding
	# or screenshot downloads. This is stationary rendering, not streaming.
	for frame in range(60):
		await process_frame
		await RenderingServer.frame_post_draw
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(180):
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append(float(now - previous) / 1000.0)
		previous = now
	times.sort()
	var total := 0.0
	for value in times:
		total += value
	return {"samples":times.size(),"mean_ms":total / float(times.size()),
		"p50_ms":times[89],"p95_ms":times[170],"p99_ms":times[178],
		"max_ms":times[179],"target_ms":1000.0 / 60.0,
		"vsync_mode":DisplayServer.window_get_vsync_mode()}
