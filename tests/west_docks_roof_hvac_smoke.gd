extends SceneTree
## Issue #51: imported official photo-HVAC must live in the playable West
## Docks stream, with original mounting rail geometry and no save/collision
## changes. Headless tests verify source and layout, not photographic quality.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(why: String) -> void:
	push_error("WEST_DOCKS_ROOF_HVAC_SMOKE: " + why)
	quit(1)

func _gather(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather(child, output)

func _check_roof(facade: Node3D) -> bool:
	var stats: Dictionary = facade.call("get_facade_stats")
	if int(stats.get("rooftop_hvac_units", 0)) != 2 or int(stats.get("rooftop_hvac_photo_surfaces", 0)) != 4:
		_fail("Two true scanned rooftop HVAC units/four photo materials missing: " + str(stats))
		return false
	if int(stats.get("original_mount_profiles", 0)) != 4:
		_fail("Original UV-unwrapped steel saddle profiles missing")
		return false
	var roof := facade.get_node_or_null("OriginalWestDocksRoofPlant")
	if roof == null:
		_fail("Rooftop artwork has not been installed into the actual service frontage")
		return false
	var metrics: Dictionary = roof.call("get_roof_stats")
	if int(metrics["collision_bodies"]) != 0 or int(metrics["added_lights"]) != 0:
		_fail("Artwork unexpectedly changed physics or practical light budget")
		return false
	if int(metrics["original_rail_triangles"]) < 150:
		_fail("Rail mounts are not true sculpted I-profile geometry")
		return false
	var rails := roof.get_node_or_null("OriginalUVSteelISectionRoofMounts") as MeshInstance3D
	if rails == null or rails.mesh == null or rails.mesh.get_surface_count() != 1:
		_fail("Original steel mount ArrayMesh missing")
		return false
	var arrays: Array = rails.mesh.surface_get_arrays(0)
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 450 or (
			arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() < 450 or (
			arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() < 450 * 4:
		_fail("Steel I-section mounts lack original triangles, UVs or tangent basis")
		return false
	var steel := rails.material_override as StandardMaterial3D
	if steel == null or steel.albedo_texture == null or not steel.normal_enabled or steel.roughness_texture == null:
		_fail("Roof supports are not using source-licensed scanned metallic PBR")
		return false
	for variant in ["Clean", "Weathered"]:
		var source := roof.get_node_or_null("CC0RooftopHVAC_" + variant) as Node3D
		if source == null:
			_fail("Missing source model " + variant)
			return false
		if absf(source.position.y - (float(facade.get("building_height")) + 0.98)) > 0.02:
			_fail("Roof unit is floating or sunk into the building")
			return false
		if absf(source.position.x) > float(facade.get("building_width")) * 0.5 - 1.5:
			_fail("Source aircon extends beyond the original building parcel")
			return false
		var scanned: Array[MeshInstance3D] = []
		_gather(source, scanned)
		if scanned.size() != 2:
			_fail("Imported clean/weathered comparison source has the wrong mesh count")
			return false
		var shown := 0
		for mesh in scanned:
			if not mesh.visible:
				continue
			shown += 1
			if mesh.mesh == null or mesh.mesh.get_surface_count() != 2:
				_fail("Source mesh lost its original two-part fan/grill geometry")
				return false
			var original_vertices := 0
			for surface in range(mesh.mesh.get_surface_count()):
				original_vertices += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material == null or material.albedo_texture == null or not material.normal_enabled or (
						material.normal_texture == null or material.roughness_texture == null):
					_fail("Imported HVAC lost its original licensed color, roughness or tangent-normal maps")
					return false
			if original_vertices < 6000:
				_fail("Imported model is not the real high-detail upstream HVAC geometry")
				return false
		if shown != 1:
			_fail("Both photo variants are overlapping in the same installation")
			return false
	return true

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Missing actual playable scene")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var session := root.get_node_or_null("GameSession")
	var city := world.get_node_or_null("CityDetails") as Node3D
	if city == null or session == null:
		_fail("Missing active city/save session")
		return
	var seed := int(session.get("world_seed"))
	var signature := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var block := Vector2i(-4, -1)
	var position := Vector3(-203.0, 0.0, -29.0)
	city.call("set_focus", position)
	var loaded: Dictionary = city.get("_loaded")
	if not loaded.has(block):
		_fail("Real Dock Watch parcel did not stream")
		return
	var chunk := loaded[block] as Node3D
	var facade := chunk.get_node_or_null("WestDocksServiceFrontage") as Node3D
	if facade == null or chunk.get_node_or_null("PhotorealFrontage_-4_-1_0") == null:
		_fail("Scanned roof equipment displaced the existing civic/service buildings")
		return
	var solid_bodies := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			solid_bodies += 1
	if solid_bodies != 2:
		_fail("Original permanent two parcel collision shells changed")
		return
	if not _check_roof(facade):
		return
	var original_stats: Dictionary = facade.call("get_facade_stats")
	city.call("set_focus", Vector3(203.0, 0.0, 203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(block):
		_fail("Source-backed art did not unload on distant travel")
		return
	city.call("set_focus", position)
	var replacement: Node3D = (city.get("_loaded") as Dictionary)[block]
	var new_facade := replacement.get_node_or_null("WestDocksServiceFrontage") as Node3D
	if new_facade == null or new_facade == facade or new_facade.call("get_facade_stats") != original_stats:
		_fail("Rooftop equipment changed across deterministic chunk reload")
		return
	if not _check_roof(new_facade):
		return
	if int(session.get("world_seed")) != seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != signature:
		_fail("Imported artwork modified world identity or persisted save contract")
		return
	print("WEST_DOCKS_ROOF_HVAC_SMOKE PASS: two official 1K source models,",
		" four true photo-PBR materials, four authored UV I-profiles,",
		" zero extra bodies/lights, fixed civic address and save identity")
	quit(0)
