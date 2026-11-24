extends SceneTree
const Crumple = preload("res://scripts/vehicle_crumple.gd")
func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void: quit(1))
	call_deferred("_verify")
func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("VEHICLE_CRASH: " + label)
		quit(1)
	return ok
func _verify() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	var fleet: Array = world.get("cars")
	var car: CharacterBody3D = fleet[2]
	var other: CharacterBody3D = fleet[6]
	car.set_physics_process(false)
	other.set_physics_process(false)
	var rig := car.get_node("RoadCarVisual/Coachwork")
	var front := rig.get_node("FrontClip") as MeshInstance3D
	var rear := rig.get_node("RearClip") as MeshInstance3D
	var original: ArrayMesh = front.mesh
	var original_rear: Mesh = rear.mesh
	var sibling := other.get_node("RoadCarVisual/Coachwork/FrontClip") as MeshInstance3D
	if not check(sibling.mesh == original, "original shared mesh"):
		return
	var collider := car.get_node("CollisionShape3D") as CollisionShape3D
	var shape := collider.shape
	# Real CharacterBody3D contact against a solid wall in an isolated airspace.
	car.global_position = Vector3(0, 100, 0)
	car.rotation = Vector3.ZERO
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 100, -4)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 8, 1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	root.add_child(wall)
	for tick in 12:
		await physics_frame
		car.set("speed", 30.0)
		car.velocity = Vector3(0, 0, -30)
		car.move_and_slide()
		if car.get_slide_collision_count() > 0:
			car.call("_resolve_contacts", Vector3(0, 0, -30))
			break
	var zones: Vector4 = car.get("damage_zones")
	if not check(zones.x > 0.5 and zones.y == 0.0 and float(car.get("condition")) < 100.0 and absf(float(car.get("speed"))) < 1.0, "real impact produces front damage and momentum loss"):
		return
	if not check(front.mesh != original and rear.mesh == original_rear and sibling.mesh == original and collider.shape == shape, "per-car deformed mesh and unchanged collision"):
		return
	var moved := 0
	for i in original.get_surface_count():
		var a: Array = original.surface_get_arrays(i)
		var b: Array = front.mesh.surface_get_arrays(i)
		var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
		if not check(av.size() == bv.size() and a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX] and a[Mesh.ARRAY_TEX_UV] == b[Mesh.ARRAY_TEX_UV] and original.surface_get_material(i) == front.mesh.surface_get_material(i), "preserved topology UV and material"):
			return
		for j in av.size():
			if av[j].distance_to(bv[j]) > 0.0001:
				moved += 1
			if not check(av[j].distance_to(bv[j]) < 0.26, "bounded crush"):
				return
	if not check(moved > 0, "crash changes actual vertex positions"):
		return
	var damaged_mesh: Mesh = front.mesh
	car.call("restore_damage", [zones.x, zones.y, zones.z, zones.w])
	if not check(front.mesh == damaged_mesh, "unchanged damage avoids rebuild"):
		return
	car.call("repair")
	if not check(front.mesh == original and rear.mesh == original_rear and car.get("damage_zones") == Vector4.ZERO and float(car.get("condition")) == 100.0, "repair restores exact original geometry"):
		return
	car.call("take_arcade_damage", 1000.0)
	car.set("occupied", true)
	car.set("speed", 0.0)
	Input.action_press("drive_accelerate")
	car.call("_physics_process", 0.1)
	Input.action_release("drive_accelerate")
	if not check(is_zero_approx(float(car.get("speed"))), "wreck cannot accelerate"):
		return
	print("VEHICLE_CRASH_SMOKE PASS: real solid contact, localized crumple, isolated mesh, repair and disabled wreck")
	quit(0)
