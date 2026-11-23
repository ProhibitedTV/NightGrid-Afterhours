extends SceneTree
## Exercises the restored coupe through the generated city and v1 snapshot path.

const R9 = preload("res://scripts/road_car_catalog.gd").R9

func _initialize() -> void:
	call_deferred("_verify")

func _fail(reason: String) -> void:
	push_error("CINDER_R9_SMOKE: " + reason)
	quit(1)

func _verify() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	world.get_node("GameMenus").call("hide_for_game")
	var fleet: Array = world.get("cars")
	if fleet.size() != 12:
		_fail("Fleet indices changed")
		return
	var expected := {2: Vector2(63,33), 6: Vector2(63,-143), 8: Vector2(-237,-202)}
	for i in fleet.size():
		var slot: CharacterBody3D = fleet[i]
		if (slot.get("model_id") == R9) != expected.has(i):
			_fail("Wrong model at v1 fleet index %d" % i)
			return
		if expected.has(i) and Vector2(slot.position.x, slot.position.z) != expected[i]:
			_fail("Cinder moved from its established parking address")
			return
		if not expected.has(i) and slot.get_node_or_null("KestrelS6HeroVisual") == null:
			_fail("Kestrel S6 must remain in the other civilian parking slots")
			return
	var car: CharacterBody3D = fleet[2]
	var player: CharacterBody3D = world.get("player")
	var hero := car.get_node("RoadCarVisual") as Node3D
	var shell := hero.get_node("Coachwork")
	var front := shell.get_node("FrontClip") as MeshInstance3D
	var materials: Array[String] = []
	var covered_left := false
	var covered_right := false
	for i in front.mesh.get_surface_count():
		var label := front.mesh.surface_get_material(i).resource_name
		materials.append(label)
		if label == "OpticCover":
			var vertices: PackedVector3Array = front.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				covered_left = covered_left or (vertex.x < -.45 and vertex.z < -2.16)
				covered_right = covered_right or (vertex.x > .45 and vertex.z < -2.16)
	for name in ["Paint", "CarbonComposite", "MachinedAlloy", "OpticCover"]:
		if name not in materials:
			_fail("Missing authored front surface " + name)
			return
	if not covered_left or not covered_right:
		_fail("Headlamp cover geometry must remain on both front corners")
		return
	var projector := shell.get_node_or_null("HeadProjectors") as MeshInstance3D
	if projector == null or projector.mesh.get_aabb().size.x < 1.1 or projector.mesh.get_aabb().size.y < .035:
		_fail("Both headlamp assemblies need three-dimensional projector optics")
		return
	for i in 5:
		await physics_frame
	player.global_position = car.to_global(Vector3(-1.56, .16, -.41))
	if not car.call("toggle_near_door", player.global_position, player.get_rid()):
		_fail("Scissor door could not open at the generated parking point")
		return
	hero.call("update_motion", 0.0, 0.0, false, false, 0.0, 0.0, .75)
	if (shell.get_node("DoorL0") as Node3D).rotation.x > -.8:
		_fail("Hinge did not raise the driver door")
		return
	world.call("_toggle_car")
	if world.get("current_car") != car or player.get_node_or_null("Visual") != null:
		_fail("Failed to enter the actual Cinder and mount the courier")
		return
	var initial := car.global_position
	Input.action_press("drive_accelerate")
	for i in 23:
		await physics_frame
	Input.action_release("drive_accelerate")
	if float(car.get("speed")) < 2.0 or car.global_position.distance_to(initial) < .65:
		_fail("Controller throttle did not advance the Cinder along the generated road")
		return
	Input.action_press("drive_brake")
	for i in 30:
		await physics_frame
	Input.action_release("drive_brake")
	if absf(float(car.get("speed"))) > .30:
		_fail("Handbrake did not stop the Cinder")
		return
	hero.call("set_lighting_hour", 21.5)
	hero.call("update_motion", 12.0, .5, true, true, .7, .75, .15)
	var head := shell.get_node("KeyLeftBeam") as SpotLight3D
	var tail := shell.get_node("RearBeam") as SpotLight3D
	var sill := shell.get_node("SillLightLeftBounce") as OmniLight3D
	var state: Dictionary = hero.call("get_motion_state")
	if not head.visible or not tail.visible or not sill.visible or int(state["live_beams"]) != 2 \
			or (-head.basis.z).dot(Vector3.FORWARD) < .9 or (-tail.basis.z).dot(Vector3.BACK) < .9 \
			or tail.light_color.r <= tail.light_color.g or float(state["steering"]) < .1 \
			or not (projector.material_override as StandardMaterial3D).emission_enabled:
		_fail("Projected night lamps, brake throw or wheel steering did not engage")
		return
	hero.call("update_motion", -2.0, 0.0, false, true, -.5, .75, .1)
	if tail.light_color.g < .7:
		_fail("Reverse light failed to switch to its warm white beam")
		return
	hero.call("set_lighting_hour", 13.4)
	hero.call("update_motion", 0.0, 0.0, false, true, 0.0, 0.0, .1)
	if head.visible or tail.visible or sill.visible or (projector.material_override as StandardMaterial3D).emission_enabled:
		_fail("Unneeded local lights active in daytime")
		return
	car.call("restore_damage", [.33, .44, .18, .05])
	var saved: Dictionary = world.call("_capture_snapshot")
	if saved["occupied_car"] != 2 or not saved["cars"][2].has("damage") or saved["cars"][0].has("damage"):
		_fail("Cinder snapshot changed the occupied index or legacy sedan record")
		return
	world.call("_toggle_car")
	if world.get("current_car") != null or not player.visible or player.collision_mask != 1:
		_fail("Clear exit failed with the lower Cinder collider")
		return
	await physics_frame
	world.call("_apply_snapshot", saved)
	if world.get("current_car") != car or not is_equal_approx((car.get("damage_zones") as Vector4).y, .44):
		_fail("Cinder occupancy or damage did not round-trip")
		return
	saved["cars"][2].erase("damage")
	world.call("_apply_snapshot", saved)
	if car.get("damage_zones") != Vector4.ZERO:
		_fail("Original v1 record should load with undamaged panels")
		return
	print("CINDER_R9_SMOKE PASS")
	quit()
