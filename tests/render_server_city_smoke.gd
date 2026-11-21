extends SceneTree
## Video-guided performance regression: static city visuals no longer allocate
## a MultiMeshInstance3D scene node per material bucket. Tests the REAL world,
## collision-preserving streamed chunks, reload equivalence and RID cleanup.
## GPU frame-time claims still require an RTX 3060 Windows playtest.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("RENDER_SERVER_CITY_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable source scene unavailable")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("Game city or save session missing")
		return
	var world_seed := int(session.get("world_seed"))
	var manifest: Dictionary = session.call("get_world_manifest")
	var signature := WorldPlan.manifest_signature(manifest)
	var global_owner := city.get_node_or_null("GlobalVisualBatches")
	if global_owner == null or not global_owner.has_method("get_batch_stats"):
		_fail("City-wide painted roads have no live RenderingServer owner")
		return
	var road_batches: Dictionary = global_owner.call("get_batch_stats")
	if int(road_batches.get("batches", 0)) < 10 or int(road_batches.get("instances", 0)) < 150:
		_fail("Global road visuals were not batched: " + str(road_batches))
		return
	if global_owner.get_child_count() != 0:
		_fail("Global road drawing still allocates per-batch children")
		return

	var block := Vector2i(3, 1)
	if not WorldPlan.landmark_for_block(block.x, block.y).is_empty():
		_fail("Test location unexpectedly became a landmark")
		return
	city.call("set_focus", Vector3(203.0, 0.0, 87.0))
	var loaded: Dictionary = city.get("_loaded")
	if not loaded.has(block):
		_fail("Required destination chunk did not load")
		return
	var chunk: Node3D = loaded[block]
	var owner: Node = chunk.get_node_or_null("VisualBatches")
	if owner == null or not owner.has_method("get_batch_stats"):
		_fail("Streamed city lot is still using visual nodes per batch")
		return
	var stat: Dictionary = owner.call("get_batch_stats")
	if int(stat.get("batches", 0)) < 8 or int(stat.get("instances", 0)) < 40:
		_fail("Chunk lost batched material visuals: " + str(stat))
		return
	if int(stat["retained_meshes"]) != int(stat["batches"]) or int(stat["retained_materials"]) != int(stat["batches"]):
		_fail("Backing RIDs might outlive meshes or materials")
		return
	if owner.get_child_count() != 0:
		_fail("Chunk still has a child per material bucket")
		return
	var physics_count := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			physics_count += 1
		elif child is MultiMeshInstance3D or child.name.begins_with("Detail_"):
			_fail("Per-material render scene node escaped the server batching path")
			return
	if physics_count != 2:
		_fail("A visual-only optimization altered physical parcel shells")
		return
	var metrics: Dictionary = city.call("get_streaming_stats")
	if str(metrics.get("render_batch_backend", "")) != "RenderingServer" or int(metrics.get("render_batches_created", 0)) < int(stat["batches"]):
		_fail("Renderer provenance/performance counters missing")
		return
	# Unloading chunks releases their RID owner by the same queue_free that
	# previously released per-material MultiMeshInstance3D nodes.
	var previous_owner := weakref(owner)
	city.call("set_focus", Vector3(-203.0, 0.0, -203.0))
	await process_frame
	await process_frame
	if (city.get("_loaded") as Dictionary).has(block):
		_fail("Old city chunk was not unloaded")
		return
	if previous_owner.get_ref() != null:
		_fail("Server RID owner leaked across chunk unload")
		return
	city.call("set_focus", Vector3(203.0, 0.0, 87.0))
	var new_chunk: Node3D = (city.get("_loaded") as Dictionary)[block]
	var new_owner := new_chunk.get_node_or_null("VisualBatches")
	if new_owner == null or new_owner == owner:
		_fail("Unloaded renderer batches were not reconstructed")
		return
	var recreated: Dictionary = new_owner.call("get_batch_stats")
	if recreated != stat:
		_fail("Batched world art changed on deterministic stream reload: %s vs %s" % [stat, recreated])
		return
	if int(session.get("world_seed")) != world_seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("RenderingServer migration changed saved world")
		return
	print("RENDER_SERVER_CITY_SMOKE PASS: server batches, original collisions, complete RID-owner teardown, deterministic reload")
	quit(0)
