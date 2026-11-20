extends SceneTree
## Automated VISUAL evidence for the next Windows playtest.
## Captures the actual playable scene through Godot's real X11/Mesa renderer.
## Never replace framebuffer images with art, cached PNGs or generated mockups.
const OUTPUT_DIR = "res://playtest-evidence"
const WorldPlan = preload("res://scripts/world_plan.gd")

var game: Node3D
var camera: Camera3D
var menu: CanvasLayer
var hud: CanvasLayer
var player: CharacterBody3D
var city: Node3D
var clock: Node
var names: Array[String] = []

func _initialize() -> void:
	call_deferred("_capture_all")

func _abort(message: String) -> void:
	push_error("PLAYTEST_EVIDENCE_CAPTURE: " + message)
	quit(1)

func _pose(at: Vector3, camera_pos: Vector3, target: Vector3, hour: float) -> void:
	clock.call("set_hour", hour)
	player.global_position = at
	player.velocity = Vector3.ZERO
	city.call("set_focus", at)
	game.get("street_lights").call("set_focus", at)
	game.get("venue_system").call("set_focus", at)
	game.get("civic_services").call("set_focus", at)
	camera.global_position = camera_pos
	camera.look_at(target, Vector3.UP)
	hud.visible = false

func _settle() -> void:
	# Wait for the actual render-thread signal; process_frame alone can copy
	# a partially initialized virtual-display framebuffer.
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

func _write_frame(filename: String) -> bool:
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_abort("Empty framebuffer: " + filename)
		return false
	if image.get_width() < 1100 or image.get_height() < 600:
		_abort("Wrong render size for " + filename)
		return false
	var unique := {}
	for ix in range(12):
		for iy in range(8):
			var x := roundi(float(ix) / 11.0 * float(image.get_width() - 1))
			var y := roundi(float(iy) / 7.0 * float(image.get_height() - 1))
			unique[image.get_pixel(x, y).to_html(false)] = true
	if unique.size() < 12:
		_abort("Near-uniform camera frame; capture may be a void: " + filename)
		return false
	var path := OUTPUT_DIR + "/" + filename
	if image.save_png(path) != OK:
		_abort("Unable to write PNG: " + filename)
		return false
	var bytes := FileAccess.get_file_as_bytes(path).size()
	if bytes <= 16000:
		_abort("Suspiciously small PNG: %s (%d bytes)" % [filename, bytes])
		return false
	print("PLAYTEST FRAME: %s (%dx%d, %d bytes)" % [
		filename, image.get_width(), image.get_height(), bytes])
	names.append(filename)
	return true

func _capture_at(filename: String, at: Vector3, from: Vector3,
		look: Vector3, hour: float) -> bool:
	_pose(at, from, look, hour)
	await _settle()
	return _write_frame(filename)

func _capture_all() -> void:
	if DisplayServer.get_name() == "headless":
		_abort("Requires an actual display driver; no headless mock captures")
		return
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_abort("Playable scene not found")
		return
	game = scene.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	camera = game.get("camera") as Camera3D
	menu = game.get_node_or_null("GameMenus") as CanvasLayer
	hud = game.get_node_or_null("HUD") as CanvasLayer
	player = game.get("player") as CharacterBody3D
	city = game.get("city_details") as Node3D
	clock = game.get("day_night") as Node
	if camera == null or menu == null or hud == null or player == null or city == null or clock == null:
		_abort("Essential real playable world camera/characters missing")
		return
	if game.get_node_or_null("MorrowBayPerimeter") == null:
		_abort("Combined playtest branch is missing the actual coastal boundary")
		return
	if WorldPlan.GRID_RADIUS != 4:
		_abort("Captures must show current 8x8 save-compatible city")
		return
	menu.call("hide_for_game")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.set_process(false)
	player.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _settle()
	# Geographically grounded camera goals face OUTWARD, beyond the last
	# drivable junction at +/-245m, rather than down an interior street.
	if not await _capture_at("01-north-quay-harbor.png",
			Vector3(0, 1.15, -223), Vector3(9, 5.2, -222),
			Vector3(0, 4.2, -355), 20.7):
		return
	if not await _capture_at("02-west-docks-port.png",
			Vector3(-222, 1.15, -7), Vector3(-219, 5.0, -12),
			Vector3(-355, 5.0, -18), 12.5):
		return
	if not await _capture_at("03-horizon-eastern-ridge.png",
			Vector3(223, 1.15, 8), Vector3(218, 7.0, 11),
			Vector3(370, 34.0, 14), 16.0):
		return
	if not await _capture_at("04-southworks-freight-edge.png",
			Vector3(0, 1.15, 222), Vector3(9, 6.8, 220),
			Vector3(0, 13.0, 370), 21.5):
		return
	# The same live drivable KESTREL S6 is repositioned, not replaced by a
	# bespoke screenshot-only vehicle model or static decorative proxy.
	var fleet: Array = game.get("cars")
	if fleet.is_empty():
		_abort("No original player-drivable KESTREL for rear QA")
		return
	var car := fleet[0] as CharacterBody3D
	car.set_physics_process(false)
	car.global_position = Vector3(28.0, 1.15, 190.0)
	car.rotation.y = 0.0
	if car.get_node_or_null("KestrelS6HeroVisual/RearHatchSolid") == null:
		_abort("Expected repaired hatch on the live KESTREL model")
		return
	if not await _capture_at("05-kestrel-rear-quarter-dusk.png",
			Vector3(34, 1.15, 203), Vector3(20.5, 3.1, 201.0),
			car.global_position + Vector3(0, 0.4, 0), 20.7):
		return
	if not await _capture_at("06-kestrel-high-rear-day.png",
			Vector3(34, 1.15, 203), Vector3(28.0, 8.0, 200.0),
			car.global_position + Vector3(0, 0.4, 0), 12.0):
		return
	if not await _capture_at("07-kestrel-side-night.png",
			Vector3(34, 1.15, 203), Vector3(39.5, 2.8, 190.0),
			car.global_position + Vector3(0, 0.4, 0), 21.5):
		return
	if not await _capture_at("08-harbor-elevated-overlook.png",
			Vector3(-200, 1.15, -190), Vector3(-215.0, 66.0, -198.0),
			Vector3(-395.0, -3.0, -350.0), 20.7):
		return
	var record := {
		"source_revision": OS.get_environment("GITHUB_SHA"),
		"renderer": "Mesa OpenGL Compatibility (set by this GitHub Actions capture workflow)",
		"scene": "res://scenes/main.tscn",
		"capture_kind": "Real Godot 4.3 framebuffers, Mesa OpenGL Compatibility, not Windows Forward+ or RTX benchmark",
		"files": names
	}
	var manifest := FileAccess.open(OUTPUT_DIR + "/manifest.json", FileAccess.WRITE)
	if manifest == null:
		_abort("Could not write real game capture manifest")
		return
	manifest.store_string(JSON.stringify(record, "  ") + "\n")
	manifest.close()
	print("PLAYTEST_EVIDENCE_CAPTURE PASS: ", names)
	quit(0)
