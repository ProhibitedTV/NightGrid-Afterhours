extends SceneTree
## Video-inspired renderer Filmic / ACES / AgX comparison in Godot 4.7.2.
## Tests state, not image quality or RTX 3060 performance.
const GameInput = preload("res://scripts/game_input.gd")
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("RENDER_COMPARISON_SMOKE: " + reason)
	quit(1)

func _check() -> void:
	GameInput.install()
	var engine_info: Dictionary = Engine.get_version_info()
	if int(engine_info.get("major", 0)) != 4 or int(engine_info.get("minor", 0)) != 7 or int(engine_info.get("patch", 0)) != 2:
		_fail("Expected matching stable Godot 4.7.2: " + str(engine_info))
		return
	if str(ProjectSettings.get_setting("physics/3d/physics_engine")) != "GodotPhysics3D":
		_fail("Engine upgrade switched legacy physical collision solver: " + str(ProjectSettings.get_setting("physics/3d/physics_engine")))
		return
	if str(ProjectSettings.get_setting("rendering/rendering_device/driver.windows")) != "vulkan":
		_fail("Windows renderer changed from Forward+/Vulkan baseline")
		return
	if Engine.physics_ticks_per_second != 60:
		_fail("Migration changed the 60 Hz physics simulation")
		return
	var f11 := false
	for event in InputMap.action_get_events("compare_render_look"):
		if event is InputEventKey and event.physical_keycode == KEY_F11:
			f11 = true
	if not f11:
		_fail("F11 A/B comparison control missing")
		return
	for action in ["playtest_mark", "record_frame_trace", "capture_playtest_frame", "game_new", "game_save"]:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey and binding.physical_keycode == KEY_F11:
				_fail("Comparison conflicts with existing key: " + action)
				return

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Game scene not found")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var clock := world.get_node_or_null("DayNight")
	var sun := world.get("sun_light") as DirectionalLight3D
	var outer := world.get("world_environment") as WorldEnvironment
	var session := root.get_node_or_null("GameSession")
	if clock == null or sun == null or outer == null or session == null:
		_fail("Actual game lighting and saved world unavailable")
		return
	var environment := outer.environment
	var manifest_before: Dictionary = session.call("get_world_manifest")
	var signature := WorldPlan.manifest_signature(manifest_before)
	var seed := int(session.get("world_seed"))
	clock.call("set_hour", 22.1167)
	var hour_before := float(clock.get("hour"))
	var former_shadow_distance := sun.directional_shadow_max_distance
	var former_angle := sun.light_angular_distance
	if str(clock.call("get_render_profile")) != "filmic_baseline":
		_fail("Player's existing look must remain the default")
		return
	if environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC or environment.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
		_fail("Original night Filmic+ambient baseline changed")
		return
	var default_fog := environment.fog_density
	clock.call("set_render_comparison", true)
	if str(clock.call("get_render_profile")) != "sky_aces_experiment" or not bool(clock.call("is_render_comparison_enabled")):
		_fail("A/B experimental profile did not activate")
		return
	if environment.tonemap_mode != Environment.TONE_MAPPER_ACES or environment.ambient_light_source != Environment.AMBIENT_SOURCE_SKY:
		_fail("Godot 4.7.2 ACES tonemapper or actual sky ambient light not applied")
		return
	if environment.ambient_light_sky_contribution < 0.75 or environment.ambient_light_sky_contribution > 0.9:
		_fail("Experimental sky ambient contribution outside intended range")
		return
	if environment.tonemap_exposure <= 1.0 or environment.fog_density >= default_fog:
		_fail("Night look did not change exposure and readable fog depth")
		return
	if sun.directional_shadow_max_distance >= former_shadow_distance:
		_fail("Experimental sun shadow cost/distance was not bounded")
		return
	if environment.ssil_enabled or environment.sdfgi_enabled or environment.volumetric_fog_enabled:
		_fail("Heavy GI, SSIL and volumetric fog must stay off by default on RTX 3060-class machines")
		return
	clock.call("set_hour", 12.0)
	if environment.tonemap_mode != Environment.TONE_MAPPER_ACES or environment.ambient_light_source != Environment.AMBIENT_SOURCE_SKY:
		_fail("Day/night tick incorrectly reset the experimental render profile")
		return
	clock.call("set_hour", hour_before)
	var agx_mode: String = str(clock.call("cycle_render_profile"))
	if agx_mode != "sky_agx_experiment" or environment.tonemap_mode != Environment.TONE_MAPPER_AGX:
		_fail("F11 failed to activate real Godot 4.7.2 AgX tonemapping")
		return
	if environment.ambient_light_source != Environment.AMBIENT_SOURCE_SKY or not bool(clock.call("is_render_comparison_enabled")):
		_fail("AgX preview must keep the sky fill and remain an experiment")
		return
	clock.call("set_hour", 12.0)
	if environment.tonemap_mode != Environment.TONE_MAPPER_AGX:
		_fail("Day/night tick unexpectedly reset AgX")
		return
	clock.call("set_hour", hour_before)
	if str(clock.call("cycle_render_profile")) != "filmic_baseline":
		_fail("F11 cycling did not return to baseline from AgX")
		return
	clock.call("set_render_comparison", false)
	if str(clock.call("get_render_profile")) != "filmic_baseline":
		_fail("Cannot return to baseline for matched screenshot comparison")
		return
	if environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC or environment.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
		_fail("A/B toggle did not restore old color/tonemapping")
		return
	if not is_equal_approx(environment.fog_density, default_fog) or not is_equal_approx(environment.tonemap_exposure, 1.0):
		_fail("Toggling off changed prior fog/exposure")
		return
	if not is_equal_approx(sun.directional_shadow_max_distance, former_shadow_distance) or not is_equal_approx(sun.light_angular_distance, former_angle):
		_fail("Original sun shadow settings were not restored")
		return
	if not is_equal_approx(float(clock.get("hour")), hour_before):
		_fail("Lighting A/B changed the game clock")
		return
	if int(session.get("world_seed")) != seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("Visual A/B changed saved city")
		return
	print("RENDER_COMPARISON_SMOKE PASS: Godot 4.7.2 Filmic > ACES > AgX > Filmic, sky ambient, reversible fog/shadow, untouched seed/save")
	quit(0)
