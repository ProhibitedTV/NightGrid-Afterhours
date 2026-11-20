extends SceneTree
## Source-level and engine-level checks for the first non-BoxMesh 3D
## Central Exchange architecture. NOT a substitute for visual screenshot review.
func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("CENTRAL_FRONTAGES_SMOKE: " + reason)
	quit(1)

func _find_facade(city: Node3D, ix: int, iz: int, which: int) -> Node3D:
	var chunks: Dictionary = city.get("_loaded")
	var chunk: Node3D = chunks.get(Vector2i(ix, iz))
	if chunk == null:
		return null
	return chunk.get_node_or_null("PhotorealFrontage_%d_%d_%d" % [ix, iz, which])

func _check() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	if main == null:
		_fail("Playable scene missing")
		return
	var world: Node3D = main.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("Real streaming city or saved manifest not available")
		return
	var original_seed: int = int(session.get("world_seed"))
	var original_manifest: Dictionary = session.call("get_world_manifest")
	var original_signature := str(load("res://scripts/world_plan.gd").manifest_signature(original_manifest))
	var original_counts: Array[Dictionary] = []
	for query in [[-1, 0, 1, "BRICKWATER"], [0, 0, 0, "AFTERHOURS"]]:
		var ix: int = query[0]
		var iz: int = query[1]
		var which: int = query[2]
		city.call("set_focus", Vector3((float(ix) + 0.5) * 58.0, 0.0, 24.0))
		var facade := _find_facade(city, ix, iz, which)
		if facade == null:
			_fail("Missing world-place façade in block %s" % str(query))
			return
		var stats: Dictionary = facade.call("get_facade_stats")
		if int(stats["architecture_surfaces"]) < 5 or int(stats["window_openings"]) < 8:
			_fail("Streetfront is not a coherent multi-surface authored architectural mesh: %s" % stats)
			return
		if int(stats["shopfront_openings"]) != 4 or int(stats["canopy_segments"]) != 20:
			_fail("Recessed retail shopfront and swept canopy require stable topology")
			return
		if int(stats["reveal_faces"]) < 32:
			_fail("Openings are missing recessed jamb and sill geometry")
			return
		if int(stats["collision_bodies"]) != 0 or int(stats["local_lights"]) != 0:
			_fail("Art pass added unapproved physical obstacles or lights")
			return
		if str(facade.get("district")) != str(query[3]):
			_fail("Fashionable architecture has been put in wrong district")
			return
		var expected_x := -18.5 if ix < 0 else 18.5
		if absf(facade.position.x - expected_x) > 0.01 or absf(facade.position.z - 14.12) > 0.02:
			_fail("Building façade detached from actual streetfront world setback: %s" % facade.position)
			return
		# A real separate custom vertex topology—not dozens of BoxMesh cards.
		for child in facade.get_children():
			if child is MeshInstance3D:
				if not (child.mesh is ArrayMesh):
					_fail("Non-authored primitive/BoxMesh used in new reference-facing architectural façade")
					return
				var array_mesh := child.mesh as ArrayMesh
				if array_mesh.get_surface_count() != 1:
					_fail("Expected material-sorted coherent geometric surfaces")
					return
				var vertices: PackedVector3Array = array_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if vertices.size() < 6:
					_fail("Degenerate architecture surface")
					return
			if child is CollisionObject3D:
				_fail("Façade unexpectedly changed existing building physics")
				return
		if not facade.has_node("ExistingShopIdentity"):
			_fail("Saved neighborhood store identity was dropped")
			return
		var root_chunk: Node3D = (city.get("_loaded") as Dictionary)[Vector2i(ix, iz)]
		var shell_found := false
		for item in root_chunk.get_children():
			if item is StaticBody3D and absf(item.position.x - expected_x) < 0.01:
				shell_found = true
				break
		if not shell_found:
			_fail("Prior stable building collision shell missing")
			return
		var scanned_base: String = "res://assets/pbr/polyhaven/brick_wall_001_"
		var is_imported: bool = ResourceLoader.exists(scanned_base + "diffuse_2k.jpg")
		if str(query[3]) == "BRICKWATER" and is_imported and int(stats["real_pbr_maps"]) != 3:
			_fail("Imported photographed PBR triplet is not bound to the real wall material")
			return
		original_counts.append(stats)
	# Switching streaming focus unloads/reconstructs this location using
	# the SAME world manifest; photoscan/PBR art must not depend on RNG state.
	city.call("set_focus", Vector3(210.0, 0.0, 210.0))
	await process_frame
	city.call("set_focus", Vector3.ZERO)
	await process_frame
	for j in range(2):
		var ix := -1 if j == 0 else 0
		var which := 1 if j == 0 else 0
		var facade := _find_facade(city, ix, 0, which)
		if facade == null or facade.call("get_facade_stats") != original_counts[j]:
			_fail("Reference architecture changed after streaming in a different order")
			return
	var snapshot: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not bool(session.call("is_valid_snapshot", snapshot)):
		_fail("Facade substitution invalidated v1 save data")
		return
	world.call("_apply_snapshot", snapshot)
	if int(session.get("world_seed")) != original_seed:
		_fail("Visual-only architecture altered world seed")
		return
	var signature := str(load("res://scripts/world_plan.gd").manifest_signature(session.call("get_world_manifest")))
	if signature != original_signature:
		_fail("Art upgrade silently mutated saved buildings/locations")
		return
	print("CENTRAL_FRONTAGES_SMOKE PASS: two unique true-geometry facades, working shop IDs, stable collision, unchanged saves")
	quit(0)
