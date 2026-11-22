extends SceneTree
## Real framebuffer QA, separate from the public gallery. Do not run headless.
var game: Node3D
var camera: Camera3D
var hud: CanvasLayer
var output: String

func _initialize() -> void:
	call_deferred("_run")

func fail(reason: String) -> void:
	push_error("RADAR_CAPTURE: " + reason)
	quit(1)

func _run() -> void:
	output = OS.get_environment("RADAR_CAPTURE_OUT")
	if output.is_empty():
		fail("RADAR_CAPTURE_OUT required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	camera = game.get("camera")
	hud = game.get_node("HUD")
	var menu: Node = game.get_node("GameMenus")
	menu.call("hide_for_game")
	game.set_process(false)
	game.set_physics_process(false)
	var actor: CharacterBody3D = game.get("player")
	actor.set_physics_process(false)
	var clock: Node = game.get("day_night")
	clock.set("paused",true)
	clock.call("set_hour",22.1)
	hud.visible = true
	actor.global_position = Vector3(-87,1.15,83)
	(actor.get("visual") as Node3D).global_rotation = Vector3.ZERO
	game.call("set_navigation_waypoint",Vector2(-58,116))
	_stage(actor.global_position, Vector3(-87,4.25,76), Vector3(-87,2.0,94))
	if not await _capture("01-on-foot.png"):
		return
	# Use an actual player vehicle and the ordinary enter interaction; don't
	# substitute a showcase mesh or patch the resulting framebuffer.
	var cars: Array = game.get("cars")
	if cars.is_empty():
		fail("No live vehicle")
		return
	var car: CharacterBody3D = cars[0]
	car.set_physics_process(false)
	car.global_position = Vector3(-58,1.05,58)
	car.global_rotation = Vector3(0,PI*0.5,0)
	actor.global_position = car.global_position + Vector3(0,0,2)
	game.call("_toggle_car")
	if game.get("current_car") != car:
		fail("Ordinary vehicle entry failed")
		return
	_stage(car.global_position, car.global_position + Vector3(8,4.5,0), car.global_position + Vector3(-5,1.4,0))
	if not await _capture("02-driving.png"):
		return
	menu.call("open_map")
	if not await _capture("03-interactive-atlas.png",false):
		return
	print("RADAR_CAPTURE PASS: three real framebuffer views ", root.get_texture().get_size())
	quit(0)

func _stage(at: Vector3, position: Vector3, look: Vector3) -> void:
	for key in ["city_details","street_lights","venue_system","civic_services"]:
		game.get(key).call("set_focus",at)
	camera.global_position = position
	camera.look_at(look,Vector3.UP)
	game.call("_update_hud")
	var radar: Control = hud.get_node("Minimap")
	radar.queue_redraw()

func _capture(filename: String, check_hud: bool = true) -> bool:
	# Wait for actual rendered frames, not merely SceneTree updates.
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	if check_hud:
		var radar: Control = hud.get_node("Minimap")
		var bounds := radar.get_global_rect()
		var viewport := radar.get_viewport_rect()
		if not radar.is_visible_in_tree() or not viewport.encloses(bounds) or not is_equal_approx(bounds.end.y,viewport.end.y - 24.0) or not is_equal_approx(bounds.position.x,24.0):
			fail("Radar not inside lower-left viewport: %s vs %s" % [bounds,viewport])
			return false
	var frame: Image = root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.get_width() < 1100 or frame.get_height() < 600:
		fail("Invalid framebuffer")
		return false
	var colors := {}
	for x in range(11):
		for y in range(7):
			colors[frame.get_pixel(x*(frame.get_width()-1)/10,y*(frame.get_height()-1)/6).to_html(false)] = true
	if colors.size() < 10 or frame.save_png(output.path_join(filename)) != OK:
		fail("Blank framebuffer or write error")
		return false
	print("RADAR_CAPTURED ", filename, " ", frame.get_size())
	return true
