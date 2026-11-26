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
	for x in [244.9, 245.5, 260.0, 300.0, 350.0]:
		var floor_query := PhysicsRayQueryParameters3D.create(Vector3(x, 3, 0), Vector3(x, -3, 0), 1)
		var hit := space.intersect_ray(floor_query)
		if hit.is_empty() or absf(float(hit["position"].y) + 0.08) > 0.2:
			_fail("Missing continuous collision floor at " + str(x))
			return
	for pair in [
		[Vector3(348, 1, 0), Vector3(360, 1, 0)],
		[Vector3(300, 1, 49), Vector3(300, 1, 59)],
		[Vector3(300, 1, -49), Vector3(300, 1, -59)],
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
