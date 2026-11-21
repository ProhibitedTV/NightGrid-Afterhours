extends SceneTree
## Live world-level end-to-end art + PHYSICS test for TWO original walk-in
## Central Exchange shops. No mock scenes and no screenshot substitutes.
## Confirms all other original save/civic/traffic/collision contracts survive.
const WorldPlan = preload("res://scripts/world_plan.gd")
const PORTAL_HALF = 1.42
const PORTAL_DEPTH = 3.35
const PORTAL_HEIGHT = 3.17

func _initialize() -> void:
	call_deferred("_check")

func _fail(why: String) -> void:
	push_error("CENTRAL_EXCHANGE_WALK_IN_SHOPS_SMOKE: " + why)
	quit(1)

func _walk(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		_walk(child, found)

func _validate_shapes(body: StaticBody3D, width: float, height: float, depth: float, front: float) -> bool:
	if body.get_child_count() != 4:
		_fail("Retail building still has a full-volume collider instead of a four-part open doorway")
		return false
	var side_count := 0
	var rear_count := 0
	var header_count := 0
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			_fail("Retail shell lost static BoxShape3D wall collision")
			return false
		var bounds := collision.shape as BoxShape3D
		if collision.name.begins_with("BuildingColliderFlank_"):
			side_count += 1
			if absf(bounds.size.x - (width * 0.5 - PORTAL_HALF)) > 0.005:
				_fail("Left/right collision flanks do not match original saved lot width")
				return false
			if absf(collision.position.x) < PORTAL_HALF:
				_fail("A flank blocks the center walk-in door")
				return false
		elif collision.name == "BuildingColliderVestibuleRear":
			rear_count += 1
			if absf(bounds.size.z - (depth - PORTAL_DEPTH)) > 0.005:
				_fail("Vestibule back wall is missing, leaving walk-through city collision")
				return false
			if absf(collision.position.z - PORTAL_DEPTH*0.5) > 0.005:
				_fail("Retail room depth and solid rear wall no longer align")
				return false
		elif collision.name == "BuildingColliderVestibuleHeader":
			header_count += 1
			if absf(bounds.size.y - (height - PORTAL_HEIGHT)) > 0.005:
				_fail("Over-door shell lintel removed or positioned at a non-walkable height")
				return false
		else:
			_fail("Unexpected collider inside a saved storefront building: "+str(collision.name))
			return false
	if side_count != 2 or rear_count != 1 or header_count != 1:
		_fail("Wrong four-wall partition around real walk-through portal")
		return false
	if absf(body.position.z - (front + depth*0.5)) > 0.005:
		_fail("Collision shell moved away from the previously saved street-front datum")
		return false
	return true

func _validate_store(chunk: Node3D, ix: int, which: int, profile: Dictionary) -> bool:
	var facade_name := "PhotorealFrontage_%d_0_%d" % [ix, which]
	var facade := chunk.get_node_or_null(facade_name) as Node3D
	if facade == null:
		_fail("Playable city is missing source-authored retail facade "+facade_name)
		return false
	var center_x: float = (float(ix) + 0.5)*58.0 + (-10.5 if which == 0 else 10.5)
	var front: float = 29.0 - 14.88
	if not facade.position.is_equal_approx(Vector3(center_x, 0.15, front)):
		_fail("Shopfront relocated an established city-parcel or sidewalk address")
		return false
	var stats: Dictionary = facade.call("get_facade_stats")
	if int(stats.get("walk_in_portals",0)) != 1 or int(stats.get("original_3d_shopfronts",0)) != 1:
		_fail("Generic window stickers are still covering the real entrance: "+str(stats))
		return false
	if int(stats.get("photographic_retail_surfaces",0)) != 4 or (
			float(stats.get("measured_interior_depth_m",0.0)) != PORTAL_DEPTH):
		_fail("Missing real photo-PBR material groups or 3.35m interior depth")
		return false
	if int(stats["collision_bodies"]) != 0 or int(stats["local_lights"]) != 0:
		_fail("Shopfront art unexpectedly duplicated gameplay collision or dynamic lamps")
		return false
	var portal := facade.get_node_or_null("Original3DWalkInRetailVestibule") as Node3D
	if portal == null:
		_fail("No actual source-imported 3D retail opening")
		return false
	var source: Node3D = portal.get_node_or_null("SourceAuthoredPhotoGLTF") as Node3D
	if source == null:
		_fail("Original glTF source storefront was not shipped in game")
		return false
	var pstats: Dictionary = portal.call("get_retail_stats")
	if int(pstats["source_models"]) != 1 or int(pstats["source_vertices"]) < 3500 or (
			int(pstats["source_triangles"]) < 1750):
		_fail("Retail source geometry replaced by simple box/sticker props: "+str(pstats))
		return false
	if int(pstats["original_photo_material_groups"]) != 4 or (
			int(pstats["display_windows"]) != 2 or int(pstats["source_uv_surfaces"]) != 6):
		_fail("Actual photographed metal/brick/concrete retail windows are absent")
		return false
	if absf(float(pstats["portal_opening_width_m"]) - 2.84) > 0.001 or (
			absf(float(pstats["portal_clear_height_m"]) - PORTAL_HEIGHT) > 0.001):
		_fail("Actual door no longer matches the four-part gameplay collision aperture")
		return false
	var models: Array[MeshInstance3D] = []
	_walk(source, models)
	if models.size() != 1 or models[0].mesh == null or models[0].mesh.get_surface_count() != 6:
		_fail("Source 3D doorway, separate transparent glass or practical light lens missing")
		return false
	var mesh := models[0].mesh
	for layer in range(6):
		var mat := mesh.surface_get_material(layer) as StandardMaterial3D
		if mat == null:
			_fail("Original glTF surface lost its imported PBR material")
			return false
		if layer < 4 and (mat.albedo_texture == null or not mat.normal_enabled or (
				mat.normal_texture == null or mat.roughness_texture == null)):
			_fail("Visible 3D retail source lost its original CC0 photo texture layers")
			return false
	var shell: StaticBody3D
	for child in chunk.get_children():
		if child is StaticBody3D and absf(child.position.x - center_x) < 0.005:
			shell = child as StaticBody3D
			break
	if shell == null or not _validate_shapes(shell,
			float(profile["width"]),float(profile["height"]),float(profile["depth"]),front):
		return false
	return true

func _check() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("Playable main scene missing")
		return
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	var session := root.get_node_or_null("GameSession")
	var city: Node3D = game.get_node_or_null("CityDetails") as Node3D
	var controller := game.get_node_or_null("TrafficSignals") as Node
	if session == null or city == null or controller == null:
		_fail("Actual city/session/signal gameplay not available")
		return
	var seed: int = int(session.get("world_seed"))
	var original_manifest := WorldPlan.manifest_signature(session.call("get_world_manifest"))
	city.call("set_focus",Vector3(0.0,0.0,29.0))
	var loaded: Dictionary = city.get("_loaded")
	for pilot in [
		{"block":Vector2i(-1,0),"ix":-1,"which":1},
		{"block":Vector2i(0,0),"ix":0,"which":0}
	]:
		var block: Vector2i = pilot["block"]
		if not loaded.has(block):
			_fail("Original pilot block was not streamed from real playable world: "+str(block))
			return
		var profile := WorldPlan.lot_profile(int(pilot["ix"]),0,int(pilot["which"]),seed)
		var saved_blocks: Dictionary = (session.call("get_world_manifest") as Dictionary).get("blocks",{})
		var saved: Variant = saved_blocks.get("%d,0" % int(pilot["ix"]),[])
		if saved is Array and saved.size()==2:
			profile = (saved[int(pilot["which"])] as Dictionary)
		if not _validate_store(loaded[block],int(pilot["ix"]),int(pilot["which"]),profile):
			return
	if int(controller.call("safe_intersection_count")) != 81:
		_fail("Retail pilots changed existing signal controller geography")
		return
	# Physically walkable test: the gap between the footpath and the
	# 3.35m vestibule MUST NOT be blocked by a whole-volume building collider.
	await physics_frame
	await physics_frame
	for x in [-18.5, 18.5]:
		var from_point := Vector3(x,1.8,13.38)
		var open_end := Vector3(x,1.8,17.20)
		var query := PhysicsRayQueryParameters3D.create(from_point,open_end)
		var path_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if not path_hit.is_empty():
			_fail("Player walk-in doorway still blocked by solid collision: "+str(path_hit))
			return
		var back_test := PhysicsRayQueryParameters3D.create(Vector3(x,1.8,16.98),Vector3(x,1.8,18.65))
		var back_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(back_test)
		if back_hit.is_empty():
			_fail("Retail inner room has no collision back wall")
			return
	var snapshot: Dictionary = game.call("_capture_snapshot")
	game.call("_apply_snapshot",snapshot)
	if int(session.get("world_seed")) != seed or (
		WorldPlan.manifest_signature(session.call("get_world_manifest")) != original_manifest):
		_fail("Shopfront portal changed persistent city seed/parcel address")
		return
	city.call("set_focus",Vector3(203.0,0.0,203.0))
	await process_frame
	if (city.get("_loaded") as Dictionary).has(Vector2i(0,0)):
		_fail("Central retail geometry was not unloaded with its original chunk")
		return
	city.call("set_focus",Vector3(0.0,0.0,29.0))
	for pilot in [
		{"block":Vector2i(-1,0),"ix":-1,"which":1},
		{"block":Vector2i(0,0),"ix":0,"which":0}
	]:
		var chunks: Dictionary = city.get("_loaded")
		var block: Vector2i = pilot["block"]
		if not chunks.has(block):
			_fail("Retail source lost on cold city streaming reload")
			return
		var profile := WorldPlan.lot_profile(int(pilot["ix"]),0,int(pilot["which"]),seed)
		var manifest: Dictionary = session.call("get_world_manifest")
		var records: Dictionary = manifest.get("blocks",{})
		var lots: Variant = records.get("%d,0" % int(pilot["ix"]),[])
		if lots is Array and lots.size()==2:
			profile = (lots[int(pilot["which"])] as Dictionary)
		if not _validate_store(chunks[block],int(pilot["ix"]),int(pilot["which"]),profile):
			return
	print("CENTRAL_EXCHANGE_WALK_IN_SHOPS_SMOKE PASS: two genuine 3D walkable 2.84m x 3.35m retail bays,",
		" photographed walls+steel and transparent glazing,",
		" actual 4-part collision, live physics rays, 81 signals, old saves, deterministic stream reload")
	quit(0)
