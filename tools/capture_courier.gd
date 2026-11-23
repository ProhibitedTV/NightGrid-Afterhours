extends SceneTree
## Capture the player in the real city with identical views on each revision.

const ANCHOR = Vector3(-87.0, 1.30, 82.0)
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var output: String
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	output = OS.get_environment("NIGHTGRID_COURIER_CAPTURE_DIR")
	var recording := "--showcase" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or (not recording and
			(not output.is_absolute_path() or DirAccess.dir_exists_absolute(output))):
		push_error("Capture requires a graphical renderer and a new absolute output path")
		quit(1)
		return
	if not recording and DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	player = world.get("player")
	camera = world.get("camera")
	var clock: Node = world.get("day_night")
	clock.set("paused", true)
	if recording:
		await _showcase(clock)
		return
	world.get_node("HUD").hide()
	world.set_process(false)
	world.get("city_details").call("set_focus", ANCHOR)
	player.global_position = ANCHOR
	for i in range(36):
		await physics_frame
	var actor: Node3D = player.get_node("Visual")
	actor.rotation.y = 0.0
	var feet := player.global_position - Vector3.UP * 0.95
	var views := [
		["day-front", Vector3(-0.65, 1.41, 3.45), Vector3(0, 1.10, 0), 12.0, 46.0],
		["day-side", Vector3(2.9, 1.30, -0.22), Vector3(0, 1.10, 0), 12.0, 50.0],
		["day-rear", Vector3(0.85, 1.65, -3.3), Vector3(0, 1.0, 0), 12.0, 46.0],
		["day-face", Vector3(-0.20, 1.82, 1.38), Vector3(0, 1.79, 0), 12.0, 40.0],
		["night-front", Vector3(-0.65, 1.41, 3.45), Vector3(0, 1.10, 0), 22.1, 46.0],
		["night-rear", Vector3(0.85, 1.65, -3.3), Vector3(0, 1.0, 0), 22.1, 46.0]
	]
	for view in views:
		var offset: Vector3 = view[1]
		var target: Vector3 = view[2]
		clock.call("set_hour", view[3])
		camera.global_position = feet + offset
		camera.fov = view[4]
		camera.look_at(feet + target)
		for i in range(65):
			await RenderingServer.frame_post_draw
		if not _save_frame(view[0], view[3]):
			quit(1)
			return
	for gait in [["day-walking", 0.31, false, 28], ["day-running", 1.0, true, 38]]:
		player.global_position = ANCHOR
		player.velocity = Vector3.ZERO
		actor.rotation.y = 0.0
		player.set("camera_yaw", PI)
		clock.call("set_hour", 12.0)
		await _ticks(20)
		Input.action_press("move_forward", gait[1])
		if gait[2]:
			Input.action_press("sprint")
		await _ticks(gait[3])
		var moving_feet := player.global_position - Vector3.UP * 0.95
		camera.global_position = moving_feet + Vector3(2.65, 1.28, 0.80)
		camera.fov = 51.0
		camera.look_at(moving_feet + Vector3.UP)
		await RenderingServer.frame_post_draw
		Input.action_release("move_forward")
		Input.action_release("sprint")
		if not _save_frame(gait[0], 12.0):
			quit(1)
			return
	var manifest := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		quit(1)
		return
	manifest.store_string(JSON.stringify({"captures": records, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"seed": root.get_node("GameSession").get("world_seed"),
		"revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION")}, "\t"))
	manifest.close()
	print("COURIER_CAPTURE PASS")
	quit()

func _ticks(count: int) -> void:
	for frame in range(count):
		await physics_frame

func _showcase(clock: Node) -> void:
	# Movie Maker records this real input route separately from performance.
	world.get_node("SurfaceTraffic").process_mode = Node.PROCESS_MODE_DISABLED
	world.get("city_details").call("set_focus", ANCHOR)
	clock.call("set_hour", 22.1)
	player.global_position = ANCHOR
	world.set("yaw", PI)
	world.set("pitch", 0.34)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	world.call("_snap_camera")
	await _ticks(55)
	Input.action_press("move_forward", 0.28)
	await _ticks(115)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(42)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _ticks(30)
	Input.action_press("move_backward", 0.38)
	await _ticks(77)
	Input.action_release("move_backward")
	await _ticks(26)
	Input.action_press("jump")
	await _ticks(3)
	Input.action_release("jump")
	await _ticks(65)
	var car: CharacterBody3D = world.get("cars")[0]
	car.global_position = Vector3(1.2, 0.78, 27.0)
	car.rotation.y = 0.0
	car.set_meta("claimed", true)
	player.global_position = car.global_position + Vector3(-1.60, 0.49, -0.43)
	player.velocity = Vector3.ZERO
	world.get("city_details").call("set_focus", car.global_position)
	clock.call("set_hour", 18.75)
	world.set("yaw", 0.0)
	world.set_process(false)
	camera.global_position = car.global_position + Vector3(-4.6, 1.65, -1.55)
	camera.look_at(car.global_position + Vector3(0, 0.48, -0.2))
	camera.fov = 53.0
	await _ticks(32)
	world.call("_toggle_car")
	await _ticks(124)
	camera.global_position = car.global_position + Vector3(5.2, 1.75, -1.45)
	camera.look_at(car.global_position + Vector3(0.7, 0.50, -0.1))
	world.call("_toggle_car")
	await _ticks(56)
	world.set_process(true)
	world.set("yaw", 0.0)
	world.get("weapons").cycle()
	Input.action_press("weapon_aim")
	await _ticks(48)
	Input.action_release("weapon_aim")
	await _ticks(16)
	print("COURIER_SHOWCASE PASS")
	quit()

func _save_frame(label: String, hour: float) -> bool:
	var image := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("Unable to write capture " + label)
		return false
	records.append({"file": label + ".png", "camera": str(camera.global_position),
		"camera_rotation": str(camera.global_rotation), "fov": camera.fov, "hour": hour,
		"resolution": [image.get_width(), image.get_height()], "sha256": FileAccess.get_sha256(path)})
	return true
