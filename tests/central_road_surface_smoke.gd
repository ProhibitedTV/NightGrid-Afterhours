extends SceneTree
## The citywide network supersedes the original central-only road overlay.
## Preserve junction, coverage, and save checks independently of the full-grid smoke.
const Plan = preload("res://scripts/world_plan.gd")
const Road = preload("res://scripts/photo_road_network.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("CENTRAL_ROAD_PBR_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable world scene missing")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var roadway := world.get_node_or_null("PhotoRoadNetwork") as Node3D
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if roadway == null or city == null or session == null or roadway.get_child_count() != 2:
		_fail("Shared two-mesh road network or save session missing")
		return
	if world.has_node("CentralExchangeScannedRoadway"):
		_fail("Retired duplicate Central Exchange road overlay is still installed")
		return
	var rects: Array[Rect2] = roadway.call("rectangles")
	# Sample the complete old pilot's central square and approaches,
	# including the crossing bands formerly omitted by the overlay.
	for i in range(-84, 85):
		for j in range(-84, 85):
			var at := Vector2(float(i)*.5+.125, float(j)*.5+.125)
			if minf(absf(at.x), absf(at.y)) >= 6.9:
				continue
			var hits := 0
			for rect in rects:
				if rect.has_point(at):
					hits += 1
			if hits != 1:
				_fail("Central road coverage gap or overlap at " + str(at))
				return
	for child in roadway.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or mesh.get_child_count() != 0 or not (mesh.mesh is ArrayMesh):
			_fail("Road network is not visual-only")
			return
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null or not mat.normal_enabled or mat.albedo_texture == null or mat.normal_texture == null or mat.roughness_texture == null or mat.metallic > .02:
			_fail("Missing dielectric photo PBR maps")
			return
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not is_equal_approx(vertex.y, Road.Y) or vertex.y >= .020:
				_fail("Shared road must remain below Central Exchange markings")
				return
	# The permanent city, signal, intersection and save layout are untouched.
	var original: Dictionary = session.call("get_world_manifest")
	var saved_signature: String = Plan.manifest_signature(original)
	var original_seed: int = int(session.get("world_seed"))
	var snapshot: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not bool(session.call("is_valid_snapshot", snapshot)):
		_fail("Road-surface-only art invalidated the save")
		return
	world.call("_apply_snapshot", snapshot)
	if int(session.get("world_seed")) != original_seed or Plan.manifest_signature(session.call("get_world_manifest")) != saved_signature:
		_fail("Photo-road upgrade modified seed/parcel manifest on restore")
		return
	if not is_instance_valid(city.get_node_or_null("../CentralExchangeHero")):
		_fail("Pilot displaced original working pedestrian/traffic junction")
		return
	print("CENTRAL_ROAD_PBR_SMOKE PASS: shared two-mesh network covers junction, no duplicate overlay, stable saves")
	quit(0)
