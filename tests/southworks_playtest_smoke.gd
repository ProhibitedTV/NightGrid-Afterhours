extends SceneTree
## Regression for real Windows playtest issues #29 and #30.
## Verify physical cargo and bins at Southworks as well as the original
## +Z-facing courier turning in every direction relative to its camera.
const PlayerScript = preload("res://scripts/player.gd")
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		Input.action_release(action)
	push_error("SOUTHWORKS_PLAYTEST_SMOKE: " + reason)
	quit(1)

func _has_solid(chunk: Node3D, position: Vector3, size: Vector3) -> bool:
	for entry in chunk.get_children():
		if not (entry is StaticBody3D):
			continue
		var body := entry as StaticBody3D
		if body.position.distance_to(position) > 0.025 or (body.collision_layer & 1) == 0:
			continue
		for collider in body.get_children():
			if not (collider is CollisionShape3D):
				continue
			var shape := collider as CollisionShape3D
			if shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.distance_to(size) <= 0.02:
				return true
	return false

func _verify_southworks(city: Node3D, block: Vector2i) -> bool:
	var center := Vector3((float(block.x) + 0.5) * WorldPlan.BLOCK_SIZE, 0.0,
		(float(block.y) + 0.5) * WorldPlan.BLOCK_SIZE)
	city.call("set_focus", center)
	var loaded: Dictionary = city.get("_loaded")
	var chunk := loaded.get(block) as Node3D
	if chunk == null:
		_fail("Southworks block could not stream: " + str(block))
		return false
	# These are the EXACT large street boxes and posts from the original
	# Southworks frontage: collision and visible geometry share extents.
	var checked := 0
	for side in [-1.0, 1.0]:
		var bin_base := center + Vector3(side * 19.5, 0.45, -12.8)
		if not _has_solid(chunk, bin_base, Vector3(0.8, 0.9, 0.8)):
			_fail("One Southworks waist-high bin is still an uncollidable decoration: " + str(bin_base))
			return false
		checked += 1
	for offset_x in [-2.0, 6.0]:
		for index in range(3):
			var x := float(index % 2) * 1.2
			var y := floorf(float(index) / 2.0) * 1.02 + 0.52
			var crate := center + Vector3(offset_x + x, y, -18.5)
			if not _has_solid(chunk, crate, Vector3.ONE):
				_fail("South Bus Works cargo stack has a see-through crate: " + str(crate))
				return false
			checked += 1
	for x in [-9.0, 9.0]:
		if not _has_solid(chunk, center + Vector3(x, 1.20, -17.5),
				Vector3(0.30, 2.3, 0.30)):
			_fail("Metal service post has no collision matching its visual size")
			return false
		checked += 1
	assert(checked == 10)
	return true

func _check() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Playable scene missing")
		return
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var city := game.get_node_or_null("CityDetails") as Node3D
	var player := game.get("player") as CharacterBody3D
	var session := root.get_node_or_null("GameSession")
	if city == null or player == null or session == null:
		_fail("Missing world player, city streamer or save session")
		return
	var seed := int(session.get("world_seed"))
	var signature := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var block := Vector2i(1, 3)
	if not _verify_southworks(city, block):
		return
	await physics_frame
	var center := Vector3(87.0, 0.0, 203.0)
	var space := game.get_world_3d().direct_space_state
	var probe := PhysicsRayQueryParameters3D.create(center + Vector3(-2.0, 0.8, -20.2),
		center + Vector3(-2.0, 0.8, -17.3))
	probe.collision_mask = 1
	var hit := space.intersect_ray(probe)
	if hit.is_empty() or not (hit.get("collider") is StaticBody3D):
		_fail("Actual Godot physics ray passes through Southworks crate")
		return
	# Leave its streaming radius and return. All ten colliders must be
	# reconstructed correctly without changing the save manifest/seed.
	city.call("set_focus", Vector3(-203.0, 0.0, -203.0))
	await process_frame
	if city.get("_loaded").has(block):
		_fail("Distant Southworks chunk failed to unload")
		return
	if not _verify_southworks(city, block):
		return
	if int(session.get("world_seed")) != seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("Collider restoration modified the saved world layout")
		return

	var visual := player.get_node_or_null("Visual") as Node3D
	if visual == null:
		_fail("Courier visual missing")
		return
	# Confirm the real source character faces +Z: both eyes are slightly
	# forward of the center of the head in the +Z direction.
	var head := visual.get_node_or_null("BreathingTorso/HeadLookRig") as Node3D
	var eye := head.get_node_or_null("LeftBlinkEye") as Node3D if head != null else null
	if eye == null or eye.position.z < 0.15:
		_fail("Character mesh forward-axis contract changed")
		return
	var tests := [
		[Vector2(0.0, -1.0), 0.0], [Vector2(0.0, 1.0), 0.0],
		[Vector2(-1.0, 0.0), 0.0], [Vector2(1.0, 0.0), 0.0],
		[Vector2(-0.7, -0.7), 0.45], [Vector2(0.7, -0.7), -0.60],
		[Vector2(0.0, -1.0), PI * 0.75], [Vector2(0.0, -1.0), -PI * 0.55]
	]
	for entry in tests:
		var axis: Vector2 = entry[0]
		var view_yaw: float = entry[1]
		var direction := Vector3(axis.x, 0.0, axis.y).rotated(Vector3.UP, view_yaw).normalized()
		var target_heading := PlayerScript.visual_yaw_for_motion(direction)
		var forward := Basis(Vector3.UP, target_heading).z
		if forward.dot(direction) < 0.999:
			_fail("Walking avatar faces camera instead of motion direction: " + str(entry))
			return
	# Do not accidentally alter physics rate while fixing render-facing.
	if int(Engine.physics_ticks_per_second) != 60:
		_fail("Courier fix changed independent 60Hz game physics")
		return
	print("SOUTHWORKS_PLAYTEST_SMOKE PASS: 10 matched solid props, physics ray, unload/reload, eight +Z avatar headings")
	quit(0)
