extends SceneTree
## Two genuine running-Godot closeups of the single Horizon Commons scanned
## fern. Never substitute concept art, mockups or external plant photography.
const DIRECTORY = "res://docs/fern-review"
const HERO_POSITION = Vector3(187.5, 0.20, 29.0)
var game: Node3D
var camera: Camera3D

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("HORIZON_FERN_CAPTURE: " + reason)
    quit(1)

func _run() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("Main playable scene cannot load")
        return
    game = scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    camera = game.get("camera") as Camera3D
    var player := game.get("player") as CharacterBody3D
    var flora := game.get_node_or_null("CityFlora") as Node3D
    if camera == null or player == null or flora == null:
        _fail("World camera/player/flora missing")
        return
    var fern := flora.get_node_or_null("HorizonCommonsHeroFern") as Node3D
    if fern == null or fern.position.distance_to(HERO_POSITION) > 0.02:
        _fail("Source-authored planted fern is not in the fixed garden bed")
        return
    var menu := game.get_node_or_null("GameMenus") as CanvasLayer
    var hud := game.get_node_or_null("HUD") as CanvasLayer
    if menu != null:
        menu.call("hide_for_game")
    if hud != null:
        hud.visible = false
    game.set_process(false)
    player.set_physics_process(false)
    player.global_position = HERO_POSITION + Vector3(0, 0.5, -2.3)
    var city := game.get("city_details") as Node3D
    city.call("set_focus", HERO_POSITION)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
    var clock: Node = game.get("day_night") as Node
    clock.call("set_hour", 12.1)
    camera.global_position = Vector3(186.4, 0.92, 26.0)
    camera.look_at(HERO_POSITION + Vector3(0.45, 0.24, 0.38), Vector3.UP)
    await _settle()
    if not _capture("horizon-fern-daylight-real-godot.png"):
        return
    clock.call("set_hour", 19.3)
    game.get("street_lights").call("set_focus", HERO_POSITION)
    camera.global_position = Vector3(190.4, 0.90, 31.6)
    camera.look_at(HERO_POSITION + Vector3(0.35, 0.23, 0.35), Vector3.UP)
    await _settle()
    if not _capture("horizon-fern-dusk-real-godot.png"):
        return
    print("HORIZON_FERN_CAPTURE PASS: two true framebuffer views of photographed source model")
    quit(0)

func _settle() -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    await process_frame
    await RenderingServer.frame_post_draw

func _capture(name: String) -> bool:
    var photo := root.get_texture().get_image() as Image
    if photo == null or photo.is_empty() or photo.get_width() < 1100 or photo.get_height() < 600:
        _fail("Invalid actual framebuffer for " + name)
        return false
    var path := DIRECTORY + "/" + name
    if photo.save_png(path) != OK or FileAccess.get_file_as_bytes(path).size() < 16000:
        _fail("Screenshot empty or could not be saved: " + name)
        return false
    print("FERN PHOTO: ", path, " ", photo.get_width(), "x", photo.get_height())
    return true
