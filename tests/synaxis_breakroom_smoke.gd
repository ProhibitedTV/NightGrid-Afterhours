extends SceneTree

const Office = preload("res://scripts/synaxis_office.gd")
const Layout = preload("res://scripts/synaxis_ground_layout.gd")

func _initialize() -> void:
	call_deferred("_test")

func _fail(reason: String) -> void:
	push_error("SYNAXIS_BREAKROOM " + reason)
	quit(1)

func _test() -> void:
	var office := Office.new()
	office.position = Office.ORIGIN
	root.add_child(office)
	office.begin_prologue()
	await physics_frame
	await physics_frame
	if OS.has_environment("NIGHTGRID_VERIFY_CREATOR_CAST"):
		var cast: Dictionary = office.get("_staff")
		for id in ["dev", "rina", "people_ops", "jetson_wang"]:
			if cast[id].get_node_or_null("CreatorCastVisual") == null:
				_fail("Missing packaged actor " + id)
				return
		var dev: Node3D = cast["dev"]
		if dev.find_child("ReviewCoffeeRightHand", true, false) == null:
			_fail("Missing Dev's packaged hand attachment")
			return
		print("CREATOR_CAST PASS")
	var art := office.get_node("BreakroomArt") as Node3D
	var kit := art.get_node("AuthoredRoom")
	for name in ["Floor", "Table", "DiningChair1", "DiningChair2", "Casework", "Sink", "Microwave", "Espresso", "Luminaires"]:
		var view := kit.find_child(name, true, false) as MeshInstance3D
		if view == null or not view.mesh is ArrayMesh or view.mesh.get_aabb().size.length() <= 0.0:
			_fail("Missing authored room component " + name)
			return
	var floor_view := kit.find_child("Floor", true, false) as MeshInstance3D
	var terrazzo := floor_view.get_active_material(0) as StandardMaterial3D
	if terrazzo == null or terrazzo.albedo_texture == null or terrazzo.normal_texture == null or terrazzo.roughness_texture == null:
		_fail("Physical floor lacks the documented photo maps")
		return
	var plaques := office.find_children("MountedWayfinding*", "Node3D", true, false)
	if plaques.size() < 3:
		_fail("Physical office wayfinding is missing")
		return
	for plaque in plaques:
		var copy := plaque.get_node_or_null("Inscription") as Label3D
		var print_bed := plaque.get_node_or_null("PrintBed") as MeshInstance3D
		var housing := plaque.get_node_or_null("Housing") as MeshInstance3D
		if copy == null or print_bed == null or housing == null or copy.outline_size != 0 or copy.fixed_size or copy.no_depth_test or copy.position.z <= print_bed.mesh.get_aabb().end.z:
			_fail("Wayfinding must be surface-mounted and depth-tested")
			return
	for node in office.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.text.begins_with("CATERING BUDGET") or label.text.begins_with("RECORDS / COMPLIANCE") or label.text.begins_with("EXECUTIVE ESPRESSO / COMPLIMENTARY"):
			_fail("Removed detached sign still exists")
			return
		if label.name in ["PrinterStatus", "CoffeeStatus"] and label.visible:
			_fail("Appliance status should use the existing interaction prompt")
			return
	var space := office.get_world_3d().direct_space_state
	for plate in plaques:
		var plaque := plate as Node3D
		var housing := plaque.get_node("Housing") as MeshInstance3D
		var tip := plaque.to_global(Vector3(0, 0, .035))
		var back := plaque.to_global(Vector3(0, 0, housing.mesh.get_aabb().position.z - .004))
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(tip, back)).is_empty():
			_fail("Wayfinding chassis does not reach the wall: " + (plaque.get_node("Inscription") as Label3D).text)
			return
	var stone := office.get_node_or_null("GroundEnvelope/Shell/ReceptionStone") as MeshInstance3D
	var suspended := office.get_node_or_null("LobbyLiftDirection/Suspension") as MeshInstance3D
	var flange := office.get_node_or_null("LobbyLiftDirection/CeilingFlange") as MeshInstance3D
	if suspended == null or flange == null or suspended.mesh.get_aabb().size.y < .30 or absf(flange.to_global(flange.mesh.get_aabb().end).y-office.global_position.y-3.35) > .015:
		_fail("The lobby direction sign must reach the ceiling on authored supports")
		return
	var lettering := office.get_node_or_null("ReceptionBrand/Lettering") as MeshInstance3D
	var diffuser := office.get_node_or_null("GroundEnvelope/ReceptionLuminaire/Diffuser") as MeshInstance3D
	if diffuser == null or absf(diffuser.mesh.get_aabb().size.x-3.16) > .02:
		_fail("The reception light needs its dimensioned recessed diffuser")
		return
	if stone == null or stone.mesh.get_aabb().size.x < 5.2 or lettering == null or lettering.mesh.get_aabb().size.z < .02:
		_fail("Reception needs a modular stone wall and extruded lettering")
		return
	var stone_finish := stone.material_override as StandardMaterial3D
	if stone_finish == null or stone_finish.albedo_texture == null or stone_finish.normal_texture == null or stone_finish.roughness_texture == null:
		_fail("Reception stone must use actual albedo, roughness and normals")
		return
	var envelope := office.get_node("GroundEnvelope") as Node3D
	var indirect := envelope.get_node("Indirect") as LightmapGI
	var baked := indirect.light_data
	if baked == null or baked.get_user_count() != 11 or baked.lightmap_textures.is_empty() or indirect.get_child_count() != 7:
		_fail("The streamed ground envelope must load its baked atlas and seven authored probes")
		return
	for index in baked.get_user_count():
		var receiver := indirect.get_node_or_null(baked.get_user_path(index)) as MeshInstance3D
		if receiver == null or receiver.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
			_fail("Broken or non-static production lightmap binding")
			return
		for surface in receiver.mesh.get_surface_count():
			var arrays := receiver.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_TEX_UV2] == null or arrays[Mesh.ARRAY_TEX_UV2].size() != arrays[Mesh.ARRAY_VERTEX].size():
				_fail("Production lightmap receiver lacks secondary UVs")
				return
	for name in ["Floor", "Ceiling", "EastWall", "ReceptionStone", "ReceptionLuminaire"]:
		if office.has_node(name):
			_fail("Duplicate ground-floor render geometry: " + name)
			return
	var front := office.to_global(Vector3(Office.BREAKROOM_POINT.x, .90, Layout.BREAKROOM_FRONT - .45))
	var inside := office.to_global(Vector3(Office.BREAKROOM_POINT.x, .90, Office.BREAKROOM_POINT.z))
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(front, inside)).is_empty():
		_fail("The mission doorway or player approach is obstructed")
		return
	if not office.breakroom_reachable(office.to_global(Office.BREAKROOM_POINT)):
		_fail("The original optional breakroom trigger is unreachable")
		return
	var table := _vertical_hit(office, space, Vector3(-4.2,1.75,8.12))
	var counter := _vertical_hit(office, space, Vector3(-7.94,1.75,8.9))
	if table.is_empty() or counter.is_empty() or absf(office.to_local(table["position"]).y - .76) > .015 or absf(office.to_local(counter["position"]).y - .936) > .015:
		_fail("Table or counter collision is disconnected from its visual surface")
		return
	var mounted := office.get_node("CorporatePropaganda/Water") as Node3D
	var facing := mounted.global_basis.z.normalized()
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		mounted.global_position + facing * .04, mounted.global_position - facing * .14))
	if wall.is_empty() or str(wall["collider"].name).find("BreakroomFront") < 0:
		_fail("The relocated poster lacks backing at the breakroom wall")
		return
	var racks := office.get_node("BasementIT/AuthoredServerRacks") as MultiMeshInstance3D
	var copier := office.get_node("Workfloor1/OfficeServices/PrinterBody") as MeshInstance3D
	var distant := office.get_node("Workfloor1/OfficeServices/PrinterBodyFar") as MeshInstance3D
	if racks.multimesh.instance_count != 20 or copier.mesh.get_faces().size() <= distant.mesh.get_faces().size():
		_fail("Rack batching or copier LOD contract failed")
		return
	if absf(copier.mesh.get_aabb().position.y) > .005 or absf(copier.mesh.get_aabb().size.y - .4) > .005:
		_fail("Copier origin or finished height drifted from the interaction furniture")
		return
	office.call("_select_floor",-1)
	if not racks.is_visible_in_tree() or art.is_visible_in_tree() or copier.is_visible_in_tree():
		_fail("Inactive floor art is still visible from B1")
		return
	office.call("_select_floor",0)
	if not art.is_visible_in_tree() or racks.is_visible_in_tree():
		_fail("Breakroom art was not restored from the basement")
		return
	print("SYNAXIS_BREAKROOM PASS: authored kit, photo maps, doorway, mission anchor, furniture and wall mounting")
	office.queue_free()
	await process_frame
	quit(0)

func _vertical_hit(office: Node3D, space: PhysicsDirectSpaceState3D, local: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(
		office.to_global(local), office.to_global(Vector3(local.x, .04, local.z))))
