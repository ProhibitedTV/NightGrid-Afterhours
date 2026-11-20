extends SceneTree
## Structural regression for #31. Audits actual visible hatch triangles, not
## just component counts; Windows camera orbit is still required for art QA.
func _initialize() -> void:
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("KESTREL_REAR_CLOSURE_SMOKE: " + message)
	quit(1)

func _point_id(point: Vector3) -> String:
	return "%d/%d/%d" % [
		roundi(point.x * 10000.0),
		roundi(point.y * 10000.0),
		roundi(point.z * 10000.0)]

func _edge_id(a: Vector3, b: Vector3) -> String:
	var first := _point_id(a)
	var second := _point_id(b)
	return first + "|" + second if first < second else second + "|" + first

func _verify_hatch(hero: Node3D) -> bool:
	var hatch := hero.get_node_or_null("RearHatchSolid") as MeshInstance3D
	if hatch == null or not (hatch.mesh is ArrayMesh):
		_fail("Missing actual painted trunk/hatch closing mesh")
		return false
	if hatch.material_override == null or hatch.material_override is not StandardMaterial3D:
		_fail("Rear hatch must share the vehicle PBR paint")
		return false
	var arrays: Array = hatch.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size() < 80 or vertices.size() % 3 != 0 or normals.size() != vertices.size():
		_fail("Rear deck has missing triangle panels or normals")
		return false
	var edge_counts := {}
	var rear_cap := 0
	var top_normals := 0
	for start in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[start]
		var b: Vector3 = vertices[start + 1]
		var c: Vector3 = vertices[start + 2]
		var triangle_normal := (b - a).cross(c - a)
		if triangle_normal.length() <= 0.00001:
			_fail("Degenerate rear hatch triangle creates a camera hole")
			return false
		triangle_normal = triangle_normal.normalized()
		if normals[start].dot(triangle_normal) < 0.2:
			_fail("Rear hatch surface normal mismatch at triangle %d: face=%s smooth=%s a=%s b=%s c=%s" % [start / 3, triangle_normal, normals[start], a, b, c])
			return false
		for pair in [[a, b], [b, c], [c, a]]:
			var key := _edge_id(pair[0], pair[1])
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
		# Smoothed vertex normals need not align 1:1 with the geometric
		# surface normal. Audit actual triangle winding for cap/deck faces.
		if a.z >= 2.30 and b.z >= 2.30 and c.z >= 2.30 and triangle_normal.z > 0.9:
			rear_cap += 1
		if a.y > 0.5 and b.y > 0.5 and c.y > 0.5 and triangle_normal.y > 0.6:
			top_normals += 1
	for key in edge_counts:
		if int(edge_counts[key]) != 2:
			_fail("Open, unpaired hatch mesh edge: " + str(key))
			return false
	if rear_cap < 2 or top_normals < 2:
		_fail("Rear cap/roof topology missing or inverted (rear cap %d, upper facets %d)" % [rear_cap, top_normals])
		return false
	var bulkhead := hero.get_node_or_null("RearCabinBulkhead") as MeshInstance3D
	var shelf := hero.get_node_or_null("RearParcelShelf") as MeshInstance3D
	if bulkhead == null or shelf == null or bulkhead.mesh == null:
		_fail("Opaque rear passenger bulkhead / cargo parcel shelf missing")
		return false
	if absf(bulkhead.position.z - 1.16) > 0.01:
		_fail("Trunk bulkhead no longer closes the opening behind the rear seats")
		return false
	return true

func _verify() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("No playable game scene")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var fleet: Array = world.get("cars")
	if fleet.is_empty():
		_fail("No drivable Kestrel fleet")
		return
	var car: CharacterBody3D = fleet[0]
	var hero := car.get_node_or_null("KestrelS6HeroVisual") as Node3D
	if hero == null or not _verify_hatch(hero):
		return
	var stats: Dictionary = hero.call("get_visual_stats")
	if int(stats["body_panels"]) < 2 or int(stats["hero_components"]) > 220:
		_fail("Rear deck was omitted or component budget exceeded: " + str(stats))
		return
	var before: Dictionary = world.call("_capture_snapshot")
	world.call("_apply_snapshot", before)
	if car.get_node_or_null("KestrelS6HeroVisual/RearHatchSolid") == null:
		_fail("Car lost closed hatch after save restore")
		return
	var police: CharacterBody3D = world.call("_create_car",
		Vector3(25.0, 1.0, 20.0), Color("78939d"), true)
	var pursuit := police.get_node_or_null("KestrelS6HeroVisual") as Node3D
	if pursuit == null or not _verify_hatch(pursuit):
		return
	police.queue_free()
	print("KESTREL_REAR_CLOSURE_SMOKE PASS: solid paired-edge trunk, outward top/rear normals, bulkhead, saves and police variant")
	quit(0)
