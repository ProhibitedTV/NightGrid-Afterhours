extends SceneTree
## Regression for issue #34: visible physical city borders, real coastal
## scenery and no rerolling existing saved city geography.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("COASTAL_PERIMETER_SMOKE: " + message)
	quit(1)

func _verify() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("The playable scene is missing")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var edge := world.get_node_or_null("MorrowBayPerimeter") as Node3D
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if edge == null or city == null or session == null:
		_fail("Physical city perimeter, streamed city or save session is missing")
		return
	var stats: Dictionary = edge.call("get_perimeter_stats")
	if int(stats["barriers"]) != 4 or int(stats["road_gates"]) != 36:
		_fail("Four continuous solid limits and 36 marked road endings are required: " + str(stats))
		return
	if int(stats["sea_surfaces"]) != 2 or int(stats["landscapes"]) != 2:
		_fail("North/west harbor and east/south terrestrial horizon are incomplete: " + str(stats))
		return
	if int(stats["port_piers"]) != 7 or int(stats["industrial_landmarks"]) != 13:
		_fail("Working harbor piers and grounded industrial yard are missing: " + str(stats))
		return
	var north: MeshInstance3D = edge.get_node_or_null("NorthQuay_OpenHarbor")
	var west: MeshInstance3D = edge.get_node_or_null("WestDocks_OpenHarbor")
	var east: MeshInstance3D = edge.get_node_or_null("HorizonGardens_DistantRidgeland")
	if north == null or west == null or east == null:
		_fail("The coast and ridge must exist as real render geometry")
		return
	if north.position.z + (north.mesh as PlaneMesh).size.y * 0.5 > -WorldPlan.city_bounds() - 12.0:
		_fail("Northern water is covering a playable street")
		return
	if west.position.x + (west.mesh as PlaneMesh).size.x * 0.5 > -WorldPlan.city_bounds() - 12.0:
		_fail("Western water is covering a playable street")
		return
	for water in [north, west]:
		var shore := water as MeshInstance3D
		var plane := shore.mesh as PlaneMesh
		var material := shore.material_override as ShaderMaterial
		if plane == null or plane.subdivide_width < 12 or material == null:
			_fail("Harbor rendering lost authored water geometry or shader material")
			return
		if material.shader == null or material.shader.resource_path != "res://assets/shaders/morrow_harbor_water.gdshader":
			_fail("Harbor shader is missing or no longer shared by both ocean surfaces")
			return
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var limit := WorldPlan.city_bounds() + 13.5
	var rays := [
		{"name": "NorthQuay_QuaySafetyWall",
			"a": Vector3(0.0, 1.0, -limit + 5.0), "b": Vector3(0.0, 1.0, -limit - 5.0)},
		{"name": "WestDocks_QuaySafetyWall",
			"a": Vector3(-limit + 5.0, 1.0, 0.0), "b": Vector3(-limit - 5.0, 1.0, 0.0)},
		{"name": "HorizonGardens_HillsideSoundwall",
			"a": Vector3(limit - 5.0, 1.0, 0.0), "b": Vector3(limit + 5.0, 1.0, 0.0)},
		{"name": "Southworks_SecurityWall",
			"a": Vector3(0.0, 1.0, limit - 5.0), "b": Vector3(0.0, 1.0, limit + 5.0)}
	]
	for entry in rays:
		var query := PhysicsRayQueryParameters3D.create(entry["a"], entry["b"])
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		if hit.is_empty() or not (hit["collider"] is StaticBody3D):
			_fail("Player/vehicle can move into the unsupported void: " + entry["name"])
			return
		var body := hit["collider"] as StaticBody3D
		if body.name != entry["name"] or body.get_node_or_null("CollisionMatchedBulkhead") == null:
			_fail("Physical road end is invisible or mismatched: " + entry["name"] + " / " + body.name)
			return
	if WorldPlan.GRID_RADIUS != 4 or WorldPlan.WORLD_LAYOUT_VERSION != 2:
		_fail("Outskirts changed the canonical district/save layout")
		return
	var saved_manifest: Dictionary = session.call("get_world_manifest")
	if not WorldPlan.valid_manifest(saved_manifest) or saved_manifest != city.get("world_manifest"):
		_fail("Coastal perimeter altered the player's stored city blocks")
		return
	if int((city.call("get_city_stats") as Dictionary)["buildings"]) != 112:
		_fail("Coastal redesign changed authored building inventory")
		return
	print("COASTAL_PERIMETER_SMOKE PASS: 4 visible solid boundaries, 36 terminal roads, 2 harbor seas, 2 horizons, 7 piers, immutable save layout")
	quit(0)
