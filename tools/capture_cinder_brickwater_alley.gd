extends SceneTree
## Genuine, uncomposited Godot Forward+ captures of the current Cinder R9
## placed at the authored Brickwater Service Alley (block -2,1).
## This is a staged car shot in the *actual game city*, not a driving playtest,
## not an AI image, not a separate art-studio backdrop, and not a GPU benchmark.

const BRICKWATER = Vector2i(-2, 1)
const CINDER = preload("res://scripts/road_car_visual.gd")
const ALLEY = preload("res://scripts/brickwater_alley.gd")
const SHOTS = [
	["01-cinder-brickwater-neon-night.png", 21.50,
		Vector3(1.35, 2.10, -10.7), Vector3(-.10, 1.20, -1.55), 59.0],
	["02-cinder-brickwater-daylight.png", 12.00,
		Vector3(1.35, 2.10, -10.7), Vector3(-.10, 1.20, -1.55), 59.0],
	["03-cinder-brickwater-front-quarter-night.png", 22.10,
		Vector3(2.12, 1.68, -7.70), Vector3(-.15, 1.00, -1.60), 66.0],
]

func _initialize() -> void:
	create_timer(720.0, true, false, true).timeout.connect(
		func() -> void: _fail("Full city Forward+ scene capture timeout"))
	call_deferred("_capture")

func _fail(message: String) -> void:
	push_error("CINDER_BRICKWATER_SHOWCASE: " + message)
	quit(1)

func _capture() -> void:
	var directory := OS.get_environment("NIGHTGRID_CINDER_ALLEY_DIR")
	if not directory.is_absolute_path() or DirAccess.dir_exists_absolute(directory):
		_fail("NIGHTGRID_CINDER_ALLEY_DIR must be a new absolute path")
		return
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("Could not create output directory")
		return
	if DisplayServer.get_name() == "headless" \
			or RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Requires true Godot Forward+ rendering to a visible framebuffer")
		return

	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Original playable game scene missing")
		return
	var world := scene.instantiate() as Node3D
	world.name = "BrickwaterOriginalPlayableCity"
	root.add_child(world)
	await process_frame

	var city := world.get("city_details") as Node3D
	var camera := world.get("camera") as Camera3D
	var clock: Node = world.get("day_night")
	var player := world.get("player") as CharacterBody3D
	if city == null or camera == null or clock == null or player == null:
		_fail("City, camera, clock, or player missing from original world")
		return
	var menus := world.get_node_or_null("GameMenus")
	if menus != null:
		menus.call("hide_for_game")
	var hud := world.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false

	var origin := Vector3((float(BRICKWATER.x)+.5)*58.0, 0.0,
		(float(BRICKWATER.y)+.5)*58.0)
	player.global_position = origin + Vector3(0, 1.0, -9.0)
	player.velocity = Vector3.ZERO
	city.call("set_focus", origin)
	world.get("street_lights").call("set_focus", origin)
	world.get("venue_system").call("set_focus", origin)
	world.get("civic_services").call("set_focus", origin)
	await physics_frame
	await physics_frame
	var chunk: Node3D = city.get("_loaded").get(BRICKWATER)
	var alley: Node3D = chunk.get_node_or_null("BrickwaterServiceAlley") if chunk != null else null
	if alley == null or alley.get_node_or_null("PhotographicAlleyPavement") == null \
			or alley.get_node_or_null("AuthoredUpperArchitecture") == null \
			or alley.get_node_or_null("BusinessFrontage") == null \
			or alley.get_node_or_null("NightShiftRepairs") == null:
		_fail("The actual complete authored Brickwater alley did not stream into the game")
		return

	# Freeze actor/world gameplay while keeping the exact original city scene,
	# buildings, materials, sign assemblies, pavement and weather dressing.
	world.set_process(false)
	world.set_physics_process(false)
	player.set_physics_process(false)
	player.hide()
	clock.set("paused", true)
	camera.make_current()

	var car := CINDER.new() as Node3D
	car.name = "CurrentOriginalCinderR9InBrickwater"
	car.call("configure", Color("9c2338"))
	world.add_child(car)
	# The R9 mesh offsets its frame 0.825m below the visual root. Tire radius
	# and axle center set the correct tire-floor contact at Alley.FLOOR_Y.
	car.global_position = origin + Vector3(0.0, ALLEY.FLOOR_Y + .825, -2.05)
	car.global_rotation = Vector3.ZERO
	await process_frame
	if car.get_node_or_null("Coachwork/FrontClip") == null \
			or car.get_node_or_null("Coachwork/FixedBrakeCaliper") != null:
		_fail("Expected current fully-authored Cinder visual not present")
		return
	var spec: Dictionary = car.call("get_motion_state")
	if int(spec.get("fixed_calipers", -1)) != 4:
		_fail("Expected four separate Cinder calipers on current rig")
		return

	var records: Array[Dictionary] = []
	for item in SHOTS:
		var name: String = item[0]
		var hour: float = float(item[1])
		clock.call("set_hour", hour)
		world.get("venue_system").call("set_hour", hour)
		world.get("civic_services").call("set_hour", hour)
		# Reproduce original Brickwater neon/wet-pavement day/night states.
		alley.call("set_night_factor", 1.0 if hour >= 19.0 else 0.05)
		car.call("set_lighting_hour", hour)
		car.call("update_motion", 0.0, 0.0, false, true, 0.0, 0.0, .25)
		var at: Vector3 = origin + item[2]
		var look: Vector3 = origin + item[3]
		camera.global_position = at
		camera.fov = float(item[4])
		camera.look_at(look, Vector3.UP)
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var pixels: Image = root.get_texture().get_image()
		if pixels == null or pixels.is_empty() or pixels.get_width() < 1200:
			_fail("The car/alley screenshot framebuffer is empty or undersized")
			return
		var output := directory.path_join(name)
		if pixels.save_png(output) != OK or FileAccess.get_file_as_bytes(output).size() < 16000:
			_fail("Couldn't save real Godot image " + name)
			return
		records.append({
			"file": name, "sha256": FileAccess.get_sha256(output),
			"hour": hour, "camera": [at.x,at.y,at.z],
			"look": [look.x,look.y,look.z], "fov": camera.fov,
			"resolution": [pixels.get_width(), pixels.get_height()],
			"vehicle": "nightgrid.cinder_r9",
			"location": "actual fully streamed Brickwater Service Alley (-2,1)",
			"capture_kind": "staged authentic in-game Forward+ framebuffer; not live driving",
		})
		print("CINDER_BRICKWATER_FRAME: ", name)
	var manifest := FileAccess.open(directory.path_join("manifest.json"), FileAccess.WRITE)
	if manifest == null:
		_fail("Couldn't create camera/source provenance manifest")
		return
	manifest.store_string(JSON.stringify({
		"source_revision": OS.get_environment("NIGHTGRID_SOURCE_REVISION"),
		"engine": Engine.get_version_info().get("string"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"source": "real Brickwater original city scene and Cinder R9 vehicle",
		"performance_comparable_to_native_gpu": false,
		"staged_not_gameplay_driving": true,
		"shots": records,
	}, "\t"))
	manifest.close()
	print("CINDER_BRICKWATER_CAPTURE PASS: ", records.size(), " uncomposited real city frames")
	quit(0)
