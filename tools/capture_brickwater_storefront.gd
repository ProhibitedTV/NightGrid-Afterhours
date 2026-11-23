extends SceneTree
## Native before/after footage from the playable alley and the standard F8 recorder.
const GAME = preload("res://scenes/main.tscn")
const APPROACH = Vector3(-87.3, 1.06, 87.9)

var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var city: Node3D
var clock: Node
var output: String
var report := {}
var failures: Array[String] = []
var largest_step := 0.0

func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("NIGHTGRID_STOREFRONT_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		push_error("Use a native renderer and a fresh absolute capture directory")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	world = GAME.instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	world.get_node("HUD").hide()
	_capture_settings()
	player = world.get("player")
	camera = world.get("camera")
	clock = world.get("day_night")
	city = world.get("city_details")
	clock.set("paused", true)
	_place(APPROACH)
	await create_timer(2.0, true).timeout
	await _still("01-day-front", 12.0, Vector3(-85.4, 1.68, 84.0), Vector3(-89.5, 1.63, 86.15), 69.0)
	await _still("02-night-front", 22.1, Vector3(-85.4, 1.68, 84.0), Vector3(-89.5, 1.63, 86.15), 69.0)
	await _still("03-display", 22.1, Vector3(-87.1, 1.52, 80.4), Vector3(-89.6, 1.46, 81.15), 57.0)
	await _still("04-alley-approach", 19.15, Vector3(-86.8, 1.32, 75.1), Vector3(-89.05, 1.6, 89.2), 69.0)
	world.set_process(true)
	player.show()
	camera.fov = 70.0
	await _walk()
	if "--storefront-playtest" in OS.get_cmdline_user_args():
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		await _visit(false)
		await _visit(true)
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	report.merge({"revision":OS.get_environment("NIGHTGRID_SOURCE_REVISION"), "size":[root.size.x, root.size.y],
		"renderer":RenderingServer.get_current_rendering_method(), "adapter":RenderingServer.get_video_adapter_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(), "seed":root.get_node("GameSession").get("world_seed")})
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BRICKWATER_STOREFRONT_CAPTURE ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _capture_settings() -> void:
	world.call("_apply_game_settings", {"ssr_enabled":true, "ao_enabled":true,
		"glow_enabled":true, "fog_enabled":true, "vsync_enabled":false})
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

func _place(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	city.call("set_focus", at)
	world.set("yaw", PI * 0.5)
	world.set("pitch", 0.38)
	world.call("_snap_camera")

func _still(label: String, hour: float, at: Vector3, look: Vector3, lens: float) -> void:
	clock.call("set_hour", hour)
	world.set_process(false)
	player.hide()
	camera.global_position = at
	camera.look_at(look)
	camera.fov = lens
	for frame in range(18):
		await RenderingServer.frame_post_draw
	var name := label + ".png"
	if root.get_texture().get_image().save_png(output.path_join(name)) != OK:
		push_error("Could not save native viewport: " + name)
		quit(1)
		return
	report[label] = {"camera":str(at), "look":str(look), "hour":hour, "fov":lens,
		"sha256":FileAccess.get_sha256(output.path_join(name))}

func _walk() -> void:
	clock.call("set_hour", 22.1)
	_place(APPROACH)
	await create_timer(0.4, true).timeout
	var recorder: RefCounted = world.get("frame_time_recorder")
	var stream: Dictionary = city.call("get_streaming_stats")
	recorder.call("begin_capture", stream["loads"], stream["stage_steps"], stream["total_build_usec"])
	Input.action_press("move_forward", 0.58)
	for frame in range(110):
		await physics_frame
	Input.action_release("move_forward")
	recorder.call("end_capture")
	recorder.call("export_csv", output.path_join("matched-approach-f8.csv"))
	report["approach_end"] = str(player.global_position)

func _expect(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		push_error(reason)
	return ok

func _press(key: Key, button: JoyButton, controller: bool) -> void:
	var event: InputEvent
	if controller:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		event = pad
	else:
		var keyboard := InputEventKey.new()
		keyboard.physical_keycode = key
		event = keyboard
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _move(to_x: float, controller: bool) -> void:
	var inward := to_x < player.global_position.x
	var sign_value := -1.0 if inward else 1.0
	var event: InputEvent
	if controller:
		var pad := InputEventJoypadMotion.new()
		pad.axis = JOY_AXIS_LEFT_Y
		pad.axis_value = sign_value * 0.64
		event = pad
	else:
		var keyboard := InputEventKey.new()
		keyboard.physical_keycode = KEY_W if inward else KEY_S
		keyboard.pressed = true
		event = keyboard
	Input.parse_input_event(event)
	var previous := player.global_position
	for tick in range(160):
		await physics_frame
		largest_step = maxf(largest_step, previous.distance_to(player.global_position))
		previous = player.global_position
		if (player.global_position.x - to_x) * sign_value >= 0.0:
			break
	event = event.duplicate()
	if controller:
		event.axis_value = 0.0
	else:
		event.pressed = false
	Input.parse_input_event(event)
	for tick in range(10):
		await physics_frame

func _visit(controller: bool) -> void:
	var label := "controller" if controller else "keyboard"
	var hour := 12.0 if controller else 22.1
	clock.call("set_hour", hour)
	_place(APPROACH)
	var shop: Node3D = city.call("repair_storefront")
	if not _expect(shop != null, "Night Shift Repairs must stream at the original address"):
		return
	var hinge: Node3D = shop.get_node("ShopDoor")
	hinge.call("restore_open", false)
	await create_timer(0.3, true).timeout
	var recorder: RefCounted = world.get("frame_time_recorder")
	var stream: Dictionary = city.call("get_streaming_stats")
	recorder.call("begin_capture", stream["loads"], stream["stage_steps"], stream["total_build_usec"])
	largest_step = 0.0
	await _move(shop.global_position.x + 0.79, controller)
	_expect(bool(shop.call("door_reachable", player.global_position)), label + " must reach the hinge")
	var outside := player.global_position
	await _press(KEY_H, JOY_BUTTON_LEFT_SHOULDER, controller)
	await create_timer(0.7, true).timeout
	_expect(float(hinge.call("openness")) > 0.98, label + " must open the door with mapped input")
	await _move(shop.global_position.x - 3.0, controller)
	if not _expect(bool(shop.call("counter_reachable", player.global_position)), label + " must walk to the service counter"):
		return
	var inside := player.global_position
	var f8_step := largest_step
	recorder.call("end_capture")
	recorder.call("export_csv", output.path_join(label + "-enter-f8.csv"))
	await create_timer(0.65, true).timeout
	var audio: Dictionary = world.get_node("WorldAudio").call("get_audio_stats")
	_expect(audio["inside"] and float(audio["exterior_cutoff"]) < 5000.0, "The doorway must attenuate city audio")
	_expect(audio["surface"] == "CONCRETE", "The workshop slab must use concrete footsteps")
	var viewport := root.get_viewport_rid()
	var counter_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	var counter_render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport)
	_expect(not bool(world.get_node("Interiors").call("is_inside")), "Do not invoke the remote interior scene")
	var camera_local := shop.to_local(camera.global_position)
	_expect(camera_local.y < 3.10 and camera_local.x > -5.57, "The gameplay camera must stay below the ceiling and in front of the rear wall")
	var session := root.get_node("GameSession")
	var save_path := output.path_join(label + "-inside-v1.json")
	var snapshot: Dictionary = world.call("_capture_snapshot")
	_expect(bool(session.call("save_snapshot_to", snapshot, save_path)), "Write a v1 save inside the shop")
	var decoded: Dictionary = session.call("read_snapshot_from", save_path)
	_expect(not decoded.is_empty() and decoded.get("night_shift_door_open", false), "v1 snapshot preserves the open leaf")
	var saved_version: int = decoded.get("version", -1)
	var car: CharacterBody3D = world.get("cars")[0]
	car.global_position = Vector3(-86.8, 1.05, 72.4)
	car.set("condition", 44.0)
	world.set("cash", 60)
	var cash: int = world.get("cash")
	world.get_node("HUD").show()
	await _press(KEY_G, JOY_BUTTON_X, controller)
	var panel := world.get("venue_panel") as Control
	_expect(panel.visible, label + " must open the service menu")
	await _frame(label + "-counter")
	await _press(KEY_1, JOY_BUTTON_A, controller)
	var repaired_condition: float = car.get("condition")
	var service_cost: int = cash - int(world.get("cash"))
	_expect(repaired_condition >= 99.9 and service_cost == 24, label + " must perform the paid repair")
	await _press(KEY_G, JOY_BUTTON_B, controller)
	world.get_node("HUD").hide()
	# Reconstruct the scene exactly as the normal pending v1 restore does.
	session.set("pending_restore", decoded)
	world.queue_free()
	await process_frame
	world = GAME.instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	world.get_node("HUD").hide()
	_capture_settings()
	player = world.get("player")
	camera = world.get("camera")
	city = world.get("city_details")
	clock = world.get("day_night")
	clock.set("paused", true)
	shop = city.call("repair_storefront")
	if not _expect(shop != null and player.global_position.distance_to(inside) < 0.10, "Reload must restore the same physical position"):
		return
	hinge = shop.get_node("ShopDoor")
	_expect(float(hinge.call("openness")) > 0.98, "Reload must restore the open door")
	await _move(shop.global_position.x + 1.1, controller)
	_expect(not bool(shop.call("contains", player.global_position)), label + " must walk back into the alley")
	_expect(largest_step < 0.24, "No teleport during ordinary traversal")
	var exit_position := player.global_position
	# Revisit both sides. Diagnostic placement is outside the measured visit.
	player.global_position = shop.to_global(Vector3(0.73, 0.95, 0.0))
	player.velocity = Vector3.ZERO
	await _press(KEY_H, JOY_BUTTON_LEFT_SHOULDER, controller)
	await create_timer(0.75, true).timeout
	_expect(float(hinge.call("openness")) < 0.02, label + " must close the door from the alley")
	await _press(KEY_H, JOY_BUTTON_LEFT_SHOULDER, controller)
	await create_timer(0.75, true).timeout
	_expect(float(hinge.call("openness")) > 0.98, label + " must reopen the door on a second visit")
	report[label] = {"outside":str(outside), "inside":str(inside), "exit":str(exit_position),
		"largest_entry_physics_step_m":f8_step, "largest_traversal_physics_step_m":largest_step,
		"audio_cutoff_hz":audio["exterior_cutoff"], "camera_in_workshop":str(camera_local),
		"condition_after_service":repaired_condition, "repair_price":service_cost, "saved_version":saved_version,
		"counter_gpu_ms":counter_gpu, "counter_render_cpu_ms":counter_render_cpu}
	if controller:
		await _still("07-workbench", hour, shop.to_global(Vector3(-2.6, 1.68, -1.86)),
			shop.to_global(Vector3(-5.12, 1.43, -5.43)), 67.0)
		await _still("08-interior-to-door", 22.1, shop.to_global(Vector3(-4.3, 1.65, -2.68)),
			shop.to_global(Vector3(0.20, 1.26, 0.01)), 66.0)

func _frame(label: String) -> void:
	for i in range(12):
		await RenderingServer.frame_post_draw
	var path := output.path_join(label + ".png")
	if _expect(root.get_texture().get_image().save_png(path) == OK, "Save gameplay frame " + label):
		report[label] = {"sha256": FileAccess.get_sha256(path),
			"camera":str(camera.global_position), "hour":clock.get("hour"), "fov":camera.fov}
