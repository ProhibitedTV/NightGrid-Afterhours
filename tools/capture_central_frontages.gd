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
	camera.global_position = Vector3(-17.7, 2.8, -3.8)
	camera.look_at(Vector3(-18.5, 7.2, 14.0), Vector3.UP)
	await _settle()
	if not await _save("brickwater-recessed-windows-closeup-real-godot.png"):
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
