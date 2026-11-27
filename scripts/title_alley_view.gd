extends Node
## Live title camera uses the existing paused playable world, not a second city.
## Only the visual clock, camera, streaming focus and temporary fog are touched.
const ORIGIN = Vector3(-87.0, 0.0, 87.0)
const SHOT = Vector3(0.20, 1.75, -10.6)
const LOOK = Vector3(0.35, 2.6, 6.5)
const CYCLE_SECONDS = 240.0
var active := false
var motion_enabled := true
var _world: Node3D
var _camera: Camera3D
var _previous_camera: Camera3D
var _clock: Node
var _city: Node
var _hud: CanvasLayer
var _environment: Environment
var _fog: FogVolume
var _fog_material: FogMaterial
var _saved_hour := 0.0
var _saved_day := 0
var _saved_hud := true
var _saved_volumetric := false
var _saved_fog_length := 64.0
var _restore_focus := Vector3.ZERO
var _elapsed := 0.0
var _clock_tick := 0.0

func begin(world: Node3D, animate: bool, allow_headless: bool = false) -> bool:
	if active:
		return true
	if not is_instance_valid(world) or not get_tree().paused:
		return false
	if DisplayServer.get_name() == "headless" and not allow_headless:
		return false
	# Don't stream away a loaded interior or the opening office set.
	if bool(world.call("_inside_opening_hq")) or bool(world.get("interiors").call("is_inside")):
		return false
	_world = world
	_city = world.get("city_details")
	_clock = world.get("day_night")
	_previous_camera = world.get_viewport().get_camera_3d()
	_hud = world.get_node_or_null("HUD") as CanvasLayer
	var world_env: WorldEnvironment = world.get("world_environment")
	var actor: Node3D = world.call("_actor")
	if not is_instance_valid(_city) or not is_instance_valid(_clock) or not is_instance_valid(_previous_camera) or not is_instance_valid(actor) or world_env == null:
		return false
	_environment = world_env.environment
	_saved_hour = float(_clock.get("hour"))
	_saved_day = int(_clock.get("day_index"))
	_saved_volumetric = _environment.volumetric_fog_enabled
	_saved_fog_length = _environment.volumetric_fog_length
	_restore_focus = actor.global_position
	motion_enabled = animate
	process_mode = Node.PROCESS_MODE_ALWAYS
	_city.call("set_focus", ORIGIN)
	if not is_instance_valid(_city.find_child("BrickwaterServiceAlley", true, false)):
		_city.call("set_focus", _restore_focus)
		return false
	_world.get("street_lights").call("set_focus", ORIGIN)
	_camera = Camera3D.new()
	_camera.name = "TitleAlleyCamera"
	_camera.fov = 70.0
	_camera.near = 0.08
	_camera.far = 720.0
	_world.add_child(_camera)
	_camera.global_position = ORIGIN + SHOT
	_camera.look_at(ORIGIN + LOOK)
	_camera.make_current()
	if _hud != null:
		_saved_hud = _hud.visible
		_hud.hide()
	# Local volumetrics only on Forward+. Respect the existing fog option.
	if RenderingServer.get_current_rendering_method() == "forward_plus" and _environment.fog_enabled:
		_environment.volumetric_fog_enabled = true
		_environment.volumetric_fog_length = 36.0
		_fog = FogVolume.new()
		_fog.name = "TitleAlleyMist"
		_fog.size = Vector3(3.3, 2.4, 11.0)
		_fog_material = FogMaterial.new()
		_fog_material.density = 0.07
		_fog_material.albedo = Color("b1c1cb")
		var noise := FastNoiseLite.new()
		noise.frequency = 0.10
		var texture := NoiseTexture3D.new()
		texture.width = 32
		texture.height = 32
		texture.depth = 32
		texture.noise = noise
		texture.seamless = true
		_fog_material.density_texture = texture
		_fog.material = _fog_material
		_world.add_child(_fog)
		_fog.global_position = ORIGIN + Vector3(0.2, 1.3, 1.8)
	_elapsed = 0.0
	_clock_tick = 0.0
	active = true
	_set_visual_hour(22.1)
	set_process(motion_enabled)
	return true

func _set_visual_hour(hour: float) -> void:
	_clock.call("set_hour", hour)
	_world.get("venue_system").call("set_hour", hour)
	_world.get("civic_services").call("set_hour", hour)

func _process(delta: float) -> void:
	if not active or not motion_enabled:
		return
	_elapsed = fposmod(_elapsed + minf(delta, 0.1), CYCLE_SECONDS)
	var cycle := _elapsed * TAU / CYCLE_SECONDS
	_camera.global_position = ORIGIN + SHOT + Vector3(sin(cycle * 3.0) * 0.16, sin(cycle * 2.0) * 0.035, sin(cycle) * 0.12)
	_camera.look_at(ORIGIN + LOOK)
	if is_instance_valid(_fog):
		_fog.global_position = ORIGIN + Vector3(0.2 + sin(cycle * 5.0) * 0.36, 1.3, 1.8 + sin(cycle * 3.0) * 0.8)
		_fog_material.density = 0.07 + sin(cycle * 4.0) * 0.018
	_clock_tick += delta
	if _clock_tick >= 0.25:
		_clock_tick = 0.0
		_set_visual_hour(fposmod(22.1 + _elapsed * 24.0 / CYCLE_SECONDS, 24.0))

func finish() -> void:
	if not active:
		return
	active = false
	set_process(false)
	if is_instance_valid(_fog):
		_fog.hide()
		_fog.queue_free()
		_fog = null
	if is_instance_valid(_environment):
		_environment.volumetric_fog_enabled = _saved_volumetric
		_environment.volumetric_fog_length = _saved_fog_length
	if is_instance_valid(_world) and is_instance_valid(_city):
		_city.call("set_focus", _restore_focus)
		_world.get("street_lights").call("set_focus", _restore_focus)
		_clock.set("day_index", _saved_day)
		_set_visual_hour(_saved_hour)
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
		_camera = null
	if is_instance_valid(_hud):
		_hud.visible = _saved_hud

func _exit_tree() -> void:
	# Normal menu transitions call finish before gameplay resumes.
	if active and is_instance_valid(_world) and not _world.is_queued_for_deletion():
		finish()
