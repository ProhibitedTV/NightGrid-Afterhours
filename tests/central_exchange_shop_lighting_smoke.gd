extends SceneTree
## Real playable Central Exchange after-dark physical-source lighting regression.
## No detached debugging scene, additional OmniLight3D nodes or artificial
## screenshot claims: exact imported source lenses illuminate real city walls.
const WorldPlan = preload("res://scripts/world_plan.gd")
const EXPECTED_Z = 29.0 - WorldPlan.PUBLIC_FACADE_SETBACK + 1.08
const EXPECTED_Y = 0.15 + 3.07 - 0.16
const LIGHT_LIMIT = 8

func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("CENTRAL_EXCHANGE_RETAIL_LIGHT_SMOKE: " + reason)
	quit(1)

func _walk_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for item in node.get_children():
		_walk_meshes(item, meshes)

func _validate_actual_source(chunk: Node3D, ix: int, which: int) -> bool:
	var facade := chunk.get_node_or_null("PhotorealFrontage_%d_0_%d" % [ix, which])
	if facade == null:
		_fail("The actual exterior-retail asset isn't in the permanently saved city")
		return false
	var store: Node3D = facade.get_node_or_null("Original3DWalkInRetailVestibule") as Node3D
	if store == null:
		_fail("Pooled light would be emitted where no modeled 3D shop exists")
		return false
	var source := store.get_node_or_null("SourceAuthoredPhotoGLTF")
	if source == null:
		_fail("The actual original 3D photo-PBR glTF has been replaced")
		return false
	var meshes: Array[MeshInstance3D] = []
	_walk_meshes(source, meshes)
	if meshes.size() != 1:
		_fail("Source-authored integrated shop material mesh disappeared")
		return false
	var mesh: Mesh = meshes[0].mesh
	if mesh == null or mesh.get_surface_count() != 6:
		_fail("Imported model lost its six real photo/glass/fixture surfaces")
		return false
	var lamps: StandardMaterial3D = mesh.surface_get_material(5) as StandardMaterial3D
	if lamps == null or not lamps.emission_enabled or lamps.emission_energy_multiplier <= 0.0:
		_fail("New practical light has no visible original emissive ceiling lens")
		return false
	var housing_vertices: PackedVector3Array = mesh.surface_get_arrays(5)[Mesh.ARRAY_VERTEX]
	var near_lens := false
	for v in housing_vertices:
		if absf(v.z - 1.08) < 0.2 and absf(v.y - 3.07) < 0.15:
			near_lens = true
			break
	if not near_lens:
		_fail("Emissive glTF geometry is detached from 1.08m-deep real light fixture")
		return false
	return true

