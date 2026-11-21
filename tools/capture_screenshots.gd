extends SceneTree
## Real screenshot capture from the actual playable Godot scene.
## Run with an actual display server (Xvfb+Mesa or desktop): NEVER --headless.
## Screenshots are PNGs straight from the rendering viewport; no mockups,
## AI images, stock images, compositing or external screenshot replacements.
const DIRECTORY = "res://docs/screenshots"
var game: Node3D
var camera: Camera3D
var hud: CanvasLayer
var menu: CanvasLayer
var results: Array[String] = []

func _initialize() -> void:
	call_deferred("_capture_all")

func _abort(reason: String) -> void:
	push_error("SCREENSHOT_CAPTURE: " + reason)
	quit(1)

func _capture_all() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_abort("Main playable scene could not be loaded")
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	camera = game.get("camera")
	hud = game.get_node_or_null("HUD")
	menu = game.get_node_or_null("GameMenus")
	if camera == null or hud == null or menu == null:
		_abort("Gameplay camera or HUD/menu missing")
		return
	menu.call("hide_for_game")
	game.set_process(false)
	(game.get("player") as CharacterBody3D).set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var clock: Node = game.get("day_night")
	clock.set("paused",true)
	var city: Node3D = game.get("city_details")
	# Allow the renderer to initialize on a real viewport before any frame is
	# captured; the checked-in images must not be synthetic placeholders.
	await _settle()
	# Show the actual new road-facing CC0 PBR Central Exchange architecture
	# rather than an older generic downtown corridor view.
	clock.call("set_hour", 20.18)
	_stage_street(Vector3(0.0, 1.15, 6.0),
		Vector3(0.0, 3.2, -21.5), Vector3(0.0, 8.4, 25.0), false)
	await _settle()
	if not await _screenshot("01-morrow-bay-neon-night.png"):
		return
	# Live player/HUD, authored restaurant frontage at night.
	var market: Vector3 = game.get("venue_system").call("venue_position", "moon_noodles")
	_stage_street(market, market + Vector3(7.8, 4.7, -13.5),
		market + Vector3(0.0, 3.1, 3.5), true)
	await _settle()
	if not await _screenshot("02-vesper-market-nightlife.png"):
		return
	# Real elevated train stopped at the permanent Helix station.
	var rail: Node3D = game.get("rail")
	rail.get("train").position.x = 116.0
	rail.set("current_station", 3)
	rail.set("next_station", 4)
	rail.set("dwell_remaining", 8.0)
	var station: Vector3 = rail.call("station_entrance", 3)
	_stage_street(station, Vector3(115.5, 8.5, -32.0),
		Vector3(116.0, 12.3, -58.0), false)
	await _settle()
	if not await _screenshot("03-m-line-helix-terminal.png"):
		return
	# A second real city state shows the planted civic neighborhood by daylight.
	clock.call("set_hour", 12.5)
	_stage_street(Vector3(203.0, 1.15, 29.0),
		Vector3(180.0, 14.0, 73.0), Vector3(203.0, 2.6, 23.0), false)
	await _settle()
	if not await _screenshot("04-horizon-commons-daylight.png"):
		return
	# Central Exchange in daylight
	clock.call("set_hour", 12.5)
	_stage_street(Vector3(0.0, 1.15, 6.0), Vector3(0.0, 3.2, -21.5), Vector3(0.0, 8.4, 25.0), false)
	await _settle()
	if not await _screenshot("10-central-exchange-daylight.png"):
		return
	# Brickwater brick and street architecture
	clock.call("set_hour", 12.0)
	_stage_street(Vector3(-3.7, 1.15, 3.8), Vector3(-3.7, 3.0, 3.8), Vector3(-10.9, 5.0, 24.0), false)
	await _settle()
	if not await _screenshot("11-brickwater-streetfront.png"):
		return
	# Afterhours illuminated steel storefront
	clock.call("set_hour", 21.0)
	_stage_street(Vector3(3.7, 1.15, 3.8), Vector3(3.7, 3.0, 3.8), Vector3(10.9, 5.0, 24.0), false)
	await _settle()
	if not await _screenshot("12-afterhours-streetfront.png"):
		return
	# North Quay Exchange
	clock.call("set_hour", 9.5)
	_stage_street(Vector3(-29.0, 1.15, -222.0), Vector3(-29.0, 4.5, -230.0), Vector3(-29.0, 3.0, -203.0), false)
	await _settle()
	if not await _screenshot("13-north-quay-exchange.png"):
		return
	# Pier Nine Depot, West Docks
	clock.call("set_hour", 17.5)
	_stage_street(Vector3(-203.0, 1.15, 8.0), Vector3(-203.0, 4.5, 1.0), Vector3(-203.0, 3.0, 29.0), false)
	await _settle()
	if not await _screenshot("14-pier-nine-depot.png"):
		return
	# Southworks Hall
	clock.call("set_hour", 13.0)
	_stage_street(Vector3(29.0, 1.15, 182.0), Vector3(29.0, 4.5, 175.0), Vector3(29.0, 3.0, 203.0), false)
	await _settle()
	if not await _screenshot("15-southworks-hall.png"):
		return
	if not await _capture_site("16-lantern-cup-exterior.png", "lantern_cup", false, 17.5):
		return
	if not await _capture_site("17-prism-club-exterior.png", "prism_club", false, 22.0):
		return
	if not await _capture_site("18-static-room-exterior.png", "static_room", false, 22.5):
		return
	if not await _capture_site("19-dock-nine-social.png", "dock_nine", false, 20.5):
		return
	if not await _capture_site("20-blue-hour-exterior.png", "blue_hour", false, 21.0):
		return
	if not await _capture_site("21-helix-espresso.png", "helix_espresso", false, 10.0):
		return
	if not await _capture_site("22-neon-bao-streetfood.png", "neon_bao", false, 20.0):
		return
	if not await _capture_site("23-crane-and-gear.png", "crane_supply", true, 12.0):
		return
	if not await _capture_site("24-mbpd-dispatch-exterior.png", "police_hq", true, 19.5):
		return
	if not await _capture_site("25-eastside-fire.png", "east_fire", true, 14.0):
		return
	clock.call("set_hour", 12.5)
	_stage_street(Vector3(0.0, 1.15, 6.0), Vector3(0.0, 4.0, 14.0), Vector3(0.0, 2.0, 6.0), true)
	game.call("_snap_camera")
	await _settle()
	if not await _screenshot("26-courier-street-view.png"):
		return
	clock.call("set_hour", 20.18)
	_stage_street(Vector3(-155.5, 1.15, -164.3), Vector3(-155.5, 4.0, -156.3), Vector3(-155.5, 2.0, -164.3), true)
	game.call("_snap_camera")
	await _settle()
	if not await _screenshot("27-vesper-player-view.png"):
		return
	# Two dedicated, reproducible real-fleet art views. Stage existing traffic
	# actors on their own outer loop lanes, never substitute showcase meshes.
	var traffic: Node = game.get("traffic")
	var bus := traffic.get_node_or_null("CityBus_2") as CharacterBody3D
	var car := traffic.get_node_or_null("AmbientCar_outer_0") as CharacterBody3D
	if bus == null or car == null or bus.get_node_or_null("CityBusCoachwork") == null or car.get_node_or_null("CivilianCarCoachwork") == null:
		_abort("Actual city bus and sedan coachwork missing")
		return
	# Freeze the fleet for these two intentionally staged art captures.
	for actor in traffic.get("fleet"):
		actor.set_physics_process(false)
	bus.global_position = Vector3(-157.0,1.75,-170.75)
	bus.rotation.y = -PI*0.5
	car.global_position = Vector3(-143.0,1.0,-170.75)
	car.rotation.y = -PI*0.5
	# Use both camera locations from the north side of the road; the
	# restaurant and masonry are behind the real lane-following vehicles.
	clock.call("set_hour",12.5)
	_stage_street(market,Vector3(-147.0,3.25,-179.0),Vector3(-157.0,1.85,-170.75),false)
	await _settle()
	if not await _screenshot("08-city-bus-coachwork.png"):
		return
	clock.call("set_hour",20.18)
	_stage_street(market,Vector3(-136.5,2.65,-177.7),Vector3(-143.0,1.2,-170.75),false)
	await _settle()
	if not await _screenshot("09-civilian-sedan-coachwork.png"):
		return
	if not await _capture_room("28-lantern-cup-interior.png", "lantern_cup", false, 17.5, Vector3(954.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	if not await _capture_room("29-prism-club-interior.png", "prism_club", false, 22.0, Vector3(954.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	if not await _capture_room("30-static-room-interior.png", "static_room", false, 22.5, Vector3(946.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	if not await _capture_room("31-mbpd-dispatch-interior.png", "police_hq", true, 19.5, Vector3(954.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	if not await _capture_room("32-horizon-health-interior.png", "garden_clinic", true, 12.0, Vector3(954.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	if not await _capture_room("33-crane-and-gear-interior.png", "crane_supply", true, 12.0, Vector3(946.0, 3.8, 956.8), Vector3(950.0, 2.5, 943.5)):
		return
	# Enter the actual grocery using the same game method as pressing H.
	clock.call("set_hour", 19.5)
	var grocery: Vector3 = game.get("civic_services").call("position_for", "quay_fresh")
	_stage_street(grocery, grocery + Vector3(7.0, 4.0, -10.0),
		grocery + Vector3(0.0, 3.2, 2.0), false)
	game.call("_toggle_interior")
	if not game.get("interiors").call("is_inside"):
		_abort("Expected actual Quay Fresh interior to open")
		return
	hud.visible = false
	camera.global_position = Vector3(954.0, 3.8, 956.8)
	camera.look_at(Vector3(950.0, 2.5, 943.5), Vector3.UP)
	await _settle()
	if not await _screenshot("05-quay-fresh-interior.png"):
		return
	# Capture the actual interactive title and full city atlas, not Figma art.
	(game.get("player") as CharacterBody3D).global_position = game.get("interiors").call("get_entry_point")
	game.call("_toggle_interior")
	clock.call("set_hour", 19.5)
	_stage_street(Vector3(0.0, 1.15, 6.0),
		Vector3(0.0, 3.2, -21.5), Vector3(0.0, 8.4, 25.0), false)
	hud.visible = false
	menu.call("open_title")
	await _settle()
	if not await _screenshot("06-title-menu.png"):
		return
	menu.call("open_map")
	await _settle()
	if not await _screenshot("07-city-map-menu.png"):
		return
	menu.call("hide_for_game")
	print("SCREENSHOT_CAPTURE PASS: ", results)
	quit(0)

func _site_position(id: String, civic: bool) -> Vector3:
	if civic:
		return game.get("civic_services").call("position_for", id)
	return game.get("venue_system").call("venue_position", id)

func _capture_site(filename: String, id: String, civic: bool, hour: float) -> bool:
	var at: Vector3 = _site_position(id, civic)
	if at == Vector3.ZERO:
		_abort("Unknown gallery destination: " + id)
		return false
	game.get("day_night").call("set_hour", hour)
	_stage_street(at, at + Vector3(7.8, 4.7, -13.5), at + Vector3(0.0, 3.1, 3.5), false)
	await _settle()
	return await _screenshot(filename)

func _capture_room(filename: String, id: String, civic: bool, hour: float, view: Vector3, target: Vector3) -> bool:
	var at: Vector3 = _site_position(id, civic)
	if at == Vector3.ZERO:
		_abort("Unknown interior destination: " + id)
		return false
	game.get("day_night").call("set_hour", hour)
	_stage_street(at, at + Vector3(7.0, 4.0, -10.0), at + Vector3(0.0, 3.2, 2.0), false)
	game.call("_toggle_interior")
	var interior: Node = game.get("interiors")
	if not interior.call("is_inside") or str(interior.call("active_site_id")) != id:
		_abort("Did not enter the expected playable room: " + id)
		return false
	hud.visible = false
	camera.global_position = view
	camera.look_at(target, Vector3.UP)
	await _settle()
	if not await _screenshot(filename):
		return false
	(game.get("player") as CharacterBody3D).global_position = interior.call("get_exit_point")
	game.call("_toggle_interior")
	if interior.call("is_inside"):
		_abort("Did not exit playable room: " + id)
		return false
	await process_frame
	return true

func _stage_street(at: Vector3, position: Vector3, look: Vector3, show_hud: bool) -> void:
	var player: CharacterBody3D = game.get("player")
	player.global_position = at
	player.velocity = Vector3.ZERO
	var city: Node3D = game.get("city_details")
	city.call("set_focus", at)
	game.get("street_lights").call("set_focus", at)
	game.get("venue_system").call("set_focus", at)
	game.get("civic_services").call("set_focus", at)
	game.get("venue_system").call("set_hour", float(game.get("day_night").get("hour")))
	game.get("civic_services").call("set_hour", float(game.get("day_night").get("hour")))
	camera.global_position = position
	camera.look_at(look, Vector3.UP)
	hud.visible = show_hud
	if show_hud:
		game.call("_update_hud")

func _settle() -> void:
	# Renderer frame_post_draw is required. process_frame alone can capture an
	# incomplete or uninitialized framebuffer with the X11 software renderer.
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

func _screenshot(filename: String) -> bool:
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_abort("Renderer returned an empty framebuffer for " + filename)
		return false
	if image.get_width() < 1100 or image.get_height() < 600:
		_abort("Unusable screenshot dimensions for " + filename +
			": " + str(image.get_size()))
		return false
	var unique_colors := {}
	for ix in range(13):
		for iy in range(8):
			var px := (ix * (image.get_width() - 1)) / 12
			var py := (iy * (image.get_height() - 1)) / 7
			var color: Color = image.get_pixel(px, py)
			unique_colors[color.to_html(false)] = true
	if unique_colors.size() < 10:
		_abort("Screenshot is blank or almost uniform: " + filename)
		return false
	var path := DIRECTORY + "/" + filename
	if image.save_png(path) != OK:
		_abort("Unable to save screenshot " + path)
		return false
	var file_size := FileAccess.get_file_as_bytes(path).size()
	if file_size < 16000:
		_abort("PNG looks suspiciously small: %s (%d bytes)" % [filename, file_size])
		return false
	results.append("%s %dx%d %d bytes" % [filename, image.get_width(),
		image.get_height(), file_size])
	print("CAPTURED: ", results[results.size() - 1])
	return true
