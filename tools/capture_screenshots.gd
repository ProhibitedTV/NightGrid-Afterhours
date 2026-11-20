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
