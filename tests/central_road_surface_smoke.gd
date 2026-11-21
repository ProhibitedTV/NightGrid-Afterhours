extends SceneTree
## Inspects the real playable scene's limited photographed roadway pilot.
## Green tests prove geometry/material contracts, not perceptual photo realism.
const Plan = preload("res://scripts/world_plan.gd")

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
	var roadway := world.get_node_or_null("CentralExchangeScannedRoadway") as Node3D
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if roadway == null or city == null or session == null:
		_fail("Photo-scan roadway, streaming city or save session missing")
		return
	var stats: Dictionary = roadway.call("get_surface_stats")
	if int(stats.get("mesh_instances", 0)) != 2 or int(stats.get("dry_quads", 0)) != 5 or int(stats.get("damp_quads", 0)) != 8:
		_fail("Roadway must use exactly two meshes: center + four dry lanes and eight damp shoulders: " + str(stats))
		return
	if int(stats.get("photographed_maps", 0)) != 3 or int(stats.get("normal_map_surfaces", 0)) != 2:
		_fail("Missing imported 2K photographed albedo/normal/roughness set")
		return
	if int(stats.get("collision_bodies", -1)) != 0 or int(stats.get("lights", -1)) != 0:
		_fail("Roadway art changed gameplay collision or night lighting")
		return
	var positions_checked := 0
	for child in roadway.get_children():
		if not (child is MeshInstance3D):
			_fail("Road material pilot must have visual-only authored meshes")
			return
		var part := child as MeshInstance3D
		if not (part.mesh is ArrayMesh) or part.mesh.get_surface_count() != 1:
			_fail("Road upgrade used BoxMesh or missing material sorted ArrayMesh")
			return
		var mat := part.material_override as StandardMaterial3D
		if mat == null or not mat.normal_enabled or mat.normal_texture == null or mat.roughness_texture == null or mat.albedo_texture == null:
			_fail("Road material must bind all three actual scanned PBR maps")
			return
		if mat.metallic > 0.02 or mat.cull_mode != BaseMaterial3D.CULL_BACK:
			_fail("Asphalt must be nonmetallic with correct upward-facing triangles")
			return
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var expected: int = 48 if child.name == "ScannedBitumenDampGutters" else 30
		if verts.size() != expected or norms.size() != expected or uvs.size() != expected or tangents.size() != expected * 4:
			_fail("Road material mesh topology or tangent UV buffers malformed: " + child.name)
			return
		for index in range(0, verts.size(), 3):
			var a: Vector3 = verts[index]
			var b: Vector3 = verts[index + 1]
			var c: Vector3 = verts[index + 2]
			if (b - a).cross(c - a).dot(Vector3.UP) < 0.001:
				_fail("Road mesh triangle is backfacing or degenerate")
				return
			for n in range(index, index + 3):
				var at: Vector3 = verts[n]
				var uv: Vector2 = uvs[n]
				if absf(at.y - 0.016) > 0.0005:
					_fail("Road art surface is elevated, floating or clipping lane paint")
					return
				if absf(uv.x - at.x / 3.5) > 0.001 or absf(uv.y - at.z / 3.5) > 0.001:
					_fail("Photographed bitumen tiling is stretched or not world-anchored")
					return
				# Preserve the crossing band around ±10.3m and stop bar ±13m:
				# no photoscan quad intrudes on the marked approach zone.
				if maxf(absf(at.x), absf(at.z)) > 7.01 and minf(absf(at.x), absf(at.z)) < 7.01:
					var longitudinal := maxf(absf(at.x), absf(at.z))
					if longitudinal < 14.14:
						_fail("Road resurfacing covers original crossing paint")
						return
			positions_checked += 1
	# Damped shoulders should be visually rougher/more reflective than dry lanes
	# without using fake metalness to increase brightness.
	var dry := roadway.call("get_surface_material", false) as StandardMaterial3D
	var damp := roadway.call("get_surface_material", true) as StandardMaterial3D
	if dry == null or damp == null or not damp.clearcoat_enabled or damp.roughness >= dry.roughness:
		_fail("Damp road shoulders have no physically motivated wet response")
		return
	if positions_checked != 26:
		_fail("All 13 physical road-plane quads must be present")
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
	print("CENTRAL_ROAD_PBR_SMOKE PASS: 2 real-asset PBR drawables, 13 authored road quads, crossing clearance, stable saves")
	quit(0)
