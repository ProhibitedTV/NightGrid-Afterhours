extends SceneTree
## Actual playable Central Exchange CC0 street art / road decal integration.
## Verifies all PBR scans, collision-safe fixed street placements and normal
## photo decals inside the existing signal city, not a detached asset viewer.
const WorldPlan = preload("res://scripts/world_plan.gd")

func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("EXCHANGE_PHOTO_STREET_KIT_SMOKE: " + reason)
	quit(1)

func _walk_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_walk_meshes(child, output)

func _check_site(site: Node3D, kind: String, rust: bool) -> bool:
	if site == null:
		_fail("Missing scanned " + kind + " source street placement")
		return false
	if minf(absf(site.position.x), absf(site.position.z)) < 11.5:
		_fail("Street furniture would obstruct central road/crossing approaches")
		return false
	if absf(site.position.y - 0.16) > 0.01:
		_fail("Photogrammetry is floating or buried in the sidewalk")
		return false
	var original := site.get_node_or_null("OriginalPolyHavenPhotoGLTF") as Node3D
	var collider := site.get_node_or_null("RealStreetFurnitureCollider") as StaticBody3D
	if original == null or collider == null or collider.get_child_count() != 1:
		_fail("Source glTF or actual street furniture collision shell missing")
		return false
	var geometry := collider.get_child(0) as CollisionShape3D
	if geometry == null or not geometry.shape is BoxShape3D:
		_fail("Photographic street furniture can be walked through")
		return false
	var shape := geometry.shape as BoxShape3D
	if shape.size.x > 0.65 or shape.size.z > 0.65 or shape.size.y > 1.22:
		_fail("Street furniture collider blocks the pedestrian walkway")
		return false
	var scanned: Array[MeshInstance3D] = []
	_walk_meshes(original, scanned)
	var trash := kind == "TRASH"
	if scanned.size() != (8 if trash else 1):
		_fail("Official source glTF parts were replaced by inaccurate placeholder")
		return false
	var visible := 0
	var triangles := 0
	for mesh in scanned:
		if not mesh.visible:
			continue
		visible += 1
		if trash and (str(mesh.name).to_lower().contains("rust") != rust):
			_fail("Clean and rusted comparison meshes overlap in a single can")
			return false
		if mesh.mesh == null:
			_fail("Original Poly Haven source lost its actual geometry")
			return false
		for surface in range(mesh.mesh.get_surface_count()):
			triangles += (mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var mat := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if mat == null or mat.albedo_texture == null or not mat.normal_enabled or (
						mat.normal_texture == null or mat.roughness_texture == null):
				_fail("Source imported without original color/roughness/normal PBR")
				return false
	if visible != (4 if trash else 1) or triangles < (4300 if trash else 3600):
		_fail("Wrong visible scanned source complexity: %d/%d" % [visible, triangles])
		return false
	return true

func _check() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_fail("Missing playable main scene")
		return
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var hero := world.get_node_or_null("CentralExchangeHero") as Node3D
	var session := root.get_node_or_null("GameSession")
	var city := world.get_node_or_null("CityDetails")
	var signals := world.get_node_or_null("TrafficSignals")
	if hero == null or session == null or city == null or signals == null:
		_fail("Source street kit must live inside actual playable central junction")
		return
	var seed := int(session.get("world_seed"))
	var manifest := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	var kit := hero.get_node_or_null("CentralExchangePhotoStreetKit") as Node3D
	if kit == null or hero.position != Vector3.ZERO:
		_fail("Real-photo street kit is missing from permanent city origin")
		return
	var stats: Dictionary = kit.call("get_street_stats")
	var hero_stats: Dictionary = hero.call("get_visual_stats")
	if int(stats["source_installs"]) != 5 or int(stats["sidewalk_collision_bodies"]) != 5:
		_fail("Need exactly 3 sampled trash cans + 2 scanned utility cabinets, with walkable collisions")
		return
	if int(stats["visible_source_meshes"]) != 14 or int(stats["source_vertices"]) < 21000:
		_fail("Imported official glTF photo meshes were not installed or culled properly: " + str(stats))
		return
	if int(stats["photo_material_surfaces"]) != 14 or int(stats["added_lights"]) != 0:
		_fail("Photo props lost original scan materials or added too many lights")
		return
	if int(stats["road_decal_projections"]) != 4 or int(stats["road_decal_photo_maps"]) != 6:
		_fail("Not enough PBR terrain detail, or material atlas is duplicated")
		return
	if int(hero_stats.get("photographed_street_props", 0)) != 5 or (
			int(hero_stats.get("photo_road_decal_projections", 0)) != 4):
		_fail("Central Exchange gameplay has not adopted the photo asset pipeline")
		return
	var sites = [
		["SouthwestRustedBin", "TRASH", true],
		["NortheastCleanBin", "TRASH", false],
		["SoutheastRustedBin", "TRASH", true],
		["NorthwestPowerCabinet", "UTILITY", false],
		["SoutheastPowerCabinet", "UTILITY", false]
	]
	for entry in sites:
		if not _check_site(kit.get_node_or_null(entry[0]) as Node3D,entry[1],entry[2]):
			return
	for target in ["NorthGutterOil", "SouthGutterOil", "WestGutterGrime", "EastGutterGrime"]:
		var decal := kit.get_node_or_null(target) as Decal
		if decal == null or decal.texture_albedo == null or decal.texture_orm == null or decal.texture_normal == null:
			_fail("Missing original photo-sourced Godot Forward+ PBR decal " + target)
			return
		if not decal.distance_fade_enabled or decal.distance_fade_begin > 40.0 or decal.size.y > 0.25:
			_fail("Road grime decal projection is too costly or can project onto cars")
			return
		if maxf(absf(decal.position.x), absf(decal.position.z)) < 15.5 or (
			minf(absf(decal.position.x),absf(decal.position.z)) > 6.5):
			_fail("Photo grime projected across central crossing instead of the road gutters")
			return
	if int(signals.call("safe_intersection_count")) != 81:
		_fail("Street realism pass altered road signal topology")
		return
	var saved: Dictionary = world.call("_capture_snapshot")
	world.call("_apply_snapshot", saved)
	if kit.call("get_street_stats") != stats or hero.call("get_visual_stats") != hero_stats:
		_fail("Street art / source decal identities changed across save restore")
		return
	if int(session.get("world_seed")) != seed or WorldPlan.manifest_signature(session.call("get_world_manifest")) != manifest:
		_fail("Photo street kit broke saved city seed/parcel manifest")
		return
	print("EXCHANGE_PHOTO_STREET_KIT_SMOKE PASS: ", stats,
		" / 81 original controlled crossings / save identity intact")
	quit(0)
