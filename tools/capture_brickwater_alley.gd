extends SceneTree
## Real, unmodified framebuffer captures from the actual playable city.
const ALLEY = preload("res://scripts/brickwater_alley.gd")
const DIR = "res:" + "//exports/brickwater_review" # runtime output, not an imported resource
var world: Node3D
var camera: Camera3D
var records: Array[Dictionary] = []
var measure_native: bool = false

func _initialize() -> void:
	call_deferred("_capture")

func _fail(reason: String) -> void:
	push_error("BRICKWATER_CAPTURE: " + reason)
	quit(1)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Requires a graphical renderer, not headless")
		return
	measure_native = "--measure" in OS.get_cmdline_user_args()
	if measure_native:
		if RenderingServer.get_current_rendering_method() != "forward_plus":
			_fail("Frame timing mode requires Forward+; do not benchmark software compatibility captures")
			return
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	camera = world.get("camera")
	var hud := world.get_node_or_null("HUD") as CanvasLayer
	var menus := world.get_node_or_null("GameMenus")
	if camera == null or hud == null or menus == null:
		_fail("Actual gameplay camera/UI missing")
		return
	menus.call("hide_for_game")
	hud.visible = false
	world.set_process(false)
	var player := world.get("player") as CharacterBody3D
	player.set_physics_process(false)
	var clock: Node = world.get("day_night")
	clock.set("paused",true)
	var block := ALLEY.PILOT_BLOCK
	var origin := Vector3((float(block.x)+0.5)*58.0,0.0,(float(block.y)+0.5)*58.0)
	var city: Node3D = world.get("city_details")
	player.global_position = origin + Vector3(0, 1.15, -9.5)
	player.velocity = Vector3.ZERO
	city.call("set_focus",origin)
	world.get("street_lights").call("set_focus",origin)
	world.get("venue_system").call("set_focus",origin)
	world.get("civic_services").call("set_focus",origin)
	await physics_frame
	await physics_frame
	var chunk := (city.get("_loaded") as Dictionary).get(block) as Node3D
	var alley: Node3D = null
	if chunk != null:
		alley = chunk.get_node_or_null("BrickwaterServiceAlley") as Node3D
	if alley == null or alley.get_node_or_null("BusinessFrontage") == null:
		_fail("Revamped permanent alley isn't loaded")
		return
	var left := float(alley.get("left_wall"))
	var right := float(alley.get("right_wall"))
	var middle := (left + right) * 0.5
	# Retain actual game render settings. Set only capture camera, clock,
	# and player visibility for a clean architecture inspection.
	player.hide()
	camera.make_current()
	camera.fov = 70.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var shots := [
		["01-alley-night-north.png",22.1,Vector3(middle,1.75,-10.6),Vector3(middle+0.15,2.6,6.5)],
		["02-alley-daylight-matched.png",12.0,Vector3(middle,1.75,-10.6),Vector3(middle+0.15,2.6,6.5)],
		["03-alley-night-south.png",22.1,Vector3(middle,1.75,7.2),Vector3(middle-0.2,2.6,-9.0)],
		["04-wet-ground-and-drain.png",22.1,Vector3(middle-0.45,0.85,-0.1),Vector3(right-0.32,0.21,-3.1)],
		["05-graffiti-and-service-front.png",22.1,Vector3(right-0.65,1.8,-5.5),Vector3(left+0.14,2.15,-3.6)],
		["06-overhead-infrastructure.png",22.1,Vector3(middle,1.85,-3.8),Vector3(middle,5.4,3.0)],
		["07-driving-height-approach.png",22.1,Vector3(middle,1.32,-12.3),Vector3(middle,1.7,7.0)]
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
		if measure_native:
			var timing: Dictionary = await _measure_frames()
			records[records.size() - 1]["stationary_frame_timing"] = timing
	var manifest := FileAccess.open(DIR + "/camera-manifest.json", FileAccess.WRITE)
	if manifest == null:
		_fail("Cannot write manifest")
		return
	manifest.store_string(JSON.stringify({"block":[block.x,block.y],"origin":[origin.x,origin.y,origin.z],"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().get("string"),"shots":records,"timing_note":"Optional stationary viewport frame intervals; no moving gameplay, no screenshot readback in timing window; not GPU-only timings."}, "\t"))
	manifest.close()
	print("BRICKWATER_CAPTURE PASS: ", records.size(), " actual framebuffer images")
	quit(0)

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
	var path := DIR + "/" + name
	if pixels.save_png(path) != OK or FileAccess.get_file_as_bytes(path).size() < 16000:
		_fail("PNG write failed or suspiciously small: " + name)
		return false
	records.append({"file":name,"hour":hour,"camera":[at.x,at.y,at.z],"look":[look.x,look.y,look.z],"fov":camera.fov,"resolution":[pixels.get_width(),pixels.get_height()]})
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
