extends SceneTree
## Source-level and engine-level checks for the first non-BoxMesh 3D
## Central Exchange architecture. NOT a substitute for visual screenshot review.
func _initialize() -> void:
	call_deferred("_check")

func _fail(reason: String) -> void:
	push_error("CENTRAL_FRONTAGES_SMOKE: " + reason)
	quit(1)

func _find_facade(city: Node3D, ix: int, iz: int, which: int) -> Node3D:
	var chunks: Dictionary = city.get("_loaded")
	var chunk: Node3D = chunks.get(Vector2i(ix, iz))
	if chunk == null:
		return null
	return chunk.get_node_or_null("PhotorealFrontage_%d_%d_%d" % [ix, iz, which])

func _check() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	if main == null:
		_fail("Playable scene missing")
		return
	var world: Node3D = main.instantiate()
	root.add_child(world)
	await process_frame
	var city := world.get_node_or_null("CityDetails") as Node3D
	var session := root.get_node_or_null("GameSession")
	if city == null or session == null:
		_fail("Real streaming city or saved manifest not available")
		return
	var original_seed: int = int(session.get("world_seed"))
	var original_manifest: Dictionary = session.call("get_world_manifest")
	var original_signature := str(load("res://scripts/world_plan.gd").manifest_signature(original_manifest))
	var original_counts: Array[Dictionary] = []
	for query in [[-1, 0, 1, "BRICKWATER"], [0, 0, 0, "AFTERHOURS"]]:
		var ix: int = query[0]
		var iz: int = query[1]
		var which: int = query[2]
		city.call("set_focus", Vector3((float(ix) + 0.5) * 58.0, 0.0, 24.0))
		var facade := _find_facade(city, ix, iz, which)
		if facade == null:
			_fail("Missing world-place façade in block %s" % str(query))
			return
		var stats: Dictionary = facade.call("get_facade_stats")
		if int(stats["architecture_surfaces"]) < 5 or int(stats["window_openings"]) < 8:
			_fail("Streetfront is not a coherent multi-surface authored architectural mesh: %s" % stats)
			return
		if int(stats["shopfront_openings"]) != 4 or int(stats["canopy_segments"]) != 20:
			_fail("Recessed retail shopfront and swept canopy require stable topology")
			return
		var avenue := facade.get_node_or_null("AvenueFacingArchitecture")
		if avenue == null:
			_fail("The original corner building side still presents a blank cube to the Central Exchange road")
			return
		var avenue_stats: Dictionary = avenue.call("get_avenue_stats")
		if int(avenue_stats["windows"]) < 16 or int(avenue_stats["shopfront_bays"]) < 4 or int(avenue_stats["meshes"]) < 5:
			_fail("The actual road-facing side lacks full-height storefronts and recessed windows: %s" % avenue_stats)
			return
		if int(stats["avenue_windows"]) != int(avenue_stats["windows"]):
			_fail("Road-facing openings not recorded in the scope of the structural asset")
			return
		if not avenue.has_node("AvenueShopIdentity"):
			_fail("Actual road-facing shop identity absent or reversed")
			return
		for part in avenue.get_children():
			if part is MeshInstance3D and not (part.mesh is ArrayMesh):
				_fail("Road-facing elevation is still a pile of box primitive cards")
				return
			if part is CollisionObject3D:
				_fail("Visual-only side replacement introduced invisible obstacles in the sidewalk")
				return
		if str(query[3]) == "BRICKWATER":
			# This is one finished building, not an indiscriminate city style.
			var finish := facade.get_node_or_null("BrickwaterSealedCornerAndRoof")
			if finish == null:
				_fail("Brickwater corner building is missing its sealed shell/roof")
				return
			var finish_stats: Dictionary = finish.call("get_finish_stats")
			if int(finish_stats["sealed_corner_returns"]) != 4 or int(finish_stats["solid_roof_edges"]) != 4 or int(finish_stats["coping_edges"]) != 4:
				_fail("Open corner seams or unsealed parapet: %s" % finish_stats)
				return
			if int(finish_stats["array_mesh_surfaces"]) != 3 or int(finish_stats["foundation_runs"]) != 3:
				_fail("Missing scanned masonry/roof/steel finish meshes: %s" % finish_stats)
				return
			if int(finish_stats["new_collisions"]) != 0 or int(finish_stats["new_lights"]) != 0:
				_fail("A visual architecture pass changed gameplay collision or lighting")
				return
			for part in finish.get_children():
				if not (part is MeshInstance3D) or not (part.mesh is ArrayMesh):
					_fail("Finished corner must only contain authored triangle meshes")
					return
				var finish_material := part.material_override as StandardMaterial3D
				if finish_material == null or finish_material.cull_mode != BaseMaterial3D.CULL_BACK:
					_fail("Finished shell has missing faces/backface holes or lacks PBR material")
					return
			var masonry := facade.call("_surface_material", "MASONRY") as StandardMaterial3D
			var cladding := facade.call("_surface_material", "CLADDING") as StandardMaterial3D
			if masonry == null or cladding == null or not masonry.normal_enabled or not cladding.normal_enabled:
				_fail("Scanned normal maps were imported but not actually enabled")
				return
			var roof := facade.call("_surface_material", "ROOF") as StandardMaterial3D
			if roof == null or not roof.normal_enabled or roof.normal_texture == null or roof.albedo_texture == null or roof.roughness_texture == null:
				_fail("Bright procedural tiled roof returned instead of photo-based bitumen PBR")
				return
			var glass := facade.call("_surface_material", "GLASS") as StandardMaterial3D
			if glass == null or glass.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				_fail("Brickwater glass remains an opaque painted panel")
				return
			if not facade.has_node("Facade_DARK_ROOM") or not avenue.has_node("AvenueSurface_DARK_ROOM"):
				_fail("Glass shows through to empty sky instead of believable room depth")
				return
		else:
			if facade.has_node("BrickwaterSealedCornerAndRoof"):
				_fail("Brickwater roof was incorrectly duplicated at Afterhours")
				return
			var afterhours_finish := facade.get_node_or_null("AfterhoursSealedCornerAndRoof")
			if afterhours_finish == null:
				_fail("Afterhours has an exposed south/avenue corner or missing roof finish")
				return
			var after_stats: Dictionary = afterhours_finish.call("get_finish_stats")
			if int(after_stats["sealed_corner_returns"]) != 4 or int(after_stats["solid_roof_edges"]) != 4:
				_fail("Afterhours envelope is not sealed on every elevation: %s" % after_stats)
				return
			if int(after_stats["coping_edges"]) != 4 or int(after_stats["foundation_runs"]) != 3:
				_fail("Afterhours roof/foundation has exposed edges")
				return
			if int(after_stats["roof_service_grilles"]) != 6 or int(after_stats["canopy_edge_seals"]) != 3:
				_fail("Afterhours rooftop service enclosure or canopy edge geometry missing")
				return
			if int(after_stats["array_mesh_surfaces"]) != 3:
				_fail("Afterhours must have material-sorted metal, roof and vent solids")
				return
			if int(after_stats["new_collisions"]) != 0 or int(after_stats["new_lights"]) != 0:
				_fail("Afterhours art introduced a collision or an unbudgeted lamp")
				return
			for part in afterhours_finish.get_children():
				if not (part is MeshInstance3D) or not (part.mesh is ArrayMesh):
					_fail("Afterhours seal must use contiguous triangle mesh geometry")
					return
				var mat := part.material_override as StandardMaterial3D
				if mat == null or mat.cull_mode != BaseMaterial3D.CULL_BACK:
					_fail("Missing rear/roof surface or backface winding")
					return
				var arrays: Array = (part.mesh as ArrayMesh).surface_get_arrays(0)
				if (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty():
					_fail("Afterhours scanned PBR surfaces have no UV tangents")
					return
			var roof_mat := facade.call("_surface_material", "ROOF") as StandardMaterial3D
			var metal_mat := facade.call("_surface_material", "CLADDING") as StandardMaterial3D
			if roof_mat == null or metal_mat == null or not roof_mat.normal_enabled or not metal_mat.normal_enabled:
				_fail("Afterhours 2K photographed roof or steel normal maps disabled")
				return
			var after_glass := facade.call("_surface_material", "GLASS") as StandardMaterial3D
			if after_glass == null or after_glass.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				_fail("Afterhours window glazing remains flat opaque panels")
				return
			if not facade.has_node("Facade_DARK_ROOM") or not avenue.has_node("AvenueSurface_DARK_ROOM"):
				_fail("Afterhours windows have no independent recessed room backings")
				return
		if int(stats["reveal_faces"]) < 32:
			_fail("Openings are missing recessed jamb and sill geometry")
			return
		if int(stats["collision_bodies"]) != 0 or int(stats["local_lights"]) != 0:
			_fail("Art pass added unapproved physical obstacles or lights")
			return
		if str(facade.get("district")) != str(query[3]):
			_fail("Fashionable architecture has been put in wrong district")
			return
		var expected_x := -18.5 if ix < 0 else 18.5
		if absf(facade.position.x - expected_x) > 0.01 or absf(facade.position.z - 14.12) > 0.02:
			_fail("Building façade detached from actual streetfront world setback: %s" % facade.position)
			return
		# A real separate custom vertex topology—not dozens of BoxMesh cards.
		for child in facade.get_children():
			if child is MeshInstance3D:
				if not (child.mesh is ArrayMesh):
					_fail("Non-authored primitive/BoxMesh used in new reference-facing architectural façade")
					return
				var array_mesh := child.mesh as ArrayMesh
				if array_mesh.get_surface_count() != 1:
					_fail("Expected material-sorted coherent geometric surfaces")
					return
				var vertices: PackedVector3Array = array_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				if vertices.size() < 6:
					_fail("Degenerate architecture surface")
					return
			if child is CollisionObject3D:
				_fail("Façade unexpectedly changed existing building physics")
				return
		if not facade.has_node("ExistingShopIdentity"):
			_fail("Saved neighborhood store identity was dropped")
			return
		var root_chunk: Node3D = (city.get("_loaded") as Dictionary)[Vector2i(ix, iz)]
		var shell_found := false
		for item in root_chunk.get_children():
			if item is StaticBody3D and absf(item.position.x - expected_x) < 0.01:
				shell_found = true
				if item.name != "PreservedBuildingCollision":
					_fail("Old solid visual cube is still underneath the new window openings")
					return
				# This is a deliberate new *physics* milestone. The original
				# opaque one-box shell is now four real solid partitions around
				# an actual player-passable 2.84m x 3.35m pilot entrance.
				var observed := {}
				for child in item.get_children():
					if child is MeshInstance3D:
						_fail("Visually occluding BoxMesh remained under the recessed glass")
						return
					var piece := child as CollisionShape3D
					if piece == null or not piece.shape is BoxShape3D:
						_fail("New storefront room lost its four-part solid collision shell")
						return
					observed[str(piece.name)] = piece.shape
				if observed.size() != 4 or not observed.has("BuildingColliderVestibuleRear") or (
					not observed.has("BuildingColliderVestibuleHeader") or
					not observed.has("BuildingColliderFlank_-1") or
					not observed.has("BuildingColliderFlank_1")):
					_fail("Original building envelope must retain two walls, a roof header and solid back wall around the newly open entrance")
					return
				var rear := observed["BuildingColliderVestibuleRear"] as BoxShape3D
				if rear == null or rear.size.x < 2.8:
					_fail("New retail vestibule lost its collision back wall")
					return
				break
		if not shell_found:
			_fail("Prior stable building collision shell missing")
			return
		var asset_root := "res:" + "//assets/pbr/polyhaven/"
		var has_brick: bool = ResourceLoader.exists(asset_root + "brick_wall_001_diffuse_2k.jpg")
		var has_steel: bool = ResourceLoader.exists(asset_root + "blue_metal_plate_diffuse_2k.jpg")
		if not has_brick or not has_steel:
			_fail("The real 2K scanned CC0 material maps must ship with the playable scene")
			return
		if str(query[3]) == "BRICKWATER" and int(stats["real_pbr_maps"]) != 9:
			_fail("Brick frontage, steel fascia and bitumen roof did not bind all nine scanned PBR maps")
			return
		if str(query[3]) == "AFTERHOURS" and int(stats["real_pbr_maps"]) != 6:
			_fail("Afterhours steel facade and bitumen roof must bind six genuine 2K PBR maps")
			return
		original_counts.append(stats)
	# Switching streaming focus unloads/reconstructs this location using
	# the SAME world manifest; photoscan/PBR art must not depend on RNG state.
	city.call("set_focus", Vector3(210.0, 0.0, 210.0))
	await process_frame
	city.call("set_focus", Vector3.ZERO)
	await process_frame
	for j in range(2):
		var ix := -1 if j == 0 else 0
		var which := 1 if j == 0 else 0
		var facade := _find_facade(city, ix, 0, which)
		if facade == null or facade.call("get_facade_stats") != original_counts[j]:
			_fail("Reference architecture changed after streaming in a different order")
			return
	var snapshot: Dictionary = session.call("make_snapshot", world.call("_capture_snapshot"))
	if not bool(session.call("is_valid_snapshot", snapshot)):
		_fail("Facade substitution invalidated v1 save data")
		return
	world.call("_apply_snapshot", snapshot)
	if int(session.get("world_seed")) != original_seed:
		_fail("Visual-only architecture altered world seed")
		return
	var signature := str(load("res://scripts/world_plan.gd").manifest_signature(session.call("get_world_manifest")))
	if signature != original_signature:
		_fail("Art upgrade silently mutated saved buildings/locations")
		return
	print("CENTRAL_FRONTAGES_SMOKE PASS: two modeled walk-in retail facades, safe four-wall collision, stable shop IDs and unchanged saves")
	quit(0)
