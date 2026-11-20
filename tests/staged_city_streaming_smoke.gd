extends SceneTree
## Regression for staged chunk building. Does not replace Windows frame profiling.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("STAGED_CITY_SMOKE: " + reason)
	quit(1)

func _geometry_signature(chunk: Node3D) -> Dictionary:
	var result := {"solid": 0, "mesh": 0, "instances": 0, "signs": 0, "façades": 0}
	var pending: Array[Node] = [chunk]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is StaticBody3D:
			result["solid"] += 1
		elif node is MeshInstance3D:
			result["mesh"] += 1
		elif node is MultiMeshInstance3D:
			var batches := (node as MultiMeshInstance3D).multimesh
			if batches != null:
				result["instances"] += batches.instance_count
		elif node is Label3D:
			result["signs"] += 1
		if node.name.begins_with("PhotorealFrontage_"):
			result["façades"] += 1
		for child in node.get_children():
			pending.append(child)
	return result

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable scene unavailable")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("The live world, streaming city or save session is missing")
		return
	var block := Vector2i(3, 1) # Authored Horizon Gardens, outside spawn ring
	var cancel_block := Vector2i(3, -3) # Far outside the new focus ring
	var loaded: Dictionary = city.get("_loaded")
	if loaded.has(block):
		_fail("Test lot was unexpectedly loaded at origin")
		return
	var old_seed: int = int(session.get("world_seed"))
	var old_manifest: Dictionary = session.call("get_world_manifest")
	var signature: String = WorldPlan.manifest_signature(old_manifest)

	# First of the staged tasks must create two real physical building shells,
	# while leaving both expensive façades and all batched details uncommitted.
	var before: Dictionary = city.call("get_streaming_stats")
	if bool(city.call("_run_build_stage", block)):
		_fail("First stage incorrectly completed an entire neighborhood block")
		return
	var staging: Dictionary = city.get("_staging")
	if not staging.has(block) or loaded.has(block):
		_fail("Partially prepared lot was published as a completed chunk")
		return
	var partial: Node3D = staging[block]["node"]
	var shells := 0
	for child in partial.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			var shape := body.get_child(0) as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				_fail("Staged building lacks a matched box collider")
				return
			shells += 1
	if shells != 2:
		_fail("Both building colliders must exist before decorative mesh stages")
		return
	var after_first: Dictionary = city.call("get_streaming_stats")
	if int(after_first["stage_steps"]) != int(before["stage_steps"]) + 1 or int(after_first["loads"]) != int(before["loads"]):
		_fail("One stage advanced multiple completed chunk builds")
		return
	if bool(city.call("_run_build_stage", block)):
		_fail("Second stage should build only one parcel")
		return
	if (city.get("_staging") as Dictionary)[block]["node"] != partial:
		_fail("Subsequent stages replaced the original collision shell")
		return

	# A superseded predictive request must remove unfinished geometry; an
	# emergency arrival must instead finish its existing work in place.
	city.call("_run_build_stage", cancel_block)
	city.call("set_focus", Vector3(203.0, 0.0, 87.0))
	if not (city.get("_loaded") as Dictionary).has(block):
		_fail("Synchronous destination failed to finish partially staged lot")
		return
	if (city.get("_staging") as Dictionary).has(block) or (city.get("_staging") as Dictionary).has(cancel_block):
		_fail("Completed/stale staging state was not discarded")
		return
	var original: Node3D = (city.get("_loaded") as Dictionary)[block]
	if original != partial:
		_fail("A forced arrival duplicated the staged colliders instead of completing them")
		return
	var before_reload := _geometry_signature(original)
	if int(before_reload["solid"]) != 2 or int(before_reload["instances"]) < 40:
		_fail("Completed staged lot lost its solid buildings or visual material batches: " + str(before_reload))
		return

	city.call("set_focus", Vector3(-203.0, 0.0, -203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(block):
		_fail("Remote travel left the distant lot loaded")
		return
	city.call("set_focus", Vector3(203.0, 0.0, 87.0))
	var recreated: Node3D = (city.get("_loaded") as Dictionary)[block]
	var after_reload := _geometry_signature(recreated)
	if before_reload != after_reload:
		_fail("Seeded geometry changed when a staged block was reloaded: %s vs %s" % [before_reload, after_reload])
		return
	# Locking streaming (e.g. while indoors) must not silently discard
	# a pending forecast forever when the same focus is requested on return.
	var resume_focus := Vector3(87.0, 0.0, 87.0)
	var resume_velocity := Vector3(-50.0, 0.0, 0.0)
	city.call("request_focus", resume_focus, resume_velocity)
	if int(city.call("get_streaming_stats")["pending_blocks"]) < 1:
		_fail("Expected predictive blocks before the streaming pause")
		return
	city.call("set_streaming_enabled", false)
	if int(city.call("get_streaming_stats")["pending_blocks"]) != 0:
		_fail("Paused city retained an active speculative queue")
		return
	city.call("set_streaming_enabled", true)
	city.call("request_focus", resume_focus, resume_velocity)
	if int(city.call("get_streaming_stats")["pending_blocks"]) < 1:
		_fail("Streaming resume did not reconstruct the cancelled forecast")
		return
	if int(session.get("world_seed")) != old_seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("Staged loading mutated save seed or authored world manifest")
		return
	print("STAGED_CITY_SMOKE PASS: early physical shells, bounded stage progress, no duplicates, cancellation and deterministic reload")
	quit(0)
