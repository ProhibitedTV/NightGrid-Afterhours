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
	RenderingServer.render_loop_enabled = true
	quit(1)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Real graphical renderer required")
		return
	# Software CI must not continuously render a full city while staging.
	# Explicit synchronous draws below still render the real root viewport.
	RenderingServer.render_loop_enabled = false
	create_timer(720.0, true, false, true).timeout.connect(func() -> void: fail("Capture watchdog elapsed"))
	print("RADAR_STAGE initializing scene")
	output = OS.get_environment("RADAR_CAPTURE_OUT")
	if output.is_empty():
		fail("RADAR_CAPTURE_OUT required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	# Retain the shipped canvas stretch policy, including its letterbox.
	# Log the physical window separately from the content framebuffer.
	print("RADAR_WINDOW ", DisplayServer.window_get_size(), " content scale ", root.content_scale_size, " aspect ", root.content_scale_aspect)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	camera = game.get("camera")
	hud = game.get_node("HUD")
	var menu: Node = game.get_node("GameMenus")
	menu.call("hide_for_game")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.make_current()
	# Freeze simulation during staged real-scene shots; rendering and the
	# always-processing menu continue. This prevents software CI from doing
	# unbounded world simulation between deliberately captured frames.
	paused = true
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
	print("RADAR_STAGE foot")
	_stage(actor.global_position, Vector3(-87,4.25,76), Vector3(-87,2.0,94))
	if not await _capture("01-on-foot.png"):
		return
	print("RADAR_STAGE equipment wheel")
	# Use the normal equipment selector with the same live paused scene.
	# Opening requires an unpaused on-foot state; there is no await until
	# the actual modal pauses simulation again.
	paused = false
	if not game.call("_open_equipment_wheel"):
		fail("Actual equipment wheel failed to open")
		return
	var wheel: Control = game.get("equipment_wheel")
	wheel.call("select_index", 1)
	wheel.call("_process", 0.14)
	if not wheel.visible or not paused:
		fail("Equipment wheel did not enter modal preview")
		return
	if not await _capture("04-equipment-wheel.png",false):
		return
	game.call("_finish_equipment_wheel", "")
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Use an actual player vehicle and the ordinary enter interaction; don't
	# substitute a showcase mesh or patch the resulting framebuffer.
	print("RADAR_STAGE vehicle")
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
	# Stage a real temporary civic restriction and a destination beyond it.
	var restrictions = game.get("road_restrictions")
	if not restrictions.add(Vector2i(-1,1),Vector2i(0,1),"QA","service",10.0):
		fail("Could not stage real civic restriction")
		return
	game.call("set_navigation_waypoint",Vector2(0,58))
	_stage(car.global_position, car.global_position + Vector3(8,4.5,0), car.global_position + Vector3(-5,1.4,0))
	if not await _capture("02-driving.png"):
		return
	print("RADAR_STAGE atlas")
	hud.visible = false
	menu.call("open_map")
	if menu.find_child("WorldMapView", true, false) == null:
		fail("Interactive atlas was not instantiated")
		return
	if not await _capture("03-interactive-atlas.png",false):
		return
	print("RADAR_CAPTURE PASS: four real framebuffer views ", root.get_texture().get_size())
	RenderingServer.render_loop_enabled = true
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
	# A paused software-rendered window can stall waiting for frame_post_draw.
	# Flush deferred UI/layout updates, explicitly draw and synchronize twice.
	# Never fall back to a mock or fabricated image.
	print("RADAR_STAGE settling ", filename)
	# One synchronized draw after two layout frames is sufficient for a
	# settled, frozen scene. A second full-city software draw was expensive.
	await process_frame
	await process_frame
	for i in range(1):
		print("RADAR_STAGE force_draw begin ", filename, " frame ", i+1)
		RenderingServer.force_draw(true, 0.0)
		RenderingServer.force_sync()
		print("RADAR_STAGE force_draw complete ", filename, " frame ", i+1)
	if check_hud:
		var radar: Control = hud.get_node("Minimap")
		var bounds := radar.get_global_rect()
		var viewport := radar.get_viewport_rect()
		if not radar.is_visible_in_tree() or not viewport.encloses(bounds) or not is_equal_approx(bounds.end.y,viewport.end.y - 24.0) or not is_equal_approx(bounds.position.x,24.0):
			fail("Radar not inside lower-left viewport: %s vs %s" % [bounds,viewport])
			return false
	print("RADAR_STAGE reading framebuffer ", filename)
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
	print("RADAR_CAPTURED ", filename, " ", frame.get_size(), " window ", DisplayServer.window_get_size())
	return true
