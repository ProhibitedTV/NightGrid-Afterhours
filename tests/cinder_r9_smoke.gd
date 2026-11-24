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
	var shell := hero.get_node("Coachwork") as Node3D
	var front := shell.get_node("FrontClip") as MeshInstance3D
	var materials: Array[String] = []
	var covered_left := false
	var covered_right := false
	var lens_outside := false
	var lens_inside := false
	var lens_edge := false
	for i in front.mesh.get_surface_count():
		var label := front.mesh.surface_get_material(i).resource_name
		materials.append(label)
		if label == "OpticCover":
			var data: Array = front.mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
			for vertex in vertices:
				covered_left = covered_left or (vertex.x < -.45 and vertex.z < -2.16)
				covered_right = covered_right or (vertex.x > .45 and vertex.z < -2.16)
			for normal in normals:
				lens_outside = lens_outside or normal.y > .7
				lens_inside = lens_inside or normal.y < -.7
				lens_edge = lens_edge or absf(normal.y) < .5
	for name in ["Paint", "CarbonComposite", "MachinedAlloy", "OpticCover"]:
		if name not in materials:
			_fail("Missing authored front surface " + name)
			return
	if not covered_left or not covered_right:
		_fail("Headlamp cover geometry must remain on both front corners")
		return
	if not lens_outside or not lens_inside or not lens_edge:
		_fail("Cinder bonded headlamp covers must include both skins and physical edge walls")
		return
	var projector := shell.get_node_or_null("HeadProjectors") as MeshInstance3D
	if projector == null or projector.mesh.get_aabb().size.x < 1.1 or projector.mesh.get_aabb().size.y < .035:
		_fail("Both headlamp assemblies need three-dimensional projector optics")
		return
	# Calipers must be distinct from the spinning wheel visuals but share
	# the knuckle's steering movement. This is a real in-game parenting check,
	# not simply an offline artifact test.
	var rotating_wheels: Array = hero.get("_wheels")
	var calipers: Array = hero.get("_brake_calipers")
	if rotating_wheels.size() != 4 or calipers.size() != 4:
		_fail("Cinder needs four spinning wheels and four independent brake calipers")
		return
	for index in 4:
		var wheel := rotating_wheels[index] as MeshInstance3D
		var caliper := calipers[index] as MeshInstance3D
		if wheel == null or caliper == null or caliper.get_parent() != wheel.get_parent() \
				or caliper.mesh == wheel.mesh or caliper.mesh.get_surface_count() == 0:
			_fail("Brake hardware must share steering knuckles but not wheel-spin meshes")
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
	var heading := -car.global_basis.z
	var starting_phase := float(hero.call("get_motion_state")["wheel_rotation"])
	Input.action_press("drive_accelerate")
	for i in 23:
		await physics_frame
	Input.action_release("drive_accelerate")
	if float(car.get("speed")) < 2.0 or car.global_position.distance_to(initial) < .65:
		_fail("Controller throttle did not advance the Cinder along the generated road")
		return
	var actual_travel := (car.global_position - initial).dot(heading)
	var radius := float(car.get("specification")["tire"])
	var driven_phase := float(hero.call("get_motion_state")["wheel_rotation"])
	if absf(angle_difference(starting_phase + actual_travel / radius, driven_phase)) > .025:
		_fail("Wheel roll did not match actual straight-line chassis displacement")
		return
	Input.action_press("drive_brake")
	for i in 30:
		await physics_frame
	Input.action_release("drive_brake")
	if absf(float(car.get("speed"))) > .30:
		_fail("Handbrake did not stop the Cinder")
		return
	# Cosmetic body loads must leave wheel centers and chassis untouched.
	var wheel_centers: Array[Vector3] = []
	for wheel in rotating_wheels:
		wheel_centers.append((wheel as Node3D).global_position)
	var chassis_pose := car.global_transform
	hero.call("reset_body_pose")
	hero.call("update_motion", 12.0, 0.0, false, true, .7, 0.0, .25, 0.0, Vector2(100.0, 100.0))
	if shell.rotation.x < .004 or shell.rotation.z < .004 \
			or absf(shell.rotation.x) * 1.94 + absf(shell.rotation.z) * 1.06 > .0181:
		_fail("Acceleration and right turn must lift the nose and load the left side within bounds")
		return
	for i in 4:
		if (rotating_wheels[i] as Node3D).global_position.distance_to(wheel_centers[i]) > .0001:
			_fail("Cosmetic coachwork pitch/roll moved an unsprung wheel center")
			return
	if not car.global_transform.is_equal_approx(chassis_pose):
		_fail("Cosmetic body loads altered the physics chassis")
		return
	hero.call("update_motion", 12.0, 0.0, true, true, 0.0, 0.0, .5, 0.0, Vector2(-100.0, -100.0))
	if shell.rotation.x > -.004 or shell.rotation.z > -.004:
		_fail("Braking and left turn must reverse the body load")
		return
	hero.call("update_motion", 0.0, 0.0, false, false, 0.0, 0.0, 1.0, 0.0, Vector2(100.0, 100.0))
	if shell.rotation.length() > .0001:
		_fail("Parked coachwork did not settle back to neutral")
		return
	# A stalled car may still report drive speed: explicit zero travel must
	# override the synthetic speed fallback, and reverse travel must unwind.
	var phase := float(hero.call("get_motion_state")["wheel_rotation"])
	hero.call("update_motion", 12.0, 0.0, false, true, .7, 0.0, .1, 0.0)
	if absf(angle_difference(phase, float(hero.call("get_motion_state")["wheel_rotation"]))) > .00001:
		_fail("Wheels rolled despite zero measured travel")
		return
	hero.call("update_motion", 0.0, 0.0, false, true, 0.0, 0.0, .1, -radius * .5)
	if absf(angle_difference(phase - .5, float(hero.call("get_motion_state")["wheel_rotation"]))) > .00001:
		_fail("Reverse displacement did not unwind wheel phase")
		return
	hero.call("set_lighting_hour", 21.5)
	hero.call("update_motion", 12.0, .5, true, true, .7, .75, .15)
	for index in 4:
		var rotating := rotating_wheels[index] as MeshInstance3D
		var fixed_brake := calipers[index] as MeshInstance3D
		if absf(rotating.rotation.x) < .05 or absf(fixed_brake.rotation.x) > .001:
			_fail("Fixed brake caliper incorrectly spins along with wheel rotation")
			return
	var head := shell.get_node("KeyLeftBeam") as SpotLight3D
	var tail := shell.get_node("RearBeam") as SpotLight3D
	var sill := shell.get_node("SillLightLeftBounce") as OmniLight3D
	var state: Dictionary = hero.call("get_motion_state")
	if not head.visible or not tail.visible or not sill.visible or int(state["live_beams"]) != 2 \
			or (-head.basis.z).dot(Vector3.FORWARD) < .9 or (-tail.basis.z).dot(Vector3.BACK) < .9 \
			or tail.light_color.r <= tail.light_color.g or float(state["steering"]) > -.1 \
			or not (projector.material_override as StandardMaterial3D).emission_enabled:
		_fail("Projected night lamps, brake throw or wheel steering did not engage")
		return
	# The car's positive drive input turns local +X (its world yaw moves
	# negative). Both front wheels must point that way, and the inside wheel
	# must steer farther than the outside wheel.
	var left_knuckle := (rotating_wheels[0] as Node3D).get_parent() as Node3D
	var right_knuckle := (rotating_wheels[1] as Node3D).get_parent() as Node3D
	hero.call("update_motion", 10.0, .78, false, true, .2, 0.0, .4)
	if not (right_knuckle.rotation.y < left_knuckle.rotation.y
			and left_knuckle.rotation.y < -.1
			and absf((calipers[0] as MeshInstance3D).rotation.x) < .001):
		_fail("Right-turn Ackermann wheel angles or fixed-caliper behavior is wrong")
		return
	var previous_right := right_knuckle.rotation.y
	hero.call("update_motion", 10.0, -.78, false, true, .2, 0.0, .016)
	if absf(right_knuckle.rotation.y - previous_right) > .026:
		_fail("Cinder wheel steering snapped rather than moving smoothly")
		return
	hero.call("update_motion", 10.0, -.78, false, true, .2, 0.0, .4)
	if not (left_knuckle.rotation.y > right_knuckle.rotation.y
			and right_knuckle.rotation.y > .1):
		_fail("Left-turn Ackermann inside/outside wheel angles are wrong")
		return
	hero.call("update_motion", 0.0, 0.0, false, false, 0.0, 0.0, .4)
	if absf(left_knuckle.rotation.y) > .001 or absf(right_knuckle.rotation.y) > .001:
		_fail("Front steering did not re-center after leaving Cinder")
		return
	for index in 4:
		if absf((calipers[index] as MeshInstance3D).rotation.x) > .001:
			_fail("Caliper rotated with spinning wheel after steering sweep")
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
	hero.call("update_motion", 0.0, 0.0, false, true, 0.0, 0.0, .25, 0.0, Vector2(10.0, 10.0))
	world.call("_apply_snapshot", saved)
	if shell.rotation != Vector3.ZERO:
		_fail("Snapshot restoration retained transient coachwork tilt")
		return
	if world.get("current_car") != car or not is_equal_approx((car.get("damage_zones") as Vector4).y, .44):
		_fail("Cinder occupancy or damage did not round-trip")
		return
	saved["cars"][2].erase("damage")
	world.call("_apply_snapshot", saved)
	if car.get("damage_zones") != Vector4.ZERO:
		_fail("Original v1 record should load with undamaged panels")
		return
	# Exercise the actual road-ray sampler in a separate physical fixture,
	# above city geometry. Static pads under two opposite tires provide
	# known heights; the other two tires have no nearby support.
	var fixture := CharacterBody3D.new()
	fixture.position = Vector3(0, 200, 0)
	var rig := preload("res://scripts/road_car_visual.gd").new()
	rig.configure(Color("9c2338"))
	fixture.add_child(rig)
	root.add_child(fixture)
	var datum := rig.get("_knuckles") as Array
	for item in [[0, .07], [3, -.07]]:
		var knuckle := datum[int(item[0])] as Node3D
		var pad := StaticBody3D.new()
		var pad_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(.4, .1, .4)
		pad_shape.shape = box
		pad.add_child(pad_shape)
		pad.position = fixture.to_global(Vector3(knuckle.position.x, -.825 + float(item[1]) - .05, knuckle.position.z))
		root.add_child(pad)
	for i in 3:
		await physics_frame
	rig.sample_suspension(fixture.get_rid(), true, .5)
	var offsets: Vector4 = rig.get_motion_state()["suspension_offsets"]
	if offsets.x < .009 or offsets.x > .0101 or absf(offsets.y) > .0001 \
			or absf(offsets.z) > .0001 or offsets.w > -.044 or offsets.w < -.0451:
		_fail("Independent road contact, bump clamp, droop clamp or missing support is wrong")
		return
	var rig_wheels: Array = rig.get("_wheels")
	var rig_brakes: Array = rig.get("_brake_calipers")
	for i in 4:
		var wheel := rig_wheels[i] as Node3D
		var brake := rig_brakes[i] as Node3D
		if absf(wheel.global_position.y - brake.global_position.y) > .0001:
			_fail("Suspension separated the brake caliper from its wheel")
			return
	rig.sample_suspension(fixture.get_rid(), false, .75)
	var settled: Vector4 = rig.get_motion_state()["suspension_offsets"]
	if settled.length() > .0001:
		_fail("Inactive suspension did not settle")
		return
	# Use the same actual physical fixture for wet-contact emission tests.
	# The raised pad is outside visual reach; only the lower reachable pad
	# (wheel 3) is allowed to spray.
	rig.sample_suspension(fixture.get_rid(), true, .5, 12.0, .8)
	var spray: Array = rig.get("_spray")
	if spray.size() != 4 or (spray[0] as CPUParticles3D).emitting \
			or (spray[1] as CPUParticles3D).emitting or (spray[2] as CPUParticles3D).emitting \
			or not (spray[3] as CPUParticles3D).emitting:
		_fail("Wet road spray must be limited to reachable wheel contact")
		return
	var plume := spray[3] as CPUParticles3D
	if plume.direction.z <= 0.0 or plume.local_coords or plume.amount != 24:
		_fail("Forward spray direction, world-space trail or particle budget is wrong")
		return
	rig.sample_suspension(fixture.get_rid(), true, .5, -12.0, .8)
	if not plume.emitting or plume.direction.z >= 0.0:
		_fail("Reverse spray did not switch to the opposite trail direction")
		return
	rig.sample_suspension(fixture.get_rid(), true, .5, 12.0, .0)
	if plume.emitting:
		_fail("Dry road emitted tire spray")
		return
	rig.sample_suspension(fixture.get_rid(), true, .5, 0.0, .8)
	if plume.emitting:
		_fail("Stationary tire emitted spray")
		return
	rig.sample_suspension(fixture.get_rid(), false, .5, 12.0, .8)
	if plume.emitting:
		_fail("Airborne tire emitted spray")
		return
	rig.sample_suspension(fixture.get_rid(), true, .5, 12.0, .8)
	rig.reset_suspension()
	if plume.emitting:
		_fail("Snapshot/reset left tire spray emitting")
		return
	if rig.get_motion_state()["suspension_offsets"] != Vector4.ZERO:
		_fail("Transient suspension did not reset")
		return
	# The two-pad road fixture must never produce a bridging shadow.
	if rig.get_node_or_null("RoadContactOcclusion") != null:
		_fail("Unsupported tire footprint produced contact occlusion")
		return
	# Test the same projection function on level and sloped road contacts.
	var origin := fixture.global_position + Vector3(0, -.825, 0)
	var contacts := PackedVector3Array([origin + Vector3(-.858, 0, -1.43),
		origin + Vector3(.858, .02, -1.43),
		origin + Vector3(-.858, .03, 1.44),
		origin + Vector3(.858, .05, 1.44)])
	rig.call("_update_contact_shadow", contacts)
	var patch := rig.get_node_or_null("RoadContactOcclusion") as MeshInstance3D
	if patch == null or not patch.visible or patch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("Supported road footprint did not produce a non-shadow-casting patch")
		return
	var center := (contacts[0] + contacts[1] + contacts[2] + contacts[3]) * .25
	if absf(patch.global_position.distance_to(center) - .012) > .001:
		_fail("Contact occlusion did not hug the actual road plane")
		return
	contacts[3] += Vector3.UP * .15
	rig.call("_update_contact_shadow", contacts)
	if patch.visible:
		_fail("Noncoplanar curb contacts must not produce a bridging shadow")
		return
	contacts[3] = Vector3.INF
	rig.call("_update_contact_shadow", contacts)
	if patch.visible:
		_fail("Missing road contact must not produce a shadow")
		return
	rig.reset_suspension()
	if patch.visible:
		_fail("Transient contact occlusion survived reset")
		return
	var cluster := rig.get_node("Coachwork/LiveInstrumentCluster")
	rig.call("update_motion", 20.0, 0.0, false, true, .8, 0.0, .2)
	var display: Dictionary = cluster.call("get_display_state")
	if not display["active"] or display["speed"] != "072" or int(display["gear"]) < 1 \
			or float(display["rpm_fraction"]) <= 0.0:
		_fail("Live cluster did not use current vehicle speed and drivetrain telemetry")
		return
	rig.call("set_lighting_hour", 21.5)
	rig.call("update_motion", -4.0, 0.0, true, true, -.5, 0.0, .2)
	display = cluster.call("get_display_state")
	if display["speed"] != "014" or display["gear"] != "R" or not display["night"] or not display["braking"]:
		_fail("Reverse, brake or night cluster state failed")
		return
	rig.call("update_motion", 0.0, 0.0, false, false, 0.0, 0.0, .01)
	if cluster.call("get_display_state")["active"]:
		_fail("Parked instrument cluster did not switch off")
		return
	rig.call("update_motion", 8.0, 0.0, false, true, .5, 0.0, .2)
	rig.call("reset_instrument_cluster")
	if cluster.call("get_display_state")["active"]:
		_fail("Instrument display survived reset")
		return
	print("CINDER_R9_SMOKE PASS")
	quit()
