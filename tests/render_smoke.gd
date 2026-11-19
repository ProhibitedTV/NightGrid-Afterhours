extends SceneTree
## Full scene preflight for fixed world/material/night-light contracts.
func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _check() -> void:
	if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "forward_plus":
		_fail("Forward+ renderer must be selected for SSR")
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Main scene failed to load")
		return
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	var clock := world.get_node_or_null("DayNight")
	var lamps := world.get_node_or_null("NightLighting")
	var puddles := world.get_node_or_null("WetStreets")
	var environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if city == null or clock == null or lamps == null or puddles == null or environment == null:
		_fail("Visual world nodes not initialized")
		return
	if not environment.environment.ssr_enabled or not environment.environment.glow_enabled:
		_fail("Wet reflections and neon bloom have not been enabled")
		return
	var city_stats: Dictionary = city.call("get_city_stats")
	if int(city_stats.get("authored_lots", 0)) != 64:
		_fail("Fixed 64-lot building plan was not applied")
		return
	if int(puddles.call("patch_count")) != 16:
		_fail("The authored wet-street patches must exist")
		return
	var library = load("res://scripts/material_library.gd")
	if library.texture_count() < 5:
		_fail("Expected cached PBR texture families")
		return
	lamps.call("set_focus", Vector3.ZERO)
	clock.call("set_hour", 12.0)
	if int(lamps.call("active_light_count")) != 0:
		_fail("Streetlights must switch fully OFF in daylight")
		return
	clock.call("set_hour", 0.0)
	var nighttime: int = lamps.call("active_light_count")
	if nighttime < 2 or nighttime > 8:
		_fail("Expected 2..8 pooled real night lights, got %d" % nighttime)
		return
	clock.call("set_hour", 12.0)
	if int(lamps.call("active_light_count")) != 0:
		_fail("Night-light pool failed to deactivate at noon")
		return
	var plan = load("res://scripts/world_plan.gd")
	for ix in range(-3, 3):
		for iz in range(-3, 3):
			if plan.landmark_for_block(ix, iz) != "":
				continue
			for side in range(2):
				var profile: Dictionary = plan.lot_profile(ix, iz, side)
				if not profile.has("height") or not profile.has("material"):
					_fail("Missing fixed parcel profile at (%d,%d) side %d" % [ix, iz, side])
					return
	print("RENDER_SMOKE PASS: ", city_stats, " textures=", library.texture_count(),
		" wet_patches=", puddles.call("patch_count"), " night_lights=", nighttime)
	quit(0)
