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
	var environment := world.get("world_environment") as WorldEnvironment
	if city == null or clock == null or lamps == null or puddles == null or environment == null:
		_fail("Visual world nodes not initialized")
		return
	if not environment.environment.ssr_enabled or not environment.environment.glow_enabled:
		_fail("Wet reflections and neon bloom have not been enabled")
		return
	if not environment.environment.ssao_enabled or not environment.environment.fog_enabled:
		_fail("Contact shadows and distance haze must default to enabled")
		return
	if environment.environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC:
		_fail("Filmic highlight response must be active")
		return
	var city_stats: Dictionary = city.call("get_city_stats")
	if int(city_stats.get("authored_lots", 0)) != 112:
		_fail("Fixed 112-lot building plan was not applied")
		return
	if int(puddles.call("patch_count")) != 16:
		_fail("The authored wet-street patches must exist")
		return
	for patch in puddles.get_children():
		if not patch is MeshInstance3D or not patch.mesh is ArrayMesh:
			_fail("Every puddle must be an irregular mesh, not a raised box")
			return
		if patch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < 30:
			_fail("Puddles require triangulated curved shorelines")
			return
	var library = load("res://scripts/material_library.gd")
	if library.texture_count() < 5 or library.normal_count() < 5 or library.roughness_count() < 5:
		_fail("Expected cached albedo, normal and roughness texture families")
		return
	var sidewalk_count := 0
	var shared: StandardMaterial3D
	for child in world.get_children():
		if not str(child.name).begins_with("PhotographicSidewalk_"):
			continue
		var slab := child as MeshInstance3D
		var material := slab.material_override as StandardMaterial3D
		if material == null or material.albedo_texture == null or material.normal_texture == null or material.roughness_texture == null:
			_fail("Sidewalk requires three source photo channels")
			return
		if shared == null:
			shared = material
		if shared != material or not material.normal_enabled or material.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_GREEN or not material.uv1_world_triplanar or material.uv1_scale != Vector3(0.5,0.5,0.5) or material.metallic != 0.0:
			_fail("Preserve shared world-scale dielectric concrete")
			return
		if not material.albedo_texture.resource_path.ends_with("concrete_base_1k.jpg") or not material.normal_texture.resource_path.ends_with("concrete_normal_1k.jpg") or not material.roughness_texture.resource_path.ends_with("concrete_arm_1k.png"):
			_fail("Expected actual bundled photographed concrete")
			return
		if not (slab.mesh is BoxMesh) or (slab.mesh as BoxMesh).size != Vector3(42.0,0.14,42.0) or not is_equal_approx(slab.position.y,0.07):
			_fail("Existing sidewalk footprint or height changed")
			return
		sidewalk_count += 1
	if sidewalk_count != 64:
		_fail("Expected 64 unchanged parcel slabs with photo concrete")
		return
	var curb := library.surface("PHOTO_CURB",Color("bfc0bd")) as StandardMaterial3D
	if curb.albedo_texture != shared.albedo_texture or curb.normal_texture != shared.normal_texture or curb.roughness_texture != shared.roughness_texture:
		_fail("Curb and sidewalk should share the same photo maps")
		return
	lamps.call("set_focus", Vector3.ZERO)
	clock.call("set_hour", 12.0)
	if environment.environment.fog_density >= 0.006:
		_fail("Daytime haze must be lighter than nighttime haze")
		return
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
	for ix in range(-4, 4):
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
