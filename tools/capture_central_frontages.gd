extends SceneTree
## Real Godot 4 framebuffer evidence for the two Central Exchange façades.
## Mesa OpenGL compatibility is NOT the Windows Forward+ quality target.
## Never use this script to generate fake or illustrated concept art.
const DIR = "res:" + "//exports/central_exchange_review"
var world: Node3D
var camera: Camera3D
var captured: Array[String] = []

func _initialize() -> void:
	call_deferred("_capture")

func _fail(reason: String) -> void:
	push_error("CENTRAL_FRONTAGE_CAPTURE: " + reason)
	quit(1)

func _capture() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Playable NightGrid scene not found")
		return
	world = packed.instantiate()
	root.add_child(world)
	await process_frame
	camera = world.get("camera")
	var hud: CanvasLayer = world.get_node_or_null("HUD")
	var menus := world.get_node_or_null("GameMenus")
	if camera == null or hud == null or menus == null:
		_fail("Real game camera/UI unavailable")
		return
	menus.call("hide_for_game")
	hud.visible = false
	world.set_process(false)
	(world.get("player") as CharacterBody3D).set_physics_process(false)
	var city: Node3D = world.get_node("CityDetails")
	city.call("set_focus", Vector3.ZERO)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var clock: Node = world.get("day_night")
	clock.call("set_hour", 20.18)
	camera.global_position = Vector3(0.0, 3.2, -21.5)
	camera.look_at(Vector3(0.0, 8.4, 25.0), Vector3.UP)
	await _settle()
	if not await _save("central-exchange-dusk-real-godot.png"):
		return
	clock.call("set_hour", 12.0)
	await _settle()
	if not await _save("central-exchange-noon-real-godot.png"):
		return
	clock.call("set_hour", 20.18)
	# The useful view is from the roadway looking at the new X-facing
	# shop windows, NOT into the plain back of a nearby older parcel.
	camera.global_position = Vector3(-3.7, 3.0, 3.8)
	camera.look_at(Vector3(-10.9, 7.0, 24.0), Vector3.UP)
	await _settle()
	if not await _save("brickwater-recessed-windows-closeup-real-godot.png"):
		return
	camera.global_position = Vector3(3.7, 3.0, 3.8)
	camera.look_at(Vector3(10.9, 7.0, 24.0), Vector3.UP)
	await _settle()
	if not await _save("afterhours-blue-steel-glazing-closeup-real-godot.png"):
		return
	# Daylight reveals true surface contrast without the night exposure bias.
	clock.call("set_hour", 12.0)
	camera.global_position = Vector3(-3.7, 3.0, 3.8)
	camera.look_at(Vector3(-10.9, 7.0, 24.0), Vector3.UP)
	await _settle()
	if not await _save("brickwater-scanned-brick-daylight-real-godot.png"):
		return
	camera.global_position = Vector3(3.7, 3.0, 3.8)
	camera.look_at(Vector3(10.9, 7.0, 24.0), Vector3.UP)
	await _settle()
	if not await _save("afterhours-scanned-steel-daylight-real-godot.png"):
		return
	# Brickwater-only structural seam inspection from pedestrian eye
	# height. This aims directly at the closed south-to-avenue return.
	clock.call("set_hour", 12.0)
	camera.global_position = Vector3(-5.2, 2.1, 9.8)
	camera.look_at(Vector3(-10.9, 4.3, 14.3), Vector3.UP)
	await _settle()
	if not await _save("brickwater-sealed-corner-daylight-real-godot.png"):
		return
	# A roofline/return inspection from above the ACTUAL selected lot.
	var loaded: Dictionary = city.get("_loaded")
	var chunk := loaded.get(Vector2i(-1, 0)) as Node3D
	var brickwater: Node3D = null
	if chunk != null:
		brickwater = chunk.get_node_or_null("PhotorealFrontage_-1_0_1") as Node3D
	if brickwater == null:
		_fail("Brickwater corner missing for roof geometry screenshot")
		return
	var roof_y := brickwater.position.y + float(brickwater.get("building_height"))
	camera.global_position = Vector3(-4.9, roof_y + 12.0, 10.0)
	camera.look_at(Vector3(-17.5, roof_y + 0.5, 26.0), Vector3.UP)
	await _settle()
	if not await _save("brickwater-roof-parapet-daylight-real-godot.png"):
		return
	# The Afterhours pilot across the intersection uses WEST-facing glazing
	# and a distinct sealed steel corner. Check it from normal street height.
	clock.call("set_hour", 12.0)
	camera.global_position = Vector3(5.2, 2.1, 9.8)
	camera.look_at(Vector3(10.9, 4.3, 14.3), Vector3.UP)
	await _settle()
	if not await _save("afterhours-sealed-corner-daylight-real-godot.png"):
		return
	var other_chunk: Node3D = (city.get("_loaded") as Dictionary).get(Vector2i(0, 0))
	var afterhours: Node3D = null
	if other_chunk != null:
		afterhours = other_chunk.get_node_or_null("PhotorealFrontage_0_0_0") as Node3D
	if afterhours == null:
		_fail("Afterhours corner building unavailable for rooftop inspection")
		return
	var other_roof := afterhours.position.y + float(afterhours.get("building_height"))
	camera.global_position = Vector3(4.9, other_roof + 12.0, 10.0)
	camera.look_at(Vector3(17.5, other_roof + 0.5, 26.0), Vector3.UP)
	await _settle()
	if not await _save("afterhours-roof-parapet-daylight-real-godot.png"):
		return
	print("CENTRAL_FRONTAGE_CAPTURE PASS: ", captured)
	quit(0)

func _settle() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw

func _save(name: String) -> bool:
	var pixels: Image = root.get_texture().get_image()
	if pixels == null or pixels.is_empty():
		_fail("Engine framebuffer was blank: " + name)
		return false
	if pixels.get_width() < 1100 or pixels.get_height() < 600:
		_fail("Engine framebuffer was too small: " + name)
		return false
	var path := DIR + "/" + name
	if pixels.save_png(path) != OK:
		_fail("Could not save actual Godot framebuffer: " + name)
		return false
	if FileAccess.get_file_as_bytes(path).size() < 16000:
		_fail("Screenshot file likely blank: " + name)
		return false
	captured.append(name)
	print("ACTUAL_GAMEPLAY_FRAME: ", path)
	return true
