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
	var save: Dictionary = world.call("_capture_snapshot")
	if save["wanted_last_known"] != [0.0, 1.0, 0.0]:
		_fail("Save did not preserve last reported location")
		return
	print("WANTED_SMOKE PASS: witnessed brandish, theft, five tiers, quiet decay, facing/range/occlusion, routine patrols and real dispatch")
	quit(0)