func _check() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable main scene missing")
		return
	var game: Node3D = packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var light_system: Node3D = game.get_node_or_null("NightLighting") as Node3D
	var clock: Node = game.get_node_or_null("DayNight")
	var city: Node3D = game.get_node_or_null("CityDetails") as Node3D
	var traffic: Node = game.get_node_or_null("TrafficSignals")
	var session: Node = root.get_node_or_null("GameSession")
	if light_system == null or clock == null or city == null or traffic == null or session == null:
		_fail("Live world clock, city, light pool, session, or signal controller absent")
		return
	var before_seed: int = int(session.get("world_seed"))
	var before_manifest: String = WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var pool: Array = light_system.get("_pool")
	var original_pool_nodes: Array = pool.duplicate()
	if pool.size() != LIGHT_LIMIT:
		_fail("Lighting upgrade allocated additional GPU lights instead of reusing 8 existing nodes")
		return
	var all_fixtures: Array = light_system.get("_fixtures")
	var portal_list: Array = []
	for item in all_fixtures:
		if str(item["kind"]) == "portal":
			portal_list.append(item)
	if portal_list.size() != 2:
		_fail("Must be exactly two permanently anchored ceiling lens sources")
		return
	for item in portal_list:
		var pos: Vector3 = item["position"]
		if not pos.is_equal_approx(Vector3(-18.5, EXPECTED_Y, EXPECTED_Z)) and (
				not pos.is_equal_approx(Vector3(18.5, EXPECTED_Y, EXPECTED_Z))):
			_fail("Pooled bright spot is floating, not mounted under real emitted lens: " + str(pos))
			return
	var focus := Vector3(0.0, 0.0, 14.12)
	city.call("set_focus", focus)
	for pilot in [
		{"cell":Vector2i(-1, 0), "ix":-1, "lot":1},
		{"cell":Vector2i(0, 0), "ix":0, "lot":0}
	]:
		var loaded: Dictionary = city.get("_loaded")
		if not loaded.has(pilot["cell"]) or not _validate_actual_source(
				loaded[pilot["cell"]], int(pilot["ix"]), int(pilot["lot"])):
			return
	light_system.call("set_focus", focus)
	clock.call("set_hour", 12.0)
	if int(light_system.call("active_light_count")) != 0:
		_fail("Retail lens spill wastes GPU time in direct daylight")
		return
	clock.call("set_hour", 0.0)
	var midnight: Dictionary = light_system.call("get_practical_light_stats")
	if int(midnight["pool_capacity"]) != LIGHT_LIMIT or int(midnight["active"]) > LIGHT_LIMIT:
		_fail("Nighttime highlights accidentally increased the limited lighting budget: " + str(midnight))
		return
	if int(midnight["available_walk_in_portals"]) != 2 or (
			int(midnight["active_walk_in_portals"]) != 2 or
			int(midnight["active_storefronts"]) < 2 or int(midnight["active_poles"]) < 1):
		_fail("Two warm interiors should share slots with live street poles and visible shop signs: " + str(midnight))
		return
	var lit_portals := 0
	var midnight_energy := 0.0
	for light in pool:
		if not light.visible:
			continue
		if light.shadow_enabled or light.omni_range > 18.01 or light.light_energy <= 0.0:
			_fail("Pooled light became shadow expensive, unbounded or unlit")
			return
		for item in portal_list:
			if light.position.is_equal_approx(item["position"]):
				lit_portals += 1
				midnight_energy += light.light_energy
				if light.omni_range > 6.3 or light.omni_range < 5.7:
					_fail("Indoor practical is lighting whole buildings instead of short doorway spill")
					return
	if lit_portals != 2 or midnight_energy < 2.0:
		_fail("Actual modeled ceiling lenses have no real nighttime floor/wall illumination")
		return
	clock.call("set_hour", 19.25)
	var dusk: Dictionary = light_system.call("get_practical_light_stats")
	if int(dusk["active_walk_in_portals"]) != 2:
		_fail("Warm dusk storefront illumination fails when it matters most")
		return
	var dusk_energy := 0.0
	for light in pool:
		if not light.visible:
			continue
		for item in portal_list:
			if light.position.is_equal_approx(item["position"]):
				dusk_energy += light.light_energy
	if dusk_energy <= 0.0 or dusk_energy > midnight_energy + 0.01:
		_fail("Light spill should transition smoothly between dusk and full night")
		return
	# Do not keep expensive indoor lights enabled across the whole city.
	light_system.call("set_focus", Vector3(203.0, 0.0, -203.0))
	light_system.call("set_night_factor", 1.0)
	var distant: Dictionary = light_system.call("get_practical_light_stats")
	if int(distant["active_walk_in_portals"]) != 0 or int(distant["active"]) > LIGHT_LIMIT:
		_fail("Central retail practical never releases its pool slot when player leaves")
		return
	city.call("set_focus", Vector3(203.0, 0.0, -203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(Vector2i(0, 0)):
		_fail("Pilot shop did not unload through original city streaming")
		return
	city.call("set_focus", focus)
	light_system.call("set_focus", focus)
	clock.call("set_hour", 0.0)
	var fresh: Dictionary = light_system.call("get_practical_light_stats")
	if int(fresh["active_walk_in_portals"]) != 2:
		_fail("Nighttime light did not return to reconstructed source-owned storefront")
		return
	for i in range(LIGHT_LIMIT):
		if pool[i] != original_pool_nodes[i]:
			_fail("Reload allocated or replaced a real-time light rather than moving a pooled node")
			return
	if int(traffic.call("safe_intersection_count")) != 81 or (
		int(session.get("world_seed")) != before_seed or
		WorldPlan.manifest_signature(session.call("get_world_manifest")) != before_manifest):
		_fail("Exterior lighting changed saved world identity or traffic system")
		return
	print("CENTRAL_EXCHANGE_RETAIL_LIGHT_SMOKE PASS: two real glTF emissive ceiling sources",
		" lighting exterior sidewalks and 3D interiors, 8 reused shadow-free lights,",
		" real dusk/noon/night transitions, shop and street illumination retained,",
		" forced city streaming and saved traffic/seed unchanged")
	quit(0)
