extends SceneTree
## Source-of-truth art test: the real playable Dock Watch neighbor, not a
## detached debug preview, must contain a correctly located source GLTF.
## Same saved parcel collision and seed before and after stream reload.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("WEST_DOCKS_CC0_ART_SMOKE: " + reason)
	quit(1)

func _mesh_children(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_mesh_children(child, result)

func _verify() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		_fail("Missing actual playable main scene")
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var session := root.get_node_or_null("GameSession")
	var city := world.get_node_or_null("CityDetails") as Node3D
	if city == null or session == null:
		_fail("Gameplay world/city/session absent")
		return
	var before_seed := int(session.get("world_seed"))
	var before_manifest := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var block := Vector2i(-4, -1)
	var fixed_address := Vector3(-203.0, 0.0, -29.0)
	city.call("set_focus", fixed_address)
	var chunks: Dictionary = city.get("_loaded")
	if not chunks.has(block):
		_fail("Fixed Dock Watch block not streamed")
		return
	var chunk: Node3D = chunks[block]
	var facade := chunk.get_node_or_null("WestDocksServiceFrontage")
	if facade == null:
		_fail("Committed CC0 glTF frontage not installed beside Dock Watch")
		return
	var civic := chunk.get_node_or_null("PhotorealFrontage_-4_-1_0")
	if civic == null:
		_fail("New service facade displaced the original Dock Watch Desk")
		return
	var phys := 0
	for child in chunk.get_children():
		if child is StaticBody3D:
			phys += 1
	if phys != 2:
		_fail("Service art changed original two save-stable parcel collision shells")
		return
	var stats: Dictionary = facade.call("get_facade_stats")
	if int(stats.get("mesh_surfaces", 0)) < 5 or int(stats.get("openings", 0)) < 15:
		_fail("Authored complete-envelope/photo-UV walls or recessed glazing missing: " + str(stats))
		return
	if int(stats["service_bays"]) != 2 or int(stats["shutter_variants"]) != 2 or int(stats["source_meshes"]) != 2:
		_fail("Need two unique real scanned model shutter variants: " + str(stats))
		return
	if int(stats["cc0_photo_maps"]) < 9 or int(stats["additional_lights"]) != 0 or int(stats["collision_bodies"]) != 0:
		_fail("Missing distinct photographic maps or art introduced unwanted gameplay lights/collision")
		return
	var shutter_meshes := 0
	var real_source_vertices := 0
	for variant in ["Clean", "Graffiti"]:
		var shutter := facade.get_node_or_null("CC0WeatheredRollerShutter_" + variant)
		if shutter == null:
			_fail("Missing imported source glTF shutter variant: " + variant)
			return
		var meshes: Array[MeshInstance3D] = []
		_mesh_children(shutter, meshes)
		if meshes.size() != 2:
			_fail("Imported glTF did not retain both original upstream meshes")
			return
		var visible := 0
		for mesh in meshes:
			if not mesh.visible:
				continue
			visible += 1
			shutter_meshes += 1
			if mesh.mesh == null or mesh.mesh.get_surface_count() < 1:
				_fail("Scanned CC0 source has no drawable mesh")
				return
			real_source_vertices += mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			if material == null or material.albedo_texture == null or not material.normal_enabled:
				_fail("Source UV mesh lost its original photo-PBR albedo/normal: " + variant)
				return
		if visible != 1:
			_fail("Clean/graffiti upstream copies overlap each other")
			return
	if shutter_meshes != 2 or real_source_vertices < 1200:
		_fail("Expected actual authored photogrammetry rather than box placeholders")
		return
	for material_name in ["BRICK", "METAL", "ROOF"]:
		var material := facade.call("_material", material_name) as StandardMaterial3D
		if material == null or material.albedo_texture == null or not material.normal_enabled:
			_fail("West Docks surrounding original envelope missing photographed UV/PBR " + material_name)
			return
	var restored_signature: Dictionary = stats.duplicate(true)
	city.call("set_focus", Vector3(203.0, 0.0, 203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(block):
		_fail("Distant source glTF scene was not unloaded with its city chunk")
		return
	city.call("set_focus", fixed_address)
	var replacement: Node3D = (city.get("_loaded") as Dictionary)[block]
	var new_facade := replacement.get_node_or_null("WestDocksServiceFrontage")
	if new_facade == null or new_facade == facade or new_facade.call("get_facade_stats") != restored_signature:
		_fail("Source model fails deterministic streamed reload")
		return
	if int(session.get("world_seed")) != before_seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != before_manifest:
		_fail("Art change modified persistent city identity")
		return
	print("WEST_DOCKS_CC0_ART_SMOKE PASS: photo glTF shaders=", shutter_meshes,
		" real scanned vertices=", real_source_vertices, " architectural maps=",
		stats["cc0_photo_maps"], " geometry=", stats,
		" / two original colliders, civic address and seed unchanged")
	quit(0)
