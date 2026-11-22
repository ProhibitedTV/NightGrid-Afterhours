extends SceneTree
## Fixed-camera Windows replay from the playable scene and its normal city generator.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output := OS.get_environment("NIGHTGRID_PHYSICAL_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		push_error("Requires a graphical run and a new absolute NIGHTGRID_PHYSICAL_CAPTURE_DIR")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	world.get_node("HUD").hide()
	var city: Node3D = world.get("city_details")
	var clock: Node = world.get("day_night")
	var player: CharacterBody3D = world.get("player")
	var camera: Camera3D = world.get("camera")
	clock.set("paused", true)
	world.set_process(false)
	camera.fov = 70.0
	var shots := [
		["m-line-and-signals", Vector3(208, 0.7, -57), Vector3(209, 3.0, -62), Vector3(231, 10, -51), 12.0],
		["east-gardens", Vector3(243, 0.7, -45), Vector3(234, 2.8, -39), Vector3(246, 8, -48), 18.5],
		["pier-storage", Vector3(-203, 0.7, -51), Vector3(-199, 3.4, -54), Vector3(-193.5, 7, -34), 12.0],
		["horizon-commons", Vector3(203, 0.7, 52), Vector3(201, 3.05, 55), Vector3(202, 4.1, 39), 2.02],
		["north-quay-market", Vector3(-29, 0.7, -192), Vector3(-34, 3.0, -191), Vector3(-29, 2.9, -201), 6.48],
	]
	var manifest: Array[Dictionary] = []
	for shot in shots:
		player.global_position = shot[1]
		player.velocity = Vector3.ZERO
		city.call("set_focus", shot[1])
		clock.call("set_hour", shot[4])
		camera.global_position = shot[2]
		camera.look_at(shot[3])
		for frame in range(100):
			await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		var path := output.path_join(shot[0] + ".png")
		if pixels == null or pixels.is_empty() or pixels.save_png(path) != OK:
			push_error("Could not capture " + path)
			quit(1)
			return
		manifest.append({"file": shot[0] + ".png", "sha256": FileAccess.get_sha256(path),
			"resolution": [pixels.get_width(), pixels.get_height()], "camera": str(shot[2]),
			"look": str(shot[3]), "hour": shot[4], "fov": camera.fov})
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"shots": manifest, "revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "seed": root.get_node("GameSession").get("world_seed")}, "\t"))
	file.close()
	print("PHYSICAL_COHERENCE_CAPTURE_PASS")
	quit()
