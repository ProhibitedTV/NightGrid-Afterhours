extends SceneTree
## Checks source images and switching. Real renderer seam/lighting QA is manual.
const Clock = preload("res://scripts/day_night.gd")
const Skies = preload("res://scripts/skybox_library.gd")
const GameInput = preload("res://scripts/game_input.gd")
class Sink extends Node:
	var calls := 0
	func set_night_factor(_v: float) -> void:
		calls += 1

func _initialize() -> void:
	create_timer(45.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")

func _check(value: bool, message: String) -> bool:
	if not value:
		push_error("SKYBOX_CYCLE_SMOKE: " + message)
		quit(1)
	return value

func _verify() -> void:
	GameInput.install()
	var f2 := false
	for event in InputMap.action_get_events("sky_weather_cycle"):
		if event is InputEventKey and event.physical_keycode == KEY_F2:
			f2 = true
	if not _check(f2, "F2 weather preview action missing"):
		return
	var pairs: Dictionary = Skies.FILES
	if not _check(pairs.size() == 8, "Expected eight original coastal sky textures"):
		return
	for name in pairs:
		var path: String = Skies.texture_path(str(name))
		if not _check(ResourceLoader.exists(path), "Missing original texture " + path):
			return
		var texture := load(path) as Texture2D
		if not _check(texture != null and texture.get_width() == 1536 and texture.get_height() == 768, "Sky texture dimension or importer " + path):
			return
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var sink := Sink.new()
	root.add_child(sink)
	var clock := Clock.new()
	root.add_child(clock)
	clock.set_process(false)
	clock.configure(env, sun, sink, null)
	clock.paused = true
	if not _check(clock.active_sky_preset() == "evening_clear" and env.environment.sky.sky_material is PanoramaSkyMaterial, "Default sunset panorama at 19:15"):
		return
	clock.set_hour(12.0)
	if not _check(clock.active_sky_preset() == "clear_day", "Bright noon palette"):
		return
	var updates: int = clock.get("_art_sky_updates")
	clock.set_hour(13.0)
	if not _check(clock.get("_art_sky_updates") == updates, "Do not reallocate sky material for every clock tick"):
		return
	if not _check(not clock.set_weather("blizzard"), "Invalid weather should be rejected"):
		return
	if not _check(clock.set_weather("cloudy") and clock.active_sky_preset() == "afternoon_clouds", "Cloudy daytime panorama"):
		return
	if not _check(clock.set_weather("overcast") and clock.active_sky_preset() == "overcast_day", "Overcast daytime panorama"):
		return
	if not _check(clock.set_weather("rain") and clock.active_sky_preset() == "storm_day", "Rain uses storm-band picture"):
		return
	var rainy_energy: float = sun.light_energy
	if not _check(clock.set_weather("storm") and sun.light_energy < rainy_energy, "Storm darkens physical directional sun further"):
		return
	clock.set_hour(6.0)
	if not _check(clock.active_sky_preset() == "storm_day", "Storm overrides dawn"):
		return
	clock.set_weather("clear")
	if not _check(clock.active_sky_preset() == "dawn_clear", "Clear dawn panorama"):
		return
	clock.set_hour(23.0)
	if not _check(clock.active_sky_preset() == "moonlit_night", "Moonlit night panorama"):
		return
	clock.set_original_sky_enabled(false)
	if not _check(clock.active_sky_preset() == "procedural" and env.environment.sky.sky_material is ProceduralSkyMaterial, "Fallback to old procedural sky"):
		return
	clock.set_original_sky_enabled(true)
	if not _check(clock.active_sky_preset() == "moonlit_night" and env.environment.sky.sky_material is PanoramaSkyMaterial, "Restored sky artwork"):
		return
	clock.cycle_render_profile()
	if not _check(env.environment.tonemap_mode == Environment.TONE_MAPPER_ACES and clock.active_sky_preset() == "moonlit_night", "F11 comparison still functions"):
		return
	print("SKYBOX_CYCLE_SMOKE PASS: eight original WebP textures, 4 clock phases, 5 weather choices, no redundant loads, procedural fallback, F2/F11")
	quit(0)
