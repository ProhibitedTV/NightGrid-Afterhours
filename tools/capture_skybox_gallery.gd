extends SceneTree
## Capture the real running game's sky/weather renderer from ONE fixed camera.
## Runs under a graphical Godot display, not --headless. These are not AI
## concepts, mockups or repainted panoramas: each PNG is root viewport pixels.

const DIRECTORY := "res://docs/screenshots/skyboxes"
var game: Node3D
var camera: Camera3D
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_capture_all")

func _fail(message: String) -> void:
	push_error("SKYBOX_GALLERY_CAPTURE: " + message)
	quit(1)

func _capture_all() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Main playable game scene missing")
		return
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	camera = game.get("camera") as Camera3D
	var hud := game.get_node_or_null("HUD") as CanvasLayer
	var menus := game.get_node_or_null("GameMenus")
	var player := game.get("player") as CharacterBody3D
	var clock: Node = game.get("day_night")
	var city: Node = game.get("city_details")
	if camera == null or hud == null or menus == null or player == null or clock == null or city == null:
		_fail("Playable camera, clock, city or interface missing")
		return
	menus.call("hide_for_game")
	hud.visible = false
	game.set_process(false)
	player.set_physics_process(false)
	clock.set_process(false)
	clock.set("paused", true)
	camera.make_current()
	camera.fov = 77.0
	# Identical geography and framing across all eight shots. The camera
	# overlooks the REAL Brickwater neighborhood, with rooftops below and
	# clear visible sky above; no separate render-only demonstration scene.
	var focus := Vector3(-87.0, 1.15, 87.0)
	var eye := Vector3(-91.0, 17.0, 43.0)
	var target := Vector3(-91.0, 35.0, 170.0)
	player.global_position = focus
	player.velocity = Vector3.ZERO
	city.call("set_focus", focus)
	game.get("street_lights").call("set_focus", focus)
	game.get("venue_system").call("set_focus", focus)
	game.get("civic_services").call("set_focus", focus)
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var shots: Array[Dictionary] = [
		{"filename":"01-dawn-clear.png","hour":6.5,"weather":"clear","expected":"dawn_clear"},
		{"filename":"02-afternoon-sunny.png","hour":12.5,"weather":"clear","expected":"clear_day"},
		{"filename":"03-afternoon-cloudy.png","hour":12.5,"weather":"cloudy","expected":"afternoon_clouds"},
		{"filename":"04-evening-golden.png","hour":18.5,"weather":"clear","expected":"evening_clear"},
		{"filename":"05-night-clear.png","hour":22.0,"weather":"clear","expected":"moonlit_night"},
		{"filename":"06-overcast.png","hour":12.5,"weather":"overcast","expected":"overcast_day"},
		{"filename":"07-rain.png","hour":12.5,"weather":"rain","expected":"storm_day"},
		{"filename":"08-storm.png","hour":12.5,"weather":"storm","expected":"storm_day"}
	]
	# Do not claim rain/storm show physical precipitation: these are the
	# corresponding sky, fog and sunlight presets of the real pilot.
	for shot in shots:
		var weather: String = shot["weather"]
		if not bool(clock.call("set_weather", weather)):
			_fail("The live game rejected weather state: " + weather)
			return
		clock.call("set_hour", float(shot["hour"]))
		game.get("venue_system").call("set_hour", float(shot["hour"]))
		game.get("civic_services").call("set_hour", float(shot["hour"]))
		var active: String = str(clock.call("active_sky_preset"))
		if active != str(shot["expected"]):
			_fail("Wrong in-game panorama for " + weather + ": " + active)
			return
		for frame in range(7):
			await process_frame
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			_fail("No game framebuffer returned for " + str(shot["filename"]))
			return
		if image.get_width() < 1280 or image.get_height() < 720:
			_fail("Capture resolution too low: " + str(image.get_size()))
			return
		var unique := {}
		for ix in range(13):
			for iy in range(8):
				var x := int(ix * (image.get_width() - 1) / 12.0)
				var y := int(iy * (image.get_height() - 1) / 7.0)
				unique[image.get_pixel(x, y).to_html(false)] = true
		if unique.size() < 12:
			_fail("Nearly blank framebuffer for " + str(shot["filename"]))
			return
		var filename: String = shot["filename"]
		var destination := DIRECTORY + "/" + filename
		if image.save_png(destination) != OK:
			_fail("Unable to write actual frame " + destination)
			return
		var size := FileAccess.get_file_as_bytes(destination).size()
		if size < 16000:
			_fail("Suspiciously small capture " + filename)
			return
		records.append({
			"file": filename, "clock_hour": shot["hour"], "weather": weather,
			"selected_sky": active, "bytes": size, "width": image.get_width(),
			"height": image.get_height()
		})
		print("SKYBOX_GALLERY FRAME: ", filename, " ", active, " ", size, " bytes")
	var manifest := {
		"source_revision": OS.get_environment("GITHUB_SHA"),
		"engine": Engine.get_version_info().get("string"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"render_driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [root.size.x, root.size.y],
		"camera_position": [eye.x, eye.y, eye.z],
		"camera_look_target": [target.x, target.y, target.z],
		"district": "Brickwater",
		"capture_type": "actual game root viewport, not a concept/render",
		"note": "Rain and storm are visual weather presets; no precipitation simulation in this pilot",
		"shots": records
	}
	var out := FileAccess.open(DIRECTORY + "/capture.json", FileAccess.WRITE)
	if out == null:
		_fail("Cannot write skybox capture manifest")
		return
	out.store_string(JSON.stringify(manifest, "\t"))
	out.close()
	print("SKYBOX_GALLERY_CAPTURE PASS: ", records.size(), " real playable game frames")
	quit(0)
