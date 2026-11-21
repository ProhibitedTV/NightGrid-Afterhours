extends SceneTree
## Exact West Docks architectural pilot, based on the real screenshot of the
## Dock Watch Desk at (-4,-1) lot 0. This checks topology and gameplay safety,
## not human approval of Windows Vulkan appearance or frame-time performance.
const WorldPlan = preload("res://scripts/world_plan.gd")
const TARGET = Vector2i(-4, -1)

func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("DOCK_WATCH_FIDELITY_SMOKE: " + why)
	quit(1)

func _facade(city: Node3D) -> Node3D:
	var loaded: Dictionary = city.get("_loaded")
	var chunk: Node3D = loaded.get(TARGET)
	if chunk == null:
		return null
	return chunk.get_node_or_null("PhotorealFrontage_-4_-1_0")

func _verify() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Real playable scene unavailable")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("World city or saved session missing")
		return
	var stable_seed := int(session.get("world_seed"))
	var manifest: Dictionary = session.call("get_world_manifest")
	var stable_signature := WorldPlan.manifest_signature(manifest)
	var civic: Node3D = world.get_node("CivicServices")
	var dock_site: Dictionary = civic.call("site_by_id", "dock_watch")
	if int(dock_site.get("ix", 0)) != -4 or int(dock_site.get("iz", 0)) != -1 or int(dock_site.get("side", -1)) != 0:
		_fail("Dock Watch civic building/address moved from its established lot")
		return
	if WorldPlan.district_at(Vector3(-203.0, 0.0, -29.0)) != "WEST DOCKS":
		_fail("Dock Watch is no longer in West Docks")
		return
	city.call("set_focus", Vector3(-203.0, 0.0, -29.0))
	var facade := _facade(city)
	if facade == null:
		_fail("Real Dock Watch chunk contains no authored photo-material architecture")
		return
	if str(facade.get("storefront_name")) != "DOCK WATCH DESK" or str(facade.get("district")) != "WEST DOCKS":
		_fail("Photographed cladding belongs to the wrong building or lost its civic identity")
		return
	var profile: Dictionary = (manifest["blocks"]["-4,-1"] as Array)[0]
	var expected_x := -213.5
	var expected_z := -43.88
	if absf(facade.position.x - expected_x) > 0.02 or absf(facade.position.z - expected_z) > 0.02:
		_fail("New facade detached from the real civic storefront: " + str(facade.position))
		return
	if absf(float(facade.get("building_width")) - float(profile["width"])) > 0.01 or absf(float(facade.get("building_height")) - float(profile["height"])) > 0.01:
		_fail("New architecture changed the saved building profile")
		return
	var data: Dictionary = facade.call("get_facade_stats")
	if int(data.get("architecture_surfaces", 0)) < 5 or int(data.get("window_openings", 0)) < 8:
		_fail("Dock Watch is still a flat procedural block: " + str(data))
		return
	if int(data.get("real_pbr_maps", 0)) < 3:
		_fail("Dock Watch needs 2K photographed steel 3-channel PBR maps: " + str(data))
		return
	var glass := facade.call("_surface_material", "GLASS") as StandardMaterial3D
	if glass == null or glass.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		_fail("Docks windows are still flat opaque panels")
		return
	for section in ["Facade_GLASS", "Facade_DARK_ROOM", "Facade_CLADDING"]:
		if not facade.has_node(section):
			_fail("Dock Watch has unbacked windows or no scanned cladding: " + section)
			return
	var side := facade.get_node_or_null("AvenueFacingArchitecture")
	var finish := facade.get_node_or_null("DockWatchSealedCornerAndRoof")
	if side == null or finish == null:
		_fail("Dock Watch exterior side/solid roof is not enclosed")
		return
	var side_data: Dictionary = side.call("get_avenue_stats")
	var finish_data: Dictionary = finish.call("get_finish_stats")
	if int(side_data.get("windows", 0)) < 8 or int(finish_data.get("sealed_corner_returns", 0)) != 4 or int(finish_data.get("solid_roof_edges", 0)) != 4:
		_fail("Dock Watch side view or scanned roof remains an incomplete silhouette")
		return
	if int(data.get("collision_bodies", -1)) != 0 or int(data.get("local_lights", -1)) != 0 or int(finish_data.get("new_collisions", -1)) != 0:
		_fail("Visual replacement introduced physics or unbudgeted lamps")
		return
	# A physical collision shape is preserved *without* an underlying solid
	# BoxMesh, which would occlude the real window openings.
	var chunk: Node3D = (city.get("_loaded") as Dictionary)[TARGET]
	var collider_count := 0
	for child in chunk.get_children():
		if child is StaticBody3D and child.name == "PreservedBuildingCollision":
			var body := child.get_node_or_null("BuildingCollider") as CollisionShape3D
			if body == null or not (body.shape is BoxShape3D):
				_fail("Original collision volume is lost")
				return
			if not child.get_children().all(func(node: Node) -> bool: return not node is MeshInstance3D):
				_fail("Opaque render mesh remains behind transparent window topology")
				return
			collider_count += 1
	if collider_count != 1:
		_fail("Expected exactly one unchanged physical Dock Watch building shell")
		return
	var stats_before: Dictionary = facade.call("get_facade_stats")
	city.call("set_focus", Vector3(205.0, 0.0, 205.0))
	await process_frame
	city.call("set_focus", Vector3(-203.0, 0.0, -29.0))
	await process_frame
	var rebuilt := _facade(city)
	if rebuilt == null or rebuilt.call("get_facade_stats") != stats_before:
		_fail("Dock Watch architecture changed after streaming unload/reload")
		return
	var snapshot: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not bool(session.call("is_valid_snapshot", snapshot)):
		_fail("New façade broke the v1 save contract")
		return
	if int(session.get("world_seed")) != stable_seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != stable_signature:
		_fail("Art substitution changed saved city seed or building manifest")
		return
	print("DOCK_WATCH_FIDELITY_SMOKE PASS: photographed 2K steel/roof, real apertures, unchanged civic anchor and save/collision")
	quit(0)
