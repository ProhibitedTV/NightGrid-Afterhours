extends SceneTree
## Native matched-camera evidence; no headless execution or compositing.
## Set NIGHTGRID_GOLD_CAPTURE_DIR to a new absolute output directory.
var world: Node3D
var cam: Camera3D
var output: String
var manifest := {}
func _initialize() -> void:
	call_deferred("_capture")
func _fail(message: String) -> void:
	push_error("BRICKWATER_GOLD_CAPTURE: "+message)
	quit(1)
func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Requires a rendered viewport")
		return
	output = OS.get_environment("NIGHTGRID_GOLD_CAPTURE_DIR")
	if output.is_empty() or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		_fail("Set NIGHTGRID_GOLD_CAPTURE_DIR to a new absolute directory")
		return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		_fail("Cannot create output directory")
		return
	create_timer(180.0,true,false,true).timeout.connect(func()->void:_fail("capture watchdog"))
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	world.set_process(false)
	world.set_physics_process(false)
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	cam = world.get("camera")
	var clock: Node = world.get("day_night")
	clock.set("paused",true)
	world.get_node("HUD").hide()
	var anchor := Vector3(-87,1.15,77)
	player.global_position = anchor
	for system in ["city_details","street_lights","venue_system","civic_services"]:
		world.get(system).call("set_focus",anchor)
	var captures := [
		["01_night_eye",22.1,Vector3(-87,1.78,77.5),Vector3(-87,2.25,95),67.0],
		["02_day_eye",12.5,Vector3(-87,1.78,77.5),Vector3(-87,2.25,95),67.0],
		["03_wall_detail",22.1,Vector3(-86.45,2.0,81),Vector3(-89.5,2.5,77.8),55.0],
		["04_street_mouth",22.1,Vector3(-87,2.2,98.0),Vector3(-87,3.0,76),65.0]]
	for shot in captures:
		clock.call("set_hour",shot[1])
		for system in ["venue_system","civic_services"]:
			world.get(system).call("set_hour",float(shot[1]))
		cam.global_position = shot[2]
		cam.look_at(shot[3],Vector3.UP)
		cam.fov = shot[4]
		print("GOLD_CAPTURE staging ",shot[0])
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var frame_image: Image = root.get_texture().get_image()
		if frame_image == null or frame_image.is_empty():
			_fail("No live framebuffer")
			return
		var filename: String = str(shot[0])+".png"
		if frame_image.save_png(output.path_join(filename)) != OK:
			_fail("Could not save "+filename)
			return
		manifest[filename] = {"hour":shot[1],"position":str(shot[2]),"look_at":str(shot[3]),"fov":shot[4],"width":frame_image.get_width(),"height":frame_image.get_height()}
		print("GOLD_CAPTURED ",filename)
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	if file==null:
		_fail("Cannot write capture manifest")
		return
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"revision":OS.get_environment("NIGHTGRID_SOURCE_REVISION"),"captures":manifest}, "\t"))
	file.close()
	print("GOLD_CAPTURE PASS ",output)
	quit(0)
