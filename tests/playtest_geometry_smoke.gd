extends SceneTree
## Regressions from first *real* Windows playtest: indoor camera flythrough,
## third-person wall occlusion, detached facades and rectangular shopkeepers.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("PLAYTEST_GEOMETRY_SMOKE: " + why)
	quit(1)

func _verify() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Main playable world does not import")
		return
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails")
	var venues := world.get_node_or_null("SocialVenues")
	var rooms := world.get_node_or_null("Interiors")
	var camera: Camera3D = world.get("camera")
	var player: CharacterBody3D = world.get("player")
	if city == null or venues == null or rooms == null or player == null or camera == null:
		_fail("Real city, camera, avatar, venue or interior missing")
		return
	# The player and the ordinary club contact used to be three box meshes.
	var avatar := player.get_node_or_null("Visual")
	if avatar == null or not avatar.has_method("update_motion"):
		_fail("Player is missing the authored animation controller")
		return
	var rig: Skeleton3D = avatar.get("skeleton")
	var mixer: AnimationPlayer = avatar.get("animations")
	if rig == null or rig.find_bone("RightHand") < 0 or mixer == null or not mixer.has_animation(&"walk"):
		_fail("Player is missing the skinned humanoid and an authored gait")
		return
	var original_seed: int = int(root.get_node("GameSession").get("world_seed"))
	var exterior: Vector3 = venues.call("venue_position", "static_room")
	player.global_position = exterior
	city.call("set_focus", exterior)
	world.call("_toggle_interior")
	if str(rooms.call("active_site_id")) != "static_room":
		_fail("Club H entrance no longer works")
		return
	if camera.global_position.distance_to(player.global_position) > 6.5:
		_fail("Entering club sends camera across distant off-map interior space")
		return
	var contact := (rooms.get("_room") as Node3D).get_node_or_null("ContactHumanoid")
	if contact == null or int(contact.call("get_visual_stats")["articulated_limbs"]) != 4:
		_fail("Club still shows generic three-box rectangle contact")
		return
	# Save/restore inside the club must reconstruct the same camera destination,
	# not interpolate through 800m of empty map.
	var session := root.get_node("GameSession")
	var packed: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not bool(session.call("is_valid_snapshot", packed)):
		_fail("Indoor save format regressed")
		return
	world.call("_apply_snapshot", packed)
	if not bool(rooms.call("is_inside")) or camera.global_position.distance_to(player.global_position) > 6.5:
		_fail("Loading inside a club leaves the camera far away")
		return
	player.global_position = rooms.call("get_entry_point")
	world.call("_toggle_interior")
	if bool(rooms.call("is_inside")) or player.global_position.distance_to(exterior) > 0.01:
		_fail("Exiting club did not return to recorded street position")
		return
	if camera.global_position.distance_to(player.global_position) > 12.0:
		_fail("Club exit camera still flies through 950m of empty space")
		return
	world.call("_process", 0.016)
	if camera.global_position.distance_to(player.global_position) > 12.0:
		_fail("Next gameplay frame reintroduced void-looking camera flythrough")
		return
	# Club exit also must restore a physically supported player, not just
	# move the camera. Advance actual Godot physics so we catch falling through
	# unloaded ground rather than asserting a one-frame teleport position.
	for frame in range(30):
		await physics_frame
	if player.global_position.y < 0.52 or not player.is_on_floor():
		_fail("Player actually fell through the ground after leaving the club")
		return
	# Test actual third-person occlusion against a deliberately placed real
	# collision wall along the camera arm (not an aesthetic-only mesh).
	var focus: Vector3 = world.call("_camera_focus")
	var desired: Vector3 = world.call("_camera_goal")
	var obstacle := StaticBody3D.new()
	obstacle.name = "RegressionCameraOccluder"
	obstacle.collision_layer = 1
	obstacle.collision_mask = 1
	obstacle.position = focus.lerp(desired, 0.45)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 3.0)
	shape_node.shape = shape
	obstacle.add_child(shape_node)
	world.add_child(obstacle)
	await physics_frame
	var clipped: Vector3 = world.call("_camera_clearance", focus, desired)
	if focus.distance_to(clipped) > focus.distance_to(desired) - 1.2:
		_fail("Third-person camera does not stop before a collidable wall")
		return
	world.call("_snap_camera")
	if camera.global_position.distance_to(focus) > focus.distance_to(desired) - 1.2:
		_fail("Camera snapping bypassed collision clipping")
		return
	obstacle.queue_free()
	await process_frame
	# The generated real buildings must touch their advertised business walls.
	# Sample the interior and exterior districts, including seeded parcels.
	var plan = load("res://scripts/world_plan.gd")
	var manifest: Dictionary = session.call("get_world_manifest")
	for cell in [Vector2i(-3, -3), Vector2i(-1, 1), Vector2i(1, -3),
			Vector2i(2, 1), Vector2i(-4, 1), Vector2i(1, -4),
			Vector2i(3, 1), Vector2i(1, 3)]:
		if not str(plan.landmark_for_block(cell.x, cell.y)).is_empty():
			continue
		var center := Vector3((float(cell.x) + 0.5) * 58.0, 0.0,
			(float(cell.y) + 0.5) * 58.0)
		city.call("set_focus", center)
		var loaded: Dictionary = city.get("_loaded")
		var chunk: Node3D = loaded.get(cell)
		if chunk == null:
			_fail("Cannot stream district lot " + str(cell))
			return
		var profiles: Array = manifest["blocks"]["%d,%d" % [cell.x, cell.y]]
		for index in range(2):
			var profile: Dictionary = profiles[index]
			var x := center.x + (-10.5 if index == 0 else 10.5)
			var z := center.z - float(plan.PUBLIC_FACADE_SETBACK) + float(profile["depth"]) / 2.0
			var y := float(profile["height"]) / 2.0 + 0.15
			var grounded := false
			for child in chunk.get_children():
				if child is StaticBody3D and child.position.distance_to(Vector3(x, y, z)) < 0.02:
					grounded = true
					break
			if not grounded:
				_fail("Building collision is detached from storefront plane: " + str(cell) + " index " + str(index))
				return
	if int(session.get("world_seed")) != original_seed:
		_fail("Camera or lot fixes altered saved seed")
		return
	print("PLAYTEST_GEOMETRY_SMOKE PASS: club H exit camera, geometry occlusion, human host and unified fronts")
	quit(0)
