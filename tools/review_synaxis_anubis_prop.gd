extends SceneTree

const HQ = preload("res://scripts/synaxis_office.gd")
const Services = preload("res://scripts/synaxis_office_services.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_environment("NIGHTGRID_SYNAXIS_REVIEW")
	if not out.is_absolute_path() or DirAccess.dir_exists_absolute(out) or DirAccess.make_dir_recursive_absolute(out) != OK:
		push_error("Expected a new review directory")
		quit(1)
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get("player") as CharacterBody3D
	var city := world.get("city_details") as Node3D
	player.global_position = HQ.ENTRY
	city.call("set_focus", HQ.ENTRY)
	var hq: Node3D
	for i in 120:
		hq = city.call("synaxis_headquarters")
		if hq != null:
			break
		await physics_frame
	if hq == null:
		push_error("Actual Synaxis parcel did not stream")
		quit(1)
		return
	world.get_node("GameMenus").call("hide_for_game")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	(world.get_node("HUD") as CanvasLayer).hide()
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.hide()
	var clock: Node = world.get("day_night")
	clock.set("paused", true)
	clock.call("set_hour", 12.0)
	hq.call("_ensure_workfloors")
	hq.call("_select_floor", 1)
	var floor_node := hq.get_node("Workfloor1") as Node3D
	var service := floor_node.get_node("OfficeServices") as Node3D
	var service_actor := floor_node.get_node("DepartmentStaff")
	service_actor.call("set_active", false)
	service.call("set_active", true)
	var printer := service.get_node("PrinterBody") as MeshInstance3D
	var review_on := OS.has_environment("NIGHTGRID_ANUBIS_REVIEW_PROPS")
	if (printer.mesh is BoxMesh) == review_on:
		push_error("The expected printer mesh did not load")
		quit(1)
		return
	var camera := world.get("camera") as Camera3D
	camera.make_current()
	camera.fov = 57.0
	camera.global_position = floor_node.to_global(Vector3(-6.28, 1.64, 0.34))
	camera.look_at(floor_node.to_global(Vector3(-7.68, 1.22, -.4)))
	paused = true
	for i in 24:
		await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out.path_join("printer.png"))
	if error != OK:
		push_error("Could not save printer frame")
		quit(1)
		return
	var frame_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 180:
		await RenderingServer.frame_post_draw
		var current := Time.get_ticks_usec()
		frame_ms.append(float(current-last)/1000.0)
		last = current
	frame_ms.sort()
	paused = false
	var interaction_point := service.to_global(Services.PRINTER_USE)
	var printed_before := int(service.call("stats")["printed"])
	var accepted := bool(service.call("interact", interaction_point))
	service.call("_process", 3.1)
	var printed_once := int(service.call("stats")["printed"]) == printed_before + 1
	var report := {"baseline": not review_on, "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"resolution": [root.size.x, root.size.y], "vsync": DisplayServer.window_get_vsync_mode(), "p95_ms": frame_ms[170], "p99_ms": frame_ms[178],
		"printer_accepted": accepted, "printed_once": printed_once}
	var file := FileAccess.open(out.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SYNAXIS_PROP_REVIEW ", JSON.stringify(report))
	quit(0 if accepted and printed_once else 1)
