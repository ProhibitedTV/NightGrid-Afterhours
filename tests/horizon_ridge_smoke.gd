extends SceneTree
## Opt-in engineering blockout: physical route, terrace and retaining limits.
const Plan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("HORIZON_RIDGE: " + message)
	quit(1)

func _verify() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame
	var edge := world.get_node("MorrowBayPerimeter")
	var stats: Dictionary = edge.call("get_perimeter_stats")
	if int(stats.get("ridge_area_m2", 0)) != 11664 or int(stats["road_gates"]) != 35:
		_fail("Expected connected terrace and one opened road end: " + str(stats))
		return
	var space := world.get_world_3d().direct_space_state
	var entrance := PhysicsRayQueryParameters3D.create(Vector3(240, 1, 0), Vector3(260, 1, 0), 1)
	if not space.intersect_ray(entrance).is_empty():
		_fail("Original east road remains blocked")
		return
	for x in [244.9, 245.5, 260.0, 280.0, 300.0, 330.0, 350.0]:
		var expected := float(edge.call("ridge_height", x))
		for z in [-35.0, -9.0, 0.0, 9.0, 35.0]:
			# The original road/sidewalk may differ at the overlap itself.
			if x < 246.0 and z != 0.0:
				continue
			var floor_query := PhysicsRayQueryParameters3D.create(Vector3(x, 15, z), Vector3(x, -3, z), 1)
			var hit := space.intersect_ray(floor_query)
			if hit.is_empty() or absf(float(hit["position"].y) - expected) > 0.2:
				_fail("Missing or mismatched graded collision at " + str(Vector2(x,z)))
				return
	if not is_equal_approx(float(edge.call("ridge_height", 353.5)) - float(edge.call("ridge_height", 245.5)), 7.2):
		_fail("Expected 7.2 m elevation gain")
		return
	for x in range(246, 353):
		var grade := float(edge.call("ridge_height", float(x)+1.0)) - float(edge.call("ridge_height", float(x)))
		if grade < -0.001 or grade > 0.101:
			_fail("Unexpected longitudinal grade")
			return
	if not is_equal_approx(float(edge.call("ridge_height", 346.0)), float(edge.call("ridge_height", 352.0))):
		_fail("Upper landing must be level")
		return
	# Confirm that the curved center and both edges hit the road itself.
	for x in [260.0, 289.5, 309.5, 333.5, 348.5]:
		var alignment: Vector2 = edge.call("ridge_alignment",x)
		var height := float(edge.call("ridge_height",x))
		for z in [alignment.x,alignment.x-alignment.y+0.5,alignment.x+alignment.y-0.5]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,height+2.0,z),Vector3(x,height-2.0,z),1)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or (hit["collider"] as Node).name != "Ridge_CentralAccess_Floor":
				_fail("Curved road width/collision mismatch")
				return
	var bend: Vector2 = edge.call("ridge_alignment",289.5)
	if not is_equal_approx(bend.x,-9.0):
		_fail("Curved road alignment missing")
		return
	if float(stats["ridge_summit_length_m"]) != 20.0 or float(stats["ridge_max_road_width_m"]) != 30.0:
		_fail("Summit turning space missing")
		return
	if edge.get_node_or_null("Ridge_LaneMarkings") == null:
		_fail("Missing road center markings")
		return
	# Summit overlook and sidewalk connection must be actual continuous
	# walkable geometry, not a decorative platform placed above collision.
	if int(stats.get("ridge_overlook_area_m2",0)) != 480:
		_fail("Missing 480 square metre overlook")
		return
	for x in [335.0,343.5,350.0]:
		for z in [-47.0,-36.0,-25.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,12,z),Vector3(x,5,z),1)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or (hit["collider"] as Node).name != "Ridge_OverlookPlaza_Floor" or absf(float(hit["position"].y)-7.12)>0.02:
				_fail("Missing level overlook floor")
				return
		var alignment: Vector2 = edge.call("ridge_alignment",x)
		var walk_edge := alignment.x-alignment.y-3.2
		var approach_z := (-24.0+walk_edge)*0.5
		var approach_ray := PhysicsRayQueryParameters3D.create(Vector3(x,12,approach_z),Vector3(x,5,approach_z),1)
		var approach_hit := space.intersect_ray(approach_ray)
		if approach_hit.is_empty() or (approach_hit["collider"] as Node).name != "Ridge_OverlookApproach_Floor":
			_fail("Missing sidewalk-to-overlook connection")
			return
	var anchor := edge.get_node_or_null("HorizonRidge_OverlookAnchor") as Marker3D
	var sign_node := edge.get_node_or_null("HorizonRidge_OverlookSign") as Label3D
	if anchor == null or sign_node == null or absf(anchor.position.y-7.12)>0.02 or (-anchor.basis.z).dot(Vector3.LEFT)<0.99:
		_fail("Missing west-facing capture anchor or wall-mounted sign")
		return
	for pair in [
		[Vector3(348, 8, 0), Vector3(360, 8, 0)],
		[Vector3(300, 5, 49), Vector3(300, 5, 59)],
		[Vector3(300, 5, -49), Vector3(300, 5, -59)],
		[Vector3(240, 1, 25), Vector3(250, 1, 25)]
	]:
		var wall_query := PhysicsRayQueryParameters3D.create(pair[0], pair[1], 1)
		var hit := space.intersect_ray(wall_query)
		if hit.is_empty() or not (hit["collider"] as Node).name.begins_with("Ridge_") and not (hit["collider"] as Node).name.begins_with("HorizonRidge_"):
			_fail("Missing terrace or retained approach wall")
			return
	if Plan.GRID_RADIUS != 4 or Plan.WORLD_LAYOUT_VERSION != 2:
		_fail("Pilot changed canonical grid")
		return
	print("HORIZON_RIDGE PASS: connected eastern terrace, continuous collision, retained approach and outer boundaries")
	quit(0)
