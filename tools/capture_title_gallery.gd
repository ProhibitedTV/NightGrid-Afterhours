extends SceneTree
## Real title-screen framebuffer evidence. No compositing or replacement art.
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_capture")

func _fail(reason: String) -> void:
	push_error("TITLE_CAPTURE: " + reason)
	quit(1)

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("A graphical renderer is required")
		return
	var output := OS.get_environment("NIGHTGRID_TITLE_CAPTURE_DIR")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		_fail("Set NIGHTGRID_TITLE_CAPTURE_DIR to a new absolute directory")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create capture output")
		return
	create_timer(900.0, true, false, true).timeout.connect(func() -> void: _fail("Capture timed out"))
	var session := root.get_node("GameSession")
	session.set("boot_menu_shown", true)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var menu: Node = world.get_node("GameMenus")
	var clock: Node = world.get("day_night")
	# Software Vulkan can be much slower than a gaming GPU. This explicit
	# capture-only option reduces convolution resolution, not artwork.
	var sky := clock.get("_panorama_resource") as Sky
	var low_radiance := "--software-capture" in OS.get_cmdline_user_args()
	if low_radiance and sky != null:
		sky.radiance_size = Sky.RADIANCE_SIZE_32
	menu.get("settings")["title_motion"] = false
	menu.call("open_title")
	var preview: Node = menu.get("_title_view")
	if preview == null or not bool(preview.get("active")) or world.get_node_or_null("TitleCinderR9") == null:
		_fail("Actual live alley title or R9 unavailable; do not capture fallback art")
		return
	var shots: Array[Dictionary] = [
		{"file":"01-title-night.png","hour":22.1,"phase":0.0},
		{"file":"02-title-dawn.png","hour":6.5,"phase":0.0},
		{"file":"03-title-day.png","hour":12.5,"phase":0.0},
		{"file":"04-title-neon-dip.png","hour":22.1,"phase":9.825}
	]
	for shot in shots:
		preview.call("_set_visual_hour", float(shot["hour"]))
		var faults: RefCounted = preview.get("_neon")
		faults.call("apply", float(shot["phase"]), 1.0 - float(clock.call("daylight_amount")), true)
		for frame in range(5):
			await process_frame
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			_fail("Empty framebuffer")
			return
		var unique := {}
		for x in range(20):
			for y in range(12):
				unique[image.get_pixel(int(x * (image.get_width()-1)/19.0), int(y * (image.get_height()-1)/11.0)).to_html(false)] = true
		if unique.size() < 20:
			_fail("Nearly blank title framebuffer")
			return
		var filename: String = shot["file"]
		var path := output.path_join(filename)
		if image.save_png(path) != OK:
			_fail("Cannot save " + filename)
			return
		records.append({"file":filename,"hour":shot["hour"],"fault_phase":shot["phase"],"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size(),"width":image.get_width(),"height":image.get_height()})
		print("TITLE_CAPTURE FRAME: ", filename)
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save provenance")
		return
	var env: WorldEnvironment = world.get("world_environment")
	file.store_string(JSON.stringify({"source_revision":OS.get_environment("NIGHTGRID_SOURCE_REVISION"),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().get("string"),"volumetric_fog":env.environment.volumetric_fog_enabled,"capture_only_low_radiance":low_radiance,"shots":records}, "\t"))
	file.close()
	menu.call("hide_for_game")
	print("TITLE_CAPTURE PASS: 4 real title framebuffers")
	quit(0)
