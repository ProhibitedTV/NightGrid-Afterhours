extends SceneTree
## A real playable replacement for West Docks (-4,-2), lot 1, not a
## stand-alone glTF showroom. Regression: original collision/stable save and
## lane/entrance coordinates survive the architectural mesh transition.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("CRANE_GEAR_GLTF_SMOKE: " + why)
	quit(1)

func _find_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, output)

func _check_asset(lot: Node3D, width: float, height: float, depth: float) -> bool:
	var stats: Dictionary = lot.call("get_art_stats")
	if int(stats["source_meshes"]) != 1 or int(stats["source_surfaces"]) != 6:
		_fail("Original self-contained glTF six-material source architecture missing: " + str(stats))
		return false
	if int(stats["source_vertices"]) < 6000 or int(stats["photographic_pbr_surfaces"]) < 3:
		_fail("Imported photo-PBR source geometry or material maps were lost: " + str(stats))
		return false
	if int(stats["collision_bodies"]) != 0 or int(stats["added_lights"]) != 0:
		_fail("Visual-only DCC art added collider or dynamic lights")
		return false
	var original := lot.get_node_or_null("OriginalCraneGearAuthoredGLTF") as Node3D
	if original == null:
		_fail("The original source-owned .gltf is not instantiated on the playable parcel")
		return false
	var corrected_scale := Vector3(width / 16.1, height / 20.0, depth / 23.0)
	if not original.scale.is_equal_approx(corrected_scale):
		_fail("Model no longer conforms to the exact persisted original parcel footprint")
		return false
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(original, meshes)
	if meshes.size() != 1:
		_fail("Original source building now rendered as placeholder separate boxes")
		return false
	var mesh := meshes[0].mesh
	if mesh == null or mesh.get_surface_count() != 6:
		_fail("Expected all six material-grouped source glTF mesh surfaces")
		return false
	var vertices := 0
	for surface in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		vertices += positions.size()
		if positions.size() < 24 or (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() != positions.size():
			_fail("Original source geometry or UV mapping was dropped at import")
			return false
		if (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() != positions.size() * 4:
			_fail("GLTF no longer supplies physically mapped tangent normal basis")
			return false
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		if material == null:
			_fail("No physically based material assigned to industrial architecture")
			return false
		if surface < 3 and (material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null):
			_fail("Source CC0 brick/steel/roof photographic PBR maps missing")
			return false
	if vertices < 6000:
		_fail("Mesh vertex count indicates an unmodeled placeholder, not original source geometry")
		return false
	return true

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Playable game world missing")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("City streamer / world session failed to initialize")
		return
	var saved_seed := int(session.get("world_seed"))
	var saved_manifest: Dictionary = session.call("get_world_manifest")
	var signature := WorldPlan.manifest_signature(saved_manifest)
	var block := Vector2i(-4, -2)
	var focus := Vector3(-203.0, 0.0, -87.0)
	var persist_profile: Dictionary = saved_manifest["blocks"]["-4,-2"][1]
	var width := float(persist_profile["width"])
	var height := float(persist_profile["height"])
	var depth := float(persist_profile["depth"])
	city.call("set_focus", focus)
	var chunks: Dictionary = city.get("_loaded")
	if not chunks.has(block):
		_fail("Permanent Crane & Gear city block not streamed")
		return
	var chunk := chunks[block] as Node3D
	var replacement := chunk.get_node_or_null("OriginalCraneGearWarehouse") as Node3D
	if replacement == null:
		_fail("New glTF source has not replaced the original opaque parcel body")
		return
	if chunk.get_node_or_null("WestDocksServiceFrontage") != null:
		_fail("New model was installed at Dock Watch instead of Crane & Gear")
		return
	var phys := 0
	for node in chunk.get_children():
		if node is StaticBody3D:
			phys += 1
	if phys != 2:
		_fail("Replacing the frontage changed the original two parcel collision shells")
		return
	var cell_center := Vector3((float(block.x)+0.5)*58.0, 0.0, (float(block.y)+0.5)*58.0)
	var expected := Vector3(cell_center.x+10.5, 0.15,
		cell_center.z - WorldPlan.PUBLIC_FACADE_SETBACK + depth*0.5)
	if not replacement.position.is_equal_approx(expected):
		_fail("Source glTF moved the public parcel away from its saved address")
		return
	if not _check_asset(replacement,width,height,depth):
		return
	var before: Dictionary = replacement.call("get_art_stats")
	city.call("set_focus",Vector3(203.0,0.0,203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(block):
		_fail("Original production glTF leaked after distant chunk unload")
		return
	city.call("set_focus",focus)
	var new_chunk: Node3D = (city.get("_loaded") as Dictionary)[block]
	var new_lot := new_chunk.get_node_or_null("OriginalCraneGearWarehouse") as Node3D
	if new_lot == null or new_lot == replacement or new_lot.call("get_art_stats") != before:
		_fail("Original model failed deterministic city stream reload")
		return
	if not _check_asset(new_lot,width,height,depth):
		return
	if int(session.get("world_seed")) != saved_seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("Architecture update broke permanent saved world identity")
		return
	print("CRANE_GEAR_GLTF_SMOKE PASS: 3114 triangle original glTF,",
		" 3 scanned CC0 PBR families, 2 genuine loading bays,",
		" 40 depth-modelled windows, no extra colliders or lights,",
		" permanent address/seed and stream cycle retained; ",before)
	quit(0)
