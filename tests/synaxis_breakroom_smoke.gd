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
	var plaques := office.find_children("MountedWayfinding*", "MeshInstance3D", true, false)
	if plaques.size() < 3:
		_fail("Physical office wayfinding is missing")
		return
	for plaque in plaques:
		var copy := plaque.get_child(0) as Label3D
		if copy == null or copy.outline_size != 0 or copy.fixed_size or copy.no_depth_test or absf(copy.position.z-.021) > .001:
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
