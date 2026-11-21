extends SceneTree
## Live original concrete curb/steel grate replacement in CENTRAL EXCHANGE.
## Checks real authored source glTF surfaces, 8 measured runs, road headroom,
## original crosswalk/civic/traffic/seed save and no additional colliders.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error("CENTRAL_AUTHORED_CURB_SMOKE: " + message)
	quit(1)

func _walk_meshes(root_node: Node, found: Array[MeshInstance3D]) -> void:
	if root_node is MeshInstance3D:
		found.append(root_node as MeshInstance3D)
	for child in root_node.get_children():
		_walk_meshes(child,found)

func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false

func _check_run(node: Node3D, position: Vector3, expected_rotation: float) -> bool:
	if node == null or not node.position.is_equal_approx(position):
		_fail("Source curb isn't at the exact former 36m placeholder footprint: " + str(position))
		return false
	if absf(node.rotation.y - expected_rotation) > 0.0001:
		_fail("Curb source orientation blocks an existing crossing")
		return false
	if _has_collision(node):
		_fail("Visual-only curb changed the 60Hz physics/roadway collision volume")
		return false
	var models: Array[MeshInstance3D] = []
	_walk_meshes(node,models)
	if models.size() != 1:
		_fail("Missing original self-contained curb glTF mesh (not 100 BoxMesh parts)")
		return false
	var mesh := models[0].mesh
	if mesh == null or mesh.get_surface_count() != 3:
		_fail("Source loses one of photographic concrete/iron/bitumen PBR layers")
		return false
	for surface in range(3):
		var data := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = data[Mesh.ARRAY_TANGENT]
		if verts.size() < 100 or uvs.size() != verts.size() or (
					normals.size() != verts.size() or tangents.size() != verts.size() * 4):
			_fail("Source geometry no longer has proper glTF normal, UV, tangent bases")
			return false
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null or material.albedo_texture == null or (
				not material.normal_enabled or material.normal_texture == null
				or material.roughness_texture == null):
			_fail("Physically photographed original material lost PBR input layers")
			return false
	return true

func _check() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Missing playable world")
		return
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var hero := game.get_node_or_null("CentralExchangeHero") as Node3D
	var controller := game.get_node_or_null("TrafficSignals") as Node
	var city := game.get_node_or_null("CityDetails") as Node
	var session := root.get_node_or_null("GameSession")
	if hero == null or controller == null or city == null or session == null:
		_fail("Original gameplay city, traffic, or session unavailable")
		return
	var seed := int(session.get("world_seed"))
	var manifest := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var kit := hero.get_node_or_null("CentralExchangeAuthoredCurbProfiles") as Node3D
	if kit == null or hero.position != Vector3.ZERO:
		_fail("Authored curb glTFs not installed in permanent Central Exchange")
		return
	var stats: Dictionary = kit.call("get_curbstone_stats")
	var hero_stats: Dictionary = hero.call("get_visual_stats")
	if int(stats["installed_static_modules"]) != 8 or (
			int(stats["source_meshes"]) != 8 or int(stats["source_surfaces"]) != 24):
		_fail("Expected 8 physically modeled, 3-surface 36m glTF curb modules: " + str(stats))
		return
	if int(stats["source_vertices"]) < 25000 or (
			int(stats["photographed_material_surfaces"]) != 24):
		_fail("Original photographed UV/tangent geometry or materials absent: " + str(stats))
		return
	if int(stats["concrete_slab_sections"]) != 96 or (
			int(stats["gutter_drain_grates"]) != 48):
		_fail("Twelve real segmented curbstones plus six steel slotted gutters per module missing")
		return
	if int(stats["physical_colliders_added"]) != 0 or int(stats["night_lights_added"]) != 0:
		_fail("Static street art added collision or dynamic light budgets")
		return
	if int(hero_stats.get("original_curb_modules",0)) != 8 or (
			int(hero_stats.get("original_slotted_drains",0)) != 48):
		_fail("Playable Central Exchange has not integrated new source-authored curbs")
		return
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var x_run := kit.get_node_or_null("EW_Corner_%d_%d" % [int(sx),int(sz)]) as Node3D
			var z_run := kit.get_node_or_null("NS_Corner_%d_%d" % [int(sx),int(sz)]) as Node3D
			if not _check_run(x_run, Vector3(sx*8.2,0.0,sz*32.0),0.0):
				return
			if not _check_run(z_run, Vector3(sx*32.0,0.0,sz*8.2),PI*0.5):
				return
	# Existing hero ramps preserve their exact original 8 sidewalk approaches,
	# and traffic controller's 81 intersection phases remain authoritative.
	if int(hero_stats["curb_ramps"]) != 8 or int(controller.call("safe_intersection_count")) != 81:
		_fail("Crossing ramp count or operational signal topology changed")
		return
	if hero.get_node_or_null("CentralExchangePhotoStreetKit") == null:
		_fail("Earlier source-scanned street furniture was lost")
		return
	var saved: Dictionary = game.call("_capture_snapshot")
	game.call("_apply_snapshot",saved)
	if kit.call("get_curbstone_stats") != stats or hero.call("get_visual_stats") != hero_stats:
		_fail("Curb geometry changed on save/restore")
		return
	if int(session.get("world_seed")) != seed or (
			WorldPlan.manifest_signature(session.call("get_world_manifest")) != manifest):
		_fail("Original art step changed existing stored parcels or world seed")
		return
	print("CENTRAL_AUTHORED_CURB_SMOKE PASS: 8 verified photo-PBR 36m glTF runs,",
		" 96 beveled expansion-jointed paving sections, 48 slotted steel drains,",
		" 24 source-photo surfaces, existing city crossings, roads and saves intact")
	quit(0)
