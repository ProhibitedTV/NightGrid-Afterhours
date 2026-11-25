extends SceneTree
const Wanted = preload("res://scripts/wanted_system.gd")

func _initialize() -> void:
	create_timer(35.0, true, false, true).timeout.connect(func() -> void: _fail("timeout"))
	call_deferred("_verify")

func _fail(message: String) -> void:
	push_error("WANTED_SMOKE: " + message)
	paused = false
	quit(1)

func _verify() -> void:
	var sim = Wanted.new()
	var at := Vector3(10, 1, 0)
	var clear := {"any": false, "police": false}
	var visible := {"any": true, "police": false}
	var cop := {"any": true, "police": true}
	var heat := 0.0
	for i in range(10):
		heat = sim.observe(heat, at, clear, true, 0.2)
	if heat != 0.0:
		_fail("Unwitnessed drawn weapon must not add heat")
		return
	for i in range(5):
		heat = sim.observe(heat, at, visible, true, 0.2)
	if Wanted.stars(heat) != 1 or sim.last_known != at:
		_fail("Sustained observed brandish must report and create one star")
		return
	var before := heat
	heat = sim.observe(heat, at, cop, true, 0.2)
	if heat != before:
		_fail("Report cooldown prevents repeated instant heat")
		return
	heat = sim.report(heat, "THEFT", at, true)
	if Wanted.stars(heat) != 2:
		_fail("Witnessed theft must escalate")
		return
	for i in range(20):
		heat = sim.report(heat, "SHOT", at, true)
	if heat != 5.0 or Wanted.stars(heat) != 5:
		_fail("Wanted levels must cap at five")
		return
	heat = sim.observe(heat, Vector3(99, 1, 0), clear, false, 0.2)
	if sim.last_known != at:
		_fail("Unseen player motion must not update last-known location")
		return
	heat = sim.decay(heat, 7.0)
	if heat != 5.0:
		_fail("Heat faded before search interval")
		return
	heat = sim.decay(heat, 2.0)
	if heat >= 5.0:
		_fail("Heat must cool after quiet interval")
		return
	# Deterministic search timing: no decay at the grace boundary and only
	# the post-boundary fraction of a long tick may reduce heat.
	var whole = Wanted.new()
	var split = Wanted.new()
	var whole_heat: float = whole.report(0.0, "THEFT", at, true)
	var split_heat: float = split.report(0.0, "THEFT", at, true)
	whole_heat = whole.decay(whole_heat, 10.0)
	for i in range(20):
		split_heat = split.decay(split_heat, 0.5)
	if not is_equal_approx(whole_heat, 0.8) or not is_equal_approx(whole_heat, split_heat):
		_fail("Search grace and cooldown depend on frame partition")
		return
	var boundary = Wanted.new()
	var boundary_heat: float = boundary.report(0.0, "THEFT", at, true)
	boundary_heat = boundary.decay(boundary_heat, 8.0)
	if boundary_heat != 1.0 or boundary.status_text(boundary_heat) != "COOLING DOWN":
		_fail("Heat changed at exact grace boundary")
		return
	boundary_heat = boundary.observe(boundary_heat, at, cop, false, 0.2)
	boundary_heat = boundary.decay(boundary_heat, 2.0)
	if boundary_heat != 1.0 or boundary.quiet != 0.0:
		_fail("Renewed officer sight must restart the search grace")
		return
	boundary_heat = boundary.observe(boundary_heat, at, clear, false, 0.2)
	boundary_heat = boundary.decay(boundary_heat, 17.0)
	if boundary_heat != 0.0 or boundary.last_known.is_finite() or not boundary.last_reason.is_empty() or boundary.status_text(boundary_heat) != "CLEAR":
		_fail("Pursuit did not clear atomically at zero stars")
		return
	var invalid = Wanted.new()
	var invalid_heat: float = invalid.report(1.0, "UNKNOWN", at, true)
	if invalid_heat != 1.0 or invalid.last_known.is_finite() or not invalid.last_reason.is_empty():
		_fail("Unsupported report mutated search state")
		return
	invalid.last_ray_count = Wanted.MAX_RAYS
	invalid.reset()
	if invalid.last_ray_count != 0:
		_fail("Reset retained stale ray count")
		return
	var packed: PackedScene = load("res://scenes/main.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var live = world.get("wanted")
	var patrols: Array = world.get("routine_patrols")
	if patrols.size() != 2 or (world.get("officers") as Array).size() != 0:
		_fail("Two routine patrols must exist at zero heat, without response units")
		return
	var eye := Vector3(0, 2, 3)
	var target := Vector3(0, 2, -6)
	var candidates: Array[Dictionary] = [{"eye": eye, "facing": Vector3.FORWARD, "police": true}]
	var player: CharacterBody3D = world.get("player")
	var ignore: Array[RID] = [player.get_rid()]
	var space := world.get_world_3d().direct_space_state
	if not bool(live.witnesses(space, target, candidates, ignore)["police"]):
		_fail("Actual open street ray should establish sight")
		return
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 2, -1)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.5)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	if bool(live.witnesses(space, target, candidates, ignore)["any"]):
		_fail("Opaque collision must block a real witness ray")
		return
	wall.queue_free()
	if Wanted.in_view(eye, Vector3.BACK, target, 26.0) or Wanted.in_view(eye, Vector3.FORWARD, Vector3(0, 2, -50), 26.0):
		_fail("Facing and range must reject candidates")
		return
	# The actual world dispatch uses last reported position, not player node.
	world.call("_report_incident", "THEFT", Vector3(0, 1, 0), true)
	world.call("_spawn_police")
	var units: Array = world.get("officers")
	if units.size() != 1 or units[0].get("police_destination") != Vector3(0, 1, 0):
		_fail("Response vehicle must use the reported location")
		return
	# Test actual first-entry path twice on an isolated parked car. Move all
	# real witness vehicles away, then position one functional patrol nearby.
	world.set_physics_process(false)
	var traffic: Node = world.get("traffic")
	var fleet: Array = traffic.get("fleet")
	for vehicle in fleet + patrols + units:
		vehicle.set_physics_process(false)
		vehicle.global_position = Vector3(220, 1.1, 220)
	world.set("heat", 0.0)
	live.reset()
	var cars: Array = world.get("cars")
	var test_car: CharacterBody3D = cars[0]
	test_car.set_physics_process(false)
	test_car.global_position = Vector3(0, 1.1, 18)
	player.global_position = Vector3(3, 1.15, 18)
	world.call("_toggle_car")
	world.call("_update_wanted", 0.01)
	if float(world.get("heat")) != 0.0 or world.get("current_car") != test_car:
		_fail("Unwitnessed actual parked car acquisition must not generate heat")
		return
	world.call("_toggle_car")
	var second: CharacterBody3D = cars[1]
	second.set_physics_process(false)
	second.global_position = Vector3(0, 1.1, 18)
	test_car.global_position = Vector3(225, 1.1, 225)
	player.global_position = Vector3(3, 1.15, 18)
	var watcher: CharacterBody3D = patrols[0]
	watcher.global_position = Vector3(3, 1.1, 10)
	watcher.rotation.y = PI
	await physics_frame
	await physics_frame
	world.call("_toggle_car")
	world.call("_update_wanted", 0.01)
	if Wanted.stars(float(world.get("heat"))) != 1 or live.last_reason != "THEFT" or world.get("current_car") != second:
		_fail("Actual theft seen by a patrol must produce a report")
		return
	var theft_heat: float = world.get("heat")
	world.call("_toggle_car")
	player.global_position = Vector3(3, 1.15, 18)
	world.call("_toggle_car")
	world.call("_update_wanted", 0.01)
	if float(world.get("heat")) > theft_heat:
		_fail("Already claimed vehicle should not generate a second theft charge")
		return
	world.call("_report_incident", "THEFT", Vector3(0, 1, 0), true)
	var save: Dictionary = world.call("_capture_snapshot")
	if save["wanted_last_known"] != [0.0, 1.0, 0.0]:
		_fail("Save did not preserve last reported location")
		return
	print("WANTED_SMOKE PASS: witnessed brandish, theft, five tiers, quiet decay, facing/range/occlusion, routine patrols and real dispatch")
	quit(0)
